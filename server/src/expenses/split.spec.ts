import { describe, it, expect } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import { withUserShare } from './split.js';

describe('withUserShare (always include the User)', () => {
  it('Equal: adds the User as one more equal share', () => {
    const out = withUserShare('Equal', 10000, [{ name: 'A' }, { name: 'B' }], 'You');
    expect(out.map((p) => p.isUser === true)).toEqual([false, false, true]);
    expect(out.at(-1)?.name).toBe('You');
  });

  it('Equal: leaves a personal expense (no participants) unchanged', () => {
    expect(withUserShare('Equal', 5000, [], 'You')).toEqual([]);
  });

  it('Ratio: infers the remainder up to 100 as the User share', () => {
    const out = withUserShare('Ratio', 10000, [{ name: 'Alex', ratio: 30 }], 'You');
    expect(out.map((p) => p.isUser === true)).toEqual([false, true]);
    expect(out.at(-1)?.ratio).toBe(70);
  });

  it('Ratio: rejects percentages that leave no room for the User', () => {
    expect(() =>
      withUserShare('Ratio', 10000, [
        { name: 'A', ratio: 60 },
        { name: 'B', ratio: 40 },
      ], 'You'),
    ).toThrow(BadRequestException);
  });

  it('Adhoc: leaves the remainder for the User', () => {
    const out = withUserShare(
      'Adhoc',
      10000,
      [
        { name: 'A', sharePaise: 2500 },
        { name: 'B', sharePaise: 3500 },
      ],
      'You',
    );
    expect(out.at(-1)?.sharePaise).toBe(4000);
    expect(out.at(-1)?.isUser).toBe(true);
  });

  it('Adhoc: rejects amounts that leave nothing for the User', () => {
    expect(() =>
      withUserShare('Adhoc', 10000, [{ name: 'A', sharePaise: 10000 }], 'You'),
    ).toThrow(BadRequestException);
  });

  it('returns the list unchanged when the User is already a sharer', () => {
    const input = [
      { name: 'Alex', ratio: 30 },
      { name: 'You', ratio: 70, isUser: true },
    ];
    expect(withUserShare('Ratio', 10000, input, 'You')).toEqual(input);
  });
});
