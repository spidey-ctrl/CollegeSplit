---
status: accepted
---

# Flutter + Dart as the mobile app framework

CollegeSplit is built with Flutter (Dart) for a single, code-shared mobile codebase, rather than separate native apps or another cross-platform framework. Flutter is chosen for a single Dart codebase across platforms and for its plugin layer, which covers every native integration already agreed on — voice capture and Hindi/Hinglish speech-to-text, reading the device contact list to auto-suggest phone numbers, Google Sign-In, and the native OS share sheet for Share's fallback path.

**Scope revision (recorded while building):** this submission targets **Android only** (ADR-0002 revised). iOS is explicitly out of scope for the current build/demo — no iOS toolchain setup, no iOS-specific plugin configuration is required. The codebase is written to remain iOS-portable (no Android-only APIs smuggled into shared logic, Flutter's cross-platform plugin interfaces used throughout), so enabling iOS later is a matter of adding the target + platform config rather than a rewrite. This revision does not change the framework choice, only which platform is built and demoed now.

