import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard.js';
import { VoiceService } from './voice.service.js';
import { assertCaptureInput } from './voice.dto.js';
import type { VoiceDraftView } from './voice-provider.js';

@Controller('voice')
@UseGuards(FirebaseAuthGuard)
export class VoiceController {
  constructor(private readonly voiceService: VoiceService) {}

  @Post('capture')
  capture(@Body() body: unknown): Promise<VoiceDraftView> {
    assertCaptureInput(body);
    return this.voiceService.capture(body);
  }
}
