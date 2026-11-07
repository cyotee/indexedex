# Original 36-instance outcome ledger

Validation date: 2026-11-07. `15-original-failures.log` is the actual serialized Solar artifact/test receipt: exit code 0, 18 suites, 315 passed, zero failures/skips. All nine named standalone matrix configurations and the inherited vault integration suites ran. This table was reconciled by exact concrete contract and test name against the log, not by substring counts. All 36 original identities remain named and passed.

The old identity prerequisites now use registered real FullSpread siblings, valid member pairs, implicit own-share processing and share-funded Hook LP genesis. Positive downstream mint/redemption, recipient, refund, manager-settlement and gas assertions remain. Independent invalid-pair and unsupported-operation negatives are separate. H1 remains conversion-only.

| Original instance | Concrete contract | Current test | Outcome |
| --- | --- | --- | --- |
| 01 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_composedRouteGasFitsCeiling` | PASS |
| 02 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_composedRouteGasFitsCeiling` | PASS |
| 03 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_bind_deploysThroughPackage` | PASS |
| 04 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_bind_deploysThroughPackage` | PASS |
| 05 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_bufferFirst_restingFace_notPaidToJoiner` | PASS |
| 06 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_bufferFirst_restingFace_notPaidToJoiner` | PASS |
| 07 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_hookSwap_exactIn_eoaPretransferRejected` | PASS |
| 08 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_hookSwap_exactIn_eoaPretransferRejected` | PASS |
| 09 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly` | PASS |
| 10 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly` | PASS |
| 11 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` | PASS |
| 12 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` | PASS |
| 13 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_index0` | PASS |
| 14 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_index0` | PASS |
| 15 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_index1` | PASS |
| 16 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_index1` | PASS |
| 17 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_partialConsumption_bookedNotRefunded` | PASS |
| 18 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_partialConsumption_bookedNotRefunded` | PASS |
| 19 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_poolManagerSwap_bothDirections_noFaceResidual` | PASS |
| 20 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_poolManagerSwap_bothDirections_noFaceResidual` | PASS |
| 21 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_previewMatchesExecution` | PASS |
| 22 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_previewMatchesExecution` | PASS |
| 23 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_rateTarget_currency1` | PASS |
| 24 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_rateTarget_currency1` | PASS |
| 25 | `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_identity_pairToken` | PASS |
| 26 | `UniswapV4FullSpreadStandardExchangeVault_OrbitalUnwrap_Test` | `test_row_identity_pairToken` | PASS |
| 27 | `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3` | `test_row_identity_pairToken` | PASS |
| 28 | `UniswapV4FullSpreadStandardExchangeVault_WeightedThreeUnwrap_Test` | `test_row_identity_pairToken` | PASS |
| 29 | `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_identity_pairToken` | PASS |
| 30 | `UniswapV4FullSpreadStandardExchangeVault_CurveUnwrap_Test` | `test_row_identity_pairToken` | PASS |
| 31 | `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5` | `test_row_identity_pairToken` | PASS |
| 32 | `UniswapV4FullSpreadStandardExchangeVault_BalancerFiveUnwrap_Test` | `test_row_identity_pairToken` | PASS |
| 33 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | `test_row_identity_thisVault` | PASS |
| 34 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_row_identity_thisVault` | PASS |
| 35 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test` | `test_dualUnwrapApprovesAndCompletesExit` | PASS |
| 36 | `UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test` | `test_disabledBufferedWithdrawalApprovesAndCompletesExit` | PASS |

Task 15 outcome: all 36 originally supplied failures have actual downstream passing receipts. The stale blanket disabled-hook-input expectation was separately replaced by `test_disabledBufferedInputBooksLocallyWithoutVaultMint`; direct prohibited disabled mint remains negative in the vault suite. This closes the original fixture migration, not the pending single-input interpretation, wider acceptance inventory, or unresolved weighted/Balancer component-adapter cases.
