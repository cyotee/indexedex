---
name: defi-ui-anvil-fixtures
description: This skill should be used when building Anvil-backed Playwright fixtures for DeFi UI tests — snapshots, time travel, mining, impersonation, and multi-account chain helpers.
license: MIT
---

## IndexedEx precedence (2026-10-19)

Current IndexedEx CLAUDE.md, product/testing law and the existing injected-wallet
Playwright framework take precedence over generic examples below. Use
frontend/apps/indexedex, not the older apps/dtf layout. Connector stubs are
isolated UI tests only, never replacements for real contract/money-path checks.
MetaMask automation is not enabled for this repository. Read the local
[IndexedEx context](references/INDEXEDEX.md) for actual network, reset, fixture,
secret and signing/broadcast authorization rules before applying an example.

**Source-version caveat (2026-10-19):** archived source has no pinned upstream
revision; Synpress v4 examples are reference-only and not installed or executed.
The original MIT metadata is retained, but no original license file was found;
[provenance](PORT_PROVENANCE.md) records that gap and all port adaptations.

# Anvil Fixtures for DeFi UI Tests

Chain helpers for the existing injected-wallet suite and isolated UI tests. Only an authorized disposable local node may be mutated.

## Test client fixture

This is an opt-in helper example, not an existing IndexedEx anvil fixture. When combined with walletPage, configure its E2E_RPC_URL to the same disposable RPC before the run or explicitly installInjectedWallet with that rpcUrl; browser and chain helper must never target different nodes. Reuse e2e/staking-migration-live.spec.ts for the actual current procedure.

```ts
// Example e2e/anvil.ts, imported only by authorized disposable-fork tests.
import { test as base, DEFAULT_E2E_CHAIN_ID } from './wallet/fixture'
import { createTestClient, http, parseEther, publicActions, walletActions } from 'viem'
import { foundry } from 'viem/chains'

const disposableRpc = process.env.E2E_MIGRATION_RPC_URL
if (!disposableRpc) throw new Error('Opt into a disposable fork explicitly')
const endpoint = new URL(disposableRpc)
if (!['127.0.0.1', 'localhost'].includes(endpoint.hostname) || endpoint.port === '8545') {
  throw new Error('Use a separate loopback fork, never the persistent 8545 node')
}

export const anvilClient = createTestClient({
  chain: { ...foundry, id: DEFAULT_E2E_CHAIN_ID, name: 'Robinhood (disposable Anvil)', rpcUrls: { default: { http: [disposableRpc] } } },
  mode: 'anvil',
  transport: http(disposableRpc),
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
    async deal(address: `0x${string}`, eth: string) {
      return client.setBalance({
        address,
        value: parseEther(eth),
      })
    },
  }))

export const test = base.extend<{ anvil: typeof anvilClient }>({
  anvil: async ({}, use) => {
    if (await anvilClient.getChainId() !== DEFAULT_E2E_CHAIN_ID) {
      throw new Error('Disposable fork chain does not match configured wallet')
    }
    await use(anvilClient)
  },
})
```

## Snapshots (required with time travel)

Anvil cannot move block time **backwards**. Take a new snapshot before each test and revert after, only on an authorized disposable fork. Never reset the shared node.

```ts
let id: `0x${string}` | undefined

test.beforeEach(async ({ anvil }) => {
  id = await anvil.snapshot()
})

test.afterEach(async ({ anvil }) => {
  if (id) {
    const reverted = await anvil.request({ method: 'evm_revert', params: [id] })
    if (reverted !== true) throw new Error('Snapshot revert failed')
    id = undefined
  }
})
```

A reverted snapshot is consumed; obtain another for the next test. Follow the actual migration suite opt-in and disposable-port checks in references/INDEXEDEX.md.

## Browser + chain time sync (Method A friendly)

The inspected framework has no date.set fixture. Use the syncDate helper above to set chain time and mine, then assert the actual bounded UI state. If browser time matters, add scoped clock control and restore it during teardown; never use fixed sleeps for readiness.

Use for vesting, funding periods, epoch-based emissions UIs.

## Fork testing

Use an operator-provided deployment or an authorized disposable fork at a pinned block with matching artifacts. Do not start a generic unseeded Anvil or expose upstream RPC credentials in logs.

Impersonate whales:

```ts
await anvil.impersonateAccount({ address: WHALE })
await anvil.setBalance({ address: WHALE, value: parseEther('100') })
// Authorized local-fork txs only; stop impersonation in teardown even on failure.
```

An isolated stub can display a whale address but proves no writes. Use installInjectedWallet unlockedAddress for authorized disposable-fork writes to real contracts. Never mock the SUT.

## Parallelism warning

Shared Anvil + `fullyParallel: true` ⇒ races. Prefer:

- `fullyParallel: false`, or  
- One Anvil per worker (different ports) — heavier  

## Existing webServer

Reuse frontend/apps/indexedex/playwright.config.ts (port 3002, one worker). E2E_SKIP_WEBSERVER=1 attaches to an operator-provided app. The config does not start Anvil. Select main versus fee_detf artifacts explicitly.

## See also

- Existing app config, e2e/wallet/fixture.ts and e2e/helpers/connect.ts.
- [Scenario patterns](../defi-ui-test-patterns/SKILL.md). No compatibility plugin required.  
