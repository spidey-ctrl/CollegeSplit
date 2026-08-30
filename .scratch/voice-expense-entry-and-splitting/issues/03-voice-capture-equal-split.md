# 03: Voice capture: Equal split + auto-Category

**What to build:** A User taps the mic, speaks a sentence in English or Hindi/Hinglish, and lands on the edit screen from ticket 02, pre-filled with the amount/Category/Payer/Participants/Equal-split the app understood — with any field it couldn't confidently extract left blank and highlighted.

**Blocked by:** 02 (Manual Expense entry with Ledger/Balance)

**Status:** ready-for-agent

- [ ] `POST /voice/capture` accepts recorded audio, calls Sarvam for transcription (English + Hindi/Hinglish), then Gemini for structured extraction (amount, Payer, Participants, Equal Split Method, Category), and returns a draft Expense payload — nothing is persisted at this stage
- [ ] Sarvam and Gemini are called only from the backend; API keys are never present in the Flutter client
- [ ] The draft prefills the same edit screen from ticket 02; the User can correct any field before confirming, which then calls the same `POST /expenses` from ticket 02
- [ ] When a required field (most importantly amount) can't be confidently extracted, it's left blank and highlighted on the edit screen rather than blocking entry or triggering a retry loop
- [ ] Flutter: a mic-capture entry point wired to `POST /voice/capture` and into the edit screen
- [ ] Backend integration tests use a fake Sarvam/Gemini provider (fixture transcripts and extractions) — no test hits the real paid APIs
- [ ] Flutter integration test: tapping the mic (with a fake capture result) through to a prefilled edit screen and a confirmed Expense
