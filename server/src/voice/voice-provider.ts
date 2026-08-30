import { BadRequestException } from '@nestjs/common';

/** Raw audio uploaded from the Flutter client for transcription. */
export interface CaptureInput {
  /** Raw audio bytes, base64-encoded. */
  audioBase64: string;
  /** Audio MIME type (e.g. audio/wav, audio/mp4, audio/aac). */
  mimeType: string;
}

/** A single Participant name extracted from speech (Equal split, ticket 03). */
export interface VoiceDraftParticipant {
  name: string;
}

/**
 * A ready-to-prefill edit-screen draft produced from a voice capture.
 * Nothing here is persisted; the User confirms (or edits) it before an Expense
 * is created via the existing POST /expenses.
 *
 * `null` + a matching entry in `missingFields` means the app couldn't
 * confidently extract the field, and it should be left blank and highlighted
 * on the edit screen rather than blocking entry.
 */
export interface VoiceDraftView {
  /** The raw transcript we extracted the draft from (shown to the User). */
  transcript: string;
  amountPaise: number | null;
  /** One of the fixed Category enum values, or null when not confident. */
  category: string | null;
  payerName: string | null;
  /** Whether the Payer is the signed-in User. Defaults to true. */
  isUserPayer: boolean;
  /** Ticket 03 only supports Equal split; the edit screen can change it. */
  splitMethod: 'Equal';
  participants: VoiceDraftParticipant[];
  /** Field names that couldn't be confidently extracted, e.g. ['amount']. */
  missingFields: string[];
}

/** The raw extraction result as Gemini returns it (already validated). */
export interface RawExtraction {
  amountPaise: number | null;
  category: string | null;
  payerName: string | null;
  isUserPayer: boolean;
  participantNames: string[];
  missingFields: string[];
}

/**
 * Abstraction over the two AI providers (Sarvam transcription + Gemini
 * extraction). The real implementation calls paid APIs from the backend only;
 * a fake can be injected so tests never hit them.
 */
export interface VoiceProvider {
  transcribe(input: CaptureInput): Promise<string>;
  extract(transcript: string): Promise<RawExtraction>;
}

/** A minimal, self-defining provider used when no AI is configured. */
export class UnconfiguredVoiceProvider implements VoiceProvider {
  async transcribe(): Promise<string> {
    throw new BadRequestException('Voice capture is not configured on the server');
  }
  async extract(): Promise<RawExtraction> {
    throw new BadRequestException('Voice capture is not configured on the server');
  }
}
