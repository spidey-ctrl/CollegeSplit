---
status: accepted
---

# Backend framework and hosting: NestJS on Cloud Run, Postgres on Neon

The custom backend (ADR-0004) is NestJS (Node.js/TypeScript), deployed to Google Cloud Run, with PostgreSQL hosted on Neon. Chosen primarily for free-tier fit at early stage: Cloud Run's always-free tier (2M requests/month) and Neon's free Postgres tier cover an app with low initial traffic at zero hosting cost, and Cloud Run sits naturally alongside Firebase (both Google Cloud products) already in use for Auth and FCM (ADR-0004). Trade-off: Neon's free tier auto-suspends the database after inactivity, adding a cold-start delay to the first request after an idle period — acceptable for this stage, worth revisiting if it becomes user-visible.
