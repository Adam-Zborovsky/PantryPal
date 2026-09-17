import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from '../app.module';

async function generate() {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.setGlobalPrefix('v1');
  await app.init();
  const document = SwaggerModule.createDocument(
    app,
    new DocumentBuilder()
      .setTitle('PantryPal API')
      .setDescription('Invite-only household recipe planning API.')
      .setVersion('1.0.0')
      .addBearerAuth()
      .build(),
    { include: [AppModule], deepScanRoutes: true },
  );
  writeFileSync(
    resolve(process.cwd(), '../../contracts/openapi.json'),
    `${JSON.stringify(document, null, 2)}\n`,
  );
  await app.close();
}

void generate();
