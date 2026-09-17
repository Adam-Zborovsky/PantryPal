import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Queue } from 'bullmq';
import { createHash } from 'node:crypto';

export const ingredientProfileQueueName = 'ingredient-profiles';
export type IngredientProfileJob = { canonicalIngredientIds: string[] };

const MAX_JOB_ID_LENGTH = 200;

/**
 * Deterministic job id for a set of canonical ingredients, so an identical
 * pending batch is not enqueued twice. BullMQ rejects custom ids containing a
 * single ':', so the prefix uses '-'.
 */
export function profileJobId(canonicalIngredientIds: string[]) {
  const id = `profiles-${[...canonicalIngredientIds].sort().join(',')}`;
  return id.length > MAX_JOB_ID_LENGTH
    ? `profiles-${createHash('sha1').update(id).digest('hex')}`
    : id;
}

@Injectable()
export class IngredientProfileQueueService implements OnModuleDestroy {
  private queue?: Queue<IngredientProfileJob>;

  enqueue(canonicalIngredientIds: string[]) {
    if (process.env.NODE_ENV === 'test' || !canonicalIngredientIds.length)
      return Promise.resolve();
    return this.getQueue().add(
      'profile-ingredients',
      { canonicalIngredientIds },
      {
        jobId: profileJobId(canonicalIngredientIds),
        attempts: 3,
        backoff: { type: 'exponential', delay: 5_000 },
        removeOnComplete: true,
        removeOnFail: true,
      },
    );
  }

  onModuleDestroy() {
    return this.queue?.close();
  }

  private getQueue() {
    return (this.queue ??= new Queue<IngredientProfileJob>(
      ingredientProfileQueueName,
      {
        connection: { url: process.env.REDIS_URL ?? 'redis://localhost:6379' },
      },
    ));
  }
}
