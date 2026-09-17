import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import { AccessClaims } from './auth.types';

@Injectable()
export class AccessTokenGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context
      .switchToHttp()
      .getRequest<Request & { user?: AccessClaims }>();
    const token = request.headers.authorization?.replace(/^Bearer\s+/i, '');
    if (!token)
      throw new UnauthorizedException('A valid access token is required.');
    try {
      request.user = await this.jwt.verifyAsync<AccessClaims>(token, {
        secret: this.config.getOrThrow<string>('ACCESS_TOKEN_SECRET'),
      });
      return true;
    } catch {
      throw new UnauthorizedException(
        'Your session has expired. Sign in again.',
      );
    }
  }
}
