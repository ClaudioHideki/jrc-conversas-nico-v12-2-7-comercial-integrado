import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e/ui',
  testMatch: 'jrc-broker-contract.spec.ts',
  timeout: 150000,
  expect: { timeout: 20000 },
  workers: 1,
  retries: 0,
  reporter: 'line',
  outputDir: '../../.codex/j5-browser-results',
  use: {
    baseURL: 'https://localhost:18443',
    channel: 'chrome',
    headless: true,
    // Trust only the ephemeral local harness certificate; backend TLS remains fully verified.
    ignoreHTTPSErrors: true,
    trace: 'off',
    video: 'off',
    screenshot: 'off',
  },
  projects: [
    { name: 'desktop', use: { viewport: { width: 1440, height: 1000 } } },
    { name: 'mobile', use: { viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true } },
  ],
});
