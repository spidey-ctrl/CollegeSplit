import 'dotenv/config';
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { PrismaService } from '../prisma/prisma.service.js';
import { ExpensesService } from '../expenses/expenses.service.js';
import { ContactsService } from './contacts.service.js';

describe('Contacts (ticket 05, real DB)', () => {
  let prisma: PrismaService;
  let contacts: ContactsService;
  let expenses: ExpensesService;
  const TEST_UID = `test-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;

  const decoded: DecodedIdToken = {
    uid: TEST_UID,
    name: 'Test Owner',
    email: `${TEST_UID}@example.com`,
    aud: 'collegesplit',
    auth_time: 0,
    exp: 0,
    firebase: { sign_in_provider: 'google.com' },
    iat: 0,
    iss: 'https://securetoken.google.com/collegesplit',
    sub: TEST_UID,
  };

  beforeAll(() => {
    prisma = new PrismaService();
    contacts = new ContactsService(prisma);
    expenses = new ExpensesService(prisma, contacts);
  });

  afterAll(async () => {
    await prisma.expense.deleteMany({ where: { userId: TEST_UID } });
    await prisma.contact.deleteMany({ where: { userId: TEST_UID } });
    await prisma.user.deleteMany({ where: { id: TEST_UID } });
    await prisma.$disconnect();
  });

  it('auto-creates a Contact after a 2nd distinct use and auto-links it', async () => {
    // First use: no Contact yet.
    await expenses.create(decoded, {
      amountPaise: 1000,
      category: 'FoodDrink',
      splitMethod: 'Equal',
      participants: [{ name: 'Dana', phoneNumber: '+91-1111111111' }],
    });
    let list = await contacts.list(TEST_UID);
    expect(list.find((c) => c.name === 'Dana')).toBeUndefined();

    // Second use: Contact auto-created and this participant auto-links to it.
    const second = await expenses.create(decoded, {
      amountPaise: 2000,
      category: 'FoodDrink',
      splitMethod: 'Equal',
      participants: [{ name: 'Dana', phoneNumber: '+91-1111111111' }],
    });
    list = await contacts.list(TEST_UID);
    const dana = list.find((c) => c.name === 'Dana');
    expect(dana).toBeDefined();
    expect(dana?.phoneNumber).toBe('+91-1111111111');

    const match = second.participants.find((p) => p.name === 'Dana')?.contactMatch;
    expect(match?.kind).toBe('autoLinked');
  });

  it('exact name match auto-links to the existing Contact silently', async () => {
    // Seed Evan as a Contact via two prior uses.
    for (let i = 0; i < 2; i++) {
      await expenses.create(decoded, {
        amountPaise: 500,
        category: 'Groceries',
        splitMethod: 'Equal',
        participants: [{ name: 'Evan', phoneNumber: '+91-2222222222' }],
      });
    }
    const third = await expenses.create(decoded, {
      amountPaise: 700,
      category: 'Groceries',
      splitMethod: 'Equal',
      participants: [{ name: 'Evan', phoneNumber: '+91-2222222222' }],
    });
    const match = third.participants.find((p) => p.name === 'Evan')?.contactMatch;
    expect(match?.kind).toBe('autoLinked');
    if (match?.kind === 'autoLinked') {
      expect(match.contactName).toBe('Evan');
    }
  });

  it('prompts disambiguation when the name matches 2+ Contacts', async () => {
    await prisma.contact.create({
      data: { userId: TEST_UID, name: 'Sam', phoneNumber: '+91-3333333333' },
    });
    await prisma.contact.create({
      data: { userId: TEST_UID, name: 'Sameer', phoneNumber: '+91-4444444444' },
    });

    const created = await expenses.create(decoded, {
      amountPaise: 900,
      category: 'Travel',
      splitMethod: 'Equal',
      participants: [{ name: 'Same', phoneNumber: '+91-5555555555' }],
    });
    const match = created.participants.find((p) => p.name === 'Same')?.contactMatch;
    expect(match?.kind).toBe('ambiguous');
  });

  it('treats a no-phone Participant as ephemeral (no auto-link) even on repeated use', async () => {
    await expenses.create(decoded, {
      amountPaise: 400,
      category: 'Other',
      splitMethod: 'Equal',
      participants: [{ name: 'Fay' }],
    });
    const second = await expenses.create(decoded, {
      amountPaise: 600,
      category: 'Other',
      splitMethod: 'Equal',
      participants: [{ name: 'Fay' }],
    });

    const participant = second.participants.find((p) => p.name === 'Fay')!;
    expect(participant.contactMatch).toBeUndefined();

    // Auto-created as a name-only Contact (accumulation) but never phone-anchored.
    const fay = (await contacts.list(TEST_UID)).find((c) => c.name === 'Fay');
    expect(fay?.phoneNumber).toBeNull();
  });
});
