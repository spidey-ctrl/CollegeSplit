import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  UseGuards,
} from '@nestjs/common';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { ContactsService, type ContactView } from './contacts.service.js';
import { assertSetPhone } from './contacts.dto.js';

@Controller('contacts')
@UseGuards(FirebaseAuthGuard)
export class ContactsController {
  constructor(private readonly contactsService: ContactsService) {}

  @Get()
  list(@CurrentUser() decoded: DecodedIdToken): Promise<ContactView[]> {
    return this.contactsService.list(decoded.uid);
  }

  @Patch(':id')
  setPhone(
    @CurrentUser() decoded: DecodedIdToken,
    @Param('id') id: string,
    @Body() body: unknown,
  ): Promise<ContactView> {
    assertSetPhone(body);
    const phone =
      typeof body.phoneNumber === 'string' && body.phoneNumber.trim().length === 0
        ? null
        : body.phoneNumber;
    return this.contactsService.setPhone(decoded.uid, id, phone);
  }
}
