---
name: playwright-fixtures
description: This skill should be used when writing Playwright fixtures for dApp tests — test.extend, mergeTests, wallet fixtures, Anvil clients, and page.evaluate helpers.
license: MIT
---

# Playwright Fixtures for dApps

Fixtures establish the environment for each test: wallet connection, Anvil RPC client, time control. Prefer fixtures over copy-pasted setup in every spec.

## Extend and merge

```ts
// tests/fixtures/wallet.ts
import { test as base, type Page } from '@playwright/test'

export class WalletFixture {
  address?: `0x${string}`
  constructor(private page: Page) {}

  async connect(name: 'alice' | 'bob') {
    // setup mock account / click connect — app-specific
  }
}

export const test = base.extend<{ wallet: WalletFixture }>({
  wallet: async ({ page }, use) => {
    await use(new WalletFixture(page))
  },
})
```

```ts
// tests/fixtures/index.ts
import { mergeTests } from '@playwright/test'
import { test as walletTest } from './wallet'
import { test as anvilTest } from './anvil'

export * from '@playwright/test'
export const test = mergeTests(walletTest, anvilTest)
```

```ts
// tests/smoke.spec.ts
import { expect, test } from './fixtures'

test('connect', async ({ page, wallet }) => {
  await page.goto('/')
  await wallet.connect('alice')
  await expect(page.getByText(`Connected: ${wallet.address}`)).toBeVisible()
})
```

## Anvil client fixture

```ts
// tests/fixtures/anvil.ts
import { test as base } from '@playwright/test'
import { createTestClient, http, publicActions, walletActions } from 'viem'
import { foundry } from 'viem/chains'

const anvil = createTestClient({
  chain: foundry,
  mode: 'anvil',
  transport: http('http://127.0.0.1:8545'),
})
  .extend(publicActions)
  .extend(walletActions)
  .extend((client) => ({
    async syncDate(date: Date) {
      await client.setNextBlockTimestamp({
        timestamp: BigInt(Math.round(date.getTime() / 1000)),
      })
      return client.mine({ blocks: 1 })
    },
  }))

export const test = base.extend<{ anvil: typeof anvil }>({
  anvil: async ({}, use) => {
    await use(anvil)
  },
})
```

## Snapshot / restore between suites

```ts
let snapshotId: `0x${string}` | undefined

test.beforeAll(async ({ anvil }) => {
  snapshotId = await anvil.snapshot()
})

test.afterAll(async ({ anvil }) => {
  if (snapshotId) await anvil.revert({ id: snapshotId })
})
```

Required when tests advance chain time — Anvil cannot go backwards without revert/snapshot.

## `page.evaluate` and `waitForFunction`

Call in-page test hooks (e.g. Wagmi mock config):

```ts
await page.waitForFunction(() => (window as any)._setupAccount)
await page.evaluate(
  (args) => (window as any)._setupAccount(...args),
  [privateKey, features] as const
)
```

## `addInitScript` for browser Date

```ts
await page.addInitScript(`Date = class extends Date { /* patch */ }`)
await page.evaluate(() => { /* same patch without reload */ })
```

## Anti-patterns

- Putting all setup in `beforeEach` without fixtures (hard to compose)
- Parallel tests mutating the same Anvil state
- Hard-coding sleeps instead of `expect(...).toBeVisible()` / chain waits

## See also

- `defi-ui-mock-connector` — full wallet fixture with Wagmi mock
- `defi-ui-anvil-fixtures` — time travel + multi-account patterns
