import { Module } from '@nestjs/common';
import { ExpensesController } from './expenses.controller.js';
import { ExpensesService } from './expenses.service.js';
import { ContactsModule } from '../contacts/contacts.module.js';

@Module({
  imports: [ContactsModule],
  controllers: [ExpensesController],
  providers: [ExpensesService],
})
export class ExpensesModule {}
