import { describe, it, expect } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import { computeShares } from './split.js';

describe('computeShares (ticket 02 split methods)', () => {
  it('Equal: divides evenly and distributes the remainder in paise', () => {
    const shares = computeShares('Equal', 10000, [
      { name: 'A' },
      { name: 'B' },
      { name: 'C' },
    ]);
    expect(shares.reduce((s, p) => s + p.sharePaise, 0)).toBe(10000);
    expect(shares.map((p) => p.sharePaise)).toEqual([3334, 3333, 3333]);
  });

  it('Equal: splits two ways cleanly', () => {
    const shares = computeShares('Equal', 10000, [
      { name: 'A' },
      { name: 'B' },
    ]);
    expect(shares.map((p) => p.sharePaise)).toEqual([5000, 5000]);
  });

  it('Equal: returns empty for a personal (zero-participant) expense', () => {
    expect(computeShares('Equal', 5000, [])).toEqual([]);
  });

  it('Ratio: splits proportionally to weights (2:1)', () => {
    const shares = computeShares('Ratio', 3000, [
      { name: 'A', ratio: 2 },
      { name: 'B', ratio: 1 },
    ]);
    expect(shares.map((p) => p.sharePaise)).toEqual([2000, 1000]);
  });

  it('Ratio: uses largest-remainder to keep shares summing to the amount', () => {
    const shares = computeShares('Ratio', 500, [
      { name: 'A', ratio: 2 },
      { name: 'B', ratio: 1 },
    ]);
    expect(shares.reduce((s, p) => s + p.sharePaise, 0)).toBe(500);
    // 500*2/3 = 333.33, 500*1/3 = 166.67 -> floors 333, 166; leftover 1 goes to B
    expect(shares.map((p) => p.sharePaise)).toEqual([333, 167]);
  });

  it('Adhoc: uses the exact shares provided', () => {
    const shares = computeShares('Adhoc', 10000, [
      { name: 'A', sharePaise: 2500 },
      { name: 'B', sharePaise: 7500 },
    ]);
    expect(shares.map((p) => p.sharePaise)).toEqual([2500, 7500]);
  });

  it('Adhoc: rejects shares that do not sum to the amount', () => {
    expect(() =>
      computeShares('Adhoc', 10000, [
        { name: 'A', sharePaise: 3000 },
        { name: 'B', sharePaise: 3000 },
      ]),
    ).toThrow(BadRequestException);
  });

  it('Ratio: rejects a zero or missing weight', () => {
    expect(() =>
      computeShares('Ratio', 1000, [{ name: 'A', ratio: 0 }, { name: 'B' }]),
    ).toThrow(BadRequestException);
  });

  it('rejects a non-positive amount', () => {
    expect(() => computeShares('Equal', 0, [{ name: 'A' }])).toThrow(
      BadRequestException,
    );
  });

  it('rejects an unknown split method', () => {
    expect(() =>
      computeShares('Unknown' as 'Equal', 1000, [{ name: 'A' }]),
    ).toThrow(BadRequestException);
  });
});
