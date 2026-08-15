import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Queue } from 'bullmq';

export const importQueueName = 'recipe-imports';

@Injectable()
export class ImportQueueService implements OnModuleDestroy {
  private readonly queue = new Queue<{ importJobId: string }>(importQueueName, {
    connection: { url: process.env.REDIS_URL ?? 'redis://localhost:6379' },
  });

  enqueue(importJobId: string) {
    return this.queue.add('process-import', { importJobId }, {
      jobId: importJobId,
      attempts: 3,
      backoff: { type: 'exponential', delay: 1_000 },
      removeOnComplete: 100,
      removeOnFail: 500,
    });
  }

  onModuleDestroy() {
    return this.queue.close();
  }
}
