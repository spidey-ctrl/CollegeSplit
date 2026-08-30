import {
  type RawExtraction,
  type VoiceDraftParticipant,
  type VoiceDraftView,
} from './voice-provider.js';

/**
 * Builds a ready-to-prefill edit-screen draft from a transcript + extraction.
 *
 * The User is the Payer of their own Expense and is not a Participant of it (see
 * the Ledger model in CONTEXT.md), so the participants are the *others* who
 * share the cost. The one exception is a Ratio split where the speaker names a
 * share for themselves but leaves the rest unstated ("Alex owes 30%, I'll cover
 * the rest") — there the remaining percentage is inferred as the User's own
 * share so the edit screen prefills a complete split.
 */
export function buildDraft(
  transcript: string,
  extraction: RawExtraction,
): VoiceDraftView {
  const participants: VoiceDraftParticipant[] = extraction.participants.map(
    (p) => ({ name: p.name, ...(p.ratio !== undefined ? { ratio: p.ratio } : {}), ...(p.isUser ? { isUser: true } : {}) }),
  );

  if (extraction.splitMethod === 'Ratio') {
    inferUserRemainder(participants);
  }

  return {
    transcript,
    amountPaise: extraction.amountPaise,
    category: extraction.category,
    payerName: extraction.payerName,
    isUserPayer: extraction.isUserPayer,
    splitMethod: extraction.splitMethod,
    participants,
    missingFields: extraction.missingFields,
  };
}

/** If no Participant is the User and the stated ratios leave a positive gap to
 *  100, append the remainder as the User's own share. Never mutates a fully
 *  specified split. */
function inferUserRemainder(participants: VoiceDraftParticipant[]): void {
  if (participants.some((p) => p.isUser === true)) return;
  const ratios = participants.map((p) => p.ratio);
  if (ratios.some((r) => typeof r !== 'number' || r <= 0)) return;

  const sum = ratios.reduce((a, b) => (a as number) + (b as number), 0) as number;
  const remainder = 100 - sum;
  if (!Number.isInteger(remainder) || remainder <= 0) return;

  participants.push({ name: 'You', ratio: remainder, isUser: true });
}
