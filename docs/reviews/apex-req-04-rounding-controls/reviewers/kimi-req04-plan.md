# Kimi K3 — REQ-04 plan draft (replacement session)

- **Label:** Replacement-session plan draft, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Controlling PRD: `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.md` (55 lines, read in full; owner ruling `:7`: preview returns 0, execution reverts, no zero-share success, no preview-echo acceptance). Nothing was edited. This is not `REMEDIATION_PRD.plan.md`.
- **Date:** 2026-10-16.

## 1. Per-family preview verdict (production `previewDepositSingle` chain read to the leaf math this round)

- **Weighted — already returns 0; no production edit.** `UniswapV4StandardExchangeWeightedBufferHookMath.sol:351-353` (`_unbalancedJoinShares`): `if (invariantWithFees <= currentInvariant) return 0;` and the final division rounds to 0 without reverting; the comment says "Quotes return zero; the execution commit rejects," matching the ruling.
- **Dual — already returns 0; no production edit.** `UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol:68`: `if (kept == 0 || other == 0) return (true, 0);`, and the `_issue` path ends in `Math.mintSharesLater` division with no zero-share revert.
- **Single-CP — already returns 0; no production edit.** `UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase.sol:66`: `if (otherOut == 0 || kept == 0) return 0;`; for a one-unit input `_singleZapSplit` (`:141-157`) yields `saleAmt == 0` → `_singleSwapQuote` returns 0 (`:186`) → the `:66` guard fires.
- **Orbital — returns 0 on the read path; no production edit.** `_previewDepositSingle` (`Common.sol:2156-2162`) → `_planZap` (`:2083`) → `_toWad(tokenIn, 1) < 3` selects `_singleSidedPlan` (`:2104-2106`) → `_computePartial` (`:2142`) integer math; no zero-share revert exists on that path. If the run shows otherwise, the stop rule fires — no fallback edit is pre-authorized.
- **Balancer-quad — must change.** `UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol:291` (`unbalancedJoinShares`): the unchecked subtraction `_invariant(next, amp, false) - currentD` returns 0 only when growth is exactly zero and **underflow-reverts (panic, an unnamed selector) when the fee trim makes growth negative** — there is no explicit zero guard. Exact change: hoist `uint256 nextD_ = _invariant(next, amp, false); if (nextD_ <= currentD) return 0;` before that return. Execution guard (shared math now returns 0): in `UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:304-305` (`_joinSingleAssetExactIn`), insert `if (shares == 0) revert ZeroAmount();` between the quote and the existing `Slippage` check — `ZeroAmount` is already this family's named selector (`:300`); none is invented.
- **Curve-quad — must change.** `UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol`: the preview reverts today in both fee regimes — `:463` `if (D2 <= D0) revert MathDomain();` (fee trim erases growth; `MathDomain` is not a named test selector) and `:465` `if (shares == 0) revert ZeroAmount();`. Exact change: `:463` → `if (D2 <= D0) return 0;`; delete the `:465` revert so zero shares return 0. Execution guard: in `UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol:466-467` (`_joinSingleAssetExactIn`), insert `if (shares == 0) revert ZeroAmount();` after the quote — same named selector, none invented. Leave `:455` (`D1 <= D0` MathDomain) intact: it signals a broken book, not rounding.

Both Math functions are shared by preview and execution chains; the two execution guards are what keep "execution reverts with the named selector" true after the math stops reverting. No other production file is touched.

## 2. Test edits (six behavior files; PRD `:24-31` sites)

**Rounding control, all six:** the static preview must succeed and decode to 0. Siblings (dual, single-CP, orbital, balancer-quad, curve-quad): keep the staticcall, add `assertTrue(previewOk, "preview returns, does not revert")` and assert the decoded value is 0; delete the `previewMatch` local and remove it from `assertTrue(named || previewMatch, …)`; keep `named` (`InsufficientTokenOut()` / `ZeroAmount()`), the execution call, and the three unchanged-balance assertions. Weighted: delete the `if (!previewOk) { vm.expectRevert(previewRet); … }` block (`:220-225`); assert `previewOk` and `abi.decode(previewRet, (uint256)) == 0`; the existing `preview == 0` branch with `MinAmountNotMet(uint256,uint256)` `(1, 0)` (`:228-233`) becomes the rejection expectation; the success branch is unreachable for this input and stays as written.

**Share site, all six:** replace `assertLt(_hookSeShares…, seBefore, "SE shares burned only for the delivered face")` with an exact reconciliation. Before the call, beside `seBefore`, capture `uint256 expectedDebit = IStandardExchangeOut(seUT).previewExchangeOut(IERC20(seUT), IERC20(face), wantOut);` using each file's existing face-leg SE handle (`seUT` = `fx.se()`; orbital reads `_hookSeShares(0)`/`face0` and its leg-0 SE; `IStandardExchangeOut` is already imported). After the call: `assertEq(seBefore - _hookSeShares(), expectedDebit, "SE debit is exactly the shares required for the delivered output")`. No strict-decrease form survives.

**Untouched:** the excluded non-CP file `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`; funded-swap, refund, and code-less-caller controls; `fx.seBooked()` checks; all other production code.

## 3. One command

Production sources **are** edited in this item (the two quad math files and their two execution cores), so they are the positional edited-source arguments; the six family directories are the test roots (the behavior bases run through their concrete pairing tests). From the repository root, warm `out/`/`cache_forge/`, no profile or `via_ir` change:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve \
  -- -vv
```

The whole run must be green. If a strengthened assertion fails — a preview still reverts, or a family's execution debit differs from its preview quote — stop and report the family and the failing value; do not patch beyond the four named production files, do not weaken an assertion, do not add a selector.

## 4. Stop rule

Before each edit, the cited line must still contain the cited text (PRD `:24-31` sites; the four production sites at `BalancerQuad…Math.sol:291`, `BalancerQuad…LiquidityCore.sol:304-305`, `CurveQuad…Math.sol:463-465`, `CurveQuad…JoinCore.sol:466-467`). Any drift: stop, report file/line/observed text, choose nothing.

I did not run Forge.
