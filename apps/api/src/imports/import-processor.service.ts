import { Inject, Injectable } from '@nestjs/common';
import { ImportStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RECIPE_ANALYSIS_PROVIDER } from './recipe-analysis.provider';
import type { RecipeAnalysisProvider } from './recipe-analysis.provider';
import { WebpageRecipeParserService } from './webpage-recipe-parser.service';

@Injectable()
export class ImportProcessorService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly parser: WebpageRecipeParserService,
    @Inject(RECIPE_ANALYSIS_PROVIDER) private readonly analysis: RecipeAnalysisProvider,
  ) {}

  async process(importJobId: string) {
    const job = await this.prisma.importJob.findUnique({ where: { id: importJobId } });
    if (!job || job.status === 'CANCELLED') return;
    if (job.sourceKind !== 'url' || !job.canonicalUrl) return this.fail(job.id, 'SOURCE_UNSUPPORTED', 'Only public recipe URLs are currently supported.');
    try {
      await this.setStatus(job.id, 'FETCHING_CONTENT', 20);
      const html = await this.fetchHtml(job.canonicalUrl);
      const parsed = this.parser.parse(html);
      if (!parsed) return this.fail(job.id, 'RECIPE_NOT_FOUND', 'No structured recipe was found on this page.');
      await this.setStatus(job.id, 'ANALYZING_TEXT', 60);
      const analysis = await this.analysis.analyzeText({ ...parsed, text: html.slice(0, 200_000) });
      if (!analysis.ingredients.length) return this.fail(job.id, 'INGREDIENTS_NOT_FOUND', 'The recipe did not include recognizable ingredients.');
      const title = analysis.title?.trim() || 'Untitled recipe';
      await this.persistReviewDraft(job, title, analysis);
    } catch (error) {
      await this.fail(job.id, 'SOURCE_UNAVAILABLE', error instanceof Error ? error.message : 'The source could not be fetched.');
    }
  }

  private async fetchHtml(url: string) {
    const response = await fetch(url, { redirect: 'manual', signal: AbortSignal.timeout(15_000), headers: { Accept: 'text/html,application/xhtml+xml' } });
    if (response.status >= 300 && response.status < 400) throw new Error('Source redirects are not followed for safety.');
    if (!response.ok) throw new Error(`Source returned HTTP ${response.status}.`);
    const contentType = response.headers.get('content-type') ?? '';
    if (!contentType.includes('html')) throw new Error('Source did not return an HTML page.');
    const contentLength = Number(response.headers.get('content-length') ?? 0);
    if (contentLength > 2_000_000) throw new Error('Source page is too large.');
    const html = await response.text();
    if (html.length > 2_000_000) throw new Error('Source page is too large.');
    return html;
  }

  private async persistReviewDraft(job: { id: string; householdId: string; accountId: string; canonicalUrl: string | null }, title: string, analysis: Awaited<ReturnType<RecipeAnalysisProvider['analyzeText']>>) {
    await this.prisma.$transaction(async (tx) => {
      const current = await tx.importJob.findUniqueOrThrow({ where: { id: job.id } });
      if (current.status === 'CANCELLED') return;
      const recipe = await tx.recipe.create({ data: { householdId: job.householdId, title, readiness: 'NEEDS_REVIEW' } });
      const version = await tx.recipeVersion.create({ data: { householdId: job.householdId, recipeId: recipe.id, version: 1, title, originalServings: analysis.originalServings ? this.servingsNumber(analysis.originalServings) : null, yieldWording: analysis.originalServings, readiness: 'NEEDS_REVIEW', snapshot: analysis as unknown as Prisma.InputJsonValue, createdByAccountId: job.accountId } });
      await tx.recipe.update({ where: { id: recipe.id }, data: { currentVersionId: version.id } });
      await tx.recipeSource.create({ data: { householdId: job.householdId, recipeId: recipe.id, kind: 'url', canonicalUrl: job.canonicalUrl, attribution: job.canonicalUrl } });
      await tx.recipeIngredient.createMany({ data: analysis.ingredients.map((item, sortOrder) => ({ householdId: job.householdId, recipeVersionId: version.id, name: item.name, quantityMin: item.quantityMin, quantityMax: item.quantityMax, originalUnit: item.originalUnit, originalText: item.originalText, inferred: item.inferred, sortOrder })) });
      await tx.recipeInstruction.createMany({ data: analysis.instructions.map((body, sortOrder) => ({ householdId: job.householdId, recipeVersionId: version.id, body, sortOrder })) });
      await tx.extractionEvidence.createMany({ data: [{ householdId: job.householdId, importJobId: job.id, fieldPath: 'recipe.title', origin: 'json-ld', excerpt: title, confidence: '0.9500' }, ...analysis.ingredients.map((item, index) => ({ householdId: job.householdId, importJobId: job.id, fieldPath: `ingredients[${index}]`, origin: 'json-ld', excerpt: item.originalText, confidence: '0.9000' }))] });
      await tx.importJob.update({ where: { id: job.id }, data: { status: 'READY_FOR_REVIEW', progress: 100, errorCode: null, errorDetail: Prisma.JsonNull, revision: { increment: 1 } } });
    });
  }

  private servingsNumber(value: string) {
    const match = value.match(/\d+(?:\.\d+)?/);
    return match?.[0] ?? null;
  }

  private setStatus(id: string, status: ImportStatus, progress: number) {
    return this.prisma.importJob.updateMany({ where: { id, status: { not: 'CANCELLED' } }, data: { status, progress } });
  }

  private fail(id: string, code: string, message: string) {
    return this.prisma.importJob.updateMany({ where: { id, status: { not: 'CANCELLED' } }, data: { status: 'FAILED', errorCode: code, errorDetail: { message }, progress: 100, revision: { increment: 1 } } });
  }
}
