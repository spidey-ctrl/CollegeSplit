import { BadRequestException } from '@nestjs/common';
import { Category, SplitMethod } from '../generated/prisma/enums.js';

export const CATEGORIES = Object.values(Category);
export const SPLIT_METHODS = Object.values(SplitMethod);

export interface ExpenseParticipantDto {
  name: string;
  ratio?: number;
  sharePaise?: number;
  isUser?: boolean;
  // Optional phone, used for local Contact matching (ticket 05). Name-only
  // Participants (no phone) are treated as ephemeral and never fuzzy-matched.
  phoneNumber?: string;
}

export interface CreateExpenseDto {
  // Total spend in paise (1 INR = 100 paise). Integer only.
  amountPaise: number;
  category: string;
  // Who fronted the money. Defaults to the owning User's displayName.
  payerName?: string;
  // Whether the Payer is the owning User. Defaults to true.
  isUserPayer?: boolean;
  splitMethod: string;
  participants?: ExpenseParticipantDto[];
}

export interface ParticipantView {
  name: string;
  sharePaise: number;
  isUser: boolean;
  contactMatch?: ParticipantMatch;
}

/** How a Participant's name resolved against the User's Contact list (ticket 05). */
export type ParticipantMatch =
  | { kind: 'autoLinked'; contactId: string; contactName: string }
  | { kind: 'ambiguous'; matches: Array<{ contactId: string; name: string }> }
  | { kind: 'ephemeral' };

export interface ExpenseView {
  id: string;
  amountPaise: number;
  category: string;
  payerName: string;
  isUserPayer: boolean;
  splitMethod: string;
  // Whether the running Balance this Expense contributed to has been settled
  // (ticket 07). Editing or deleting a settled Expense reopens that Balance.
  settled: boolean;
  createdAt: string;
  participants: ParticipantView[];
}

/** Lightweight manual validation (no class-validator dependency in this repo). */
export function assertCreateExpenseDto(body: unknown): asserts body is CreateExpenseDto {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be a JSON object');
  }
  const b = body as Record<string, unknown>;

  if (typeof b.category !== 'string' || !CATEGORIES.includes(b.category as Category)) {
    throw new BadRequestException(
      `category must be one of: ${CATEGORIES.join(', ')}`,
    );
  }
  if (typeof b.splitMethod !== 'string' || !SPLIT_METHODS.includes(b.splitMethod as SplitMethod)) {
    throw new BadRequestException(
      `splitMethod must be one of: ${SPLIT_METHODS.join(', ')}`,
    );
  }
  if (typeof b.amountPaise !== 'number' || !Number.isInteger(b.amountPaise) || b.amountPaise <= 0) {
    throw new BadRequestException('amountPaise must be a positive integer');
  }
  if (b.payerName !== undefined && typeof b.payerName !== 'string') {
    throw new BadRequestException('payerName must be a string');
  }
  if (b.isUserPayer !== undefined && typeof b.isUserPayer !== 'boolean') {
    throw new BadRequestException('isUserPayer must be a boolean');
  }
  if (b.participants !== undefined && !Array.isArray(b.participants)) {
    throw new BadRequestException('participants must be an array');
  }
  if (Array.isArray(b.participants)) {
    for (const p of b.participants as unknown[]) {
      if (typeof p !== 'object' || p === null) {
        throw new BadRequestException('each participant must be an object');
      }
      const pp = p as Record<string, unknown>;
      if (typeof pp.name !== 'string') {
        throw new BadRequestException('each participant needs a name');
      }
      if (pp.phoneNumber !== undefined && typeof pp.phoneNumber !== 'string') {
        throw new BadRequestException('participant phoneNumber must be a string');
      }
    }
  }
}
