import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { ExpensesService } from './expenses.service.js';

@Controller('expenses')
@UseGuards(FirebaseAuthGuard)
export class ExpensesController {
  constructor(private readonly expensesService: ExpensesService) {}

  @Post()
  create(@CurrentUser() decoded: DecodedIdToken, @Body() body: unknown) {
    return this.expensesService.create(decoded, body);
  }

  @Get()
  list(@CurrentUser() decoded: DecodedIdToken) {
    return this.expensesService.list(decoded.uid);
  }

  @Patch(':id')
  update(
    @CurrentUser() decoded: DecodedIdToken,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    return this.expensesService.update(decoded, id, body);
  }

  @Delete(':id')
  remove(@CurrentUser() decoded: DecodedIdToken, @Param('id') id: string) {
    return this.expensesService.remove(decoded, id);
  }
}
