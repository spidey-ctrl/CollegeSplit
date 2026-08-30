import { Module } from '@nestjs/common';
import { VoiceController } from './voice.controller.js';
import { VoiceService } from './voice.service.js';
import { SarvamVoiceProvider } from './sarvam-voice.provider.js';
import { SARVAM_VOICE_PROVIDER } from './voice.tokens.js';
import type { VoiceProvider } from './voice-provider.js';
import { UnconfiguredVoiceProvider } from './voice-provider.js';

@Module({
  controllers: [VoiceController],
  providers: [
    VoiceService,
    {
      provide: SARVAM_VOICE_PROVIDER,
      // Fall back to a self-defining provider so the app still boots (and
      // returns a clear error) if neither real keys nor a test fake are present.
      useFactory: (): VoiceProvider => {
        if (process.env.SARVAM_API_KEY && process.env.GEMINI_API_KEY) {
          return new SarvamVoiceProvider();
        }
        return new UnconfiguredVoiceProvider();
      },
    },
  ],
})
export class VoiceModule {}
