import {
  type CaptureInput,
  type RawExtraction,
  type VoiceProvider,
} from './voice-provider.js';

/**
 * Test double for the AI provider pipeline. It never calls Sarvam or Gemini;
 * instead it returns fixture transcripts and extractions for known inputs so
 * integration tests exercise the real orchestration without costing money.
 */
export class FakeVoiceProvider implements VoiceProvider {
  constructor(private readonly fixtures: VoiceFixture[] = DEFAULT_FIXTURES) {}

  async transcribe(input: CaptureInput): Promise<string> {
    // Identify the fixture by a stable substring the test supplies in the
    // audio's base64 payload (mirrors how the real flow carries audio and
    // turns it into a transcript).
    const hint = Buffer.from(input.audioBase64, 'base64').toString('utf8');
    const fixture = this.fixtures.find((f) =>
      hint.toLowerCase().includes(f.key.toLowerCase()),
    );
    if (!fixture) {
      throw new Error('No transcription fixture matched the supplied audio');
    }
    return fixture.transcript;
  }

  async extract(transcript: string): Promise<RawExtraction> {
    const fixture = this.fixtures.find(
      (f) =>
        f.transcript.trim().toLowerCase() === transcript.trim().toLowerCase(),
    );
    if (!fixture) {
      throw new Error('No extraction fixture matched the transcript');
    }
    return fixture.extraction;
  }
}

export interface VoiceFixture {
  /** A substring to match against the test audio's base64 payload. */
  key: string;
  transcript: string;
  extraction: RawExtraction;
}

/** A realistic "I paid 120 rupees for lunch with Alice and Bob" fixture. */
export const DEFAULT_FIXTURES: VoiceFixture[] = [
  {
    key: 'lunch',
    transcript: 'I paid one hundred and twenty rupees for lunch with Alice and Bob.',
    extraction: {
      amountPaise: 12000,
      category: 'FoodDrink',
      payerName: null,
      isUserPayer: true,
      participantNames: ['Alice', 'Bob'],
      missingFields: [],
    },
  },
  {
    key: 'missing-amount',
    transcript: 'Alice picked up the cab fare but I am not sure of the amount.',
    extraction: {
      amountPaise: null,
      category: 'Transport',
      payerName: 'Alice',
      isUserPayer: false,
      participantNames: [],
      missingFields: ['amount'],
    },
  },
  {
    key: 'personal',
    transcript: 'I bought groceries for myself only.',
    extraction: {
      amountPaise: 750,
      category: 'Groceries',
      payerName: null,
      isUserPayer: true,
      participantNames: [],
      missingFields: ['amount'],
    },
  },
];
