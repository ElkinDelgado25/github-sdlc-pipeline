'use strict';

const { defineConfig, devices } = require('@playwright/test');

const PORT = Number(process.env.PORT) || 3000;
const BASE_URL = process.env.E2E_BASE_URL || `http://127.0.0.1:${PORT}`;

module.exports = defineConfig({
  testDir: './tests/e2e',
  // En CI fallamos si alguien dejó un test.only olvidado.
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI
    ? [['github'], ['html', { open: 'never' }]]
    : [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  // Playwright levanta el servidor solo si E2E_BASE_URL no apunta a un entorno ya desplegado.
  webServer: process.env.E2E_BASE_URL
    ? undefined
    : {
        command: 'node src/server.js',
        url: BASE_URL,
        reuseExistingServer: !process.env.CI,
        timeout: 60_000,
      },
});
