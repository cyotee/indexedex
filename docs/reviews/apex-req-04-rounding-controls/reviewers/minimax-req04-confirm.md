# MiniMax M3 — REQ-04 confirmation (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Confirm whether `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.plan.md` was executed accurately against the source. Treat the execution report as an untrusted claim. A saved log is not an independent rerun.
- **Inputs read:** `REMEDIATION_PRD.md` (65 lines, controlling PRD), `REMEDIATION_PRD.plan.md` (96 lines, plan), `EXECUTION_REPORT.md` (102 lines, untrusted claim). The two quad Math files, the two quad Core files, and the six named test files were re-read at the cited line ranges.
- **Forge:** Not run. No code edit.

---

## Verdict — code-side execution is accurate; the follow-up was applied as authorized

The plan's source-side edits are present in the working tree. The owner-authorized follow-up (plan lines 9–17, EXECUTION_REPORT lines 7–22) is also applied: the Dual `DepositQuoteLib._swap` early-return, the Balancer SimpleYield F6/F9 and Orbital RebasingAware positive one-unit controls, the unified `ZeroAmount()` for the two quad zero-share controls, and the strict-math preservation. The execution report's runtime claims (175 focused rows passed; 3,642 full-suite tests passed; 0 failures) are untrusted and not independently rerun by me.

No gap remains at the source level for REQ-04. The PRD's "Required outcome" is met by the corrected previews (return 0 for zero-rounded one-unit input), the corrected executions (revert with the test's named selector without taking input), the strengthened share-debit reconciliation (`seBefore + _faceSharesMintedToHook() == _hookSeShares() + expectedDebit`), the orbital preview selector correction, and the protected funded-swap / refund / code-less-caller controls.

Production cleanup behavior was not re-read for this confirmation, per the PRD's "Required outcome" and the plan's "Do not allow a successful zero-share deposit."

---

## Production-side verification

### Two quad preview paths

#### Balancer-quad Math (`UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol`)

- Original strict `unbalancedJoinShares` at lines 277–292: **unchanged**. Line 291 still reads `return FixedPointMathLib.fullMulDiv(supply, _invariant(next, amp, false) - currentD, currentD);` — the bare invariant subtraction the plan said to leave alone. Per the plan, the strict math stays.
- New `previewSingleJoinExactInShares` at lines 304–324: **present and zero-aware**.
  - Line 309: `if (supply == 0) revert ZeroAmount();` (book validation).
  - Line 311: `if (amount == 0) return 0;` (converted-input-zero guard).
  - Line 322: `if (nextD <= currentD) return 0;` (non-growth guard, before any unsigned subtraction).
  - The structure mirrors the strict function on lines 277–292 with fee/balance/array/scale handling identical, but the zero-aware return prevents both the underflow and the zero-share revert.

#### Curve-quad Math (`UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol`)

- Original strict `singleJoinExactInShares` at lines 431–466: **unchanged**. Lines 455 (`if (D1 <= D0) revert MathDomain();`), 463 (`if (D2 <= D0) revert MathDomain();`), and 465 (`if (shares == 0) revert ZeroAmount();`) are intact. Per the plan, the strict math stays.
- New `previewSingleJoinExactInShares` at lines 469–504: **present and zero-aware**.
  - Line 477: `if (supply == 0) revert ZeroAmount();`.
  - Line 484: `if (amountInWad == 0) return 0;` (converted-input-zero guard).
  - Line 494: `if (D1 <= D0) return 0;` (non-growth guard for first fee regime).
  - Line 502: `if (D2 <= D0) return 0;` (non-growth guard for second fee regime).
  - The post-guard share return at line 503 (`shares = (supply * (D2 - D0)) / D0;`) can still produce 0; the function does not need an extra zero-share return because the formula naturally rounds to 0 for tiny inputs.

### Two execution joins

#### Balancer-quad LiquidityCore (`UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol`)

- Line 283–289 (`_entryPreviewDepositSingle`): now routes through `_quoteSingleJoinExactInPreview(tokenIn, amountIn, _previewSupplyAfterProtocolMint())`. The preview uses the zero-aware `Math.previewSingleJoinExactInShares` instead of the strict `unbalancedJoinShares`.
- Line 304–306 (`_joinSingleAssetExactIn`): now uses `_quoteSingleJoinExactInPreview` for the quote (line 305) and `if (shares == 0) revert ZeroAmount();` (line 306) **before** the existing `Slippage` check and **before** any input pull. The plan and the owner-authorized follow-up both require this guard. Comment on line 304: "Detect zero invariant growth before strict math can underflow." is consistent with the follow-up's "validated zero-aware quote."

#### Curve-quad JoinCore (`UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol`)

- Line 439–449 (`_entryPreviewDepositSingle`): now uses `_quoteSingleJoinExactInPreview` for the non-SE-share route. The `isSeShare` branch still routes to `_entryPreviewJoinSingleAssetExactIn` per the follow-up's "Curve retains its existing inactive/invalid-token handling and existing flexible SE-share route."
- Line 470–472 (`_joinSingleAssetExactIn`): now uses `_quoteSingleJoinExactInPreview` for the quote (line 471) and `if (shares == 0) revert ZeroAmount();` (line 472) **before** `Slippage` and input pull. Comment on line 470: "A fee-rounded zero contribution is a zero-amount rejection, not a broken book." matches the follow-up's framing.

### Dual production follow-up

The plan's "Owner-authorized follow-up" step 2 says: "In Dual `DepositQuoteLib._swap`, return `(amountIn, 0)` when the computed sale is zero, before invoking an underlying SE deposit transition." Verified at `UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol:131`:

```solidity
// A zero-sized swap cannot fund the other leg; SE transitions may reject zero deposits.
if (sale == 0) return (amountIn, 0);
```

This supersedes the original "Do not edit dual production" line in the plan. The execution report records the follow-up explicitly (lines 11–13 of EXECUTION_REPORT). The early-return is in place.

### Weighted, single-CP, and orbital production

The plan's "Done when" requires: "Weighted, dual, single-CP, and orbital production are unchanged" — but the owner-authorized follow-up explicitly edited dual. The "weighted, single-CP, and orbital" subset is required to be unchanged.

I cannot run `git diff` in this session. My confirmation rests on:

- The execution report (untrusted claim) at line 22: "Source hashes confirm exactly the declared three production and six test changes relative to the follow-up starting state; the strict math libraries and excluded non-CP behavior are unchanged." At line 72: "All non-quad hook production sources and the excluded non-CP behavior file match the initial hashes." (Both lines are untrusted claims.)
- The visible presence of the production files for weighted, single-CP, and orbital with their `previewDepositSingle` and `_quoteSingleJoinExactIn` definitions at the expected line ranges, and no `previewSingleJoinExactInShares` Math function added in those directories.

A definitive `git diff` would require a shell, which is not available to me. I record: weighted, single-CP, and orbital production **were not edited for this item per the plan/report agreement and the absence of any visible Math-function addition in those directories**, with **medium-high confidence, not directly diff-verified**.

---

## Test-side verification — six named tests

The six `_roundingToZeroControl` functions and six share sites were re-read at the cited line ranges. All six match the plan's "Exact test rule" + the follow-up's selector narrowing for the quads. Confirmed by source read:

| File | Rounding-control preview-ok + decodes-to-0 | Expects named selector | Share-site new pattern |
|---|---|---|---|
| weighted (`:214-229`) | yes (`:218-222`) | `MinAmountNotMet(1, 0)` | `seBefore + _faceSharesMintedToHook() == _hookSeShares() + expectedDebit` (`:273`) |
| dual (`:319-324`) | yes | `InsufficientTokenOut() or ZeroAmount()` (`:324`) | `seBefore + _faceSharesMintedToHook() == _hookSeShares() + expectedDebit` (`:372`) |
| single-CP (`:269-294`) | yes (`:273-277`) | `InsufficientTokenOut() or ZeroAmount()` (`:290`) | `seBefore + _faceSharesMintedToHook() == _hookSeShares() + expectedDebit` (`:338`) |
| orbital (`:312-322`) | yes (`:317-321`) | `InsufficientTokenOut() or ZeroAmount()` | `seBefore + _faceSharesMintedToHook() == _hookSeShares(0) + expectedDebit` (`:383`) |
| balancer-quad (`:343-362`) | yes (`:347-351`) | `InsufficientTokenOut() or ZeroAmount()` | `seBefore + _faceSharesMintedToHook() == _hookSeShares() + expectedDebit` (`:411`) |
| curve-quad (`:269-293`) | yes (`:273-277`) | **only `ZeroAmount()`** (`:289`, per follow-up) | `seBefore + _faceSharesMintedToHook() == _hookSeShares() + expectedDebit` (`:337`) |

`previewMatch` allowance is **deleted** in all six files (`grep "previewMatch"` over the six files returns no matches in the rounding controls). The `vm.expectRevert(previewRet)` branch is **deleted** in all six files.

### Orbital preview selector correction

The plan requires: "Orbital's staticcall currently encodes `previewDepositSingle(address,uint256,bytes)`. Change it to `previewDepositSingle(address,uint256)`. Do not change the six-argument deposit execution call." Verified at `orbital/.../SeMatrixBehavior.sol:318`:

```solidity
abi.encodeWithSignature("previewDepositSingle(address,uint256)", face0, uint256(1))
```

The two-arg selector is in place. The execution call at `:304` is `orbital.depositSingle(face0, 1, user, expectedShares, block.timestamp + 1 hours, bytes(""))` — six-argument form, retained as the plan requires.

### Positive one-unit controls (follow-up)

The plan's follow-up step 3 requires Balancer SimpleYield F6/F9 and Orbital RebasingAware to have explicit positive one-unit controls with fixed share expectations. Confirmed in source:

- `orbital/.../SeMatrixBehavior.sol:295-310` — `_positiveOneUnitDepositControl(uint256 expectedShares)` with expected shares, exact execution match, recipient share, exact input debit, exact SE inventory, no new face residual.
- `stable/quad/balancer/.../SeMatrixBehavior.sol:325-340` — same pattern.
- The default `_roundingToZeroControl` is still the standard zero-revert path, with `_oneUnitDepositControl()` virtual hook at `:321` allowing positive-fixture overrides.

The expected shares are hard-coded by the follow-up: `240384615373`, `240384613` (Balancer SimpleYield F6/F9), and `1` (Orbital RebasingAware), per EXECUTION_REPORT.md line 13.

### What must not change (PRD `:56-61`)

The plan's "What not to do" preserves funded-swap, refund, and code-less-caller controls. Verified at:

- `weighted/.../SeMatrixBehavior.sol:231-...` (`test_row_hookSwap_exactIn_eoaPretransferRejected` and similar) — present.
- `dual/.../SeMatrixBehavior.sol:330-...` — present.
- `single-CP/.../SeMatrixBehavior.sol:296-...` — present.
- `orbital/.../SeMatrixBehavior.sol:328-...` — present.
- `balancer-quad/.../SeMatrixBehavior.sol:358-...` — present.
- `curve-quad/.../SeMatrixBehavior.sol:295-...` — present.

The excluded non-CP file `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol` was not opened for this confirmation. The plan and the execution report both attest it was not edited; I do not re-verify by read because it is out of scope and unchanged per the agreement.

---

## Findings

### Confirm-REQ04-1 — Plan executed accurately at source

- **Severity:** N/A (confirmation, not a defect).
- **File and line:** `UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol:277-292` (unchanged strict), `:304-324` (new preview); `UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol:431-466` (unchanged strict), `:469-504` (new preview); `UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:283-289, 304-306`; `UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol:439-449, 470-472`; `UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol:131` (follow-up); the six `*SeMatrixBehavior.sol` files at the cited line ranges.
- **Intended behavior (PRD `:26-28`):** "For each of the six named families, a one-unit deposit whose output rounds to zero has a preview that returns 0. The deposit execution reverts. The caller, the hook, and the booked balance are unchanged. The test does not accept the preview's revert bytes as that execution result."
- **Verification:** Both quad Math files add `previewSingleJoinExactInShares` with the required zero-aware guards. Both quad Core files route the preview through `_quoteSingleJoinExactInPreview` and add `if (shares == 0) revert ZeroAmount();` before input transfer. The Dual follow-up is applied at `DepositQuoteLib._swap:131`. The six rounding controls now require the preview to succeed and decode to 0, then execution to revert with the named selector(s). The share sites use the new `seBefore + _faceSharesMintedToHook() == _hookSeShares() + expectedDebit` pattern. Orbital uses the two-arg preview selector.
- **Impact class:** Confirmation of plan execution; no defect.
- **Confidence:** High (direct source read).

### Confirm-REQ04-2 — Runtime claim is untrusted

- **Severity:** N/A (procedural note, not a defect).
- **File and line:** `EXECUTION_REPORT.md:1-22` and the supporting evidence files.
- **Intended behavior (PRD `:11`):** "The original draft had no Forge run. The implementation and authorized follow-up are now validated: 175 focused rows and 3,642 full-suite tests passed; see the execution report."
- **Verification:** The execution report claims the prescribed command exited 0 with "175 passed, 0 failed, 0 skipped" for the focused rows, and "3,642 passed, 0 failed, 0 skipped across 383 suites" for the full selection. I do not rerun Forge. The plan's "Done when" run-record requirement is satisfied on the report's face.
- **Impact class:** Procedural; source-level plan execution is confirmed regardless of the runtime result. A re-verified pass would require a fresh Forge run, which is out of scope.
- **Confidence:** High that the source changes match the plan; no opinion on the runtime outcome beyond what the report records.

### Confirm-REQ04-3 — Weighted, single-CP, and orbital production unchanged per agreement

- **Severity:** N/A (confirmation, not a defect).
- **File and line:** the production files for the three families under `contracts/hooks/uniswap/v4/standardExchange/{weighted,constantProduct/single,orbital}/`.
- **Intended behavior (PRD `:56-61`, plan `:91`):** "Weighted, dual, single-CP, and orbital production are unchanged." (Dual superseded by the follow-up; weighted, single-CP, orbital remain required to be unchanged.)
- **Verification:** No `previewSingleJoinExactInShares` Math function added in any of those three directories. The `previewDepositSingle` and `_quoteSingleJoinExactIn` definitions are present at expected line ranges. No `git diff` was run by me; this rests on the plan/report agreement and the absence of any visible new function.
- **Impact class:** Confirmation; no defect.
- **Confidence:** Medium-High (plan/report agreement; not a direct `git diff`).

### Confirm-REQ04-4 — Follow-up amendments applied

- **Severity:** N/A (confirmation, not a defect).
- **File and line:** `DepositQuoteLib.sol:131`; `_positiveOneUnitDepositControl` in `balancer-quad` and `orbital` SeMatrixBehavior files; `ZeroAmount()` only on the curve-quad zero-share control at `:289`.
- **Intended behavior (plan `:9-17`):** The owner-authorized follow-up applies four amendments to the original plan: (1) `_quoteSingleJoinExactInPreview` routing, (2) Dual `_swap` zero-sale early return, (3) positive one-unit controls for SimpleYield F6/F9 and RebasingAware, (4) `ZeroAmount()` only for the two quad zero-share controls.
- **Verification:** All four amendments are present in source. The strict math libraries remain byte-for-byte unchanged per the follow-up's preservation clause.
- **Impact class:** Confirmation; no defect.
- **Confidence:** High (direct source read on each amendment site).

---

## Items I am not asserting

- I am not asserting the runtime result. The "175 / 3,642" claims are from the executor's logs. I do not rerun Forge.
- I am not asserting the production cleanup behavior of the four families. The PRD/plan do not require it for this item.
- I am not asserting byte-for-byte preservation of weighted, single-CP, and orbital production. I have not run `git diff`. The plan/report agreement and the absence of any visible new Math function are the evidence.
- I am not asserting the exact values of the positive one-unit expected shares (`240384615373`, `240384613`, `1`). These are hard-coded in the test fixtures per the follow-up; I read the test calls to `_positiveOneUnitDepositControl(expectedShares)` and the fixture-construction code path, but I did not recompute the math.

---

## Files examined (this confirmation)

- `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.md` — read in full (65 lines).
- `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.plan.md` — read in full (96 lines).
- `docs/reviews/apex-req-04-rounding-controls/EXECUTION_REPORT.md` — read in full (102 lines). Treated as untrusted claim.
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol` — re-read at `:270-349`.
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol` — re-read at `:280-329`.
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol` — re-read at `:390-504`.
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol` — re-read at `:435-484`.
- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol` — re-read at `:120-149` (follow-up edit at `:131`).
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol` — re-read at `:210-292, :325-345`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol` — re-read at `:315-389`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol` — re-read at `:268-355`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol` — re-read at `:288-389`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol` — re-read at `:318-411`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol` — re-read at `:268-355`.
- File-scoped `grep` for `_assertNoMaxAllowances` (not present in REQ-04), `previewMatch` (no rounding-control matches in the six files), `expectedDebit` (six-file table).

No other reviewer files were read. No Forge / build / test was executed. No code was edited.

---

I did not run Forge.