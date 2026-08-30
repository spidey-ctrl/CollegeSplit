---
status: accepted
---

# Client-server integration: REST + OpenAPI codegen, fetch-on-demand, monorepo

The Flutter app and NestJS backend (ADR-0004, ADR-0005) live in one monorepo (`/app`, `/server`), talk over plain REST, and use an OpenAPI spec generated from NestJS decorators to generate a typed Dart client — avoiding hand-kept-in-sync request/response models across Dart and TypeScript without the operational overhead of GraphQL. Balance/Ledger data is fetched on demand (on screen open or pull-to-refresh) rather than pushed over a realtime connection: since each User's Ledger is private and never viewed live by anyone else (round 3 of the domain grill), there's no concurrent viewer to justify WebSocket infrastructure — Firebase Cloud Messaging, already used for Share notifications, doubles as the signal to refresh in the background when something relevant changed.
