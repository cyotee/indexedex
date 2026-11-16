---
name: metamask-transactions-approvals
description: This skill should be used when testing MetaMask transactions, signatures, ERC-20 approvals, rejections, and gas confirmation flows in E2E tests.
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

# MetaMask Transactions & Approvals

## Mental model

1. dApp sends RPC (`eth_sendTransaction`, `eth_signTypedData_v4`, …)
2. MetaMask shows confirmation
3. User confirms/rejects
4. Provider promise resolves/rejects
5. dApp UI + chain state update

E2E must cover **steps 2–5**, not only the click that starts step 1.

## Extension reference: transaction confirm / reject

These Synpress calls describe wallet UX, not Native tools or an approved IndexedEx automation path. Reuse the existing injected-wallet fixture for real local money tests; do not enable MetaMask automation. Any signature/confirmation must already be authorized for the local wallet and intended payload.

```ts
// Synpress
await page.getByTestId('supply-button').click()
await metamask.confirmTransaction()
// negative
await metamask.rejectTransaction()
```

## ERC-20 allowances

Two-step DeFi pattern: approve then action.

```ts
await page.getByRole('button', { name: /Approve/i }).click()
// Use the intended bounded amount; max only if this disposable test explicitly requires it.
await metamask.approveTokenPermission({ spendLimit: 1 })
await page.getByRole('button', { name: /Supply/i }).click()
await metamask.confirmTransaction()
```

- Use `approveTokenPermission` for ERC-20 spend
- Use `confirmTransaction` for NFT approvals / generic txs
- Permit / Permit2 may include signatures, but IndexedEx split Permit2 + router CTAs still require their own real approval receipts. Approve remains the action until confirmation, then Stake. Verify spender, amount, chain, domain, nonce and expiry before signing.

## Signatures

```ts
await metamask.confirmSignature()
// confirmSignatureWithRisk exists in the source API reference, but is not a bypass.
// Stop and inspect the payload; do not automatically accept risk warnings.
await metamask.rejectSignature()
```

Cover EIP-712 (Permit2, offline quotes) and `personal_sign` login if your app uses SIWE.

## Assertions after confirm

Don't stop at "button clicked":

```ts
await expect(page.getByTestId('tx-success')).toBeVisible()
// Required money-path proof: successful real receipt plus relevant asset/position delta.
// Use the existing live suite RPC helpers and pre-action balances.
// A native balance decrease alone can be gas and does not prove ERC-20 supply.
```

## Failure modes to automate

| Scenario | How |
|----------|-----|
| User rejects tx | `rejectTransaction` |
| User rejects connect | cancel connect / mock `connectError` |
| Insufficient funds | drain account on Anvil or use empty imported key |
| Wrong network | Deliberately mismatched local/read-only provider, expect switch gate; never sign/broadcast on mainnet |
| Stale allowance | approve low spendLimit then attempt large swap |

## Gas

Local deployment gas/mining rules still apply. Await a real receipt and relevant effect. Gas UI/API overrides are external Synpress reference details, not permission to change the operator deployment or submit public-chain transactions.
