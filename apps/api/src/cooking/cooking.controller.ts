import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AccessTokenGuard } from '../auth/access-token.guard';
import type { AuthenticatedRequest } from '../auth/auth.types';
import { CookingService } from './cooking.service';
import {
  CreateCookingInstanceDto,
  CookAgainDto,
  RequestCookTransferDto,
  ResolveCookTransferDto,
  UpdateCookingTripDto,
} from './cooking.dto';

@ApiTags('cooking')
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller('households/:householdId/cooking')
export class CookingController {
  constructor(private readonly cooking: CookingService) {}

  @Get()
  list(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
  ) {
    return this.cooking.list(request.user.sub, householdId);
  }

  @Post()
  create(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Body() input: CreateCookingInstanceDto,
  ) {
    return this.cooking.create(request.user.sub, householdId, input);
  }

  @Patch(':cookingInstanceId')
  assignTrip(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('cookingInstanceId') cookingInstanceId: string,
    @Body() input: UpdateCookingTripDto,
  ) {
    return this.cooking.assignTrip(
      request.user.sub,
      householdId,
      cookingInstanceId,
      input.shoppingTripId,
    );
  }

  @Post(':cookingInstanceId/cook-transfer')
  requestTransfer(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('cookingInstanceId') cookingInstanceId: string,
    @Body() input: RequestCookTransferDto,
  ) {
    return this.cooking.requestTransfer(
      request.user.sub,
      householdId,
      cookingInstanceId,
      input,
    );
  }

  @Post(':cookingInstanceId/cook-transfer/resolve')
  resolveTransfer(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('cookingInstanceId') cookingInstanceId: string,
    @Body() input: ResolveCookTransferDto,
  ) {
    return this.cooking.resolveTransfer(
      request.user.sub,
      householdId,
      cookingInstanceId,
      input,
    );
  }

  @Post(':cookingInstanceId/mark-cooked')
  markCooked(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('cookingInstanceId') cookingInstanceId: string,
  ) {
    return this.cooking.markCooked(
      request.user.sub,
      householdId,
      cookingInstanceId,
    );
  }

  @Post(':cookingInstanceId/cook-again')
  cookAgain(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('cookingInstanceId') cookingInstanceId: string,
    @Body() input: CookAgainDto,
  ) {
    return this.cooking.cookAgain(
      request.user.sub,
      householdId,
      cookingInstanceId,
      input,
    );
  }
}
