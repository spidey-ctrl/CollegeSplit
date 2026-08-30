import { Module } from '@nestjs/common';
import { ShareController } from './share.controller.js';
import { ShareService } from './share.service.js';
import { LedgerModule } from '../ledger/ledger.module.js';

@Module({
  imports: [LedgerModule],
  controllers: [ShareController],
  providers: [ShareService],
})
export class ShareModule {}
