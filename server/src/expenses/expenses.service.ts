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
} from './dto.js';
import { computeShares, type SplitMethod } from './split.js';

@Injectable()
export class ExpensesService {
  constructor(private readonly prisma: PrismaService) {}

  async create(decoded: DecodedIdToken, body: unknown): Promise<ExpenseView> {
    assertCreateExpenseDto(body);

    // Ensure the owning User exists (first expense after sign-in).
    await this.provisionUser(decoded);

    const amountPaise = body.amountPaise;
    const category = body.category;
    const splitMethod = body.splitMethod;
    const participants = body.participants ?? [];
    const isUserPayer = body.isUserPayer ?? true;

    const shares = computeShares(
      splitMethod as SplitMethod,
      amountPaise,
      participants.map((p) => ({ ...p })),
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

    return this.toView(expense);
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

  private toView(expense: {
    id: string;
    amount: number;
    category: string;
    payerName: string;
    isUserPayer: boolean;
    splitMethod: string;
    createdAt: Date;
    participants: Array<{ name: string; sharePaise: number; isUser: boolean }>;
  }): ExpenseView {
    return {
      id: expense.id,
      amountPaise: expense.amount,
      category: expense.category,
      payerName: expense.payerName,
      isUserPayer: expense.isUserPayer,
      splitMethod: expense.splitMethod,
      createdAt: expense.createdAt.toISOString(),
      participants: expense.participants.map((p) => ({
        name: p.name,
        sharePaise: p.sharePaise,
        isUser: p.isUser,
      })),
    };
  }
}
