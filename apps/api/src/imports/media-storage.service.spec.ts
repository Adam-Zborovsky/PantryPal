import { S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { ConfigService } from '@nestjs/config';
import { HouseholdAccessService } from '../households/household-access.service';
import { PrismaService } from '../prisma/prisma.service';
import { MediaStorageService } from './media-storage.service';

jest.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: jest.fn(),
}));

describe('MediaStorageService', () => {
  const requireActiveMembership = jest.fn().mockResolvedValue({});
  const create = jest.fn();
  const deleteAsset = jest.fn();
  const findFirst = jest.fn();
  const update = jest.fn();
  const updateMany = jest.fn();
  const findMany = jest.fn();
  const findInstance = jest.fn();
  const updateInstance = jest.fn();
  const configValues: Record<string, string> = {
    S3_ENDPOINT: 'http://localhost:9000',
    S3_REGION: 'us-east-1',
    S3_BUCKET: 'pantrypal',
    S3_ACCESS_KEY: 'test-access',
    S3_SECRET_KEY: 'test-secret',
    MEDIA_MAX_BYTES: '1000',
  };

  const service = () =>
    new MediaStorageService(
      {
        mediaAsset: {
          create,
          delete: deleteAsset,
          findFirst,
          update,
          updateMany,
          findMany,
        },
        cookingInstance: {
          findFirst: findInstance,
          update: updateInstance,
        },
      } as unknown as PrismaService,
      { requireActiveMembership } as unknown as HouseholdAccessService,
      {
        get: jest.fn((key: string) => configValues[key]),
      } as unknown as ConfigService,
    );

  beforeEach(() => {
    jest.clearAllMocks();
    (getSignedUrl as jest.Mock).mockResolvedValue(
      'https://storage.test/signed',
    );
  });

  it('rejects media types outside the allowed kind-specific list', async () => {
    await expect(
      service().createUpload('account-1', 'household-1', {
        kind: 'image',
        mimeType: 'video/mp4',
        byteSize: 50,
      }),
    ).rejects.toThrow('Unsupported media type');
    expect(create).not.toHaveBeenCalled();
  });

  it('rejects a declared media size above the configured bound', async () => {
    await expect(
      service().createUpload('account-1', 'household-1', {
        kind: 'image',
        mimeType: 'image/jpeg',
        byteSize: 1001,
      }),
    ).rejects.toThrow('MEDIA_TOO_LARGE_OR_LONG');
    expect(create).not.toHaveBeenCalled();
  });

  it('creates a pending asset and returns a short-lived signed PUT URL', async () => {
    create.mockResolvedValue({});
    const result = await service().createUpload('account-1', 'household-1', {
      kind: 'image',
      mimeType: 'image/jpeg',
      byteSize: 1000,
    });
    expect(result.uploadUrl).toBe('https://storage.test/signed');
    expect(result.assetExpiresAt.getTime()).toBeGreaterThan(Date.now());
    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          householdId: 'household-1',
          kind: 'IMAGE',
          status: 'UPLOAD_PENDING',
          byteSize: 1000,
          storageKey: expect.stringContaining('imports/household-1/'),
        }),
      }),
    );
    expect(getSignedUrl).toHaveBeenCalledWith(
      expect.any(S3Client),
      expect.anything(),
      expect.objectContaining({ expiresIn: 900 }),
    );
  });

  it('marks an upload ready only after object metadata matches the request', async () => {
    findFirst.mockResolvedValue({
      id: 'asset-1',
      householdId: 'household-1',
      status: 'UPLOAD_PENDING',
      storageKey: 'imports/household-1/asset-1.jpg',
      mimeType: 'image/jpeg',
      byteSize: 500,
      expiresAt: new Date(Date.now() + 60_000),
    });
    update.mockResolvedValue({});
    const instance = service();
    const client = {
      send: jest
        .fn()
        .mockResolvedValue({ ContentType: 'image/jpeg', ContentLength: 500 }),
    };
    (instance as unknown as { client: S3Client }).client =
      client as unknown as S3Client;

    await expect(
      instance.completeUpload('account-1', 'household-1', 'asset-1'),
    ).resolves.toEqual({ assetId: 'asset-1', status: 'READY', byteSize: 500 });
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { status: 'READY', uploadedAt: expect.any(Date) },
      }),
    );
  });

  describe('cover photos', () => {
    const archivedInstance = {
      id: 'instance-1',
      householdId: 'household-1',
      status: 'ARCHIVED',
      archiveCoverKey: null as string | null,
    };

    it('rejects cover uploads for a meal that is not archived', async () => {
      findInstance.mockResolvedValue({
        ...archivedInstance,
        status: 'SCHEDULED',
      });
      await expect(
        service().createCoverUpload(
          'account-1',
          'household-1',
          'instance-1',
          { mimeType: 'image/jpeg', byteSize: 500 },
        ),
      ).rejects.toThrow('archived');
    });

    it('creates a pending cover asset under the covers prefix', async () => {
      findInstance.mockResolvedValue(archivedInstance);
      create.mockResolvedValue({});
      const result = await service().createCoverUpload(
        'account-1',
        'household-1',
        'instance-1',
        { mimeType: 'image/jpeg', byteSize: 1000 },
      );
      expect(result.uploadUrl).toBe('https://storage.test/signed');
      expect(create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            householdId: 'household-1',
            kind: 'COVER',
            status: 'UPLOAD_PENDING',
            storageKey: expect.stringContaining('covers/household-1/'),
          }),
        }),
      );
    });

    it('rejects non-image mime types for covers', async () => {
      findInstance.mockResolvedValue(archivedInstance);
      await expect(
        service().createCoverUpload(
          'account-1',
          'household-1',
          'instance-1',
          { mimeType: 'video/mp4', byteSize: 500 },
        ),
      ).rejects.toThrow('Unsupported media type');
      expect(create).not.toHaveBeenCalled();
    });

    it('completes the cover, retains the asset, and attaches the key to the instance', async () => {
      findFirst
        .mockResolvedValueOnce({
          id: 'asset-1',
          householdId: 'household-1',
          kind: 'COVER',
          status: 'UPLOAD_PENDING',
          storageKey: 'covers/household-1/cover.jpg',
          mimeType: 'image/jpeg',
          byteSize: 500,
          expiresAt: new Date(Date.now() + 60_000),
        })
        .mockResolvedValue(null);
      findInstance.mockResolvedValue({ ...archivedInstance });
      update.mockResolvedValue({});
      updateInstance.mockResolvedValue({});
      const instance = service();
      const client = {
        send: jest
          .fn()
          .mockResolvedValue({ ContentType: 'image/jpeg', ContentLength: 500 }),
      };
      (instance as unknown as { client: S3Client }).client =
        client as unknown as S3Client;

      await expect(
        instance.completeCoverUpload(
          'account-1',
          'household-1',
          'instance-1',
          'asset-1',
        ),
      ).resolves.toEqual({
        cookingInstanceId: 'instance-1',
        archiveCoverKey: 'covers/household-1/cover.jpg',
      });
      expect(update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: 'READY',
            retained: true,
            expiresAt: null,
          }),
        }),
      );
      expect(updateInstance).toHaveBeenCalledWith(
        expect.objectContaining({
          data: { archiveCoverKey: 'covers/household-1/cover.jpg' },
        }),
      );
    });

    it('refuses to complete when the object metadata does not match', async () => {
      findFirst.mockResolvedValueOnce({
        id: 'asset-1',
        householdId: 'household-1',
        kind: 'COVER',
        status: 'UPLOAD_PENDING',
        storageKey: 'covers/household-1/cover.jpg',
        mimeType: 'image/jpeg',
        byteSize: 500,
        expiresAt: new Date(Date.now() + 60_000),
      });
      update.mockResolvedValue({});
      const instance = service();
      const client = {
        send: jest
          .fn()
          .mockResolvedValue({ ContentType: 'image/jpeg', ContentLength: 499 }),
      };
      (instance as unknown as { client: S3Client }).client =
        client as unknown as S3Client;

      await expect(
        instance.completeCoverUpload(
          'account-1',
          'household-1',
          'instance-1',
          'asset-1',
        ),
      ).rejects.toThrow('did not match');
      expect(updateInstance).not.toHaveBeenCalled();
    });

    it('reads a retained cover back with its mime type', async () => {
      findInstance.mockResolvedValue({
        ...archivedInstance,
        archiveCoverKey: 'covers/household-1/cover.jpg',
      });
      findFirst.mockResolvedValueOnce({
        householdId: 'household-1',
        storageKey: 'covers/household-1/cover.jpg',
        mimeType: 'image/webp',
        byteSize: 3,
        status: 'READY',
      });
      const instance = service();
      const client = {
        send: jest.fn().mockResolvedValue({
          Body: {
            transformToByteArray: async () => [1, 2, 3],
          },
        }),
      };
      (instance as unknown as { client: S3Client }).client =
        client as unknown as S3Client;

      await expect(
        instance.readCoverBytes('account-1', 'household-1', 'instance-1'),
      ).resolves.toEqual({
        mimeType: 'image/webp',
        bytes: Buffer.from([1, 2, 3]),
      });
    });

    it('404s when the archived meal has no cover yet', async () => {
      findInstance.mockResolvedValue(archivedInstance);
      await expect(
        service().readCoverBytes('account-1', 'household-1', 'instance-1'),
      ).rejects.toThrow('No cover photo');
    });
  });
});
