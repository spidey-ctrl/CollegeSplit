# CollegeSplit

A mobile app for logging personal expenses by voice and splitting their cost with other people, without requiring those people to have accounts.

## Language

### People

**User**:
A person who has installed CollegeSplit and created their own account via Google Sign-In. Each User has their own private Ledger — Ledgers are never shared or synced between Users. A User may optionally add a phone number to their own profile, stored privately and used only as a matching key for Share (below); it is never displayed to other Users and is unrelated to sign-in.
_Avoid_: primary user, account holder

**Contact**:
A person a User has previously split an Expense with, remembered by the app for reuse across future Expenses. Requires no explicit setup — it accumulates automatically from Participants used more than once. May, separately, also happen to be a User in their own right (matched by phone number) — this does not merge or share Ledgers, it only enables Share (below).
_Avoid_: Friend

**Participant**:
A person named on a single Expense as sharing its cost, created inline with just a name and, optionally, a phone number — with zero onboarding required. If a phone number is given, it's the identity key used to recognize the same person across Expenses; without one, the Participant is name-only and ephemeral (the app won't try to match it to other records later). May or may not later become a Contact.
_Avoid_: Friend

**Group**:
A saved, named set of Contacts a User splits Expenses with repeatedly (e.g. "Roommates"), used to avoid re-naming the same people on every Expense.

### Money & splitting

**Expense**:
A single spend event entered by a User, with an amount (in INR), a Category, a Payer, and zero or more Participants who share its cost.

**Payer**:
The person who fronted the money for an Expense — the User by default, but editable to any Participant. Determines the direction of the resulting Balance.

**Split**:
How an Expense's amount is divided among its Participants.

**Split Method**:
The rule used to compute a Split: **Equal** (divided evenly), **Ratio** (proportional shares, e.g. percentages), or **Adhoc** (manually entered exact amount per Participant). Equal and Ratio can be set by voice; Adhoc is entered on the edit screen only.

**Ledger**:
A User's own private record of who owes whom, computed from their Expenses and Splits. The system never moves money itself — it only tracks Balances; settlement happens outside the app (cash, a separate payment app, etc.).
_Avoid_: Payment, transaction

**Balance**:
The net amount one person owes another (or is owed) with a given counterparty, derived from a User's Ledger.

**Settle**:
The action of recording that a Balance with a person has been paid outside the app. Applies to the whole running Balance with that person at once (not one Expense at a time), zeroing it and marking every Expense that contributed to it as settled. Editing or deleting a settled Expense reopens the Balance it belonged to.
_Avoid_: Pay, payment

**Category**:
A fixed, system-defined classification of an Expense (e.g. Food & Drink, Transport, Groceries, Rent & Utilities, Travel, Entertainment, Other), inferred automatically from the voice transcript and editable by the user.

### Sharing

**Share**:
A User-initiated action that sends another person a read-only view of a single Expense or of the aggregate Balance owed with them. Matching a Participant to a registered User is done by exact phone number match only — never by name, since names collide across the whole user base in a way a User's own small Contact list doesn't. On a match, Share is delivered as an in-app notification linking to that read-only view. Without a match, it falls back to the device's native share sheet with a text summary — pre-targeted at the Participant's phone number when one is on file (e.g. a direct WhatsApp/SMS deep link), or left for the User to pick a recipient themselves when it isn't. Sharing never grants edit access or merges Ledgers.
