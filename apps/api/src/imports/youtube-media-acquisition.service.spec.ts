import { ConfigService } from '@nestjs/config';
import { YouTubeMediaAcquisitionService } from './youtube-media-acquisition.service';

describe('YouTubeMediaAcquisitionService', () => {
  it('refuses server-side video download unless explicitly enabled', async () => {
    const service = new YouTubeMediaAcquisitionService({
      get: jest.fn().mockReturnValue(undefined),
    } as unknown as ConfigService);

    await expect(
      service.acquire('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
    ).rejects.toMatchObject({ code: 'MEDIA_DOWNLOAD_DISABLED' });
  });
});
