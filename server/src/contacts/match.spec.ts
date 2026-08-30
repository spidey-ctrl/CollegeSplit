import { describe, it, expect } from 'vitest';
import {
  normalizeName,
  nearMatchName,
  resolveParticipant,
  type MatchableContact,
} from './match.js';

const contacts: MatchableContact[] = [
  { id: 'c-alice', name: 'Alice', phoneNumber: '+91-9000000001' },
  { id: 'c-alex', name: 'Alex', phoneNumber: '+91-9000000002' },
  { id: 'c-alexander', name: 'Alexander', phoneNumber: '+91-9000000003' },
  { id: 'c-robert', name: 'Robert', phoneNumber: '+91-9000000004' },
  // Name-only Contact: not a stable match target.
  { id: 'c-bob', name: 'Bob', phoneNumber: null },
];

describe('nearMatchName', () => {
  it('normalizes names for case and whitespace-insensitive comparison', () => {
    expect(normalizeName('  Mary Jane Doe ')).toBe('mary jane doe');
    expect(normalizeName('Alice')).toBe('alice');
  });

  it('is case and whitespace insensitive', () => {
    expect(nearMatchName('Alice', '  alice ')).toBe(true);
    expect(nearMatchName('Mary Jane', 'mary jane')).toBe(true);
  });

  it('treats a nickname (proper prefix) as a match', () => {
    expect(nearMatchName('Rob', 'Robert')).toBe(true);
    expect(nearMatchName('Alexander', 'Alex')).toBe(true);
    expect(nearMatchName('Al', 'Alice')).toBe(true); // 2-char nickname allowed
  });

  it('rejects unrelated and single-character prefixes', () => {
    expect(nearMatchName('Alice', 'Bob')).toBe(false);
    expect(nearMatchName('Charlie', 'Bob')).toBe(false);
    expect(nearMatchName('A', 'Alice')).toBe(false); // 1-char prefix too short
  });
});

describe('resolveParticipant (ticket 05 local matching)', () => {
  it('treats a Participant without a phone as ephemeral (never auto-links)', () => {
    const r = resolveParticipant({ name: 'Alice', phoneNumber: '', contacts });
    expect(r.kind).toBe('ephemeral');
  });

  it('exact (case/space-insensitive) match auto-links silently', () => {
    const r = resolveParticipant({
      name: '  alice ',
      phoneNumber: '+91-9000000001',
      contacts,
    });
    expect(r).toEqual({
      kind: 'autoLinked',
      contactId: 'c-alice',
      contactName: 'Alice',
    });
  });

  it('near-exact (nickname) match auto-links silently', () => {
    const r = resolveParticipant({
      name: 'Rob',
      phoneNumber: '+91-9000000004',
      contacts,
    });
    expect(r.kind).toBe('autoLinked');
    expect((r as { contactId: string }).contactId).toBe('c-robert');
  });

  it('2+ matches prompt the User to disambiguate rather than guessing', () => {
    const r = resolveParticipant({
      name: 'Alex',
      phoneNumber: '+91-9000000099',
      contacts,
    });
    expect(r.kind).toBe('ambiguous');
    if (r.kind === 'ambiguous') {
      expect(r.matches.map((m) => m.name).sort()).toEqual(['Alex', 'Alexander']);
    }
  });

  it('does not match against a name-only Contact (no phone anchor)', () => {
    const r = resolveParticipant({
      name: 'Bob',
      phoneNumber: '+91-9000000099',
      contacts,
    });
    expect(r.kind).toBe('ephemeral');
  });

  it('returns ephemeral when no Contact matches', () => {
    const r = resolveParticipant({
      name: 'Nobody',
      phoneNumber: '+91-9000000099',
      contacts,
    });
    expect(r.kind).toBe('ephemeral');
  });
});
