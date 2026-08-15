import { SourceUrlService } from './source-url.service';

describe('SourceUrlService', () => {
  const service = new SourceUrlService();
  it('removes tracking fragments and parameters', () => expect(service.canonicalize('https://example.com/a?utm_source=x&keep=y#part')).toBe('https://example.com/a?keep=y'));
  it.each(['http://127.0.0.1/a', 'http://169.254.169.254/latest', 'file:///etc/passwd'])('rejects unsafe source %s', (url) => expect(() => service.canonicalize(url)).toThrow());
});
