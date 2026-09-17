import { ActivityService } from './activity.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

describe('ActivityService', () => {
  it('includes the domain summary in realtime events so clients can refetch the affected entity', async () => {
    const createdAt = new Date('2026-08-16T12:00:00.000Z');
    const prisma = {
      activityEvent: {
        create: jest.fn().mockResolvedValue({
          id: 'activity-1',
          createdAt,
        }),
      },
    } as unknown as PrismaService;
    const realtime = { publish: jest.fn() } as unknown as RealtimeGateway;
    const service = new ActivityService(prisma, realtime);
    const actor = { accountId: 'account-1', displayName: 'Alex' };
    const summary = { tripId: 'trip-1', status: 'NEED_TO_BUY' };

    await service.record(
      'household-1',
      actor,
      'shopping_trip',
      'item-1',
      'shopping_item.changed',
      summary,
    );

    expect(realtime.publish).toHaveBeenNthCalledWith(
      1,
      'household-1',
      'household.activity.created',
      expect.objectContaining({
        entityId: 'activity-1',
        actor,
        action: 'shopping_item.changed',
        summary,
      }),
    );
    expect(realtime.publish).toHaveBeenNthCalledWith(
      2,
      'household-1',
      'shopping_item.changed',
      expect.objectContaining({
        entityId: 'item-1',
        actor,
        action: 'shopping_item.changed',
        summary,
      }),
    );
  });
});
