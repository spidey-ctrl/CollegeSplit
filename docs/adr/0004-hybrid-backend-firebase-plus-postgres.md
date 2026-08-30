---
status: accepted
---

# Hybrid backend: Firebase for auth/push, custom API + Postgres for domain data

Firebase is used narrowly for Google Sign-In (Firebase Auth) and Share's in-app push notifications (Firebase Cloud Messaging) — nothing else. All domain data (Users, Contacts, Participants, Expenses, Splits, Balances, Groups) lives in a custom backend API backed by PostgreSQL, not Firestore. We considered a full Firebase/Firestore approach for simplicity, but Balance and Settle require summing many Expense rows per counterparty and atomically zeroing a set of them at once — a natural fit for relational transactions and joins, and awkward in Firestore's document model. The custom API also proxies all Sarvam and Gemini calls so those API keys never reach the Flutter client.
