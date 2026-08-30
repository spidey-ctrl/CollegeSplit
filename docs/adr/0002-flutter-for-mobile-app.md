---
status: accepted
---

# Flutter + Dart as the mobile app framework

CollegeSplit is built with Flutter (Dart) for a single codebase across iOS and Android, rather than separate native apps or another cross-platform framework. This carries real lock-in (a full rewrite is the only way off it) and touches every native integration already agreed on — voice capture and Hindi/Hinglish speech-to-text, reading the device contact list to auto-suggest phone numbers, Google Sign-In, and the native OS share sheet for Share's fallback path — all of which will go through Flutter's platform-channel/plugin layer rather than being written natively.
