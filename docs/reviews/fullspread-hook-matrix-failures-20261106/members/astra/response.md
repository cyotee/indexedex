## Identity

- Run ID: fullspread-hook-matrix-failures-20261106
- Member label: astra
- Profile: review
- Phase: initial independent response
- Owned path: `docs/reviews/fullspread-hook-matrix-failures-20261106/members/astra/response.md`
- Requested role: council-member
- Requested model and reasoning: chatgpt-subscription/gpt-6-astra:high
- Actual role: not exposed
- Actual model: not exposed
- Actual reasoning: not exposed
- Actual task ID: not exposed
- Actual session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Diagnose each distinct supplied failure in the FullSpread hook-matrix and buffer-integration tests and propose its smallest resolution, without implementation. The review distinguishes a required integration non-pass from a product defect and does not use the text of a failure message alone to make that distinction.

The following aliases denote the complete paths throughout this response:

| Alias | Required target |
| --- | --- |
| T1 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| T2 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| T3 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` |
| T4 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| T5 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` |
| T6 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol` |
| PRD | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` |
| Plan | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` |

## Evidence

**Source observation: governing requirements.**

- PRD:22 forbids installing `asset()` to make a rejected identity bind pass. PRD:55 and Plan:100 forbid installing `getRate` on this vault.
- PRD:510-518 separates family defects from intentional rejections and separate hook requirements. A cited rejection remains an unresolved integration record; it does not close the canonical cross-vault proof.
- Plan:223-225 specifies the actual PairToken identity record, its external provider, pre-acquired shares, and no PairToken money calls inside the outer unlock. If rejected, record consumer, selector, arguments, and revert; do not pass it, add `asset()`, substitute a raw leg as FS-A26, or substitute another FullSpread instance.
- Plan:295 explicitly keeps FS-A26 open on the dual identity rejection. Plan:297 and PRD:573 explicitly require the FullSpread identity attempt to remain a non-pass on rejection.
- PRD:210 and PRD:587 state: "A buffered withdrawal still succeeds." Plan:200 repeats that requirement. The same requirements retain the disable rejection for non-withdrawals. Plan:439 and PRD:658 require each unwrap hook to approve the vault and complete the exit.

**Source observation: identity classification.**

`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:171-195` accepts membership through `vaultTokens()`, or recognizes identity wrapper inventory through a successful `asset()` read returning a different nonzero underlying. It does not generally require `asset()` for a face-token bind. An identity share is not automatically a member of its own underlying-token list.

`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:203-253` constructs the sibling through the real PairToken package and acquires its shares before the hook transaction. Its underlying faces differ from the FullSpread faces. `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol:260-265` initializes the backing faces as vault tokens; its expected selector list at lines 360-469 contains no ERC-4626 `asset()` selector. `assetInfo` is a different selector.

The source validation sites are:

| Consumer | Entry selector | Rejecting source |
| --- | --- | --- |
| `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol` | `processArgs(bytes)` at 271-275 | `_validateArgs` at 374-388 checks each SE/token binding; `_requireTokenInVaultTokens` at 391-392 reverts `TokenNotInVaultTokens()` on failed membership. |
| `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol` | `processArgs(bytes)` at 235-239 | `_validateArgs` at 363-396 checks SE membership before token decimals; `_requireSeOwnsToken` at 408-410 reverts `InvalidSE()`. |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol` | `processArgs(bytes)` at 249-253 | `_validateArgs` at 373-447 checks sorted records, scales, providers, and membership; `_requireSeOwnsToken` at 450-451 reverts `InvalidSE()`. |
| `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol` | `processArgs(bytes)` at 237-241 | `_validateArgs` at 358-419 checks the four records; `_requireSeOwnsToken` at 422-423 reverts `InvalidSE()`. |
| `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol` | `processArgs(bytes)` at 237-241 | `_validateArgs` at 351-409 checks the dynamic records; `_requireSeOwnsToken` at 412-413 reverts `InvalidSE()`. |

These are source-derived rejection explanations, not decoded runtime traces. The brief supplies the outer assertion messages, not the captured inner revert bytes or deployed consumer addresses.

**Source observation: recording and inheritance.**

T1:117-119 defines the `FS_HOOK_04` record with consumer, `processArgs(bytes)` selector, ABI-encoded arguments, and caught revert. T1:321-358 records failed binding and deliberately fails the required identity gate. T2:85-95, T4:97-110, and T5:93-106 capture their rejected binding separately from their continuing raw-leg controls.

The corresponding five-leg capture is inherited from `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:95-145`. Its rejected record is emitted before the continuing control removes the sibling's SE binding. Those controls retain the actual share and its provider; they do not establish acceptance of the original identity record.

T6:240, 251, 271, 280, and 299 inherit the dual, orbital, weighted-three, Curve, and Balancer-five rows respectively. The repeated failures are inherited instances, not evidence of five additional production causes.

**Supplied runtime, not member execution.**

The brief supplies 36 failing contract/test instances: 32 with the PairToken/FS-A26 OPEN message, two with the FullSpread/FS-A24 OPEN message, one dual unwrap assertion without the OPEN suffix, and one `VaultDisabled` revert. No test execution, transaction receipt, or trace was produced by this review.

The extreme gas observations belong to the dual `test_row_index1` and `test_row_rateTarget_currency1`, including their inherited T6 copies. T1:404-426 rebuilds sibling configuration inside those test bodies. The fixture's `deploySibling` at lines 239-244 contains an unbounded address-selection loop; `_sidedSiblingTokens` at lines 256-284 contains another selection loop. PairToken's `calcSalt` at lines 205-206 hashes the complete package arguments, so changing the name is a real salt input. This is source evidence of fixture work on those paths. It is not a measurement of iteration counts or a proof that a particular loop accounts for the supplied gas total.

T1:511-520 places the required identity gate before the composed measurement. A failed gate provides no passing composed-route gas measurement. Do not replace the gas ceiling or diagnose a production swap loop from the test gas figures.

## Assumptions

- The supplied results are observations of the code family under review, but no source-to-runtime artifact fingerprint was provided. Static source attribution is not bytecode equivalence proof.
- The captured identity rejection must be preserved as its actual bytes. The source predicts `TokenNotInVaultTokens()` for dual and `InvalidSE()` for the other four packages on the rejected membership branch; the supplied assertion strings alone do not prove those exact inner errors.
- The exact address `0x55A8BCB67Bc9F37B585A47f76552de0597D5c493` is unverified. T6:97 disables `seUT`, and the inferred failing call targets that same bound FullSpread vault, but the admitted supplied output does not include the address mapping needed to equate the literal with `seUT`.
- Dated owner locks and the required PRD/Plan control this review. Prior reports and historical compatibility labels are not requirements or passing evidence.

## Coverage

| Target | Status | Scope checked |
| --- | --- | --- |
| T1 | examined | Entire file, both identity rejection sites, every supplied failing test body, and source of fixture rebuilding. |
| T2 | examined | Entire file, identity capture, deliberate failure, and separation of raw-leg controls. |
| T3 | examined | Entire file and relevant inherited five-leg setup/capture in its two-leg parent. |
| T4 | examined | Entire file, sorted identity record, rejection capture, and continuing raw controls. |
| T5 | examined | Entire file, three-leg identity record, rejection capture, and continuing raw controls. |
| T6 | examined | Entire file, inherited failure instances, direct dual unwrap assertion, and disabled withdrawal path. |
| PRD | examined | Entire document, including owner locks, FS-HOOK-04, FS-A24/26/38, and unwrap inventory row 054. |
| Plan | examined | Entire document, including exact rejection-record instructions and disable/unwrap obligations. |

Relevant production and test context was read only to explain these failures: the shared leg classifier, five package validators, PairToken package surface and initialization, FullSpread fixture and money target, constant-product row/setup, withdrawal facet/target/library, claim-library residual helpers, and tuple helper. These contextual reads were targeted, not a whole-repository audit.

The optional `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md` and `docs/audits/apex-2026-09-17-evidence.md` were supplied as optional context and were **not examined**. The required PRD and Plan provide the governing sentences used here.

Failure accounting:

| Finding | Supplied instances | Disposition |
| --- | ---: | --- |
| F1 | 1 | Required buffered-withdrawal behavior is blocked by a separate non-withdrawal side effect. |
| F2 | 32 | PairToken identity rejection; retain required non-passes and open FS-A26. |
| F3 | 2 | FullSpread identity rejection; retain required non-passes and open FS-A24. |
| F4 | 1 | Dual unwrap is blocked before execution by the same required identity gate. |
| Total | 36 | Every supplied failing instance assigned. |

## Conclusions

Only the disabled buffered withdrawal has a product-code correction supported by the requirements read in this pass. The source shows a permitted share redemption followed by residual handling that can attempt a forbidden deposit into the disabled vault. This is separate from the identity-binding failures.

The three identity-related messages do not authorize changing package membership, installing `asset()` or `getRate`, substituting a raw leg as the canonical proof, or greening FS-A24/FS-A26. The deliberate failures agree with the Plan's explicit non-pass instructions. Their downstream positive assertions, including the dual unwrap and composed gas proof, remain unexecuted or unproven.

The smallest resolutions are the four dispositions below. No new owner product decision is needed to preserve the identity non-passes or require the disabled withdrawal to complete. Making the rejected identity topology supported would require a separate product change; this response does not select or authorize one.

## Review findings

**F1 - High: post-withdrawal residual reinvestment can veto an otherwise permitted disabled-vault exit.**

- **Affected test:** T6, `UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test.test_disabledBufferedWithdrawalApprovesAndCompletesExit`.
- **Location:** T6:93-101 disables the underlying `seUT` after seeding and calls the hook's proportional `withdraw`. T6:43-54 propagates the hook revert before the approval/burn/payment assertions. The production route is installed by `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/facets/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet.sol:17-20,31-34`. Its implementation is `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol:507-537`, with the residual wrapper at 338-340.
- **Invariant or requirement:** PRD:210, PRD:587, and Plan:200 require a buffered withdrawal to succeed while disabled. They simultaneously require a deposit/non-withdrawal to remain rejected. Plan:439 and PRD:658 require the approval and completed exit, not merely a successful quote.
- **Source observation:** `_withdraw` obtains the pro-rata claims, burns LP, unwraps SE shares, transfers outputs, updates reserves and fee state, then calls `_refundPairDust`. `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol:80-89` approves and calls canonical share-in/face-out `exchangeIn`; the FullSpread guard at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol:36-46,136-149` permits that withdrawal.
- **Source observation:** Despite its name, `refundPairDust` at WithdrawalLib:126-136 tries to reinvest residual face tokens when its preview is positive. `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:379-394` obtains that preview and calls face-in/share-out execution. `contracts/utils/ExchangeInAmount.sol:17-29` confirms that its helper named `exchangeOut` actually invokes canonical `exchangeIn`. This is a deposit, not the vault's unsupported exact-output selector. The FullSpread disable predicate correctly rejects it.
- **Impact:** A late, incidental deposit can revert the entire hook withdrawal, undoing the preceding burn and payouts. This is withdrawal unavailability through the hook, not evidence that the vault burned shares and paid nothing, and not evidence of a missing approval. Direct share-in redemption has the specified disable exception.
- **Fix direction:** **Product-code change already required by the PRD/Plan.** Make the proportional-withdrawal cleanup refrain from residual reinvestment into a disabled underlying SE. Keep the actual approval, share redemption, recipient payout, minima, and disabled deposit rejection. The narrow correction belongs at the withdrawal's residual-maintenance boundary, not in FullSpread's disable predicate. Preserve the residual's existing hook ownership; do not refund another holder's residue to the exiting caller, introduce new valuation economics, or swallow arbitrary downstream failures. Keep this test as a positive completed-exit assertion, rather than changing it to expect `VaultDisabled`. Subsequent authorized verification must establish that no face-in/share-out maintenance call is made on this disabled exit and that the existing disabled-mint negative still holds.
- **Evidence class:** Source observation for the full call chain and guard; supplied runtime for the reported revert; inference for attributing this particular supplied execution to the residual branch. The branch is a concrete reachable explanation, but no supplied trace identifies the precise revert frame or the literal address.

**F2 - Required non-pass: rejected PairToken identity binding fans out into 32 supplied failures.**

- **Location:** T1:321-359 and its failing callers at 362-418,421-427,444-482,496,511-520; T2:68-95,155-163; T3:19-37 and its parent binding at lines 95-145 cited in Evidence; T4:78-110,176-184; T5:61-106,171-179. The package validation sites are enumerated in Evidence.
- **Invariant or requirement:** Plan:223-225 requires a real PairToken identity record, not an interchangeable raw token. Plan:295 requires FS-A26 to remain open if that record is rejected. Plan:315,329,341,357 permits separate raw-direction coverage while retaining the rejected identity record. PRD:497 and PRD:516-518 impose the same distinction.
- **Affected tests, dual group:** Each of the following occurs both in T1's `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` and in T6's `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test`, for 24 supplied instances:
  - `test_composedRouteGasFitsCeiling`
  - `test_row_bind_deploysThroughPackage`
  - `test_row_bufferFirst_restingFace_notPaidToJoiner`
  - `test_row_hookSwap_exactIn_eoaPretransferRejected`
  - `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly`
  - `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed`
  - `test_row_index0`
  - `test_row_index1`
  - `test_row_partialConsumption_bookedNotRefunded`
  - `test_row_poolManagerSwap_bothDirections_noFaceResidual`
  - `test_row_previewMatchesExecution`
  - `test_row_rateTarget_currency1`
- **Affected tests, other topologies:** `test_row_identity_pairToken` in each of the following eight contract/file instances:
  - T2: `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault`.
  - T3: `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5`.
  - T4: `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault`.
  - T5: `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3`.
  - T6: `UniswapV4FullSpreadStandardExchangeVault_OrbitalUnwrap_Test`.
  - T6: `UniswapV4FullSpreadStandardExchangeVault_BalancerFiveUnwrap_Test`.
  - T6: `UniswapV4FullSpreadStandardExchangeVault_CurveUnwrap_Test`.
  - T6: `UniswapV4FullSpreadStandardExchangeVault_WeightedThreeUnwrap_Test`.
- **Source observation:** Dual binds FullSpread's face as its converting leg and the PairToken diamond as both the second SE and second token, with their respective configured providers. The other four topologies use the same identity relation in their own records. Shared membership validation does not accept the PairToken share as an underlying and does not recognize it as an `asset()` wrapper. The catch stores the failed acceptance state and the recorded rejection. The listed failures explicitly require that state to be accepted before claiming the identity-dependent proof.
- **Impact:** The canonical cross-vault proof is still open. The 24 dual failures do not independently establish defects in refunds, exact-output handling, previews, index placement, or gas; those assertions are downstream of the rejected prerequisite. The eight identity-specific failures similarly do not invalidate independent raw-leg controls, but neither can those controls close FS-A26. A failed exact-output test at this gate is not proof that its intended fail-closed execution assertion ran.
- **Fix direction:** **No product-code change, because the admitted Plan/PRD requires the row to remain a recorded non-pass.** Preserve the identity attempt, its captured consumer/selector/complete arguments/revert, and the failing acceptance result. Keep FS-A26 open and retain raw controls only under their own topology claims. Carry the captured rejection into the evidence record; do not replace it with the assertion string or fabricate inner revert bytes. No addition of `asset()`, identity-membership shortcut, new vault provider, or substituted FullSpread/raw leg is justified by these failures.
- **Evidence class:** Source observation for the constructed records, classifier, catch/fail control flow, and inheritance; supplied runtime for the 32 failure reports; inference for the exact inner membership error in each supplied run. The extreme gas values remain fixture-inclusive supplied observations, not passing route measurements or proven production liveness defects.

**F3 - Required non-pass: FullSpread's own identity attempt correctly leaves FS-A24 open.**

- **Affected tests:** T1, `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_identity_thisVault`; and T6, `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_identity_thisVault`.
- **Location:** T1:429-440 changes package leg 0 to `standardExchange0 == token0 == seUT`, retains the PairToken leg and configured providers, calls `processArgs(bytes)`, records caught rejection, and deliberately fails with FS-A24 OPEN. T6:240 inherits it. Dual package validation checks leg 0 before leg 1 at `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:384-392`.
- **Invariant or requirement:** Plan:297 says: "If the package rejects that bind without `asset()`, record the consumer, selector, arguments, and revert under FS-HOOK-04. Do not pass. Do not add `asset()`." PRD:573 states that this row does not pass on rejection. PRD:22 and PRD:283 exclude greening it by adding `asset()` or editing the hook.
- **Impact:** This is the specified FullSpread identity limitation, separately identified from the PairToken FS-A26 fixture. It is not a failure of the accepted FullSpread face-to-share route. The dual validator reaches the FullSpread identity membership check first; the rejected PairToken second leg is not needed to explain this source branch.
- **Fix direction:** **No product-code change, because the admitted Plan/PRD requires the row to remain a recorded non-pass.** Retain the actual attempted record and rejection as FS-A24 OPEN. Do not rewrite this test as a passing negative acceptance row and do not fold it into FS-A26.
- **Evidence class:** Source observation for the attempted arguments, validation order, and deliberate failure; supplied runtime for the two messages; inference for the exact runtime membership revert until the recorded inner bytes are supplied.

**F4 - Required non-pass: the dual unwrap fails its identity prerequisite, before approval or withdrawal execution.**

- **Affected test:** T6, `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_dualUnwrapApprovesAndCompletesExit`.
- **Location:** T6:239-247 asserts `identityAccepted` at line 242 before `_seed()` or `_assertHookExit`. Its inherited setup is T1:295-352, which records the binding rejection and sets `hook` to zero instead of deploying the rejected configuration.
- **Invariant or requirement:** Plan:225 and Plan:295 keep the rejected identity configuration unpassed. Plan:439 and PRD:658 still require a real approved, completed unwrap; an assertion failure before the call does not satisfy that requirement.
- **Impact:** The supplied message without the FS-A26 suffix is another presentation of the same binding prerequisite, not a separate production unwrap failure. No runtime evidence from this test reaches the approval, burn, or recipient payment. In particular, this does not justify an allowance patch and does not explain the unrelated constant-product `VaultDisabled` failure in F1.
- **Fix direction:** **No product-code change, because the admitted Plan/PRD requires the row to remain a recorded non-pass.** Retain the unwrap obligation and report it as blocked by the captured PairToken identity rejection, with FS-A26 still open. Link its evidence to the inherited `FS_HOOK_04` record rather than treating the shorter assertion text as a new root cause. Do not skip the assertion, return success on a rejected bind, or remove the unwrap requirement.
- **Evidence class:** Source observation for ordering and inheritance; supplied runtime for this assertion failure. No unwrap execution or missing-approval diagnosis is established.

## Limits

This is one initial independent response, not coordinator synthesis, a peer vote, an implementation, or implementation authorization.

No peers, coordinator draft, feedback, or prior council reports were read. No project tests, Forge commands, installs, deployments, wallet operations, Git operations, credential inspection, or public source submission were performed. Public queries: not used.

The Solidity language-server definition request timed out. Relevant symbols were instead traced through imports, content searches, and direct source reads. Incorrect guessed context filenames were not treated as examined; the actual `DFPkg.sol` and `facets/...WithdrawFacet.sol` paths were subsequently located and read.

The runtime address mapping, exact captured identity revert bytes, and disabled-withdrawal call trace remain unverified. No numeric gas attribution, passing acceptance claim, whole-repository safety claim, or proof about same-backing-pool sequential composition is made.

Only the owned response file is written by this pass. No project code, tests, configuration, requirements, or other council artifact is changed.
