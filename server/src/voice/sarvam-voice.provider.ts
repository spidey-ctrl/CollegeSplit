import { BadRequestException } from '@nestjs/common';
import {
  type CaptureInput,
  type RawExtraction,
  type VoiceProvider,
} from './voice-provider.js';
import { CATEGORIES } from '../expenses/dto.js';

/**
 * Real voice provider: Sarvam speech-to-text for transcription followed by
 * Gemini structured extraction. Both keys live only in the backend .env and
 * are never exposed to the Flutter client.
 */
export class SarvamVoiceProvider implements VoiceProvider {
  private readonly sarvamKey = process.env.SARVAM_API_KEY;
  private readonly geminiKey = process.env.GEMINI_API_KEY;

  async transcribe(input: CaptureInput): Promise<string> {
    if (!this.sarvamKey) {
      throw new BadRequestException(
        'SARVAM_API_KEY is not configured on the server',
      );
    }

    const form = new FormData();
    const bytes = this.base64ToBytes(input.audioBase64);
    const blob = new Blob([bytes], { type: input.mimeType || 'audio/wav' });
    form.append('file', blob, `capture.${this.mimeToExt(input.mimeType)}`);
    form.append('model', 'saaras:v3');
    form.append('language_code', 'unknown');
    form.append('mode', 'transcribe');

    let res: Response;
    try {
      res = await fetch('https://api.sarvam.ai/speech-to-text', {
        method: 'POST',
        headers: { 'api-subscription-key': this.sarvamKey },
        body: form,
      });
    } catch {
      throw new BadRequestException('Failed to reach the transcription service');
    }

    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new BadRequestException(
        `Transcription failed (${res.status}): ${text}`,
      );
    }

    const json = (await res.json()) as { transcript?: string };
    const transcript = json.transcript?.trim();
    if (!transcript) {
      throw new BadRequestException('No speech was understood');
    }
    return transcript;
  }

  async extract(transcript: string): Promise<RawExtraction> {
    if (!this.geminiKey) {
      throw new BadRequestException(
        'GEMINI_API_KEY is not configured on the server',
      );
    }

    const body = {
      contents: [{ parts: [{ text: this.extractionPrompt(transcript) }] }],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: this.extractionSchema(),
      },
    };

    let res: Response;
    try {
      res = await fetch(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
        {
          method: 'POST',
          headers: {
            'x-goog-api-key': this.geminiKey,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(body),
        },
      );
    } catch {
      throw new BadRequestException('Failed to reach the extraction service');
    }

    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new BadRequestException(
        `Extraction failed (${res.status}): ${text}`,
      );
    }

    const json = (await res.json()) as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    const text = json.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      throw new BadRequestException('Extraction returned no result');
    }

    let raw: Record<string, unknown>;
    try {
      raw = JSON.parse(text) as Record<string, unknown>;
    } catch {
      throw new BadRequestException('Extraction returned malformed JSON');
    }
    return this.normalize(raw);
  }

  private extractionPrompt(transcript: string): string {
    return [
      'You extract a shared-expense draft from a spoken sentence in English, Hindi or Hinglish.',
      'Fill in every field you can infer. If you are NOT confident about a field, leave it null ' +
        'AND add it to the missingFields list so the app knows to leave it blank and highlighted.',
      'Rules:',
      '- amountPaise: the total money, as an integer number of paise (1 INR = 100 paise). Always required; ' +
        'if the amount is not clearly stated, set null and add "amount".',
      '- category: one of exactly: ' + CATEGORIES.join(', ') + '. If unsure or unstated, set null and add "category".',
      '- payerName: who paid. If it is the speaker (e.g. "I paid", "main gaya"), set isUserPayer true and ' +
        'payerName null. If an external person paid, set isUserPayer false and their name.',
      '- isUserPayer: true when the speaker/owner is the payer, false when an external named person paid.',
      '- participantNames: the other people splitting the expense (free-text names). If only the speaker and a ' +
        'lone other person split, include that other person. Empty when it is a personal expense.',
      '- splitMethod: always "Equal" for this ticket.',
      '',
      'Return ONLY valid JSON matching the schema. Never invent an amount that is not clearly stated.',
      '',
      `TRANSCRIPT: "${transcript}"`,
    ].join('\n');
  }

  private extractionSchema(): Record<string, unknown> {
    return {
      type: 'object',
      properties: {
        amountPaise: { type: 'integer', description: 'Total amount in paise, or null if unstated.' },
        category: {
          type: ['string', 'null'],
          enum: this.categorySchemaEnum(),
          description: 'One of the fixed categories, or null if unsure.',
        },
        payerName: { type: ['string', 'null'], description: 'External payer name, or null.' },
        isUserPayer: { type: 'boolean', description: 'True if the owner is the payer.' },
        participantNames: {
          type: 'array',
          items: { type: 'string' },
          description: 'Other participants, free-text names.',
        },
        missingFields: {
          type: 'array',
          items: { type: 'string' },
          description: "Fields ('amount', 'category', 'payerName') that could not be confidently extracted.",
        },
      },
      required: ['amountPaise', 'category', 'payerName', 'isUserPayer', 'participantNames', 'missingFields'],
    };
  }

  /** Gemini enum cannot contain 'null' alongside string values in all versions,
   *  so we provide the category enum plus a separate nullable handling. */
  private categorySchemaEnum(): Array<string | null> {
    return [...CATEGORIES, null];
  }

  private normalize(raw: Record<string, unknown>): RawExtraction {
    const amountPaise = this.asPosInt(raw.amountPaise);
    const category = this.asCategory(raw.category);
    const payerName = this.asString(raw.payerName);
    const isUserPayer = typeof raw.isUserPayer === 'boolean' ? raw.isUserPayer : true;
    const participantNames = Array.isArray(raw.participantNames)
      ? (raw.participantNames as unknown[])
          .map((p) => this.asString(p))
          .filter((n): n is string => n !== null && n.length > 0)
      : [];

    // Derive missingFields from whatever could not be confidently extracted.
    const missing = new Set<string>();
    if (amountPaise === null) missing.add('amount');
    if (category === null) missing.add('category');
    // payerName is only "missing" when important (an external payer was named but
    // we couldn't read it). For the owner-payer case it is intentionally null.
    if (isUserPayer === false && payerName === null) missing.add('payerName');

    return {
      amountPaise,
      category,
      payerName,
      isUserPayer,
      participantNames,
      missingFields: Array.from(missing),
    };
  }

  private base64ToBytes(base64: string): Uint8Array<ArrayBuffer> {
    // Strip a possible data: URL prefix the client may have sent.
    const clean = base64.includes(',') ? base64.slice(base64.indexOf(',') + 1) : base64;
    const binary = Buffer.from(clean, 'base64');
    const out = new Uint8Array(binary.byteLength);
    out.set(binary);
    return out;
  }

  private mimeToExt(mime: string): string {
    const map: Record<string, string> = {
      'audio/wav': 'wav',
      'audio/wave': 'wav',
      'audio/mpeg': 'mp3',
      'audio/mp3': 'mp3',
      'audio/aac': 'aac',
      'audio/mp4': 'm4a',
      'audio/x-m4a': 'm4a',
      'audio/ogg': 'ogg',
      'audio/x-opus': 'opus',
      'audio/flac': 'flac',
      'audio/webm': 'webm',
    };
    return map[mime] ?? 'wav';
  }

  private asPosInt(v: unknown): number | null {
    if (typeof v !== 'number' || !Number.isInteger(v) || v <= 0) return null;
    return v;
  }

  private asString(v: unknown): string | null {
    if (typeof v !== 'string') return null;
    const t = v.trim();
    return t.length > 0 ? t : null;
  }

  private asCategory(v: unknown): string | null {
    const s = this.asString(v);
    return s && (CATEGORIES as string[]).includes(s) ? s : null;
  }
}
