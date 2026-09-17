import { Module } from '@nestjs/common';
import { ActivityModule } from '../activity/activity.module';
import { AuthModule } from '../auth/auth.module';
import { HouseholdsModule } from '../households/households.module';
import { RecipesModule } from '../recipes/recipes.module';
import { TripsModule } from '../trips/trips.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CookingController } from './cooking.controller';
import { CookingService } from './cooking.service';

@Module({
  imports: [
    AuthModule,
    HouseholdsModule,
    RecipesModule,
    ActivityModule,
    TripsModule,
    NotificationsModule,
  ],
  controllers: [CookingController],
  providers: [CookingService],
})
export class CookingModule {}
