import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  Res,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { AccessTokenGuard } from '../auth/access-token.guard';
import type { AuthenticatedRequest } from '../auth/auth.types';
import { MediaStorageService } from '../imports/media-storage.service';
import { ArchiveService } from './archive.service';
import { CompleteCoverUploadDto, CreateCoverUploadDto } from './archive.dto';

@ApiTags('archive')
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller('households/:householdId/archive')
export class ArchiveController {
  constructor(
    private readonly archive: ArchiveService,
    private readonly media: MediaStorageService,
  ) {}

  @Get()
  list(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
  ) {
    return this.archive.list(request.user.sub, householdId);
  }

  @Post(':cookingInstanceId/cover/upload-request')
  createCoverUploadRequest(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('cookingInstanceId') cookingInstanceId: string,
    @Body() dto: CreateCoverUploadDto,
  ) {
    return this.media.createCoverUpload(
      request.user.sub,
      householdId,
      cookingInstanceId,
      dto,
    );
  }

  @Post(':cookingInstanceId/cover/complete')
  completeCoverUpload(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('cookingInstanceId') cookingInstanceId: string,
    @Body() dto: CompleteCoverUploadDto,
  ) {
    return this.media.completeCoverUpload(
      request.user.sub,
      householdId,
      cookingInstanceId,
      dto.assetId,
    );
  }

  @Get(':cookingInstanceId/cover')
  async cover(
    @Res({ passthrough: true }) response: Response,
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('cookingInstanceId') cookingInstanceId: string,
  ): Promise<StreamableFile> {
    const { bytes, mimeType } = await this.media.readCoverBytes(
      request.user.sub,
      householdId,
      cookingInstanceId,
    );
    response.set('Content-Type', mimeType);
    return new StreamableFile(bytes);
  }
}
