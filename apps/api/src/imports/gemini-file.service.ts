import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createReadStream } from 'node:fs';
import type { ImportErrorCode } from './import-errors';

export class GeminiFileError extends Error {
  constructor(
    readonly code: Extract<
      ImportErrorCode,
      'PROVIDER_RATE_LIMITED' | 'ANALYSIS_FAILED' | 'MEDIA_PROCESSING_FAILED'
    >,
    message: string,
  ) {
    super(message);
  }
}

type GeminiFile = { name?: string; uri?: string; state?: string };

@Injectable()
export class GeminiFileService {
  constructor(private readonly config: ConfigService) {}

  async uploadTemporary(input: {
    path: string;
    byteSize: number;
    mimeType: string;
    displayName: string;
  }) {
    const apiKey = this.apiKey();
    let remoteName: string | undefined;
    try {
      const started = await fetch(
        'https://generativelanguage.googleapis.com/upload/v1beta/files',
        {
          method: 'POST',
          signal: AbortSignal.timeout(30_000),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
            'X-Goog-Upload-Protocol': 'resumable',
            'X-Goog-Upload-Command': 'start',
            'X-Goog-Upload-Header-Content-Length': input.byteSize.toString(),
            'X-Goog-Upload-Header-Content-Type': input.mimeType,
          },
          body: JSON.stringify({ file: { display_name: input.displayName } }),
        },
      );
      if (started.status === 429) this.rateLimited();
      const uploadUrl = started.headers.get('x-goog-upload-url');
      if (!started.ok || !uploadUrl) {
        throw new GeminiFileError(
          'ANALYSIS_FAILED',
          `Media upload provider returned HTTP ${started.status}.`,
        );
      }
      const stream = createReadStream(input.path);
      const finalized = await fetch(uploadUrl, {
        method: 'POST',
        signal: AbortSignal.timeout(120_000),
        headers: {
          'Content-Length': input.byteSize.toString(),
          'X-Goog-Upload-Offset': '0',
          'X-Goog-Upload-Command': 'upload, finalize',
        },
        body: stream as unknown as BodyInit,
        duplex: 'half',
      } as RequestInit & { duplex: 'half' });
      if (finalized.status === 429) this.rateLimited();
      if (!finalized.ok) {
        throw new GeminiFileError(
          'ANALYSIS_FAILED',
          `Media upload provider returned HTTP ${finalized.status}.`,
        );
      }
      const payload = (await finalized.json()) as { file?: GeminiFile };
      const file = payload.file;
      if (!file?.name || !file.uri) {
        throw new GeminiFileError(
          'ANALYSIS_FAILED',
          'Media upload provider returned an incomplete file reference.',
        );
      }
      remoteName = file.name;
      const active = await this.waitForActive(apiKey, file);
      return {
        fileData: { fileUri: active.uri!, mimeType: input.mimeType },
        cleanup: () => this.delete(apiKey, active.name!),
      };
    } catch (error) {
      if (remoteName) await this.delete(apiKey, remoteName);
      throw error;
    }
  }

  private async waitForActive(apiKey: string, file: GeminiFile) {
    let current = file;
    const deadline = Date.now() + 5 * 60_000;
    while (current.state === 'PROCESSING') {
      if (Date.now() >= deadline) {
        throw new GeminiFileError(
          'MEDIA_PROCESSING_FAILED',
          'Media analysis preparation timed out.',
        );
      }
      await new Promise((resolve) => setTimeout(resolve, 5_000));
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/${this.filePath(current.name!)}`,
        {
          headers: { 'x-goog-api-key': apiKey },
          signal: AbortSignal.timeout(30_000),
        },
      );
      if (response.status === 429) this.rateLimited();
      if (!response.ok) {
        throw new GeminiFileError(
          'ANALYSIS_FAILED',
          `Media status provider returned HTTP ${response.status}.`,
        );
      }
      current = (await response.json()) as GeminiFile;
    }
    if (current.state === 'FAILED' || !current.uri || !current.name) {
      throw new GeminiFileError(
        'MEDIA_PROCESSING_FAILED',
        'Media analysis provider could not process this file.',
      );
    }
    return current;
  }

  private async delete(apiKey: string, name: string) {
    try {
      await fetch(
        `https://generativelanguage.googleapis.com/v1beta/${this.filePath(name)}`,
        {
          method: 'DELETE',
          headers: { 'x-goog-api-key': apiKey },
          signal: AbortSignal.timeout(30_000),
        },
      );
    } catch {
      // Deletion is attempted in finally and must not obscure the import result.
    }
  }

  private apiKey() {
    const key = this.config.get<string>('GEMINI_API_KEY')?.trim();
    if (!key) {
      throw new GeminiFileError(
        'MEDIA_PROCESSING_FAILED',
        'Audio and video imports require recipe analysis to be configured. Paste recipe text instead.',
      );
    }
    return key;
  }

  private rateLimited(): never {
    throw new GeminiFileError(
      'PROVIDER_RATE_LIMITED',
      'Recipe analysis is temporarily rate limited. Try again shortly.',
    );
  }

  private filePath(name: string) {
    return name.split('/').map(encodeURIComponent).join('/');
  }
}
