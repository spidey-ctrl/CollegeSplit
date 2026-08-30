import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

export interface ContactView {
  id: string;
  name: string;
  phoneNumber: string | null;
}

/**
 * Manages a User's own Contact list (ticket 05). Contacts accumulate
 * automatically from Participants the User names on 2+ Expenses; a phone
 * number can be added/edited manually. Matching against this list is scoped
 * strictly to the owning User.
 */
@Injectable()
export class ContactsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string): Promise<ContactView[]> {
    const contacts = await this.prisma.contact.findMany({
      where: { userId },
      orderBy: { name: 'asc' },
    });
    return contacts.map((c) => this.toView(c));
  }

  async setPhone(
    userId: string,
    contactId: string,
    phoneNumber: string | null,
  ): Promise<ContactView> {
    const contact = await this.prisma.contact.findFirst({
      where: { id: contactId, userId },
    });
    if (!contact) {
      throw new NotFoundException('Contact not found');
    }
    const updated = await this.prisma.contact.update({
      where: { id: contactId },
      data: { phoneNumber },
    });
    return this.toView(updated);
  }

  /**
   * When a Participant name is used on 2+ distinct Expenses by this User, ensure
   * a Contact exists for it (auto-creation — no explicit "add contact" action).
   * If a phone is supplied it seeds/updates the Contact's phone (never blanks
   * an existing phone with a missing value).
   */
  async ensureFromExpense(
    userId: string,
    name: string,
    phoneNumber?: string | null,
  ): Promise<void> {
    const expenses = await this.prisma.participant.groupBy({
      by: ['expenseId'],
      where: {
        name,
        isUser: false,
        expense: { userId },
      },
    });
    if (expenses.length < 2) {
      return;
    }

    const data: { phoneNumber?: string | null } = {};
    if (phoneNumber && phoneNumber.trim().length > 0) {
      data.phoneNumber = phoneNumber.trim();
    }

    await this.prisma.contact.upsert({
      where: { userId_name: { userId, name } },
      update: data,
      create: { userId, name, ...data },
    });
  }

  private toView(c: {
    id: string;
    name: string;
    phoneNumber: string | null;
  }): ContactView {
    return {
      id: c.id,
      name: c.name,
      phoneNumber: c.phoneNumber,
    };
  }
}
