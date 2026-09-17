export interface AnalysisIngredient {
  name: string;
  quantityMin: string | null;
  quantityMax: string | null;
  originalUnit: string | null;
  originalText: string;
  inferred: boolean;
}

export interface RecipeAnalysisResult {
  title: string | null;
  originalServings: string | null;
  ingredients: AnalysisIngredient[];
  instructions: string[];
  completeness: number;
}

export interface RecipeAnalysisInput {
  title?: string;
  servings?: string;
  ingredients: string[];
  instructions: string[];
  text: string;
  sourceUri?: string;
  inlineData?: { mimeType: string; data: string };
  inlineImages?: Array<{ mimeType: string; data: string }>;
  fileData?: { mimeType: string; fileUri: string };
}

export interface RecipeAnalysisProvider {
  analyzeText(input: RecipeAnalysisInput): Promise<RecipeAnalysisResult>;
}

export const RECIPE_ANALYSIS_PROVIDER = Symbol('RECIPE_ANALYSIS_PROVIDER');
