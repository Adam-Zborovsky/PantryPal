import {
  BadRequestException,
  Injectable,
  OnModuleDestroy,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';
import { AccessClaims } from '../auth/auth.types';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
@WebSocketGateway({
  namespace: '/v1/realtime',
  cors: {
    origin: process.env.APP_ORIGIN ?? 'http://localhost:3000',
    credentials: true,
  },
})
export class RealtimeGateway implements OnGatewayConnection, OnModuleDestroy {
  @WebSocketServer() server!: Server;
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  afterInit(server: Server) {
    const url = process.env.REDIS_URL;
    if (
      !url ||
      process.env.NODE_ENV === 'test' ||
      process.env.JEST_WORKER_ID ||
      typeof server.adapter !== 'function'
    )
      return;
    const publisher = new Redis(url);
    const subscriber = publisher.duplicate();
    server.adapter(createAdapter(publisher, subscriber));
    this.redis = [publisher, subscriber];
  }
  private redis?: [Redis, Redis];

  async onModuleDestroy() {
    await Promise.all(this.redis?.map((client) => client.quit()) ?? []);
  }

  async handleConnection(client: Socket) {
    try {
      const token =
        client.handshake.auth.token ??
        client.handshake.headers.authorization?.replace(/^Bearer\s+/i, '');
      client.data.claims = await this.jwt.verifyAsync<AccessClaims>(token, {
        secret: this.config.getOrThrow<string>('ACCESS_TOKEN_SECRET'),
      });
    } catch {
      client.disconnect(true);
    }
  }

  @SubscribeMessage('household.subscribe')
  async subscribe(
    @ConnectedSocket() client: Socket,
    // @MessageBody() is required: undecorated gateway parameters are never
    // populated by the WebSocket proxy and silently arrive as undefined.
    @MessageBody() householdId: unknown,
  ) {
    if (!client.data.claims) throw new UnauthorizedException();
    if (typeof householdId !== 'string' || householdId.length === 0) {
      throw new BadRequestException(
        'household.subscribe requires a householdId string.',
      );
    }
    const membership = await this.prisma.householdMembership.findUnique({
      where: {
        householdId_accountId: {
          householdId,
          accountId: client.data.claims.sub,
        },
      },
    });
    if (!membership || membership.status !== 'ACTIVE')
      throw new UnauthorizedException();
    await client.join(`household:${householdId}`);
    return { householdId };
  }

  publish(
    householdId: string,
    event: string,
    payload: Record<string, unknown>,
  ) {
    this.server?.to(`household:${householdId}`).emit(event, payload);
  }
}
