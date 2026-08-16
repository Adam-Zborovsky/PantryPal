import { Module } from '@nestjs/common';
import { RealtimeModule } from '../realtime/realtime.module';
import { AuthModule } from '../auth/auth.module';
import { ActivityService } from './activity.service';
import { ActivityController } from './activity.controller';

@Module({ imports: [RealtimeModule, AuthModule], controllers: [ActivityController], providers: [ActivityService], exports: [ActivityService] })
export class ActivityModule {}
