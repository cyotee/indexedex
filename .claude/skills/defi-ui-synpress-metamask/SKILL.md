---
name: defi-ui-synpress-metamask
description: This skill should be used when implementing DeFi UI E2E with Synpress, Playwright, MetaMask, and Hardhat/Anvil — wallet setup cache, connect, approve, deposit/borrow/liquidate flows.
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

# Method B: Synpress + Playwright + MetaMask + Anvil/Hardhat

Reference-only extension E2E for DeFi UIs; IndexedEx uses its existing injected wallet and forbids MetaMask automation. No extension setup, installation or run is authorized by this skill. Based on patterns from the [Coinmonks Synpress guide](https://medium.com/coinmonks/guideline-to-be-qa-web3-complete-e2e-defi-project-with-synpress-playwright-and-hardhat-anvil-5e3af494cca4) and Synpress v4 docs.

## Why this method

- Proves MetaMask connect, network, approve, and confirm UX  
- Best for QA, release gates, demos, and wallet regression  
- Page objects keep dApp selectors separate from wallet automation  

## 1. Dependencies (reference only)

Synpress and Chromium are external requirements for this archived extension method, not installed dependencies of the current app. Do not install them or change the existing Playwright setup for this port. A future authorized extension project must verify its pinned Synpress API and extension versions first.

## 2. Wallet setup + cache

```ts
// wallet-setup/metamask.setup.ts
import { defineWalletSetup } from '@synthetixio/synpress'
import { MetaMask } from '@synthetixio/synpress/playwright'

const SEED = 'test test test test test test test test test test test junk'
const PASSWORD = 'Tester@1234'

export default defineWalletSetup(PASSWORD, async (context, walletPage) => {
  const metamask = new MetaMask(context, walletPage, PASSWORD)
  await metamask.importWallet(SEED)
  await metamask.addNetwork({
    name: 'Robinhood (Anvil)',
    rpcUrl: 'http://127.0.0.1:8545',
    chainId: 4663,
    symbol: 'ETH',
  })
  await metamask.switchNetwork('Robinhood (Anvil)', true)
})
```

Wallet caching remains an external reference concept; do not generate or commit wallet caches in this review.

## 3. Test bootstrap

```ts
// tests/e2e/lending.spec.ts
import { testWithSynpress } from '@synthetixio/synpress'
import { MetaMask, metaMaskFixtures } from '@synthetixio/synpress/playwright'
import setup from '../../wallet-setup/metamask.setup'

const test = testWithSynpress(metaMaskFixtures(setup))
const { expect } = test

test('borrower deposits collateral', async ({
  context,
  page,
  metamaskPage,
  extensionId,
}) => {
  const metamask = new MetaMask(
    context,
    metamaskPage,
    setup.walletPassword,
    extensionId
  )
  const lending = new LendingPage(page, metamask)

  await page.goto('/')
  await lending.connectWallet()
  await lending.deposit('1')
  await lending.confirmTx()
  await expect(page.getByTestId('supplied-balance')).not.toHaveText('0')
})
```

## 4. Page object

```ts
export class LendingPage {
  constructor(
    private page: Page,
    private metamask: MetaMask
  ) {}

  async connectWallet() {
    await this.page.getByRole('button', { name: /Connect Wallet/i }).click()
    await this.metamask.connectToDapp()
  }

  async deposit(amount: string) {
    await this.page.getByTestId('deposit-input').fill(amount)
    await this.page.getByTestId('deposit-button').click()
  }

  async confirmTx() {
    await this.metamask.confirmTransaction()
  }

  async approveToken() {
    // Bounded intended allowance; unlimited only for an explicitly authorized case.
    await this.metamask.approveTokenPermission({ spendLimit: 1 })
  }
}
```

## 5. Multi-actor DeFi (borrower + liquidator)

1. Setup wallet with seed (account 1)  
2. `importWalletFromPrivateKey` for Anvil account 2 as liquidator  
3. Only if an approved product actually supports lending: drive real borrower contracts toward the liquidation condition on a disposable fork using real market/interest mechanics. Never replace the oracle or SUT with a mock, patch production storage to simulate success, or assume IndexedEx has a lending route.  
4. `switchAccount('Liquidator')` — ensure dApp refreshes account  
5. Liquidate + `confirmTransaction`  
6. Assert supported health-factor/collateral effects in both UI and chain state, with snapshot cleanup even on failure. Required IndexedEx money paths remain bond/stake/swap coverage through the existing injected fixture.  

## 6. IndexedEx execution path

Reuse the operator-provided main or fee_detf deployment and app Playwright config. Read references/INDEXEDEX.md for the real fixture, network and future commands; do not start a generic node or run Synpress in this repository.

## 7. Reporting tip

MetaMask lives on another page/tab. Subscribe before the triggering action with `context.waitForEvent('page', { timeout: 20_000 })` (only when a new page is expected), then capture the popup and attach screenshots with `testInfo.attach` for HTML reports.

## Choosing a non-extension test

- CI minutes tight  
- Testing pure routing/UI without wallet chrome  
- Need deterministic injected errors without clicking reject  

Use the existing real local injected-wallet fixture for chain tests. Mock connectors are only for isolated UI/error cases, never substitutes for real wallet/chain coverage. MetaMask compatibility claims require a separately authorized real-wallet check; do not infer them from injection.
