# 06: Device-contacts auto-suggest

**What to build:** A phone number is auto-suggested onto a Participant when their name matches an entry in the User's own device contact list, so attaching one never requires typing it in.

**Blocked by:** 05 (Contacts: accumulation, phone number, local matching)

**Status:** ready-for-agent

- [x] Flutter requests device contact-list permission at the appropriate point (not at first app launch)
- [x] When a spoken or typed Participant name matches an entry in the User's device contacts, its phone number is auto-suggested onto the Participant, subject to the User's permission grant
- [x] The User can still override or clear an auto-suggested number via the manual edit path from ticket 05
- [x] Denying contact permission doesn't block adding a Participant — manual entry (ticket 05) remains available
- [x] Flutter integration test: a device-contacts fixture list, a matching spoken/typed name, and the resulting auto-suggested phone number on the edit screen
