---
status: accepted
---

# Sarvam for speech-to-text, Gemini for parsing

Voice capture is a two-stage pipeline: the recorded audio is transcribed by the Sarvam API (chosen for its Hindi/Hinglish code-switching support, which general-purpose STT engines handle poorly), then the resulting transcript is sent to the Gemini API for structured extraction — amount, Payer, Participants, Split Method, and Category — which prefills the edit screen. Both are third-party API dependencies reachable only with network connectivity and a valid API key, so voice capture has no offline path in v1.
