import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpsertPushSubscriptionDto } from './push-subscriptions.dto';

@Injectable()
export class PushSubscriptionsService {
  constructor(private readonly prisma: PrismaService) {}

  async upsert(accountId: string, input: UpsertPushSubscriptionDto) {
    await this.prisma.pushSubscription.upsert({
      where: { endpoint: input.endpoint },
      create: {
        accountId,
        platform: input.platform,
        endpoint: input.endpoint,
        keys: { provider: 'fcm' } as Prisma.InputJsonValue,
      },
      update: {
        accountId,
        platform: input.platform,
        keys: { provider: 'fcm' } as Prisma.InputJsonValue,
      },
    });
    return { registered: true };
  }

  async remove(accountId: string, endpoint: string) {
    await this.prisma.pushSubscription.deleteMany({
      where: { accountId, endpoint },
    });
    return { removed: true };
  }
}
