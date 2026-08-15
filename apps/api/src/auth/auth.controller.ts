import { Body, Controller, HttpCode, Post, Req, Res, UnauthorizedException } from '@nestjs/common';
import { ApiCreatedResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import type { Request, Response } from 'express';
import { randomUUID } from 'node:crypto';
import { AuthService } from './auth.service';
import { AuthSessionResponseDto, LoginDto, RefreshDto, RegisterDto } from './auth.dto';

const refreshCookie = 'pantrypal_refresh';
const csrfCookie = 'pantrypal_csrf';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  @ApiCreatedResponse({ description: 'Account and first household created.', type: AuthSessionResponseDto })
  async register(@Body() input: RegisterDto, @Res({ passthrough: true }) response: Response) {
    const result = await this.auth.register(input);
    return this.respondWithSession(result, input.client ?? 'web', response);
  }

  @Post('login')
  @HttpCode(200)
  @ApiOkResponse({ description: 'Session established.', type: AuthSessionResponseDto })
  async login(@Body() input: LoginDto, @Res({ passthrough: true }) response: Response) {
    const result = await this.auth.login(input);
    return this.respondWithSession(result, input.client ?? 'web', response);
  }

  @Post('refresh')
  @HttpCode(200)
  @ApiOkResponse({ type: AuthSessionResponseDto })
  async refresh(@Body() input: RefreshDto, @Req() request: Request, @Res({ passthrough: true }) response: Response) {
    const client = input.client ?? 'web';
    this.requireCsrf(request, client);
    const raw = client === 'web' ? request.cookies?.[refreshCookie] : input.refreshToken;
    const result = await this.auth.refresh(raw ?? '');
    return this.respondWithSession(result, client, response);
  }

  @Post('logout')
  @HttpCode(204)
  async logout(@Body() input: RefreshDto, @Req() request: Request, @Res({ passthrough: true }) response: Response) {
    const client = input.client ?? 'web';
    this.requireCsrf(request, client);
    await this.auth.logout(client === 'web' ? request.cookies?.[refreshCookie] : input.refreshToken);
    response.clearCookie(refreshCookie, this.cookieOptions());
    response.clearCookie(csrfCookie, { sameSite: 'strict', secure: this.isProduction() });
  }

  private respondWithSession(
    result: Record<string, unknown>,
    client: 'web' | 'android',
    response: Response,
  ) {
    if (client === 'web') {
      response.cookie(refreshCookie, result.refreshToken, this.cookieOptions(result.refreshExpiresAt as Date));
      response.cookie(csrfCookie, randomUUID(), { httpOnly: false, sameSite: 'strict', secure: this.isProduction() });
      const { refreshToken, ...webResult } = result;
      return webResult;
    }
    return result;
  }

  private cookieOptions(expires?: Date) {
    return { httpOnly: true, sameSite: 'strict' as const, secure: this.isProduction(), expires, path: '/v1/auth' };
  }

  private isProduction() {
    return process.env.APP_ENV === 'production';
  }

  private requireCsrf(request: Request, client: 'web' | 'android') {
    if (client === 'web' && (!request.cookies?.[csrfCookie] || request.headers['x-csrf-token'] !== request.cookies[csrfCookie])) {
      throw new UnauthorizedException('Your browser security token is missing or expired. Sign in again.');
    }
  }
}
