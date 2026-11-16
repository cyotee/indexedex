---
name: metamask-overview
description: This skill should be used when the user asks about MetaMask in testing or dApps — injected provider, window.ethereum, connection flow, or how MetaMask fits into Playwright/Synpress E2E.
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

# MetaMask Overview (for Testers & Devs)

MetaMask is a browser-extension wallet that injects an EIP-1193 provider (`window.ethereum`). dApps request accounts, signatures, chain switches, and transactions through that provider; MetaMask shows **user-facing confirmations**.

## Why it matters for E2E

| Layer | What to verify |
|-------|----------------|
| Provider | `eth_requestAccounts`, chain id, RPC errors |
| UX | Connect modal, account list, network add/switch |
| Tx | Gas, reject/confirm, stuck/pending states |
| Permissions | ERC-20 `approve` / Permit2 vs spend caps |
| Multi-account | `accountsChanged` handling in the dApp |

## Two automation strategies

1. **Real MetaMask** — actual wallet UX coverage; Synpress is a reference automation option, prohibited in current IndexedEx tests. Human compatibility checks require separate authorization.
2. **Existing injected EIP-1193 wallet** — no extension, but real local signing/RPC in IndexedEx.
3. **Wagmi mock connector** — separate, explicitly isolated UI/error tests only; not proof of signing or chain execution.

These skills document wallet domain knowledge; use the existing IndexedEx framework for implementation, not a new plugin.

## Default local test identity

Anvil account #0 is the automated disposable local test identity; #1 is the operator-funded human UI identity. Never fund these public identities on a public chain or import personal keys. Signing/broadcast still requires task authorization:

- Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Seed: `test test test test test test test test test test test junk`

## Related skills

- [metamask-extension-testing](../metamask-extension-testing/SKILL.md) — extension vs mock tradeoffs
- [metamask-networks-accounts](../metamask-networks-accounts/SKILL.md) — chains, accounts, switching
- [metamask-transactions-approvals](../metamask-transactions-approvals/SKILL.md) — txs, signatures, token allowances

## Docs

- https://docs.metamask.io/
- https://eips.ethereum.org/EIPS/eip-1193
