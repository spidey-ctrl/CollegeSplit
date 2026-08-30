import { Injectable, NotFoundException } from '@nestjs/common';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { PrismaService } from '../prisma/prisma.service.js';
import { LedgerService } from '../ledger/ledger.service.js';
import {
  balanceShareText,
  expenseShareText,
  phoneDeepLink,
} from './text.js';
import type {
  ShareBalanceDto,
  ShareExpenseDto,
  SharePayload,
} from './share.dto.js';

/**
 * Generates what the client hands off to the device's native share sheet when
 * a Participant/Balance has no registered-User match (ticket 10). The
 * registered-User match (in-app notification) is a later ticket; this service
 * is the "native fallback" branch: a read-only text summary, pre-targeted at
 * the Participant's phone number when one is on file.
 *
 * Sharing is informational only — the payload carries text, never edit access,
 * and never merges Ledgers.
 */
@Injectable()
export class ShareService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
  ) {}

  async shareExpense(
    decoded: DecodedIdToken,
    dto: ShareExpenseDto,
  ): Promise<SharePayload> {
    const expense = await this.prisma.expense.findFirst({
      where: { id: dto.expenseId, userId: decoded.uid },
      include: { participants: true },
    });
    if (!expense) {
      throw new NotFoundException('Expense not found');
    }

    const text = expenseShareText(expense);

    // Pre-target only when the Expense names a single counterparty (the common
    // split-with-one-person case) and that person has a phone on file.
    const counterparties = expense.participants.filter((p) => !p.isUser);
    const sole = counterparties.length === 1 ? counterparties[0] : undefined;
    const phone = sole
      ? (await this.counterpartyPhone(decoded.uid, sole.name)) ?? sole.phoneNumber ?? null
      : null;
    return { text, target: this.targetFor(phone, text) };
  }

  async shareBalance(
    decoded: DecodedIdToken,
    dto: ShareBalanceDto,
  ): Promise<SharePayload> {
    const counterparty = dto.counterparty.trim();
    const ledger = await this.ledger.ledger(decoded.uid);
    const entry = ledger.entries.find((e) => e.counterparty === counterparty);
    if (!entry) {
      throw new NotFoundException('No open Balance with this counterparty');
    }

    const text = balanceShareText(counterparty, entry.balancePaise);
    const phone = await this.counterpartyPhone(decoded.uid, counterparty);
    return { text, target: this.targetFor(phone, text) };
  }

  /** Pre-targeted payload when a phone is on file; generic (no recipient)
   *  otherwise. */
  private targetFor(phone: string | null, text: string): SharePayload['target'] {
    return phone
      ? { kind: 'phone', phoneNumber: phone, deepLinkUrl: phoneDeepLink(phone, text) }
      : { kind: 'none' };
  }

  /**
   * The phone number on file for a counterparty: the remembered Contact's phone
   * when one exists, else the phone stored on the most recent Expense Participant
   * (covers one-off counterparties the User hasn't split with twice yet).
   */
  private async counterpartyPhone(
    userId: string,
    name: string,
  ): Promise<string | null> {
    const contact = await this.prisma.contact.findUnique({
      where: { userId_name: { userId, name } },
      select: { phoneNumber: true },
    });
    if (contact?.phoneNumber) return contact.phoneNumber;

    const participant = await this.prisma.participant.findFirst({
      where: { name, isUser: false, expense: { userId } },
      orderBy: { expense: { createdAt: 'desc' } },
      select: { phoneNumber: true },
    });
    return participant?.phoneNumber ?? null;
  }
}
