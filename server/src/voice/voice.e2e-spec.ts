import 'dotenv/config';
import { describe, it, expect } from 'vitest';
import { VoiceService } from './voice.service.js';
import { FakeVoiceProvider } from './fake-voice.provider.js';

/** Encodes the fixture key as a base64 audio payload (the fake decodes and matches it). */
function audio(key: string): string {
  return Buffer.from(key, 'utf8').toString('base64');
}

describe('Voice capture (ticket 03, fake provider)', () => {
  const makeService = () => new VoiceService(new FakeVoiceProvider());

  it('turns a full utterance into an Equal-split draft for the edit screen', async () => {
    const service = makeService();
    const draft = await service.capture({
      audioBase64: audio('lunch'),
      mimeType: 'audio/wav',
    });

    expect(draft.amountPaise).toBe(12000);
    expect(draft.category).toBe('FoodDrink');
    expect(draft.isUserPayer).toBe(true);
    expect(draft.payerName).toBeNull();
    expect(draft.splitMethod).toBe('Equal');
    expect(draft.participants.map((p) => p.name)).toEqual(['Alice', 'Bob']);
    expect(draft.missingFields).toEqual([]);
    expect(draft.transcript).toContain('lunch');
  });

  it('leaves an unsure amount blank and flags it as missing (no retry loop)', async () => {
    const service = makeService();
    const draft = await service.capture({
      audioBase64: audio('missing-amount'),
      mimeType: 'audio/wav',
    });

    expect(draft.amountPaise).toBeNull();
    expect(draft.missingFields).toContain('amount');
    // Category and payer are still confidently extracted.
    expect(draft.category).toBe('Transport');
    expect(draft.payerName).toBe('Alice');
    expect(draft.isUserPayer).toBe(false);
  });

  it('supports a personal (zero-participant) expense', async () => {
    const service = makeService();
    const draft = await service.capture({
      audioBase64: audio('personal'),
      mimeType: 'audio/wav',
    });

    expect(draft.participants).toEqual([]);
    expect(draft.category).toBe('Groceries');
    expect(draft.amountPaise).toBe(750);
  });

  it('rejects audio the provider cannot match (nothing persisted)', async () => {
    const service = makeService();
    await expect(
      service.capture({
        audioBase64: Buffer.from('unmatched-audio', 'utf8').toString('base64'),
        mimeType: 'audio/wav',
      }),
    ).rejects.toThrow();
  });

  it('never writes anything to the database (draft is ephemeral)', async () => {
    // VoiceService has no Prisma dependency, so a capture cannot persist.
    const service = new VoiceService(new FakeVoiceProvider());
    const draft = await service.capture({
      audioBase64: audio('lunch'),
      mimeType: 'audio/wav',
    });
    // The draft carries no id/createdAt — it is not a stored Expense.
    expect(draft).not.toHaveProperty('id');
    expect(draft).not.toHaveProperty('createdAt');
  });
});
