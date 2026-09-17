import { ConfigService } from '@nestjs/config';
import { SocialMediaAcquisitionService } from './social-media-acquisition.service';

describe('SocialMediaAcquisitionService', () => {
  it('refuses social-media download unless explicitly enabled', async () => {
    const service = new SocialMediaAcquisitionService({
      get: jest.fn().mockReturnValue(undefined),
    } as unknown as ConfigService);

    await expect(
      service.acquire('tiktok', 'https://www.tiktok.com/@creator/video/1'),
    ).rejects.toMatchObject({ code: 'MEDIA_DOWNLOAD_DISABLED' });
  });
});
