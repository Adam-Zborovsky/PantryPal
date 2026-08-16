import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Queue } from 'bullmq';

export const importQueueName = 'recipe-imports';

@Injectable()
export class ImportQueueService implements OnModuleDestroy {
  private queue?: Queue<{ importJobId: string }>;

  enqueue(importJobId: string) {
    if (process.env.NODE_ENV === 'test') return Promise.resolve();
    return this.getQueue().add('process-import', { importJobId }, {
      jobId: importJobId,
      attempts: 3,
      backoff: { type: 'exponential', delay: 1_000 },
      removeOnComplete: 100,
      removeOnFail: 500,
    });
  }

  onModuleDestroy() {
    return this.queue?.close();
  }

  private getQueue() {
    return this.queue ??= new Queue<{ importJobId: string }>(importQueueName, {
      connection: { url: process.env.REDIS_URL ?? 'redis://localhost:6379' },
    });
  }
}
