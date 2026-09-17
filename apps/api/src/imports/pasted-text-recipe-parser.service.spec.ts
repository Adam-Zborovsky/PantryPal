import { PastedTextRecipeParserService } from './pasted-text-recipe-parser.service';

describe('PastedTextRecipeParserService', () => {
  const parser = new PastedTextRecipeParserService();

  it('extracts labelled recipe sections from pasted text', () => {
    expect(
      parser.parse(
        'Weeknight soup\nServes 4\n\nIngredients\n- 2 carrots\n- 1 cup broth\n\nMethod\n1. Chop the carrots.\n2. Simmer with broth.',
      ),
    ).toEqual({
      title: 'Weeknight soup',
      servings: '4',
      ingredients: ['2 carrots', '1 cup broth'],
      instructions: ['Chop the carrots.', 'Simmer with broth.'],
      source: 'pasted-text',
    });
  });

  it('keeps a paste without ingredients out of the import pipeline', () => {
    expect(parser.parse('A lovely story about soup.')).toBeUndefined();
  });
});
