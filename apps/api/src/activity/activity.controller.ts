import { Controller, Get, Param, Query, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { AccessTokenGuard } from '../auth/access-token.guard';
import type { AuthenticatedRequest } from '../auth/auth.types';
import { ActivityService } from './activity.service';

@ApiTags('activity')
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller('households/:householdId/activity')
export class ActivityController {
  constructor(private readonly activity: ActivityService) {}
  @Get()
  @ApiOkResponse({ description: 'Newest household activity events.' })
  list(@Req() request: AuthenticatedRequest, @Param('householdId') householdId: string, @Query('limit') limit?: string) {
    return this.activity.list(householdId, request.user.sub, Number(limit ?? 50));
  }
}
