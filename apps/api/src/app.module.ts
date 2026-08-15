import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { HealthController } from './health/health.controller';
import { MetricsController } from './health/metrics.controller';
import { HouseholdsModule } from './households/households.module';
import { ImportsModule } from './imports/imports.module';
import { PrismaModule } from './prisma/prisma.module';
import { RecipesModule } from './recipes/recipes.module';
import { ActivityModule } from './activity/activity.module';
import { RealtimeModule } from './realtime/realtime.module';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true, envFilePath: ['../../.env', '.env'] }), PrismaModule, AuthModule, RealtimeModule, ActivityModule, HouseholdsModule, ImportsModule, RecipesModule],
  controllers: [HealthController, MetricsController],
  providers: [],
})
export class AppModule {}
