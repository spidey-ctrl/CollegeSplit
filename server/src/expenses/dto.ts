import { BadRequestException } from '@nestjs/common';
import { Category, SplitMethod } from '../generated/prisma/enums.js';

export const CATEGORIES = Object.values(Category);
export const SPLIT_METHODS = Object.values(SplitMethod);

export interface ExpenseParticipantDto {
  name: string;
  ratio?: number;
  sharePaise?: number;
  isUser?: boolean;
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
}

export interface ExpenseView {
  id: string;
  amountPaise: number;
  category: string;
  payerName: string;
  isUserPayer: boolean;
  splitMethod: string;
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
}
