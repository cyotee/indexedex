---
name: defi-ui-mock-connector
description: This skill should be used when implementing DeFi UI E2E with Playwright, Anvil, and Wagmi mock connector — window._setupAccount, fixtures, error features, without MetaMask extension.
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

# Isolated UI Tests: Playwright + Wagmi Mock Connector

Wallet-agnostic E2E: no browser extension. Based on patterns from [rombrom.com](https://www.rombrom.com/posts/testing-dapps-with-playwright-anvil-wagmi/).

## Why this method

- No MetaMask UI flakiness or version coupling  
- Programmatic rejections and errors via mock `features`  
- Impersonate any address (and private keys for signing clients)  
- Isolated connector/UI error tests only, not required money-path CI  

## 1. Optional isolated test-harness config

The examples below belong to a separate test-only harness, not IndexedEx production providers, root layout or normal E2E suite. The createClient example illustrates connector state, not verified real signing/contract execution. Use IndexedEx injected-wallet fixtures for money paths.

```ts
// Isolated test-harness module only, excluded from the production bundle.
import { createClient, http, isAddress } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { createConfig } from 'wagmi'
import { injected, mock, type MockParameters } from 'wagmi/connectors'
import { foundry, mainnet } from 'wagmi/chains'

// Source illustrative chains, not IndexedEx deployment config. No mainnet signing.
const chains = [mainnet, foundry] as const

export const config = createConfig({
  chains,
  client: ({ chain }) => createClient({ chain, transport: http() }),
  connectors: [injected()],
  ssr: true,
})

export function createMockConfig(
  addressOrPkey: `0x${string}`,
  features?: MockParameters['features']
) {
  const account = isAddress(addressOrPkey)
    ? addressOrPkey
    : privateKeyToAccount(addressOrPkey)
  const address = typeof account === 'string' ? account : account.address

  return createConfig({
    chains,
    connectors: [mock({ accounts: [address], features })],
    client: ({ chain }) =>
      createClient({
        account: typeof account === 'string' ? undefined : account,
        chain,
        transport: http(),
      }),
    ssr: true,
  })
}
```

## 2. Expose setup on `window` (test-only hook)

Only a dedicated isolated test build may contain this component and its test keys. Do not add this hook to the IndexedEx app. A runtime non-production check alone is insufficient. Keep harness config in React state for hot-swapping:

```tsx
// root layout / App providers
const [wagmiConfig, setWagmiConfig] = useState(config)

const _setupAccount = useCallback(
  (...args: Parameters<typeof createMockConfig>) => {
    setWagmiConfig(createMockConfig(...args))
  },
  []
)

if (typeof window !== 'undefined') {
  // This module exists only in the dedicated isolated test build.
  ;(window as any)._setupAccount = _setupAccount
}

return (
  <WagmiProvider config={wagmiConfig}>
    {children}
  </WagmiProvider>
)
```

Declare:

```ts
declare global {
  interface Window {
    _setupAccount: (...args: Parameters<typeof createMockConfig>) => void
  }
}
```

## 3. Wallet fixture

```ts
// tests/fixtures/wallet.ts
import { test as base, type Page } from '@playwright/test'
import { privateKeyToAccount } from 'viem/accounts'
import type { MockParameters } from 'wagmi/connectors'

const ACCOUNT_PKEYS = {
  alice: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
  bob: '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d',
} as const

export class WalletFixture {
  address?: `0x${string}`
  constructor(private page: Page) {}

  async connect(
    name: keyof typeof ACCOUNT_PKEYS,
    features?: MockParameters['features']
  ) {
    const pkey = ACCOUNT_PKEYS[name]
    this.address = privateKeyToAccount(pkey).address
    await this.page.waitForFunction(() => (window as any)._setupAccount, undefined, { timeout: 20_000 })
    await this.page.evaluate(
      ([key, feats]) => (window as any)._setupAccount(key, feats),
      [pkey, features] as const
    )
    await this.page.getByRole('button', { name: /Mock Connector/i }).click()
  }
}

export const test = base.extend<{ wallet: WalletFixture }>({
  wallet: async ({ page }, use) => {
    await use(new WalletFixture(page))
  },
})
```

## 4. Isolated harness examples

The pageerror case applies only if that harness intentionally rethrows. If the UI handles the rejection, assert its real error state and unchanged chain state instead. Do not force the production app to throw for this example.

```ts
import { expect, test } from './fixtures'
import { UserRejectedRequestError } from 'viem'

test('connect alice', async ({ page, wallet }) => {
  await page.goto('/')
  await wallet.connect('alice')
  await expect(page.getByText(`Connected: ${wallet.address}`)).toBeVisible()
})

test('user rejects connect', async ({ page, wallet }) => {
  await page.goto('/')
  const [error] = await Promise.all([
    page.waitForEvent('pageerror', { timeout: 20_000 }),
    wallet.connect('alice', {
      connectError: new UserRejectedRequestError(new Error('user rejected')),
    }),
  ])
  expect(error.name).toBe('UserRejectedRequestError')
})
```

## 5. Existing IndexedEx real-wallet fixture

Tests under frontend/apps/indexedex/e2e/ import test/expect from './wallet/fixture' and prepareLocalChain/connectInjectedWallet from './helpers/connect'. walletPage injects before load and signs real local transactions. Reuse the existing config, port 3002 and one-worker serialization; do not replace it with a mock harness or start another Anvil.

## Security / prod

- Never ship an always-on mock connector to production users  
- Exclude window._setupAccount, mock config and keys from production builds entirely  
- Test keys are public Anvil defaults only  

## Example repo

https://github.com/re-nft/blockchain-web-app-e2e-testing-remix-wagmi
