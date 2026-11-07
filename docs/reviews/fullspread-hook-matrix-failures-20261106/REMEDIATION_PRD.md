# FullSpread hook-matrix failures: diagnosis and proposed resolutions

## Result

**36 failing instances reduce to two mechanisms: 35 rejected identity prerequisites and one disabled buffered-exit defect.** This is a full four-member review council, not implementation authorization. The current requirements deliberately leave the rejected identity configurations non-passing; making those 35 tests green requires separately scoped integration work, not suppressing the failures.

Run: `fullspread-hook-matrix-failures-20261106`. The original request was to diagnose the supplied failures and propose resolutions. No project code, tests, configuration, PRD, plan, or existing audit artifact was changed. No reviewed-project tests were run.

## Findings and resolutions

### R1. Disabled withdrawal is followed by a prohibited deposit

**Location.** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol:94-101` disables the underlying vault and requires a real hook exit. The constant-product single hook's `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol:507-537`, under `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`, performs redemption and payouts, then invokes residual cleanup.

In that same directory, `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol:126-136` buffers residual pair tokens when the balance exceeds dust and the preview is positive. `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:379-394` then spends face tokens for SE shares: a deposit, not a withdrawal.

**Requirement.** FS-OWN-26 and FS-A38 in the FullSpread PRD require buffered withdrawals to succeed while non-withdrawals remain blocked. The implementation-and-test plan repeats this in section 11. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol:39-40,136-140` correctly permits share-in/face-out and rejects the later face-in/share-out call while disabled.

**Impact.** Cleanup can veto the entire withdrawal. Atomic reversion undoes earlier burns and payments; the evidence does not show a completed burn without payment.

**Proposed resolution.** Make the hook's withdrawal residual-maintenance path avoid reinvesting into a disabled underlying SE. Keep the vault guard, approval, actual redemption, recipient payout, and minima intact. Preserve residual ownership as hook inventory, not an extra payout to the exiting caller. Do not swallow arbitrary failures or introduce new valuation rules. Implementation must verify that retained inventory remains accounted for and available to remaining holders, and that enabled cleanup still works.

**Evidence class.** Source observation for the call chain; supplied runtime for the failure; inference for attribution of this particular revert to the cleanup call. No supplied trace identifies the exact failing frame. The literal address `0x55A8BCB67Bc9F37B585A47f76552de0597D5c493` remains unverified.

**Dissent.** None on the behavior. MiniMax initially described change ownership as an open product decision, then accepted that the specified outcome makes the edit boundary an engineering matter. Implementation still requires a separate instruction.

### R2. PairToken identity rejection blocks 32 tests before their intended assertions

**Location.** `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:174-195` accepts a leg through `vaultTokens()` membership or identity-wrapper recognition. Wrapper recognition requires a successful `asset()` probe returning a distinct nonzero underlying. These vaults expose backing faces, not their own shares, in `vaultTokens()` and do not expose that wrapper surface.

The dual matrix's `_requireIdentity` at lines 355-358 deliberately fails after rejected package binding. The corresponding orbital, Balancer five-leg, Curve, and weighted N3 identity assertions fail at lines 158, 27, 179, and 174 of their required files. Inherited buffer-suite copies reproduce those prerequisites; they are not additional independent production causes.

**Requirement.** FullSpread PRD FS-HOOK-02/04 and FS-A26/27, and plan lines 223-225 and 295, explicitly require a rejected identity bind to remain a recorded non-pass. They forbid adding `asset()` or substituting a raw leg to claim the canonical proof.

**Proposed resolution.** Preserve the rejected binds and their actual consumer, selector, arguments, and revert bytes. Keep FS-A26 open. Retain separate face/raw controls, but do not claim that they satisfy the cross-vault proof. Do not install `getRate`, bypass membership, skip tests, or weaken assertions.

The record should name the leg under test: the PairToken identity leg for FS-A26. Preserve provider obligations under FS-OWN-29 and the composed-gas obligation as unproved where their prerequisites fail.

**Evidence class.** Static source and supplied failure messages. Package-specific inner error selectors are source predictions, not observed runtime bytes.

**Dissent.** None on preserving non-passes. This is an unresolved support limitation, not evidence that every downstream swap/refund/preview behavior is defective. Supporting this identity configuration requires a separately scoped hook requirement; this report does not select a new recognition contract.

### R3. Two this-vault identity failures are FS-A24, not FS-A26

**Location.** The dual matrix's `test_row_identity_thisVault`, lines 429-439, attempts leg 0 with `token == se == this FullSpread vault`; the DualUnwrap contract inherits it.

**Requirement and resolution.** PRD FS-A24 and plan line 297 require a rejected attempt to remain non-passing without adding `asset()`. Preserve this distinct record. Name leg 0 and document that the validator checks it before the PairToken leg. This explains attribution in source; the revert payload alone does not identify the leg. Do not merge this requirement into FS-A26.

**Evidence class.** Source inspection plus supplied runtime. **Dissent:** none.

### R4. The additional dual unwrap never reaches withdrawal

**Location.** `BufferHookIntegration.t.sol:240-247` asserts `identityAccepted` before seeding or executing `test_dualUnwrapApprovesAndCompletesExit`.

**Impact and resolution.** The shorter error message denotes the same rejected prerequisite, not a missing approval or a second withdrawal defect. Keep the test red and explicitly link its result to the inherited setup's rejection record, stating that unwrap execution was not reached.

Setup already records the rejection; evidence is not wholly absent. Aligning the assertion message or reusing the identity guard is optional diagnostic maintenance. Per-instance contract/requirement linkage should remain explicit regardless. The dual event helper at lines 117-119 wraps the argument bytes once with `abi.encode(args_)`; preserve or document that decoding rather than inventing revert data.

**Evidence class.** Source control flow and supplied runtime. **Dissent resolved:** Grok's “missing record” wording is narrowed to per-test linkage, consistent with inherited evidence observed by Astra, Kimi, and MiniMax.

## Coverage and accounting

The complete target paths are numbered T1-T8 in `brief.md` and repeated in member originals. The reviewed targets are:

| Target | Coverage |
| --- | --- |
| T1: dual `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Examined, all supplied failing bodies and guards |
| T2: orbital `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Examined, identity and raw controls |
| T3: Balancer quad `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` | Examined, including relevant inherited setup |
| T4: Curve quad `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Examined |
| T5: weighted `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` | Examined |
| T6: FullSpread `BufferHookIntegration.t.sol` | Examined, direct and inherited failures |
| T7: FullSpread `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | Examined by council; MiniMax's individual reading was partial |
| T8: FullSpread `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` | Examined by council; MiniMax's individual reading was partial |

Production dependencies were examined only to explain these failures. The coordinator checked the principal classifier, guard, cleanup chain, requirement rows, and disputed diagnostic locations. Optional blockers/audit context received partial member coverage, not a coordinator audit.

| Supplied instances | Count | Resolution |
| --- | ---: | --- |
| Twelve dual identity-gated tests, each in T1 and inherited DualUnwrap | 24 | R2 |
| `test_row_identity_pairToken` in T2-T5 and OrbitalUnwrap, BalancerFiveUnwrap, CurveUnwrap, WeightedThreeUnwrap | 8 | R2 |
| `test_row_identity_thisVault` in T1 and DualUnwrap | 2 | R3 |
| `test_dualUnwrapApprovesAndCompletesExit` in DualUnwrap | 1 | R4 |
| `test_disabledBufferedWithdrawalApprovesAndCompletesExit` in BufferHookIntegration_Test | 1 | R1 |
| Total | 36 | Complete supplied-failure coverage |

The twelve dual names are `test_composedRouteGasFitsCeiling`, `test_row_bind_deploysThroughPackage`, `test_row_bufferFirst_restingFace_notPaidToJoiner`, `test_row_hookSwap_exactIn_eoaPretransferRejected`, `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly`, `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed`, `test_row_index0`, `test_row_index1`, `test_row_partialConsumption_bookedNotRefunded`, `test_row_poolManagerSwap_bothDirections_noFaceResidual`, `test_row_previewMatchesExecution`, and `test_row_rateTarget_currency1`.

## Gas interpretation and future verification

The roughly 17-billion gas totals are not composed-route measurements. Those tests rebuild fixture configuration before the identity guard; source contains address-selection loops. This supports a fixture-cost explanation, not measured attribution of the exact totals. The composed-gas test fails before its route measurement. Retain the existing ceiling and mark the canonical measurement unavailable, not passed or proven oversized.

After separately authorized implementation, verify real disabled exits, remaining-holder residual accounting, enabled cleanup, minima, and continued rejection/rollback of disabled deposits, pass-throughs, and buffered non-withdrawals. The 35 identity-related instances stay unresolved until separately authorized support is actually demonstrated. Do not change them to expected-revert passes.

## Participation and advisory outcome

Full council; invoking-agent coordinator, not a fifth vote:

| Member | Native resolved route | Task | Advisory disposition |
| --- | --- | --- | --- |
| Astra | chatgpt-subscription/gpt-6-astra:high | st_01a1b0fc | support |
| Grok | xai/grok-4.7:xhigh | st_01a1b0fd | support |
| MiniMax | minimax/MiniMax-M3 | st_01a1b0fe | support-with-reservations |
| Kimi | kimi-coding/k3.1-pro:high | st_01a1b0ff | support |

Astra and Grok required acknowledgment-only recovery after initial output-completion errors. Their originals were preserved. MiniMax adaptive configuration was observed; its live request payload was not exposed. Actual member session IDs and isolation were not exposed.

Reviewed draft: `draft-fullspread-hook-matrix-failures-20261106-r1`, `coordinator/draft.md`, unchanged after review. No fingerprint was computed. Resolution: `coordinator/resolution.md`.

MiniMax's reservations led to explicit leg attribution, clearer contract-level evidence linkage, and removal of unnecessarily broad criticism of its gas wording. MiniMax explicitly labeled its causal inference; the final preserves that qualification without claiming a measured breakdown. Broader audit-artifact omissions were observed by MiniMax, not independently rechecked by the coordinator: preserve that provenance and check/update contract-level linkage in subsequent record maintenance. No audit artifact was edited.

No substantive response is missing or counted as approval by silence. Grok and Kimi had feedback-file publication failures; their inline delivery is archived in the resolution rather than represented as member-authored files. Final wording is a coordinator revision, not newly member-approved text. No further round was requested.

## Limitations and publication

This is static review of supplied failures, not runtime reproduction, source-to-bytecode equivalence proof, an atomic checkout snapshot, or a whole-repository security audit. Exact revert frames, deployed address mapping, captured identity bytes, and numeric gas breakdown remain unverified. Tests absent from the failure list are not certified passing. No public research was needed.

Publication: `docs/reviews/fullspread-hook-matrix-failures-20261106/REMEDIATION_PRD.md`. Only new council artifacts and their run record were written. Existing PRDs, plans, code, tests, and audit artifacts were preserved. No Git actions or model reruns for publication; originals and frozen draft retained. This report proposes resolutions and does not authorize implementing them.
