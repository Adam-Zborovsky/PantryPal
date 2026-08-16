import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { Prisma } from '@prisma/client';
import { ForbiddenException } from '@nestjs/common';

export interface ActivityActor {
  accountId: string;
  displayName: string;
}

@Injectable()
export class ActivityService {
  constructor(private readonly prisma: PrismaService, private readonly realtime: RealtimeGateway) {}

  async record(householdId: string, actor: ActivityActor, entityType: string, entityId: string, action: string, summary: Record<string, unknown>) {
    const event = await this.prisma.activityEvent.create({
      data: { householdId, actorAccountId: actor.accountId, actorDisplayName: actor.displayName, entityType, entityId, action, summary: summary as Prisma.InputJsonValue },
    });
    this.realtime.publish(householdId, 'household.activity.created', {
      householdId, entityId: event.id, revision: 1, actor, occurredAt: event.createdAt.toISOString(), action,
    });
    return event;
  }

  async list(householdId: string, accountId: string, limit: number) {
    const membership = await this.prisma.householdMembership.findUnique({ where: { householdId_accountId: { householdId, accountId } } });
    if (!membership || membership.status !== 'ACTIVE') throw new ForbiddenException('You are not an active member of this household.');
    return this.prisma.activityEvent.findMany({ where: { householdId }, orderBy: { createdAt: 'desc' }, take: Math.min(Math.max(limit, 1), 100) });
  }
}
