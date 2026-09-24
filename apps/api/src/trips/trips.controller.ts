import {
  Body,
  Controller,
  Get,
  Patch,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AccessTokenGuard } from '../auth/access-token.guard';
import type { AuthenticatedRequest } from '../auth/auth.types';
import {
  CreateShoppingTripDto,
  CreateShoppingItemDto,
  UpdateShoppingItemDto,
  UpdateShoppingTripDto,
} from './trips.dto';
import { TripsService } from './trips.service';

@ApiTags('trips')
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller('households/:householdId/trips')
export class TripsController {
  constructor(private readonly trips: TripsService) {}
  @Get() list(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
  ) {
    return this.trips.list(request.user.sub, householdId);
  }
  @Post() create(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Body() input: CreateShoppingTripDto,
  ) {
    return this.trips.create(request.user.sub, householdId, input);
  }
  @Get(':tripId') detail(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('tripId') tripId: string,
  ) {
    return this.trips.detail(request.user.sub, householdId, tripId);
  }
  @Patch(':tripId') update(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('tripId') tripId: string,
    @Body() input: UpdateShoppingTripDto,
  ) {
    return this.trips.update(request.user.sub, householdId, tripId, input);
  }
  @Post(':tripId/confirm') confirm(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('tripId') tripId: string,
  ) {
    return this.trips.confirm(request.user.sub, householdId, tripId);
  }
  @Post(':tripId/start') start(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('tripId') tripId: string,
  ) {
    return this.trips.start(request.user.sub, householdId, tripId);
  }
  @Post(':tripId/complete') complete(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('tripId') tripId: string,
  ) {
    return this.trips.complete(request.user.sub, householdId, tripId);
  }
  @Post(':tripId/cancel') cancel(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('tripId') tripId: string,
  ) {
    return this.trips.cancel(request.user.sub, householdId, tripId);
  }
  @Post(':tripId/items')
  createItem(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('tripId') tripId: string,
    @Body() input: CreateShoppingItemDto,
  ) {
    return this.trips.createManualItem(
      request.user.sub,
      householdId,
      tripId,
      input,
    );
  }
  @Patch(':tripId/items/:itemId') updateItem(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('tripId') tripId: string,
    @Param('itemId') itemId: string,
    @Body() input: UpdateShoppingItemDto,
  ) {
    return this.trips.updateItem(
      request.user.sub,
      householdId,
      tripId,
      itemId,
      input,
    );
  }
}
