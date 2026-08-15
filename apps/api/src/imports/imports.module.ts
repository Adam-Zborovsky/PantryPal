import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { HouseholdsModule } from '../households/households.module';
import { ImportsController } from './imports.controller';
import { ImportsService } from './imports.service';
import { SourceUrlService } from './source-url.service';

@Module({ imports: [AuthModule, HouseholdsModule], controllers: [ImportsController], providers: [ImportsService, SourceUrlService] })
export class ImportsModule {}
