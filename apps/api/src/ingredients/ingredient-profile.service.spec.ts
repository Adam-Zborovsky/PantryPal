import { Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  IngredientProfileGenerator,
  IngredientProfileProviderError,
} from './ingredient-profile.generator';
import { IngredientProfileQueueService } from './ingredient-profile-queue.service';
import { IngredientProfileService } from './ingredient-profile.service';

describe('IngredientProfileService', () => {
  let prisma: {
    canonicalIngredient: {
      createMany: jest.Mock;
      findMany: jest.Mock;
      updateMany: jest.Mock;
      update: jest.Mock;
    };
  };
  let queue: { enqueue: jest.Mock };
  let generator: {
    isEnabled: jest.Mock;
    model: jest.Mock;
    generate: jest.Mock;
  };
  let service: IngredientProfileService;

  beforeEach(() => {
    prisma = {
      canonicalIngredient: {
        createMany: jest.fn().mockResolvedValue({ count: 0 }),
        findMany: jest.fn(),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    queue = { enqueue: jest.fn().mockResolvedValue(undefined) };
    generator = {
      isEnabled: jest.fn().mockReturnValue(true),
      model: jest.fn().mockReturnValue('gemini-3.6-flash'),
      generate: jest.fn(),
    };
    service = new IngredientProfileService(
      prisma as unknown as PrismaService,
      queue as unknown as IngredientProfileQueueService,
      generator as unknown as IngredientProfileGenerator,
    );
    jest.spyOn(Logger.prototype, 'warn').mockImplementation();
    jest.spyOn(Logger.prototype, 'log').mockImplementation();
  });
  afterEach(() => jest.restoreAllMocks());

  it('resolves normalized unique names with sorted createMany and findMany', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([
      { id: 'ci-olive oil', canonicalName: 'olive oil' },
      { id: 'ci-tomato', canonicalName: 'tomato' },
    ]);
    const result = await service.resolveIngredients([
      'Tomatoes',
      'tomato',
      ' ',
      'Olive Oil',
    ]);
    expect(prisma.canonicalIngredient.createMany).toHaveBeenCalledWith({
      data: [{ canonicalName: 'olive oil' }, { canonicalName: 'tomato' }],
      skipDuplicates: true,
    });
    expect(prisma.canonicalIngredient.findMany).toHaveBeenCalledWith({
      where: { canonicalName: { in: ['olive oil', 'tomato'] } },
      select: { id: true, canonicalName: true },
    });
    expect([...result.entries()]).toEqual([
      ['olive oil', 'ci-olive oil'],
      ['tomato', 'ci-tomato'],
    ]);
  });

  it('skips queries when there is no name to resolve', async () => {
    const result = await service.resolveIngredients([' ', '']);
    expect(result.size).toBe(0);
    expect(prisma.canonicalIngredient.createMany).not.toHaveBeenCalled();
    expect(prisma.canonicalIngredient.findMany).not.toHaveBeenCalled();
  });

  it('enqueues pending rows and failed rows past the cooldown, resetting only those failed rows', async () => {
    jest.useFakeTimers({ now: new Date('2026-09-17T12:00:00.000Z') });
    try {
      prisma.canonicalIngredient.findMany.mockResolvedValue([
        { id: 'a', profileStatus: 'PENDING' },
        { id: 'c', profileStatus: 'FAILED' },
      ]);
      await service.requestProfiles(['a', 'b', 'c']);
      const cutoff = new Date('2026-09-16T12:00:00.000Z');
      expect(prisma.canonicalIngredient.findMany).toHaveBeenCalledWith({
        where: {
          id: { in: ['a', 'b', 'c'] },
          OR: [
            { profileStatus: 'PENDING' },
            { profileStatus: 'FAILED', updatedAt: { lt: cutoff } },
          ],
        },
        select: { id: true, profileStatus: true },
      });
      expect(prisma.canonicalIngredient.updateMany).toHaveBeenCalledWith({
        where: { id: { in: ['c'] }, profileStatus: 'FAILED' },
        data: { profileStatus: 'PENDING' },
      });
      expect(queue.enqueue).toHaveBeenCalledWith(['a', 'c']);
    } finally {
      jest.useRealTimers();
    }
  });

  it('does not re-request a failed row still inside the cooldown', async () => {
    // The database filter excludes young FAILED rows, so only the pending row comes back.
    prisma.canonicalIngredient.findMany.mockResolvedValue([
      { id: 'a', profileStatus: 'PENDING' },
    ]);
    await service.requestProfiles(['a', 'young-failed']);
    expect(prisma.canonicalIngredient.updateMany).not.toHaveBeenCalled();
    expect(queue.enqueue).toHaveBeenCalledTimes(1);
    expect(queue.enqueue).toHaveBeenCalledWith(['a']);
  });

  it('chunks requested ids into batches of 25', async () => {
    const ids = Array.from({ length: 30 }, (_, index) => `id-${index}`);
    prisma.canonicalIngredient.findMany.mockResolvedValue(
      ids.map((id) => ({ id, profileStatus: 'PENDING' })),
    );
    await service.requestProfiles(ids);
    expect(queue.enqueue).toHaveBeenCalledTimes(2);
    expect(queue.enqueue).toHaveBeenNthCalledWith(1, ids.slice(0, 25));
    expect(queue.enqueue).toHaveBeenNthCalledWith(2, ids.slice(25));
  });

  it('does nothing when profiles are disabled', async () => {
    generator.isEnabled.mockReturnValue(false);
    await service.requestProfiles(['a']);
    expect(queue.enqueue).not.toHaveBeenCalled();
  });

  it('never throws when enqueueing fails', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([
      { id: 'a', profileStatus: 'PENDING' },
    ]);
    queue.enqueue.mockRejectedValue(new Error('redis down'));
    await expect(service.requestProfiles(['a'])).resolves.toBeUndefined();
  });

  it('stores ready profiles and fails rejected names', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([
      { id: 'ci-flour', canonicalName: 'flour' },
      { id: 'ci-salt', canonicalName: 'salt' },
    ]);
    generator.generate.mockResolvedValue({
      profiles: [
        {
          name: 'flour',
          dimension: 'MASS',
          shoppingUnit: 'g',
          unitEstimates: { ml: '0.53' },
          packageSizes: ['1000'],
        },
      ],
      rejected: [{ name: 'salt', reason: 'missing from response' }],
    });
    await service.processBatch('job-1', ['ci-flour', 'ci-salt'], false);
    const updateMock = prisma.canonicalIngredient.update as jest.Mock<
      Promise<unknown>,
      [{ where: { id: string }; data: Record<string, unknown> }]
    >;
    expect(updateMock).toHaveBeenCalledTimes(1);
    const [{ where, data }] = updateMock.mock.calls[0];
    expect(where).toEqual({ id: 'ci-flour' });
    expect(data).toMatchObject({
      profileStatus: 'READY',
      dimension: 'MASS',
      shoppingUnit: 'g',
      unitEstimates: { ml: '0.53' },
      packageSizes: ['1000'],
      profileModel: 'gemini-3.6-flash',
    });
    expect(prisma.canonicalIngredient.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['ci-salt'] } },
      data: { profileStatus: 'FAILED' },
    });
  });

  it('skips work when no requested row is still pending', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([]);
    await service.processBatch('job-1', ['x'], false);
    expect(generator.generate).not.toHaveBeenCalled();
  });

  it('rethrows retryable errors before the final attempt', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([
      { id: 'a', canonicalName: 'flour' },
    ]);
    generator.generate.mockRejectedValue(
      new IngredientProfileProviderError(true, 'HTTP 503'),
    );
    await expect(service.processBatch('job-1', ['a'], false)).rejects.toThrow(
      'HTTP 503',
    );
  });

  it('fails rows without throwing when a retryable error hits the final attempt', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([
      { id: 'a', canonicalName: 'flour' },
    ]);
    generator.generate.mockRejectedValue(
      new IngredientProfileProviderError(true, 'HTTP 503'),
    );
    await expect(
      service.processBatch('job-1', ['a'], true),
    ).resolves.toBeUndefined();
    expect(prisma.canonicalIngredient.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['a'] } },
      data: { profileStatus: 'FAILED' },
    });
  });

  it('fails rows on the final attempt or a non-retryable error', async () => {
    prisma.canonicalIngredient.findMany.mockResolvedValue([
      { id: 'a', canonicalName: 'flour' },
    ]);
    generator.generate.mockRejectedValue(
      new IngredientProfileProviderError(false, 'HTTP 404'),
    );
    await service.processBatch('job-1', ['a'], false);
    expect(prisma.canonicalIngredient.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['a'] } },
      data: { profileStatus: 'FAILED' },
    });
  });
});
