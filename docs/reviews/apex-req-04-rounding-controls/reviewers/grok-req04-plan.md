# Grok plan draft — REQ-04

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Controlling PRD:** `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.md`

This file does not authorize an edit. It is not `REMEDIATION_PRD.plan.md`.

## Stop

If a line in the PRD table no longer has the preview-echo or the `assertLt` share check, stop and report that file and line. Do not choose another line. Do not edit `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`.

## Production

- **Weighted:** `previewDepositSingle` already returns 0. `Math._unbalancedJoinShares` returns 0 when the invariant does not increase. Do not edit production. Execution already reverts `MinAmountNotMet(1, 0)` in `_commitJoin`.
- **Dual:** `_previewDepositSingle` already returns 0. `DepositQuoteLib.previewLegacy` returns 0 when a leg is empty. Do not edit production.
- **Single constant-product:** `_singlePreviewDeposit` already returns 0 when the zap output is zero, and `ClaimLib.singleFinishDeposit` returns minted 0 when an added leg is zero. Do not edit production.
- **Orbital:** `_previewDepositSingle` already returns the plan shares, including 0 from `_singleSidedPlan`. Do not edit production. Execution already reverts `ZeroAmount()`.
- **Balancer quad:** `_entryPreviewJoinSingleAssetExactIn` already returns 0 when the computed shares round to zero. Do not edit production.
- **Curve quad:** change `UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore._entryPreviewJoinSingleAssetExactIn` so a zero-rounded quote returns 0 instead of letting `Math.singleJoinExactInShares` revert `MathDomain` or `ZeroAmount`. Do not edit `singleJoinExactInShares`. Execution `_joinSingleAssetExactIn` must still revert `ZeroAmount()`, which the test already names. Do not add a selector, and do not let a zero-share deposit succeed.

## Test edits

In each of the six `_roundingToZeroControl` functions: the static `previewDepositSingle` call must succeed and decode to 0. Delete weighted's `vm.expectRevert(previewRet)` branch and every sibling `previewMatch`. Then expect the deposit to revert: weighted with `MinAmountNotMet(uint256,uint256)` arguments `1, 0`; each sibling with only `InsufficientTokenOut()` or `ZeroAmount()`. Caller, hook, and booked balances stay unchanged. Delete the successful zero-share retention branch.

On each share site, before the exchange, quote the shares with the same call production uses to size the burn: `IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(deliveredFace), wantOut)`, where `se` is the standard exchange whose balance the current share helper reads and `deliveredFace` is that test's output token. Replace `assertLt` with `assertEq(seBefore - sharesAfter, sharesRequired)`.

## Command

From the repository root, after the curve preview change and the six test edits:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve \
  -- -vv
```

Do not pass another production source. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`. If the command fails, stop and report it. Do not add a selector to make it pass.

I did not run Forge.
