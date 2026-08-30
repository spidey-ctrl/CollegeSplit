import { BadRequestException } from '@nestjs/common';

export type SplitMethod = 'Equal' | 'Ratio' | 'Adhoc';

export interface SplitParticipantInput {
  name: string;
  // Equal: unused. Ratio: integer weight (>0). Adhoc: exact share in paise (>0).
  ratio?: number;
  sharePaise?: number;
  isUser?: boolean;
}

export interface SplitParticipant {
  name: string;
  sharePaise: number;
  isUser: boolean;
}

/**
 * Computes per-Participant shares (in paise) for an Expense of the given
 * amount, according to the Split Method. Shares always sum exactly to the
 * amount (remainders are distributed with the largest-remainder method so no
 * money is lost or invented).
 */
export function computeShares(
  method: SplitMethod,
  amount: number,
  participants: SplitParticipantInput[],
): SplitParticipant[] {
  if (!Number.isInteger(amount) || amount <= 0) {
    throw new BadRequestException('amountPaise must be a positive integer');
  }

  if (participants.length === 0) {
    return [];
  }

  switch (method) {
    case 'Equal':
      return splitEqual(amount, participants);
    case 'Ratio':
      return splitRatio(amount, participants);
    case 'Adhoc':
      return splitAdhoc(amount, participants);
    default:
      throw new BadRequestException(
        `Unknown split method '${method}'. Expected Equal, Ratio or Adhoc.`,
      );
  }
}

/**
 * Ensures the signed-in User is a Participant of the split, so the amount is
 * shared among the User AND the others (the User's own share is the remainder).
 *
 * The incoming [participants] are the OTHER people. When none is already marked
 * `isUser`, the User's share is inferred:
 *  - Equal: the User is one more equal share.
 *  - Ratio: the User takes the percentage gap left by the others (to 100).
 *  - Adhoc: the User takes whatever the others' exact amounts leave unsettled.
 *
 * When a Participant is already marked `isUser` (e.g. a voice Ratio where the
 * User was named, or an external-Payer expense), the list is returned unchanged.
 * A personal expense (no other Participant) needs no User share.
 */
export function withUserShare(
  method: SplitMethod,
  amount: number,
  participants: SplitParticipantInput[],
  userName: string,
): SplitParticipantInput[] {
  if (participants.some((p) => p.isUser === true)) return participants;
  if (participants.length === 0) return participants;

  switch (method) {
    case 'Equal':
      return [...participants, { name: userName, isUser: true }];
    case 'Ratio': {
      const ratios = participants.map((p) => p.ratio as number);
      if (ratios.some((r) => !Number.isInteger(r) || r <= 0)) return participants;
      const used = ratios.reduce((sum, r) => sum + r, 0);
      const remainder = 100 - used;
      if (remainder <= 0) {
        throw new BadRequestException(
          'The share percentages must leave room for your own share.',
        );
      }
      return [...participants, { name: userName, ratio: remainder, isUser: true }];
    }
    case 'Adhoc': {
      const shares = participants.map((p) => p.sharePaise as number);
      if (shares.some((s) => !Number.isInteger(s) || s <= 0)) return participants;
      const used = shares.reduce((sum, s) => sum + s, 0);
      const remainder = amount - used;
      if (remainder <= 0) {
        throw new BadRequestException(
          'The amounts you entered must leave room for your own share.',
        );
      }
      return [...participants, { name: userName, sharePaise: remainder, isUser: true }];
    }
    default:
      return participants;
  }
}

function splitEqual(
  amount: number,
  inputs: SplitParticipantInput[],
): SplitParticipant[] {
  const n = inputs.length;
  const base = Math.floor(amount / n);
  let remainder = amount - base * n;
  return inputs.map((p) => {
    const share = base + (remainder > 0 ? 1 : 0);
    if (remainder > 0) remainder -= 1;
    return { name: p.name, sharePaise: share, isUser: p.isUser ?? false };
  });
}

function splitRatio(
  amount: number,
  inputs: SplitParticipantInput[],
): SplitParticipant[] {
  const ratios: number[] = inputs.map((p) => p.ratio as number);
  if (ratios.some((r) => !Number.isInteger(r) || r <= 0)) {
    throw new BadRequestException(
      'Give every Participant a positive whole-number ratio.',
    );
  }
  const total = ratios.reduce((sum, r) => sum + r, 0);
  if (total <= 0) {
    throw new BadRequestException('The ratio weights must add up to more than zero.');
  }

  const exact = ratios.map((r) => (amount * r) / total);
  // Largest-remainder method: floor first, then give each remaining paisa to
  // the Participants with the largest fractional remainders.
  const floors = exact.map((x) => Math.floor(x));
  const remainders = exact.map((x, i) => x - floors[i]);
  let leftover = amount - floors.reduce((a, b) => a + b, 0);

  const order = remainders
    .map((r, i) => ({ r, i }))
    .sort((a, b) => b.r - a.r);

  for (const { i } of order) {
    if (leftover === 0) break;
    floors[i] += 1;
    leftover -= 1;
  }

  return inputs.map((p, i) => ({
    name: p.name,
    sharePaise: floors[i],
    isUser: p.isUser ?? false,
  }));
}

function splitAdhoc(
  amount: number,
  inputs: SplitParticipantInput[],
): SplitParticipant[] {
  const shares: number[] = inputs.map((p) => p.sharePaise as number);
  if (shares.some((s) => !Number.isInteger(s) || s <= 0)) {
    throw new BadRequestException(
      'Give every Participant an exact amount greater than zero.',
    );
  }
  const total = shares.reduce((sum, s) => sum + s, 0);
  if (total !== amount) {
    throw new BadRequestException(
      `The amounts you entered (₹${paiseToRupees(total)}) must add up to the expense total (₹${paiseToRupees(amount)}).`,
    );
  }
  return inputs.map((p, i) => ({
    name: p.name,
    sharePaise: shares[i],
    isUser: p.isUser ?? false,
  }));
}

/** Formats a paise amount as an INR string, e.g. 4000 -> "40.00". */
function paiseToRupees(paise: number): string {
  const rupees = Math.trunc(paise / 100);
  const fraction = (paise % 100).toString().padStart(2, '0');
  return `${rupees}.${fraction}`;
}
