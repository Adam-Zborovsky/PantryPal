import { Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AccessTokenGuard } from '../auth/access-token.guard';
import type { AuthenticatedRequest } from '../auth/auth.types';
import { NotificationsService } from './notifications.service';
@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller('households/:householdId/notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}
  @Get() list(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
  ) {
    return this.notifications.list(request.user.sub, householdId);
  }
  @Post(':notificationId/read') markRead(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('notificationId') notificationId: string,
  ) {
    return this.notifications.markRead(
      request.user.sub,
      householdId,
      notificationId,
    );
  }
}
