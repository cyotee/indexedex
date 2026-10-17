# Remediation PRD — hook rounding controls

- **Status:** IMPLEMENTED with the owner-authorized follow-up; see [EXECUTION_REPORT.md](./EXECUTION_REPORT.md).
- **Date:** 2026-10-16
- **ID:** REQ-04
- **Severity:** Medium. This is a test-oracle gap, and a production preview gap only if a named preview reverts instead of returning 0.
- **Owner ruling:** If the amount out rounds to zero, the preview returns 0 and the execution reverts. A successful zero-share retention is not allowed. A failed preview is not the expected execution result.
- **Astra participation:** Targeted question. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Execution evidence:** The original draft had no Forge run. The implementation and authorized follow-up are now validated: 175 focused rows and 3,642 full-suite tests passed; see the execution report.

Writing this PRD does not authorize a test or code edit.

## Owner-authorized follow-up (2026-10-16)

After the initial implementation and diagnosis of all 17 failing controls, the owner requested all suggested corrections. This authorization supersedes the preview-only production restriction below:

- The two quad deposit execution paths use the validated zero-aware quote and reject zero shares with `ZeroAmount()` before taking input. Shared strict math remains unchanged; genuine invalid-book errors remain errors.
- Dual preview stops before attempting an underlying `DepositExactIn` transition with a zero-sized swap leg.
- One raw token unit is not universally a zero-share input. Balancer SimpleYield F6/F9 and Orbital RebasingAware fixtures have explicit positive one-unit controls that require preview/execution parity, exact share receipt, exact payment and SE inventory. The other rounding controls still require preview zero and rejection; they do not branch on whatever preview happens to return.

The original implementation and follow-up validation are recorded in [EXECUTION_REPORT.md](./EXECUTION_REPORT.md).

## Required outcome

For each of the six named families, a one-unit deposit whose output rounds to zero has a preview that returns 0. The deposit execution reverts. The caller, the hook, and the booked balance are unchanged. The test does not accept the preview's revert bytes as that execution result.

## Files

All paths are under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`.

| Family | Preview-echo site | Share site |
| --- | --- | --- |
| `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol` | 216–225 | 282 |
| `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol` | 321–322 | 380 |
| `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol` | 286–287 | 345 |
| `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol` | 308–309 | 368 |
| `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol` | 338–339 | 397 |
| `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol` | 286–287 | 345 |

The non-constant-product file `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol` is not in this list. Do not edit it for this item.

## Exact test rule

- Assert the static preview call succeeds and decodes to 0. Delete the branch that does `vm.expectRevert(previewRet)` when the preview fails.
- Then expect the execution to revert. Weighted keeps `MinAmountNotMet(uint256,uint256)` with arguments `1, 0`. Each sibling keeps only its already named selectors, `InsufficientTokenOut()` and `ZeroAmount()`. Delete `previewMatch`.
- Caller, hook, and booked balances are unchanged.
- On each share site, replace `assertLt` with equality to the shares that family's exact-output preview requires for the delivered output. Capture that quote before the call. Do not assert only that shares decreased.

## Production

If a named family's `previewDepositSingle` reverts for this one-unit zero-output case, change that preview to return 0. Do not make the execution succeed. Do not invent a new revert selector. The execution keeps the selector the test already names for that family. A later plan names the production function only if the current preview does not already return 0. If it already returns 0, do not edit production.

## Non-goals

- Do not delete funded-swap, refund, or code-less-caller controls that already assert exact deltas.
- Do not mark a row passed because a preview failed.
- Do not allow a retained zero-share success.
- Do not edit the excluded non-constant-product file.

## Dissent

Astra asked whether zero-share success was allowed. The owner ruled that it is not. Grok's proposed selector names are the ones this draft keeps. MiniMax and Kimi reported no further owner question after that ruling.
