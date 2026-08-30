---
status: accepted
---

# Prisma as the data-access + migration tool for the NestJS backend

The custom backend (ADR-0004, ADR-0005) uses Prisma as its ORM and migration tool against Postgres/Neon, chosen over TypeORM and Knex.

Prisma's schema-as-source-of-truth maps directly onto the conceptual data model in the spec — User, Contact, Participant, Expense, Split, Group — as a single declarative schema file from which generated types and migrations are derived, avoiding hand-kept-in-sync model layers across the TypeScript service code.

The money/split behaviour reinforces the choice: computing per-Participant shares (Equal/Ratio/Adhoc), aggregating Balances per counterparty from many Expense/Split rows (`net = paid − fairShare`), and Ticket 07's atomically zeroing a whole Balance with one counterparty are natural Prisma queries and transactions — the relational reads the hybrid backend exists for (ADR-0004). Prisma's `prisma migrate deploy` applies migrations idempotently at deploy time on Cloud Run.

Suitability for our constraints: full Windows support (we develop on Windows), Node 24 compatibility, and a typed-query story that pairs cleanly with the OpenAPI-codegen integration (ADR-0006). TypeORM is more NestJS-native but clunkier for a greenfield multi-entity relational schema; Knex is too low-level (no schema-as-source, hand-written joins/boilerplate) for this entity/relation count.

Trade-off: Prisma is a heavier runtime dependency than Knex and its schema DSL is Prisma-specific, so the data layer is coupled to Prisma — acceptable given the domain is stable and the entities are known up front.
