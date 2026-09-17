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
import { PastedTextRecipeParserService } from './pasted-text-recipe-parser.service';
import { GeminiRecipeAnalysisProvider } from './gemini-recipe-analysis.provider';
import { YouTubeSourceAdapterService } from './youtube-source-adapter.service';
import { SocialSourceClassifierService } from './social-source-classifier.service';
import { MediaStorageService } from './media-storage.service';
import { MediaLifecycleService } from './media-lifecycle.service';
import { MediaToolService } from './media-tool.service';
import { GeminiFileService } from './gemini-file.service';
import { YouTubeMediaAcquisitionService } from './youtube-media-acquisition.service';
import { SocialMediaAcquisitionService } from './social-media-acquisition.service';

@Module({
  imports: [AuthModule, HouseholdsModule],
  controllers: [ImportsController],
  providers: [
    ImportsService,
    SourceUrlService,
    WebpageRecipeParserService,
    PastedTextRecipeParserService,
    DeterministicAnalysisProvider,
    GeminiRecipeAnalysisProvider,
    YouTubeSourceAdapterService,
    SocialSourceClassifierService,
    MediaStorageService,
    MediaLifecycleService,
    MediaToolService,
    GeminiFileService,
    YouTubeMediaAcquisitionService,
    SocialMediaAcquisitionService,
    ImportProcessorService,
    ImportQueueService,
    {
      provide: RECIPE_ANALYSIS_PROVIDER,
      useExisting: GeminiRecipeAnalysisProvider,
    },
  ],
  exports: [ImportProcessorService, MediaStorageService],
})
export class ImportsModule {}
