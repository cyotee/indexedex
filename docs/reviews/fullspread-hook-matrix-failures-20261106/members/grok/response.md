# Grok initial response

## Identity

- Run ID: fullspread-hook-matrix-failures-20261106
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/fullspread-hook-matrix-failures-20261106/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role: not exposed
- Actual model: not exposed
- Actual reasoning: not exposed
- Task ID: not exposed
- Session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Diagnose each distinct failure in the supplied Foundry results for the Uniswap V4 FullSpread Standard Exchange hook-matrix and buffer-integration tests, and propose the smallest resolution for each. Do not implement.

Required targets, all examined:

1. test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
2. test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
3. test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol
4. test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
5. test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol
6. test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol
7. contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md
8. contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md

Distinct supplied messages, coordinator-supplied, not re-run:

1. FS-HOOK-04: required PairToken identity rejected; FS-A26 OPEN
2. FS-HOOK-04: this-vault identity rejected; FS-A24 OPEN
3. FS-HOOK-04: required PairToken identity rejected
4. VaultDisabled(0x55A8BCB67Bc9F37B585A47f76552de0597D5c493)

Public queries: not used.

## Evidence

Source observation is separated from inference. Supplied failure text is coordinator-supplied runtime, not this member's execution. This member did not run Forge.

### Identity reject gate

The hook packages do not call `asset()` themselves. They call `UniswapV4SeBufferHookLegLib.pairInVaultTokens`.

Observed in `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol` lines 174-197:

- A bind is accepted when `pair` is in `se.vaultTokens()`, or when `isWrapperShareInventory` is true.
- `isWrapperShareInventory` is true only when `pair == se` and a staticcall to selector `0x38d52e0f` returns a non-zero underlying different from `pair`. The comment on lines 188-190 calls that the identity-wrapper alternative and says it is not a general `asset()` gate.
- Otherwise `pairInVaultTokens` returns false.

Observed callers, all reached from `processArgs` through `_validateArgs`:

- Dual package, `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol` lines 374-392, reverts `TokenNotInVaultTokens`.
- Orbital package, `UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol` lines 363-410, reverts `InvalidSE` from `_requireSeOwnsToken`.
- Weighted package, `UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol` lines 451 area, reverts `InvalidSE`.
- Curve package, `UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol` lines 423 area, reverts `InvalidSE`.
- Balancer package, `UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol` lines 413 area, reverts `InvalidSE`.

Observed membership inputs:

- FullSpread `initAccount` sets `vaultTokens` to the two pool faces, with WETH substituted for native. `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` lines 191 and 239-244. A search of that family's production Solidity found no `asset()` definition.
- PairToken `initAccount` sets `vaultTokens` to the two faces and sets share decimals to 18. `UniswapV4PairTokenStandardExchangeVaultDFPkg.sol` lines 260-263. A search of that family's Solidity found no `asset()` definition.
- `deploySibling` assigns `pairPkg_.deployVault` to `sib_.share`. `SeMatrix_FullSpreadV4Fixture.sol` lines 203-236. The share address and the PairToken vault address are the same diamond.

Inference, not observed revert bytes: the tests bind `token == se` for the PairToken share, and for FS-A24 they also bind `token ==` this FullSpread vault. `pairInVaultTokens` is false for that pair because the share is not a face and the wrapper-share staticcall is the only `asset()` path. The first failing check in the dual validator is that membership check. Rate-provider absence is not that check: the identity tests pass a provider, and the dual validator skips the provider requirement when `token == se` (dual package lines 388-389). Decimal mismatch is not the first check on the rows that copy live decimals through `HookPkgArgsDecimalsLib.seDec`, and PairToken init sets decimals to 18. The supplied messages say the identity bind was rejected. They do not include the revert selector. This member did not read `identityRevert`.

### What the tests record

Observed record helper in target 1, lines 103-108:

```solidity
event FS_HOOK_04(address consumer, bytes4 selector, bytes arguments, bytes revertData);
emit FS_HOOK_04(consumer_, bytes4(keccak256("processArgs(bytes)")), abi.encode(args_), reason_);
```

Callers pass `abi.encode(args_)`, which is the `processArgs` input, and `record` wraps that bytes value again. Observation: the event's third field is one ABI `bytes` wrapper outside the `processArgs` argument. A decode of that field as `bytes` recovers the argument. The selector field is the outer `processArgs` selector, which is the call the test made. The revert field is the catch data.

That event is emitted in the bind catch before the failing assertion. For tests that only bind in `setUp`, the emission is in `setUp`. This member did not execute, so this member did not see whether Foundry attached that `setUp` log to the failure trace.

The in-test `fail()` strings do not themselves repeat consumer, selector, and arguments. They log the revert bytes, except message 3, which does not.

### Message 1 paths

Target 1, lines 354-360: `_requireIdentity` logs the stored revert and calls `fail` with message 1 when `processArgs` rejected the PairToken bind. `_bindDual` lines 336-348 sets `hook` to `address(0)` on that reject. The twelve message-1 tests call `_requireIdentity` directly or through `_crossVaultDirections`. Tests that do not need the hook are not in the supplied failure list. That absence is not a pass certification.

Targets 2-5 fail only `test_row_identity_pairToken` with message 1, at lines 158, 27, 179, and 174. Their other public tests run the face/raw directions and call the PairToken directions only if `identityAccepted` is true. On reject they clear the rejected SE binding and still deploy the face/raw control. Target 3 inherits that bind from `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` lines 129-145. The five-leg file's own `fail` is line 27.

Target 6 repeats those functions by inheritance. `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` is `FullSpreadDualRow`. The orbital, curve, weighted-three, and balancer-five unwrap contracts inherit the corresponding rows. Their supplied message-1 failures are those inherited functions, not new assertions.

### Message 2 path

Target 1, lines 429-441, `test_row_identity_thisVault`. It calls `hookPkg.processArgs` with `token0 == seUT` and `standardExchange0 == seUT`, catches any revert, emits `FS_HOOK_04`, and `fail`s with message 2. It does not decode the revert. The same function is inherited by the dual unwrap contract.

Inference from dual `_validateArgs` order: leg 0 is checked before leg 1. Leg 0 is `token ==` this vault. That membership check fails before the PairToken leg is checked. The caught revert is therefore the this-vault reject if no earlier zero-address or same-token check fails. The arguments in that test are non-zero and the two SE addresses differ. This is inference, not observed revert data.

### Message 3 path

Target 6, lines 236-247, `test_dualUnwrapApprovesAndCompletesExit`:

```solidity
assertTrue(identityAccepted, "FS-HOOK-04: required PairToken identity rejected");
```

The contract comment on line 236 says the canonical identity reject remains a blocker and is never a skipped unwrap. The assertion does not emit `FS_HOOK_04`, does not log the revert, does not name consumer, selector, or arguments, and does not include the FS-A26 OPEN suffix. It stops before the withdraw call. `hook` is `address(0)` after the dual bind reject, so the withdraw cannot run on this contract.

### Message 4 path

Target 6, lines 110-120, `test_disabledBufferedWithdrawalApprovesAndCompletesExit`. The contract inherits the constant-product single row, not the dual row. It disables `seUT` and calls hook `withdraw(uint256,address,uint256,uint256,uint256)`. The file comment on line 110 calls this H10. The file does not mention FS-HOOK-04 in this test. No source read for this test connects it to the identity bind.

The supplied revert argument `0x55A8BCB67Bc9F37B585A47f76552de0597D5c493` was searched as a literal across the repository and was not found. It is unverified. It is not a test assertion. The test does not encode an expected address.

Observed vault predicate, `UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol` lines 39-40 and 134-141: `exchangeIn` treats the call as a withdrawal only when `tokenIn == address(this)` and `tokenOut` is a face. Otherwise `_disable` reverts `IVaultRegistryDisableQuery.VaultDisabled(address(this))` when `isDisabled(address(this))` is true. The quote target's `previewExchangeIn` does not contain that check.

Observed hook path for the called selector: `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet` installs `IHook.withdraw` on `WithdrawTarget`. `WithdrawTarget._withdraw` calls `Withdrawal.unwrapSeShares`, then later `Withdrawal.refundPairDust`.

- `unwrapSeShares`, withdrawal library lines 80-91, calls `exchangeIn` with `tokenIn` the bound SE and `tokenOut` the bound pair token.
- The constant-product FullSpread row binds `pairToken` to `face` and `standardExchange` to `seUT`. Behavior file lines 118-125.
- `refundPairDust`, withdrawal library lines 122-131, can call `ClaimLib.bufferQuotedResidual`. That function, claim library lines 389-394, calls `exchangeIn` with the pair token in and the SE share out. That is a deposit, not a withdrawal, under the predicate above. `MAX_DUST_WEI` is 10. The call runs when the hook's pair-token balance exceeds that dust and the preview is non-zero.

Inference: a share-to-face `exchangeIn` on this binding matches the withdrawal exception and should not be the `VaultDisabled` source. A later face-to-share `exchangeIn` on the same withdraw matches the non-withdrawal predicate and reverts `VaultDisabled(address(this))`, rolling the withdrawal back. This member did not execute, so this member does not claim the residual call is the call that produced the supplied revert. It is a source path on the tested function that produces that error. The supplied address is not identified with `seUT`.

### Gas figures

Coordinator-supplied. Not re-run. Not treated as proof of a product loop.

`test_row_index1` and `test_row_rateTarget_currency1` on target 1, and the same two names on the dual unwrap contract, are the only supplied figures above one billion gas. Both tests call `_configureDual(false)`. That calls `deploySibling`.

Observed unbounded searches in `SeMatrix_FullSpreadV4Fixture.sol`:

- lines 229-234, a name-salt loop until the predicted PairToken address sorts on the requested side of the face;
- lines 247-272, a CREATE2 salt loop until the sibling faces sort on that same side.

Those searches run before `_requireIdentity` `fail`s. They are fixture setup, not the composed swap measured by `coldSwap`. The other message-1 tests use the `setUp` configuration and fail at about 33k-38k supplied gas, which is consistent with failing at `_requireIdentity` without that second search. The dual unwrap copies of the two large figures are 69 and 96 above the target-1 figures. That is the same source path, not a second loop. This member does not convert those gas numbers into an iteration count.

### Plan and PRD sentences relied on

PRD:

- FS-HOOK-02 point 2, line 497: the other SE share may be an identity leg only if the current package accepts `token == se` without `asset()`. If it rejects, that bind is FS-HOOK-04, not a pass.
- FS-HOOK-04, lines 512-518: an `asset()` requirement is a separate requirement. Name the consumer, selector, arguments, and revert. Do not implement that change here. A cited reject does not close the canonical proof.
- FS-A24, line 573: attempt `token ==` this vault. If the package rejects it without `asset()`, record the reject under FS-HOOK-04 and do not pass. Do not add `asset()`.
- FS-A26, line 575: the FS-HOOK-02 fixture completes exact-input both directions on two backing keys.
- FS-A27, line 576: a cited reject does not replace FS-A26. The FS-OWN-29 rows are not closed by an FS-HOOK-04 record.
- FS-OWN-26, line 210, and FS-A38, line 587: a buffered withdrawal still succeeds. A non-withdrawal reverts `VaultDisabled`.
- Inventory 054, line 658: each required hook that unwraps this share must approve the vault and complete the exit.

Plan:

- Line 225: if the package rejects `token == se` without `asset()`, record consumer, selector, arguments, and revert under FS-HOOK-04. Do not pass that variant. Do not add `asset()`. Do not replace the leg with a raw token and call that row FS-A26.
- Lines 295-297: the dual row passes FS-A26 only when the identity record is accepted. If rejected, record FS-HOOK-04 and FS-A26 stays open. `test_row_identity_thisVault` is FS-A24, not the canonical proof.
- Lines 315, 329, 341, and 357: orbital, weighted three-leg, curve, and balancer five-leg record FS-HOOK-04 for the rejected leg and still run the raw-leg directions. That result does not close FS-A26.
- Lines 112-113 and 200: the disable predicate, and a buffered withdrawal still succeeds.
- Line 379: FS-A24 is the dual-row `test_row_identity_thisVault`.
- Line 439: audit 054 is the integration unwrap.

`IMPLEMENTATION_PLAN_BLOCKERS.md` was partially examined at B-08 and the already-locked list. Those sections keep `getRate` and `rateAsset` uninstalled and say the rate-provider rows are not an incompatible-hook record. They do not change the identity or disable sentences above. `docs/audits/apex-2026-09-17-evidence.md` was not examined.

## Assumptions

- The supplied messages are the Foundry failure strings for the named tests. They are not this member's run.
- A test absent from the supplied failure list is not a certified pass.
- `identityRevert` was not read from a trace. Error selectors named below are inferred from validation order and the bindings the tests construct.
- The PairToken diamond is both share and vault because `deploySibling` stores `deployVault`'s return as `share`.
- Foundry `fail()` and a failing `assertTrue` are non-passes. They are not, by themselves, product defects.
- The event wrapper around the `processArgs` argument does not erase the argument. It is noted and does not change the resolution class.

## Coverage

| Target | Status |
| --- | --- |
| 1. Dual matrix row | examined |
| 2. Orbital matrix row | examined |
| 3. Balancer five-leg matrix row | examined |
| 4. Curve matrix row | examined |
| 5. Weighted three-leg matrix row | examined |
| 6. BufferHookIntegration.t.sol | examined |
| 7. FullSpread PRD | examined |
| 8. Implementation and test plan | examined |
| IMPLEMENTATION_PLAN_BLOCKERS.md | partially examined |
| docs/audits/apex-2026-09-17-evidence.md | not examined |
| Production hook and vault sources named in Evidence | examined for the paths cited |
| Peer responses and coordinator/draft.md | not examined |

Every supplied failing test is named in Review findings. No required failing test is left uncovered.

## Conclusions

Four distinct failures. Three stay red. One is a required product outcome the current withdraw path does not meet.

1. Message 1 is the required FS-A26 non-pass. The package rejects `token == se` without the wrapper-share `asset()` path. The plan requires that reject to be recorded and not passed, and forbids adding `asset()`. The non-dual rows still have a raw-leg path, and the supplied list does not show those raw-leg tests failing. Do not install `getRate`. Do not turn these rows into passes.
2. Message 2 is the required FS-A24 non-pass. It is not the FS-A26 proof. Do not add `asset()`.
3. Message 3 is the same rejected bind blocking the dual unwrap. It is not a second product defect and not a correct FS-HOOK-04 record. Keep it red. Repair the record. Do not skip it into a pass.
4. Message 4 is not FS-HOOK-04. The admitted text already requires the buffered withdrawal to succeed. The tested hook withdraw has a later non-withdrawal vault call that the disable predicate rejects. The supplied address is unverified.

The extreme gas figures are the fixture address search on the index-1 PairToken configuration. They are not a product loop and do not change resolution 1.

This response does not authorize implementation.

## Review findings

### F1. PairToken identity bind remains a required FS-A26 non-pass

Location:

- Target 1, lines 336-360 and 354-360. Fail string at line 358.
- Target 2, lines 148-160. Fail string at line 158.
- Target 3, lines 22-31. Fail string at line 27. Bind catch in the parent balancer row, lines 129-145.
- Target 4, lines 172-181. Fail string at line 179.
- Target 5, lines 168-176. Fail string at line 174.
- Target 6 inherited executions of those same functions:
  - `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test`: the twelve target-1 names listed below.
  - `UniswapV4FullSpreadStandardExchangeVault_OrbitalUnwrap_Test.test_row_identity_pairToken`
  - `UniswapV4FullSpreadStandardExchangeVault_BalancerFiveUnwrap_Test.test_row_identity_pairToken`
  - `UniswapV4FullSpreadStandardExchangeVault_CurveUnwrap_Test.test_row_identity_pairToken`
  - `UniswapV4FullSpreadStandardExchangeVault_WeightedThreeUnwrap_Test.test_row_identity_pairToken`
- Gate: `UniswapV4SeBufferHookLegLib.sol` lines 174-197, and the five package validators cited in Evidence.
- Requirements: PRD lines 497, 512-518, 575-576. Plan lines 225, 295, 315, 329, 341, 357.

Tests in this finding, every supplied message-1 failure:

- `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` and `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test`: `test_composedRouteGasFitsCeiling`, `test_row_bind_deploysThroughPackage`, `test_row_bufferFirst_restingFace_notPaidToJoiner`, `test_row_hookSwap_exactIn_eoaPretransferRejected`, `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly`, `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed`, `test_row_index0`, `test_row_index1`, `test_row_partialConsumption_bookedNotRefunded`, `test_row_poolManagerSwap_bothDirections_noFaceResidual`, `test_row_previewMatchesExecution`, `test_row_rateTarget_currency1`.
- `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` and `UniswapV4FullSpreadStandardExchangeVault_OrbitalUnwrap_Test`: `test_row_identity_pairToken`.
- `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5` and `UniswapV4FullSpreadStandardExchangeVault_BalancerFiveUnwrap_Test`: `test_row_identity_pairToken`.
- `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` and `UniswapV4FullSpreadStandardExchangeVault_CurveUnwrap_Test`: `test_row_identity_pairToken`.
- `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3` and `UniswapV4FullSpreadStandardExchangeVault_WeightedThreeUnwrap_Test`: `test_row_identity_pairToken`.

Invariant or requirement: If the current package rejects `token == se` without `asset()`, record the consumer, selector, arguments, and revert under FS-HOOK-04 and do not pass. Do not add `asset()`. Do not replace the PairToken leg with a raw token and call that row FS-A26. FS-A26 stays open until the identity record itself runs. A cited reject does not close FS-OWN-29. On orbital, weighted three-leg, curve, and balancer five-leg, the raw-leg directions still run and do not close FS-A26.

Impact: Foundry FAIL is the required non-pass, not a FullSpread money defect and not a missing `getRate`. The dual canonical proof cannot run because `_bindDual` leaves `hook` at `address(0)`. The other families' identity tests stay red while their face/raw tests are not in the supplied failure list. `test_row_rateTarget_currency1` on the dual row fails at the identity gate after configuring the currency1 provider. That is not an FS-OWN-29 incompatibility record and does not close FS-OWN-29. The composed gas tests fail before `coldSwap`. They are not FS-A31 ceiling failures. The two billion-gas figures are the fixture search in `deploySibling` and `_sidedSiblingTokens`, observed at fixture lines 229-234 and 247-272, executed by `_configureDual(false)`. They are not a product loop.

Fix direction: no product-code change, because the admitted plan or PRD requires the row to remain a recorded non-pass. Do not add `asset()`. Do not install `getRate`. Do not rewrite a raw-leg result as FS-A26. The event already names consumer, outer selector, wrapped arguments, and revert. The extra `abi.encode` around the `processArgs` argument is recoverable and is not a reason to pass the row. The in-test `fail()` is what keeps FS-A26 open.

Evidence class: source observation for the gate, the bindings, the `fail()` sites, and the address-search loops. Inference for the unobserved revert selector. Coordinator-supplied runtime for the failure strings and gas figures.

### F2. This-vault identity bind remains a required FS-A24 non-pass

Location:

- Target 1, lines 429-441. Fail string at line 439.
- The same function inherited by `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_identity_thisVault`.
- Requirements: PRD line 573. Plan lines 297 and 379.

Invariant or requirement: Attempt `token ==` this vault. If the package rejects that bind without `asset()`, record consumer, selector, arguments, and revert under FS-HOOK-04. Do not pass. Do not add `asset()`. This test is FS-A24. It is not the canonical FS-A26 proof.

Impact: Foundry FAIL is the required FS-A24 non-pass. It does not close FS-A26 and it does not authorize an `asset()` installation on this vault. The test records the four fields in the catch before `fail`. The arguments field has the same one-wrapper encoding as F1. The test does not decode the revert, so the message does not by itself prove the selector. Validation order makes the this-vault membership miss the first failing check for the arguments this test builds. That selector claim is inference.

Fix direction: no product-code change, because the admitted plan or PRD requires the row to remain a recorded non-pass. Do not add `asset()`. Do not treat this failure as the FS-A26 proof or as a reason to pass F1.

Evidence class: source observation for the test and the validator order. Inference for the unobserved revert selector. Coordinator-supplied runtime for message 2.

### F3. Dual unwrap assertion cites FS-HOOK-04 without the required record

Location:

- Target 6, lines 236-247, `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_dualUnwrapApprovesAndCompletesExit`. Assertion at line 242.
- The identity state it reads is set by the inherited dual bind, target 1 lines 336-348.
- Requirements: PRD line 658. Plan lines 225, 295, and 439.

Invariant or requirement: Audit 054 requires each required unwrap hook to approve the vault and complete the exit. FS-HOOK-04, when cited, requires the consumer, selector, arguments, and revert, and requires the identity variant not to pass. FS-A26 is the dual row's canonical proof, not this assertion.

Impact: The assertion fails because `identityAccepted` is false, which is the F1 reject. It does not attempt the withdraw, so it does not show a missing approval. Its Foundry message is message 3. It does not name consumer, selector, arguments, or revert, and it omits the FS-A26 OPEN suffix used by the row that actually records that non-pass. A reader can mistake this for a completed FS-HOOK-04 record or for an unwrap that rejected the identity. It is neither. Turning it into a pass would require the identity bind the plan forbids this family to implement. Skipping it would hide the blocked unwrap.

Fix direction: a test-record change that preserves that required non-pass. Keep the test red. The failing record should name the same consumer, `processArgs` selector, identity arguments, and stored revert already captured by the dual bind, and it should say the unwrap was not executed. Do not add `asset()`. Do not skip the test. Do not treat this assertion as closing FS-A26 or as a substitute for F1. Do not change product code to make this assertion true.

Evidence class: source observation for the assertion and the `hook = address(0)` bind. Coordinator-supplied runtime for message 3. The connection to F1 is source observation of the shared `identityAccepted` flag, not a second product defect.

### F4. Disabled buffered withdrawal reverts VaultDisabled

Location:

- Target 6, lines 110-120, `UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test.test_disabledBufferedWithdrawalApprovesAndCompletesExit`.
- Vault predicate: `UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol` lines 39-40 and 134-141.
- Hook withdraw: `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet.sol` selector installation, `WithdrawTarget` withdraw at line 477, `Withdrawal.unwrapSeShares` at lines 80-91, `Withdrawal.refundPairDust` at lines 122-131, `ClaimLib.bufferQuotedResidual` at lines 389-394.
- Row binding: constant-product behavior lines 118-125, `pairToken` is `face`.
- Requirements: PRD line 210 and line 587. Plan lines 112-113, 200, and the section-13 assignment of FS-A38 and inventory 045 to this file.

Invariant or requirement: A disabled vault reverts `VaultDisabled(address(this))` on every execution route except a withdrawal, `donate`, and `compound`. A withdrawal is `exchangeIn` with the share as `tokenIn` and a face as `tokenOut`, or `exchangeBundleOut` with the share as `tokenIn` and the two faces as outputs. A pass-through and a deposit are not withdrawals. A buffered withdrawal still succeeds. A buffered non-withdrawal reverts. Views do not revert `VaultDisabled`.

Impact: The supplied test reverts with message 4 instead of completing the approval, share burn, and face payment it asserts. That is the buffered-withdrawal outcome the PRD and plan already require. It is not an FS-HOOK-04 identity failure. The constant-product row has no PairToken identity bind, and this test does not call `processArgs`. The supplied address was not found in source and is unverified. If the reverting contract is the FullSpread money target, the argument is `address(this)` of that vault. This member cannot confirm that equality.

The share-to-face `exchangeIn` in `unwrapSeShares` matches the withdrawal exception on the binding this row deploys. The later face-to-share `exchangeIn` in `refundPairDust` does not. It is a deposit. If that call runs, the vault reverts `VaultDisabled` and the withdrawal does not complete. That last sentence is inference about which call produced the supplied revert. The existence of that rejecting call on the tested withdraw is source observation.

Fix direction: a product-code change that the admitted plan or PRD already requires, cited to FS-OWN-26, FS-A38, plan section 6, and plan section 11: the buffered withdrawal still succeeds. Do not widen the exception to deposits, pass-throughs, or `exchangeOut`. Do not fold this failure into FS-HOOK-04. Do not add `asset()`. Do not install `getRate`. The address in the supplied revert stays unverified until a later reader identifies it from a trace or from deployment source. This finding does not choose a patch.

Evidence class: source observation for the predicate, the withdraw path, and the absence of an FS-HOOK-04 connection. Inference for which call on that path reverted. Coordinator-supplied runtime for message 4 and its gas figure. The address is unverified.

## Limits

- This member did not run Forge, project tests, installs, deploys, wallet operations, or git mutations.
- Revert selectors inside `identityRevert` were not observed. They are inferred from the validators and the arguments the tests build.
- `0x55A8BCB67Bc9F37B585A47f76552de0597D5c493` is unverified. No coordinator guess about it is adopted.
- Supplied gas figures are not this member's measurements. The large figures are explained by a source path. They are not an iteration count.
- Tests absent from the supplied failure list are not certified passes.
- `docs/audits/apex-2026-09-17-evidence.md` was not examined. The blockers file was only partially examined.
- Peer responses and `coordinator/draft.md` were not read.
- Public search was not used.
- This response is advice. It does not authorize implementation, a PRD edit, or a plan edit.
