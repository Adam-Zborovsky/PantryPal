import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { HealthController } from './health/health.controller';
import { MetricsController } from './health/metrics.controller';
import { HouseholdsModule } from './households/households.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true, envFilePath: ['../../.env', '.env'] }), PrismaModule, AuthModule, HouseholdsModule],
  controllers: [HealthController, MetricsController],
  providers: [],
})
export class AppModule {}
