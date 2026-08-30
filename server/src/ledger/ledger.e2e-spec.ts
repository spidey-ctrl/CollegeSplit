import 'dotenv/config';
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { PrismaService } from '../prisma/prisma.service.js';
import { ExpensesService } from '../expenses/expenses.service.js';
import { LedgerService } from './ledger.service.js';
import { ContactsService } from '../contacts/contacts.service.js';

describe('Expenses + Ledger (ticket 02, real DB)', () => {
  let prisma: PrismaService;
  let expenses: ExpensesService;
  let ledger: LedgerService;
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
    ledger = new LedgerService(prisma);
  });

  afterAll(async () => {
    // Owner User and everything they own cascade.
    await prisma.expense.deleteMany({ where: { userId: TEST_UID } });
    await prisma.user.deleteMany({ where: { id: TEST_UID } });
    await prisma.$disconnect();
  });

  it('creates an Equal split expense and reflects it on the ledger', async () => {
    const created = await expenses.create(decoded, {
      amountPaise: 12000,
      category: 'FoodDrink',
      splitMethod: 'Equal',
      participants: [
        { name: 'Alice' },
        { name: 'Bob' },
        { name: 'Carol' },
      ],
    });

    expect(created.amountPaise).toBe(12000);
    expect(created.category).toBe('FoodDrink');
    expect(created.isUserPayer).toBe(true);
    expect(created.participants.reduce((s, p) => s + p.sharePaise, 0)).toBe(12000);
    expect(created.participants.map((p) => p.sharePaise)).toEqual([4000, 4000, 4000]);

    const l = await ledger.ledger(TEST_UID);
    const alice = l.entries.find((e) => e.counterparty === 'Alice');
    const bob = l.entries.find((e) => e.counterparty === 'Bob');
    const carol = l.entries.find((e) => e.counterparty === 'Carol');
    expect(alice?.balancePaise).toBe(4000);
    expect(bob?.balancePaise).toBe(4000);
    expect(carol?.balancePaise).toBe(4000);
    expect(l.totalOwedToUserPaise).toBe(12000);
    expect(l.totalUserOwesPaise).toBe(0);
  });

  it('computes a Ratio split and aggregates into the running balance', async () => {
    await expenses.create(decoded, {
      amountPaise: 3000,
      category: 'Transport',
      splitMethod: 'Ratio',
      participants: [
        { name: 'Alice', ratio: 2 },
        { name: 'Bob', ratio: 1 },
      ],
    });

    const l = await ledger.ledger(TEST_UID);
    const alice = l.entries.find((e) => e.counterparty === 'Alice');
    const bob = l.entries.find((e) => e.counterparty === 'Bob');
    // Alice now owes 4000 + 2000 = 6000; Bob owes 4000 + 1000 = 5000
    expect(alice?.balancePaise).toBe(6000);
    expect(bob?.balancePaise).toBe(5000);
    expect(l.totalOwedToUserPaise).toBe(15000);
  });

  it('creates an Adhoc split with exact per-participant shares', async () => {
    const created = await expenses.create(decoded, {
      amountPaise: 10000,
      category: 'Groceries',
      splitMethod: 'Adhoc',
      participants: [
        { name: 'Alice', sharePaise: 2500 },
        { name: 'Bob', sharePaise: 7500 },
      ],
    });
    expect(created.participants.map((p) => p.sharePaise)).toEqual([2500, 7500]);

    const l = await ledger.ledger(TEST_UID);
    const alice = l.entries.find((e) => e.counterparty === 'Alice');
    const bob = l.entries.find((e) => e.counterparty === 'Bob');
    expect(alice?.balancePaise).toBe(8500);
    expect(bob?.balancePaise).toBe(12500);
  });

  it('creates a personal (zero-participant) expense with no ledger entries', async () => {
    await expenses.create(decoded, {
      amountPaise: 5000,
      category: 'Other',
      splitMethod: 'Equal',
      participants: [],
    });

    const l = await ledger.ledger(TEST_UID);
    // Total owed stays as before (25000 after the Adhoc test), no new entry.
    expect(l.totalOwedToUserPaise).toBe(25000);
  });

  it('rejects an Adhoc split whose shares do not sum to the amount', async () => {
    await expect(
      expenses.create(decoded, {
        amountPaise: 1000,
        category: 'FoodDrink',
        splitMethod: 'Adhoc',
        participants: [
          { name: 'Alice', sharePaise: 300 },
          { name: 'Bob', sharePaise: 300 },
        ],
      }),
    ).rejects.toThrow();
  });

  it('settles the whole running Balance with a counterparty and marks every contributing Expense settled', async () => {
    // Two Expenses with a fresh counterparty so they auto-accumulate into a Contact.
    await expenses.create(decoded, {
      amountPaise: 2000,
      category: 'FoodDrink',
      splitMethod: 'Equal',
      participants: [{ name: 'Sel' }],
    });
    await expenses.create(decoded, {
      amountPaise: 8000,
      category: 'Travel',
      splitMethod: 'Adhoc',
      participants: [{ name: 'Sel', sharePaise: 8000 }],
    });

    const before = await ledger.ledger(TEST_UID);
    const selEntry = before.entries.find((e) => e.counterparty === 'Sel');
    expect(selEntry?.balancePaise).toBe(10000);
    expect(selEntry?.contactId).not.toBeNull();

    const after = await ledger.settle(TEST_UID, selEntry!.contactId!);

    // The whole running Balance with Sel is now zero (entry dropped).
    expect(after.entries.find((e) => e.counterparty === 'Sel')).toBeUndefined();

    // Every Expense that contributed to Sel's Balance is marked settled.
    const settledExpenses = await prisma.expense.findMany({
      where: { userId: TEST_UID, settled: true },
      include: { participants: true },
    });
    const contributingToSel = settledExpenses.filter((x) =>
      x.participants.some((p) => p.name === 'Sel'),
    );
    expect(contributingToSel.length).toBe(2);
    expect(contributingToSel.reduce((s, x) => s + x.amount, 0)).toBe(10000);
  });
});
