import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  timeout: 90_000,
  expect: { timeout: 20_000 },
  use: { baseURL: process.env.E2E_BASE_URL ?? 'http://127.0.0.1:3013' },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 7'] } },
  ],
  webServer: process.env.E2E_BASE_URL ? undefined : {
    command: 'npm run start -- -p 3013',
    url: 'http://127.0.0.1:3013',
    reuseExistingServer: !process.env.CI,
  },
})
