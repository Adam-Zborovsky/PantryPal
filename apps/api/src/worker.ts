import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { Worker } from 'bullmq';
import { AppModule } from './app.module';
import { ImportProcessorService } from './imports/import-processor.service';
import { importQueueName } from './imports/import-queue.service';
import { ArchiveService } from './archive/archive.service';
import { IngredientProfileService } from './ingredients/ingredient-profile.service';
import {
  IngredientProfileJob,
  ingredientProfileQueueName,
} from './ingredients/ingredient-profile-queue.service';

async function bootstrap() {
  const logger = new Logger('Worker');
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn', 'log'],
  });
  const processor = app.get(ImportProcessorService);
  const archive = app.get(ArchiveService);
  const worker = new Worker<{ importJobId: string }>(
    importQueueName,
    async (job) => processor.process(job.data.importJobId),
    {
      connection: { url: process.env.REDIS_URL ?? 'redis://localhost:6379' },
      concurrency: 2,
    },
  );
  worker.on('active', (job) =>
    logger.log(`Import ${job.data.importJobId} started.`),
  );
  worker.on('error', (error) =>
    logger.error(`Import queue error: ${error.message}`),
  );
  worker.on('failed', (job, error) =>
    logger.error(
      `Import ${job?.data.importJobId ?? 'unknown'} failed: ${error.message}`,
    ),
  );
  const profiles = app.get(IngredientProfileService);
  if (!profiles.isEnabled())
    logger.log('Ingredient profiles disabled: GEMINI_API_KEY is not set.');
  const profileWorker = new Worker<IngredientProfileJob>(
    ingredientProfileQueueName,
    async (job) =>
      profiles.processBatch(
        job.id ?? 'unknown',
        job.data.canonicalIngredientIds,
        job.attemptsMade + 1 >= (job.opts.attempts ?? 1),
      ),
    {
      connection: { url: process.env.REDIS_URL ?? 'redis://localhost:6379' },
      concurrency: 1,
    },
  );
  profileWorker.on('error', (error) =>
    logger.error(`Ingredient profile queue error: ${error.message}`),
  );
  profileWorker.on('failed', (job, error) =>
    logger.error(
      `Ingredient profile batch ${job?.id ?? 'unknown'} failed: ${error.message}`,
    ),
  );
  const archivePastCooking = async () => {
    const count = await archive.catchUp();
    if (count) logger.log(`Archived ${count} past cooking instance(s).`);
  };
  await archivePastCooking();
  setInterval(
    () =>
      void archivePastCooking().catch((error: unknown) => logger.error(error)),
    15 * 60_000,
  ).unref();
  logger.log('PantryPal import worker started.');
}

void bootstrap();
