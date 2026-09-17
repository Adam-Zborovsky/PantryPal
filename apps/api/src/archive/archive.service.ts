import { Injectable } from '@nestjs/common';
import { HouseholdAccessService } from '../households/household-access.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ArchiveService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: HouseholdAccessService,
  ) {}

  async list(accountId: string, householdId: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    const instances = await this.prisma.cookingInstance.findMany({
      where: { householdId, status: 'ARCHIVED' },
      orderBy: { archivedAt: 'desc' },
    });
    return instances.map((instance) => ({
      id: instance.id,
      recipeId: instance.recipeId,
      recipeVersionId: instance.recipeVersionId,
      recipeSnapshot: instance.recipeSnapshot,
      scaledIngredients: instance.scaledIngredients,
      targetServings: instance.targetServings.toString(),
      cookingDate: instance.cookingDate?.toISOString() ?? null,
      archivedAt: instance.archivedAt?.toISOString() ?? null,
      archiveCoverKey: instance.archiveCoverKey,
      revision: instance.revision,
    }));
  }

  async catchUp(now = new Date()) {
    const result = await this.prisma.cookingInstance.updateMany({
      where: {
        status: 'SCHEDULED',
        cookingDate: { lt: now },
      },
      data: {
        status: 'ARCHIVED',
        archivedAt: now,
        revision: { increment: 1 },
      },
    });
    return result.count;
  }
}
