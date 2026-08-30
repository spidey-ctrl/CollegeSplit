import { defineConfig } from 'vitest/config';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    globals: true,
    root: './',
    include: ['**/*.e2e-spec.ts'],
    // DB-backed tests run against a pooled Neon connection; each create now
    // also hits Contacts queries, so grant a generous per-test budget.
    testTimeout: 30000,
  },
});
