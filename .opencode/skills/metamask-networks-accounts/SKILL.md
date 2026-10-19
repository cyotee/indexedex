---
name: metamask-networks-accounts
description: This skill should be used when testing MetaMask networks and accounts — add/switch chain, testnets, Anvil, multi-account, and dApp accountsChanged handling.
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

# MetaMask Networks & Accounts

## Local Anvil network

| Field | Value |
|-------|-------|
| Network name | Robinhood (Anvil) |
| RPC URL | `http://127.0.0.1:8545` |
| Chain ID | `4663` (IndexedEx local deployment) |
| Currency | ETH |

Foundry/Hardhat generic defaults are not IndexedEx deployment configuration. Confirm the actual RPC chain and matching exports; see references/INDEXEDEX.md.

## Programmatic Synpress reference only

Not enabled in IndexedEx. Use its existing injected-wallet fixture instead; do not execute these extension examples under current repo rules.

```ts
await metamask.addNetwork({
  name: 'Robinhood (Anvil)',
  rpcUrl: 'http://127.0.0.1:8545',
  chainId: 4663,
  symbol: 'ETH',
})
await metamask.switchNetwork('Robinhood (Anvil)', true)
```

## dApp-initiated prompts

When the app calls `wallet_addEthereumChain` / `wallet_switchEthereumChain`:

```ts
await metamask.approveNewNetwork()
await metamask.approveSwitchNetwork()
// or rejectNewNetwork / rejectSwitchNetwork
```

## Multi-account testing

```ts
await metamask.addNewAccount('Liquidator')
await metamask.switchAccount('Liquidator')
// OR import second Anvil private key
await metamask.importWalletFromPrivateKey(ANVIL_KEY_1)
```

**Critical:** switching account in MetaMask does **not** update the dApp unless it listens to `accountsChanged` / reconnects. Assert both:

1. Wallet shows new account
2. UI address / balances refresh

## Mock-connector multi-account

Only an isolated UI harness may use Wagmi mock accounts; do not expose window._setupAccount in IndexedEx production. Required chain tests use real funded local accounts and existing injectWallet options, assert accountsChanged-driven refresh and read actual balances.

## Test network visibility

Enable "Show test networks" when selecting Sepolia etc.:

```ts
await metamask.openSettings()
// open appropriate sidebar menu, then:
await metamask.toggleShowTestNetworks()
```
