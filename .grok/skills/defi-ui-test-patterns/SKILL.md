---
name: defi-ui-test-patterns
description: This skill should be used when designing DeFi UI E2E test cases — connect wallet, token approve, swap, lend/borrow, health factor, liquidation, and multi-account journeys for mock or Synpress.
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

# DeFi UI Test Patterns

Scenario catalog for the existing IndexedEx injected-wallet framework. Stub/error cases are explicitly isolated UI tests; Synpress is reference-only, not a repository execution path. Generic lending examples apply only when approved product routes exist.

## 1. Connect wallet

| Step | Assert |
|------|--------|
| Open app | App loads, Connect visible |
| Connect | Address shown, disconnect available |
| Wrong network | Switch network CTA / auto prompt |
| Reject connect | Error toast / idle state (Method A `connectError`, Method B cancel) |

## 2. ERC-20 approve → action

| Step | Assert |
|------|--------|
| Select asset + amount | Preview rates |
| Approve | Real local approval receipt and resulting allowance; isolated stub test proves UI only |
| Allowance UI | Button becomes Supply/Swap |
| Action tx | Success UI + balance change |
| Reject approve | Stays unauthorized |

## 3. Swap / trade

```
connect → select pair → enter amount → (approve if needed) → swap → success
```

Assert: input debit, output credit, price impact warning, failed path on slippage.

## 4. Lending: deposit / borrow / repay / withdraw

Borrower journey:

1. Deposit collateral  
2. UI shows supplied balance + borrow power  
3. Borrow asset under max LTV  
4. Health factor displayed  
5. Repay  
6. Withdraw collateral  

Cross-layer checks:

- UI numbers  
- Required for money paths: real RPC receipts and `publicClient.readContract` positions/balances  

## 5. Liquidation (two accounts)

| Actor | Actions |
|-------|---------|
| Borrower | Deposit, borrow near max |
| Test harness | Reach the condition with real protocol/market behavior or supported local time progression; no oracle/SUT mock or storage patch |
| UI | Position shows liquidatable |
| Liquidator | Switch account, liquidate, confirm |
| Assert | Borrower HF improves or position closed; liquidator receives bonus |

Use real funded local accounts with the existing injection helpers for chain paths, and assert account-specific state refresh. A mock wallet.connect only tests isolated UI state; extension account-switch calls below are external reference concepts.

## 6. Signature-gated UX (Permit2 / SIWE)

1. Trigger sign  
2. Confirm/reject signature (Method B `confirmSignature` / Method A mock features)  
3. Verify domain, chain, spender, amount, nonce and expiry; assert the actual resulting session/permit and required real receipt/state. A Permit2 signature alone does not replace required token or router approvals.  

## 7. Stability patterns

```ts
// Prefer test ids
page.getByTestId('deposit-button')

// Assert UI + chain
await expect(page.getByTestId('success')).toBeVisible()
expect(await getSupplyBalance(address)).toBeGreaterThan(0n)

// Avoid fixed sleep; poll expectations
await expect(page.getByTestId('hf')).toHaveText(/1\.\d+/)
```

## 8. Existing suite split

Keep shell/IA and isolated connector-error checks separate from real-chain money paths in frontend/apps/indexedex/e2e/. Reuse the existing Playwright config and test:e2e / test:e2e:live scripts. Preserve required live bond, stake and swap tests; unavailable prerequisites are blockers or explicit skips, not stubbed passes. Synpress is not a nightly requirement in IndexedEx. Share scenario names and business intent, not fake contract outcomes.
