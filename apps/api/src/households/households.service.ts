import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { createHash, randomBytes } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { HouseholdAccessService } from './household-access.service';
import { ActivityService } from '../activity/activity.service';

@Injectable()
export class HouseholdsService {
  constructor(private readonly prisma: PrismaService, private readonly access: HouseholdAccessService, private readonly activity: ActivityService) {}

  async list(accountId: string) {
    return this.prisma.householdMembership.findMany({
      where: { accountId, status: 'ACTIVE' },
      include: { household: true },
      orderBy: { joinedAt: 'asc' },
    });
  }

  async join(accountId: string, rawCode: string) {
    const code = await this.prisma.householdInviteCode.findUnique({ where: { codeHash: this.hash(rawCode) } });
    if (!code) throw new NotFoundException('That household code is invalid. Ask a member for the current code.');
    const household = await this.prisma.household.findUnique({ where: { id: code.householdId } });
    if (!household) throw new NotFoundException('That household no longer exists.');
    const membership = await this.prisma.householdMembership.upsert({
      where: { householdId_accountId: { householdId: household.id, accountId } },
      create: { householdId: household.id, accountId },
      update: { status: 'ACTIVE', leftAt: null },
    });
    await this.record(household.id, accountId, 'household_membership', membership.id, 'household.joined', { householdName: household.name });
    return { household, membership };
  }

  async rotateCode(accountId: string, householdId: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    const rawCode = this.newCode();
    await this.prisma.$transaction([
      this.prisma.householdInviteCode.deleteMany({ where: { householdId } }),
      this.prisma.householdInviteCode.create({
        data: { householdId, codeHash: this.hash(rawCode), rotatedByAccountId: accountId, rotatedAt: new Date() },
      }),
    ]);
    await this.record(householdId, accountId, 'household_invite_code', householdId, 'household.invite_code_rotated', {});
    return { code: rawCode };
  }

  async leave(accountId: string, householdId: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    await this.prisma.householdMembership.update({
      where: { householdId_accountId: { householdId, accountId } },
      data: { status: 'LEFT', leftAt: new Date() },
    });
    await this.record(householdId, accountId, 'household_membership', `${householdId}:${accountId}`, 'household.left', {});
  }

  async members(accountId: string, householdId: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    return this.prisma.householdMembership.findMany({
      where: { householdId, status: 'ACTIVE' },
      include: { account: { select: { id: true, email: true, displayName: true } } },
      orderBy: { joinedAt: 'asc' },
    });
  }

  private hash(value: string) {
    return createHash('sha256').update(value.trim()).digest('base64url');
  }

  private newCode() {
    return randomBytes(12).toString('base64url');
  }

  private async record(householdId: string, accountId: string, entityType: string, entityId: string, action: string, summary: Record<string, unknown>) {
    const account = await this.prisma.account.findUniqueOrThrow({ where: { id: accountId }, select: { displayName: true } });
    await this.activity.record(householdId, { accountId, displayName: account.displayName }, entityType, entityId, action, summary);
  }
}
