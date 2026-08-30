# 11: Registered-User matching + in-app Share notification

**What to build:** A User can optionally add a private phone number to their own profile. Share then resolves a Participant to a registered User by exact phone match only, and on a match delivers an in-app push notification linking to a read-only view scoped to just that shared Expense/Balance.

**Blocked by:** 01 (Project scaffolding + Google Sign-In walking skeleton), 05 (Contacts: accumulation, phone number, local matching), 10 (Share: native fallback + phone pre-targeting)

**Status:** ready-for-agent

- [ ] A User can optionally add a phone number to their own profile via settings; it's never displayed to any other User anywhere in the app, and is unrelated to sign-in
- [ ] Firebase Cloud Messaging is wired up: device tokens registered per signed-in User
- [ ] Share resolves a Participant to a registered User by exact phone-number match only — never by name
- [ ] On a match, Share dispatches an FCM push notification linking to a read-only view scoped to just that shared Expense/Balance, instead of the native share-sheet fallback from ticket 10
- [ ] `GET /shared/:id` serves that read-only view; it grants no edit access and doesn't expose the sender's full Ledger
- [ ] Editing a previously-Shared Expense does not trigger a new notification to the recipient
- [ ] Backend integration test: a Participant phone number matching a registered User's on-file phone triggers a push dispatch and a fetchable read-only view; a non-matching or absent phone number falls back to ticket 10's native-share behavior
- [ ] Flutter integration test: receiving a (simulated) push notification and opening it to the read-only shared view
