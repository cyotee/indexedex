---
name: playwright-config
description: This skill should be used when configuring Playwright for dApp/DeFi E2E — fullyParallel, workers, webServer, Chromium-only projects, baseURL, retries, and CI settings.
license: MIT
---

# Playwright Config for DeFi UIs

## Minimal blockchain-friendly config

```ts
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests',
  // Blockchain state is often linear — avoid parallel tests in a file
  fullyParallel: false,
  workers: process.env.CI ? 1 : undefined,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: 'http://127.0.0.1:3000',
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
  webServer: [
    {
      command: 'anvil',
      url: 'http://127.0.0.1:8545',
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
    },
    {
      command: 'npm run dev',
      url: 'http://127.0.0.1:3000',
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
    },
  ],
})
```

## Why `fullyParallel: false` for chain tests

If enabled, Playwright may run **tests inside the same file in parallel**. Shared Anvil state (balances, nonces, time travel, snapshots) races and flakes. Prefer:

- Serial tests per file (`fullyParallel: false`)
- Or isolated Anvil per worker (heavier)
- Snapshots/reverts in `beforeAll` / `afterAll`

Synpress wallet-cache mode can restore higher parallelism for **independent** specs once the extension is cached.

## Pin the app port

Vite defaults to `5173`. Pin host/port so `baseURL` and `webServer.url` match:

```ts
// vite.config.ts
export default defineConfig({
  server: { host: '0.0.0.0', port: 3000 },
})
```

## Synpress-oriented notes

- Synpress currently targets **Chromium** projects.
- Keep a single browser project unless you also run mock-connector suites on other browsers.

## Timeouts

DeFi flows (approve + swap + mine) are slower than Web2:

```ts
export default defineConfig({
  timeout: 60_000,
  expect: { timeout: 15_000 },
  use: { actionTimeout: 15_000, navigationTimeout: 30_000 },
})
```

## package.json scripts

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:headed": "playwright test --headed",
    "test:e2e:report": "playwright show-report"
  }
}
```

## See also

- `playwright-webserver` — multi-service orchestration details
- `playwright-fixtures` — shared setup patterns
