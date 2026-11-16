---
name: synpress-metamask-api
description: This skill should be used when calling Synpress MetaMask API methods — connectToDapp, confirmTransaction, approveTokenPermission, switchNetwork, signatures, and account import.
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

# Synpress MetaMask API

Archived reference for @synthetixio/synpress/playwright MetaMask class (v4). Methods automate extension UI and are not Native tool names. This dependency is not declared in the app; current IndexedEx rules prohibit MetaMask automation. Do not run these calls or add dependencies. A separately authorized future integration must verify the pinned official API first.

## Construction

```ts
import { MetaMask } from '@synthetixio/synpress/playwright'

const metamask = new MetaMask(context, metamaskPage, password, extensionId)
```

## Wallet lifecycle

| Method | Purpose |
|--------|---------|
| `importWallet(seedPhrase)` | Onboard from seed (setup) |
| `importWalletFromPrivateKey(privateKey)` | Add imported account |
| `addNewAccount(accountName)` | HD account from seed |
| `switchAccount(accountName)` | Change active account |
| `getAccountAddress()` | Read current address |
| `lock()` / `unlock()` | Lock screen |

## dApp connection

| Method | Purpose |
|--------|---------|
| `connectToDapp(accounts?)` | Approve connection (default account if omitted) |

## Transactions & permissions

| Method | Purpose |
|--------|---------|
| `confirmTransaction({ gasSetting? })` | Approve tx; also NFT approvals |
| `rejectTransaction()` | Reject tx |
| `approveTokenPermission({ spendLimit?, gasSetting? })` | ERC-20 spend cap (`'max'` or number) |
| `rejectTokenPermission()` | Reject ERC-20 approve |

> For NFTs use `confirmTransaction`, not `approveTokenPermission`.

## Signatures

| Method | Purpose |
|--------|---------|
| `confirmSignature()` | eth_sign / personal_sign / typed data |
| `confirmSignatureWithRisk()` | Source capability only; never auto-accept a risk warning or bypass payload review |
| `rejectSignature()` | Reject sign request |

## Networks

| Method | Purpose |
|--------|---------|
| `addNetwork({ name, rpcUrl, chainId, symbol, blockExplorerUrl? })` | Custom chain (Anvil) |
| `switchNetwork(networkName, isTestnet)` | Select network |
| `approveNewNetwork()` / `rejectNewNetwork()` | dApp add-chain prompt |
| `approveSwitchNetwork()` / `rejectSwitchNetwork()` | dApp switch-chain prompt |
| `approveNewEthereumRPC()` / `rejectNewEthereumRPC()` | RPC provider prompts |

## Settings helpers

| Method | Purpose |
|--------|---------|
| `goBackToHomePage()` | Extension home |
| `openSettings()` | Settings |
| `openSidebarMenu(menu)` | Sidebar entry |
| `toggleShowTestNetworks()` | Show testnets (menu must be open) |

## Gas settings

Pass optional `gasSetting` into confirm/approve methods when tests must assert slow/fast gas or custom limits (see Synpress `GasSettings` type).

## Historical patterns (not an IndexedEx execution path)

Before a trigger, subscribe to the exact expected popup/event with a bounded timeout when needed. After wallet confirmation require real receipt plus relevant contract/asset state, not only toast or click. Rejections must leave chain state unchanged. An existing extension page may be reused, so do not blindly wait for a new page.

```ts
// Happy path swap
await dapp.triggerSwap()
await metamask.confirmTransaction()

// Allowance then action
await dapp.clickEnableToken()
// Bounded intended allowance; unlimited requires an explicit disposable test case.
await metamask.approveTokenPermission({ spendLimit: 1 })
await dapp.clickSwap()
await metamask.confirmTransaction()

// User rejection
await dapp.triggerSwap()
await metamask.rejectTransaction()
await expect(dapp.rejectionToast).toBeVisible()
```

## See also

- [metamask-transactions-approvals](../metamask-transactions-approvals/SKILL.md) — conceptual approve vs tx flows
- [defi-ui-synpress-metamask](../defi-ui-synpress-metamask/SKILL.md) — full DeFi E2E playbook
