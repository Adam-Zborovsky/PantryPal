import { PrismaService } from '../prisma/prisma.service';
import { PushSubscriptionsService } from './push-subscriptions.service';

describe('PushSubscriptionsService', () => {
  it('binds an Android FCM token to the authenticated account', async () => {
    const prisma = {
      pushSubscription: { upsert: jest.fn().mockResolvedValue(undefined) },
    };
    const service = new PushSubscriptionsService(
      prisma as unknown as PrismaService,
    );

    await expect(
      service.upsert('account-1', { platform: 'android', endpoint: 'token-1' }),
    ).resolves.toEqual({ registered: true });

    expect(prisma.pushSubscription.upsert).toHaveBeenCalledWith({
      where: { endpoint: 'token-1' },
      create: {
        accountId: 'account-1',
        platform: 'android',
        endpoint: 'token-1',
        keys: { provider: 'fcm' },
      },
      update: {
        accountId: 'account-1',
        platform: 'android',
        keys: { provider: 'fcm' },
      },
    });
  });

  it('only removes the current account subscription', async () => {
    const prisma = {
      pushSubscription: { deleteMany: jest.fn().mockResolvedValue({ count: 1 }) },
    };
    const service = new PushSubscriptionsService(
      prisma as unknown as PrismaService,
    );

    await expect(service.remove('account-1', 'token-1')).resolves.toEqual({
      removed: true,
    });
    expect(prisma.pushSubscription.deleteMany).toHaveBeenCalledWith({
      where: { accountId: 'account-1', endpoint: 'token-1' },
    });
  });
});
