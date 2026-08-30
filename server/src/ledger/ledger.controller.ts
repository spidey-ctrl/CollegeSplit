import { Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { LedgerService } from './ledger.service.js';

@Controller('ledger')
@UseGuards(FirebaseAuthGuard)
export class LedgerController {
  constructor(private readonly ledgerService: LedgerService) {}

  @Get()
  ledger(@CurrentUser() decoded: DecodedIdToken) {
    return this.ledgerService.ledger(decoded.uid);
  }

  @Post(':contactId/settle')
  settle(
    @CurrentUser() decoded: DecodedIdToken,
    @Param('contactId') contactId: string,
  ) {
    return this.ledgerService.settle(decoded.uid, contactId);
  }
}
