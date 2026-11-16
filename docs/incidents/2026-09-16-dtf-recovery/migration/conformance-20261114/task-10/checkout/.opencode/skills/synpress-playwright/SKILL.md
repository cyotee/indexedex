---
name: synpress-playwright
description: This skill should be used when writing Playwright tests with Synpress — testWithSynpress, metaMaskFixtures, connecting dApps, confirming txs, and page objects with MetaMask.
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

# Synpress + Playwright Tests

## Archived extension bootstrap (reference only)

Current IndexedEx law prohibits MetaMask automation. These examples retain the source v4 integration and page-object coverage for a separately authorized future scope, not a second framework to install/run. Use frontend/apps/indexedex/e2e/wallet/fixture.ts and its current config for all present chain tests. Generic lending selectors below are illustrative, not existing IndexedEx product routes.

```ts
// tests/e2e/lending.spec.ts
import { testWithSynpress } from '@synthetixio/synpress'
import { MetaMask, metaMaskFixtures } from '@synthetixio/synpress/playwright'
import basicSetup from '../../wallet-setup/metamask.setup'

const test = testWithSynpress(metaMaskFixtures(basicSetup))
const { expect } = test

test.describe('Lending Protocol', () => {
  test('connect wallet', async ({ context, page, metamaskPage, extensionId }) => {
    const metamask = new MetaMask(
      context,
      metamaskPage,
      basicSetup.walletPassword,
      extensionId
    )

    await page.goto('/')
    await page.getByRole('button', { name: /Connect Wallet/i }).click()
    await metamask.connectToDapp()

    await expect(page.getByText(/0xf39F/i)).toBeVisible()
  })
})
```

Some Synpress versions expose a ready `metamask` fixture from `metaMaskFixtures` — prefer the fixture when available to avoid manual construction.

## Page object with MetaMask

```ts
// pages/lending.page.ts
import type { Page, Locator } from '@playwright/test'
import type { MetaMask } from '@synthetixio/synpress/playwright'

export class LendingPage {
  readonly connectWalletButton: Locator
  readonly depositButton: Locator

  constructor(
    private page: Page,
    private metamask: MetaMask
  ) {
    this.connectWalletButton = page.getByRole('button', { name: /Connect Wallet/i })
    this.depositButton = page.getByTestId('deposit-button')
  }

  async connectWallet() {
    await this.connectWalletButton.click()
    await this.metamask.connectToDapp()
  }

  async depositAndConfirm() {
    await this.depositButton.click()
    await this.metamask.confirmTransaction()
  }

  async approveTokenIfPrompted() {
    // Only the intended amount; max needs an explicit disposable test case.
    await this.metamask.approveTokenPermission({ spendLimit: 1 })
  }
}
```

## Common flows

```ts
// Connect
await page.getByRole('button', { name: /Connect/i }).click()
await metamask.connectToDapp()

// Send tx
await page.getByTestId('swap-button').click()
await metamask.confirmTransaction()

// Reject tx (negative path)
await page.getByTestId('swap-button').click()
await metamask.rejectTransaction()

// Token allowance (ERC-20 approve)
await metamask.approveTokenPermission({ spendLimit: 1 })
// NFTs: use confirmTransaction() instead

// Switch account (dApp must listen to accountsChanged)
await metamask.switchAccount('Account 2')

// Network
await metamask.approveSwitchNetwork()
```

## Capturing MetaMask popup in reports

Extension UI may be a separate or reused page. The following event-first example applies only when the pinned setup opens a new page; otherwise observe the existing wallet page state. Do not use fixed sleeps. Attach only sanitized local-dev captures:

```ts
const popupPromise = context.waitForEvent('page', { timeout: 20_000 })
await page.getByTestId('swap-button').click()
const popup = await popupPromise
await popup.screenshot({ path: 'mm-popup.png' })
await page.screenshot({ path: 'dapp.png' })
// Attach sanitized captures with existing reporting utilities; no extra image dependency.
```

## IndexedEx run ownership

Use the existing workspace scripts described in references/INDEXEDEX.md; the current task owns its relevant validation. Do not run Synpress setup, install Chromium, start a server or execute wallet actions. No extension/cache is enabled by staging this source.

## Tips

- Prefer `getByRole` / `getByTestId` on the dApp; let Synpress own extension selectors
- Required money-path proof is UI outcome plus real receipt and relevant chain state; a stub or toast is insufficient
- Preserve existing workers:1 / fullyParallel:false with shared local RPC state
