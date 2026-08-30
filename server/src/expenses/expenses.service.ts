import { Injectable } from '@nestjs/common';
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

    const shares = computeShares(
      splitMethod as SplitMethod,
      amountPaise,
      participantInputs.map((p) => ({ ...p })),
    );

    const payerName =
      body.payerName ??
      (isUserPayer ? (decoded.name ?? decoded.email ?? 'You') : shares[0]?.name);

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
          })),
        },
      },
      include: { participants: true },
    });

    return this.attachContacts(decoded.uid, expense, participantInputs);
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
