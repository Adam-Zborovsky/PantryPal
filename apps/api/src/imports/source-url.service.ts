import { BadRequestException, Injectable } from '@nestjs/common';
import { isIP } from 'node:net';

const blockedHosts = new Set(['localhost', 'metadata.google.internal', 'metadata', '169.254.169.254']);

@Injectable()
export class SourceUrlService {
  canonicalize(raw: string) {
    let url: URL;
    try { url = new URL(raw.trim()); } catch { throw new BadRequestException('SOURCE_UNSUPPORTED: Enter a valid public HTTP or HTTPS link.'); }
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || this.isBlockedHost(url.hostname)) {
      throw new BadRequestException('SOURCE_UNSUPPORTED: Only public HTTP or HTTPS recipe links can be analysed.');
    }
    url.hash = '';
    for (const key of [...url.searchParams.keys()]) if (/^(utm_|fbclid$|gclid$)/i.test(key)) url.searchParams.delete(key);
    return url.toString();
  }

  private isBlockedHost(host: string) {
    const lower = host.toLowerCase().replace(/^\[|\]$/g, '');
    if (blockedHosts.has(lower) || lower.endsWith('.local') || lower.endsWith('.internal')) return true;
    if (!isIP(lower)) return false;
    if (lower === '::1' || lower.startsWith('fe80:') || lower.startsWith('fc') || lower.startsWith('fd')) return true;
    const [a, b] = lower.split('.').map(Number);
    return a === 10 || a === 127 || a === 0 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168);
  }
}
