import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { FcmPushService } from './fcm-push.service';

describe('FcmPushService', () => {
  it('does not query subscriptions or initialize Firebase until delivery is enabled', async () => {
    const prisma = {
      pushSubscription: { findMany: jest.fn() },
    };
    const config = { get: jest.fn().mockReturnValue(undefined) };
    const service = new FcmPushService(
      prisma as unknown as PrismaService,
      config as unknown as ConfigService,
    );

    await expect(
      service.deliverToAccounts(['account-1'], {
        title: 'Trip confirmed',
        body: 'The shopping list is ready.',
        deepLink: '/shop/trip-1',
      }),
    ).resolves.toEqual({ delivered: 0 });
    expect(prisma.pushSubscription.findMany).not.toHaveBeenCalled();
  });
});
