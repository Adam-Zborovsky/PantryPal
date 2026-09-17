import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  AnalysisIngredient,
  RecipeAnalysisProvider,
  RecipeAnalysisResult,
} from './recipe-analysis.provider';
import { DeterministicAnalysisProvider } from './deterministic-analysis.provider';

type ProviderFailureCode = 'PROVIDER_RATE_LIMITED' | 'ANALYSIS_FAILED';

export class RecipeAnalysisProviderError extends Error {
  constructor(
    readonly code: ProviderFailureCode,
    message: string,
  ) {
    super(message);
  }
}

@Injectable()
export class GeminiRecipeAnalysisProvider implements RecipeAnalysisProvider {
  constructor(
    private readonly config: ConfigService,
    private readonly fallback: DeterministicAnalysisProvider,
  ) {}

  async analyzeText(
    input: Parameters<RecipeAnalysisProvider['analyzeText']>[0],
  ): Promise<RecipeAnalysisResult> {
    const apiKey = this.config.get<string>('GEMINI_API_KEY')?.trim();
    if (!apiKey) return this.fallback.analyzeText(input);

    const model = this.config.get<string>('GEMINI_MODEL') ?? 'gemini-3.6-flash';
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      {
        method: 'POST',
        signal: AbortSignal.timeout(30_000),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: this.prompt(input) },
                ...(input.sourceUri || input.fileData
                  ? [
                      {
                        fileData: input.fileData ?? {
                          fileUri: input.sourceUri!,
                        },
                      },
                    ]
                  : []),
                ...(input.inlineData ? [{ inlineData: input.inlineData }] : []),
                ...(input.inlineImages ?? []).map((inlineData) => ({
                  inlineData,
                })),
              ],
            },
          ],
          generationConfig: {
            responseMimeType: 'application/json',
            responseJsonSchema: recipeSchema,
          },
        }),
      },
    );
    if (response.status === 429) {
      throw new RecipeAnalysisProviderError(
        'PROVIDER_RATE_LIMITED',
        'Recipe analysis is temporarily rate limited. Try again shortly.',
      );
    }
    if (!response.ok) {
      const reason = await this.providerErrorMessage(response);
      throw new RecipeAnalysisProviderError(
        'ANALYSIS_FAILED',
        reason
          ? `Recipe analysis provider returned HTTP ${response.status}: ${reason}`
          : `Recipe analysis provider returned HTTP ${response.status}.`,
      );
    }
    const payload = (await response.json()) as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    const text = payload.candidates?.[0]?.content?.parts
      ?.map((part) => part.text ?? '')
      .join('');
    if (!text) {
      throw new RecipeAnalysisProviderError(
        'ANALYSIS_FAILED',
        'Recipe analysis returned no structured result.',
      );
    }
    try {
      return this.validate(JSON.parse(text));
    } catch (error) {
      throw new RecipeAnalysisProviderError(
        'ANALYSIS_FAILED',
        error instanceof Error
          ? `Recipe analysis returned an invalid result: ${error.message}`
          : 'Recipe analysis returned an invalid result.',
      );
    }
  }

  private async providerErrorMessage(response: Response) {
    try {
      const payload = (await response.json()) as {
        error?: { message?: unknown };
      };
      const message = payload.error?.message;
      return typeof message === 'string' ? message.slice(0, 300) : undefined;
    } catch {
      return undefined;
    }
  }

  private prompt(input: Parameters<RecipeAnalysisProvider['analyzeText']>[0]) {
    return [
      'Extract a recipe from the supplied evidence. Return JSON only.',
      'Do not invent ingredient amounts, units, servings, or steps. Use null for unknown values and inferred=true when an ingredient could not be parsed reliably.',
      `Candidate title: ${input.title ?? ''}`,
      `Candidate servings: ${input.servings ?? ''}`,
      `Candidate ingredients:\n${input.ingredients.join('\n')}`,
      `Candidate instructions:\n${input.instructions.join('\n')}`,
      `Source text:\n${input.text.slice(0, 200_000)}`,
    ].join('\n\n');
  }

  private validate(value: unknown): RecipeAnalysisResult {
    if (!value || typeof value !== 'object')
      throw new Error('result is not an object');
    const record = value as Record<string, unknown>;
    const ingredients = Array.isArray(record.ingredients)
      ? record.ingredients.map((item, index) => this.ingredient(item, index))
      : [];
    const instructions = Array.isArray(record.instructions)
      ? record.instructions
          .filter((item): item is string => typeof item === 'string')
          .map((item) => item.trim())
          .filter(Boolean)
      : [];
    return {
      title: this.optionalString(record.title),
      originalServings: this.optionalString(record.originalServings),
      ingredients,
      instructions,
      completeness: this.completeness(record.completeness),
    };
  }

  private ingredient(value: unknown, index: number): AnalysisIngredient {
    if (!value || typeof value !== 'object')
      throw new Error(`ingredient ${index + 1} is invalid`);
    const record = value as Record<string, unknown>;
    const name = this.optionalString(record.name);
    if (!name) throw new Error(`ingredient ${index + 1} has no name`);
    return {
      name,
      quantityMin: this.decimal(record.quantityMin),
      quantityMax: this.decimal(record.quantityMax),
      originalUnit: this.optionalString(record.originalUnit),
      originalText: this.optionalString(record.originalText) ?? name,
      inferred: record.inferred === true,
    };
  }

  private optionalString(value: unknown) {
    return typeof value === 'string' && value.trim() ? value.trim() : null;
  }

  private decimal(value: unknown) {
    const normalized =
      typeof value === 'number' ? value.toString() : this.optionalString(value);
    if (normalized == null) return null;
    if (!/^\d+(?:\.\d+)?$/.test(normalized))
      throw new Error('ingredient amount is not a decimal');
    return normalized;
  }

  private completeness(value: unknown) {
    return typeof value === 'number' && Number.isFinite(value)
      ? Math.min(100, Math.max(0, Math.round(value)))
      : 0;
  }
}

const recipeSchema = {
  type: 'object',
  properties: {
    title: { type: ['string', 'null'] },
    originalServings: { type: ['string', 'null'] },
    ingredients: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          quantityMin: { type: ['string', 'null'] },
          quantityMax: { type: ['string', 'null'] },
          originalUnit: { type: ['string', 'null'] },
          originalText: { type: 'string' },
          inferred: { type: 'boolean' },
        },
        required: [
          'name',
          'quantityMin',
          'quantityMax',
          'originalUnit',
          'originalText',
          'inferred',
        ],
      },
    },
    instructions: { type: 'array', items: { type: 'string' } },
    completeness: { type: 'integer' },
  },
  required: [
    'title',
    'originalServings',
    'ingredients',
    'instructions',
    'completeness',
  ],
};
