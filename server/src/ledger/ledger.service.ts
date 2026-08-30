import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

export interface LedgerEntry {
  counterparty: string;
  // Positive = this counterparty owes the User (User is owed).
  // Negative = the User owes this counterparty.
  balancePaise: number;
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
    const expenses = await this.prisma.expense.findMany({
      where: { userId },
      include: { participants: true },
      orderBy: { createdAt: 'asc' },
    });

    const balance = new Map<string, number>();

    for (const expense of expenses) {
      if (expense.isUserPayer) {
        for (const p of expense.participants) {
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

    // Drop zero balances so counterparties with nothing owed don't clutter the
    // Ledger screen.
    const entries: LedgerEntry[] = Array.from(balance.entries())
      .filter(([, paise]) => paise !== 0)
      .map(([counterparty, balancePaise]) => ({
        counterparty,
        balancePaise,
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
}
