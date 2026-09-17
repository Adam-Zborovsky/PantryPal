import { JwtService } from '@nestjs/jwt';
import type { Socket } from 'socket.io';
import { RealtimeGateway } from './realtime.gateway';

describe('RealtimeGateway', () => {
  const verifyAsync = jest.fn();
  const getOrThrow = jest.fn(() => 'test-secret');
  const findUnique = jest.fn();

  const gateway = () =>
    new RealtimeGateway(
      { verifyAsync } as unknown as JwtService,
      { getOrThrow } as never,
      {
        householdMembership: { findUnique },
      } as never,
    );

  const client = {
    data: { claims: { sub: 'account-1' } },
    join: jest.fn().mockResolvedValue(undefined),
  } as unknown as Socket;

  beforeEach(() => {
    jest.clearAllMocks();
    verifyAsync.mockResolvedValue({ sub: 'account-1' });
  });

  it('joins the household room for a bare-string payload', async () => {
    findUnique.mockResolvedValue({
      status: 'ACTIVE',
      householdId: 'household-1',
      accountId: 'account-1',
    });
    const result = await gateway().subscribe(client, 'household-1');
    expect(result).toEqual({ householdId: 'household-1' });
    expect(client.join).toHaveBeenCalledWith('household:household-1');
    expect(findUnique).toHaveBeenCalledWith({
      where: {
        householdId_accountId: {
          householdId: 'household-1',
          accountId: 'account-1',
        },
      },
    });
  });

  it('rejects a missing or malformed payload without querying membership', async () => {
    await expect(gateway().subscribe(client, undefined)).rejects.toThrow();
    await expect(gateway().subscribe(client, 42 as never)).rejects.toThrow();
    await expect(gateway().subscribe(client, '')).rejects.toThrow();
    await expect(
      gateway().subscribe(client, { householdId: 'x' } as never),
    ).rejects.toThrow();
    expect(findUnique).not.toHaveBeenCalled();
  });

  it('rejects an inactive member', async () => {
    findUnique.mockResolvedValue(null);
    await expect(gateway().subscribe(client, 'household-1')).rejects.toThrow();
  });
});
