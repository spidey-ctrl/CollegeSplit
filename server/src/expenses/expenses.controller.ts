import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { ExpensesService } from './expenses.service.js';

@Controller('expenses')
@UseGuards(FirebaseAuthGuard)
export class ExpensesController {
  constructor(private readonly expensesService: ExpensesService) {}

  @Post()
  create(
    @CurrentUser() decoded: DecodedIdToken,
    @Body() body: unknown,
  ) {
    return this.expensesService.create(decoded, body);
  }
}
