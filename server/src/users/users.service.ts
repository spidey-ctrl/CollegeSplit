import { Injectable } from '@nestjs/common';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  // Get-or-create the User for the authenticated Firebase account.
  async me(decoded: DecodedIdToken) {
    const email = decoded.email ?? `${decoded.uid}@users.noreply.collegesplit`;
    return this.prisma.user.upsert({
      where: { id: decoded.uid },
      update: {
        displayName: decoded.name ?? email,
        email,
      },
      create: {
        id: decoded.uid,
        displayName: decoded.name ?? email,
        email,
      },
    });
  }
}
