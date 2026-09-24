import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, RecipeReadiness } from '@prisma/client';
import { ActivityService } from '../activity/activity.service';
import { HouseholdAccessService } from '../households/household-access.service';
import { IngredientProfileService } from '../ingredients/ingredient-profile.service';
import { PrismaService } from '../prisma/prisma.service';
import { normalizeIngredientName, parseUnit } from './units';
import { CreateRecipeDto, RecipeInputDto, SaveRecipeReviewDto } from './recipes.dto';

type ReviewIngredient = {
  name: string;
  quantityMin: string | null;
  quantityMax: string | null;
  originalUnit: string | null;
  preparationNote: string | null;
  classification: 'REQUIRED' | 'FLEXIBLE' | 'PANTRY_STAPLE' | 'GARNISH';
  includeInShopping: boolean;
};

@Injectable()
export class RecipesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: HouseholdAccessService,
    private readonly activity: ActivityService,
    private readonly ingredients: IngredientProfileService,
  ) {}

  async list(accountId: string, householdId: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    const recipes = await this.prisma.recipe.findMany({
      where: { householdId, deletedAt: null },
      orderBy: { updatedAt: 'desc' },
    });
    return recipes.map((recipe) => ({
      id: recipe.id,
      title: recipe.title,
      readiness: recipe.readiness,
      revision: recipe.revision,
      currentVersionId: recipe.currentVersionId,
      updatedAt: recipe.updatedAt.toISOString(),
    }));
  }

  async create(
    accountId: string,
    householdId: string,
    input: CreateRecipeDto,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    this.assertDecimalInput(input);
    const normalized = input.ingredients.map((item) =>
      this.normalizeIngredient(item),
    );
    const canonicalIds = await this.ingredients.resolveIngredients(
      normalized.map((item) => item.name),
    );
    const readiness = this.readiness(
      input.title,
      input.originalServings ?? null,
      normalized,
      input.instructions,
    );
    const recipe = await this.prisma.$transaction(async (tx) => {
      const recipe = await tx.recipe.create({
        data: { householdId, title: input.title.trim(), readiness },
      });
      const version = await tx.recipeVersion.create({
        data: {
          householdId,
          recipeId: recipe.id,
          version: 1,
          title: input.title.trim(),
          originalServings: this.decimalOrNull(input.originalServings),
          yieldWording: this.emptyToNull(input.yieldWording),
          readiness,
          snapshot: {
            manualFields: [
              'recipe.title',
              'recipe.originalServings',
              ...normalized.flatMap((_, index) => [
                `ingredients[${index}].name`,
                `ingredients[${index}].amount`,
              ]),
              'instructions',
            ],
          } as Prisma.InputJsonValue,
          createdByAccountId: accountId,
        },
      });
      await tx.recipeIngredient.createMany({
        data: normalized.map((item, sortOrder) => ({
          householdId,
          recipeVersionId: version.id,
          name: item.name,
          canonicalIngredientId:
            canonicalIds.get(normalizeIngredientName(item.name)) ?? null,
          normalizedUnit: item.originalUnit?.trim()
            ? parseUnit(item.originalUnit).token
            : null,
          quantityMin: this.decimalOrNull(item.quantityMin),
          quantityMax: this.decimalOrNull(item.quantityMax),
          originalUnit: this.emptyToNull(item.originalUnit),
          preparationNote: this.emptyToNull(item.preparationNote),
          originalText: this.ingredientText(item),
          classification: item.classification,
          includeInShopping: item.includeInShopping,
          inferred: false,
          sortOrder,
        })),
      });
      await tx.recipeInstruction.createMany({
        data: input.instructions
            .map((body, sortOrder) => ({
              householdId,
              recipeVersionId: version.id,
              body: body.trim(),
              sortOrder,
            }))
            .filter((item) => item.body),
      });
      return tx.recipe.update({
        where: { id: recipe.id },
        data: { currentVersionId: version.id },
      });
    });
    void this.ingredients.requestProfiles([...new Set(canonicalIds.values())]);
    const account = await this.prisma.account.findUniqueOrThrow({
      where: { id: accountId },
      select: { displayName: true },
    });
    await this.activity.record(
      householdId,
      { accountId, displayName: account.displayName },
      'recipe',
      recipe.id,
      'recipe.created',
      { readiness },
    );
    return this.review(accountId, householdId, recipe.id);
  }

  async review(accountId: string, householdId: string, recipeId: string) {
    await this.access.requireActiveMembership(accountId, householdId);
    const recipe = await this.prisma.recipe.findFirst({
      where: { id: recipeId, householdId, deletedAt: null },
    });
    if (!recipe || !recipe.currentVersionId)
      throw new NotFoundException('Recipe not found in this household.');
    const version = await this.prisma.recipeVersion.findFirst({
      where: { id: recipe.currentVersionId, householdId },
    });
    if (!version)
      throw new NotFoundException('Recipe review draft is unavailable.');
    const [ingredients, instructions, importJob, sources] = await Promise.all([
      this.prisma.recipeIngredient.findMany({
        where: { householdId, recipeVersionId: version.id },
        orderBy: { sortOrder: 'asc' },
      }),
      this.prisma.recipeInstruction.findMany({
        where: { householdId, recipeVersionId: version.id },
        orderBy: { sortOrder: 'asc' },
      }),
      this.prisma.importJob.findFirst({
        where: { householdId, recipeId },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.recipeSource.findMany({
        where: { householdId, recipeId },
        orderBy: { createdAt: 'asc' },
        take: 1,
      }),
    ]);
    const evidence = importJob
      ? await this.prisma.extractionEvidence.findMany({
          where: { householdId, importJobId: importJob.id },
          orderBy: { createdAt: 'asc' },
        })
      : [];
    const normalizedIngredients = ingredients.map((item) => ({
      id: item.id,
      name: item.name,
      quantityMin: item.quantityMin?.toString() ?? null,
      quantityMax: item.quantityMax?.toString() ?? null,
      originalUnit: item.originalUnit,
      preparationNote: item.preparationNote,
      classification: item.classification,
      includeInShopping: item.includeInShopping,
      originalText: item.originalText,
      inferred: item.inferred,
    }));
    const manualFields = this.manualFields(version.snapshot);
    return {
      recipe: {
        id: recipe.id,
        title: recipe.title,
        readiness: recipe.readiness,
        revision: recipe.revision,
      },
      version: {
        id: version.id,
        number: version.version,
        title: version.title,
        originalServings: version.originalServings?.toString() ?? null,
        yieldWording: version.yieldWording,
      },
      source: sources[0]
        ? {
            canonicalUrl: sources[0].canonicalUrl,
            attribution: sources[0].attribution,
          }
        : null,
      ingredients: normalizedIngredients,
      instructions: instructions.map((item) => item.body),
      evidence: evidence.map((item) => ({
        fieldPath: item.fieldPath,
        origin: item.origin,
        excerpt: item.excerpt,
        timestampMs: item.timestampMs,
        frameIndex: item.frameIndex,
        confidence: item.confidence?.toString() ?? null,
      })),
      completeness: this.completeness({
        title: version.title,
        servings: version.originalServings?.toString() ?? null,
        sourceAvailable: sources.length > 0,
        ingredients: normalizedIngredients,
        instructions: instructions.map((item) => item.body),
        manualFields,
      }),
    };
  }

  async saveReview(
    accountId: string,
    householdId: string,
    recipeId: string,
    input: SaveRecipeReviewDto,
  ) {
    await this.access.requireActiveMembership(accountId, householdId);
    this.assertDecimalInput(input);
    const canonicalIds = await this.ingredients.resolveIngredients(
      input.ingredients.map((item) => item.name),
    );
    const result = await this.prisma.$transaction(async (tx) => {
      const recipe = await tx.recipe.findFirst({
        where: { id: recipeId, householdId, deletedAt: null },
      });
      if (!recipe || !recipe.currentVersionId)
        throw new NotFoundException('Recipe not found in this household.');
      if (recipe.revision.toString() !== input.expectedRevision) {
        throw new ConflictException(
          'This recipe changed elsewhere. Refresh the review before saving.',
        );
      }
      const previous = await tx.recipeVersion.findUniqueOrThrow({
        where: { id: recipe.currentVersionId },
      });
      const previousIngredients = await tx.recipeIngredient.findMany({
        where: { recipeVersionId: previous.id },
        orderBy: { sortOrder: 'asc' },
      });
      const normalized = input.ingredients.map((item) =>
        this.normalizeIngredient(item),
      );
      const manualFields = this.changedFields(
        previous,
        previousIngredients,
        input,
        normalized,
      );
      const readiness = this.readiness(
        input.title,
        input.originalServings ?? null,
        normalized,
        input.instructions,
      );
      const version = await tx.recipeVersion.create({
        data: {
          householdId,
          recipeId,
          version: previous.version + 1,
          title: input.title.trim(),
          originalServings: this.decimalOrNull(input.originalServings),
          yieldWording: this.emptyToNull(input.yieldWording),
          readiness,
          snapshot: { manualFields } as Prisma.InputJsonValue,
          createdByAccountId: accountId,
        },
      });
      await tx.recipeIngredient.createMany({
        data: normalized.map((item, sortOrder) => ({
          householdId,
          recipeVersionId: version.id,
          name: item.name,
          canonicalIngredientId:
            canonicalIds.get(normalizeIngredientName(item.name)) ?? null,
          normalizedUnit: item.originalUnit?.trim()
            ? parseUnit(item.originalUnit).token
            : null,
          quantityMin: this.decimalOrNull(item.quantityMin),
          quantityMax: this.decimalOrNull(item.quantityMax),
          originalUnit: this.emptyToNull(item.originalUnit),
          preparationNote: this.emptyToNull(item.preparationNote),
          originalText: this.ingredientText(item),
          classification: item.classification,
          includeInShopping: item.includeInShopping,
          inferred: false,
          sortOrder,
        })),
      });
      await tx.recipeInstruction.createMany({
        data: input.instructions
          .map((body, sortOrder) => ({
            householdId,
            recipeVersionId: version.id,
            body: body.trim(),
            sortOrder,
          }))
          .filter((item) => item.body),
      });
      const updated = await tx.recipe.update({
        where: { id: recipeId },
        data: {
          title: input.title.trim(),
          readiness,
          currentVersionId: version.id,
          revision: { increment: 1 },
        },
      });
      return { updated, readiness };
    });
    void this.ingredients.requestProfiles([...new Set(canonicalIds.values())]);
    const account = await this.prisma.account.findUniqueOrThrow({
      where: { id: accountId },
      select: { displayName: true },
    });
    await this.activity.record(
      householdId,
      { accountId, displayName: account.displayName },
      'recipe',
      recipeId,
      'recipe.reviewed',
      { readiness: result.readiness },
    );
    return this.review(accountId, householdId, recipeId);
  }

  private completeness(input: {
    title: string;
    servings: string | null;
    sourceAvailable: boolean;
    ingredients: Array<ReviewIngredient>;
    instructions: string[];
    manualFields: Set<string>;
  }) {
    let extracted = 0;
    let manual = 0;
    let missing = 0;
    const add = (path: string, present: boolean, weight: number) => {
      if (!present) missing += weight;
      else if (input.manualFields.has(path)) manual += weight;
      else extracted += weight;
    };
    add(
      'recipe.title',
      input.title.trim().length > 0 && input.sourceAvailable,
      5,
    );
    add('recipe.originalServings', this.isPositiveDecimal(input.servings), 20);
    const requiredWeight = 65.0;
    const required = input.ingredients
      .map((item, index) => ({ item, index }))
      .filter(
        ({ item }) =>
          item.classification === 'REQUIRED' && item.includeInShopping,
      );
    if (required.length === 0) {
      missing += requiredWeight;
    } else {
      for (var index = 0; index < required.length; index += 1) {
        const { item: ingredient, index: ingredientIndex } = required[index];
        add(
          `ingredients[${ingredientIndex}].name`,
          ingredient.name.trim().length > 0,
          25 / required.length,
        );
        add(
          `ingredients[${ingredientIndex}].amount`,
          this.isPositiveDecimal(ingredient.quantityMin) &&
            (ingredient.originalUnit?.trim().length ?? 0) > 0,
          40 / required.length,
        );
      }
    }
    add(
      'instructions',
      input.instructions.some((body) => body.trim().length > 0),
      10,
    );
    return {
      extracted: Math.round(extracted),
      manual: Math.round(manual),
      missing: Math.round(missing),
    };
  }

  private readiness(
    title: string,
    servings: string | null,
    ingredients: ReviewIngredient[],
    instructions: string[],
  ) {
    const hasCookBasics =
      title.trim().length > 0 &&
      ingredients.length > 0 &&
      instructions.some((item) => item.trim().length > 0);
    const required = ingredients.filter(
      (item) => item.classification === 'REQUIRED' && item.includeInShopping,
    );
    const shoppingReady =
      this.isPositiveDecimal(servings) &&
      required.length > 0 &&
      required.every(
        (item) =>
          this.isPositiveDecimal(item.quantityMin) &&
          (item.originalUnit?.trim().length ?? 0) > 0,
      );
    if (shoppingReady) return RecipeReadiness.SHOPPING_READY;
    return hasCookBasics
      ? RecipeReadiness.COOK_READY
      : RecipeReadiness.NEEDS_REVIEW;
  }

  private changedFields(
    previous: {
      title: string;
      originalServings: Prisma.Decimal | null;
      snapshot: Prisma.JsonValue;
    },
    previousIngredients: Array<{
      name: string;
      quantityMin: Prisma.Decimal | null;
      originalUnit: string | null;
    }>,
    input: SaveRecipeReviewDto,
    ingredients: ReviewIngredient[],
  ) {
    const priorManual = this.manualFields(previous.snapshot);
    const manual = new Set(priorManual);
    if (previous.title !== input.title.trim()) manual.add('recipe.title');
    if (
      (previous.originalServings?.toString() ?? null) !==
      this.emptyToNull(input.originalServings)
    )
      manual.add('recipe.originalServings');
    for (var index = 0; index < ingredients.length; index += 1) {
      const before = previousIngredients[index];
      const after = ingredients[index];
      if (!before || before.name !== after.name)
        manual.add(`ingredients[${index}].name`);
      if (
        !before ||
        before.quantityMin?.toString() !==
          this.emptyToNull(after.quantityMin) ||
        before.originalUnit !== this.emptyToNull(after.originalUnit)
      )
        manual.add(`ingredients[${index}].amount`);
    }
    return [...manual];
  }

  private manualFields(snapshot: Prisma.JsonValue) {
    if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot))
      return new Set<string>();
    const fields = (snapshot as Record<string, unknown>).manualFields;
    return new Set(
      Array.isArray(fields)
        ? fields.filter((item): item is string => typeof item === 'string')
        : [],
    );
  }

  private normalizeIngredient(
    item: RecipeInputDto['ingredients'][number],
  ): ReviewIngredient {
    return {
      name: item.name.trim(),
      quantityMin: this.emptyToNull(item.quantityMin),
      quantityMax: this.emptyToNull(item.quantityMax),
      originalUnit: this.emptyToNull(item.originalUnit),
      preparationNote: this.emptyToNull(item.preparationNote),
      classification: item.classification,
      includeInShopping: item.includeInShopping,
    };
  }

  private assertDecimalInput(input: RecipeInputDto) {
    if (
      input.originalServings != null &&
      !this.isPositiveDecimal(input.originalServings)
    ) {
      throw new BadRequestException(
        'Original servings must be a positive decimal value.',
      );
    }
    for (const ingredient of input.ingredients) {
      for (const value of [ingredient.quantityMin, ingredient.quantityMax]) {
        if (value != null && !this.isPositiveDecimal(value)) {
          throw new BadRequestException(
            'Ingredient amounts must be positive decimal values.',
          );
        }
      }
    }
  }

  private ingredientText(item: ReviewIngredient) {
    return [item.quantityMin, item.originalUnit, item.name]
      .filter((value) => value?.trim().length ?? 0)
      .join(' ');
  }

  private decimalOrNull(value: string | null | undefined) {
    const normalized = this.emptyToNull(value);
    if (!normalized) return null;
    return new Prisma.Decimal(normalized);
  }

  private isPositiveDecimal(value: string | null) {
    return (
      value != null &&
      /^\d+(?:\.\d+)?$/.test(value) &&
      new Prisma.Decimal(value).gt(0)
    );
  }

  private emptyToNull(value: string | null | undefined) {
    const trimmed = value?.trim();
    return trimmed ? trimmed : null;
  }
}
