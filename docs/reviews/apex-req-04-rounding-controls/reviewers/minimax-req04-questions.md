# MiniMax M3 — REQ-04 owner-question answer (replacement-session targeted)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Targeted answer only. Not a new review round.
- **Controlling text:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` section "REQ-04 — Matrix rounding controls still echo a failed preview" (lines 124–134 of that PRD).
- **Files read for this answer:** the PRD section, and the six cited `*SeMatrixBehavior.sol` files at the cited lines plus the surrounding test bodies. No peer review files were read.
- **Forge:** Not run.

---

## Headline answer — No blocking question

The exact expected rounding result, the share assertion shape, and the file list are already determined by the current tests and the PRD section. The implementer reads the production hook/SE to fill in the share-burn value, which is normal implementation work and not an owner decision. No policy or scope question is left for the owner before the PRD for REQ-04 is written.

---

## Evidence by item the owner asked about

### 1. File list — determined by the PRD

The PRD names the six files and the lines verbatim (lines 124–134 of `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md`):

- Weighted control: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol:216-225`, share assertion at `:282`.
- Dual previewMatch: `.../dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol:321-322`.
- Single-CP previewMatch: `.../constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:286-287`.
- Orbital previewMatch: `.../orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol:308-309`.
- Balancer-quad previewMatch: `.../stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol:338-339`.
- Curve-quad previewMatch: `.../stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol:286-287`.

The PRD also excludes the single non-CP file (the row of `UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol` under `single/`): "The single non-CP file was not shown by search to use `previewMatch` in that control and is not included." Confirmed by my read of that file: it does not import or use `previewMatch` in its rounding control. No additional file is in scope, and no additional file is missing from scope. The list is closed.

### 2. Exact expected rounding result — determined by the current tests

For each of the six files, the rounding-control helper's branch-on-revert already names a selector or set of selectors that constitute the family's exact rounding result. The PRD's first acceptance bullet says the control "expects the family's exact rounding result … without taking the expected failure from an arbitrary failed preview." The fix is to remove the arbitrary-preview-failure acceptance (`previewMatch` and, for weighted, `expectRevert(previewRet)`); the named selectors stay. Verified by reading each file at the cited lines:

- **Dual (`:321-322`)**: named selectors `InsufficientTokenOut()` and `ZeroAmount()`; `previewMatch` is the bug to remove.
- **Single-CP (`:286-287`)**: same pair of named selectors; same fix.
- **Orbital (`:308-309`)**: same pair; same fix.
- **Balancer-quad (`:338-339`)**: same pair; same fix.
- **Curve-quad (`:286-287`)**: same pair; same fix.
- **Weighted (`:216-225`)**: line 229 already pins the family's exact rounding result as `MinAmountNotMet(uint256,uint256)(1, 0)` for the `preview == 0` branch. The `!previewOk` branch at `:220-225` echoes the preview's revert bytes (`expectRevert(previewRet)`) and is the bug to remove. The fix is to apply the already-pinned selector `MinAmountNotMet(uint256,uint256)(1, 0)` to that branch too. No selector needs to be invented; the current code at `:229` supplies it.

The current tests therefore determine the rounding result for every family. The implementer does not invent a selector.

### 3. Share assertion — determined by the PRD's shape plus a function call

The PRD's second and third acceptance bullets state the assertion shape:

- "The weighted exact-output assertion reconciles the SE debit with the shares required for that output."
- "Sibling share assertions are checked the same way where they still use a strict decrease for this control. A file that already reconciles the exact debit is cited and left alone."

All six files currently share the same `assertLt(_hookSeShares(), seBefore, "SE shares burned only for the delivered face");` pattern at the refund-test tail (verified locations: weighted `:282`, dual `:380`, single-CP `:345`, orbital `:368`, balancer-quad `:397`, curve-quad `:345`). The fix is to replace `assertLt` with `assertEq` against the shares required for `wantOut`.

The "shares required" is a function call on the production hook/SE, not a hard-coded value the owner must supply. The weighted file already exercises the relevant family-specific preview function for adjacent tests (line 380 calls `weighted.previewWithdrawSingle(face, burn)`); the SE view is also available (`seUT` is declared at the top of each behavior file and is the SE diamond). The implementer reads the production hook/SE to determine the exact share-burn expression — that is normal implementation work for a test that asserts an exact reconciliation, not an owner policy decision.

If a specific file already reconciles the exact debit, the PRD's third bullet says to cite it and leave it alone. The implementer notes that case during the audit step; no owner decision is needed to anticipate it.

### 4. No production edit, no policy question, no scope expansion

The PRD's non-goals (line 134) forbid deleting funded-swap, refund, or code-less-caller controls, and forbid marking a row compatible on the strength of a preview echo. These non-goals are explicit and closed. There is no production-code edit in REQ-04. There is no family addition or removal. There is no scope expansion to non-named files.

---

## Items I am not asserting

- I am not asserting any selector or value beyond what is already in the current tests.
- I am not asserting that any of the six files already reconciles the exact debit. The PRD's third bullet anticipates that case and instructs the implementer to cite it; if it exists, the implementer notes the line; if it does not, the implementer applies the fix shape.
- I am not asserting production behavior. The hook/SE share-accounting semantics were not re-read for this answer. The implementer reads them as part of writing the test expression.

---

## What would change this answer

This is "No blocking question" only if the implementer can determine everything from the PRD section and the current tests plus a normal read of the production hook/SE. The answer flips to "one blocking question" if any of the following is true; I checked all three and none is true:

1. The PRD names a selector or value that is not in the current tests and the production code does not pin it. — Not true. Every selector the PRD requires is already in a current test (siblings: `InsufficientTokenOut`/`ZeroAmount`; weighted: `MinAmountNotMet(uint256,uint256)(1, 0)` at line 229).
2. The PRD names a selector that conflicts between two families. — Not true. Each family has its own selector and the PRD does not require a unified selector across families.
3. The PRD requires a hard-coded share-burn value rather than a function call. — Not true. The PRD says "reconciles" and "shares required," which is a function-call-shaped requirement, not a constant.

---

## Files examined

- `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` REQ-04 section (lines 124–134) — read in full.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol` — read at `:140-241`, `:260-282`, `:341-351`, `:370-385`. Helper `_hookSeShares` at `:143-145`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol` — read at `:300-339`, `:355-381`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol` — read at `:270-304`, `:320-345`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol` — read at `:290-326`, `:345-369`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol` — read at `:320-356`, `:375-397`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol` — read at `:270-304`, `:320-345`.

No Forge / build / test was executed.

---

I did not run Forge.