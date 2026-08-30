# 01: Project scaffolding + Google Sign-In walking skeleton

**What to build:** The monorepo, deployed backend, and a User signing in with Google and seeing their own name on a home screen — the full stack wired end to end, proving every layer before any feature work lands on top of it.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] Monorepo created with `/app` (Flutter) and `/server` (NestJS) directories
- [ ] NestJS backend deployed to Google Cloud Run; Postgres provisioned on Neon with a working migration tool
- [ ] OpenAPI spec generated from NestJS decorators, with a typed Dart client generated from it and consumed by the Flutter app
- [ ] Flutter app scaffolded with Riverpod for state management
- [ ] A User can sign in with Google via Firebase Auth on the Flutter app; the backend verifies the resulting Firebase ID token via the Firebase Admin SDK
- [ ] A signed-in User's profile (id, display name, email) is persisted in Postgres on first sign-in and returned by a `GET /me` endpoint
- [ ] After signing in, the User sees a home screen displaying their own name, fetched from `GET /me`
- [ ] Backend integration test: a request with a valid (test) Firebase ID token reaches a real Postgres-backed `/me` endpoint and returns the correct User
- [ ] Flutter integration test: driving the sign-in screen (with a fake auth provider) through to the home screen showing the User's name
