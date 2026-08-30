import 'dotenv/config';
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { PrismaService } from '../prisma/prisma.service.js';

describe('User persistence (ticket 01 walking skeleton)', () => {
  let prisma: PrismaService;
  const TEST_UID = `test-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;

  beforeAll(() => {
    prisma = new PrismaService();
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: TEST_UID } });
    await prisma.$disconnect();
  });

  it('persists a User in Postgres on first sign-in via upsert', async () => {
    const email = `${TEST_UID}@example.com`;

    const created = await prisma.user.upsert({
      where: { id: TEST_UID },
      update: { displayName: 'Test User', email },
      create: { id: TEST_UID, displayName: 'Test User', email },
    });

    expect(created.id).toBe(TEST_UID);
    expect(created.displayName).toBe('Test User');
    expect(created.email).toBe(email);

    const fetched = await prisma.user.findUnique({ where: { id: TEST_UID } });
    expect(fetched).toMatchObject({
      id: TEST_UID,
      displayName: 'Test User',
      email,
    });
  });
});
