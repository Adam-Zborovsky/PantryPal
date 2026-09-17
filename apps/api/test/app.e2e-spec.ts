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
    await prisma.notification.deleteMany();
    await prisma.pantryAssessment.deleteMany();
    await prisma.shoppingItemContribution.deleteMany();
    await prisma.shoppingItem.deleteMany();
    await prisma.tripRecipeAssignment.deleteMany();
    await prisma.cookAssignmentTransfer.deleteMany();
    await prisma.cookingInstance.deleteMany();
    await prisma.shoppingTrip.deleteMany();
    await prisma.recipeInstruction.deleteMany();
    await prisma.recipeIngredient.deleteMany();
    await prisma.recipeSource.deleteMany();
    await prisma.recipeVersion.deleteMany();
    await prisma.recipe.deleteMany();
    await prisma.activityEvent.deleteMany();
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

  it('persists cooking assignments, aggregates a trip, and invalidates confirmation after a date edit', async () => {
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
        email: 'planner@example.com',
        password: 'secure-password-123',
        displayName: 'Planner',
        betaInvite: invite,
        householdName: 'Planning household',
        client: 'android',
      })
      .expect(201);
    const token = registration.body.accessToken as string;
    const householdId = registration.body.household.id as string;
    const accountId = registration.body.account.id as string;
    const otherMember = await prisma.account.create({
      data: {
        email: 'member@example.com',
        displayName: 'Member',
        passwordHash: 'not-used-in-this-test',
      },
    });
    await prisma.householdMembership.create({
      data: { householdId, accountId: otherMember.id },
    });
    const recipe = await prisma.recipe.create({
      data: {
        householdId,
        title: 'Tomato soup',
        readiness: 'SHOPPING_READY',
      },
    });
    const version = await prisma.recipeVersion.create({
      data: {
        householdId,
        recipeId: recipe.id,
        version: 1,
        title: recipe.title,
        originalServings: '2',
        readiness: 'SHOPPING_READY',
        snapshot: {},
        createdByAccountId: accountId,
      },
    });
    await prisma.recipe.update({
      where: { id: recipe.id },
      data: { currentVersionId: version.id },
    });
    await prisma.recipeIngredient.create({
      data: {
        householdId,
        recipeVersionId: version.id,
        name: 'Tomatoes',
        quantityMin: '3',
        originalUnit: 'each',
        originalText: '3 tomatoes',
        includeInShopping: true,
        sortOrder: 0,
      },
    });
    await request(app.getHttpServer())
      .get(`/v1/households/${householdId}/recipes`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) =>
        expect(body).toEqual([
          expect.objectContaining({
            id: recipe.id,
            title: 'Tomato soup',
            readiness: 'SHOPPING_READY',
          }),
        ]),
      );
    const firstDate = '2026-08-20T10:00:00.000Z';
    const trip = await request(app.getHttpServer())
      .post(`/v1/households/${householdId}/trips`)
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduledFor: firstDate })
      .expect(201);
    const cooking = await request(app.getHttpServer())
      .post(`/v1/households/${householdId}/cooking`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        recipeId: recipe.id,
        targetServings: '4',
        cookingDate: '2026-08-21T18:00:00.000Z',
        shoppingTripId: trip.body.id,
      })
      .expect(201);
    await expect(
      prisma.tripRecipeAssignment.findUnique({
        where: {
          shoppingTripId_cookingInstanceId: {
            shoppingTripId: trip.body.id,
            cookingInstanceId: cooking.body.id,
          },
        },
      }),
    ).resolves.toMatchObject({ assignmentMode: 'AUTOMATIC' });
    await request(app.getHttpServer())
      .post(`/v1/households/${householdId}/trips/${trip.body.id}/confirm`)
      .set('Authorization', `Bearer ${token}`)
      .expect(201)
      .expect(({ body }) => expect(body.status).toBe('CONFIRMED'));
    const detail = await request(app.getHttpServer())
      .get(`/v1/households/${householdId}/trips/${trip.body.id}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(detail.body.items).toEqual([
      expect.objectContaining({
        displayName: 'Tomatoes',
        quantityMin: '6',
        contributions: [
          expect.objectContaining({
            cookingInstanceId: cooking.body.id,
            recipeTitle: 'Tomato soup',
          }),
        ],
      }),
    ]);
    await request(app.getHttpServer())
      .patch(`/v1/households/${householdId}/trips/${trip.body.id}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduledFor: '2026-08-22T10:00:00.000Z' })
      .expect(200)
      .expect(({ body }) => expect(body.status).toBe('PROPOSED'));
    await expect(
      prisma.cookingInstance.findUnique({ where: { id: cooking.body.id } }),
    ).resolves.toMatchObject({ shoppingTripId: null });
    await expect(
      prisma.tripRecipeAssignment.findUnique({
        where: {
          shoppingTripId_cookingInstanceId: {
            shoppingTripId: trip.body.id,
            cookingInstanceId: cooking.body.id,
          },
        },
      }),
    ).resolves.toBeNull();
    await expect(
      prisma.notification.findFirst({
        where: {
          householdId,
          accountId: otherMember.id,
          title: 'Shopping date changed',
        },
      }),
    ).resolves.toMatchObject({
      title: 'Shopping date changed',
      deepLink: `/households/${householdId}/trips/${trip.body.id}`,
    });
    await request(app.getHttpServer())
      .post(
        `/v1/households/${householdId}/cooking/${cooking.body.id}/mark-cooked`,
      )
      .set('Authorization', `Bearer ${token}`)
      .expect(201)
      .expect(({ body }) => expect(body.status).toBe('ARCHIVED'));
    await request(app.getHttpServer())
      .get(`/v1/households/${householdId}/archive`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) =>
        expect(body).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              id: cooking.body.id,
              recipeId: recipe.id,
              targetServings: '4',
            }),
          ]),
        ),
      );
    await request(app.getHttpServer())
      .post(
        `/v1/households/${householdId}/cooking/${cooking.body.id}/cook-again`,
      )
      .set('Authorization', `Bearer ${token}`)
      .send({
        targetServings: '6',
        cookingDate: '2026-08-27T18:00:00.000Z',
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body).toMatchObject({
          recipeId: recipe.id,
          targetServings: '6',
          status: 'SCHEDULED',
        });
        expect(body.id).not.toBe(cooking.body.id);
      });
  });

  it('requires the invited household member to accept a cook handoff and keeps their notifications private', async () => {
    const primaryInvite = randomBytes(32).toString('base64url');
    const secondaryInvite = randomBytes(32).toString('base64url');
    await prisma.betaInvite.createMany({
      data: [primaryInvite, secondaryInvite].map((token) => ({
        tokenHash: createHash('sha256').update(token).digest('base64url'),
        expiresAt: new Date(Date.now() + 60_000),
      })),
    });
    const primary = await request(app.getHttpServer())
      .post('/v1/auth/register')
      .send({
        email: 'handoff-owner@example.com',
        password: 'secure-password-123',
        displayName: 'Handoff owner',
        betaInvite: primaryInvite,
        householdName: 'Handoff household',
        client: 'android',
      })
      .expect(201);
    const secondary = await request(app.getHttpServer())
      .post('/v1/auth/register')
      .send({
        email: 'handoff-member@example.com',
        password: 'secure-password-123',
        displayName: 'Handoff member',
        betaInvite: secondaryInvite,
        householdName: 'Member household',
        client: 'android',
      })
      .expect(201);
    const householdId = primary.body.household.id as string;
    const primaryToken = primary.body.accessToken as string;
    const secondaryToken = secondary.body.accessToken as string;
    const secondaryAccountId = secondary.body.account.id as string;

    await request(app.getHttpServer())
      .get(`/v1/households/${householdId}/recipes`)
      .set('Authorization', `Bearer ${secondaryToken}`)
      .expect(403);
    await request(app.getHttpServer())
      .post('/v1/households/join')
      .set('Authorization', `Bearer ${secondaryToken}`)
      .send({ code: primary.body.householdCode })
      .expect(201);

    const recipe = await prisma.recipe.create({
      data: {
        householdId,
        title: 'Handoff pasta',
        readiness: 'SHOPPING_READY',
      },
    });
    const version = await prisma.recipeVersion.create({
      data: {
        householdId,
        recipeId: recipe.id,
        version: 1,
        title: recipe.title,
        originalServings: '2',
        readiness: 'SHOPPING_READY',
        snapshot: {},
        createdByAccountId: primary.body.account.id as string,
      },
    });
    await prisma.recipe.update({
      where: { id: recipe.id },
      data: { currentVersionId: version.id },
    });
    const cooking = await request(app.getHttpServer())
      .post(`/v1/households/${householdId}/cooking`)
      .set('Authorization', `Bearer ${primaryToken}`)
      .send({
        recipeId: recipe.id,
        targetServings: '2',
        cookingDate: '2026-08-24T18:00:00.000Z',
      })
      .expect(201);

    await request(app.getHttpServer())
      .post(
        `/v1/households/${householdId}/cooking/${cooking.body.id}/cook-transfer`,
      )
      .set('Authorization', `Bearer ${primaryToken}`)
      .send({ targetAccountId: secondaryAccountId })
      .expect(201)
      .expect(({ body }) => expect(body.status).toBe('PENDING'));

    const memberInbox = await request(app.getHttpServer())
      .get(`/v1/households/${householdId}/notifications`)
      .set('Authorization', `Bearer ${secondaryToken}`)
      .expect(200);
    const handoffRequest = memberInbox.body.find(
      (notification: { title: string }) =>
        notification.title === 'Cook handoff requested',
    );
    expect(handoffRequest).toMatchObject({
      accountId: secondaryAccountId,
      deepLink: `/households/${householdId}/cooking/${cooking.body.id}`,
      readAt: null,
    });
    await request(app.getHttpServer())
      .post(
        `/v1/households/${householdId}/notifications/${handoffRequest.id}/read`,
      )
      .set('Authorization', `Bearer ${secondaryToken}`)
      .expect(201)
      .expect(({ body }) => expect(body.readAt).toEqual(expect.any(String)));

    await request(app.getHttpServer())
      .post(
        `/v1/households/${householdId}/cooking/${cooking.body.id}/cook-transfer/resolve`,
      )
      .set('Authorization', `Bearer ${secondaryToken}`)
      .send({ accept: true })
      .expect(201)
      .expect(({ body }) => {
        expect(body.confirmedCookAccountId).toBe(secondaryAccountId);
        expect(body.pendingCookAccountId).toBeNull();
      });

    await request(app.getHttpServer())
      .get(`/v1/households/${householdId}/notifications`)
      .set('Authorization', `Bearer ${primaryToken}`)
      .expect(200)
      .expect(({ body }) =>
        expect(body).toEqual(
          expect.arrayContaining([
            expect.objectContaining({ title: 'Cook handoff updated' }),
          ]),
        ),
      );
    await request(app.getHttpServer())
      .get(`/v1/households/${householdId}/notifications`)
      .set('Authorization', `Bearer ${secondaryToken}`)
      .expect(200)
      .expect(({ body }) =>
        expect(body).not.toEqual(
          expect.arrayContaining([
            expect.objectContaining({ title: 'Cook handoff updated' }),
          ]),
        ),
      );
  });

  afterEach(async () => {
    await app?.close();
  });

  afterAll(async () => prisma.$disconnect());
});
