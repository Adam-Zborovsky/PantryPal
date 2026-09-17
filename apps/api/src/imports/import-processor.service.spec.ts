import { Logger } from '@nestjs/common';
import { ImportProcessorService } from './import-processor.service';

describe('ImportProcessorService webpage fetch failures', () => {
  const job = {
    id: 'job-1',
    householdId: 'household-1',
    status: 'QUEUED',
    sourceKind: 'url',
    sourceInput: 'https://recipes.example/pasta',
    canonicalUrl: 'https://recipes.example/pasta',
  };
  type FailureUpdate = { data: { status: string; errorCode?: string } };
  let updateMany: jest.Mock<Promise<{ count: number }>, [FailureUpdate]>;
  let warn: jest.SpyInstance;
  let processor: ImportProcessorService;

  beforeEach(() => {
    updateMany = jest
      .fn<Promise<{ count: number }>, [FailureUpdate]>()
      .mockResolvedValue({ count: 1 });
    const prisma = {
      importJob: {
        findUnique: jest.fn().mockResolvedValue(job),
        updateMany,
      },
    };
    processor = new ImportProcessorService(
      prisma as never,
      {} as never,
      {} as never,
      { supports: () => false } as never,
      { assertPublicUrl: jest.fn().mockResolvedValue(undefined) } as never,
      { platform: () => undefined } as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );
    warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation();
  });
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
    jest.restoreAllMocks();
  });

  const respondWith = (
    status: number,
    headers: Record<string, string> = {},
  ) => {
    global.fetch = jest
      .fn<Promise<Response>, []>()
      .mockResolvedValue(new Response('', { status, headers }));
  };

  const failure = () =>
    updateMany.mock.calls
      .map(([args]) => args.data)
      .find((data) => data.status === 'FAILED');

  it.each([401, 402, 403, 429])(
    'marks HTTP %s as a site that blocks automatic imports',
    async (status) => {
      respondWith(status);
      await processor.process(job.id);
      expect(failure()).toMatchObject({ errorCode: 'SOURCE_BLOCKED' });
    },
  );

  it.each([404, 410])('marks HTTP %s as a removed page', async (status) => {
    respondWith(status);
    await processor.process(job.id);
    expect(failure()).toMatchObject({ errorCode: 'SOURCE_REMOVED' });
  });

  it('keeps server errors as temporarily unavailable', async () => {
    respondWith(503);
    await processor.process(job.id);
    expect(failure()).toMatchObject({ errorCode: 'SOURCE_UNAVAILABLE' });
  });

  it('marks redirects as unsupported links', async () => {
    respondWith(301, { location: 'https://recipes.example/other' });
    await processor.process(job.id);
    expect(failure()).toMatchObject({ errorCode: 'SOURCE_UNSUPPORTED' });
  });

  it('logs the job, code, and reason when an import fails', async () => {
    respondWith(402);
    await processor.process(job.id);
    expect(warn).toHaveBeenCalledWith(
      'Import job-1 failed [SOURCE_BLOCKED]: Source returned HTTP 402.',
    );
  });
});
