import { Body, Controller, Delete, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AccessTokenGuard } from '../auth/access-token.guard';
import type { AuthenticatedRequest } from '../auth/auth.types';
import {
  RemovePushSubscriptionDto,
  UpsertPushSubscriptionDto,
} from './push-subscriptions.dto';
import { PushSubscriptionsService } from './push-subscriptions.service';

@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller('push-subscriptions')
export class PushSubscriptionsController {
  constructor(private readonly subscriptions: PushSubscriptionsService) {}

  @Post()
  upsert(
    @Req() request: AuthenticatedRequest,
    @Body() input: UpsertPushSubscriptionDto,
  ) {
    return this.subscriptions.upsert(request.user.sub, input);
  }

  @Delete()
  remove(
    @Req() request: AuthenticatedRequest,
    @Body() input: RemovePushSubscriptionDto,
  ) {
    return this.subscriptions.remove(request.user.sub, input.endpoint);
  }
}
