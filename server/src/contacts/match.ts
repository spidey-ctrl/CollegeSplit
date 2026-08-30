/**
 * Local, per-User name matching for Contacts (ticket 05).
 *
 * Matching is scoped to a single User's own Contact list (never the whole user
 * base). The identity anchor for a "real, reusable" person is a phone number:
 *  - A Participant WITHOUT a phone is name-only and ephemeral — it is never
 *    fuzzy-matched against other records (see CONTEXT.md "Participant").
 *  - Among a User's Contacts, only phone-anchored ones are eligible match
 *    targets, so a name can't silently merge two different people who happen
 *    to share a name but have no phone to disambiguate them.
 */

export interface MatchableContact {
  id: string;
  name: string;
  phoneNumber: string | null;
}

export type ParticipantMatch =
  | { kind: 'autoLinked'; contactId: string; contactName: string }
  | { kind: 'ambiguous'; matches: Array<{ contactId: string; name: string }> }
  | { kind: 'ephemeral' };

export interface ResolveInput {
  /** The name as spoken/typed for the Participant. */
  name: string;
  /** The Participant's phone, if one was given. Empty means name-only/ephemeral. */
  phoneNumber?: string | null;
  /** The User's own Contact list. */
  contacts: MatchableContact[];
}

/** Normalizes a name for case/whitespace-insensitive comparison. */
export function normalizeName(name: string): string {
  return name.trim().replace(/\s+/g, ' ').toLowerCase();
}

/**
 * True when two names near-exactly match: same normalized name (case/space
 * insensitive), or one is a nickname of the other (a proper prefix, so "Rob"
 * matches "Robert" and "Alex" matches "Alexander"). Prefix must be at least
 * two characters to avoid over-matching initials.
 */
export function nearMatchName(a: string, b: string): boolean {
  const na = normalizeName(a);
  const nb = normalizeName(b);
  if (na === nb) return true;
  const [short, long] = na.length <= nb.length ? [na, nb] : [nb, na];
  return short.length >= 2 && long.startsWith(short);
}

/**
 * Resolves a typed Participant name against the User's Contacts.
 *
 * Returns:
 *  - `autoLinked` when the name matches exactly one phone-anchored Contact;
 *  - `ambiguous` when it matches 2+ phone-anchored Contacts (the client should
 *    ask the User to disambiguate rather than guess);
 *  - `ephemeral` when there is no phone on the Participant, no match, or no
 *    phone-anchored match (keeps the free-text name, no auto-link).
 */
export function resolveParticipant(input: ResolveInput): ParticipantMatch {
  const phone = input.phoneNumber?.trim();
  if (!phone) {
    return { kind: 'ephemeral' };
  }

  const phoneAnchored = input.contacts.filter((c) => c.phoneNumber?.trim());
  const matches = phoneAnchored.filter((c) => nearMatchName(input.name, c.name));

  if (matches.length === 1) {
    return {
      kind: 'autoLinked',
      contactId: matches[0].id,
      contactName: matches[0].name,
    };
  }
  if (matches.length > 1) {
    return {
      kind: 'ambiguous',
      matches: matches.map((c) => ({ contactId: c.id, name: c.name })),
    };
  }
  return { kind: 'ephemeral' };
}
