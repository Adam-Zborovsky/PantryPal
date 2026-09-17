import { Injectable, NotFoundException } from '@nestjs/common';
import { MembershipStatus } from '@prisma/client';
import { HouseholdAccessService } from '../households/household-access.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { FcmPushService } from './fcm-push.service';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: HouseholdAccessService,
    private readonly realtime: RealtimeGateway,
    private readonly fcm: FcmPushService,
  ) {}

  async list(accountId: string, householdId: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    return this.prisma.notification.findMany({
      where: { householdId, accountId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async markRead(
    accountId: string,
    householdId: string,
    notificationId: string,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    const notification = await this.prisma.notification.findFirst({
      where: { id: notificationId, householdId, accountId },
    });
    if (!notification)
      throw new NotFoundException('Notification not found in this household.');
    return this.prisma.notification.update({
      where: { id: notification.id },
      data: { readAt: notification.readAt ?? new Date() },
    });
  }

  async notifyHouseholdExcept(input: {
    householdId: string;
    actorAccountId: string;
    dedupeKey: string;
    title: string;
    body: string;
    deepLink: string;
  }) {
    const recipients = await this.prisma.householdMembership.findMany({
      where: {
        householdId: input.householdId,
        status: MembershipStatus.ACTIVE,
        accountId: { not: input.actorAccountId },
      },
      select: { accountId: true },
    });
    if (!recipients.length) return { count: 0 };
    const recipientIds = recipients.map(({ accountId }) => accountId);
    const existing = await this.prisma.notification.findMany({
      where: {
        accountId: { in: recipientIds },
        channel: 'IN_APP',
        dedupeKey: input.dedupeKey,
      },
      select: { accountId: true },
    });
    const existingIds = new Set(existing.map(({ accountId }) => accountId));
    const newRecipientIds = recipientIds.filter(
      (accountId) => !existingIds.has(accountId),
    );
    if (!newRecipientIds.length) return { count: 0 };
    const result = await this.prisma.notification.createMany({
      data: newRecipientIds.map((accountId) => ({
        householdId: input.householdId,
        accountId,
        channel: 'IN_APP',
        dedupeKey: input.dedupeKey,
        title: input.title,
        body: input.body,
        deepLink: input.deepLink,
      })),
      skipDuplicates: true,
    });
    if (result.count) {
      this.realtime.publish(input.householdId, 'notification.created', {
        householdId: input.householdId,
        entityId: input.dedupeKey,
        revision: 1,
        actor: {
          accountId: input.actorAccountId,
          displayName: 'Household member',
        },
        occurredAt: new Date().toISOString(),
      });
      await this.fcm.deliverToAccounts(newRecipientIds, input);
    }
    return result;
  }

  async notifyAccount(input: {
    householdId: string;
    accountId: string;
    dedupeKey: string;
    title: string;
    body: string;
    deepLink: string;
  }) {
    const existing = await this.prisma.notification.findFirst({
      where: {
        accountId: input.accountId,
        channel: 'IN_APP',
        dedupeKey: input.dedupeKey,
      },
      select: { id: true },
    });
    if (existing) return { count: 0 };
    const result = await this.prisma.notification.createMany({
      data: [{ ...input, channel: 'IN_APP' }],
      skipDuplicates: true,
    });
    if (result.count) {
      this.realtime.publish(input.householdId, 'notification.created', {
        householdId: input.householdId,
        entityId: input.dedupeKey,
        revision: 1,
        actor: { accountId: input.accountId, displayName: 'Household member' },
        occurredAt: new Date().toISOString(),
      });
      await this.fcm.deliverToAccounts([input.accountId], input);
    }
    return result;
  }
}
