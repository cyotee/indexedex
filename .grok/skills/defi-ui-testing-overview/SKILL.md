---
name: defi-ui-testing-overview
description: This skill should be used when planning or implementing DeFi UI E2E tests — choosing between Wagmi mock connector vs Synpress MetaMask, stack layout with Anvil, and test strategy for dApps.
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

# DeFi UI E2E Testing Overview

Test full user journeys against a **local chain** so runs are idempotent, free, and forkable. Use the existing injected EIP-1193 wallet as IndexedEx default. The following archived alternatives explain tradeoffs; they do not authorize a new runner or extension integration:

| | **Method A — Mock connector** | **Method B — Synpress + MetaMask** |
|--|------------------------------|-------------------------------------|
| Stack | Playwright + Wagmi `mock` + Anvil + Viem | Playwright + Synpress + MetaMask + Anvil/Hardhat |
| Wallet | In-app mock connector / `window._setupAccount` | Real extension |
| Speed | Fast | Medium (cache helps) |
| Fidelity | App + chain logic | App + chain + wallet UX |
| Flake risk | Low | Medium (extension UI) |
| Best for | Explicitly isolated UI/error checks only | External real-wallet compatibility checks, separately authorized |
| Inspiration | [rombrom.com — Playwright/Anvil/Wagmi](https://www.rombrom.com/posts/testing-dapps-with-playwright-anvil-wagmi/) | [Coinmonks — Synpress/Playwright/Anvil](https://medium.com/coinmonks/guideline-to-be-qa-web3-complete-e2e-defi-project-with-synpress-playwright-and-hardhat-anvil-5e3af494cca4) |

Do not mandate both in IndexedEx: reuse its real local signing fixture and Playwright framework. Stub tests are additive isolation checks; extension automation remains prohibited by current local guidance.

## Shared stack

```
┌─────────────────────────────────────────┐
│  Playwright test runner                 │
├──────────────────┬──────────────────────┤
│ Method A         │ Method B             │
│ Wagmi mock       │ Synpress + MetaMask  │
├──────────────────┴──────────────────────┤
│  dApp UI (React/Next/Remix + wagmi/viem)│
├─────────────────────────────────────────┤
│  Anvil (or Hardhat node) local RPC      │
│  optional: mainnet fork                 │
└─────────────────────────────────────────┘
```

## What “E2E” means in DeFi

1. Connect wallet  
2. Complete a financial action (deposit, borrow, swap, stake, liquidate)  
3. Require **UI** and real RPC **receipts/state effects** for money paths; a real-wallet compatibility claim additionally requires the actual authorized wallet UX  
4. Cover multi-step journeys (approve → supply → borrow → health factor)

## Current IndexedEx layout and prerequisites

```text
frontend/apps/indexedex/
  e2e/
    wallet/fixture.ts       # existing Playwright fixture
    wallet/injectWallet.ts  # real local RPC signing bridge
    helpers/connect.ts     # actual network/storage preparation
  playwright.config.ts     # existing one-worker framework, port 3002
frontend/packages/protocol/src/addresses/chain/4663/
```

Use current declared app dependencies and operator-provided chain deployments; do not install a baseline, upgrade dependencies, add Synpress, start another node or create parallel test directories. See [IndexedEx context](references/INDEXEDEX.md) for main versus fee_detf exports and disposable-fork reset procedures.

## Related skills

- [defi-ui-mock-connector](../defi-ui-mock-connector/SKILL.md) — Method A deep dive  
- [defi-ui-synpress-metamask](../defi-ui-synpress-metamask/SKILL.md) — Method B deep dive  
- [defi-ui-anvil-fixtures](../defi-ui-anvil-fixtures/SKILL.md) — snapshots, time travel, multi-account  
- [defi-ui-test-patterns](../defi-ui-test-patterns/SKILL.md) — lending/swap/liquidation scenarios  

## Native tooling and test selection

Use Native tool discovery and only names present in the live catalog, not plugin names as tool APIs. No compatibility plugins are required.

- PR money-path regression: existing injected wallet plus real local contracts and receipt/state assertions.
- Pure connector/rendering error: explicitly isolated stub test, never a replacement for the preceding gate.
- MetaMask UX compatibility: report the need for a separately authorized real-wallet check; do not enable extension automation under current repo law.
- Vesting/epochs: real deployed contracts plus disposable snapshots, bounded state assertions and local time/mining helpers.
- Multi-actor flows: only approved existing product routes and real actors/contracts.
