import 'dotenv/config';
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { PrismaService } from '../prisma/prisma.service.js';
import { ExpensesService } from './expenses.service.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { ContactsService } from '../contacts/contacts.service.js';

describe('Expenses edit/delete + reopen settled balance (ticket 08, real DB)', () => {
  let prisma: PrismaService;
  let expenses: ExpensesService;
  let ledger: LedgerService;
  let contacts: ContactsService;
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
    ledger = new LedgerService(prisma);
  });

  afterAll(async () => {
    // Owner User and everything they own cascade.
    await prisma.expense.deleteMany({ where: { userId: TEST_UID } });
    await prisma.contact.deleteMany({ where: { userId: TEST_UID } });
    await prisma.user.deleteMany({ where: { id: TEST_UID } });
    await prisma.$disconnect();
  });

  it('lists the User history with the settled flag', async () => {
    const created = await expenses.create(decoded, {
      amountPaise: 5000,
      category: 'FoodDrink',
      splitMethod: 'Equal',
      participants: [{ name: 'Listy' }],
    });
    const list = await expenses.list(TEST_UID);
    const found = list.find((e) => e.id === created.id);
    expect(found).toBeDefined();
    expect(found?.settled).toBe(false);
    // Newest first.
    expect(list[0].id).toBe(created.id);
  });

  it('editing a settled Expense reopens the Balance and recalculates it fresh', async () => {
    // Two Expenses with a fresh counterparty so they auto-accumulate into a Contact.
    const first = await expenses.create(decoded, {
      amountPaise: 2000,
      category: 'FoodDrink',
      splitMethod: 'Equal',
      participants: [{ name: 'Ed' }],
    });
    const second = await expenses.create(decoded, {
      amountPaise: 3000,
      category: 'Travel',
      splitMethod: 'Equal',
      participants: [{ name: 'Ed' }],
    });

    const before = await ledger.ledger(TEST_UID);
    const edBefore = before.entries.find((e) => e.counterparty === 'Ed');
    expect(edBefore?.balancePaise).toBe(5000);
    expect(edBefore?.contactId).not.toBeNull();

    await ledger.settle(TEST_UID, edBefore!.contactId!);
    expect(
      (await ledger.ledger(TEST_UID)).entries.find((e) => e.counterparty === 'Ed'),
    ).toBeUndefined();

    // Edit one of the contributing (now settled) Expenses.
    const updated = await expenses.update(decoded, first.id, {
      amountPaise: 4000,
      category: 'FoodDrink',
      splitMethod: 'Equal',
      participants: [{ name: 'Ed' }],
    });
    expect(updated.settled).toBe(false);

    // The balance is reopened and recalculated from BOTH expenses: 4000 + 3000.
    const after = await ledger.ledger(TEST_UID);
    const edAfter = after.entries.find((e) => e.counterparty === 'Ed');
    expect(edAfter?.balancePaise).toBe(7000);

    // Both contributing Expenses are now unsettled again.
    const remaining = await prisma.expense.findMany({
      where: { userId: TEST_UID, settled: false },
    });
    const edited = remaining.find((x) => x.id === first.id);
    const sibling = remaining.find((x) => x.id === second.id);
    expect(edited?.amount).toBe(4000);
    expect(sibling?.amount).toBe(3000);
  });

  it('deleting a settled Expense reopens the Balance and recalculates it fresh', async () => {
    const first = await expenses.create(decoded, {
      amountPaise: 1500,
      category: 'Groceries',
      splitMethod: 'Equal',
      participants: [{ name: 'Del' }],
    });
    await expenses.create(decoded, {
      amountPaise: 3500,
      category: 'Other',
      splitMethod: 'Equal',
      participants: [{ name: 'Del' }],
    });

    const before = await ledger.ledger(TEST_UID);
    const delBefore = before.entries.find((e) => e.counterparty === 'Del');
    expect(delBefore?.balancePaise).toBe(5000);
    await ledger.settle(TEST_UID, delBefore!.contactId!);

    // Delete one contributing (now settled) Expense.
    await expenses.remove(decoded, first.id);

    const after = await ledger.ledger(TEST_UID);
    const delAfter = after.entries.find((e) => e.counterparty === 'Del');
    // Only the remaining 3500 Expense contributes again.
    expect(delAfter?.balancePaise).toBe(3500);
  });

  it('editing/deleting an unsettled Expense has no reopen side effects', async () => {
    const keep = await expenses.create(decoded, {
      amountPaise: 700,
      category: 'Transport',
      splitMethod: 'Equal',
      participants: [{ name: 'Plain' }],
    });
    const drop = await expenses.create(decoded, {
      amountPaise: 500,
      category: 'Transport',
      splitMethod: 'Equal',
      participants: [{ name: 'Plain' }],
    });

    await expenses.update(decoded, keep.id, {
      amountPaise: 900,
      category: 'Transport',
      splitMethod: 'Equal',
      participants: [{ name: 'Plain' }],
    });
    await expenses.remove(decoded, drop.id);

    const ledgerNow = await ledger.ledger(TEST_UID);
    const plain = ledgerNow.entries.find((e) => e.counterparty === 'Plain');
    expect(plain?.balancePaise).toBe(900);
    expect(plain?.contactId).not.toBeNull();
  });
});
