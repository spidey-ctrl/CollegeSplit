import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { PrismaNeon } from '@prisma/adapter-neon';
import { PrismaClient } from '../generated/prisma/client.js';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleDestroy {
  constructor() {
    const url = process.env.DATABASE_URL;
    if (!url) {
      throw new Error('DATABASE_URL is not set');
    }
    super({ adapter: new PrismaNeon({ connectionString: url }) });
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
