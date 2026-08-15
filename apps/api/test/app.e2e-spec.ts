import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import cookieParser from 'cookie-parser';
import { PrismaClient } from '@prisma/client';
import { createHash, randomBytes } from 'node:crypto';
import { config } from 'dotenv';
import { AppModule } from './../src/app.module';

config({ path: '../../.env' });

describe('HealthController (e2e)', () => {
  let app: INestApplication<App>;
  const prisma = new PrismaClient();

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('v1');
    app.use(cookieParser());
    await app.init();
    await prisma.householdInviteCode.deleteMany();
    await prisma.householdMembership.deleteMany();
    await prisma.household.deleteMany();
    await prisma.session.deleteMany();
    await prisma.account.deleteMany();
    await prisma.betaInvite.deleteMany();
  });

  it('/v1/live (GET)', () => {
    return request(app.getHttpServer())
      .get('/v1/live')
      .expect(200)
      .expect({ status: 'ok' });
  });

  it('registers through a beta invite then scopes household access to the session', async () => {
    const invite = randomBytes(32).toString('base64url');
    await prisma.betaInvite.create({
      data: {
        tokenHash: createHash('sha256').update(invite).digest('base64url'),
        expiresAt: new Date(Date.now() + 60_000),
      },
    });
    const registration = await request(app.getHttpServer())
      .post('/v1/auth/register')
      .send({
        email: 'alex@example.com',
        password: 'secure-password-123',
        displayName: 'Alex',
        betaInvite: invite,
        householdName: 'Alex household',
        client: 'android',
      })
      .expect(201);

    expect(registration.body.accessToken).toEqual(expect.any(String));
    expect(registration.body.householdCode).toEqual(expect.any(String));
    await request(app.getHttpServer())
      .get('/v1/households')
      .set('Authorization', `Bearer ${registration.body.accessToken}`)
      .expect(200)
      .expect(({ body }) => expect(body).toHaveLength(1));
  });

  afterEach(async () => {
    await app?.close();
  });

  afterAll(async () => prisma.$disconnect());
});
