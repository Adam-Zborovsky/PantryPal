import { BadRequestException, Injectable } from '@nestjs/common';
import { promises as dns } from 'node:dns';
import { isIP } from 'node:net';

const blockedHosts = new Set([
  'localhost',
  'metadata.google.internal',
  'metadata',
  '169.254.169.254',
]);

@Injectable()
export class SourceUrlService {
  async canonicalize(raw: string) {
    let url: URL;
    try {
      url = new URL(raw.trim());
    } catch {
      throw new BadRequestException(
        'SOURCE_UNSUPPORTED: Enter a valid public HTTP or HTTPS link.',
      );
    }
    if (
      !['http:', 'https:'].includes(url.protocol) ||
      url.username ||
      url.password ||
      this.isBlockedHost(url.hostname)
    ) {
      throw new BadRequestException(
        'SOURCE_UNSUPPORTED: Only public HTTP or HTTPS recipe links can be analysed.',
      );
    }
    url.hash = '';
    for (const key of [...url.searchParams.keys()])
      if (/^(utm_|fbclid$|gclid$)/i.test(key)) url.searchParams.delete(key);
    await this.assertPublicUrl(url);
    return url.toString();
  }

  async assertPublicUrl(url: URL | string) {
    const parsed = typeof url === 'string' ? new URL(url) : url;
    const host = parsed.hostname.toLowerCase().replace(/^\[|\]$/g, '');
    if (this.isBlockedHost(host)) {
      throw new BadRequestException(
        'SOURCE_BLOCKED: This link resolves to a private or local address.',
      );
    }
    let addresses: Array<{ address: string; family: number }>;
    try {
      addresses = await dns.lookup(host, { all: true, verbatim: true });
    } catch {
      throw new BadRequestException(
        'SOURCE_UNAVAILABLE: The source host could not be resolved safely.',
      );
    }
    if (
      !addresses.length ||
      addresses.some((entry) => this.isBlockedHost(entry.address))
    ) {
      throw new BadRequestException(
        'SOURCE_BLOCKED: This link resolves to a private or local address.',
      );
    }
  }

  private isBlockedHost(host: string): boolean {
    const lower = host
      .toLowerCase()
      .replace(/^\[|\]$/g, '')
      .replace(/\.$/, '');
    if (lower.startsWith('::ffff:')) return this.isBlockedHost(lower.slice(7));
    if (
      blockedHosts.has(lower) ||
      lower.endsWith('.local') ||
      lower.endsWith('.internal')
    )
      return true;
    if (!isIP(lower)) return false;
    if (
      lower === '::1' ||
      lower.startsWith('fe80:') ||
      lower.startsWith('fc') ||
      lower.startsWith('fd')
    )
      return true;
    const [a, b] = lower.split('.').map(Number);
    return (
      a === 10 ||
      a === 127 ||
      a === 0 ||
      (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168)
    );
  }
}
