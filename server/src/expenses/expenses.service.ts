import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import type { DecodedIdToken } from 'firebase-admin/auth';
import {
  Category as CategoryEnum,
  SplitMethod as SplitMethodEnum,
} from '../generated/prisma/enums.js';
import {
  assertCreateExpenseDto,
  type ExpenseView,
  type ParticipantMatch,
} from './dto.js';
import { computeShares, type SplitMethod } from './split.js';
import { ContactsService } from '../contacts/contacts.service.js';
import { resolveParticipant } from '../contacts/match.js';

@Injectable()
export class ExpensesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly contacts: ContactsService,
  ) {}

  async create(decoded: DecodedIdToken, body: unknown): Promise<ExpenseView> {
    assertCreateExpenseDto(body);

    // Ensure the owning User exists (first expense after sign-in).
    await this.provisionUser(decoded);

    const amountPaise = body.amountPaise;
    const category = body.category;
    const splitMethod = body.splitMethod;
    const participantInputs = body.participants ?? [];
    const isUserPayer = body.isUserPayer ?? true;

    // The Participants are the others who share the cost — the User is the
    // Payer, never a Participant of their own Expense (see the Ledger model).
    const shares = computeShares(
      splitMethod as SplitMethod,
      amountPaise,
      participantInputs.map((p) => ({ ...p })),
    );

    const payerName =
      body.payerName ??
      (isUserPayer ? (decoded.name ?? decoded.email ?? 'You') : shares[0]?.name);

    const requestPhones = this.requestPhoneByParticipant(participantInputs);

    const expense = await this.prisma.expense.create({
      data: {
        userId: decoded.uid,
        amount: amountPaise,
        category: category as CategoryEnum,
        payerName,
        isUserPayer,
        splitMethod: splitMethod as SplitMethodEnum,
        participants: {
          create: shares.map((s) => ({
            name: s.name,
            sharePaise: s.sharePaise,
            isUser: s.isUser,
            phoneNumber: requestPhones.get(s.name.trim()) ?? null,
          })),
        },
      },
      include: { participants: true },
    });

    return this.attachContacts(decoded.uid, expense, participantInputs);
  }

  /**
   * Lists every Expense in the User's history (newest first), used by the
   * history view (ticket 08). Settled Expenses are included so the client can
   * show their settled state and still offer edit/delete.
   */
  async list(userId: string): Promise<ExpenseView[]> {
    const expenses = await this.prisma.expense.findMany({
      where: { userId },
      include: { participants: true },
      orderBy: { createdAt: 'desc' },
    });
    return expenses.map((e) => this.toView(e));
  }

  /**
   * Edits a saved Expense (ticket 08). If the Expense had been settled, the
   * whole Balance it belonged to is reopened (every settled Expense contributing
   * to that counterparty's balance is un-settled) so the Ledger recalculates
   * fresh from the edited values.
   */
  async update(
    decoded: DecodedIdToken,
    id: string,
    body: unknown,
  ): Promise<ExpenseView> {
    assertCreateExpenseDto(body);

    const existing = await this.prisma.expense.findFirst({
      where: { id, userId: decoded.uid },
      include: { participants: true },
    });
    if (!existing) {
      throw new NotFoundException('Expense not found');
    }

    const amountPaise = body.amountPaise;
    const category = body.category;
    const splitMethod = body.splitMethod;
    const participantInputs = body.participants ?? [];
    const isUserPayer = body.isUserPayer ?? existing.isUserPayer;

    const shares = computeShares(
      splitMethod as SplitMethod,
      amountPaise,
      participantInputs.map((p) => ({ ...p })),
    );

    const payerName =
      body.payerName ??
      (isUserPayer
        ? (decoded.name ?? decoded.email ?? 'You')
        : shares[0]?.name);

    const requestPhones = this.requestPhoneByParticipant(participantInputs);

    // Editing a settled Expense reopens the Balance(s) it belonged to.
    if (existing.settled) {
      await this.reopenSettledBalances(
        decoded.uid,
        this.counterpartyNamesOf(existing),
      );
    }

    const expense = await this.prisma.expense.update({
      where: { id },
      data: {
        amount: amountPaise,
        category: category as CategoryEnum,
        payerName,
        isUserPayer,
        splitMethod: splitMethod as SplitMethodEnum,
        settled: false,
        participants: {
          deleteMany: {},
          create: shares.map((s) => ({
            name: s.name,
            sharePaise: s.sharePaise,
            isUser: s.isUser,
            phoneNumber: requestPhones.get(s.name.trim()) ?? null,
          })),
        },
      },
      include: { participants: true },
    });

    return this.attachContacts(decoded.uid, expense, participantInputs);
  }

  /**
   * Deletes a saved Expense (ticket 08). Like editing, deleting a settled
   * Expense reopens the Balance it belonged to so the Ledger stays accurate.
   */
  async remove(decoded: DecodedIdToken, id: string): Promise<void> {
    const existing = await this.prisma.expense.findFirst({
      where: { id, userId: decoded.uid },
      include: { participants: true },
    });
    if (!existing) {
      throw new NotFoundException('Expense not found');
    }

    if (existing.settled) {
      await this.reopenSettledBalances(
        decoded.uid,
        this.counterpartyNamesOf(existing),
        existing.id,
      );
    }

    await this.prisma.expense.delete({ where: { id } });
  }

  /**
   * Reopens the Balance(s) a settled Expense belonged to by un-settling every
   * settled Expense of the User that contributed to any of the given
   * counterparty names. The Ledger is a derived read, so the reopened amounts
   * are recomputed simply by including those Expenses again.
   */
  private async reopenSettledBalances(
    userId: string,
    counterpartyNames: string[],
    excludeId?: string,
  ): Promise<void> {
    const names = counterpartyNames
      .map((n) => n.trim())
      .filter((n) => n.length > 0);
    if (names.length === 0) return;

    const settled = await this.prisma.expense.findMany({
      where: { userId, settled: true },
      include: { participants: true },
    });

    const toReopen: string[] = [];
    for (const expense of settled) {
      if (expense.id === excludeId) continue;
      const expenseNames = this.counterpartyNamesOf(expense);
      if (expenseNames.some((n) => names.includes(n))) {
        toReopen.push(expense.id);
      }
    }
    if (toReopen.length > 0) {
      await this.prisma.expense.updateMany({
        where: { id: { in: toReopen } },
        data: { settled: false },
      });
    }
  }

  /**
   * The set of counterparty names an Expense contributes a Balance to, using
   * the same semantics as the Ledger derivation (and the Settle action):
   * participant names when the User pays; the Payer's name when the User shares
   * in an external Payer's Expense.
   */
  private counterpartyNamesOf(expense: {
    isUserPayer: boolean;
    payerName: string;
    participants: Array<{ name: string; isUser: boolean }>;
  }): string[] {
    if (expense.isUserPayer) {
      return expense.participants
        .filter((p) => !p.isUser)
        .map((p) => p.name.trim())
        .filter((n) => n.length > 0);
    }
    const userIsParticipant = expense.participants.some((p) => p.isUser);
    if (!userIsParticipant) return [];
    return [expense.payerName.trim()].filter((n) => n.length > 0);
  }

  /**
   * After an Expense is stored, (a) auto-create Contacts for Participants the
   * User has named on 2+ Expenses, and (b) resolve each Participant's name
   * against the User's Contacts, returning the match (autoLink/ambiguous) on
   * the view. Never blocks or guesses — ambiguous names surface for the User.
   */
  private async attachContacts(
    userId: string,
    expense: {
      id: string;
      amount: number;
      category: string;
      payerName: string;
      isUserPayer: boolean;
      splitMethod: string;
      settled: boolean;
      createdAt: Date;
      participants: Array<{ name: string; sharePaise: number; isUser: boolean }>;
    },
    participantInputs: Array<{ name: string; phoneNumber?: string }>,
  ): Promise<ExpenseView> {
    // Per-name phone captured from the request (the identity anchor for matching).
    const requestPhones = new Map<string, string>();
    for (const p of participantInputs) {
      const nm = p.name?.trim();
      const ph = p.phoneNumber?.trim();
      if (nm && ph) requestPhones.set(nm, ph);
    }

    // Auto-create Contacts once a name is used on 2+ Expenses.
    const uniqueNamed = expense.participants
      .filter((s) => !s.isUser)
      .map((s) => s.name.trim())
      .filter((n) => n.length > 0);
    for (const name of new Set(uniqueNamed)) {
      await this.contacts.ensureFromExpense(
        userId,
        name,
        requestPhones.get(name) ?? null,
      );
    }

    const contacts = await this.contacts.list(userId);
    const matches = new Map<string, ParticipantMatch>();
    for (const s of expense.participants) {
      if (s.isUser) continue;
      const name = s.name.trim();
      if (!name) continue;
      const result = resolveParticipant({
        name,
        phoneNumber: requestPhones.get(name) ?? null,
        contacts,
      });
      if (result.kind !== 'ephemeral') matches.set(name, result);
    }

    return this.toView(expense, matches);
  }

  /**
   * Maps each Participant name (trimmed) to the phone the User supplied in the
   * request, so a phone is persisted onto the Participant row (the identity
   * anchor Share uses to pre-target a native share-sheet hand-off).
   */
  private requestPhoneByParticipant(
    participantInputs: Array<{ name: string; phoneNumber?: string }>,
  ): Map<string, string> {
    const phones = new Map<string, string>();
    for (const p of participantInputs) {
      const nm = p.name?.trim();
      const ph = p.phoneNumber?.trim();
      if (nm && ph) phones.set(nm, ph);
    }
    return phones;
  }

  private async provisionUser(decoded: DecodedIdToken) {
    const email = decoded.email ?? `${decoded.uid}@users.noreply.collegesplit`;
    await this.prisma.user.upsert({
      where: { id: decoded.uid },
      update: { displayName: decoded.name ?? email, email },
      create: {
        id: decoded.uid,
        displayName: decoded.name ?? email,
        email,
      },
    });
  }

  private toView(
    expense: {
      id: string;
      amount: number;
      category: string;
      payerName: string;
      isUserPayer: boolean;
      splitMethod: string;
      settled: boolean;
      createdAt: Date;
      participants: Array<{ name: string; sharePaise: number; isUser: boolean }>;
    },
    matches?: Map<string, ParticipantMatch>,
  ): ExpenseView {
    return {
      id: expense.id,
      amountPaise: expense.amount,
      category: expense.category,
      payerName: expense.payerName,
      isUserPayer: expense.isUserPayer,
      splitMethod: expense.splitMethod,
      settled: expense.settled,
      createdAt: expense.createdAt.toISOString(),
      participants: expense.participants.map((p) => {
        const view: ExpenseView['participants'][number] = {
          name: p.name,
          sharePaise: p.sharePaise,
          isUser: p.isUser,
        };
        if (!p.isUser) {
          const match = matches?.get(p.name.trim());
          if (match) view.contactMatch = match;
        }
        return view;
      }),
    };
  }
}
