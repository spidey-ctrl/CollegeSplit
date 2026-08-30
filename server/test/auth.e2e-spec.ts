import 'dotenv/config';
import { generateKeyPairSync } from 'node:crypto';
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module.js';

describe('FirebaseAuthGuard (e2e)', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    const { privateKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
      publicKeyEncoding: { type: 'spki', format: 'pem' },
    });
    const fakeSa = {
      type: 'service_account',
      project_id: 'collegesplit',
      private_key_id: 'fake000000000000000000000000000000000000',
      private_key: privateKey,
      client_email: 'fake@collegesplit.iam.gserviceaccount.com',
      client_id: '000000000000000000000',
    };
    process.env.FIREBASE_SERVICE_ACCOUNT = JSON.stringify(fakeSa);

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    delete process.env.FIREBASE_SERVICE_ACCOUNT;
    await app.close();
  });

  it('GET /users/me returns 401 when no bearer token is supplied', async () => {
    const res = await request(app.getHttpServer()).get('/users/me');
    expect(res.status).toBe(401);
  });
});
