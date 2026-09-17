import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { normalizeIngredientName } from '../recipes/units';
import {
  IngredientProfileGenerator,
  IngredientProfileProviderError,
} from './ingredient-profile.generator';
import { IngredientProfileQueueService } from './ingredient-profile-queue.service';

export const FAILED_RETRY_COOLDOWN_MS = 24 * 60 * 60 * 1000;
export const PROFILE_BATCH_SIZE = 25;

@Injectable()
export class IngredientProfileService {
  private readonly logger = new Logger(IngredientProfileService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly queue: IngredientProfileQueueService,
    private readonly generator: IngredientProfileGenerator,
  ) {}

  isEnabled() {
    return this.generator.isEnabled();
  }

  /**
   * Resolves canonical ingredient ids on the shared (non-transactional) client.
   * Rows are created in sorted order with skipDuplicates so concurrent
   * households never wait on each other's locks.
   */
  async resolveIngredients(names: string[]) {
    const resolved = new Map<string, string>();
    const canonicalNames = [
      ...new Set(names.map(normalizeIngredientName).filter(Boolean)),
    ].sort();
    if (!canonicalNames.length) return resolved;
    await this.prisma.canonicalIngredient.createMany({
      data: canonicalNames.map((canonicalName) => ({ canonicalName })),
      skipDuplicates: true,
    });
    const rows = await this.prisma.canonicalIngredient.findMany({
      where: { canonicalName: { in: canonicalNames } },
      select: { id: true, canonicalName: true },
    });
    for (const row of rows) resolved.set(row.canonicalName, row.id);
    return resolved;
  }

  /** Enqueues profile generation; never throws, so callers need not await. */
  async requestProfiles(canonicalIngredientIds: string[]) {
    if (!canonicalIngredientIds.length || !this.generator.isEnabled()) return;
    try {
      const rows = await this.prisma.canonicalIngredient.findMany({
        where: {
          id: { in: canonicalIngredientIds },
          OR: [
            { profileStatus: 'PENDING' },
            {
              profileStatus: 'FAILED',
              updatedAt: {
                lt: new Date(Date.now() - FAILED_RETRY_COOLDOWN_MS),
              },
            },
          ],
        },
        select: { id: true, profileStatus: true },
      });
      if (!rows.length) return;
      const failedIds = rows
        .filter((row) => row.profileStatus === 'FAILED')
        .map((row) => row.id);
      if (failedIds.length)
        await this.prisma.canonicalIngredient.updateMany({
          where: { id: { in: failedIds }, profileStatus: 'FAILED' },
          data: { profileStatus: 'PENDING' },
        });
      const ids = rows.map((row) => row.id);
      for (let start = 0; start < ids.length; start += PROFILE_BATCH_SIZE)
        await this.queue.enqueue(ids.slice(start, start + PROFILE_BATCH_SIZE));
    } catch (error) {
      this.logger.warn(
        `Could not request ingredient profiles: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }
  }

  async processBatch(
    jobId: string,
    canonicalIngredientIds: string[],
    finalAttempt: boolean,
  ) {
    const rows = await this.prisma.canonicalIngredient.findMany({
      where: { id: { in: canonicalIngredientIds }, profileStatus: 'PENDING' },
      select: { id: true, canonicalName: true },
    });
    if (!rows.length) return;
    let result;
    try {
      result = await this.generator.generate(
        rows.map((row) => row.canonicalName),
      );
    } catch (error) {
      const retryable =
        error instanceof IngredientProfileProviderError && error.retryable;
      if (retryable && !finalAttempt) throw error;
      await this.prisma.canonicalIngredient.updateMany({
        where: { id: { in: rows.map((row) => row.id) } },
        data: { profileStatus: 'FAILED' },
      });
      this.logger.warn(
        `Ingredient profile batch ${jobId} failed: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
      return;
    }
    const idByName = new Map(rows.map((row) => [row.canonicalName, row.id]));
    for (const profile of result.profiles) {
      const id = idByName.get(profile.name);
      if (!id) continue;
      await this.prisma.canonicalIngredient.update({
        where: { id },
        data: {
          profileStatus: 'READY',
          dimension: profile.dimension,
          shoppingUnit: profile.shoppingUnit,
          unitEstimates: profile.unitEstimates,
          packageSizes: profile.packageSizes,
          profileModel: this.generator.model(),
          profiledAt: new Date(),
        },
      });
    }
    const failedIds = result.rejected
      .map((entry) => idByName.get(entry.name))
      .filter((id): id is string => !!id);
    if (failedIds.length)
      await this.prisma.canonicalIngredient.updateMany({
        where: { id: { in: failedIds } },
        data: { profileStatus: 'FAILED' },
      });
    const reasons = result.rejected
      .map((entry) => `${entry.name}: ${entry.reason}`)
      .join(', ');
    this.logger.log(
      `Ingredient profile batch ${jobId} ready: ${result.profiles.length}, failed: ${result.rejected.length}${reasons ? ` [${reasons}]` : ''}`,
    );
  }
}
