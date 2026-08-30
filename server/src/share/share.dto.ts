import { BadRequestException } from '@nestjs/common';

export interface ShareExpenseDto {
  expenseId: string;
}

export interface ShareBalanceDto {
  counterparty: string;
}

/** What the client hands to the native share sheet (ticket 10). */
export type ShareTarget =
  | { kind: 'none' }
  | { kind: 'phone'; phoneNumber: string; deepLinkUrl: string };

export interface SharePayload {
  /**
   * Read-only text summary of the shared Expense/Balance. Sharing is
   * informational only — it never carries edit rights or merges Ledgers.
   */
  text: string;
  target: ShareTarget;
}

export function assertShareExpenseDto(body: unknown): asserts body is ShareExpenseDto {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be a JSON object');
  }
  const b = body as Record<string, unknown>;
  if (typeof b.expenseId !== 'string' || b.expenseId.length === 0) {
    throw new BadRequestException('expenseId is required');
  }
}

export function assertShareBalanceDto(body: unknown): asserts body is ShareBalanceDto {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be a JSON object');
  }
  const b = body as Record<string, unknown>;
  if (typeof b.counterparty !== 'string' || b.counterparty.trim().length === 0) {
    throw new BadRequestException('counterparty is required');
  }
}
