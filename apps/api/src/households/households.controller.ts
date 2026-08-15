import { Body, Controller, Get, HttpCode, Param, Post, UseGuards, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { AccessTokenGuard } from '../auth/access-token.guard';
import type { AuthenticatedRequest } from '../auth/auth.types';
import { JoinHouseholdDto } from './household.dto';
import { HouseholdsService } from './households.service';

@ApiTags('households')
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller('households')
export class HouseholdsController {
  constructor(private readonly households: HouseholdsService) {}

  @Get()
  @ApiOkResponse({ description: 'Active household memberships for the signed-in account.' })
  list(@Req() request: AuthenticatedRequest) {
    return this.households.list(request.user.sub);
  }

  @Post('join')
  join(@Req() request: AuthenticatedRequest, @Body() input: JoinHouseholdDto) {
    return this.households.join(request.user.sub, input.code);
  }

  @Get(':householdId/members')
  members(@Req() request: AuthenticatedRequest, @Param('householdId') householdId: string) {
    return this.households.members(request.user.sub, householdId);
  }

  @Post(':householdId/invite-code/rotate')
  rotateCode(@Req() request: AuthenticatedRequest, @Param('householdId') householdId: string) {
    return this.households.rotateCode(request.user.sub, householdId);
  }

  @Post(':householdId/leave')
  @HttpCode(204)
  leave(@Req() request: AuthenticatedRequest, @Param('householdId') householdId: string) {
    return this.households.leave(request.user.sub, householdId);
  }
}
