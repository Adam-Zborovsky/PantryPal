import { Injectable } from '@nestjs/common';

export interface DeterministicRecipeDraft {
  title?: string;
  servings?: string;
  ingredients: string[];
  instructions: string[];
  source:
    | 'json-ld'
    | 'pasted-text'
    | 'youtube'
    | 'uploaded-image'
    | 'uploaded-audio'
    | 'uploaded-video';
}

@Injectable()
export class WebpageRecipeParserService {
  parse(html: string): DeterministicRecipeDraft | undefined {
    const scripts = [
      ...html.matchAll(
        /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
      ),
    ].map((match) => match[1]);
    for (const script of scripts) {
      try {
        const candidate = this.findRecipe(JSON.parse(script));
        if (!candidate) continue;
        const ingredients = this.toStrings(candidate.recipeIngredient);
        const instructions = this.instructions(candidate.recipeInstructions);
        if (candidate.name || ingredients.length || instructions.length) {
          return {
            title: this.first(candidate.name),
            servings: this.first(candidate.recipeYield),
            ingredients,
            instructions,
            source: 'json-ld',
          };
        }
      } catch {
        /* Invalid publisher JSON-LD is ignored; text/AI fallback remains available. */
      }
    }
    return undefined;
  }

  private findRecipe(value: unknown): Record<string, unknown> | undefined {
    if (Array.isArray(value))
      return value.map((item) => this.findRecipe(item)).find(Boolean);
    if (!value || typeof value !== 'object') return undefined;
    const record = value as Record<string, unknown>;
    const types = Array.isArray(record['@type'])
      ? record['@type']
      : [record['@type']];
    if (types.some((type) => String(type).toLowerCase() === 'recipe'))
      return record;
    for (const key of ['@graph', 'mainEntity', 'itemListElement']) {
      const found = this.findRecipe(record[key]);
      if (found) return found;
    }
    return undefined;
  }

  private instructions(value: unknown): string[] {
    if (typeof value === 'string') return [value.trim()].filter(Boolean);
    if (!Array.isArray(value)) return [];
    return value
      .flatMap((item) => {
        if (typeof item === 'string') return [item.trim()];
        if (!item || typeof item !== 'object') return [];
        const record = item as Record<string, unknown>;
        if (Array.isArray(record.itemListElement))
          return this.instructions(record.itemListElement);
        return this.toStrings(record.text ?? record.name);
      })
      .filter(Boolean);
  }

  private toStrings(value: unknown): string[] {
    return Array.isArray(value)
      ? value.flatMap((item) => this.toStrings(item))
      : typeof value === 'string'
        ? [value.trim()].filter(Boolean)
        : [];
  }
  private first(value: unknown): string | undefined {
    return this.toStrings(value)[0];
  }
}
