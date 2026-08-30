# 08: Edit/delete a saved Expense, including reopening a settled Balance

**What to build:** A User can edit or delete any past Expense from their history at any time; editing or deleting a Settled one automatically reopens the Balance it belonged to.

**Blocked by:** 07 (Settle)

**Status:** ready-for-agent

- [ ] A history/list view of a User's past Expenses, with edit and delete actions available on each, regardless of settled state
- [ ] `PATCH /expenses/:id` and `DELETE /expenses/:id`, usable on any Expense including ones already marked settled
- [ ] Editing or deleting a settled Expense reopens the Balance it contributed to (recalculated fresh)
- [ ] Backend integration test: settle a Balance, edit/delete one of its contributing Expenses, and verify the Balance is reopened and correctly recalculated
- [ ] Flutter integration test: editing a settled Expense from the history view and seeing the Balance reopen
