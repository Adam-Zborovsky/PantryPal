import { promises as dns } from 'node:dns';
import { SourceUrlService } from './source-url.service';

describe('SourceUrlService', () => {
  const service = new SourceUrlService();
  beforeEach(() => {
    jest
      .spyOn(dns, 'lookup')
      .mockResolvedValue([{ address: '93.184.216.34', family: 4 }]);
  });
  afterEach(() => jest.restoreAllMocks());

  it('removes tracking fragments and parameters', async () =>
    await expect(
      service.canonicalize('https://example.com/a?utm_source=x&keep=y#part'),
    ).resolves.toBe('https://example.com/a?keep=y'));
  it.each([
    'http://127.0.0.1/a',
    'http://169.254.169.254/latest',
    'file:///etc/passwd',
  ])(
    'rejects unsafe source %s',
    async (url) => await expect(service.canonicalize(url)).rejects.toThrow(),
  );

  it('blocks a hostname that resolves to a private address', async () => {
    jest
      .spyOn(dns, 'lookup')
      .mockResolvedValue([{ address: '10.0.0.8', family: 4 }]);
    await expect(
      service.canonicalize('https://safe-looking.example/recipe'),
    ).rejects.toThrow('SOURCE_BLOCKED');
  });
});
