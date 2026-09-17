import { ConfigService } from '@nestjs/config';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { GeminiFileService } from './gemini-file.service';

describe('GeminiFileService', () => {
  it('requires configured Gemini credentials before any media upload', async () => {
    const service = new GeminiFileService({
      get: jest.fn().mockReturnValue(undefined),
    } as unknown as ConfigService);

    await expect(
      service.uploadTemporary({
        path: 'unused.flac',
        byteSize: 1,
        mimeType: 'audio/flac',
        displayName: 'unused',
      }),
    ).rejects.toMatchObject({ code: 'MEDIA_PROCESSING_FAILED' });
  });

  it('uses a resumable upload, exposes fileData, and deletes the temporary remote file', async () => {
    const directory = await mkdtemp(join(tmpdir(), 'pantrypal-gemini-test-'));
    const path = join(directory, 'audio.flac');
    await writeFile(path, 'test audio');
    const originalFetch = global.fetch;
    const fetchMock = jest
      .fn()
      .mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({
          'x-goog-upload-url': 'https://upload.test/session',
        }),
      })
      .mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({
          file: {
            name: 'files/media-1',
            uri: 'https://generativelanguage.googleapis.com/v1beta/files/media-1',
            state: 'ACTIVE',
          },
        }),
      })
      .mockResolvedValueOnce({ ok: true, status: 200 });
    global.fetch = fetchMock as unknown as typeof fetch;
    try {
      const service = new GeminiFileService({
        get: jest.fn().mockReturnValue('test-key'),
      } as unknown as ConfigService);
      const uploaded = await service.uploadTemporary({
        path,
        byteSize: 10,
        mimeType: 'audio/flac',
        displayName: 'PantryPal audio import',
      });
      expect(uploaded.fileData).toEqual({
        mimeType: 'audio/flac',
        fileUri:
          'https://generativelanguage.googleapis.com/v1beta/files/media-1',
      });
      await uploaded.cleanup();
      expect(fetchMock.mock.calls[0][1]).toMatchObject({
        headers: expect.objectContaining({
          'X-Goog-Upload-Command': 'start',
          'X-Goog-Upload-Protocol': 'resumable',
        }),
      });
      expect(fetchMock.mock.calls[2][0]).toBe(
        'https://generativelanguage.googleapis.com/v1beta/files/media-1',
      );
      expect(fetchMock.mock.calls[2][1]).toMatchObject({ method: 'DELETE' });
    } finally {
      global.fetch = originalFetch;
      await rm(directory, { recursive: true, force: true });
    }
  });
});
