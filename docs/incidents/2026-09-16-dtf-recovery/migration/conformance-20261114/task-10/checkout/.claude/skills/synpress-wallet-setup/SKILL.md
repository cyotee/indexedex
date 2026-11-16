---
name: synpress-wallet-setup
description: This skill should be used when configuring Synpress wallet-setup — defineWalletSetup, MetaMask seed/password, wallet-setup cache, and Anvil/Hardhat test accounts.
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

# Synpress Wallet Setup

Archived setup reference: onboarding once and caching state can amortize an external extension suite. IndexedEx currently forbids MetaMask automation and uses e2e/wallet/fixture.ts instead. Do not generate a cache, install an extension or add this setup to its runner.

## File layout

```
wallet-setup/
  metamask.setup.ts    # or basic.setup.ts
.cache-synpress/       # generated — gitignore this
```

## defineWalletSetup

```ts
// wallet-setup/metamask.setup.ts
import { defineWalletSetup } from '@synthetixio/synpress'
import { MetaMask } from '@synthetixio/synpress/playwright'

// Anvil / Hardhat default mnemonic account #0
const SEED_PHRASE =
  'test test test test test test test test test test test junk'
const PASSWORD = 'Tester@1234'

export default defineWalletSetup(PASSWORD, async (context, walletPage) => {
  const metamask = new MetaMask(context, walletPage, PASSWORD)
  await metamask.importWallet(SEED_PHRASE)
  // Optional: import extra Anvil keys, add local network, etc.
})
```

## Generate cache

The source workflow used the Synpress wallet-setup CLI. This is not an instruction to run it here. Any future extension integration requires separate authorization and verification of its pinned official CLI syntax.

Opens Chromium, runs onboarding, writes cache under `.cache-synpress/`. Re-run when setup file or MetaMask version changes.

## Local network accounts

| Index | Address (Anvil default) | Use |
|-------|-------------------------|-----|
| 0 | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | Primary tester |
| 1 | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | Counterparty / liquidator |

Import Anvil private keys with `importWalletFromPrivateKey` inside setup or in tests via the `metamask` fixture.

## Add Anvil network during setup

```ts
await metamask.addNetwork({
  name: 'Robinhood (Anvil)',
  rpcUrl: 'http://127.0.0.1:8545',
  chainId: 4663,
  symbol: 'ETH',
})
await metamask.switchNetwork('Robinhood (Anvil)', true)
```

## .gitignore

```
.cache-synpress/
```

If separately authorized to maintain setup source, commit only non-secret source. Never commit the cache, browser profiles or wallet state; no CI convenience exception. Disposable test passwords do not make a cache safe to publish.

## CI

For current IndexedEx CI, reuse the existing Playwright app config and real injected-wallet fixtures against the selected operator-provided stack. Snapshot mutations only on an authorized disposable fork and always revert. An external extension suite would additionally need version-pinned dependencies and private disposable cache lifecycle, but is not installed or enabled here.

## Security

- Use **well-known test seeds only** (Anvil/Hardhat defaults)
- Never use production seed phrases
- Any separately authorized extension CI must obtain passwords from secret injection (for example process.env.METAMASK_PW), redact logs and never capture/export wallet secrets. Signing/broadcast requires authorization for the actual payload and local target.
