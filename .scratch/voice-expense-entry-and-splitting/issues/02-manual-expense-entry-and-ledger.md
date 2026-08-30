# 02: Manual Expense entry with Ledger/Balance

**What to build:** A User can manually add an Expense — amount, Category, Payer, Participants, Split Method — with no voice involved, and see the resulting Balance per counterparty on their private Ledger. Proves out the core domain model before voice complexity layers on top.

**Blocked by:** 01 (Project scaffolding + Google Sign-In walking skeleton)

**Status:** ready-for-agent

- [ ] Expense schema: amount (INR), Category (fixed taxonomy), Payer (defaults to the signed-in User), zero or more Participants, Split Method (Equal/Ratio/Adhoc)
- [ ] `POST /expenses` creates an Expense with a chosen Split Method (Equal, Ratio, or Adhoc) and computes per-Participant shares accordingly
- [ ] Participants can be entered as free-text names (no Contact-matching yet — that's ticket 05)
- [ ] A User can create a zero-Participant (personal) Expense
- [ ] `GET /ledger` returns the User's aggregate Balance per counterparty, computed from their Expenses and Splits (not a separately stored mutable value)
- [ ] Flutter: a manual "add expense" form (amount, Category picker, Payer, Participants, Split Method) and a Ledger/Balance screen showing per-counterparty Balances
- [ ] Backend integration tests covering Equal, Ratio, and Adhoc split computation and the resulting Balance
- [ ] Flutter integration test: adding an Expense through the form and seeing the correct Balance appear on the Ledger screen
