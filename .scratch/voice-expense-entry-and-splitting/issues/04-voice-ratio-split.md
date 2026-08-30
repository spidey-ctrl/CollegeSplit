# 04: Ratio split via voice

**What to build:** A User can speak a Ratio split ("Alex owes 30%, I'll cover the rest") and have the app correctly infer the unstated remainder as the User's own share, prefilling the edit screen accordingly.

**Blocked by:** 03 (Voice capture: Equal split + auto-Category)

**Status:** ready-for-agent

- [x] Gemini extraction is extended to recognize a spoken Ratio split
- [x] When only some Participants' shares are stated, the remainder is inferred as the signed-in User's own share
- [x] The draft Expense prefills the edit screen with the inferred Ratio Split Method and per-Participant shares
- [x] Backend integration tests (fake provider) covering: fully-specified ratios, partial-specified ratios with inferred remainder, and a 3+-Participant ratio split
- [x] Flutter integration test: a voice capture resulting in a Ratio-split draft displayed and editable on the edit screen
