import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { HouseholdsModule } from '../households/households.module';
import { ImportsController } from './imports.controller';
import { ImportsService } from './imports.service';
import { SourceUrlService } from './source-url.service';
import { WebpageRecipeParserService } from './webpage-recipe-parser.service';
import { DeterministicAnalysisProvider } from './deterministic-analysis.provider';
import { RECIPE_ANALYSIS_PROVIDER } from './recipe-analysis.provider';
import { ImportProcessorService } from './import-processor.service';
import { ImportQueueService } from './import-queue.service';

@Module({ imports: [AuthModule, HouseholdsModule], controllers: [ImportsController], providers: [ImportsService, SourceUrlService, WebpageRecipeParserService, DeterministicAnalysisProvider, ImportProcessorService, ImportQueueService, { provide: RECIPE_ANALYSIS_PROVIDER, useExisting: DeterministicAnalysisProvider }], exports: [ImportProcessorService] })
export class ImportsModule {}
