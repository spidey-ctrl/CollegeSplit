# 10: Share: native fallback + phone pre-targeting

**What to build:** A User can share a single Expense or an aggregate Balance; without a registered-User match, it opens the device's native share sheet with a text summary — pre-targeted at the Participant's phone when one's on file, or left for the User to pick a recipient when it isn't.

**Blocked by:** 02 (Manual Expense entry with Ledger/Balance)

**Status:** ready-for-agent

- [ ] A Share action available on a single Expense and on an aggregate Balance with a counterparty
- [ ] Share produces a read-only text summary of the shared Expense/Balance
- [ ] When the Participant has a phone number on file, Share hands off to the device's native share sheet pre-targeted at that number (e.g. a WhatsApp/SMS deep link)
- [ ] When no phone number is on file, Share opens a generic native share sheet with no pre-selected recipient
- [ ] Sharing never grants edit access or merges Ledgers
- [ ] Backend integration test: generating the correct share payload for both a single Expense and an aggregate Balance
- [ ] Flutter integration test: triggering Share on an Expense with and without a Participant phone number, verifying the correct share-sheet invocation in each case
