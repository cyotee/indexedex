# Remaining work

- **Date:** 2026-10-17
- **Status:** Work queue. This is not a new audit and not permission to edit code.
- **Source:** The unfinished items named from `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md`. Closed and withdrawn items are not repeated here.
- **Rule:** Except for the Crane delivery below, every item is unverified. Confirm it against current source before writing a repair. Do not treat this list as proof that the defect still exists.

## Not in this queue

REQ-02, REQ-03, REQ-04, REQ-C04, REQ-C06, REQ-SEP-01, REQ-SEP-04, REQ-H03's source edit, and REQ-ADJ-01 are closed. The legacy V4 package gaps are withdrawn. The missing REQ-ADJ-01 execution report is a documentation gap and is not a task here.

The deleted tree is `contracts/protocols/dexes/uniswap/v4`. The supported V4 vaults under `contracts/vaults/standard/exchange/protocols/uniswap/v4/` are not that deletion.

## 1. Deliver the REQ-H03 Crane revision

- **Status:** Source edit exists. Delivery stopped.
- **What remains:** The short-burn check is in the Crane working tree. It was not committed. The recorded gitlink `2d626b3663a22281587cb34ac0ac271e968ee3cd` does not contain it.
- **Done when:** Crane is on a branch, its only change is `contracts/tokens/ERC20/ERC20Repo.sol`, IndexedEx is dirty only at the three REQ-H03 test files and the `lib/crane` gitlink, and `scripts/submodule-commit.sh` then records that revision. If any other path is dirty, stop. Do not commit unrelated files.
- **Do not:** Re-edit the burn body. Do not add the `address(0)` rejection.

## 2. Stage-1 items never verified

Controlling text: `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`. These were not re-read in the 2026-10-14 application round. No repair is authorized until a verification pass confirms the current code still breaks the requirement.

### REQ-05 — Outside-trade credit

- **Severity claimed:** Medium. Not reconfirmed.
- **Claim:** An outside pool trade must not refresh the vault book. The next credit may use only tokens the vault holds. The reserve-reconcile supplement is not that proof.
- **Scope:** V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault. One variant does not close another. These are the supported vaults, not the deleted legacy package.
- **Next action:** Read the current tests and say whether each named family has that outside-trade control. If it does, close the item. If it does not, write a test-only PRD.

### REQ-06 — `maxRedeem` share cap

- **Severity claimed:** Low. Not reconfirmed.
- **Claim:** `maxRedeem` must be the largest owner share amount that `redeem` can pay from held receipts. It must not call `maxWithdraw` or `convertToShares`. `maxWithdraw` must equal `previewRedeem(maxRedeem(owner))`.
- **Files named then:** `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol` and `ReceiptBackedERC4626AccountingLib.sol`.
- **Next action:** Read the current formula. If it already matches, close the item. If not, write a PRD for that formula only.

### REQ-07 — Plain rate uses the live preview

- **Severity claimed:** Medium. Not reconfirmed.
- **Claim:** An empty-state rate prices the live vault. It must not call `quoteState` or read remaining gas. A caller-supplied snapshot is still priced as that snapshot. A failed snapshot is not replaced with the live rate.
- **File named then:** `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`.
- **Next action:** Read the current empty-state path. If the gas-gated snapshot is gone, close the item. If it remains, write a PRD to remove that branch only.

### REQ-08 — Current FullSpread V4 evidence

- **Severity claimed:** Medium. Not reconfirmed.
- **Claim:** Completion evidence must name the current hookless and Pons-family source, selectors, tests, and a regenerated build, selector, size, and regression run. A September attestation does not verify a later tree.
- **Scope:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. Do not restore the deleted legacy package. Do not merge hookless and Pons. Ignoring `scripts/r12_selector_size_compare.py` does not close this item.
- **Next action:** Check whether a current-source map and a regenerated run exist. If they do, cite them. If they do not, the missing evidence is the task. Do not treat a missing run as a production defect.

## 3. September items never verified

Controlling text: `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Later explicit-holder law and the legacy V4 deletion do not close these. RC-01 and RC-04 are not in this queue.

### RC-02 — ERC-4626 local-first payout

- **Severity claimed:** Medium. Not reconfirmed.
- **Claim:** A local-first underlying payout can deliver more than the accounted amount because a rounded-up share redemption is accepted when it pays at least the shortfall.
- **File named then:** `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol`.
- **Next action:** Read the current payout. If the recipient now receives exactly the due amount, close the item. If not, write a PRD. Do not send the remainder to `feeTo`.

### RC-03 — Stata backing omits booked aToken

- **Severity claimed:** Medium. Not reconfirmed.
- **Claim:** Stata issuance and the shared adapter can price the same shares against different backing when booked aToken is included on only one surface.
- **Files named then:** `AaveV3StataStandardExchangeCommon.sol` and `ReceiptBackedERC4626Target.sol`.
- **Next action:** Read both backing functions. If they now use one calculation, close the item. If they differ, write a PRD. Do not add a second share ledger.

### RC-05 — Unused single-CP exact-out refund

- **Severity claimed:** Low. Not reconfirmed.
- **Claim:** An unused HookTarget `exchangeOut` still refunds `maxAmountIn - amountIn` without the credit cap and caller check.
- **File named then:** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol`.
- **Next action:** Check whether that function still exists. If it is gone, close the item. If it remains, stop and ask whether to delete it or route it through the guarded helper. Do not leave that choice to an implementer.

### RC-06 — Orbital unwrap reports the approval cap

- **Severity claimed:** Low. Not reconfirmed. MiniMax dissented that the return is unused.
- **Claim:** After `exchangeOut`, the function assigns the approval cap to the returned share count and discards the amount the SE reported.
- **File named then:** `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol`.
- **Next action:** Read the current return. If it already reports shares pulled, or no longer returns a share count, close the item. If it still reports the cap, stop and ask whether to report the pulled amount or remove the return.

### RC-07 — Availability math panics on a book deficit

- **Severity claimed:** Low for practical impact. Not reconfirmed.
- **Claim:** `_unbookedSurplus` uses checked subtraction, so `balance < booked` panics instead of returning zero.
- **File named then:** `contracts/vaults/basic/BasicVaultCommon.sol`.
- **Next action:** Read the current helper. If a deficit now returns zero, close the item. If it still panics, write a PRD that lists historical callers before any base-helper edit. Do not change consumers outside the stated scope.

### RC-08 — V2 zap-out backing check has no named error

- **Severity claimed:** Low. Not reconfirmed.
- **Claim:** The pool-token backing check reverts with an empty `revert()` instead of a named error carrying both compared values.
- **File named then:** `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`.
- **Next action:** Read the current check. If it already reverts a named error with both values, close the item. If it is still empty, write a PRD for that error only. Do not weaken the comparison.

## Order

1. Deliver the REQ-H03 Crane revision.
2. Verify REQ-05.
3. Verify REQ-06.
4. Verify REQ-07.
5. Verify REQ-08.
6. Verify RC-02, RC-03, RC-05, RC-06, RC-07, and RC-08, in that order.

A verification that finds no remaining defect closes that item. It does not authorize the next edit.
