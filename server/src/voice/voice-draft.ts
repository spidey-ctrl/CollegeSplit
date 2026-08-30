import {
  type RawExtraction,
  type VoiceDraftParticipant,
  type VoiceDraftView,
} from './voice-provider.js';

/**
 * Builds a ready-to-prefill edit-screen draft from a transcript + extraction.
 *
 * The signed-in User always takes a share. When the stated shares don't already
 * include the User, the User is appended as the remainder — the percentage gap
 * up to 100 for a Ratio split (e.g. "Alex owes 30%, I'll cover the rest"), or a
 * plain "You" participant for an Equal split — so the edit screen prefills a
 * complete split that includes the User.
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
  } else if (
    participants.length > 0 &&
    !participants.some((p) => p.isUser === true)
  ) {
    participants.push({ name: 'You', isUser: true });
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
