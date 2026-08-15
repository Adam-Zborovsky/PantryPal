import { WebpageRecipeParserService } from './webpage-recipe-parser.service';

describe('WebpageRecipeParserService', () => {
  it('extracts a schema.org Recipe before AI analysis', () => {
    const draft = new WebpageRecipeParserService().parse('<script type="application/ld+json">{"@context":"https://schema.org","@type":"Recipe","name":"Soup","recipeYield":"4 servings","recipeIngredient":["2 carrots"],"recipeInstructions":[{"@type":"HowToStep","text":"Simmer."}]}</script>');
    expect(draft).toEqual({ title: 'Soup', servings: '4 servings', ingredients: ['2 carrots'], instructions: ['Simmer.'], source: 'json-ld' });
  });
});
