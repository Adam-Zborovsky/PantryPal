import { SocialSourceClassifierService } from './social-source-classifier.service';

describe('SocialSourceClassifierService', () => {
  const classifier = new SocialSourceClassifierService();

  it.each([
    ['https://www.instagram.com/reel/example/', 'instagram'],
    ['https://vm.tiktok.com/example/', 'tiktok'],
  ])('classifies %s as %s', (raw, platform) => {
    expect(classifier.platform(new URL(raw))).toBe(platform);
  });

  it('does not classify an ordinary recipe page', () => {
    expect(
      classifier.platform(new URL('https://example.com/recipe')),
    ).toBeUndefined();
  });
});
