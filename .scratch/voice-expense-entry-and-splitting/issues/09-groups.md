# 09: Groups

**What to build:** A User can save a named Group of Contacts (e.g. "Roommates") and select it when adding an Expense instead of naming the same people every time.

**Blocked by:** 05 (Contacts: accumulation, phone number, local matching)

**Status:** ready-for-agent

- [ ] Group schema: owned by a User, a name, a set of member Contacts
- [ ] CRUD endpoints for Groups
- [ ] Flutter: create/manage a Group, and select a Group when adding an Expense to prefill its Participants
- [ ] Backend integration test: creating a Group and using it to prefill Participants on a new Expense
- [ ] Flutter integration test: adding an Expense via a saved Group and seeing all its members as Participants
