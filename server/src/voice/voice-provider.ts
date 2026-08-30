import { BadRequestException } from '@nestjs/common';

/** Raw audio uploaded from the Flutter client for transcription. */
export interface CaptureInput {
  /** Raw audio bytes, base64-encoded. */
  audioBase64: string;
  /** Audio MIME type (e.g. audio/wav, audio/mp4, audio/aac). */
  mimeType: string;
}

/**
 * A single Participant in a Draft.
 *
 * For an Equal split (ticket 03) only `name` is set. For a Ratio split
 * (ticket 04) the participant carries its stated integer `ratio` weight, and
 * `isUser` marks the participant representing the signed-in User (including a
 * remainder inferred as the User's own share).
 */
export interface VoiceDraftParticipant {
  name: string;
  ratio?: number;
  isUser?: boolean;
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
  /** Equal (ticket 03) or Ratio (ticket 04); the edit screen can change it. */
  splitMethod: 'Equal' | 'Ratio';
  participants: VoiceDraftParticipant[];
  /** Field names that couldn't be confidently extracted, e.g. ['amount']. */
  missingFields: string[];
}

/** A Participant as extracted: name, optional ratio weight, optional isUser. */
export interface RawExtractionParticipant {
  name: string;
  ratio?: number;
  isUser?: boolean;
}

/** The raw extraction result as Gemini returns it (already validated). */
export interface RawExtraction {
  amountPaise: number | null;
  category: string | null;
  payerName: string | null;
  isUserPayer: boolean;
  splitMethod: 'Equal' | 'Ratio';
  participants: RawExtractionParticipant[];
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
