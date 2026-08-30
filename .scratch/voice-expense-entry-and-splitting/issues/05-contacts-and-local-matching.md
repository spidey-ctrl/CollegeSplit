# 05: Contacts: accumulation, phone number, local matching

**What to build:** Participants a User names more than once become Contacts automatically, with a phone number that can be added manually and matching logic scoped to that User's own list.

**Blocked by:** 02 (Manual Expense entry with Ledger/Balance)

**Status:** ready-for-agent

- [ ] Contact schema: owned by a User, name, optional phone number, optionally resolved to a registered User via phone match (resolution logic itself is ticket 11 — this ticket just carries the field)
- [ ] A Participant named on 2+ Expenses by the same User automatically becomes a Contact — no explicit "add contact" action required
- [ ] A phone number can be manually added or edited on a Participant/Contact via the edit screen
- [ ] A spoken or typed name that exactly (or near-exactly, e.g. case/nickname) matches an existing Contact auto-links to it silently
- [ ] A name matching 2+ existing Contacts prompts the User to disambiguate on the edit screen rather than guessing
- [ ] A Participant with no phone number is treated as ephemeral and never fuzzy-matched against other name-only records
- [ ] Backend integration tests covering: Contact auto-creation after a second use, exact-match auto-link, ambiguous-match disambiguation prompt
- [ ] Flutter integration test: entering the same name twice across two Expenses and seeing it resolve to one Contact on the second entry
