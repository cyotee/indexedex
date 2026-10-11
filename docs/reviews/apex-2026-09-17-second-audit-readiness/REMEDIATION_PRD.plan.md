# Implementation plan: APEX second-audit readiness, stage 1

- **Status:** ready for a separately authorized implementation session
- **Date:** 2026-10-06
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). OD-08 controls older sentences in OD-01, OD-04, OD-06, REQ-01, REQ-02, REQ-05, and REQ-08.
- **This plan does not authorize code changes.** A later session must be explicitly asked to implement it. Writing this plan is not that request.
- **Stage:** 1 only. Stage 2 is named so it is not forgotten. It is not started by this plan.

## Objective

Implement and test the repairs in the remediation PRD. Stage 1 is a fast-fail check that those repairs match the recorded decisions. A failing stage-1 test is iterated, including an alternate design if the stated repair cannot be made correct. Stage 1 passing is not audit submission and does not certify the 108 original APEX criteria.

## Read first

Read `CLAUDE.md`, `.github/ASSISTANT_RULES.md` and its coding and testing documents, `docs/testing/ARTIFACT_BUILDS.md`, and the controlling PRD. Use production TestBases. Do not mock the system under test. Do not enable `via_ir`. Do not change Foundry profiles. Do not delete `out/` or `cache_forge/`. After a production edit, refresh artifacts with `python3 scripts/forge-artifacts.py` before `forge test`. Wait for compiler completion. Do not kill `forge` or `solc` for lack of progress lines.

Test names, comments, and reports must not describe how to attack a live system. Tests must still exercise the real production path and assert the exact corrected result, including that a forbidden credit or payout does not occur. OD-07.

## In scope

- REQ-01 and REQ-02, as narrowed by OD-08.
- REQ-03 custody negatives and the bare-revert scanner.
- REQ-04 matrix rounding and accounting assertions.
- REQ-05 outside-trade credit tests for V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault.
- REQ-06 `maxRedeem` / `maxWithdraw` direction.
- REQ-07 removal of the empty-state `quoteState` gas branch.
- REQ-08 current-source map plus the stage-1 build, selector, size, and named regression run.

## Out of scope

- Stage 2. Do not reopen the 108-criterion ledger, the full hook × SE matrix recount, or audit submission.
- Deployment, migration, registry disablement, broadcasts, and live transactions.
- Deleting preserved Uniswap source under `contracts/protocols/dexes/uniswap/{v3,v4}/`.
- Merging the hookless and Pons-family FullSpread packages.
- Binding the wings vault to a Pons-configured pool.
- Deciding or removing the `supportsInterface` probe at `UniswapV4DetfCommon.sol:669-678`.
- Porting OpenZeppelin virtual shares, changing `previewRedeem` rounding, or replacing `ReceiptBackedERC4626AccountingLib`.
- Removing vault `quoteState`, `quoteTransition`, or hook projection that passes an existing snapshot.
- Reconstructing the old stored-total equality and greater-than cases.
- A red run on preserved old source. Historical logs stay labeled historical.

## Stage 1 work order

Execute in order. Stop on the first failing security assertion and fix that repair before continuing. Do not loosen an assertion to make a test pass. Do not start stage 2 from a failure.

### Step 1 — Confirm the tree and leave deferred sites alone

- **Files:** read-only. `UniswapV4DetfCommon.sol`, `ReceiptBackedERC4626Target.sol`, `StandardExchangeRateProviderFacet.sol`, the three FullSpread package roots, and `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`.
- **Do:** record the current revisions and dirty paths in the stage-1 evidence note. Confirm the cited catch lines still match before editing. If they have moved, re-locate the same functions. Do not edit the `supportsInterface` probe.
- **Done when:** the implementer can name the exact functions to edit and has not treated a moved line number as a missing defect.

### Step 2 — REQ-01 and REQ-02, residual joins

- **Files:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol`. Hook callers of `previewResidualBuffer` only if a test shows they treat a zero or a revert as a booked residual.
- **Do:** keep book-and-wait only for a successful Standard Exchange `previewExchangeIn` of `0` through `_pairQuoteIsZero`. Do not call the Standard Exchange deposit after that zero. Book the leftover to holders. Do not pay it to the caller or the fee recipient. Remove the hook-join translation catches at the current `_joinResidualCapped`, `_joinResidualUnbalanced`, and `_entryJoinResidualAtomic` sites. Those joins become hard calls. A hook preview of `0`, or a hook join revert, rolls the parent transaction back and does not add a holder-reserve update. Do not recreate a catch in `previewResidualBuffer`.
- **Tests:** one production-proxy test for the Standard Exchange zero path, and one for the hook zero or hook-join revert path. Assert exact balances, the holder book, and that the caller and fee recipient do not receive the leftover. A reverting preview must not be recorded as a successful zero.
- **Done when:** REQ-01 and REQ-02 acceptance criteria pass on the current functions, and the `supportsInterface` probe is unchanged.

### Step 3 — REQ-03, custody negatives

- **Files:** `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol`, `RebasingAwareERC4626_Fuzz.t.sol`, and `scripts/apex_bare_expectrevert_scan.sh`. Production guard: `RebasingAwareStandardYieldTarget.sol`.
- **Do:** do not weaken the EOA guard. Retarget the mis-aimed tests. The ownership test must use an allowed contract caller, expect the precise share-accounting error, and show the other holder's shares unchanged. The reentrancy test must expect the nested-guard error and show no partial credit. The minimality fuzz test must expect the exact short-funding error and assert shares, balances, and reserves on both rejection and success. Extend the scanner so custody files count even when they lack an APEX marker.
- **Done when:** those three tests reach the named condition, and the scanner fails if a bare `vm.expectRevert()` remains in the D16 regression inventory it selects.

### Step 4 — REQ-04, matrix controls

- **Files:** the seven `*SeMatrixBehavior.sol` files under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`, starting with the weighted behavior.
- **Do:** replace the catch-all rounding control. Each family either expects its exact rounding error or asserts a successful measured zero-output and retained book, including the branch precondition. Partial-consumption tests must reconcile actual consumption, credited amount, book change, and exact share movement. The AMM separation control must establish a nonzero unpaired book before the later call. Do not delete funded swap, refund, or EOA controls that already assert exact deltas. Do not mark a row COMPATIBLE because the catch-all passed.
- **Done when:** the weighted file and the same control in the other six behaviors no longer pass on an arbitrary revert.

### Step 5 — REQ-06, receipt redemption cap

- **Files:** `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol`. Do not replace `ReceiptBackedERC4626AccountingLib.sol` and do not add an OpenZeppelin virtual-share offset.
- **Do:** stop deriving `maxRedeem` from `maxWithdraw` or `convertToShares`. `maxRedeem` is the largest owner share amount whose `previewRedeem` is at least one receipt and no greater than held receipts. If the full balance meets that test, return the full balance. `maxWithdraw` returns `previewRedeem(maxRedeem(owner))`. `redeem` continues to pay `previewRedeem`.
- **Tests:** both dispatched families. One non-integral-rate case where the full balance is payable. One case where held receipts cannot pay the full balance. One case where `previewRedeem` of the balance is zero, which must not be advertised as redeemable. `redeem` at the cap succeeds and transfers no more receipts than the vault holds.
- **Done when:** REQ-06 acceptance criteria pass and `previewRedeem` rounding is unchanged.

### Step 6 — REQ-07, plain rate call

- **Files:** `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`, the empty-state branch in `_getRate`.
- **Do:** delete the `gasleft` check and the empty-state `quoteState` call. An empty state prices the live vault through the ordinary preview. Keep `_safePreviewExchangeIn` and the D48 exact-length rule. Keep `quoteRate` for a caller-supplied snapshot. A failed snapshot is not replaced with the live rate. Do not delete vault `quoteState` or hook projection.
- **Tests:** empty-state `getRate` does not change when `quoteState` would fail or when the call budget is low, because `quoteState` is not called. A caller-supplied snapshot still prices against that snapshot. A failed caller-supplied snapshot is not reported as the live rate.
- **Done when:** REQ-07 acceptance criteria pass and the wings vault still implements `quoteState`.

### Step 7 — REQ-05, outside-trade credit

- **Files:** new or extended tests beside the existing FullSpread and wings suites. The reserve-reconcile supplement at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol` may remain, but its name and evidence citation must not call it the stale-reserve proof.
- **Do:** add one outside-trade credit test for each of V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault. The pool trade is not a vault call. That trade must not refresh the vault book. The following deposit or redemption credits only tokens the vault holds. No unearned shares or output are credited. Do not reconstruct stored-total equality and greater-than cases. Do not delete preserved source.
- **Done when:** four named tests pass, and the supplement is not cited as the stale-reserve proof.

### Step 8 — REQ-08, stage-1 evidence run

- **Files:** a new stage-1 note under `docs/reviews/apex-2026-09-17-second-audit-readiness/`. Do not overwrite historical files under `docs/audits/apex-2026-09-17-evidence/`.
- **Do:** write a snapshot-to-current map of the hookless and Pons-family packages, their source files, and the tests that cover each. Do not merge the packages. Regenerate the build, selector check, size check, and the named APEX regressions for the edited tree. Record commands, outcomes, and source identity. One current matrix count is recorded only if that run actually counts it. Do not adopt 195/1/7 or 165/3/7 from an old log.
- **Done when:** the stage-1 note cites the new run. A missing or failed run means stage 1 is not complete. The note says stage 1 is not audit submission.

## Verification commands

Use the artifact helper. Repeat `--test-root` for the suites touched by a step. Do not change `FOUNDRY_TEST`. Do not run these commands in the review session that wrote this plan.

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol \
  --test-root test/foundry/spec/vaults/detf \
  -- -vv
```

Add the edited receipt-adapter, rate-provider, custody, matrix, FullSpread, and wings roots in the stage-1 evidence run. The selector and size check uses the repository's existing comparison script if one is already present. Do not invent a new compiler profile to make a size check pass.

## Fast-fail rule

If a named security assertion fails, stop. Fix that repair or, if the stated repair cannot be made correct, stop and report the alternate design for an owner decision. Do not continue into stage 2. Do not replace a failing assertion with a weaker one.

## Stage 2, not started here

Stage 2 starts only after the owner is satisfied with stage 1. It reopens the APEX program and checks the broader changes and new vaults against the same standard before any audit submission. It is a separate request. This plan does not list its steps, because listing them would invite an implementer to start them early.

## Open items this plan does not decide

- The `supportsInterface` probe in `UniswapV4DetfCommon.sol`.
- Whether a later package may bind the wings vault to a Pons-configured pool.
- Live chain-4663 remediation. Replacement tests do not upgrade immutable instances.
- D12 resting credit for contract callers. That residual stays documented.
