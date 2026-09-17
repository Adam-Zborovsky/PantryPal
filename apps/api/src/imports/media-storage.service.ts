import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommandOutput,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MediaAssetStatus, MediaKind } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { createWriteStream } from 'node:fs';
import { mkdir, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Readable, Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { HouseholdAccessService } from '../households/household-access.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMediaUploadDto } from './imports.dto';
import type { ImportErrorCode } from './import-errors';

const allowedMimeTypes: Record<MediaKind, ReadonlySet<string>> = {
  IMAGE: new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
  AUDIO: new Set([
    'audio/mpeg',
    'audio/mp4',
    'audio/wav',
    'audio/x-wav',
    'audio/flac',
    'audio/ogg',
    'audio/webm',
  ]),
  VIDEO: new Set(['video/mp4', 'video/webm', 'video/quicktime']),
  COVER: new Set(['image/jpeg', 'image/png', 'image/webp']),
};

const kindBySourceKind: Record<string, MediaKind | undefined> = {
  image: 'IMAGE',
  audio: 'AUDIO',
  video: 'VIDEO',
};

const mediaAssetTtlMs = 60 * 60 * 1000;
const signedUploadTtlSeconds = 15 * 60;

export class MediaStorageError extends Error {
  constructor(
    readonly code: Extract<
      ImportErrorCode,
      'MEDIA_TOO_LARGE_OR_LONG' | 'MEDIA_PROCESSING_FAILED'
    >,
    message: string,
  ) {
    super(message);
  }
}

@Injectable()
export class MediaStorageService {
  private client?: S3Client;

  constructor(
    private readonly prisma: PrismaService,
    private readonly access: HouseholdAccessService,
    private readonly config: ConfigService,
  ) {}

  async createUpload(
    accountId: string,
    householdId: string,
    input: CreateMediaUploadDto,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const kind = kindBySourceKind[input.kind];
    const mimeType = input.mimeType.trim().toLowerCase();
    if (!kind || !allowedMimeTypes[kind].has(mimeType)) {
      throw new BadRequestException('Unsupported media type for this upload.');
    }
    if (input.byteSize > this.maxBytes()) {
      throw new BadRequestException(
        'MEDIA_TOO_LARGE_OR_LONG: Media exceeds the configured size limit.',
      );
    }

    const assetId = randomUUID();
    const assetExpiresAt = new Date(Date.now() + mediaAssetTtlMs);
    const uploadExpiresAt = new Date(
      Date.now() + signedUploadTtlSeconds * 1000,
    );
    const storageKey = `imports/${householdId}/${assetId}${this.extensionFor(mimeType)}`;
    await this.prisma.mediaAsset.create({
      data: {
        id: assetId,
        householdId,
        kind,
        status: 'UPLOAD_PENDING',
        storageKey,
        mimeType,
        byteSize: input.byteSize,
        expiresAt: assetExpiresAt,
      },
    });
    try {
      const uploadUrl = await getSignedUrl(
        this.s3(),
        new PutObjectCommand({
          Bucket: this.bucket(),
          Key: storageKey,
          ContentType: mimeType,
        }),
        {
          expiresIn: signedUploadTtlSeconds,
          signableHeaders: new Set(['content-type']),
        },
      );
      return { assetId, uploadUrl, uploadExpiresAt, assetExpiresAt };
    } catch (error) {
      await this.prisma.mediaAsset.delete({ where: { id: assetId } });
      throw error;
    }
  }

  async completeUpload(
    accountId: string,
    householdId: string,
    assetId: string,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const asset = await this.findOwnedAsset(householdId, assetId);
    if (asset.status === 'READY') {
      return {
        assetId: asset.id,
        status: 'READY' as const,
        byteSize: asset.byteSize,
      };
    }
    if (asset.status === 'EXPIRED' || this.isExpired(asset.expiresAt)) {
      await this.expire(asset);
      throw new BadRequestException(
        'This media upload has expired. Start a new upload.',
      );
    }

    let head: HeadObjectCommandOutput;
    try {
      head = await this.s3().send(
        new HeadObjectCommand({ Bucket: this.bucket(), Key: asset.storageKey }),
      );
    } catch {
      throw new BadRequestException('The uploaded media is not available yet.');
    }
    const contentType = head.ContentType?.split(';')[0]?.trim().toLowerCase();
    if (
      head.ContentLength !== asset.byteSize ||
      contentType !== asset.mimeType
    ) {
      await this.expire(asset);
      throw new BadRequestException(
        'Uploaded media did not match the requested size or type.',
      );
    }
    await this.prisma.mediaAsset.update({
      where: { id: asset.id },
      data: { status: 'READY', uploadedAt: new Date() },
    });
    return {
      assetId: asset.id,
      status: 'READY' as const,
      byteSize: asset.byteSize,
    };
  }

  /**
   * Cover photo for an archived meal: same presigned-PUT-then-verify flow as
   * import media, but the asset is retained on completion so the TTL sweep
   * never deletes a household's archive cover.
   */
  async createCoverUpload(
    accountId: string,
    householdId: string,
    cookingInstanceId: string,
    input: { mimeType: string; byteSize: number },
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const instance = await this.prisma.cookingInstance.findFirst({
      where: { id: cookingInstanceId, householdId },
    });
    if (!instance) {
      throw new NotFoundException('Archived meal not found in this household.');
    }
    if (instance.status !== 'ARCHIVED') {
      throw new BadRequestException(
        'Only archived meals can receive a cover photo.',
      );
    }
    const mimeType = input.mimeType.trim().toLowerCase();
    if (!allowedMimeTypes.COVER.has(mimeType)) {
      throw new BadRequestException('Unsupported media type for this upload.');
    }
    if (input.byteSize > this.maxBytes()) {
      throw new BadRequestException(
        'MEDIA_TOO_LARGE_OR_LONG: Media exceeds the configured size limit.',
      );
    }

    const assetId = randomUUID();
    const uploadExpiresAt = new Date(
      Date.now() + signedUploadTtlSeconds * 1000,
    );
    const storageKey = `covers/${householdId}/${assetId}${this.extensionFor(mimeType)}`;
    await this.prisma.mediaAsset.create({
      data: {
        id: assetId,
        householdId,
        kind: 'COVER',
        status: 'UPLOAD_PENDING',
        storageKey,
        mimeType,
        byteSize: input.byteSize,
        expiresAt: new Date(Date.now() + mediaAssetTtlMs),
      },
    });
    try {
      const uploadUrl = await getSignedUrl(
        this.s3(),
        new PutObjectCommand({
          Bucket: this.bucket(),
          Key: storageKey,
          ContentType: mimeType,
        }),
        {
          expiresIn: signedUploadTtlSeconds,
          signableHeaders: new Set(['content-type']),
        },
      );
      return { assetId, storageKey, uploadUrl, uploadExpiresAt };
    } catch (error) {
      await this.prisma.mediaAsset.delete({ where: { id: assetId } });
      throw error;
    }
  }

  async completeCoverUpload(
    accountId: string,
    householdId: string,
    cookingInstanceId: string,
    assetId: string,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const asset = await this.findOwnedAsset(householdId, assetId);
    if (asset.kind !== 'COVER') {
      throw new BadRequestException('This media asset is not a cover photo.');
    }
    if (this.isExpired(asset.expiresAt)) {
      await this.expire(asset);
      throw new BadRequestException(
        'This media upload has expired. Start a new upload.',
      );
    }

    let head: HeadObjectCommandOutput;
    try {
      head = await this.s3().send(
        new HeadObjectCommand({ Bucket: this.bucket(), Key: asset.storageKey }),
      );
    } catch {
      throw new BadRequestException('The uploaded media is not available yet.');
    }
    const contentType = head.ContentType?.split(';')[0]?.trim().toLowerCase();
    if (
      head.ContentLength !== asset.byteSize ||
      contentType !== asset.mimeType
    ) {
      await this.expire(asset);
      throw new BadRequestException(
        'Uploaded media did not match the requested size or type.',
      );
    }

    const instance = await this.prisma.cookingInstance.findFirst({
      where: { id: cookingInstanceId, householdId },
    });
    if (!instance || instance.status !== 'ARCHIVED') {
      throw new BadRequestException(
        'Only archived meals can receive a cover photo.',
      );
    }

    await this.prisma.mediaAsset.update({
      where: { id: asset.id },
      data: {
        status: 'READY',
        retained: true,
        expiresAt: null,
        uploadedAt: new Date(),
      },
    });
    await this.prisma.cookingInstance.update({
      where: { id: instance.id },
      data: { archiveCoverKey: asset.storageKey },
    });
    if (instance.archiveCoverKey && instance.archiveCoverKey !== asset.storageKey) {
      try {
        await this.s3().send(
          new DeleteObjectCommand({
            Bucket: this.bucket(),
            Key: instance.archiveCoverKey,
          }),
        );
      } catch {
        // The old object is swept eventually even if this delete fails.
      }
    }
    return {
      cookingInstanceId: instance.id,
      archiveCoverKey: asset.storageKey,
    };
  }

  async readCoverBytes(
    accountId: string,
    householdId: string,
    cookingInstanceId: string,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const instance = await this.prisma.cookingInstance.findFirst({
      where: { id: cookingInstanceId, householdId },
    });
    if (!instance?.archiveCoverKey) {
      throw new NotFoundException('No cover photo found for this meal.');
    }
    const asset = await this.prisma.mediaAsset.findFirst({
      where: {
        householdId,
        storageKey: instance.archiveCoverKey,
        status: 'READY',
      },
    });
    try {
      const response = await this.s3().send(
        new GetObjectCommand({
          Bucket: this.bucket(),
          Key: instance.archiveCoverKey,
        }),
      );
      if (!response.Body) throw new Error('Media object had no body.');
      const bytes = await response.Body.transformToByteArray();
      return {
        mimeType:
          asset?.mimeType ?? response.ContentType ?? 'application/octet-stream',
        bytes: Buffer.from(bytes),
      };
    } catch (error) {
      if (error instanceof NotFoundException) throw error;
      throw new ServiceUnavailableException(
        'The cover photo could not be read right now.',
      );
    }
  }

  async reserveForImport(
    householdId: string,
    assetId: string,
    sourceKind: string,
    importJobId: string,
  ) {
    const expectedKind = kindBySourceKind[sourceKind];
    if (!expectedKind) return;
    const asset = await this.findOwnedAsset(householdId, assetId);
    if (
      asset.status !== 'READY' ||
      asset.kind !== expectedKind ||
      this.isExpired(asset.expiresAt)
    ) {
      throw new BadRequestException(
        'Media must be uploaded and verified before it can be imported.',
      );
    }
    const result = await this.prisma.mediaAsset.updateMany({
      where: { id: asset.id, householdId, importJobId: null },
      data: { importJobId },
    });
    if (result.count !== 1) {
      throw new BadRequestException(
        'This media asset is already attached to an import.',
      );
    }
  }

  releaseImportReservation(
    householdId: string,
    assetId: string,
    importJobId: string,
  ) {
    return this.prisma.mediaAsset.updateMany({
      where: { id: assetId, householdId, importJobId },
      data: { importJobId: null },
    });
  }

  async sweepExpired(limit = 100) {
    const expired = await this.prisma.mediaAsset.findMany({
      where: {
        retained: false,
        status: { not: 'EXPIRED' },
        expiresAt: { lt: new Date() },
      },
      take: limit,
    });
    await Promise.all(expired.map((asset) => this.expire(asset)));
    return expired.length;
  }

  async readReadyImageForImport(
    householdId: string,
    assetId: string,
    importJobId: string,
  ) {
    const asset = await this.prisma.mediaAsset.findFirst({
      where: {
        id: assetId,
        householdId,
        importJobId,
        kind: 'IMAGE',
        status: 'READY',
      },
    });
    if (!asset || this.isExpired(asset.expiresAt)) {
      throw new MediaStorageError(
        'MEDIA_PROCESSING_FAILED',
        'The uploaded image is no longer available for analysis.',
      );
    }
    if (asset.byteSize > this.maxInlineImageBytes()) {
      throw new MediaStorageError(
        'MEDIA_TOO_LARGE_OR_LONG',
        'This image is too large for inline recipe analysis. Upload an image smaller than 10 MB or paste the recipe text.',
      );
    }
    try {
      const response = await this.s3().send(
        new GetObjectCommand({ Bucket: this.bucket(), Key: asset.storageKey }),
      );
      if (!response.Body) throw new Error('Media object had no body.');
      const bytes = await response.Body.transformToByteArray();
      if (bytes.byteLength !== asset.byteSize) {
        throw new Error('Media object size changed after verification.');
      }
      return {
        mimeType: asset.mimeType,
        data: Buffer.from(bytes).toString('base64'),
      };
    } catch (error) {
      if (error instanceof MediaStorageError) throw error;
      throw new MediaStorageError(
        'MEDIA_PROCESSING_FAILED',
        'The uploaded image could not be read for analysis.',
      );
    }
  }

  async downloadReadyMediaForImport(
    householdId: string,
    assetId: string,
    importJobId: string,
  ) {
    const asset = await this.prisma.mediaAsset.findFirst({
      where: {
        id: assetId,
        householdId,
        importJobId,
        kind: { in: ['AUDIO', 'VIDEO'] },
        status: 'READY',
      },
    });
    if (!asset || this.isExpired(asset.expiresAt)) {
      throw new MediaStorageError(
        'MEDIA_PROCESSING_FAILED',
        'The uploaded media is no longer available for analysis.',
      );
    }
    const root = this.config.get<string>('MEDIA_TEMP_ROOT')?.trim() || tmpdir();
    await mkdir(root, { recursive: true });
    const directory = await mkdtemp(join(root, 'pantrypal-media-'));
    const path = join(directory, `source${this.extensionFor(asset.mimeType)}`);
    try {
      const response = await this.s3().send(
        new GetObjectCommand({ Bucket: this.bucket(), Key: asset.storageKey }),
      );
      if (!response.Body) throw new Error('Media object had no body.');
      let received = 0;
      const limit = new Transform({
        transform(chunk: Buffer, _encoding, callback) {
          received += chunk.length;
          if (received > asset.byteSize) {
            callback(new Error('Media object exceeded its verified size.'));
            return;
          }
          callback(null, chunk);
        },
      });
      await pipeline(
        response.Body as Readable,
        limit,
        createWriteStream(path, { flags: 'wx' }),
      );
      if (received !== asset.byteSize) {
        throw new Error('Media object size changed after verification.');
      }
      return {
        path,
        directory,
        kind: asset.kind,
        mimeType: asset.mimeType,
        byteSize: asset.byteSize,
        cleanup: () => rm(directory, { recursive: true, force: true }),
      };
    } catch {
      await rm(directory, { recursive: true, force: true });
      throw new MediaStorageError(
        'MEDIA_PROCESSING_FAILED',
        'The uploaded media could not be acquired for analysis.',
      );
    }
  }

  private async findOwnedAsset(householdId: string, assetId: string) {
    const asset = await this.prisma.mediaAsset.findFirst({
      where: { id: assetId, householdId },
    });
    if (!asset)
      throw new NotFoundException('Media asset not found in this household.');
    return asset;
  }

  private async expire(asset: {
    id: string;
    storageKey: string;
    status: MediaAssetStatus;
  }) {
    if (asset.status !== 'EXPIRED') {
      try {
        await this.s3().send(
          new DeleteObjectCommand({
            Bucket: this.bucket(),
            Key: asset.storageKey,
          }),
        );
      } catch {
        // The row still expires even if the object is absent or storage is briefly unavailable.
      }
      await this.prisma.mediaAsset.update({
        where: { id: asset.id },
        data: { status: 'EXPIRED' },
      });
    }
  }

  private s3() {
    return (this.client ??= new S3Client({
      endpoint: this.required('S3_ENDPOINT'),
      region: this.config.get<string>('S3_REGION') ?? 'us-east-1',
      forcePathStyle:
        this.config.get<string>('S3_FORCE_PATH_STYLE') !== 'false',
      credentials: {
        accessKeyId: this.required('S3_ACCESS_KEY'),
        secretAccessKey: this.required('S3_SECRET_KEY'),
      },
    }));
  }

  private bucket() {
    return this.required('S3_BUCKET');
  }

  private required(name: string) {
    const value = this.config.get<string>(name)?.trim();
    if (!value)
      throw new ServiceUnavailableException(
        'Media uploads are not configured.',
      );
    return value;
  }

  private maxBytes() {
    const configured = Number(this.config.get<string>('MEDIA_MAX_BYTES'));
    return Number.isSafeInteger(configured) && configured > 0
      ? configured
      : 500 * 1024 * 1024;
  }

  private maxInlineImageBytes() {
    const configured = Number(
      this.config.get<string>('MEDIA_IMAGE_ANALYSIS_MAX_BYTES'),
    );
    return Number.isSafeInteger(configured) && configured > 0
      ? configured
      : 10 * 1024 * 1024;
  }

  private isExpired(expiresAt: Date | null) {
    return expiresAt != null && expiresAt <= new Date();
  }

  private extensionFor(mimeType: string) {
    return (
      {
        'image/jpeg': '.jpg',
        'image/png': '.png',
        'image/webp': '.webp',
        'image/heic': '.heic',
        'audio/mpeg': '.mp3',
        'audio/mp4': '.m4a',
        'audio/wav': '.wav',
        'audio/x-wav': '.wav',
        'audio/flac': '.flac',
        'audio/ogg': '.ogg',
        'audio/webm': '.webm',
        'video/mp4': '.mp4',
        'video/webm': '.webm',
        'video/quicktime': '.mov',
      }[mimeType] ?? ''
    );
  }
}
