# MiniMax M3 — Cross-review (APEX remediation-application)

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer artifact used as authority. No replacement. No earlier cross-review answers were attached.
- **Target:** current IndexedEx working tree, current state 2026-10-14
- **Question:** agreements, specific objections, evidence that changes my view, corrections, and unresolved dissent against the three peer originals.
- **I did not run Forge.** No shell, build, or test was executed. Source presence is not a passing run.

## Re-reads performed before this cross-review

To confirm or refute material peer claims, I re-read the disputed current source lines. I did not re-read every peer-cited file end-to-end; I re-read the lines each peer cited as the basis for their finding.

- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol` (full read, 37 lines)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol` (full read, 119 lines)
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol` (full read, 151 lines)
- `contracts/vaults/standard/exchange/protocols/uniswap/README.md:28-42`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:85-134`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:140-155`
- `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol:73-77, 108-123, 490-525, 623-679`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol:210-289`

## Agreements with peer findings

### Agree — Astra-01 / Kimi-01 / Grok 3 (REQ-C04 hook zero not applied)

All three peers flag the same defect. I confirmed it in my own first pass (F1, F2) and agree that source lines `UniswapV4DetfCommon.sol:604-605, :614-615, :565, :590, :543-545` still return `0` on a hook preview of zero, that the join loops still break on that zero, that the terminal `_updateReserve` at `:543-545` still runs after a hook-zero return, and that the tests `UniswapV4DetfLeftoverPreview.t.sol:52-84` and `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:46-58` still encode the withdrawn continuation semantics. Severity Medium matches the controlling PRD.

### Agree — Grok 2 / Kimi 4 (legacy V4 yield path dropped the disable check)

I re-read `UniswapV4StandardYieldExecutionTarget.sol:26-36` and `UniswapV4StandardExchangeInTarget.sol:55`. The direct yield path is `nonReentrant` and pokes the TWAP, but does not call `_requireNotDisabled()`. Public `exchangeIn` at `UniswapV4StandardExchangeInTarget.sol:55` does. Severity Low matches Kimi 4; I accept Grok's stronger Medium framing too because the disable gate is named explicitly in the RC-01 plan as a protection the direct yield path must keep.

### Agree — Grok 4 (REQ-C06 caller check on hookless/Pons measurement order)

I re-read `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:85-104` and the Pons mirror. `_pretransferCredit` is called at line 94, then `_amountInForZapMint` at line 95 uses that credit, then `if (amountIn > maxAmountIn) revert UniswapV4ExchangeOut_InsufficientInput()` at line 96 may revert before `_requirePrepaidCredit` at line 101. Compare V3 at `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-86`, which calls `LocalCreditLib.requirePretransferCaller(msg.sender)` BEFORE measuring credit. The PRD says "On a pretransfer, the caller is authenticated before the credit is measured." The plan says place the caller check before the short-credit revert. Hookless and Pons measure first; the caller check sits before the `TransferDeltaInsufficient` revert but not before measurement.

Severity Low matches Grok; the call still reverts. The impact class is diagnostic order, not authorization.

### Agree — Grok 5 (rebasing SY comment and exemption teach a self-call)

I re-read `RebasingAwareStandardYieldTarget.sol:41-44` and `:57-58`. The NatSpec at line 44 says "The vault's own self-call path is unaffected." Line 57 exempts `msg.sender == address(this)` from `requirePretransferCaller`. The function does not itself call `address(this)`, so the exemption is currently unused, but the comment teaches the withdrawn shape. Severity Low; documentation/recurrence.

### Agree — Astra-02 / Grok 1 / Kimi 3 (legacy V4 yield settlement routed via delegatecall to a different execution delegate)

I re-read `UniswapV4StandardYieldExecutionTarget.sol:26-36` and `UniswapV4StandardExchangeInExecutionDelegate.sol:13-18`. `_settleNamedHolder` does `delegatecall` to `executeNamedHolderRedemption`. The plan says "do not move the yield path onto a delegate, to get under the limit" and "Both yield facets call the inherited exact-input settlement and pass the holder." V3's yield target calls the inherited function internally at `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:26-29`. Legacy V4 chose a delegate instead.

Severity disagreement is real but small:
- Kimi rated Low and explicitly noted the confirmation PRD kept REQ-C01 at Medium for the unmet self-call prohibition; the identity-forging self-call is gone, and the new entrypoint is contained by `DelegateCallRequired` (line 9, 16) and by the selector not being exported on the diamond (`UniswapV4StandardExchangeInFacet.sol:25-30`). No unauthorized payout path exists in the tree I read.
- Astra rated Low for the same shape.
- Grok rated Low because the holder and burn semantics are improved and the identity-changing self-call is gone.

I keep Low. This is a specification-conformance defect, not an authorization bypass. V3 is the model and V4 deviates.

### Agree — Astra-03 (Stage-1 REQ-04 matrix rounding controls still match preview reverts to execution reverts)

I re-read `UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol:212-241`. `_roundingToZeroControl` at line 216-225 matches a failed preview to the execution revert by passing `previewRet` to `vm.expectRevert`. PRD lines 246-250 require an exact rounding error or a measured successful zero-output with the branch precondition. The test still derives its expected revert from a failed preview, so a shared unrelated failure can satisfy the rounding control. The SE shares assertion at line 282 is a strict-decrease check rather than an exact consumption check.

Astra's reachability claim that the same shape lives in dual, orbital, single-CP, Balancer-quad, and curve-quad matrix behaviors was not separately re-read; the verdict on those is unverified per Kimi 4 and the original confirmation.

### Agree — Astra-04 (README line 38 contradicts line 32 on excess exact-in)

I re-read `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32-38`. Line 32 says "An exact-in excess push does not revert merely for being excess, and exact-in never refunds." Line 38 says "An exact-in call whose declared amount differs from that surplus reverts." This is the September council RC-04 stale-comment defect. The REQ-C05 PRD did not cover line 38. Severity Low; documentation/integrator guidance.

### Agree — Astra-05 (Balancer callback test oracle queries the wrong adapter instance)

I re-read `Adversarial_BalancerV3SinglePoolSE.t.sol:73-77, 108-123, 490-525, 623-679`. The test class member `adapter` is set in setUp from `_deployAdapter()` (line 73) and is the production adapter. The test in `test_RC01_callback_nestedMoneyEntry_hitsAdapterLock_outerSucceeds` (line 493) deploys a separate adapter `locked_` via `_deployProbePool(probe)` (line 495) and operates on `locked_`. `_assertNoMaxAllowances(IERC20(address(probe)))` at line 520 reads allowances for `adapter` (the test class member, the production adapter), not for `locked_` (the exercised adapter). The probe token's allowance mapping at line 668-675 stores `allowance[from][msg.sender]` keyed by `from` and `msg.sender`; the helper at lines 110-122 queries that mapping against the production adapter's address, not `locked_`.

Severity Medium matches Astra. This is a test-oracle defect that lets the callback regression report successful cleanup without establishing it on the exercised adapter.

### Agree — Astra-06 (holder-balance negative tests use bare `vm.expectRevert()`)

I re-read `UniswapV3FullSpreadVaultHeldRedeem.t.sol:142-152`. `test_RC01_insufficientHolderBalance_reverts` at line 147 uses `vm.expectRevert()` without pinning a specific error selector. The same shape is at `UniswapV4StandardExchangeVaultHeldRedeem.t.sol:154-163` per Astra. Severity Low; test gap.

## Specific objections and corrections

### Withdraw F3 (positive observation, V3 `_secureTokenTransfer` caller-before-credit order) from my original

I am not withdrawing the observation; the source still has the order. I am recording that it is consistent with Grok's Finding 4 framing: the V3 `_executeQuotedSwapOut` quoted branch has the right order, but the hookless/Pons exact-output mint and direct-out branches do not. F3 stands as positive for V3 only.

### Narrow F4 (V4 `address(this)` previews) from my original

I am narrowing F4. Grok 4 and Kimi do not object to the boundary observation, and the PRD explicitly excludes view previews from the call-to-self rule. I keep F4 as adjacent/informational, not a finding.

### No change to F1 and F2 from my original

Astra, Grok, and Kimi all agree the hook-zero is not applied and the tests still encode the withdrawn continuation. F1 and F2 stand as written. The peer consensus on this defect strengthens my confidence, not weakens it.

## Unverified or partial peer claims I cannot resolve

- **Kimi R-04 (Stage-1 REQ-04) "applied (verified by re-read + pattern absence)"**: Kimi's re-read covers the weighted behavior body and a grep showing no `catch` and no bare `expectRevert()` in `*SeMatrixBehavior.sol`. That is the opposite conclusion from Astra-03. The grep assertion is consistent with Kimi's claim (no broad catch), but the `_roundingToZeroControl` body I re-read still derives the expected revert from the failed preview's `previewRet`, which is a finer-grained match that still gates the control on the preview's behavior. Without an execution run, the effective difference between "uses previewRet as expected revert" and "matches any revert" cannot be evaluated. Recording partial.

- **Astra-06 V4 file line number**: Astra cites `UniswapV4StandardExchangeVaultHeldRedeem.t.sol:154-163`; I did not re-read this round. The shape is consistent with the V3 finding.

- **Kimi 4 V3 disable rule**: Kimi notes V3's public `exchangeIn` deliberately skips the disable check for share routes (`UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:41`). I did not re-read that file. The legacy V4 disable check remains an unresolved shape question (Grok 2 / Kimi 4).

## Material peer claims not separately re-read (cross-review efficiency)

- All Stage-1 September PRD items (REQ-01 through REQ-08) — Kimi re-read REQ-02 / REQ-03 / REQ-04 / REQ-05 / REQ-06 / REQ-07 source in part. I accept Kimi's per-row verdicts for items I did not separately re-read; my own first pass marked them unverified, and the cross-review continues that posture for items I did not re-confirm.
- September council RC-01 through RC-08: no peer produced a complete re-read; I keep them unverified.
- All `*SeMatrixBehavior.sol` files beyond weighted: I accept Astra's claim that the same shape appears in dual, orbital, single-CP, Balancer-quad, and curve-quad. I did not re-read those bodies.

## Verdicts on my own first-pass findings after cross-review

| My first-pass ID | Action | Reason |
|---|---|---|
| F1 (REQ-C04 hook zero not applied) | Keep | Three peers agree; source re-read confirms. |
| F2 (REQ-C04 tests still encode continuation) | Keep | Three peers agree; test re-read confirms. |
| F3 (V3 `_secureTokenTransfer` caller-before-credit) | Keep as informational; narrow to V3 only | Grok 4 confirms hookless/Pons deviate. |
| F4 (V4 `address(this)` previews) | Keep as adjacent/informational | PRD excludes view previews; not a finding. |

## Unresolved dissent this pass cannot resolve

1. **Legacy V4 yield path shape (Astra-02 / Grok 1 / Kimi 3).** The plan forbids moving the yield path onto a delegate even under EIP-170 pressure. Legacy V4 did. V3 did not. Whether an owner amendment I have not read permits the V4 shape is unknown. I record it as a Low severity conformance defect.
2. **Legacy V4 disable check (Grok 2 / Kimi 4).** The plan requires it. The yield helper does not call it. The FullSpread README at line 58 (`contracts/vaults/standard/exchange/protocols/uniswap/README.md`) says disabling allows SY exits. That README is the FullSpread family file, not legacy V4. No owner ruling applying the FullSpread rule to legacy V4 was re-read. I record it as Low.
3. **REQ-C06 measurement order (Grok 4).** PRD and plan disagree on whether `LocalCreditLib.requirePretransferCaller` must precede `_pretransferCredit` measurement or just the short-credit revert. The plan's "before the comparison" instruction was followed on hookless/Pons; the PRD's "before measurement" was not. I record the impact as diagnostic order, not authorization.
4. **Stage-1 REQ-04 weighted vs the other six matrices.** Kimi says applied (no catch). Astra says partial (still matches preview reverts). I did not exhaustively re-read the other six. Partial.

## Evidence gaps

- Forge, build, and tests were not run. No source identity hash was recomputed. No current-source map, artifact provenance, runtime-size result, selector inventory, or passing regression count is certified. RC-07 ignore does not waive Stage-1 REQ-08 or EIP-170.
- Constructor immutables of `UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE` were not compared with the V4 facet constructor; runtime behaviour matches because the holder is passed through, but a strict byte-equivalence proof was not done.
- The legacy V4 stored-reserve-minus-deployed credit (`UniswapV4StandardExchangeCommon.sol:1256-1274` region) was not re-read this round; the September confirmation PRD kept that as a residual decision, not a failed RC-03 deletion.
- The `Astra-03` claim that all six other matrix behaviors share the roundingToZeroControl shape was not separately re-read.
- The `Astra-04` README line 38 contradiction was confirmed; the September PRD's required-comment text I did not restate verbatim, only paraphrased.
- Slipstream was not opened (per REQ-C06 non-goal).

## Final note

**I did not run Forge.** No `forge build`, `forge test`, or shell command was executed. Source presence is not a passing run. The cross-review is a re-read of disputed lines against the three peer originals; it is not a re-audit and does not certify that any unverified ID is closed.