import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import { createHash, randomBytes } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { LoginDto, RegisterDto } from './auth.dto';
import { AccessClaims } from './auth.types';

const refreshLifetimeMs = 30 * 24 * 60 * 60 * 1000;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(input: RegisterDto) {
    const email = input.email.trim().toLowerCase();
    const betaInviteHash = this.hashToken(input.betaInvite);
    const existing = await this.prisma.account.findUnique({ where: { email } });
    if (existing) throw new ConflictException('An account already exists for this email.');

    const invite = await this.prisma.betaInvite.findUnique({ where: { tokenHash: betaInviteHash } });
    if (!invite || invite.redeemedAt || invite.expiresAt <= new Date()) {
      throw new UnauthorizedException('This beta invite is invalid, expired, or already used.');
    }

    const passwordHash = await argon2.hash(input.password, { type: argon2.argon2id });
    const householdCode = this.newToken();
    const account = await this.prisma.$transaction(async (tx) => {
      const redeemed = await tx.betaInvite.updateMany({
        where: { id: invite.id, redeemedAt: null },
        data: { redeemedAt: new Date() },
      });
      if (redeemed.count !== 1) throw new UnauthorizedException('This beta invite was just redeemed.');
      const created = await tx.account.create({ data: { email, displayName: input.displayName.trim(), passwordHash } });
      const household = await tx.household.create({ data: { name: input.householdName.trim(), timezone: input.timezone ?? 'UTC' } });
      await tx.householdMembership.create({ data: { householdId: household.id, accountId: created.id } });
      await tx.householdInviteCode.create({
        data: { householdId: household.id, codeHash: this.hashToken(householdCode), rotatedByAccountId: created.id },
      });
      await tx.betaInvite.update({ where: { id: invite.id }, data: { redeemedByAccountId: created.id } });
      return { ...created, household, householdCode };
    });
    const session = await this.createSession(account);
    return { ...session, account: this.accountSummary(account), household: account.household, householdCode };
  }

  async login(input: LoginDto) {
    const email = input.email.trim().toLowerCase();
    const account = await this.prisma.account.findUnique({ where: { email } });
    if (!account || !(await argon2.verify(account.passwordHash, input.password))) {
      throw new UnauthorizedException('Email or password is incorrect.');
    }
    const session = await this.createSession(account);
    return { ...session, account: this.accountSummary(account) };
  }

  async refresh(rawRefreshToken: string) {
    const [sessionId] = rawRefreshToken.split('.');
    if (!sessionId) throw new UnauthorizedException('Your refresh session is invalid.');
    const current = await this.prisma.session.findUnique({ where: { id: sessionId } });
    if (!current || current.revokedAt || current.expiresAt <= new Date() || !(await argon2.verify(current.refreshTokenHash, rawRefreshToken))) {
      throw new UnauthorizedException('Your refresh session is invalid or expired.');
    }
    const account = await this.prisma.account.findUniqueOrThrow({ where: { id: current.accountId } });
    return this.prisma.$transaction(async (tx) => {
      const revoked = await tx.session.updateMany({ where: { id: current.id, revokedAt: null }, data: { revokedAt: new Date() } });
      if (revoked.count !== 1) throw new UnauthorizedException('Your refresh session was already rotated.');
      return this.createSession(account, current.id, tx);
    });
  }

  async logout(rawRefreshToken?: string) {
    const sessionId = rawRefreshToken?.split('.')[0];
    if (sessionId) await this.prisma.session.updateMany({ where: { id: sessionId, revokedAt: null }, data: { revokedAt: new Date() } });
  }

  async createBetaInvite(expiresInDays = 14) {
    const token = this.newToken();
    const expiresAt = new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000);
    await this.prisma.betaInvite.create({ data: { tokenHash: this.hashToken(token), expiresAt } });
    return { token, expiresAt };
  }

  async resetPassword(email: string, password: string) {
    const account = await this.prisma.account.findUnique({ where: { email: email.trim().toLowerCase() } });
    if (!account) throw new UnauthorizedException('No account exists for this email.');
    const passwordHash = await argon2.hash(password, { type: argon2.argon2id });
    await this.prisma.$transaction([
      this.prisma.account.update({ where: { id: account.id }, data: { passwordHash } }),
      this.prisma.session.updateMany({ where: { accountId: account.id, revokedAt: null }, data: { revokedAt: new Date() } }),
    ]);
  }

  private async createSession(
    account: { id: string; email: string },
    rotatedFromId?: string,
    client: PrismaService | Prisma.TransactionClient = this.prisma,
  ) {
    const raw = this.newToken();
    const session = await client.session.create({
      data: { accountId: account.id, refreshTokenHash: await argon2.hash(raw, { type: argon2.argon2id }), expiresAt: new Date(Date.now() + refreshLifetimeMs), rotatedFromId },
    });
    const claims: AccessClaims = { sub: account.id, email: account.email, sessionId: session.id };
    const accessToken = await this.jwt.signAsync(claims, {
      secret: this.config.getOrThrow<string>('ACCESS_TOKEN_SECRET'),
      expiresIn: '15m',
    });
    return { accessToken, refreshToken: `${session.id}.${raw}`, refreshExpiresAt: session.expiresAt };
  }

  private hashToken(value: string) {
    return createHash('sha256').update(value.trim()).digest('base64url');
  }

  private newToken() {
    return randomBytes(32).toString('base64url');
  }

  private accountSummary(account: { id: string; email: string; displayName: string }) {
    return { id: account.id, email: account.email, displayName: account.displayName };
  }
}
