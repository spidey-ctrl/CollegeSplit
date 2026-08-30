import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { ShareService } from './share.service.js';
import {
  assertShareBalanceDto,
  assertShareExpenseDto,
  type SharePayload,
} from './share.dto.js';

@Controller('share')
@UseGuards(FirebaseAuthGuard)
export class ShareController {
  constructor(private readonly shareService: ShareService) {}

  @Post('expense')
  expense(
    @CurrentUser() decoded: DecodedIdToken,
    @Body() body: unknown,
  ): Promise<SharePayload> {
    assertShareExpenseDto(body);
    return this.shareService.shareExpense(decoded, body);
  }

  @Post('balance')
  balance(
    @CurrentUser() decoded: DecodedIdToken,
    @Body() body: unknown,
  ): Promise<SharePayload> {
    assertShareBalanceDto(body);
    return this.shareService.shareBalance(decoded, body);
  }
}
