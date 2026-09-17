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
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async record(
    householdId: string,
    actor: ActivityActor,
    entityType: string,
    entityId: string,
    action: string,
    summary: Record<string, unknown>,
  ) {
    const event = await this.prisma.activityEvent.create({
      data: {
        householdId,
        actorAccountId: actor.accountId,
        actorDisplayName: actor.displayName,
        entityType,
        entityId,
        action,
        summary: summary as Prisma.InputJsonValue,
      },
    });
    this.realtime.publish(householdId, 'household.activity.created', {
      householdId,
      entityId: event.id,
      revision: 1,
      actor,
      occurredAt: event.createdAt.toISOString(),
      action,
      summary,
    });
    const domainEvent = this.domainEvent(action);
    if (domainEvent) {
      this.realtime.publish(householdId, domainEvent, {
        householdId,
        entityId,
        revision: this.revision(summary),
        actor,
        occurredAt: event.createdAt.toISOString(),
        action,
        summary,
      });
    }
    return event;
  }

  async list(householdId: string, accountId: string, limit: number) {
    const membership = await this.prisma.householdMembership.findUnique({
      where: { householdId_accountId: { householdId, accountId } },
    });
    if (!membership || membership.status !== 'ACTIVE')
      throw new ForbiddenException(
        'You are not an active member of this household.',
      );
    return this.prisma.activityEvent.findMany({
      where: { householdId },
      orderBy: { createdAt: 'desc' },
      take: Math.min(Math.max(limit, 1), 100),
    });
  }

  private domainEvent(action: string) {
    if (action.startsWith('cooking.')) return 'cooking.changed';
    if (action === 'cook_assignment.requested')
      return 'cook_assignment.requested';
    if (action.startsWith('cook_assignment.'))
      return 'cook_assignment.resolved';
    if (action.startsWith('trip.')) return 'trip.changed';
    if (action === 'shopping_item.changed') return 'shopping_item.changed';
    if (action === 'pantry.recheck_required') return 'pantry.recheck_required';
    return null;
  }

  private revision(summary: Record<string, unknown>) {
    return typeof summary.revision === 'number' ? summary.revision : 1;
  }
}
