import { defineConfig, devices } from '@playwright/test'

const deployment = process.env.E2E_SITE_DEPLOYMENT ?? 'indexedex'
if (!['indexedex', 'dtf'].includes(deployment)) throw new Error('Invalid E2E_SITE_DEPLOYMENT')
const port = deployment === 'dtf' ? 3013 : 3012
const baseURL = process.env.E2E_BASE_URL ?? `http://127.0.0.1:${port}`

export default defineConfig({
  testDir: './e2e/deployment',
  forbidOnly: !!process.env.CI,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  timeout: 90_000,
  expect: { timeout: 20_000 },
  use: { baseURL, screenshot: 'only-on-failure' },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 7'] } },
  ],
  webServer: process.env.E2E_BASE_URL ? undefined : {
    command: `npm run start -- -p ${port}`,
    url: baseURL,
    reuseExistingServer: false,
    env: { NEXT_PUBLIC_SITE_DEPLOYMENT: deployment },
  },
})
