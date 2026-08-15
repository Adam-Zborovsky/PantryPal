import { Injectable, NotFoundException } from '@nestjs/common';
import { HouseholdAccessService } from '../households/household-access.service';
import { PrismaService } from '../prisma/prisma.service';
import { SourceUrlService } from './source-url.service';
import { CreateImportDto } from './imports.dto';

@Injectable()
export class ImportsService {
  constructor(private readonly prisma: PrismaService, private readonly access: HouseholdAccessService, private readonly urls: SourceUrlService) {}

  async create(accountId: string, householdId: string, input: CreateImportDto) {
    await this.access.requireActiveMembership(accountId, householdId);
    const canonicalUrl = input.sourceKind === 'url' ? this.urls.canonicalize(input.sourceInput) : undefined;
    return this.prisma.importJob.create({ data: { householdId, accountId, sourceKind: input.sourceKind, sourceInput: input.sourceInput, canonicalUrl, status: 'QUEUED' } });
  }

  async get(accountId: string, householdId: string, id: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    const job = await this.prisma.importJob.findFirst({ where: { id, householdId } });
    if (!job) throw new NotFoundException('Import job not found in this household.');
    return job;
  }

  async cancel(accountId: string, householdId: string, id: string) {
    const job = await this.get(accountId, householdId, id);
    if (['READY_FOR_REVIEW', 'FAILED', 'CANCELLED'].includes(job.status)) return job;
    return this.prisma.importJob.update({ where: { id }, data: { status: 'CANCELLED', revision: { increment: 1 } } });
  }
}
