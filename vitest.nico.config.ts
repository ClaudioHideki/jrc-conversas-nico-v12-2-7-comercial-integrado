import { defineConfig } from 'vitest/config';

// Pure request-session tests do not require the dashboard-wide store fixtures.
export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['app/javascript/dashboard/components-next/jrcCopilot/specs/*.spec.js'],
    maxWorkers: 1,
    minWorkers: 1,
  },
});
