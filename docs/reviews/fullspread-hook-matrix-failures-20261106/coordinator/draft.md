# FullSpread hook-matrix failure diagnosis

Draft ID: draft-fullspread-hook-matrix-failures-20261106-r1

This is the immutable draft for one advisory pass. Profile: review. Council kind: full. This proposal does not authorize implementation, change the family PRD, or certify passing tests.

## 1. Conclusion

The 36 supplied failures have two underlying mechanisms, not 36 independent product defects:

- **35 identity-related failures:** package membership validation rejects a share used as its own SE identity leg. The current PRD and plan explicitly require these rejected configurations to remain non-passing. Preserve FS-A24 and FS-A26 as open integration obligations.
- **One disabled-withdrawal failure:** the constant-product hook permits the initial share redemption, but its subsequent residual cleanup can attempt a face-to-share deposit into the disabled vault. That deposit is correctly rejected and rolls back the entire withdrawal. The specified buffered exit needs a hook-side correction; the vault's disable rule must stay intact.

The second attribution is a source-derived explanation, not a captured execution trace. The supplied revert address and the exact inner identity-rejection bytes remain unverified.

## 2. Scope and participation

The user requested diagnosis and proposed resolutions only. No source/test/configuration changes, test execution, installations, deployments, wallet operations, or Git mutations are part of this council.

All four substantive independent originals were read:

| Member | Native resolved route | Task | Initial outcome |
| --- | --- | --- | --- |
| Astra | chatgpt-subscription/gpt-6-astra:high | st_01a1b0fc | Complete; acknowledgment recovered after an output-completion error |
| Grok | xai/grok-4.7:xhigh | st_01a1b0fd | Complete; acknowledgment recovered after an output-completion error |
| MiniMax | minimax/MiniMax-M3 | st_01a1b0fe | Complete |
| Kimi | kimi-coding/k3.1-pro:high | st_01a1b0ff | Complete |

MiniMax's adaptive setting was present in configuration; its live request payload was not exposed. Member session IDs and actual isolation were not exposed. Both acknowledgment recoveries preserved the originals and requested no new research. The invoking coordinator is not another vote. Advisory dispositions are pending.

Evidence is local source inspection plus the user's supplied results. No public query was used. This is not an atomic snapshot or a whole-family audit.

## 3. Identity rejection: retain the non-pass, do not conceal the missing support

**Location and mechanism.** `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:174-195` accepts a pair token through membership in `se.vaultTokens()`, or through identity-wrapper recognition. The latter requires `pair == se` and a successful `asset()` probe returning a distinct nonzero underlying. The relevant vaults expose their backing faces as vault tokens rather than their own shares, and do not provide that wrapper surface. Members inspected both package initialization and selector surfaces.

The dual row catches the rejected `processArgs(bytes)` bind, leaves no deployed hook for that configuration, and fails its identity guard at `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:355-358`. These guard failures do not establish separate defects in the later refund, swap, preview, index, or gas assertions.

**Requirement.** In `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, FS-HOOK-02 and FS-HOOK-04 at lines 492-518 classify this as a separate integration requirement. FS-A24 at line 573 requires the rejected this-vault bind not to pass; FS-A26/27 at lines 575-576 keep the canonical cross-vault proof open. The corresponding implementation-and-test plan at lines 223-225 explicitly forbids adding `asset()` or replacing the PairToken identity record with a raw token to claim FS-A26.

**Resolution.** Preserve the rejected identity attempts, real consumer, selector, argument bytes, captured revert bytes, and failing acceptance result. Keep the mixed-topology face/raw controls separate. Do not add `asset()`, install `getRate`, bypass membership checks, skip failures, or count raw controls as the canonical proof. FS-OWN-29 provider obligations and the dual composed-gas obligation do not become complete through an FS-HOOK-04 record.

This resolves the diagnosis, not the integration limitation: these tests remain red under the current scope. Making the identity configuration supported needs a separately scoped hook requirement with its own acceptance design; this council does not choose a new identity-recognition contract.

## 4. Distinguish FS-A24 and the blocked dual unwrap

The this-vault test at the dual row's lines 429-439 changes leg 0 to the FullSpread share identity. Its two failing instances are FS-A24, not FS-A26. Validation order explains the first rejected leg in source; it is not a substitute for recorded runtime revert bytes.

`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol:240-247` contains the additional dual unwrap test. Its `assertTrue(identityAccepted, ...)` at line 242 fails before seeding or attempting withdrawal. It therefore proves neither a missing approval nor a second withdrawal defect.

**Resolution.** Keep that test non-passing and link its result to the inherited rejection record, explicitly stating that unwrap execution was not reached. Reusing the identity guard or aligning the diagnostic message is a possible record-only improvement, not required product work. The inherited setup already captures the rejection; this is not a complete absence of evidence.

The event helper in the dual file at lines 117-119 wraps its bytes argument with `abi.encode(args_)`. Preserve that encoding or document decoding it once; do not label an inferred selector or a copied assertion string as captured revert data. No event-ABI redesign is proposed.

## 5. Disabled buffered exit: correct residual maintenance, not the vault guard

**Location.** `BufferHookIntegration.t.sol:94-101` disables the underlying vault and requires an actual hook withdrawal. The production path is:

1. `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol:507-537`: calculate claims, burn LP, unwrap SE shares, pay the recipient, check minima, update accounting, then perform residual maintenance.
2. `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol:126-136`: `refundPairDust` attempts residual buffering above the dust threshold when its preview is positive.
3. `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:379-394`: the residual call spends face tokens for SE shares.
4. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol:39-40,136-140`: share-in/face-out is allowed while disabled; face-in/share-out is not.

**Requirement and impact.** PRD FS-OWN-26 and FS-A38 (lines 210 and 587), together with plan section 11, require buffered withdrawals to succeed while deposits remain blocked. A cleanup deposit can veto the whole exit. Atomic reversion undoes the preceding burn and payouts; this is withdrawal unavailability, not evidence of a completed burn without payment.

**Proposed correction.** At the hook withdrawal's residual-maintenance boundary, avoid reinvesting into a disabled underlying SE. Keep approval, redemption, recipient payments, minima, and the vault's rejection of non-withdrawals unchanged. Preserve residual ownership as hook inventory rather than gifting it to the exiting caller. Do not swallow arbitrary errors or introduce new valuation rules. The later implementation must verify that retained inventory remains correctly represented for remaining holders and that enabled cleanup still works.

The existing requirement settles the desired behavior; choosing a repository edit boundary is engineering work, not by itself a missing owner product decision. Authorization to implement is still absent.

## 6. Complete failure accounting

Required source aliases below are the six full test paths listed in `../brief.md`; the PRD and plan are targets seven and eight. Member originals give path-level coverage. Astra and Kimi report full reading of all eight; MiniMax reports partial PRD/plan coverage. Coordinator source checks covered the principal classifier, cleanup chain, guard, requirements, and disputed diagnostic sites.

| Group | Instances | Disposition |
| --- | ---: | --- |
| Twelve dual identity-gated tests, in the dual matrix and inherited DualUnwrap contract | 24 | FS-A26 prerequisite rejected |
| `test_row_identity_pairToken` in orbital, weighted N3, Curve, Balancer five-leg, and their four inherited unwrap contracts | 8 | Same identity rejection; retain separate raw controls |
| `test_row_identity_thisVault` in dual and inherited DualUnwrap | 2 | FS-A24 remains open |
| `test_dualUnwrapApprovesAndCompletesExit` | 1 | Same prerequisite; unwrap not executed |
| `test_disabledBufferedWithdrawalApprovesAndCompletesExit` | 1 | Required exit obstructed by cleanup deposit |
| Total | 36 | Every supplied failure accounted for |

The twelve dual names, each occurring twice, are:

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

## 7. Gas and future verification

The approximately 17-billion figures are not passing composed-route measurements. The two tests rebuild fixture configuration before hitting the identity guard; members found address-selection loops in that setup. This supports a fixture-cost explanation, not a measured attribution of the exact totals. No production loop or ceiling violation is established by those figures. The composed test fails its prerequisite before measuring its route.

After separately authorized implementation, verification should establish:

- Disabled withdrawal completes with real approval, share burn, and recipient payment; no forbidden reinvestment occurs.
- Retained residual belongs to the hook and remains accounted for, including remaining-holder exits.
- Enabled withdrawal cleanup and minima behavior remain correct.
- Disabled deposits, pass-throughs, and buffered non-withdrawals still reject and roll back.
- The 35 identity-related instances remain explicitly unresolved unless a separate identity-support change is authorized and demonstrated.
- Any eventual accepted canonical route satisfies the existing gas ceiling using the required measurement, rather than failed-test totals.

No such checks ran in this council.

## 8. Differences among originals and limits

All four agree on the principal mechanisms. MiniMax calls ownership of the cleanup change an open product decision; the coordinator does not adopt that as a blocker because buffered exit behavior is already specified. A new identity-support contract remains separate work.

Grok calls the short dual-unwrap assertion an incomplete record. Kimi and Astra correctly note inherited setup evidence exists. The proposal is clearer per-test linkage, not a claim that no record exists.

MiniMax proposes broader audit-record provenance updates. Those are retained as record-maintenance suggestions, not independently verified defects or production prerequisites. No audit JSON edit is authorized here.

Grok and MiniMax use stronger gas-cause wording than runtime evidence supports. The final must retain the qualification in section 7. Some Grok line numbers differ from coordinator reads; this draft uses the coordinator-checked disabled-test and record-helper locations.

The exact revert frame, deployed address mapping, captured inner identity bytes, current bytecode equivalence, and numeric gas breakdown are unverified. Passing controls not present in the user's failure list are not certified by omission. The advisory pass may correct this draft; agreement is not runtime proof.
