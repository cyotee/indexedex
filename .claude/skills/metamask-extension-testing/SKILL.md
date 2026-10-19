---
name: metamask-extension-testing
description: This skill should be used when deciding how to test MetaMask integration — real extension automation vs mock provider, flaky UX, and CI constraints.
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

# Testing with the MetaMask Extension

## Real extension path

**Reference tooling:** Synpress + Playwright (Chromium) + cached wallet setup. Current IndexedEx guidance prohibits MetaMask automation; do not install or run this alternative. It describes coverage a future separately authorized compatibility check would need.

**Pros**

- Validates true connect / approve / sign UX
- Catches MetaMask version regressions that affect your dApp
- Exercises network add/switch prompts from the wallet side

**Cons**

- Slower; Chromium-centric
- Sensitive to MetaMask UI changes (Synpress absorbs most selectors)
- Extension + dApp multi-page screenshots/debug complexity

## Mock provider path

**Isolated UI tooling:** Playwright + Wagmi mock connector. Distinguish this from IndexedEx e2e/wallet/injectWallet.ts, which signs real local transactions and forwards real contract reads.

**Pros**

- Fast, parallel-friendly, fewer moving parts
- Programmatic failures via mock `features`
- Impersonate addresses without importing keys into an extension

**Cons**

- Does not prove MetaMask UI compatibility
- Won't catch extension-only permission quirks

## Recommended matrix

| Suite | When | Stack |
|-------|------|-------|
| PR / local money paths | Existing required coverage | Playwright injected wallet + real contracts/RPC |
| Isolated connector UI | Explicit UI/error cases | Stub only, no money-path claim |
| Real-wallet compatibility | Separately authorized manual check | Human MetaMask + disposable Anvil identity; no extension automation |

## Manual import of Anvil key (exploratory)

1. Human operator confirms the authorized local deployment and imports only the known disposable Anvil #1 identity; do not start a generic node or use a funded personal wallet
2. MetaMask → Import account → paste key
3. Add network RPC `http://127.0.0.1:8545`, chain id `4663`
4. Connect dApp pointed at local RPC

## Flakiness checklist

- Wait for dApp button enabled after `connectToDapp`
- Don't race `confirmTransaction` before notification page exists
- Preserve the deployment gas/mining configuration; await the actual local receipt, not an arbitrary gas override
- Snapshot Anvil when using time-dependent MetaMask-displayed data
