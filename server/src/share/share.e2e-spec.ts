import 'dotenv/config';
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { PrismaService } from '../prisma/prisma.service.js';
import { ExpensesService } from '../expenses/expenses.service.js';
import { ContactsService } from '../contacts/contacts.service.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { ShareService } from '../share/share.service.js';

describe('Share (ticket 10, real DB)', () => {
  let prisma: PrismaService;
  let expenses: ExpensesService;
  let share: ShareService;
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
    expenses = new ExpensesService(prisma, new ContactsService(prisma));
    share = new ShareService(prisma, new LedgerService(prisma));
  });

  afterAll(async () => {
    await prisma.expense.deleteMany({ where: { userId: TEST_UID } });
    await prisma.contact.deleteMany({ where: { userId: TEST_UID } });
    await prisma.user.deleteMany({ where: { id: TEST_UID } });
    await prisma.$disconnect();
  });

  it('shares a single Expense pre-targeted at the Participant phone when one is on file', async () => {
    const created = await expenses.create(decoded, {
      amountPaise: 12000,
      category: 'FoodDrink',
      splitMethod: 'Equal',
      participants: [{ name: 'Priya', phoneNumber: '+91-9999999999' }],
    });

    const payload = await share.shareExpense(decoded, { expenseId: created.id });

    // Read-only summary of the whole Expense.
    expect(payload.text).toContain('₹120.00');
    expect(payload.text).toContain('Food & Drink');
    expect(payload.text).toContain('Paid by Test Owner');
    expect(payload.text).toContain('Priya');

    // Pre-targeted at the phone via a WhatsApp deep link.
    expect(payload.target.kind).toBe('phone');
    if (payload.target.kind === 'phone') {
      expect(payload.target.phoneNumber).toBe('+91-9999999999');
      expect(decodeURIComponent(payload.target.deepLinkUrl)).toContain(
        'wa.me/919999999999',
      );
      expect(decodeURIComponent(payload.target.deepLinkUrl)).toContain('Priya');
    }
  });

  it('shares a single Expense with a generic sheet when there is no phone on file', async () => {
    const created = await expenses.create(decoded, {
      amountPaise: 500,
      category: 'Transport',
      splitMethod: 'Equal',
      participants: [{ name: 'Evan' }],
    });

    const payload = await share.shareExpense(decoded, { expenseId: created.id });
    expect(payload.target.kind).toBe('none');
    expect(payload.text).toContain('₹5.00');
    expect(payload.text).toContain('Evan');
  });

  it('shares an aggregate Balance pre-targeted via the counterparty Contact phone', async () => {
    await prisma.contact.create({
      data: { userId: TEST_UID, name: 'Dana', phoneNumber: '+91-8888888888' },
    });
    await expenses.create(decoded, {
      amountPaise: 3000,
      category: 'Groceries',
      splitMethod: 'Equal',
      participants: [{ name: 'Dana' }],
    });

    const payload = await share.shareBalance(decoded, { counterparty: 'Dana' });

    // The balance direction: this counterparty owes the User.
    expect(payload.text).toContain('Dana owes you');
    expect(payload.text).toContain('₹30.00');
    expect(payload.target.kind).toBe('phone');
    if (payload.target.kind === 'phone') {
      expect(decodeURIComponent(payload.target.deepLinkUrl)).toContain(
        'wa.me/918888888888',
      );
    }
  });

  it('shares an aggregate Balance generically for an ephemeral counterparty', async () => {
    await expenses.create(decoded, {
      amountPaise: 8000,
      category: 'Other',
      splitMethod: 'Equal',
      participants: [{ name: 'Fay' }],
    });

    const payload = await share.shareBalance(decoded, { counterparty: 'Fay' });
    expect(payload.text).toContain('Fay owes you');
    expect(payload.text).toContain('₹80.00');
    expect(payload.target.kind).toBe('none');
  });

  it('refuses to share an Expense that is not owned by the User', async () => {
    const outsider = decoded.uid.replace(/^test-/, 'test-outsider-');
    const foreignUser = await prisma.user.upsert({
      where: { id: outsider },
      update: {},
      create: { id: outsider, displayName: 'Other', email: `${outsider}@example.com` },
    });
    const foreign = await prisma.expense.create({
      data: {
        userId: foreignUser.id,
        amount: 1000,
        category: 'FoodDrink',
        payerName: 'Other',
        splitMethod: 'Equal',
        participants: { create: [{ name: 'Zed', sharePaise: 1000 }] },
      },
    });

    await expect(
      share.shareExpense(decoded, { expenseId: foreign.id }),
    ).rejects.toThrow();

    await prisma.expense.deleteMany({ where: { userId: foreignUser.id } });
    await prisma.user.deleteMany({ where: { id: foreignUser.id } });
  });
});
