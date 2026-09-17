import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';
import { PrismaService } from '../prisma/prisma.service';

export interface PushMessage {
  title: string;
  body: string;
  deepLink: string;
}

@Injectable()
export class FcmPushService {
  private readonly logger = new Logger(FcmPushService.name);
  private messaging: Messaging | undefined;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async deliverToAccounts(accountIds: string[], message: PushMessage) {
    if (!this.isEnabled() || !accountIds.length) return { delivered: 0 };

    try {
      const subscriptions = await this.prisma.pushSubscription.findMany({
        where: { accountId: { in: accountIds }, platform: 'android' },
        select: { endpoint: true },
      });
      if (!subscriptions.length) return { delivered: 0 };

      const response = await this.client().sendEachForMulticast({
        tokens: subscriptions.map(({ endpoint }) => endpoint),
        notification: { title: message.title, body: message.body },
        data: { deepLink: message.deepLink },
        android: { priority: 'high' },
      });
      const invalidEndpoints = response.responses.flatMap((result, index) =>
        result.success || !this.isInvalidToken(result.error?.code)
          ? []
          : [subscriptions[index].endpoint],
      );
      if (invalidEndpoints.length) {
        await this.prisma.pushSubscription.deleteMany({
          where: { endpoint: { in: invalidEndpoints } },
        });
      }
      return { delivered: response.successCount };
    } catch (error) {
      this.logger.warn(
        `Firebase delivery failed; in-app notifications remain available. ${this.errorLabel(error)}`,
      );
      return { delivered: 0 };
    }
  }

  private isEnabled() {
    return (
      this.config.get<string>('FIREBASE_MESSAGING_ENABLED')?.trim().toLowerCase() ===
      'true'
    );
  }

  private client() {
    if (this.messaging) return this.messaging;
    const app =
      getApps().find((candidate) => candidate.name === 'pantrypal') ??
      initializeApp({ credential: applicationDefault() }, 'pantrypal');
    this.messaging = getMessaging(app);
    return this.messaging;
  }

  private isInvalidToken(code: string | undefined) {
    return (
      code === 'messaging/invalid-registration-token' ||
      code === 'messaging/registration-token-not-registered'
    );
  }

  private errorLabel(error: unknown) {
    return error instanceof Error ? error.message : 'Unknown Firebase error.';
  }
}
