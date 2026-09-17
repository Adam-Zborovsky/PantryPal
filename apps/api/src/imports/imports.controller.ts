import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { AccessTokenGuard } from '../auth/access-token.guard';
import type { AuthenticatedRequest } from '../auth/auth.types';
import {
  CompleteMediaUploadResponseDto,
  CreateImportDto,
  CreateMediaUploadDto,
  MediaUploadResponseDto,
} from './imports.dto';
import { ImportsService } from './imports.service';
import { MediaStorageService } from './media-storage.service';

@ApiTags('imports')
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller('households/:householdId/imports')
export class ImportsController {
  constructor(
    private readonly imports: ImportsService,
    private readonly media: MediaStorageService,
  ) {}

  @Post('media-assets/upload-url')
  @ApiCreatedResponse({ type: MediaUploadResponseDto })
  createMediaUpload(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Body() input: CreateMediaUploadDto,
  ): Promise<MediaUploadResponseDto> {
    return this.media.createUpload(request.user.sub, householdId, input);
  }

  @Post('media-assets/:assetId/complete')
  @HttpCode(HttpStatus.OK)
  @ApiOkResponse({ type: CompleteMediaUploadResponseDto })
  completeMediaUpload(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('assetId') assetId: string,
  ): Promise<CompleteMediaUploadResponseDto> {
    return this.media.completeUpload(request.user.sub, householdId, assetId);
  }

  @Post() create(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Body() input: CreateImportDto,
  ) {
    return this.imports.create(request.user.sub, householdId, input);
  }
  @Get(':id') get(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('id') id: string,
  ) {
    return this.imports.get(request.user.sub, householdId, id);
  }
  @Post(':id/cancel') cancel(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('id') id: string,
  ) {
    return this.imports.cancel(request.user.sub, householdId, id);
  }
}
