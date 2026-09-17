import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { HouseholdsModule } from '../households/households.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { FcmPushService } from './fcm-push.service';
import { PushSubscriptionsController } from './push-subscriptions.controller';
import { PushSubscriptionsService } from './push-subscriptions.service';
@Module({
  imports: [AuthModule, HouseholdsModule, RealtimeModule],
  controllers: [NotificationsController, PushSubscriptionsController],
  providers: [NotificationsService, PushSubscriptionsService, FcmPushService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
