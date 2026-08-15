import { Injectable } from '@nestjs/common';
import { RecipeAnalysisProvider, RecipeAnalysisResult } from './recipe-analysis.provider';

@Injectable()
export class DeterministicAnalysisProvider implements RecipeAnalysisProvider {
  async analyzeText(input: { title?: string; servings?: string; ingredients: string[]; instructions: string[]; text: string }): Promise<RecipeAnalysisResult> {
    const ingredients = input.ingredients.map((originalText) => {
      const match = originalText.match(/^\s*(\d+(?:\.\d+)?)(?:\s*(?:-|to)\s*(\d+(?:\.\d+)?))?\s*([^\d\s]+)?\s+(.+)$/i);
      return {
        name: match?.[4] ?? originalText,
        quantityMin: match?.[1] ?? null,
        quantityMax: match?.[2] ?? null,
        originalUnit: match?.[3] ?? null,
        originalText,
        inferred: !match,
      };
    });
    const requiredWithAmounts = ingredients.filter((ingredient) => ingredient.quantityMin && ingredient.originalUnit).length;
    const completeness = Math.min(100, (input.title ? 5 : 0) + (input.servings ? 20 : 0) + (ingredients.length ? 25 : 0) + (ingredients.length ? (40 * requiredWithAmounts) / ingredients.length : 0) + (input.instructions.length ? 10 : 0));
    return { title: input.title ?? null, originalServings: input.servings ?? null, ingredients, instructions: input.instructions, completeness };
  }
}
