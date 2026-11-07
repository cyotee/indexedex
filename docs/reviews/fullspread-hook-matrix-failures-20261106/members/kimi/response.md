## Identity

- Run ID: fullspread-hook-matrix-failures-20261106
- Member label: kimi
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/fullspread-hook-matrix-failures-20261106/members/kimi/response.md
- Requested role: council-member
- Requested model and reasoning: kimi-coding/k3.1-pro:high, global route
- Actual role: not exposed
- Actual model: not exposed
- Actual reasoning: not exposed
- Actual task ID: not exposed
- Actual session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Question: diagnose each distinct failure in the coordinator-supplied Foundry results for the Uniswap V4 FullSpread Standard Exchange hook-matrix and buffer-integration tests, and propose the smallest resolution for each without implementing it.

Required targets, named as T1 through T8 below:

- T1: test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
- T2: test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
- T3: test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol
- T4: test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
- T5: test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol
- T6: test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol
- T7: contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md
- T8: contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md

## Evidence

Source observations:

1. T1 lines 355-358 implement `_requireIdentity()` by emitting the captured identity revert and calling `fail("FS-HOOK-04: required PairToken identity rejected; FS-A26 OPEN")` when `identityAccepted` is false. The twelve supplied dual failures other than `test_row_identity_thisVault` all reach this guard directly or through `_crossVaultDirections()`.
2. T2 line 158, T3 line 27, T4 line 179, and T5 line 174 each contain the same explicit failure in `test_row_identity_pairToken` when the identity bind was rejected. Their setup code retains raw-leg or transfer-only controls without representing those controls as FS-A26 passes.
3. T1 lines 429-439 implement FS-A24 separately: the test attempts `token0 == seUT`, records the caught `processArgs` revert, and deliberately fails with `FS-A24 OPEN`.
4. T6 line 242 uses `assertTrue(identityAccepted, "FS-HOOK-04: required PairToken identity rejected")` in `test_dualUnwrapApprovesAndCompletesExit`. It therefore records the same rejected identity but omits the explicit FS-A26-open suffix used by the matrix guard.
5. The shared consumer logic in contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol lines 174-196 accepts an identity `pair == se` through wrapper-share inventory only when the `asset()` probe succeeds and returns a distinct nonzero underlying; otherwise the pair must occur in `vaultTokens()`. T7 line 22 expressly forbids installing `asset()` to turn this rejected bind into a pass. The supplied messages do not include the underlying `processArgs` revert data, so this review does not assign a specific revert selector to the identity rejection.
6. T8 line 225 says that a rejected PairToken identity bind must record consumer, selector, arguments, and revert under FS-HOOK-04, must not pass, and must not add `asset()`. T8 line 295 says the dual row passes FS-A26 only when the identity record is accepted and executes without a PairToken money call; rejection leaves FS-A26 open. T8 lines 315, 329, 341, and 357 require the other topologies to retain their raw-leg directions without closing FS-A26.
7. T8 line 297 and T7 line 573 make this-vault identity rejection the separate FS-A24 record, not the canonical FS-A26 proof.
8. T6 lines 94-101 disable `seUT` and require a real hook withdrawal to approve and complete exit. The vault predicate in contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol lines 39-40 correctly treats share-in/face-out as a withdrawal, and line 139 is the source of `VaultDisabled(address(this))` for a disallowed route.
9. The constant-product withdrawal does not stop after that allowed unwrap. contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol lines 523 and 536 unwrap and then call `_refundPairDust`. That reaches UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol lines 126-136, which calls `ClaimLib.bufferQuotedResidual`; UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol lines 389-392 then executes pair-token-to-SE `exchangeIn`. That later call is a non-withdrawal and is required to revert while disabled. This is a source-derived explanation for the supplied disabled-withdrawal failure, not a traced frame.
10. T7 line 210 (FS-OWN-26), T7 line 587 (FS-A38), and T8 line 200 require a buffered withdrawal to succeed while a buffered non-withdrawal reverts `VaultDisabled`.

Runtime evidence is entirely coordinator-supplied. This member did not execute Forge or obtain a trace. The supplied set contains 36 failing tests: 32 with the FS-A26-open message, two with the FS-A24-open message, one dual-unwrap identity assertion without the suffix, and one disabled-withdrawal `VaultDisabled` revert.

## Assumptions

- The supplied runtime is assumed to correspond to the admitted source tree; no run identifier or trace was supplied to prove that correspondence.
- A deliberate `fail()` is classified by the assertion and the plan row it records, not by Foundry's red status alone.
- The exact address encoded in the supplied `VaultDisabled` data is not assumed to be a named deployment. Source shows that only `seUT` is disabled in the test and that the vault error carries `address(this)`, but the concrete address mapping is not independently verified.
- The extreme supplied gas values are treated as runtime observations only. They are not evidence of a loop or of a separate product defect without a source path and trace establishing that conclusion.

## Coverage

| Target | Status | Scope examined |
| --- | --- | --- |
| T1 | examined | Full dual matrix row, identity guards, all twelve FS-A26-gated supplied failures, and FS-A24. |
| T2 | examined | Full orbital row, identity-only failure, rejected-bind fallback, and raw-leg controls. |
| T3 | examined | Full Balancer five-leg row and its identity-only failure. |
| T4 | examined | Full Curve four-leg row and its identity-only failure. |
| T5 | examined | Full weighted three-leg row and its identity-only failure. |
| T6 | examined | Full buffer-integration file, inherited matrix rows, dual unwrap assertion, and disabled-withdrawal test. |
| T7 | examined | Full PRD, including FS-HOOK-02, FS-HOOK-04, FS-OWN-26, FS-A24, FS-A26, FS-A27, and FS-A38. |
| T8 | examined | Full implementation-and-test plan, including hook row rules, disable behavior, and acceptance mapping. |

Every supplied failing test is assigned to a finding below. Supporting production and fixture files cited in Evidence were examined only as needed to explain the required failures.

## Conclusions

1. The 32 FS-A26-open failures are deliberate records of a rejected PairToken identity bind. The plan requires those rows to remain non-passing; they do not establish a FullSpread product defect and do not authorize `asset()`, `getRate`, or a raw-token substitute.
2. The two FS-A24-open failures are a separate, deliberate this-vault identity record. They also require no product-code change.
3. `test_dualUnwrapApprovesAndCompletesExit` is the same required FS-A26 non-pass, but its bare assertion gives a less explicit record than the shared matrix guard. A small test-record change can align it without making the row pass.
4. `test_disabledBufferedWithdrawalApprovesAndCompletesExit` is independent of FS-HOOK-04. The allowed share-to-face unwrap is followed by hook cleanup that attempts a forbidden face-to-share deposit while disabled. The smallest compliant direction is to prevent that post-withdrawal rebuffer on the disabled path, preserving the vault's disable predicate.
5. No open product decision is needed for the supplied failures.

## Review findings

### Finding 1 — Dual FS-A26 identity rejection is a required recorded non-pass

- Location: T1 lines 355-358 and the twelve callers listed below; T6 `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test`, which inherits the same rows; T8 lines 225 and 295.
- Invariant or requirement: FS-A26 passes only when the PairToken identity record is accepted and executes both exact-input directions without a PairToken money call on disjoint backing PoolKeys. If the bind is rejected, the row records FS-HOOK-04 and FS-A26 stays open.
- Impact: The canonical cross-vault proof remains unresolved. The following twelve tests are deliberate non-passes in both `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` (T1) and `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` (T6), for 24 supplied failures total: `test_composedRouteGasFitsCeiling`, `test_row_bind_deploysThroughPackage`, `test_row_bufferFirst_restingFace_notPaidToJoiner`, `test_row_hookSwap_exactIn_eoaPretransferRejected`, `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly`, `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed`, `test_row_index0`, `test_row_index1`, `test_row_partialConsumption_bookedNotRefunded`, `test_row_poolManagerSwap_bothDirections_noFaceResidual`, `test_row_previewMatchesExecution`, and `test_row_rateTarget_currency1`.
- Fix direction: No product-code change, because the admitted plan requires the row to remain a recorded non-pass. Preserve the captured consumer/selector/arguments/revert record and the FS-A26-open failure. Do not add `asset()`, install `getRate`, or relabel a raw-leg control as the canonical proof.
- Evidence class: Source inspection for the explicit guard and plan requirement; supplied runtime for the failures and gas figures. No member execution.

### Finding 2 — Non-dual PairToken identity rows correctly remain open while raw controls continue

- Location: T2 line 158, T3 line 27, T4 line 179, T5 line 174, and their inherited rows in T6; T8 lines 315, 329, 341, and 357.
- Invariant or requirement: Each topology records FS-HOOK-04 when its PairToken identity leg is rejected and still runs the required face/raw directions. Those controls do not close FS-A26.
- Impact: Eight supplied failures are deliberate identity records, not evidence that the raw-leg controls failed: `test_row_identity_pairToken` in T2's `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault`; T3's `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5`; T4's `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault`; T5's `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3`; and T6's `UniswapV4FullSpreadStandardExchangeVault_OrbitalUnwrap_Test`, `UniswapV4FullSpreadStandardExchangeVault_BalancerFiveUnwrap_Test`, `UniswapV4FullSpreadStandardExchangeVault_CurveUnwrap_Test`, and `UniswapV4FullSpreadStandardExchangeVault_WeightedThreeUnwrap_Test`.
- Fix direction: No product-code change, because the admitted plan requires these identity rows to remain recorded non-passes. Keep the identity failures and the independent raw controls; do not convert the controls into FS-A26 passes or change the vault interface to force acceptance.
- Evidence class: Source inspection for the explicit failures and fallback controls; supplied runtime for each red row. No member execution.

### Finding 3 — FS-A24 this-vault identity rejection is separate and intentional

- Location: T1 lines 429-439; the inherited `test_row_identity_thisVault` in T6's `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test`; T8 line 297; T7 line 573.
- Invariant or requirement: Attempt `token == this vault` on one dual leg. If the package rejects it without `asset()`, record the consumer, selector, arguments, and revert under FS-HOOK-04 and do not pass. FS-A24 is not FS-A26.
- Impact: Two supplied failures, one in T1 and one inherited in T6, record the this-vault integration limitation. They do not diagnose the PairToken row and do not justify a vault interface addition.
- Fix direction: No product-code change, because the admitted PRD and plan require this row to remain a recorded non-pass. Preserve the separate FS-A24-open record and do not add `asset()`.
- Evidence class: Source inspection for the try/catch, event record, and deliberate failure; supplied runtime for both failures. No member execution.

### Finding 4 — Dual unwrap uses a less explicit FS-A26 test record

- Location: T6 lines 241-247, especially line 242; compare T1 lines 355-358 and T8 line 225.
- Invariant or requirement: The rejected PairToken identity bind must remain an FS-HOOK-04 record with FS-A26 open, including the captured revert evidence. It must not become a passing unwrap.
- Impact: `test_dualUnwrapApprovesAndCompletesExit` fails before `_seed()` as required, but its bare `assertTrue` message omits the FS-A26-open marker and does not reuse the matrix guard's explicit log/fail path. Setup has already captured the `FS_HOOK_04` event, so the defect is record clarity, not a missing non-pass.
- Fix direction: Test-record change that preserves the required non-pass: route the rejected case through the same explicit identity-record guard used by the dual matrix, including the FS-A26-open message, and retain the existing unwrap assertions only for an accepted identity. No product-code change.
- Evidence class: Source inspection for the assertion and shared guard; supplied runtime for message 3. No member execution.

### Finding 5 — Disabled buffered withdrawal reaches a forbidden post-exit rebuffer

- Location: T6 lines 94-101; UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol lines 39-40 and 136-140; UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol lines 523 and 536; UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol lines 80-89 and 126-136; UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol lines 389-392; T7 lines 210 and 587; T8 line 200.
- Invariant or requirement: FS-OWN-26 and FS-A38 permit share-in/underlying-out withdrawal while disabled, require every non-withdrawal execution route to revert `VaultDisabled`, and expressly require a buffered withdrawal to succeed.
- Impact: `test_disabledBufferedWithdrawalApprovesAndCompletesExit` cannot complete the required exit. Source shows that the allowed unwrap is followed by residual pair-to-SE buffering, which is a separate non-withdrawal call and triggers the same disable guard; the outer withdrawal therefore reverts. This is not an FS-HOOK-04 identity failure.
- Fix direction: Product-code change that the admitted PRD and plan already require, cited to T7 FS-A38's sentence “A buffered withdrawal still succeeds” and T8 line 200's identical requirement. In the constant-product hook's withdrawal cleanup, skip residual pair-to-SE rebuffering when the bound vault is disabled, leaving the residual local while preserving normal enabled-vault cleanup. Keep the vault's share-to-face withdrawal allowance and its rejection of the standalone pair-to-share route; do not weaken `_disable` to admit that non-withdrawal.
- Evidence class: Supplied runtime for `VaultDisabled`; source inspection for the withdrawal and rebuffer path; source-derived inference for the exact failing call because no trace was supplied. The concrete supplied revert address is unverified.

## Limits

- No Forge run, project test, trace, deployment, install, wallet operation, or Git mutation was performed. All failure text and gas figures are coordinator-supplied runtime, not member execution.
- The exact underlying `processArgs` revert data and the exact frame that produced `VaultDisabled` were not supplied. The identity selector is therefore not guessed, and the disabled-withdrawal root cause is labeled as source-derived inference.
- The supplied extreme gas values for `test_row_index1` and `test_row_rateTarget_currency1` do not establish a loop or another distinct failure. Both tests contain snapshot/reconfiguration work before the same identity guard, but no runtime explanation for those gas figures is claimed.
- Public queries: not used.
- Peer responses and coordinator/draft.md were not read. This response proposes resolutions only and does not authorize implementation.
