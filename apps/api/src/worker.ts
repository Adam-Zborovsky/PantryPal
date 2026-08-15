import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { Worker } from 'bullmq';
import { AppModule } from './app.module';
import { ImportProcessorService } from './imports/import-processor.service';
import { importQueueName } from './imports/import-queue.service';

async function bootstrap() {
  const logger = new Logger('Worker');
  const app = await NestFactory.createApplicationContext(AppModule, { logger: ['error', 'warn', 'log'] });
  const processor = app.get(ImportProcessorService);
  const worker = new Worker(importQueueName, async (job) => processor.process(job.data.importJobId), { connection: { url: process.env.REDIS_URL ?? 'redis://localhost:6379' }, concurrency: 2 });
  worker.on('failed', (job, error) => logger.error(`Import ${job?.data.importJobId ?? 'unknown'} failed: ${error.message}`));
  logger.log('PantryPal import worker started.');
}

void bootstrap();
