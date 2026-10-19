---
name: synpress-overview
description: This skill should be used when the user asks about "Synpress", "@synthetixio/synpress", Web3 E2E with MetaMask extension, or wallet-cache setup for Playwright/Cypress dApp tests.
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

# Synpress Overview

[Synpress](https://docs.synpress.io/) is a Web3 E2E library built on **Playwright** (primary) and experimental Cypress. It automates real wallet extensions (MetaMask, Phantom) with one-time wallet setup caching for speed and parallel runs.

## IndexedEx status

Synpress is an external, uninstalled reference alternative. The app already has Playwright and real injected-wallet fixtures and explicitly prohibits MetaMask automation. Do not install @latest, add a second runner, generate wallet caches or upgrade dependencies. A future separately authorized extension integration must verify pinned official APIs first.

## Why Synpress

| Problem | Synpress approach |
|---------|-------------------|
| Playwright has no wallet | Controls MetaMask extension UI |
| Slow wallet onboarding every test | One-time setup + browser state cache |
| Flaky extension flows | Typed MetaMask API (`connectToDapp`, `confirmTransaction`, …) |
| Need real UX | Approvals, network switch, signature popups as users see them |

## Architecture

```
defineWalletSetup  →  npx synpress wallet-setup  →  .cache-synpress/
        ↓
testWithSynpress(metaMaskFixtures(setup))
        ↓
Playwright tests with `metamask` fixture
```

## Merits vs mock connector

**Use Synpress when you need:**

- Real MetaMask UX (connect modal, gas UI, token spend permissions)
- Confidence that extension + dApp integration works
- Multi-account switching as the wallet presents it
- QA-style E2E against local Anvil/Hardhat

**Use explicitly isolated UI connector stubs only when you need:**

- Faster, less flaky CI without extension chrome
- Wallet-agnostic tests
- Injected error features (`connectError`, reject tx) without clicking UI
- Impersonating arbitrary addresses via test hooks

In IndexedEx use existing injection plus real contracts/RPC for required money paths. Isolated stubs are additive UI checks, not PR/release proof. Synpress remains a reference option, not an enabled nightly suite; real-wallet compatibility claims require an authorized real-wallet check.

## Related skills

- [synpress-wallet-setup](../synpress-wallet-setup/SKILL.md) — `defineWalletSetup`, seed, cache
- [synpress-playwright](../synpress-playwright/SKILL.md) — `testWithSynpress`, fixtures, page objects
- [synpress-metamask-api](../synpress-metamask-api/SKILL.md) — MetaMask class methods reference

## Official docs

- https://docs.synpress.io/
- https://github.com/Synthetixio/synpress
