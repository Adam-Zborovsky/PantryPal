import { ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class HouseholdAccessService {
  constructor(private readonly prisma: PrismaService) {}

  async requireActiveMembership(accountId: string, householdId: string) {
    const membership = await this.prisma.householdMembership.findUnique({
      where: { householdId_accountId: { householdId, accountId } },
    });
    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenException('You are not an active member of this household.');
    }
    return membership;
  }
}
