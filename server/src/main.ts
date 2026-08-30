import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import express from 'express';
import { AppModule } from './app.module.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bodyParser: false });
  // Voice capture posts base64 audio up to ~5MB; raise Nest's default 100KB limit.
  app.use(express.json({ limit: '6mb' }));
  app.use(express.urlencoded({ extended: true, limit: '6mb' }));
  app.enableCors();
  await app.listen(process.env.PORT ?? 3000);
}
await bootstrap();
