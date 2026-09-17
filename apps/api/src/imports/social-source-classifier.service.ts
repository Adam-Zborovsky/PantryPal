import { Injectable } from '@nestjs/common';
import type { SourceAdapter } from './source-adapter';

export type SocialPlatform = 'instagram' | 'tiktok';

const platformHosts: Record<SocialPlatform, Set<string>> = {
  instagram: new Set(['instagram.com', 'www.instagram.com', 'm.instagram.com']),
  tiktok: new Set([
    'tiktok.com',
    'www.tiktok.com',
    'm.tiktok.com',
    'vm.tiktok.com',
    'vt.tiktok.com',
  ]),
};

@Injectable()
export class SocialSourceClassifierService implements SourceAdapter {
  supports(url: URL) {
    return this.platform(url) !== undefined;
  }

  platform(url: URL): SocialPlatform | undefined {
    const host = url.hostname.toLowerCase();
    return (Object.keys(platformHosts) as SocialPlatform[]).find((platform) =>
      platformHosts[platform].has(host),
    );
  }
}
