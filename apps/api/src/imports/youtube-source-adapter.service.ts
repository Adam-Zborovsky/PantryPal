import { Injectable } from '@nestjs/common';
import { ImportSourceError, SourceAdapter } from './source-adapter';

const youtubeHosts = new Set([
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'youtu.be',
]);

export interface YouTubeMetadata {
  canonicalUrl: string;
  title: string;
  authorName: string;
  authorUrl: string;
}

@Injectable()
export class YouTubeSourceAdapterService implements SourceAdapter {
  supports(url: URL) {
    return youtubeHosts.has(url.hostname.toLowerCase());
  }

  async fetchMetadata(rawUrl: string): Promise<YouTubeMetadata> {
    const canonicalUrl = this.canonicalize(rawUrl);
    const response = await fetch(
      `https://www.youtube.com/oembed?url=${encodeURIComponent(canonicalUrl)}&format=json`,
      {
        signal: AbortSignal.timeout(15_000),
        headers: { Accept: 'application/json' },
      },
    );
    if (response.status === 401 || response.status === 403) {
      throw new ImportSourceError(
        'SOURCE_PRIVATE_OR_LOGIN_REQUIRED',
        'This YouTube video is private or requires sign-in. Paste its recipe text instead.',
      );
    }
    if (response.status === 404) {
      throw new ImportSourceError(
        'SOURCE_REMOVED',
        'This YouTube video is unavailable. Paste the recipe text or choose another source.',
      );
    }
    if (!response.ok) {
      throw new ImportSourceError(
        'SOURCE_UNAVAILABLE',
        `YouTube metadata returned HTTP ${response.status}.`,
      );
    }
    const payload = (await response.json()) as Record<string, unknown>;
    const title = this.string(payload.title);
    const authorName = this.string(payload.author_name);
    const authorUrl = this.string(payload.author_url);
    if (!title || !authorName || !authorUrl) {
      throw new ImportSourceError(
        'SOURCE_METADATA_ONLY',
        'YouTube provided incomplete public metadata. Paste the recipe text instead.',
      );
    }
    return { canonicalUrl, title, authorName, authorUrl };
  }

  canonicalize(rawUrl: string) {
    let url: URL;
    try {
      url = new URL(rawUrl);
    } catch {
      throw new ImportSourceError(
        'SOURCE_UNSUPPORTED',
        'Enter a valid YouTube URL.',
      );
    }
    if (!this.supports(url)) {
      throw new ImportSourceError(
        'SOURCE_UNSUPPORTED',
        'Enter a valid YouTube URL.',
      );
    }
    const id = this.videoId(url);
    if (!id) {
      throw new ImportSourceError(
        'SOURCE_UNSUPPORTED',
        'This YouTube URL does not identify a public video.',
      );
    }
    return `https://www.youtube.com/watch?v=${id}`;
  }

  private videoId(url: URL) {
    if (url.hostname.toLowerCase() === 'youtu.be')
      return this.validId(url.pathname.slice(1));
    if (url.pathname === '/watch')
      return this.validId(url.searchParams.get('v') ?? '');
    const match = url.pathname.match(/^\/(?:shorts|embed)\/([^/?#]+)/);
    return match ? this.validId(match[1]) : undefined;
  }

  private validId(value: string) {
    return /^[A-Za-z0-9_-]{11}$/.test(value) ? value : undefined;
  }

  private string(value: unknown) {
    return typeof value === 'string' && value.trim() ? value.trim() : undefined;
  }
}
