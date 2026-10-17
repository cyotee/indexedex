# Kimi K3 — REQ-04 rounding controls: is an owner question left? (replacement-session targeted answer)

- **Label:** Replacement-session targeted answer, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Controlling text: `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` REQ-04 (`:122-132`, re-read this round). All six cited behavior files were read at the cited lines this round. Nothing was edited. This is not a new findings round.
- **Date:** 2026-10-16.

## Answer: No blocking question.

The section and the current tests determine all three inputs the owner named. Nothing remains that is a product, economic, or API decision; what remains is mechanical and the plan can pin it without asking anyone to search.

## 1. The file list is determined

Six files, each verified at the cited lines this round:

| File (under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`) | Preview-echo site (verified) | Strict-decrease share site (verified) |
|---|---|---|
| `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol` | `:216-225` — on preview failure, `vm.expectRevert(previewRet)` (echoes the failed preview's bytes) | `:282` — `assertLt(_hookSeShares(), seBefore, "SE shares burned only for the delivered face")` |
| `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol` | `:321-322` — `previewMatch` disjunct | `:380` — same `assertLt` |
| `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol` | `:286-287` — same | `:345` — same |
| `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol` | `:308-309` — same (on `_hookSeShares(0)` face leg) | `:368` — same |
| `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol` | `:338-339` — same | `:397` — same |
| `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol` | `:286-287` — same | `:345` — same |

Every sibling's `previewMatch` line is textually identical: `bool previewMatch = !previewOk && previewRet.length >= 4 && sel == bytes4(previewRet);` feeding `assertTrue(named || previewMatch, ...)`. The non-CP file `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol` is excluded — the section says it was not shown to use `previewMatch` in that control, and my read of its grep surface is consistent (it asserts exact `_seOf` deltas instead). No seventh file.

## 2. The exact expected rounding result is determined

The named-error vocabulary is already inside each control and needs no new information:

- The five sibling controls already name the acceptable rejections: `InsufficientTokenOut()` and `ZeroAmount()` (the `named` boolean, e.g. dual `:320`). The fix deletes the `previewMatch` disjunct so the rejection must be one of the named selectors — never "whatever the failed preview returned."
- Weighted's control already demonstrates the fully-named pattern in its `preview == 0` branch: `vm.expectRevert(abi.encodeWithSignature("MinAmountNotMet(uint256,uint256)", 1, 0))` (`:229`). Its `!previewOk` branch (`:220-225`) must adopt the siblings' call-and-selector shape so it can assert the named set instead of `vm.expectRevert(previewRet)`.
- The success branches already assert the exact rounding result: `shares == abi.decode(previewRet, ...)` ("dust execution matches its preview") plus the unchanged caller/hook/book assertions. Those stay.

## 3. The share assertion is determined

Each file's exact-out control already holds every value the reconciliation needs: `wantOut` (face delivered, asserted exact), `seBefore = _hookSeShares()` captured before the call, `seUT` (= `fx.se()`, the face-leg SE, e.g. weighted `:72`, `:143-145`), and an existing `IStandardExchangeOut` import (`:6`). The closed form, identical in all six files (orbital reads `_hookSeShares(0)`):

```
uint256 expectedDebit = IStandardExchangeOut(seUT).previewExchangeOut(IERC20(seUT), IERC20(face), wantOut);
// captured with seBefore, before execution
assertEq(seBefore - _hookSeShares(), expectedDebit, "SE debit is exactly the shares required for the delivered output");
```

This reconciles the measured SE debit with the shares the family's own exact-out preview requires for the delivered output — the section's criterion verbatim. Preview/execution parity is not assumed blindly: these same files already enforce preview-equals-execution on their swap/join rows (e.g. weighted `:376-390`), and the control's own run is the check — if a family's execution debit diverges from its preview, the strengthened assertion fails and that divergence is reported as a finding, not patched around. The oracle is the family's production preview; no alternative is offered, so there is no implementer choice.

## What the plan must pin (all mechanical, no owner input)

1. Six files, the twelve sites in the table above; no others.
2. Siblings: delete the `previewMatch` local and remove it from the disjunction; keep `named`, the selector check, and the three untouched-balance assertions.
3. Weighted: convert the `!previewOk` branch to the sibling call-and-selector shape, expecting `InsufficientTokenOut()` or `ZeroAmount()`; the `preview == 0` branch keeps `MinAmountNotMet(1, 0)`; the success branch is unchanged.
4. All six: replace `assertLt(_hookSeShares…, seBefore, …)` with the exact-debit assertion in §3, capturing `expectedDebit` beside `seBefore` before the call.
5. Untouched: the funded swap, refund, and code-less-caller controls that already assert exact deltas (section non-goal); `fx.seBooked()` checks; the non-CP single file; all production code.

I did not run Forge.
