import { Injectable, Inject } from '@nestjs/common';
import {
  type CaptureInput,
  type VoiceDraftView,
  type VoiceProvider,
  UnconfiguredVoiceProvider,
} from './voice-provider.js';
import { SARVAM_VOICE_PROVIDER } from './voice.tokens.js';
import { buildDraft } from './voice-draft.js';

/**
 * Listens to a voice capture and turns it into a prefilled draft for the
 * ticket-02 edit screen. Nothing is persisted here — the User confirms (and
 * possibly edits) the draft, which then goes through the existing POST
 * /expenses.
 */
@Injectable()
export class VoiceService {
  constructor(
    @Inject(SARVAM_VOICE_PROVIDER)
    private readonly provider: VoiceProvider = new UnconfiguredVoiceProvider(),
  ) {}

  async capture(input: CaptureInput): Promise<VoiceDraftView> {
    const transcript = await this.provider.transcribe(input);
    const extraction = await this.provider.extract(transcript);
    return buildDraft(transcript, extraction);
  }
}
