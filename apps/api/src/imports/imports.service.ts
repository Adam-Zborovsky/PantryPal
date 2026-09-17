import { Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { HouseholdAccessService } from '../households/household-access.service';
import { PrismaService } from '../prisma/prisma.service';
import { SourceUrlService } from './source-url.service';
import { CreateImportDto } from './imports.dto';
import { ImportQueueService } from './import-queue.service';
import { MediaStorageService } from './media-storage.service';

@Injectable()
export class ImportsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: HouseholdAccessService,
    private readonly urls: SourceUrlService,
    private readonly queue: ImportQueueService,
    private readonly media: MediaStorageService,
  ) {}

  async create(accountId: string, householdId: string, input: CreateImportDto) {
    await this.access.requireActiveMembership(accountId, householdId);
    const canonicalUrl =
      input.sourceKind === 'url'
        ? await this.urls.canonicalize(input.sourceInput)
        : undefined;
    const isImage = input.sourceKind === 'image';
    const jobId = isImage ? randomUUID() : undefined;
    if (isImage && jobId) {
      await this.media.reserveForImport(
        householdId,
        input.sourceInput,
        input.sourceKind,
        jobId,
      );
    }
    let job;
    try {
      job = await this.prisma.importJob.create({
        data: {
          ...(jobId ? { id: jobId } : {}),
          householdId,
          accountId,
          sourceKind: input.sourceKind,
          sourceInput: input.sourceInput,
          canonicalUrl,
          status: 'QUEUED',
        },
      });
    } catch (error) {
      if (isImage && jobId) {
        await this.media.releaseImportReservation(
          householdId,
          input.sourceInput,
          jobId,
        );
      }
      throw error;
    }
    await this.queue.enqueue(job.id);
    return job;
  }

  async get(accountId: string, householdId: string, id: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    const job = await this.prisma.importJob.findFirst({
      where: { id, householdId },
      select: {
        id: true,
        householdId: true,
        status: true,
        progress: true,
        errorCode: true,
        errorDetail: true,
        revision: true,
        sourceKind: true,
        sourceInput: true,
        canonicalUrl: true,
        recipeId: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    if (!job)
      throw new NotFoundException('Import job not found in this household.');
    return job;
  }

  async cancel(accountId: string, householdId: string, id: string) {
    const job = await this.get(accountId, householdId, id);
    if (['READY_FOR_REVIEW', 'FAILED', 'CANCELLED'].includes(job.status))
      return job;
    return this.prisma.importJob.update({
      where: { id },
      data: { status: 'CANCELLED', revision: { increment: 1 } },
    });
  }
}
