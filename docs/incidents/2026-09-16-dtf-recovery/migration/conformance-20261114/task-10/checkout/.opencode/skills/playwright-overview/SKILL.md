---
name: playwright-overview
description: This skill should be used when the user asks about "Playwright", "E2E browser tests", "@playwright/test", "playwright config", or needs to set up or run browser end-to-end tests for a web or dApp UI.
license: MIT
---

# Playwright Overview

Playwright is a browser automation and E2E test runner for Chromium, Firefox, and WebKit. For DeFi UIs it is the base layer under both **mock-wallet** (Wagmi) and **real-wallet** (Synpress + MetaMask) approaches.

## Install

```bash
npm install --save-dev @playwright/test
npx playwright install
# Chromium is enough for most dApp E2E (Synpress currently Chromium-only)
npx playwright install chromium
```

## Quick smoke test

```ts
// tests/smoke.spec.ts
import { expect, test } from '@playwright/test'

test('load the homepage', async ({ page }) => {
  await page.goto('/')
  await expect(page).toHaveTitle(/App/)
})
```

```json
// package.json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui"
  }
}
```

## Core concepts

| Concept | Role in DeFi UI tests |
|---------|------------------------|
| `test` / `expect` | Assertions and test cases |
| `page` | Main dApp tab |
| `context` | Browser context (extensions share a context in Synpress) |
| Fixtures | Shared wallet, Anvil client, date helpers |
| `webServer` | Start Anvil + app before tests |
| `page.evaluate` | Call in-page helpers like `window._setupAccount` |
| `addInitScript` | Patch browser globals (e.g. `Date`) before navigation |

## Skills in this plugin

- `playwright-config` — config for serial blockchain tests, reports, CI
- `playwright-fixtures` — `test.extend`, `mergeTests`, wallet/anvil fixtures
- `playwright-webserver` — orchestrate Anvil + frontend via `webServer[]`

## Related marketplace plugins

- `synpress` — MetaMask extension automation on Playwright
- `metamask` — wallet flows, approvals, networks
- `defi-ui-testing` — both mock-connector and Synpress methods for DeFi UIs
- `wagmi`, `foundry` (`anvil-node`) — stack companions

## When not to use Playwright alone

Playwright has no built-in wallet. For wallet UX you either:

1. **Mock** — Wagmi `mock` connector + fixtures (`defi-ui-mock-connector`)
2. **Real extension** — Synpress + MetaMask (`defi-ui-synpress-metamask`)

## Official docs

- https://playwright.dev/docs/intro
- https://playwright.dev/docs/test-fixtures
- https://playwright.dev/docs/test-webserver
