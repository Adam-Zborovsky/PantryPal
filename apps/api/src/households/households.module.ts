import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { HouseholdAccessService } from './household-access.service';
import { HouseholdsController } from './households.controller';
import { HouseholdsService } from './households.service';
import { ActivityModule } from '../activity/activity.module';

@Module({
  imports: [AuthModule, ActivityModule],
  controllers: [HouseholdsController],
  providers: [HouseholdsService, HouseholdAccessService],
  exports: [HouseholdAccessService, HouseholdsService],
})
export class HouseholdsModule {}
