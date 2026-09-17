import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import { AuthService } from './auth.service';

describe('AuthService.refresh', () => {
  const sessionId = 'session-1';
  const rawSecret = 'raw-refresh-secret';
  const fullCredential = `${sessionId}.${rawSecret}`;

  function buildService(sessionRow: Record<string, unknown> | null) {
    const prisma = {
      session: {
        findUnique: jest.fn().mockResolvedValue(sessionRow),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: 'account-1',
          email: 'user@example.com',
        }),
      },
      $transaction: jest.fn((fn: (tx: unknown) => Promise<unknown>) =>
        fn({
          session: {
            create: jest.fn().mockResolvedValue({ id: 'session-2' }),
            updateMany: jest.fn().mockResolvedValue({ count: 1 }),
          },
        }),
      ),
    } as never;
    const jwt = {
      signAsync: jest.fn().mockResolvedValue('access-token'),
    } as never;
    const config = {
      getOrThrow: jest.fn().mockReturnValue('test-secret'),
    } as never;
    return new AuthService(prisma, jwt, config);
  }

  function sessionRow(refreshTokenHash: string) {
    return {
      id: sessionId,
      accountId: 'account-1',
      refreshTokenHash,
      expiresAt: new Date(Date.now() + 60_000),
      revokedAt: null,
    };
  }

  it('accepts the full sessionId.raw refresh credential', async () => {
    const hashOfRawSecretOnly = await argon2.hash(rawSecret, {
      type: argon2.argon2id,
    });
    const service = buildService(sessionRow(hashOfRawSecretOnly));

    const result = await service.refresh(fullCredential);

    expect(result.refreshToken).toBeDefined();
    expect(result.accessToken).toBe('access-token');
  });

  it('rejects a credential whose secret does not match', async () => {
    const hashOfOtherSecret = await argon2.hash('different-secret', {
      type: argon2.argon2id,
    });
    const service = buildService(sessionRow(hashOfOtherSecret));

    await expect(service.refresh(fullCredential)).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('rejects a revoked session', async () => {
    const hashOfRawSecretOnly = await argon2.hash(rawSecret, {
      type: argon2.argon2id,
    });
    const service = buildService(
      sessionRow(hashOfRawSecretOnly) as Record<string, unknown> & {
        revokedAt: Date;
      },
    );
    (service as unknown as { prisma: { session: { findUnique: unknown } } })
      .prisma.session.findUnique = jest.fn().mockResolvedValue({
      id: sessionId,
      accountId: 'account-1',
      refreshTokenHash: hashOfRawSecretOnly,
      expiresAt: new Date(Date.now() + 60_000),
      revokedAt: new Date(),
    });

    await expect(service.refresh(fullCredential)).rejects.toThrow(
      UnauthorizedException,
    );
  });
});
