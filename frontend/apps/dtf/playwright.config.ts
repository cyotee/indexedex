import { defineConfig, devices } from '@playwright/test'

const PORT = Number(process.env.E2E_PORT ?? 3002)
const BASE_URL = process.env.E2E_BASE_URL ?? `http://127.0.0.1:${PORT}`

/**
 * DTF (Down To Finance) Playwright config.
 * Default target: Robinhood chain id 4663 + local Anvil RPC (see e2e/wallet/).
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],
  timeout: 90_000,
  expect: { timeout: 20_000 },
  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'off',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: process.env.E2E_SKIP_WEBSERVER
    ? undefined
    : {
        command: process.env.E2E_WEB_SERVER_CMD ?? `npm run start -- -p ${PORT}`,
        url: BASE_URL,
        reuseExistingServer: !process.env.CI,
        timeout: 180_000,
        stdout: 'pipe',
        stderr: 'pipe',
        env: {
          ...process.env,
          NEXT_PUBLIC_DEFAULT_CHAIN_ID: process.env.E2E_CHAIN_ID ?? '4663',
          NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT:
            process.env.NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT ?? 'anvil_robinhood_main',
          NEXT_PUBLIC_LOCAL_RPC_URL:
            process.env.E2E_RPC_URL ?? process.env.NEXT_PUBLIC_LOCAL_RPC_URL ?? 'http://127.0.0.1:8545',
        },
      },
})
