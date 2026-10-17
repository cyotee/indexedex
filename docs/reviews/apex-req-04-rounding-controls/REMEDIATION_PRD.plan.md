# Implementation plan — hook rounding controls

- **Date:** 2026-10-16
- **Status:** COMPLETE under the owner-authorized follow-up below. The owner explicitly requested implementation and then all diagnosed corrections. See [EXECUTION_REPORT.md](./EXECUTION_REPORT.md).
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-04.
- **Council:** Astra replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t` does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. Kimi replacement `ses_ec3d04e91ffeJa0is24e2jZv06` does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. The first calls timed out. The drafts were collected by resuming those same sessions. No Forge run. Consensus is not proof.

## Owner-authorized follow-up (2026-10-16)

The owner requested all corrections recommended after diagnosing the initial 17 failures. This amendment supersedes the conflicting production and fixture restrictions in the original steps below:

1. Route each quad's single-deposit execution quote through `_quoteSingleJoinExactInPreview`, retaining its validation and the `ZeroAmount()` guard before input transfer. Leave the strict math functions unchanged.
2. In Dual `DepositQuoteLib._swap`, return `(amountIn, 0)` when the computed sale is zero, before invoking an underlying SE deposit transition. Keep the subsequent zero-share return and execution rejection.
3. Keep default fixture zero-preview/rejection controls. Give Balancer SimpleYield F6/F9 and Orbital RebasingAware explicit positive one-unit controls with fixed share expectations and exact execution/accounting assertions. Do not infer expected behavior from the observed preview.
4. Require exactly `ZeroAmount()` in both quad zero-share controls. Preserve the other families' named selectors and every exact-output share-debit assertion.
5. Refresh production artifacts for the two quad cores and Dual quote library. Run the six-family focused one-unit/partial-consumption rows, then the full six-family selection. Record results and the incremental diff in `EXECUTION_REPORT.md`.

## Production sentence (original execution)

Change only the two stable-quad preview paths. In each quad math file, add `previewSingleJoinExactInShares` with the same parameters and formula as that file's `singleJoinExactInShares`. It returns 0, before any unsigned invariant subtraction or zero-share revert, when the converted input is zero, the post-fee invariant does not exceed the original, or the share division rounds to zero. Route `_entryPreviewDepositSingle` through a new `_quoteSingleJoinExactInPreview` that uses the existing input, scale, supply, and fee steps and calls that preview function. Do not change the strict execution math. In each `_joinSingleAssetExactIn`, after the existing quote and before input is taken, insert `if (shares == 0) revert ZeroAmount();`. `ZeroAmount` is already named. Do not replace a `MathDomain` revert that means a broken book. Do not edit weighted, dual, single-CP, or orbital production.

## What not to do

- Do not edit `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`.
- Do not invent a revert selector.
- Do not allow a successful zero-share deposit.
- Do not accept a failed preview's revert bytes as the execution result.
- Do not delete funded-swap, refund, or code-less-caller controls.
- Do not enable `via_ir` or delete `out/` or `cache_forge/`.

## Step 1 — quad preview

Files:

- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol`

If line 291 of the Balancer math file is no longer the bare invariant subtraction, or lines 463 and 465 of the Curve math file no longer revert, stop and report. Do not choose another function.

## Step 2 — six tests

All paths are under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`.

For each rounding control:

- The static preview call must succeed and decode to 0.
- Delete `vm.expectRevert(previewRet)` and delete `previewMatch`.
- Weighted execution expects `MinAmountNotMet(uint256,uint256)` with arguments `1, 0`.
- Each other family expects only `InsufficientTokenOut()` or `ZeroAmount()`.
- Caller, hook, and booked balances stay unchanged.

Orbital's staticcall currently encodes `previewDepositSingle(address,uint256,bytes)`. Change it to `previewDepositSingle(address,uint256)`. Do not change the six-argument deposit execution call.

For each share site, before the call capture:

```solidity
uint256 expectedDebit = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(face), wantOut);
```

Use that file's existing face-leg SE handle. Orbital uses the leg-0 handle and `_hookSeShares(0)`. After the call, the burned shares plus any shares minted back to the hook in that call equal `expectedDebit`. If no such mint occurs, the minted-back count is 0. Replace `assertLt`.

## Step 3 — run

Record `git status` and preserve unrelated changes. From the repository root:

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

If a named assertion fails because execution reverts with a selector outside that family's named set, stop and report the family and selector. Do not add that selector. Do not weaken the assertion. Record the command and result in `EXECUTION_REPORT.md` in this directory.

## Done when

- Both quad previews return 0 for a zero-rounded one-unit deposit.
- Both quad executions revert `ZeroAmount()` for that case and do not take input.
- The six tests assert preview 0, the named execution revert, and the exact share debit.
- Weighted, single-CP, and orbital production are unchanged. The Dual `_swap` early return is authorized by the follow-up above and supersedes the original sentence that Dual production was unchanged.
- The excluded non-CP test file is unchanged.

## Dissent

MiniMax's first draft said no production edit. Grok's first draft changed only Curve. The cross-reviews agree both quads can revert instead of returning 0. This plan uses preview-only functions so the strict execution math used by other callers stays. It does not rewrite that shared math in place.
