import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
} from '@nestjs/common';
import { ImportStatus, Prisma } from '@prisma/client';
import { readFile } from 'node:fs/promises';
import { PrismaService } from '../prisma/prisma.service';
import { RECIPE_ANALYSIS_PROVIDER } from './recipe-analysis.provider';
import type { RecipeAnalysisProvider } from './recipe-analysis.provider';
import { PastedTextRecipeParserService } from './pasted-text-recipe-parser.service';
import { RecipeAnalysisProviderError } from './gemini-recipe-analysis.provider';
import { ImportSourceError } from './source-adapter';
import type { ImportErrorCode } from './import-errors';
import { WebpageRecipeParserService } from './webpage-recipe-parser.service';
import { YouTubeSourceAdapterService } from './youtube-source-adapter.service';
import { SourceUrlService } from './source-url.service';
import { SocialSourceClassifierService } from './social-source-classifier.service';
import {
  MediaStorageError,
  MediaStorageService,
} from './media-storage.service';
import { MediaToolError, MediaToolService } from './media-tool.service';
import { GeminiFileError, GeminiFileService } from './gemini-file.service';
import { YouTubeMediaAcquisitionService } from './youtube-media-acquisition.service';
import { SocialMediaAcquisitionService } from './social-media-acquisition.service';

type EvidenceOrigin =
  | 'json-ld'
  | 'pasted-text'
  | 'youtube'
  | 'social-media'
  | 'uploaded-image'
  | 'uploaded-audio'
  | 'uploaded-video';

type ParsedSource = {
  draft:
    | {
        title?: string;
        servings?: string;
        ingredients: string[];
        instructions: string[];
        source: EvidenceOrigin;
      }
    | undefined;
  text: string;
  sourceUri?: string;
  inlineData?: { mimeType: string; data: string };
  fileData?: { mimeType: string; fileUri: string };
  visualFrames?: Array<{
    timestampMs: number;
    frameIndex: number;
    inlineData: { mimeType: string; data: string };
  }>;
  cleanup?: () => Promise<void>;
};

@Injectable()
export class ImportProcessorService {
  private readonly logger = new Logger(ImportProcessorService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly parser: WebpageRecipeParserService,
    private readonly pastedText: PastedTextRecipeParserService,
    private readonly youtube: YouTubeSourceAdapterService,
    private readonly urls: SourceUrlService,
    private readonly social: SocialSourceClassifierService,
    private readonly media: MediaStorageService,
    private readonly mediaTools: MediaToolService,
    private readonly geminiFiles: GeminiFileService,
    private readonly youtubeMedia: YouTubeMediaAcquisitionService,
    private readonly socialMedia: SocialMediaAcquisitionService,
    @Inject(RECIPE_ANALYSIS_PROVIDER)
    private readonly analysis: RecipeAnalysisProvider,
  ) {}

  async process(importJobId: string) {
    const job = await this.prisma.importJob.findUnique({
      where: { id: importJobId },
    });
    if (!job || job.status === 'CANCELLED') return;
    if (!['url', 'text', 'image'].includes(job.sourceKind))
      return this.fail(
        job.id,
        'SOURCE_UNSUPPORTED',
        'This import type is not available yet. Paste recipe text or use a public recipe URL.',
      );
    let source: ParsedSource | undefined;
    try {
      source = await this.parseSource(job);
      if (!source?.draft)
        return this.fail(
          job.id,
          'RECIPE_NOT_FOUND',
          'No structured recipe was found on this page.',
        );
      const visualFrames =
        'visualFrames' in source ? source.visualFrames : undefined;
      const startsWithVisualAnalysis =
        !source.fileData && (visualFrames?.length ?? 0) > 0;
      await this.setStatus(
        job.id,
        source.inlineData ||
          source.fileData ||
          source.sourceUri ||
          startsWithVisualAnalysis
          ? 'STRUCTURING_RECIPE'
          : 'ANALYZING_TEXT',
        source.inlineData ||
          source.fileData ||
          source.sourceUri ||
          startsWithVisualAnalysis
          ? 70
          : 60,
      );
      if (startsWithVisualAnalysis)
        await this.setStatus(job.id, 'ANALYZING_VISUALS', 65);
      let analysis = await this.analysis.analyzeText({
        ...source.draft,
        text: source.text,
        sourceUri: source.sourceUri,
        inlineData: source.inlineData,
        inlineImages: startsWithVisualAnalysis
          ? visualFrames!.map((frame) => frame.inlineData)
          : undefined,
        fileData: source.fileData,
      });
      let usedVisualFrames = startsWithVisualAnalysis
        ? (visualFrames ?? [])
        : [];
      if (
        !analysis.ingredients.length &&
        source.fileData &&
        visualFrames?.length
      ) {
        await this.setStatus(job.id, 'ANALYZING_VISUALS', 75);
        analysis = await this.analysis.analyzeText({
          ...source.draft,
          text: this.visualAnalysisPrompt(visualFrames),
          inlineImages: visualFrames.map((frame) => frame.inlineData),
        });
        usedVisualFrames = visualFrames;
      }
      if (!analysis.ingredients.length)
        return this.fail(
          job.id,
          source.sourceUri ? 'SOURCE_METADATA_ONLY' : 'INGREDIENTS_NOT_FOUND',
          source.sourceUri
            ? 'We could access the public video, but could not identify recipe ingredients. Paste the recipe text or upload a shorter clip.'
            : 'The recipe did not include recognizable ingredients.',
        );
      const title = analysis.title?.trim() || 'Untitled recipe';
      await this.persistReviewDraft(
        job,
        title,
        analysis,
        source.draft.source,
        usedVisualFrames,
      );
      this.logger.log(`Import ${job.id} is ready for review.`);
    } catch (error) {
      await this.fail(
        job.id,
        error instanceof RecipeAnalysisProviderError
          ? error.code
          : error instanceof ImportSourceError
            ? error.code
            : error instanceof MediaStorageError
              ? error.code
              : error instanceof MediaToolError
                ? error.code
                : error instanceof GeminiFileError
                  ? error.code
                  : error instanceof BadRequestException
                    ? this.errorCode(error.message)
                    : 'SOURCE_UNAVAILABLE',
        error instanceof Error
          ? error.message
          : 'The source could not be fetched.',
      );
    } finally {
      await source?.cleanup?.();
    }
  }

  private async parseSource(job: {
    id: string;
    householdId: string;
    sourceKind: string;
    sourceInput: string;
    canonicalUrl: string | null;
  }): Promise<ParsedSource | undefined> {
    if (job.sourceKind === 'text') {
      await this.setStatus(job.id, 'ANALYZING_TEXT', 35);
      return {
        draft: this.pastedText.parse(job.sourceInput),
        text: job.sourceInput.slice(0, 200_000),
        sourceUri: undefined,
      };
    }
    if (job.sourceKind === 'image') {
      await this.setStatus(job.id, 'ACQUIRING_MEDIA', 20);
      const image = await this.media.readReadyImageForImport(
        job.householdId,
        job.sourceInput,
        job.id,
      );
      await this.setStatus(job.id, 'ANALYZING_VISUALS', 45);
      return {
        draft: {
          title: 'Uploaded recipe image',
          ingredients: [],
          instructions: [],
          source: 'uploaded-image' as const,
        },
        text: 'Uploaded recipe image. Extract only recipe details visible in the image.',
        sourceUri: undefined,
        inlineData: image,
      };
    }
    if (!job.canonicalUrl) return undefined;
    await this.urls.assertPublicUrl(job.canonicalUrl);
    const url = new URL(job.canonicalUrl);
    const socialPlatform = this.social.platform(url);
    if (socialPlatform) {
      return this.parseSocialMedia(job.id, socialPlatform, job.canonicalUrl);
    }
    if (this.youtube.supports(url)) {
      await this.setStatus(job.id, 'FETCHING_METADATA', 20);
      const metadata = await this.youtube.fetchMetadata(job.canonicalUrl);
      return this.parseYouTubeMedia(job.id, metadata);
    }
    await this.setStatus(job.id, 'FETCHING_CONTENT', 20);
    const html = await this.fetchHtml(job.canonicalUrl);
    return {
      draft: this.parser.parse(html),
      text: html.slice(0, 200_000),
      sourceUri: undefined,
    };
  }

  private async fetchHtml(url: string) {
    const response = await fetch(url, {
      redirect: 'manual',
      signal: AbortSignal.timeout(15_000),
      headers: { Accept: 'text/html,application/xhtml+xml' },
    });
    if (response.status >= 300 && response.status < 400)
      throw new ImportSourceError(
        'SOURCE_UNSUPPORTED',
        'Source redirects are not followed for safety.',
      );
    if (!response.ok)
      throw new ImportSourceError(
        this.httpFailureCode(response.status),
        `Source returned HTTP ${response.status}.`,
      );
    const contentType = response.headers.get('content-type') ?? '';
    if (!contentType.includes('html'))
      throw new Error('Source did not return an HTML page.');
    const contentLength = Number(response.headers.get('content-length') ?? 0);
    if (contentLength > 2_000_000) throw new Error('Source page is too large.');
    const html = await response.text();
    if (html.length > 2_000_000) throw new Error('Source page is too large.');
    return html;
  }

  private async parseYouTubeMedia(
    jobId: string,
    metadata: {
      canonicalUrl: string;
      title: string;
      authorName: string;
      authorUrl: string;
    },
  ) {
    await this.setStatus(jobId, 'ACQUIRING_MEDIA', 30);
    const media = await this.youtubeMedia.acquire(metadata.canonicalUrl);
    try {
      const probe = await this.mediaTools.probe(media.path, 'VIDEO');
      const sampledFrames = await this.mediaTools.extractVideoFrames(
        media.path,
        media.directory,
        probe.durationSeconds,
      );
      const visualFrames = await Promise.all(
        sampledFrames.map(async (frame) => ({
          timestampMs: frame.timestampMs,
          frameIndex: frame.frameIndex,
          inlineData: {
            mimeType: frame.mimeType,
            data: (await readFile(frame.path)).toString('base64'),
          },
        })),
      );
      const uploaded = probe.hasAudio
        ? await this.uploadExtractedAudio(
            jobId,
            media.path,
            media.directory,
            'YouTube video',
          )
        : undefined;
      return {
        draft: {
          title: metadata.title,
          ingredients: [],
          instructions: [],
          source: 'youtube' as const,
        },
        text: uploaded
          ? [
              'Extract a recipe only from spoken instructions. Do not infer ingredients or quantities that are not audible.',
              `Video title: ${metadata.title}`,
              `Creator: ${metadata.authorName}`,
            ].join('\n\n')
          : this.visualAnalysisPrompt(visualFrames),
        sourceUri: undefined,
        fileData: uploaded?.fileData,
        visualFrames,
        cleanup: async () => {
          await uploaded?.cleanup();
          await media.cleanup();
        },
      };
    } catch (error) {
      await media.cleanup();
      throw error;
    }
  }

  private async parseSocialMedia(
    jobId: string,
    platform: 'instagram' | 'tiktok',
    canonicalUrl: string,
  ) {
    await this.setStatus(jobId, 'ACQUIRING_MEDIA', 30);
    const media = await this.socialMedia.acquire(platform, canonicalUrl);
    try {
      const probe = await this.mediaTools.probe(media.path, 'VIDEO');
      const sampledFrames = await this.mediaTools.extractVideoFrames(
        media.path,
        media.directory,
        probe.durationSeconds,
      );
      const visualFrames = await Promise.all(
        sampledFrames.map(async (frame) => ({
          timestampMs: frame.timestampMs,
          frameIndex: frame.frameIndex,
          inlineData: {
            mimeType: frame.mimeType,
            data: (await readFile(frame.path)).toString('base64'),
          },
        })),
      );
      const uploaded = probe.hasAudio
        ? await this.uploadExtractedAudio(
            jobId,
            media.path,
            media.directory,
            `${platform === 'instagram' ? 'Instagram' : 'TikTok'} video`,
          )
        : undefined;
      const name = platform === 'instagram' ? 'Instagram' : 'TikTok';
      return {
        draft: {
          title: `${name} recipe`,
          ingredients: [],
          instructions: [],
          source: 'social-media' as const,
        },
        text: uploaded
          ? [
              'Extract a recipe only from spoken instructions. Do not infer ingredients or quantities that are not audible.',
              `Source platform: ${name}.`,
            ].join('\n\n')
          : this.visualAnalysisPrompt(visualFrames),
        sourceUri: canonicalUrl,
        fileData: uploaded?.fileData,
        visualFrames,
        cleanup: async () => {
          await uploaded?.cleanup();
          await media.cleanup();
        },
      };
    } catch (error) {
      await media.cleanup();
      throw error;
    }
  }

  private async persistReviewDraft(
    job: {
      id: string;
      householdId: string;
      accountId: string;
      canonicalUrl: string | null;
      sourceKind: string;
    },
    title: string,
    analysis: Awaited<ReturnType<RecipeAnalysisProvider['analyzeText']>>,
    evidenceOrigin: EvidenceOrigin,
    visualFrames: Array<{ timestampMs: number; frameIndex: number }> = [],
  ) {
    await this.prisma.$transaction(async (tx) => {
      const current = await tx.importJob.findUniqueOrThrow({
        where: { id: job.id },
      });
      if (current.status === 'CANCELLED') return;
      const recipe = await tx.recipe.create({
        data: {
          householdId: job.householdId,
          title,
          readiness: 'NEEDS_REVIEW',
        },
      });
      const version = await tx.recipeVersion.create({
        data: {
          householdId: job.householdId,
          recipeId: recipe.id,
          version: 1,
          title,
          originalServings: analysis.originalServings
            ? this.servingsNumber(analysis.originalServings)
            : null,
          yieldWording: analysis.originalServings,
          readiness: 'NEEDS_REVIEW',
          snapshot: analysis as unknown as Prisma.InputJsonValue,
          createdByAccountId: job.accountId,
        },
      });
      await tx.recipe.update({
        where: { id: recipe.id },
        data: { currentVersionId: version.id },
      });
      await tx.recipeSource.create({
        data: {
          householdId: job.householdId,
          recipeId: recipe.id,
          kind:
            evidenceOrigin === 'youtube'
              ? 'youtube'
              : evidenceOrigin === 'social-media'
                ? 'social-media'
                : job.sourceKind,
          canonicalUrl: job.canonicalUrl,
          attribution: job.canonicalUrl ?? 'Pasted recipe text',
        },
      });
      await tx.recipeIngredient.createMany({
        data: analysis.ingredients.map((item, sortOrder) => ({
          householdId: job.householdId,
          recipeVersionId: version.id,
          name: item.name,
          quantityMin: item.quantityMin,
          quantityMax: item.quantityMax,
          originalUnit: item.originalUnit,
          originalText: item.originalText,
          inferred: item.inferred,
          sortOrder,
        })),
      });
      await tx.recipeInstruction.createMany({
        data: analysis.instructions.map((body, sortOrder) => ({
          householdId: job.householdId,
          recipeVersionId: version.id,
          body,
          sortOrder,
        })),
      });
      await tx.extractionEvidence.createMany({
        data: [
          {
            householdId: job.householdId,
            importJobId: job.id,
            fieldPath: 'recipe.title',
            origin: evidenceOrigin,
            excerpt: title,
            confidence: '0.9500',
          },
          ...analysis.ingredients.map((item, index) => ({
            householdId: job.householdId,
            importJobId: job.id,
            fieldPath: `ingredients[${index}]`,
            origin: evidenceOrigin,
            excerpt: item.originalText,
            confidence: '0.9000',
          })),
          ...visualFrames.map((frame) => ({
            householdId: job.householdId,
            importJobId: job.id,
            fieldPath: `video.frames[${frame.frameIndex}]`,
            origin: evidenceOrigin,
            excerpt: `Sampled video frame at ${this.timestampLabel(frame.timestampMs)}.`,
            timestampMs: frame.timestampMs,
            frameIndex: frame.frameIndex,
            confidence: '0.7000',
          })),
        ],
      });
      await tx.importJob.update({
        where: { id: job.id },
        data: {
          recipeId: recipe.id,
          status: 'READY_FOR_REVIEW',
          progress: 100,
          errorCode: null,
          errorDetail: Prisma.JsonNull,
          revision: { increment: 1 },
        },
      });
    });
  }

  private servingsNumber(value: string) {
    const match = value.match(/\d+(?:\.\d+)?/);
    return match?.[0] ?? null;
  }

  private async uploadExtractedAudio(
    jobId: string,
    path: string,
    directory: string,
    sourceKind: string,
  ) {
    await this.setStatus(jobId, 'ANALYZING_AUDIO', 45);
    const audio = await this.mediaTools.extractMonoFlac(path, directory);
    return this.geminiFiles.uploadTemporary({
      ...audio,
      displayName: `PantryPal ${sourceKind} import`,
    });
  }

  private visualAnalysisPrompt(
    frames: Array<{ timestampMs: number; frameIndex: number }>,
  ) {
    return [
      'Extract a recipe only from details visibly present in these sampled video frames.',
      'Do not invent ingredients, quantities, or instructions obscured by motion, captions, or cuts.',
      `Frame timestamps: ${frames
        .map(
          (frame) =>
            `${frame.frameIndex + 1}=${this.timestampLabel(frame.timestampMs)}`,
        )
        .join(', ')}.`,
    ].join('\n\n');
  }

  private timestampLabel(timestampMs: number) {
    const totalSeconds = Math.max(0, Math.floor(timestampMs / 1000));
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${String(seconds).padStart(2, '0')}`;
  }

  private setStatus(id: string, status: ImportStatus, progress: number) {
    return this.prisma.importJob.updateMany({
      where: { id, status: { not: 'CANCELLED' } },
      data: { status, progress },
    });
  }

  private httpFailureCode(status: number): ImportErrorCode {
    if ([401, 402, 403, 429].includes(status)) return 'SOURCE_BLOCKED';
    if ([404, 410].includes(status)) return 'SOURCE_REMOVED';
    return 'SOURCE_UNAVAILABLE';
  }

  private fail(id: string, code: string, message: string) {
    this.logger.warn(`Import ${id} failed [${code}]: ${message}`);
    return this.prisma.importJob.updateMany({
      where: { id, status: { not: 'CANCELLED' } },
      data: {
        status: 'FAILED',
        errorCode: code,
        errorDetail: { message },
        progress: 100,
        revision: { increment: 1 },
      },
    });
  }

  private errorCode(message: string) {
    return message.startsWith('SOURCE_BLOCKED')
      ? 'SOURCE_BLOCKED'
      : message.startsWith('SOURCE_UNAVAILABLE')
        ? 'SOURCE_UNAVAILABLE'
        : 'SOURCE_UNAVAILABLE';
  }
}
