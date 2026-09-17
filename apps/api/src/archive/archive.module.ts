import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { HouseholdsModule } from '../households/households.module';
import { ImportsModule } from '../imports/imports.module';
import { ArchiveController } from './archive.controller';
import { ArchiveService } from './archive.service';

@Module({
  imports: [AuthModule, HouseholdsModule, ImportsModule],
  controllers: [ArchiveController],
  providers: [ArchiveService],
  exports: [ArchiveService],
})
export class ArchiveModule {}
