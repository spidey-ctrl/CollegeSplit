# Voice Expense Entry, Splitting, and Auto-Categorization

## Problem Statement

Logging a shared expense today means stopping to open an app, manually typing the amount, hunting for the right category, and typing in the names of everyone it's shared with — and if one of those people has never used the app before, either they have to go through a sign-up flow first, or the expense doesn't get tracked accurately at all. This friction means expenses get logged late, inconsistently, or not at all, especially for the fast, one-off situations (a cab fare split with someone you just met, a round of chai) that make up a lot of a college student's day-to-day spending.

## Solution

A mobile app where a User adds an Expense by speaking it naturally — amount, who it's shared with, and (for the common cases) how it's split — and the app transcribes it, infers a Category, and drops the User onto a review/edit screen to confirm or correct anything before it's saved. The people an Expense is shared with (Participants) never need an account or any setup of their own: they're identified by name (and optionally a phone number picked up from the User's own device contacts), with zero friction on their side. The app remembers people it's seen before (as Contacts) and lets the User group them (as Groups, e.g. "Roommates") without ever requiring explicit contact management. It tracks who owes whom (a private Ledger per User) without moving any real money, and lets a User optionally notify someone about what they owe via Share.

## User Stories

### Voice capture

1. As a User, I want to add an Expense by speaking a single sentence describing it, so that I don't have to fill out a form for every small purchase.
2. As a User, I want the app to transcribe my speech and pre-fill an Expense with the amount, Category, Payer, Participants, and Split Method it understood, so that I only have to correct what it got wrong rather than enter everything manually.
3. As a User, I want to speak in English, Hindi, or a natural mix of both (Hinglish), so that I can talk to the app the way I actually talk to my friends.
4. As a User, when the app can't confidently extract a required field (like the amount) from what I said, I want to land on the edit screen with that field left blank and highlighted, so that I can fill in just the missing piece rather than redo the whole entry.
5. As a User, I want each voice capture to produce exactly one Expense, so that the app's understanding of what I said stays predictable (I can always speak a second time for a second Expense).
6. As a User, I want to say an Equal split out loud ("split with Alex and Sam") and have the app apply it correctly, so that the most common case needs no manual editing at all.
7. As a User, I want to say a Ratio split out loud ("Alex owes 30%, I'll cover the rest") and have the app infer the remainder correctly when I only name some people's shares, so that I don't have to do the arithmetic myself before speaking.

### Reviewing and editing

8. As a User, I want to review and edit every field the app inferred from my voice — amount, Category, Payer, Participants, Split Method — before the Expense is saved, so that a misheard or misunderstood detail never silently makes it into my Ledger.
9. As a User, I want to switch an Expense to an Adhoc split (exact amount per person) on the edit screen, so that I can handle cases too fiddly to describe out loud.
10. As a User, I want to change who the Payer was (not just assume it was always me), so that an Expense someone else fronted still produces the correct direction of debt.
11. As a User, I want to edit or delete an Expense at any time, even after it's been Settled or Shared, so that correcting a mistake is never blocked.
12. As a User, when I edit a Settled Expense, I want the Balance it was part of to reopen automatically, so that my Ledger stays accurate rather than silently wrong.
13. As a User, I want to log a purely personal Expense with no Participants at all, so that I can track my own spending without being forced into a split.

### Categorization

14. As a User, I want the app to automatically infer a Category for my Expense from what I said (e.g. Food & Drink, Transport, Groceries, Rent & Utilities, Travel, Entertainment, Other), so that I don't have to pick one myself for every entry.
15. As a User, I want to change the inferred Category with a simple picker on the edit screen, so that a wrong guess is a one-tap fix.

### People: Contacts, Participants, and Groups

16. As a User, I want to name someone in my Expense just by saying their first name, with zero setup required on their end, so that splitting with a stranger or a one-off acquaintance is exactly as easy as splitting with my roommate.
17. As a User, I want the app to remember people I've split with before as Contacts, without my ever having to explicitly add them, so that a "friends list" builds itself as a byproduct of normal use.
18. As a User, when I say a name that closely matches an existing Contact, I want it auto-linked without me having to confirm, so that re-entering the same person's name each time is frictionless.
19. As a User, when a spoken name is ambiguous against my Contacts, I want the app to ask me to disambiguate on the edit screen rather than silently guessing, so that I never misattribute a debt to the wrong person.
20. As a User, I want the app to auto-suggest a phone number for a Participant by matching the spoken name against my device's own contact list (with my permission), so that adding a phone number doesn't require me to look it up and type it in myself.
21. As a User, I want to manually add or edit a Participant's phone number on the edit screen for anyone not in my device contacts, so that I'm never blocked from attaching one.
22. As a User, when I add a Participant with no phone number at all, I want them treated as a one-off, ephemeral record that the app won't try to match against other name-only records later, so that the app doesn't silently and unreliably guess at whether two same-named strangers are the same person.
23. As a User, I want to save a named Group of Contacts (e.g. "Roommates"), so that I don't have to name the same set of people on every recurring Expense.

### Ledger and Balances

24. As a User, I want a private Ledger that only I can see, showing who owes whom based on my Expenses, so that I have an accurate personal record without needing anyone else to have an account.
25. As a User, I want to see my net Balance with each person I've split Expenses with, so that I know at a glance who I owe or am owed.
26. As a User, I want to mark my whole running Balance with a person as Settled in one action (not Expense by Expense), so that squaring up after a trip or a month of shared costs isn't twelve separate taps.

### Sharing

27. As a User, I want to share a single Expense or my aggregate Balance with someone, so that I can let them know what they owe without having to explain it myself.
28. As a User, when the person I'm sharing with is a registered User of the app themselves, I want them to get an in-app notification with a read-only view of just that Expense or Balance, so that they see it clearly without me having to leave the app.
29. As a User, when the person I'm sharing with is not a registered User, I want Share to hand off to my phone's normal share sheet (WhatsApp, SMS, etc.) with a text summary, so that I can still reach them through whatever app we already use to talk.
30. As a User, when I have a phone number on file for the person I'm sharing with, I want the share to be pre-targeted directly at their chat/number (e.g. a WhatsApp deep link), so that it's a single tap rather than me having to find them in the target app myself.
31. As a User, when I don't have a phone number on file for the person I'm sharing with, I want Share to still work by opening a generic share sheet I can pick a recipient from myself, so that missing a phone number never blocks me from sharing.
32. As a registered User receiving a Share notification, I want to see only the specific Expense or Balance that was shared with me — not the sender's whole Ledger — so that my view stays scoped to what was actually shared.
33. As a User, I don't want a recipient's view of a shared Expense to grant them edit access or merge our Ledgers, so that sharing stays informational only, never collaborative bookkeeping.
34. As a User editing a previously Shared Expense, I don't want a new notification sent to the recipient on every edit, so that they aren't spammed every time I make a small correction.

### Account and privacy

35. As a User, I want to sign up and sign in with Google only, so that I don't need to create or remember a separate password.
36. As a User, I want adding my own phone number to my profile to be entirely optional, so that a privacy-conscious User can use the full app without ever supplying one.
37. As a User, I want my own phone number, if I add one, to never be shown to any other User anywhere in the app, so that I know it's used purely as an internal matching key and nothing more.
38. As a User, I want to be matched to Share notifications only by an exact phone number match — never by name — so that I never receive (or send) a notification meant for a different person who happens to share my name.

## Implementation Decisions

**Modules (NestJS backend):**
- **Auth**: verifies the Firebase ID token issued by Firebase Auth (Google Sign-In) on each request; no separate password store.
- **Users**: profile data, including the optional, private phone number used solely as the Share-matching key.
- **Voice**: accepts recorded audio, calls Sarvam for transcription, then Gemini for structured extraction (amount, Payer, Participants, Split Method guess, Category guess); returns a draft Expense payload to the client for review. Nothing is persisted at this stage — persistence happens only when the User confirms on the edit screen.
- **Contacts**: per-User list, auto-populated from repeated Participants; owns the local, name-based fuzzy-matching/disambiguation logic (scoped to one User's own Contacts, never across the whole user base).
- **Groups**: named sets of Contacts, owned per-User.
- **Expenses**: create/edit/delete; owns Split computation (Equal, Ratio with remainder-inference, Adhoc) and Payer assignment; editing or deleting a Settled Expense reopens the Balance it contributed to.
- **Ledger**: read-side aggregation of Balances (overall and per-counterparty), computed from Expenses and Splits rather than maintained as separately-mutated state, to avoid drift between the two.
- **Settle**: zeroes a User's whole running Balance with one counterparty at once and marks every contributing Expense as settled.
- **Share**: resolves a Participant to a registered User by exact phone-number match only (never by name, to avoid the "which Priya?" collision at whole-user-base scale, distinct from Contacts' local fuzzy matching); on a match, dispatches an FCM push linking to a read-only view scoped to just the shared Expense/Balance; on no match, returns a payload for the client to hand off to the native OS share sheet, pre-targeted at the Participant's phone number when one is on file.

**API contract**: REST, with an OpenAPI spec generated from NestJS decorators and a Dart client generated from that spec — no hand-maintained request/response models on the Flutter side. Balance/Ledger data is fetched on demand (screen open, pull-to-refresh); FCM pushes double as the signal to refresh in the background rather than a realtime subscription, since a User's Ledger is private and never viewed live by anyone else.

**Data model (conceptual)**: User (Google identity, optional private phone), Contact (owned by a User, name + optional phone, optionally resolved to a registered User via phone match), Group (owned by a User, a named set of Contacts), Expense (amount in INR, Category, Payer, zero or more Participants, Split Method, settled state), and Split rows (per-Participant share, computed per the Split Method). Balance is a derived read, not a separately stored mutable value.

**Third-party dependencies**: Sarvam (speech-to-text, Hindi/Hinglish) and Gemini (structured extraction from transcript) are called only from the backend — never directly from the Flutter client — so their API keys are never exposed on-device. Firebase is scoped narrowly to Auth (Google Sign-In) and FCM (push); all domain data lives in Postgres, not Firestore.

**Repo/hosting**: monorepo (`/app` for Flutter, `/server` for NestJS); NestJS deployed to Google Cloud Run, Postgres hosted on Neon; Flutter state management via Riverpod.

**Full architectural rationale**: see ADR-0001 through ADR-0006 in `docs/adr/`, and the canonical vocabulary in `CONTEXT.md`.

## Testing Decisions

This is a greenfield codebase — there is no prior in-repo test art to follow, so these conventions should be established from the first commit:

- **Test external behavior, not internals.** Assert on API responses and resulting database state (e.g. "given these Expenses, `GET` the Balance for this counterparty and it equals X") rather than on internal service method calls or intermediate data structures.
- **Backend seam**: integration tests that make real HTTP requests into the running NestJS app, backed by a real (disposable, per-test-run) Postgres database — not mocked repositories or services. This is the primary seam and should cover Expense/Split/Balance/Settle/Share/Group/Contact-matching behavior end to end through the actual API contract.
- **Voice pipeline within the backend seam**: Sarvam and Gemini are swapped for a fake provider implementing the same interface, returning fixture transcripts and structured extractions. No test hits the real paid APIs; this keeps the voice-parsing-to-draft-Expense mapping covered by the same integration tests without network flakiness or cost.
- **Flutter seam**: UI/integration tests that drive actual screens (voice capture entry → edit/review screen → confirm → appears in Ledger; the settle flow; the share flow) against a stub HTTP server returning fixtures shaped like the real OpenAPI contract — not widget-level tests of individual providers or components in isolation.

## Out of Scope

- Real payment/money movement of any kind (ADR-0001) — settlement is always recorded, never processed.
- Multi-currency support — INR only.
- Recurring or scheduled Expenses (e.g. auto-generated monthly rent) — Groups only remove the friction of re-naming people, not of re-entering the Expense itself.
- Parsing multiple Expenses out of a single voice capture — always exactly one Expense per capture.
- A shared/synced Ledger between two Users — every User's Ledger is private; Share is a one-directional, read-only notification, never a merged or collaborative record.
- Custom or user-defined Categories — a fixed system taxonomy only.
- A web app — mobile (Flutter, iOS/Android) only for this scope.
- Offline voice capture — Sarvam and Gemini are both network-dependent third-party APIs; there is no offline fallback.
- Outbound automated messaging (SMS, WhatsApp Business messages, etc.) sent by the app itself — Share only ever hands off to the User's own native share sheet or an in-app notification to an already-registered User; the app never messages a non-User on the User's behalf.
- Phone-number/OTP sign-up — Google Sign-In is the only sign-up/sign-in method.

## Further Notes

- Test seams were proposed and confirmed with the developer before writing this spec: (1) backend API integration tests against a real test Postgres with a fake voice provider, and (2) Flutter UI integration tests against a stubbed backend.
- Hosting free-tier caveat: Neon's free Postgres tier auto-suspends after inactivity, adding a cold-start delay to the first request after an idle period (ADR-0005) — worth revisiting if it becomes user-visible.
- Sarvam and Gemini both have their own metered free/trial tiers, separate from hosting; confirm current limits directly with each provider before committing, since API pricing changes independently of the rest of this stack.
- This spec was produced from an extended domain-modeling and architecture discussion rather than a fresh interview; `CONTEXT.md` and `docs/adr/0001`–`0006` are the canonical source for terminology and rationale and should be kept in sync if requirements shift during implementation.
- Publishing to the project issue tracker with the `ready-for-agent` label is still pending — the tracker and triage label vocabulary haven't been configured for this project yet. Run `/setup-matt-pocock-skills` to set that up, then this spec can be published.
