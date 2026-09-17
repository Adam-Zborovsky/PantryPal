import { YouTubeSourceAdapterService } from './youtube-source-adapter.service';

describe('YouTubeSourceAdapterService', () => {
  const adapter = new YouTubeSourceAdapterService();

  it.each([
    ['https://youtu.be/dQw4w9WgXcQ?t=12'],
    ['https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share'],
    ['https://m.youtube.com/shorts/dQw4w9WgXcQ'],
  ])('canonicalizes public video URLs: %s', (url) => {
    expect(adapter.canonicalize(url)).toBe(
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
  });

  it('rejects non-video YouTube pages', () => {
    expect(() =>
      adapter.canonicalize('https://www.youtube.com/@PantryPal'),
    ).toThrow('does not identify a public video');
  });
});
