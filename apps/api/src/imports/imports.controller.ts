import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AccessTokenGuard } from '../auth/access-token.guard';
import type { AuthenticatedRequest } from '../auth/auth.types';
import { CreateImportDto } from './imports.dto';
import { ImportsService } from './imports.service';

@ApiTags('imports')
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller('households/:householdId/imports')
export class ImportsController {
  constructor(private readonly imports: ImportsService) {}
  @Post() create(@Req() request: AuthenticatedRequest, @Param('householdId') householdId: string, @Body() input: CreateImportDto) { return this.imports.create(request.user.sub, householdId, input); }
  @Get(':id') get(@Req() request: AuthenticatedRequest, @Param('householdId') householdId: string, @Param('id') id: string) { return this.imports.get(request.user.sub, householdId, id); }
  @Post(':id/cancel') cancel(@Req() request: AuthenticatedRequest, @Param('householdId') householdId: string, @Param('id') id: string) { return this.imports.cancel(request.user.sub, householdId, id); }
}
