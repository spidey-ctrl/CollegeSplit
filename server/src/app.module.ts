import { Module } from '@nestjs/common';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { UsersModule } from './users/users.module.js';
import { ExpensesModule } from './expenses/expenses.module.js';
import { LedgerModule } from './ledger/ledger.module.js';

@Module({
  imports: [PrismaModule, UsersModule, ExpensesModule, LedgerModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
