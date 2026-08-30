# 07: Settle

**What to build:** A User can zero their whole running Balance with one counterparty in a single action, marking every contributing Expense as settled underneath.

**Blocked by:** 02 (Manual Expense entry with Ledger/Balance)

**Status:** ready-for-agent

- [x] `POST /ledger/:contactId/settle` zeroes the User's whole running Balance with that counterparty in one action
- [x] Every Expense contributing to that Balance is marked settled as part of the same action
- [x] Flutter: a "Settle" action on a counterparty's Balance view, with a confirmation step
- [x] Backend integration test: multiple unsettled Expenses with one counterparty, settle, and verify the Balance is zero and every contributing Expense is marked settled
- [x] Flutter integration test: tapping Settle on a Balance and seeing it go to zero
