import { Injectable } from '@nestjs/common';
import type { DeterministicRecipeDraft } from './webpage-recipe-parser.service';

const ingredientHeadings = /^(ingredients?|what you(?:'|’)ll need)$/i;
const instructionHeadings =
  /^(instructions?|method|directions?|steps?|preparation)$/i;
const servingsPattern =
  /(?:serves?|servings?|yield)\s*(?:[:=-]\s*)?(\d+(?:\.\d+)?(?:\s*[-–]\s*\d+(?:\.\d+)?)?\s*(?:servings?|people|portions?)?)/i;
const listPrefix = /^(?:[-*•]\s*|\d+[.)]\s*)/;

@Injectable()
export class PastedTextRecipeParserService {
  parse(text: string): DeterministicRecipeDraft | undefined {
    const lines = text
      .replace(/\r/g, '')
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean);
    if (!lines.length) return undefined;

    const ingredientsAt = lines.findIndex((line) =>
      ingredientHeadings.test(line),
    );
    const instructionsAt = lines.findIndex((line) =>
      instructionHeadings.test(line),
    );
    const title = this.title(lines, ingredientsAt, instructionsAt);
    const servings = lines
      .map((line) => line.match(servingsPattern)?.[1])
      .find(Boolean);
    const ingredients = this.section(lines, ingredientsAt, instructionsAt, true)
      .map((line) => line.replace(listPrefix, '').trim())
      .filter((line) => line.length > 0 && !instructionHeadings.test(line));
    const instructions = this.section(lines, instructionsAt, -1, false)
      .map((line) => line.replace(listPrefix, '').trim())
      .filter((line) => line.length > 0 && !ingredientHeadings.test(line));
    if (!ingredients.length) return undefined;
    return {
      title,
      servings,
      ingredients,
      instructions,
      source: 'pasted-text',
    };
  }

  private title(
    lines: string[],
    ingredientsAt: number,
    instructionsAt: number,
  ) {
    const positions = [ingredientsAt, instructionsAt].filter(
      (index) => index >= 0,
    );
    const boundary = positions.length ? Math.min(...positions) : lines.length;
    const candidate = lines
      .slice(0, boundary)
      .find(
        (line) => !servingsPattern.test(line) && !ingredientHeadings.test(line),
      );
    return candidate?.replace(/^recipe\s*:\s*/i, '').trim();
  }

  private section(
    lines: string[],
    start: number,
    end: number,
    ingredientFallback: boolean,
  ) {
    if (start >= 0) {
      const from = start + 1;
      const to = end > start ? end : lines.length;
      return lines.slice(from, to);
    }
    if (!ingredientFallback) return [];
    return lines.filter((line) => listPrefix.test(line));
  }
}
