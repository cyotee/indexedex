# Astra — REQ-04 replacement-session plan draft

Continuation of this replacement's independent drafting pass; I do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. No peer notes were read. The controlling `REMEDIATION_PRD.md` and the six test controls and their production preview call chains were read directly. No code was edited. This is not the consolidated implementation plan and does not authorize execution.

## Production decisions — one per family

Paths in this section start at `contracts/hooks/uniswap/v4/standardExchange/`.

1. **Weighted — no production edit:** `weighted/UniswapV4StandardExchangeWeightedBufferHookJoinQueryTarget.sol:53–59` delegates through JoinCore to Math `_unbalancedJoinShares`, whose lines 349–353 already return zero for non-growing rounded invariant or zero rounded shares; execution `_commitJoin` already rejects zero with `MinAmountNotMet(1,0)`.
2. **Dual CP — no production edit:** `dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:_previewDepositSingle` at 1203–1216 delegates to DepositQuoteLib, whose projected and legacy paths return zero for empty rounded deposit legs (68 and 198–201), and whose proportional issuance math returns the rounded result without a final zero-output revert.
3. **Single CP — no production edit:** `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewTarget.sol:77–79` delegates to InQuoteBase `_singlePreviewDeposit`, which returns zero for empty rounded legs, including ClaimLib `singleFinishDeposit:84`; preserve the separate execution rejection.
4. **Orbital — no production edit for the identified test problem:** the installed `orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositQueryTarget.sol:69–75` exposes **two** preview arguments and returns `_planZap(...).shares`, including existing zero-result paths; the test incorrectly calls a three-argument preview and must call the installed two-argument selector instead.
5. **Balancer quad — preview change required:** `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:_entryPreviewDepositSingle` at 283–288 must use a preview-only quote path rather than strict `Math.singleJoinExactInShares`, which rejects zero converted input at 298 and can underflow on rounded invariant non-growth at 291; implement the isolated zero-aware quote described below in this Core and its sibling Math file.
6. **Curve quad — preview change required:** `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol:_entryPreviewDepositSingle` at 439–445 must use a preview-only quote path rather than strict `Math.singleJoinExactInShares:431–465`, which rejects zero converted input, non-growing rounded invariants and zero final shares; implement the isolated zero-aware quote described below in this Core and its sibling Math file.

These are source conclusions, not executed results for every concrete matrix fixture. Do not change unsupported-route, invalid-book, invalid-fee or dependency-failure behavior into zero just to satisfy a test.

### Exact stable-family preview change

In each of the two Math files, add `previewSingleJoinExactInShares` with the **same parameters and numeric formula** as that file's existing `singleJoinExactInShares`. Preserve structural, index, fee, supply and valid-book checks. For valid books, return zero when converted input is zero, when the computed post-input/post-fee invariant is no greater than the original invariant, or when final share division rounds to zero. In Balancer's preview-only computation, perform the non-growth comparisons before unsigned invariant subtraction. Do not modify the existing strict execution math function or the shared unbalanced-join implementation.

In each named Core, add `_quoteSingleJoinExactInPreview` using the existing `_quoteSingleJoinExactIn` input resolution, conversion, scale, supply and fee calculations, but dispatch to the new preview-only Math function. Route `_entryPreviewDepositSingle` through that helper, retaining its existing token classification/live-state behavior. Keep other public selectors and execution entrypoints unchanged. No broad catch, external self-call, arbitrary-revert-to-zero conversion or new error selector.

**Known completion limitation:** strict stable execution math can also reject invariant non-growth with an error outside the PRD's two sibling selectors (Curve explicitly uses `MathDomain`). The present PRD authorizes preview repair and fixes the execution selector set; this draft does not authorize changing execution or expanding that set. If the fixed one-unit control reaches such a strict-math error, stop and report the source branch to the coordinator; do not accept it or silently normalize it. Consequently this is a bounded draft, not a claim that all concrete rows are already demonstrated executable to completion.

## Ordered test edits

Use only the six `*_SeMatrixBehavior.sol` files in the PRD table: weighted, dual, constantProduct/single, orbital, stable/quad/balancer and stable/quad/curve. Their preview-echo/share locations still match the PRD. Do not edit `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`.

1. Before any edit, validate all six helper/share anchors and the production functions above. A changed or missing anchor stops the whole batch; no substitute site or new family search. After preflight, follow validated function identities despite self-induced line shifts.
2. In each `_roundingToZeroControl`, retain the supported seeded fixture and balance snapshots. Require the static preview call to succeed, require an ABI-decodable scalar and assert the decoded value equals zero. A positive result is a failed zero-rounding precondition, not permission to keep the old positive-success branch or choose another input during implementation.
3. **Orbital only:** replace `previewDepositSingle(address,uint256,bytes)` with `previewDepositSingle(address,uint256)` and remove the preview's bytes argument. Keep the execution's six-argument `depositSingle(...,bytes)` form: that signature is real and distinct.
4. Weighted expects exactly encoded `MinAmountNotMet(uint256,uint256)` with arguments `1,0` and calls execution. Delete `vm.expectRevert(previewRet)` and both success branches.
5. Each sibling retains its low-level execution call, requires `ok == false`, and accepts only the already named `InsufficientTokenOut()` or `ZeroAmount()` selectors; require the expected no-argument error shape, remove `previewMatch`, and delete successful-zero-retention and positive-success acceptance. Do not introduce another selector or bare expected revert.
6. For every rejection, assert unchanged caller face balance, hook face balance and SE booked balance; also snapshot/check hook share supply, caller LP balance and output-leg SE shares. Preserve unrelated funded-swap, capacity, refund and caller-rejection controls.

## Exact share equality

At the six current strict-decrease sites (weighted 282; dual 380; single-CP 345; orbital 368; Balancer quad 397; curve quad 345), capture **before execution**:

`expectedSeDebit = IStandardExchangeOut(outputSe).previewExchangeOut(IERC20(outputSe), IERC20(outputFace), wantOut)`.

Use `seUT`/`face` in five families and `seUT0`/`face0` for orbital. Do not use `needIn`: it is denominated in the hook swap's input token, not output-leg SE shares. Preserve exact output, payer debit and bounded-credit refund assertions. Replace strict decrease with exact reconciliation of the required SE debit.

**Do not hide rebuffering:** weighted `_unwrapExactTokenOut:576–590` can burn SE shares and then mint some back from output surplus, so net balance decrease alone need not equal the gross quote. Capture SE mint-to-hook transfers during this operation and assert `seBefore + mintedBack - seAfter == expectedSeDebit`, restricting the mint total to the output SE's actual zero-address-to-hook mint events; use the same reconciliation in all six behaviors, with zero minted-back where none occurs. This preserves exact equality without incorrectly treating an allowed rebuffer as overburn. Reject an unexplained share transfer or incompatible fixture instead of weakening equality to a tolerance/decrease.

## One artifact-aware command for later authorized execution

After completing the bounded edits, run from the repository root, default hermetic profile, unchanged compiler settings, no `via_ir`, and retained warm artifacts:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve \
  -- -vv
```

The behavior files are abstract `.sol` consumers; directory roots run their concrete `.t.sol` rows and existing family regressions without selecting the excluded non-CP directory. The helper prepares runtime artifacts before tests. Record every build/test result; a missing selector, positive one-unit quote, unexpected execution error or unequal share reconciliation is a stop/report, not an implementer choice to change economics, selectors, scope or assertions. A saved run is not an independent rerun.

Only this report was written. No code, final plan, PRD, configuration, tests or excluded file was edited. No other reviewers' notes, delegation, shell, tests or deployments were used. The previous save attempt was aborted; this continuation saves the same independent pass's draft with its limitations explicit.

I did not run Forge.
