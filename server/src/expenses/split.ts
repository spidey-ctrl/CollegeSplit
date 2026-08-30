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
      'Ratio split requires a positive integer ratio for every Participant',
    );
  }
  const total = ratios.reduce((sum, r) => sum + r, 0);
  if (total <= 0) {
    throw new BadRequestException('Ratio weights must sum to more than zero');
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
      'Adhoc split requires a positive integer sharePaise for every Participant',
    );
  }
  const total = shares.reduce((sum, s) => sum + s, 0);
  if (total !== amount) {
    throw new BadRequestException(
      `Adhoc shares (${total}) must sum exactly to the expense amount (${amount})`,
    );
  }
  return inputs.map((p, i) => ({
    name: p.name,
    sharePaise: shares[i],
    isUser: p.isUser ?? false,
  }));
}
