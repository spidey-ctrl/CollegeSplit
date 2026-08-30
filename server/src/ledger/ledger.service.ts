import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

export interface LedgerEntry {
  counterparty: string;
  // Positive = this counterparty owes the User (User is owed).
  // Negative = the User owes this counterparty.
  balancePaise: number;
  // The id of the User's Contact for this counterparty, when one exists
  // (i.e. the person the User has split with 2+ times). Null for ephemeral
  // counterparties, which therefore cannot be settled (ticket 07).
  contactId: string | null;
}

export interface LedgerView {
  entries: LedgerEntry[];
  // How much the User is owed in total (sum of positive balances).
  totalOwedToUserPaise: number;
  // How much the User owes in total (sum of negative balances, as a positive number).
  totalUserOwesPaise: number;
}

/**
 * Computes the User's private Ledger — the net Balance with each counterparty —
 * entirely from their Expenses and Splits. No Balance is ever stored; it is
 * derived on demand.
 *
 * Semantics (ticket 02):
 *  - If the User is the Payer, every other Participant owes the User their share.
 *  - If an external (non-User) person is the Payer and the User is listed as a
 *    Participant, the User owes the Payer the User's own share.
 */
@Injectable()
export class LedgerService {
  constructor(private readonly prisma: PrismaService) {}

  async ledger(userId: string): Promise<LedgerView> {
    // Settled Expenses (ticket 07) no longer contribute to the running Balance.
    const expenses = await this.prisma.expense.findMany({
      where: { userId, settled: false },
      include: { participants: true },
      orderBy: { createdAt: 'asc' },
    });

    const balance = new Map<string, number>();

    for (const expense of expenses) {
      if (expense.isUserPayer) {
        for (const p of expense.participants) {
          if (p.isUser) continue;
          const key = p.name;
          balance.set(key, (balance.get(key) ?? 0) + p.sharePaise);
        }
      } else {
        // External Payer; only matters if the User is a Participant.
        const userPart = expense.participants.find((p) => p.isUser);
        if (userPart) {
          const key = expense.payerName;
          balance.set(key, (balance.get(key) ?? 0) - userPart.sharePaise);
        }
      }
    }

    // Map each counterparty name to the User's Contact (if any) so the client
    // can offer a Settle action only against a remembered person.
    const contactIdByName = await this.contactIdByCounterpartyName(userId);

    // Drop zero balances so counterparties with nothing owed don't clutter the
    // Ledger screen.
    const entries: LedgerEntry[] = Array.from(balance.entries())
      .filter(([, paise]) => paise !== 0)
      .map(([counterparty, balancePaise]) => ({
        counterparty,
        balancePaise,
        contactId: contactIdByName.get(counterparty) ?? null,
      }))
      .sort((a, b) => b.balancePaise - a.balancePaise);

    let totalOwedToUser = 0;
    let totalUserOwes = 0;
    for (const e of entries) {
      if (e.balancePaise > 0) totalOwedToUser += e.balancePaise;
      else totalUserOwes += Math.abs(e.balancePaise);
    }

    return {
      entries,
      totalOwedToUserPaise: totalOwedToUser,
      totalUserOwesPaise: totalUserOwes,
    };
  }

  /**
   * Settles the User's whole running Balance with a single Contact in one
   * action: marks every unsettled Expense that contributed to that
   * counterparty's Balance as settled, then returns the freshly-derived
   * Ledger (in which that counterparty's Balance is now zero).
   */
  async settle(userId: string, contactId: string): Promise<LedgerView> {
    const contact = await this.prisma.contact.findFirst({
      where: { id: contactId, userId },
    });
    if (!contact) {
      throw new NotFoundException('Contact not found');
    }

    // Find every unsettled Expense of the User that contributed to this
    // counterparty's Balance, using the same matching the Ledger derivation
    // applies (Participant name when User pays; Payer name when User shares in
    // an external Payer's Expense).
    const expenses = await this.prisma.expense.findMany({
      where: { userId, settled: false },
      include: { participants: true },
    });

    const contributing: string[] = [];
    for (const expense of expenses) {
      if (expense.isUserPayer) {
        const contributes = expense.participants.some(
          (p) => !p.isUser && p.name.trim() === contact.name.trim(),
        );
        if (contributes) contributing.push(expense.id);
      } else {
        const userPart = expense.participants.find((p) => p.isUser);
        if (
          userPart &&
          expense.payerName.trim() === contact.name.trim()
        ) {
          contributing.push(expense.id);
        }
      }
    }

    if (contributing.length > 0) {
      await this.prisma.expense.updateMany({
        where: { id: { in: contributing } },
        data: { settled: true },
      });
    }

    return this.ledger(userId);
  }

  private async contactIdByCounterpartyName(
    userId: string,
  ): Promise<Map<string, string>> {
    const contacts = await this.prisma.contact.findMany({
      where: { userId },
      select: { id: true, name: true },
    });
    return new Map(contacts.map((c) => [c.name, c.id]));
  }
}
