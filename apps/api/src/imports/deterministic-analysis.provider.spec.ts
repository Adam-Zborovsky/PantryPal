import { DeterministicAnalysisProvider } from './deterministic-analysis.provider';

describe('DeterministicAnalysisProvider', () => {
  it('keeps unknown values inferred instead of inventing amounts', async () => {
    const result = await new DeterministicAnalysisProvider().analyzeText({ title: 'Soup', ingredients: ['2 carrots', 'salt to taste'], instructions: ['Cook'], text: '' });
    expect(result.ingredients[0]).toMatchObject({ quantityMin: '2', name: 'carrots', inferred: false });
    expect(result.ingredients[1]).toMatchObject({ quantityMin: null, inferred: true });
  });
});
