import {
  type RawExtraction,
  type VoiceDraftParticipant,
  type VoiceDraftView,
} from './voice-provider.js';

/** Builds a ready-to-prefill edit-screen draft from a transcript + extraction. */
export function buildDraft(
  transcript: string,
  extraction: RawExtraction,
): VoiceDraftView {
  const participants: VoiceDraftParticipant[] = extraction.participantNames.map(
    (name) => ({ name }),
  );
  return {
    transcript,
    amountPaise: extraction.amountPaise,
    category: extraction.category,
    payerName: extraction.payerName,
    isUserPayer: extraction.isUserPayer,
    splitMethod: 'Equal',
    participants,
    missingFields: extraction.missingFields,
  };
}
