import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';

@ApiTags('system')
@Controller()
export class HealthController {
  @Get('live')
  @ApiOkResponse({ description: 'The API process is live.' })
  live() {
    return { status: 'ok' };
  }

  @Get('ready')
  @ApiOkResponse({ description: 'The API is ready to accept requests.' })
  ready() {
    return { status: 'ready', dependencies: 'unverified' };
  }
}
