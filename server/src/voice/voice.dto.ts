import { BadRequestException } from '@nestjs/common';
import type { CaptureInput } from './voice-provider.js';

const MAX_AUDIO_BASE64 = 5 * 1024 * 1024; // ~3.7MB of raw audio

/** Lightweight manual validation (no class-validator dependency). */
export function assertCaptureInput(body: unknown): asserts body is CaptureInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be a JSON object');
  }
  const b = body as Record<string, unknown>;

  if (typeof b.audioBase64 !== 'string' || b.audioBase64.trim().length === 0) {
    throw new BadRequestException('audioBase64 is required');
  }
  if (b.audioBase64.length > MAX_AUDIO_BASE64) {
    throw new BadRequestException('audioBase64 is too large');
  }
  if (typeof b.mimeType !== 'string' || b.mimeType.trim().length === 0) {
    throw new BadRequestException('mimeType is required');
  }
}
