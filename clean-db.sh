#!/usr/bin/env bash
# Clean the database: drop and recreate all tables to a fresh empty schema.
# Re-applies all Prisma migrations from scratch. Destructive — all data is lost.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/server"

if [[ ! -f .env ]]; then
  echo "ERROR: server/.env is missing. Create it from .env.example first." >&2
  exit 1
fi

npx prisma migrate reset --force

echo "Database cleaned and reset to a fresh schema."
