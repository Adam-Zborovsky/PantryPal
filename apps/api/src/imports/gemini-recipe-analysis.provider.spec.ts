import { ConfigService } from '@nestjs/config';
import { DeterministicAnalysisProvider } from './deterministic-analysis.provider';
import { GeminiRecipeAnalysisProvider } from './gemini-recipe-analysis.provider';

describe('GeminiRecipeAnalysisProvider', () => {
  it('uses deterministic extraction when Gemini credentials are absent', async () => {
    const provider = new GeminiRecipeAnalysisProvider(
      { get: jest.fn().mockReturnValue(undefined) } as unknown as ConfigService,
      new DeterministicAnalysisProvider(),
    );

    await expect(
      provider.analyzeText({
        title: 'Soup',
        ingredients: ['2 carrots'],
        instructions: ['Simmer.'],
        text: 'Soup recipe',
      }),
    ).resolves.toMatchObject({
      title: 'Soup',
      ingredients: [{ name: 'carrots', quantityMin: '2' }],
    });
  });

  it('passes a public source URI as a Gemini file part', async () => {
    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: JSON.stringify({
                    title: 'Video soup',
                    originalServings: '2',
                    ingredients: [
                      {
                        name: 'carrots',
                        quantityMin: '2',
                        quantityMax: null,
                        originalUnit: null,
                        originalText: '2 carrots',
                        inferred: false,
                      },
                    ],
                    instructions: ['Simmer.'],
                    completeness: 80,
                  }),
                },
              ],
            },
          },
        ],
      }),
    });
    const originalFetch = global.fetch;
    global.fetch = fetchMock as unknown as typeof fetch;
    try {
      const provider = new GeminiRecipeAnalysisProvider(
        {
          get: jest.fn((key: string) =>
            key === 'GEMINI_API_KEY' ? 'test-key' : 'gemini-2.5-flash',
          ),
        } as unknown as ConfigService,
        new DeterministicAnalysisProvider(),
      );
      await provider.analyzeText({
        ingredients: [],
        instructions: [],
        text: 'Video metadata',
        sourceUri: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      });
      const body = JSON.parse(fetchMock.mock.calls[0][1].body as string);
      expect(body.contents[0].parts).toContainEqual({
        fileData: { fileUri: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' },
      });
    } finally {
      global.fetch = originalFetch;
    }
  });

  it('passes a verified image as inline Gemini data', async () => {
    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: JSON.stringify({
                    title: 'Photo soup',
                    originalServings: null,
                    ingredients: [],
                    instructions: [],
                    completeness: 5,
                  }),
                },
              ],
            },
          },
        ],
      }),
    });
    const originalFetch = global.fetch;
    global.fetch = fetchMock as unknown as typeof fetch;
    try {
      const provider = new GeminiRecipeAnalysisProvider(
        {
          get: jest.fn((key: string) =>
            key === 'GEMINI_API_KEY' ? 'test-key' : 'gemini-2.5-flash',
          ),
        } as unknown as ConfigService,
        new DeterministicAnalysisProvider(),
      );
      await provider.analyzeText({
        ingredients: [],
        instructions: [],
        text: 'Uploaded image',
        inlineData: { mimeType: 'image/jpeg', data: 'aGVsbG8=' },
      });
      const body = JSON.parse(fetchMock.mock.calls[0][1].body as string);
      expect(body.contents[0].parts).toContainEqual({
        inlineData: { mimeType: 'image/jpeg', data: 'aGVsbG8=' },
      });
    } finally {
      global.fetch = originalFetch;
    }
  });

  it('passes sampled video frames as separate inline Gemini parts', async () => {
    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: JSON.stringify({
                    title: 'Video soup',
                    originalServings: null,
                    ingredients: [],
                    instructions: [],
                    completeness: 5,
                  }),
                },
              ],
            },
          },
        ],
      }),
    });
    const originalFetch = global.fetch;
    global.fetch = fetchMock as unknown as typeof fetch;
    try {
      const provider = new GeminiRecipeAnalysisProvider(
        {
          get: jest.fn((key: string) =>
            key === 'GEMINI_API_KEY' ? 'test-key' : 'gemini-2.5-flash',
          ),
        } as unknown as ConfigService,
        new DeterministicAnalysisProvider(),
      );
      await provider.analyzeText({
        ingredients: [],
        instructions: [],
        text: 'Sampled frames from a recipe video.',
        inlineImages: [
          { mimeType: 'image/jpeg', data: 'Zmlyc3Q=' },
          { mimeType: 'image/jpeg', data: 'c2Vjb25k' },
        ],
      });
      const body = JSON.parse(fetchMock.mock.calls[0][1].body as string);
      expect(body.contents[0].parts).toEqual(
        expect.arrayContaining([
          { inlineData: { mimeType: 'image/jpeg', data: 'Zmlyc3Q=' } },
          { inlineData: { mimeType: 'image/jpeg', data: 'c2Vjb25k' } },
        ]),
      );
    } finally {
      global.fetch = originalFetch;
    }
  });

  it('leaves sampling parameters at the Gemini 3 defaults', async () => {
    const fetchMock = jest.fn<Promise<unknown>, [string, RequestInit]>();
    fetchMock.mockResolvedValue({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      title: 'Soup',
                      originalServings: null,
                      ingredients: [],
                      instructions: [],
                      completeness: 5,
                    }),
                  },
                ],
              },
            },
          ],
        }),
    });
    const originalFetch = global.fetch;
    global.fetch = fetchMock as unknown as typeof fetch;
    try {
      const provider = new GeminiRecipeAnalysisProvider(
        {
          get: jest.fn((key: string) =>
            key === 'GEMINI_API_KEY' ? 'test-key' : 'gemini-3.6-flash',
          ),
        } as unknown as ConfigService,
        new DeterministicAnalysisProvider(),
      );
      await provider.analyzeText({
        ingredients: [],
        instructions: [],
        text: 'Soup recipe',
      });
      const body = JSON.parse(fetchMock.mock.calls[0][1].body as string) as {
        generationConfig: Record<string, unknown>;
      };
      expect(body.generationConfig).not.toHaveProperty('temperature');
      expect(body.generationConfig).toMatchObject({
        responseMimeType: 'application/json',
      });
    } finally {
      global.fetch = originalFetch;
    }
  });

  it('includes the provider explanation when Gemini rejects a request', async () => {
    const fetchMock = jest.fn<Promise<unknown>, [string, RequestInit]>();
    fetchMock.mockResolvedValue({
      ok: false,
      status: 404,
      json: () =>
        Promise.resolve({
          error: {
            code: 404,
            message:
              'This model models/gemini-2.5-flash is no longer available to new users.',
            status: 'NOT_FOUND',
          },
        }),
    });
    const originalFetch = global.fetch;
    global.fetch = fetchMock as unknown as typeof fetch;
    try {
      const provider = new GeminiRecipeAnalysisProvider(
        {
          get: jest.fn((key: string) =>
            key === 'GEMINI_API_KEY' ? 'test-key' : 'gemini-2.5-flash',
          ),
        } as unknown as ConfigService,
        new DeterministicAnalysisProvider(),
      );
      await expect(
        provider.analyzeText({
          ingredients: [],
          instructions: [],
          text: 'Soup recipe',
        }),
      ).rejects.toMatchObject({
        code: 'ANALYSIS_FAILED',
        message:
          'Recipe analysis provider returned HTTP 404: This model models/gemini-2.5-flash is no longer available to new users.',
      });
    } finally {
      global.fetch = originalFetch;
    }
  });
});
