import { defineConfig } from 'vitest/config';
import vue from '@vitejs/plugin-vue';
import { fileURLToPath, URL } from 'node:url';

// Pure request-session tests do not require the dashboard-wide store fixtures.
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      dashboard: fileURLToPath(
        new URL('./app/javascript/dashboard', import.meta.url)
      ),
      shared: fileURLToPath(
        new URL('./app/javascript/shared', import.meta.url)
      ),
    },
  },
  test: {
    globals: true,
    environment: 'node',
    include: [
      'app/javascript/dashboard/components-next/jrcCopilot/specs/*.spec.js',
    ],
    maxWorkers: 1,
    minWorkers: 1,
  },
});
