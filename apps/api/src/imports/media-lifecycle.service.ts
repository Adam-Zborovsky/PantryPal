import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { MediaStorageService } from './media-storage.service';

@Injectable()
export class MediaLifecycleService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MediaLifecycleService.name);
  private timer?: NodeJS.Timeout;

  constructor(private readonly media: MediaStorageService) {}

  onModuleInit() {
    this.timer = setInterval(() => void this.sweep(), 15 * 60 * 1000);
    this.timer.unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  private async sweep() {
    try {
      await this.media.sweepExpired();
    } catch (error) {
      this.logger.warn(
        `Media expiry sweep failed: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }
  }
}
