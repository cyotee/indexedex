# Task20 current V4 FullSpread matrix publication

Historical bounded publication against receipt 19. The final refresh is
`56-final-summary.md`, using receipt 54: 179 standalone and 194 inherited
V4 cases, 28,411 passing default cases, zero failures/skips. The later
user funding clarification supersedes the strict interpretation below.

Publication date: 2026-11-07. This is one bounded evidence publication, not implementation, release clearance, deployment authority, or completion of all 24 tasks. Evidence paths below are repository-relative. A bare receipt filename resolves under `.omo/evidence/fullspread-se-hooks-20261106/`.

## Authority, source and toolchain

Requirements: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, FS-TEST-04, revision `fullspread-se-prd-hook-fees-bootstrap-20261106`. Execution/publication inventory: `docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`, task20 and its 48 acceptance rows. Router and all four assistant rule documents were read. The explicit current publication scope takes precedence over the router's historical removal statement.

`00-execution-baseline.md` records the source baseline HEAD `2655665c632d2c4fcc7416f48e8ac487e25a2137` in an already-dirty workspace; it is historical identity, not a fresh fingerprint of current files. It records Foundry 1.9.1-nightly, commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`, and Solar `0.3.0-dev+commit.e7a91fc7` / Solidity 0.8.38. Current receipt commands use `forge build --use solar` followed by `forge test --use solar --isolate -vv`, targeting the seven SE hook directories, shared leg/component libraries and FullSpread vault directory. No toolchain or source identity was freshly queried here. No Git, test/build/artifact writer, install, deployment, delegation, or memory operation was performed by this publication. Only apply_patch made edits.

## Latest executed receipt and counting method

Primary receipt: `.omo/evidence/fullspread-se-hooks-20261106/19-final-integrated-green.log`: **473 suites, 5,111 passed, zero failed, zero skipped; exit 0 as supplied with the receipt**. This is targeted integrated coverage, NOT whole-repository/default-suite certification. Its complete 26,096-line file was read; exact suite headers and PASS identities were parsed across the entire file, not a truncated prefix. Parsed suite/pass counts match the footer, 473/5,111.

Nine exact standalone V4 matrix contracts account for **178 passes**, zero failures/skips. Nine inherited contracts in `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol` account for **193 passes**, zero failures/skips. Combined: **18 suites / 371 passes**, a subset of 5,111, not additional tests to add to that total. All ten existing generator-required `test_row_*` controls remain present in every standalone row. Named unsupported-operation negatives count as passing assertions, not fabricated route capabilities.

The superseded nine-row snapshot was **124 passes / 17 failures** in `docs/research/se-fullspread-remediation-plan-20261106/EXECUTION_RESULTS.json`; it and `EXECUTION_REPORT.md` remain historical provenance. Five old BLOCKED rows are now COMPATIBLE; the other four remain COMPATIBLE with refreshed actual controls. No old snapshot was edited.

| Configuration | Exact standalone contract | Historical state pass/fail | Current pass/fail | Current primary cold transaction gas |
| --- | --- | --- | --- | ---: |
| balancer-quad | `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | COMPATIBLE 15/0 | 18/0 | 873097 |
| curve-quad | `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | BLOCKED 16/1 | 20/0 | 938956 |
| dual | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | BLOCKED 3/13 | 25/0 | 1080835 |
| orbital | `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | BLOCKED 17/1 | 21/0 | 1202138 |
| single-cp | `UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | COMPATIBLE 16/0 | 22/0 | 821056 |
| single-noncp | `UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | COMPATIBLE 13/0 | 16/0 | 647308 |
| weighted | `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault` | COMPATIBLE 15/0 | 18/0 | 856230 |
| weighted N3 | `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3` | BLOCKED 14/1 | 19/0 | 978049 |
| balancer-quad N5 | `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5` | BLOCKED 15/1 | 19/0 | 1070128 |

For every row, `file` is unchanged and `log` now names the primary receipt. `tests` and `declaredTests` list exact executed names (including inherited controls); they do not claim fresh whole-repository discovery. `legs` remains empty rather than inventing persistent addresses. `legsNote` retains old log/state/count provenance and describes per-test registered disjoint fixtures, not deployments.

Matrix totals after this bounded refresh: **205 rows / expectedRowCount 205 / missingSuites [] / unexpectedSuites []**; **197 COMPATIBLE, 7 DEPRECATED, 1 INCOMPATIBLE, 0 BLOCKED**. Of these, **196 rows retain their exact earlier evidence**, including **seven V3 FullSpread rows**. This mixed-provenance summary is not a fresh 205-suite rerun. `generatedFrom` intentionally remains `phase2-release-001-hermetic.log` for the historical baseline; current per-row `log` wins for the nine refreshed rows. The summary/note explain that boundary.

## Exact edited fields

No schema keys or status enums were invented. Existing COMPATIBLE and EVIDENCED states are reused; unrelated rows and acceptance criteria are not reclassified.

`docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json`: only the nine V4 rows, aggregate `summary.COMPATIBLE` (192 -> 197), `summary.BLOCKED` (5 -> 0), `note`, and `findings.FS-HOOK-04`. Row field change counts:

| Field | V4 rows actually changed |
| --- | ---: |
| `rows[*].tests` | 9 |
| `rows[*].passed` | 9 |
| `rows[*].log` | 9 |
| `rows[*].declaredTests` | 9 |
| `rows[*].legsNote` | 9 |
| `rows[*].coldWholeTransactionGas` | 9 |
| `rows[*].state` | 5 |
| `rows[*].failed` | 5 |
| `rows[*].failures` | 5 |
| `rows[*].findings` | 5 |

All row `hook`, `seFamily`, `suite`, `file`, existing `combo`/`faceDecimals`, and `legs` values are preserved. `failed`, `failures` and current `findings` are now zero/empty in all nine rows; four already had those values. Historical F1-F9 descriptions, including the shared V3/V4 F6 record, are unchanged. The current V4 orbital row no longer carries the resolved historical F1 as an active finding.

`docs/audits/apex-2026-09-17-evidence/hook-se-matrix-findings.json`: only these seven existing V4 keys changed; all have empty current `findings`/`blockedTests` and the actual receipt as `evidence`:

| Existing key | Fields actually changed |
| --- | --- |
| `orbital:UniswapV4FullSpreadStandardExchangeVault` | `findings`, `blockedTests`, `evidence` |
| `single-cp:UniswapV4FullSpreadStandardExchangeVault` | `blockedTests`, `currentLimitation`, `evidence` |
| `dual:UniswapV4FullSpreadStandardExchangeVault` | `findings`, `blockedTests`, `evidence` |
| `single-noncp:UniswapV4FullSpreadStandardExchangeVault` | `evidence` |
| `weighted:UniswapV4FullSpreadStandardExchangeVault` | `findings`, `blockedTests`, `evidence` |
| `curve-quad:UniswapV4FullSpreadStandardExchangeVault` | `findings`, `blockedTests`, `evidence` |
| `balancer-quad:UniswapV4FullSpreadStandardExchangeVault` | `findings`, `blockedTests`, `evidence` |

The single-CP `currentLimitation` now explicitly supersedes the disabled cleanup-mint failure while retaining direct prohibited disabled-mint rejection. It is not a blanket disabled-vault success claim.

`docs/audits/apex-2026-09-17-evidence/hook-se-matrix-finding-descriptions.json`: only `FS-HOOK-04.title`, `.detail`, `.control`, `.ruling` changed. Its original detail remains under an explicit historical-failure prefix; current positive evidence/capability limits replace the stale open ruling. The embedded matrix copy matches the standalone description exactly. Site, severity and affected-row locator are retained as historical context, not a fresh source-location audit.

`docs/audits/apex-2026-09-17-evidence/acceptance.json`: only item **R10.3**, `state` BLOCKED -> EVIDENCED and **five appended evidence strings**. All ten earlier evidence entries, the criterion and historical `independentReview` remain intact. EVIDENCED means the current scoped matrix receipt is published; it is not whole-repository or release clearance.

`docs/audits/apex-2026-09-17-evidence.md`: only the current V4 paragraph starting "2026-11-06 Solar execution replaces" was replaced by current results plus a V4 capability/limit paragraph. Earlier historical tables, V3 statements and all unrelated narrative are unchanged. This file is the sixth and final allowed edit, the task20 handoff itself.

## Original36 migration and independent negatives

`15-original-outcomes.md` enumerates 36 distinct original standalone/inherited identities. `15-original-failures.log` is the earlier actual exit-0 receipt, **18 suites / 315 passes / zero failures/skips**. Despite its historical filename, it is green. Every listed identity also appears as PASS in the latest integrated receipt; **36/36 matched by concrete contract and exact method**, no substring multiplication. Their original identity guards were replaced by registered real siblings, valid member pairs, implicit own-share processing and share-funded genesis, retaining downstream positive mint/redemption, refund, recipient and manager-settlement behavior. H1 remains conversion-only.

| Original instance | Exact contract.method in current receipt | Current result |
| --- | --- | --- |
| 01 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_composedRouteGasFitsCeiling` | PASS |
| 02 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_composedRouteGasFitsCeiling` | PASS |
| 03 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_bind_deploysThroughPackage` | PASS |
| 04 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_bind_deploysThroughPackage` | PASS |
| 05 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_bufferFirst_restingFace_notPaidToJoiner` | PASS |
| 06 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_bufferFirst_restingFace_notPaidToJoiner` | PASS |
| 07 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_hookSwap_exactIn_eoaPretransferRejected` | PASS |
| 08 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_hookSwap_exactIn_eoaPretransferRejected` | PASS |
| 09 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly` | PASS |
| 10 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly` | PASS |
| 11 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` | PASS |
| 12 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` | PASS |
| 13 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_index0` | PASS |
| 14 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_index0` | PASS |
| 15 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_index1` | PASS |
| 16 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_index1` | PASS |
| 17 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_partialConsumption_bookedNotRefunded` | PASS |
| 18 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_partialConsumption_bookedNotRefunded` | PASS |
| 19 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_poolManagerSwap_bothDirections_noFaceResidual` | PASS |
| 20 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_poolManagerSwap_bothDirections_noFaceResidual` | PASS |
| 21 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_previewMatchesExecution` | PASS |
| 22 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_previewMatchesExecution` | PASS |
| 23 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_rateTarget_currency1` | PASS |
| 24 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_rateTarget_currency1` | PASS |
| 25 | `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_identity_pairToken` | PASS |
| 26 | `UniswapV4FullSpreadStandardExchangeVault_OrbitalUnwrap_Test.test_row_identity_pairToken` | PASS |
| 27 | `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.test_row_identity_pairToken` | PASS |
| 28 | `UniswapV4FullSpreadStandardExchangeVault_WeightedThreeUnwrap_Test.test_row_identity_pairToken` | PASS |
| 29 | `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_identity_pairToken` | PASS |
| 30 | `UniswapV4FullSpreadStandardExchangeVault_CurveUnwrap_Test.test_row_identity_pairToken` | PASS |
| 31 | `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.test_row_identity_pairToken` | PASS |
| 32 | `UniswapV4FullSpreadStandardExchangeVault_BalancerFiveUnwrap_Test.test_row_identity_pairToken` | PASS |
| 33 | `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.test_row_identity_thisVault` | PASS |
| 34 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_row_identity_thisVault` | PASS |
| 35 | `UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test.test_dualUnwrapApprovesAndCompletesExit` | PASS |
| 36 | `UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test.test_disabledBufferedWithdrawalApprovesAndCompletesExit` | PASS |

`15-original-negatives.md` preserves the separate exact-identity index of **62** independent negatives from the 315-case run. The latest receipt does not turn invalid pair bindings, EOA pretransfer, minimum failure, disabled direct mint or unavailable inverse into positive routes. `test_disabledBufferedInputBooksLocallyWithoutVaultMint` replaces only the stale blanket hook-input failure. `test_disabledBufferedWithdrawalApprovesAndCompletesExit` proves the repaired real withdrawal.

## All48 acceptance dispositions

The following is a **receipt index**, not a new PRD, a code audit, or a declaration that every assertion combination in each row is exhaustive. There are **42 rows with selected exact passing controls, five withdrawn rows (A12-A16), and one reporting-only boundary (A30)**. Old pending execution and replaced failures are superseded by the actual latest receipt; unconstructed state combinations are not inferred from a green test name. In particular, A34's recorded own-credit rejection is not independently an own-negative-debt construction. Source-only coverage caveats in `18-acceptance-source-audit.md` are not runtime passes and are not re-audited here. No acceptance ID is added or renumbered.

All named controls below were checked by exact contract/method in the complete integrated receipt. Alias expansion:

| Alias | Exact contract | Exact file |
| --- | --- | --- |
| P | `UniswapV4FullSpreadStandardExchangeVault_Package_Test` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Package.t.sol` |
| M | `UniswapV4FullSpreadStandardExchangeVault_Money_Test` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol` |
| O | `UniswapV4FullSpreadStandardExchangeVault_OneSidedAndExit_Test` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol` |
| Q | `UniswapV4FullSpreadStandardExchangeVault_QuotesAndRate_Test` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/QuotesAndRate.t.sol` |
| C | `UniswapV4FullSpreadStandardExchangeVault_Callbacks_Test` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Callbacks.t.sol` |
| U | `UniswapV4FullSpreadStandardExchangeVault_AlreadyUnlocked_Test` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol` |
| N | `UniswapV4FullSpreadStandardExchangeVault_Native_Test` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol` |
| B | `UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol` |
| I | `UniswapV4FullSpreadStandardExchangeVault_InitializationReplay_Test` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/InitializationReplay.t.sol` |
| L | `UniswapV4SeBufferHookLegLibTest` | `test/foundry/spec/hooks/uniswap/v4/interfaces/UniswapV4SeBufferHookLegLib.t.sol` |

`DUAL` is the exact standalone dual contract in the nine-row table. `ALL9` expands to all nine exact contracts in that table. `CA6` expands to each of the six LP-family contracts below, all of which executed each CA6-named shared control in the table. Larger weighted/Balancer variants also execute, but are not silently multiplied into six base-family counts. The H1 component contract `UniswapV4SingleSEBufferHook_ComponentAccounting` has custody/conversion controls, not LP issuance or genesis obligations.

| CA6 exact contract | Exact file |
| --- | --- |
| `UniswapV4SingleStandardExchangeBufferConstantProductHook_ComponentAccounting` | `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ComponentAccounting.t.sol` |
| `UniswapV4DualSEBCPHook_ComponentAccounting` | `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_ComponentAccounting.t.sol` |
| `UniswapV4StandardExchangeOrbitalBufferHook_ComponentAccounting` | `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_ComponentAccounting.t.sol` |
| `UniswapV4StandardExchangeCurveQuadStableBufferHook_ComponentAccounting` | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_ComponentAccounting.t.sol` |
| `UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting` | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting.t.sol` |
| `UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting` | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting.t.sol` |

| PRD row | Disposition | Exact executed control and coverage boundary |
| --- | --- | --- |
| FS-A01 | Executed named controls | `P.test_reviewedSelectorManifestIsComplete` - Selector controls; no vault getRate. |
| FS-A02 | Executed named controls | `P.test_bindingHashChangesWithAnyBinding` - Binding identity. |
| FS-A03 | Executed named controls | `I.test_doubleInitializationAbortsRealProxyConstruction` - Actual second-init revert plus real registered money control; separate 18-initialization-replay-r2.log passes. |
| FS-A04 | Executed named controls | `P.test_liveInstancesKeepSupplyBooksAndConfigurationIsolated` - Live-instance isolation control. |
| FS-A05 | Executed named controls | `O.test_M14_genesisFloorPositionAndFeeAreNotExtraIssuance` - Vault genesis floor and fee are not extra issuance. |
| FS-A06 | Executed named controls | `Q.test_bundleExitPreviewParityBothCallerOrders` - Both caller-order bundle controls. |
| FS-A07 | Executed named controls | `O.test_M11_bundleBooksFeesAndRefundsInVaultTokenOrder` - Actual refund/book accounting control. |
| FS-A08 | Executed named controls | `O.test_M10_bundleExitPaysExactBookedAndUnpaidClaimsBothOrders` - Booked plus unpaid exact claims. |
| FS-A09 | Executed named controls | `M.test_enabledExchangeOutIsAbsent` - Enabled unsupported inverse is intentionally negative. |
| FS-A10 | Executed named controls | `N.test_nativeShareExitPaysDistinctRecipientWethOnly` - WETH recipient boundary. |
| FS-A11 | Executed named controls | `O.test_M07_passThroughBothWaysAndMinimumRollback` - No-supply-change/pass-through control. |
| FS-A12 | Withdrawn | No replacement test; not counted as passing. |
| FS-A13 | Withdrawn | No replacement test; not counted as passing. |
| FS-A14 | Withdrawn | No replacement test; not counted as passing. |
| FS-A15 | Withdrawn | No replacement test; not counted as passing. |
| FS-A16 | Withdrawn | No replacement test; not counted as passing. |
| FS-A17 | Executed named controls | `C.test_lockedMintOneUnlockAndConsumedCallbackPerAction` - Dispatch-count control. |
| FS-A18 | Executed named controls | `C.test_uncommittedPayloadReverts` - Replay/uncommitted callback controls. |
| FS-A19 | Executed named controls | `U.test_borrowedExchangeInMintsAndClearsDeltas` - Borrowed real mint. |
| FS-A20 | Executed named controls | `U.test_borrowedValueRejectsAtNonpayableBoundary` - Borrowed nonpayable and funding controls. |
| FS-A21 | Executed named controls | `U.test_borrowedUnfundedCallerAndUnownedSharesRevert` - No unowned-share or unfunded authority. |
| FS-A22 | Executed named controls | `U.test_borrowedBundleOutDonateAndCompoundReject` - Prohibited borrowed operations reject. |
| FS-A23 | Executed named controls | `U.test_caughtBorrowedMinimumFailureRestoresVault` - Caught failure restoration; outer failure also passes. |
| FS-A24 | Executed named controls | `L.test_pairMembership_ownShareIsImplicitAndSeparate` - Positive own-share/member bindings in the nine matrix rows; not same-token invalid-route success. |
| FS-A25 | Executed named controls | `B.test_disabledBufferedWithdrawalApprovesAndCompletesExit` - Actual underlying redemption positive; inherited unwrap positives remain. |
| FS-A26 | Executed named controls | `DUAL.test_fixture_twoFullSpread_publicSharesAndRedemption` - Two registered real disjoint siblings, both directions. |
| FS-A27 | Executed named controls | `ALL9.test_row_bind_deploysThroughPackage` - All nine configurations execute downstream controls. H1 LP-only scenarios inapplicable. |
| FS-A28 | Executed named controls | `B.test_exactOutHookPaysNeitherToken` - Hook inverse-preview rejection/rollback; zero inverse quote may reject before unsupported vault execution. Direct enabled negative is A09. Local-only hook success stays positive. |
| FS-A29 | Executed named controls | `B.test_getRateAbsentAndProviderReadsTuple` - Both-target composed gas controls across all nine configurations; H1 has no provider field. |
| FS-A30 | Reporting boundary | Disjoint backing evidence only; no same-backing-pool sequential safety claim. |
| FS-A31 | Executed named controls | `ALL9.test_composedRouteGasFitsCeiling` - All four gas routes per row; actual current maxima 556371 preview / 1449022 transaction. |
| FS-A32 | Executed named controls | `Q.test_economicViewsDisabledAndUnlocked` - Economic-view context controls. |
| FS-A33 | Executed named controls | `U.test_borrowedMintBothFacesMatchesLockedFromSameState` - Same-state mint parity; both-face exit and pass-through parity also execute. |
| FS-A34 | Executed named controls | `U.test_borrowedNonzeroOwnDeltaBareReverts` - Own-credit rejection/foreign-debt preservation execute. This publication does not infer an own-negative-debt construction from the test name. |
| FS-A35 | Executed named controls | `N.test_borrowedNativeDebtPreservesForeignCreditAndBacking` - Native sync/foreign credit isolation. |
| FS-A36 | Executed named controls | `U.test_outerFailureRestoresBorrowedSwap` - Propagated failure rollback; caught failure also executes. |
| FS-A37 | Executed named controls | `U.test_borrowedExchangeInMintsAndClearsDeltas` - Funded non-hook caller success. |
| FS-A38 | Executed named controls | `B.test_disabledBufferedInputBooksLocallyWithoutVaultMint` - Hook-local positive; direct borrowed disabled mint remains negative. Cleanup-mint failure superseded. |
| FS-A39 | Executed named controls | `O.test_M16_liveFeeToAndGlobalAndFunctionOperators` - Live feeTo/operator controls. |
| FS-A40 | Executed named controls | `CA6.test_HB40_memberPairsSeparateFromImplicitShares` - Membership/implicit own-share positives; L nonmember/list and asset-answering-nonmember negatives also execute. |
| FS-A41 | Executed named controls | `CA6.test_HB41_ambientPairTransfersDoNotFundLaterJoin` - Caller/ambient custody controls; H1 refund/custody cases execute separately. |
| FS-A42 | Executed named controls | `CA6.test_HB42_outputDeficitRedeemsOnlyAfterLocalBook` - Local-first/deficit controls; equality remains a separate family-specific case. |
| FS-A43 | Executed named controls | `CA6.test_HB43_pairInputConversionBacksEveryAcceptedComponent` - Literal pre-intake/caller-only; impossible baskets reject, valid complete baskets remain positive. No owner approval inferred. |
| FS-A44 | Executed named controls | `CA6.test_HB44_twoHoldersExitOnlyTheirComponentFractions` - Weighted four-alias actual receipts/state positive; unsupported sequential VIEW fails closed. Balancer partial conversion rejects, real consuming ERC4626 positive retained. |
| FS-A45 | Executed named controls | `CA6.test_HB45_preownedSharesJoinWithoutDisabledMint` - Address/package disable axes and preowned shares; no disabled-backing-zero assumption. |
| FS-A46 | Executed named controls | `CA6.test_HB16_joinMarketExitUnderlyingUnwind` - Six real native-book sequence controls; conversion PnL separate, no wider swap-manipulation safety claim. |
| FS-A47 | Executed named controls | `CA6.test_HB47_mintFeeSplitsBackedGross` - Backed gross = fee + net; rate-only no-mint controls pass. No growth issuance or separate protocol swap-fee accumulation selected. H1 inapplicable. |
| FS-A48 | Executed named controls | `CA6.test_HB48_genesisRedeemsFivePercentOfShares` - Actual 5% share consumption/local receipt, retained shares, rollback and later-component joins; H1 LP genesis inapplicable. |

A03's old actual-repeat-init gap is superseded by `18-initialization-replay-r2.log`, **one suite / one PASS**, and the same exact initialization replay test also passes in the integrated receipt. The receipt concerns an actual double-initialization revert with a registered real money-path control, not the earlier idempotent second-deploy assertion. No withdrawn rate behavior is restored.

## Preserved45 audit-ID taxonomy

Copied from the sole PRD FS-TEST-04 inventory, not re-derived from the old audit. **45 IDs, APEX-2026-010 through -054**: 20 plain yes + three yes-as-negative = **23 yes-family**, 17 plain no + one no-separate-Wings = **18 no-family**, and **four integration-only**. Original qualifiers are retained below. This is a scope taxonomy, **not 45 passing vulnerability-absence claims**. No "no" row is reopened; integration-only findings are not relabelled as vault fixes. No old audit was reread to change a disposition.

| Audit ID | Locked in-plan disposition |
| --- | --- |
| APEX-2026-010 | yes |
| APEX-2026-011 | yes |
| APEX-2026-012 | no |
| APEX-2026-013 | yes |
| APEX-2026-014 | integration only |
| APEX-2026-015 | integration only |
| APEX-2026-016 | no |
| APEX-2026-017 | no |
| APEX-2026-018 | no |
| APEX-2026-019 | yes, as a negative |
| APEX-2026-020 | no |
| APEX-2026-021 | no |
| APEX-2026-022 | yes |
| APEX-2026-023 | yes |
| APEX-2026-024 | yes |
| APEX-2026-025 | no |
| APEX-2026-026 | no separate Wings test |
| APEX-2026-027 | no |
| APEX-2026-028 | yes |
| APEX-2026-029 | yes, as a negative |
| APEX-2026-030 | integration only |
| APEX-2026-031 | no |
| APEX-2026-032 | yes |
| APEX-2026-033 | no |
| APEX-2026-034 | yes |
| APEX-2026-035 | no |
| APEX-2026-036 | yes |
| APEX-2026-037 | no |
| APEX-2026-038 | no |
| APEX-2026-039 | yes |
| APEX-2026-040 | yes |
| APEX-2026-041 | yes |
| APEX-2026-042 | yes |
| APEX-2026-043 | integration only |
| APEX-2026-044 | yes |
| APEX-2026-045 | yes |
| APEX-2026-046 | no |
| APEX-2026-047 | no |
| APEX-2026-048 | yes |
| APEX-2026-049 | yes, as a negative |
| APEX-2026-050 | no |
| APEX-2026-051 | yes |
| APEX-2026-052 | yes |
| APEX-2026-053 | no |
| APEX-2026-054 | yes |

## Later strict, fee/genesis, capability and review evidence

- `13-preintake-decision.md`: the clarification timed out; the user instructed best judgment and continuation. This is **not owner approval** of paid incumbent swaps or a PRD amendment. All six LP families follow literal pre-intake snapshots and caller-only component quantities. Impossible single-input baskets reject atomically; valid complete baskets and legitimate zero-component cases remain positive. **D1/D2 are not open product questions.**
- `13-strict-family-results.md` records the intermediate 4,222-pass/74-fail six-family run, not the current result. Later `10-strict-family-final.log` is **76 suites / 905 passes**, and `12-strict-family-final.log` is **61 suites / 730 passes**, both zero failures/skips. The latest integrated 5,111-pass receipt supersedes their old pending/failure descriptions; those files were not edited.
- Fee evidence includes exact CA6 `test_HB47_mintFeeSplitsBackedGross`, `test_HB47_rateOnlyMovementMintsNoLp`, the fee arithmetic/alias controls in the integrated run, and review disposition. Fee LP is split from **fully backed gross = fee + net**, not minted on top. No growth/yield issuance or separate protocol swap-fee accumulation remains the selected model. Existing swap fees still accrue to LP holdings. Family activation/dust policies are not standardized by publication.
- Genesis evidence includes exact CA6 `test_HB48_genesisRedeemsFivePercentOfShares`, `test_HB48_genesisFailureRollsBackEveryLeg`, `test_HB48_initialPairInputRejectedAtomically`, `test_HB48_seedLpIndependentOfRedemptionPrice` and `test_HB48_laterJoinUsesCurrentComponents`. Funded SE legs accept shares, redeem **floor(receivedShares * 5 / 100)** with actual share consumption/positive local receipt, and book retained shares separately; raw legs retain the raw exception. Subsequent joins use current component fractions, not a continuing 5% target. H1 has no LP genesis.
- `10-exit-quote-capability.log`: **two suites / two passes**. Weighted FullSpread sequential exit **VIEW** fails closed `InvalidQuoteState()` when there is no valid projected state after an earlier conversion. Actual `withdrawSingle`, exact-LP-input, SE and SY exit aliases remain positive and produce exactly equal receipts/state. Unavailable view capability is not actual exit failure, not an invented projection interface, and not an owner question.
- `12-share-exit-conversion-contract.log`: **three suites / three passes**. Both FullSpread Balancer configurations reject a requested share-only payout when conversion refunds input, with exact whole-exit rollback. A fully consuming real ERC4626 SE positively pays allocated shares plus the converted local claim with exact preview parity. No fake output, replacement transition interface, or mixed payout was invented.
- `22-review-disposition.md`: source-review disposition, **not runtime clearance**. It records dual incomplete reserve-interface advertisement removal, Curve registration of installed interfaces, Orbital refund-after-final-state correction, and literal pre-intake backing. `22-audit-regressions-green.log` is described there as four passing selected regressions; current integrated exact cases also execute. Existing permissionless funded dual ownerSwap aliases, retained uninstalled helper cleanup, and family activation/dust policies stay explicitly outside the new FullSpread economic change. This publication does not claim an ownership role was added.

## Exact gas and capability limits

`17-gas-final-receipts.md` / `17-capabilities.md` remain route-method and historical measurement provenance; their older maximum transaction **1,448,998** is not substituted for the newer integrated value **1,449,022**. The latest nine standalone suites each report four measured composed routes, **36 route measurements**. Each cell below is **cold preview gas / whole router transaction gas**, including intrinsic calldata for the transaction, excluding fixture setup/bootstrap. The existing row field `coldWholeTransactionGas` records the primary mint only, not the four-route maximum.

| Configuration | currency0 primary mint | currency0 redeem | currency1 mint | currency1 redeem |
| --- | ---: | ---: | ---: | ---: |
| balancer-quad | 321657/873097 | 283229/777830 | 331180/886220 | 296074/797261 |
| curve-quad | 444909/938956 | 404310/843814 | 454432/947017 | 417155/858183 |
| dual | 474313/1080835 | 543526/1424529 | 488898/1104082 | 556371/1449022 |
| orbital | 470804/1202138 | 431021/1110041 | 485389/1230423 | 448928/1144634 |
| single-cp | 290528/821056 | 242179/711407 | 300053/833804 | 255026/731171 |
| single-noncp | 126986/647308 | 104972/545649 | 126385/696547 | 105864/516892 |
| weighted | 327561/856230 | 286476/768115 | 337084/863666 | 299321/783181 |
| weighted N3 | 452838/978049 | 415007/893188 | 462361/985485 | 427852/908254 |
| balancer-quad N5 | 468685/1070128 | 430257/974862 | 478208/1083251 | 443102/994293 |

Current maxima: **556,371 preview** (ceiling 5,000,000) and **1,449,022 transaction** (ceiling 12,000,000), both on the dual currency1 redemption. The 40-case inherited/CP gas receipt and independent canonical preview in the 17-series remain historical evidence; no setup gas or local-only swap is substituted for measured real SE mint/redemption. Both targets execute across all nine configurations; H1 binds both member faces without a provider field.

Direct FullSpread vault exact-output remains intentionally unavailable: zero inverse preview and enabled `ExchangeOutNotAvailable()` execution. Hook local-only exact-output is separate and supported. Hook deficit attempts may stop at the zero inverse quote, so that negative does not establish an actual unsupported vault execution call; the direct vault negative is independently present. Vault `getRate()` is absent; LP-bearing fixtures use external providers. Own-share omission from `vaultTokens()` is supported for processing, but the configured pair must actually be a member. All nine real sibling fixtures use **disjoint backing pools**. None establishes same-backing-pool sequential safety or wider swap-manipulation protection.

**Parent full-default artifact/build/test/size gates are pending at this publication cutoff.** Earlier partial integrated failures and older size receipts are history, not a current release result. No whole-repo green, size clearance, audit certification, deployment approval, or all-24-complete claim is made. No pending parent gate was run, waited on, or inferred by this bounded publication.

## Validation and preservation receipt

Authorized validation was read-only JavaScript parsing/comparison in eval; no test/build/artifact writer ran.

- **Four JSON parses passed** for the three matrix documents and acceptance.json.
- **205/205 raw matrix row blocks counted** before/after. **196 non-V4 rows byte-identical**, including all **seven V3 FullSpread rows**. The nine refreshed rows match exact suite/file/test/pass/fail receipt identities. Aggregated states match summary counts; unchanged expected/missing/unexpected metadata remains historical inventory.
- **108 acceptance items counted** before/after; **107 non-R10.3 items byte-identical**. R10.3's original criterion, ten earlier evidence strings and entire historical independentReview object are semantically unchanged; only state and five appended evidence strings changed.
- Unrelated finding-map entries and all standalone/embedded F1-F9 descriptions compare equal. The new FS-HOOK-04 embedded/standalone copies compare equal. No unrelated V3 shared F6 prose was changed.
- Audit Markdown compares exactly to the original with only the affected V4 paragraph replacement described above.
- **36/36 original identities** match PASS in the latest integrated run. **48/48 acceptance IDs** indexed, with **42 selected-control / five withdrawn / one reporting-boundary** dispositions. **45/45 audit IDs** retain exact PRD taxonomy and qualifiers.
- Existing generator `scripts/hook_se_matrix_evidence.py` was read, not executed: it consumes the existing summary/rows/tests/findings schemas, uses the ten named controls and known states, and would regenerate all rows. This publication deliberately does not run that artifact writer or reinterpret unrelated rows from a targeted log. Source searches found it as the only executable matrix JSON consumer in the searched py/ts/js/sh files. No exhaustive claim about other file types is made.
- The apply_patch diagnostic hook reported **Biome LSP not installed (command not found: biome)**. No installation was attempted under the explicit prohibition. JSON parse/receipt/preservation validation above passed; LSP diagnostics are unavailable, not claimed clean.

Only the five allowed current audit documents and this handoff were edited. PRD, plan, historical snapshots, code/config, other acceptance/evidence files and runtime artifacts were not edited by this publication. This handoff ends task20's bounded current-matrix publication; parent verification remains separate.

