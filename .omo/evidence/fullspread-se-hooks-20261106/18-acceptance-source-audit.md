# Task 18: FullSpread acceptance source audit

Source inspection dated 2026-11-07. **This is not runtime evidence.** No build,
test, artifact refresh, Git operation, installation, deployment, network access,
delegation, or memory operation was performed. Only this file is an edit target.
The parent owns discovery, compilation, execution, gas results, and source/runtime
identity reconciliation.

## Authority and reading conventions

Requirements authority: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
(revision `fullspread-se-prd-hook-fees-bootstrap-20261106`), especially
FS-OWN-24/27/30/32/33/34-37, FS-HOOK-05-10, and lines 663-721.
Execution destination/context: the user-authorized
`docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`,
including its 48-row ledger and task 18. The existing
`.omo/evidence/fullspread-se-hooks-20261106/01-acceptance-ledger.md` was read;
its execution dispositions are not changed here. No `.omo` plan substitutes for
the authorized plan or PRD.

**Pending owner interpretation:** whether paid internal swaps may precede the LP
component snapshot on single-input joins. A43/A47 alias assertions using a
post-trade snapshot are recorded below as **pending interpretation**, not accepted
requirements or proof of compliance. Neither current implementation nor its
matching tests resolves that question.

There are exactly 48 acceptance rows below. A12-A16 are withdrawn, not passing
tests. A source reference means the assertion body was read, not that the test
was discovered, executed, or passed. "No additional gap identified" is bounded
to the named assertions and inspected sources, not an audit clearance.

### Exact vault source and contract keys

`VT` = `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.
`HT` = `test/foundry/spec/hooks/uniswap/v4/standardExchange/`.
`VP` = `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.
Every `Key.test_name` below expands to the exact file and contract in this table.
Line numbers refer to the source read in this audit, not to generated artifacts.

| Key | Exact source under VT | Exact contract |
| --- | --- | --- |
| P | `Package.t.sol` | `UniswapV4FullSpreadStandardExchangeVault_Package_Test` |
| M | `Money.t.sol:82-306` | `UniswapV4FullSpreadStandardExchangeVault_Money_Test` |
| O | `Money.t.sol:344-1785` | `UniswapV4FullSpreadStandardExchangeVault_OneSidedAndExit_Test` |
| MG | `Money.t.sol:314-342` | `UniswapV4FullSpreadStandardExchangeVault_MoneyCompoundGas_Test` |
| Q | `QuotesAndRate.t.sol:64-340` | `UniswapV4FullSpreadStandardExchangeVault_QuotesAndRate_Test` |
| QR | `QuotesAndRate.t.sol:342-437` | `UniswapV4FullSpreadQuadraticLock_Test` |
| C | `Callbacks.t.sol:49-217` | `UniswapV4FullSpreadStandardExchangeVault_Callbacks_Test` |
| U | `AlreadyUnlocked.t.sol:143-524` | `UniswapV4FullSpreadStandardExchangeVault_AlreadyUnlocked_Test` |
| N | `Native.t.sol:78-236` | `UniswapV4FullSpreadStandardExchangeVault_Native_Test` |
| F | `OneSidedFuzz.t.sol:34-72` | `UniswapV4FullSpreadStandardExchangeVault_OneSidedFuzz_Test` |
| B | `BufferHookIntegration.t.sol:78-226` | `UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test` |

These vault tests use `VP/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol:36-115`.
Its setup deploys the real PoolManager from artifact-backed CREATE3, facets through
factory services, and the vault package through the manager, then calls
`package.deployVault`. Its six ancillary infrastructure addresses are a
`FullSpreadInfrastructureStub` (lines 92-98,117), not operational implementations
of all six protocols. Thus package binding/getter assertions do not prove behavior
of a real Quoter, Universal Router, or other ancillary protocol.

Status vocabulary:

- **Live-proxy source**: body calls a production package/vault/hook proxy according
  to the source fixture. This does not attest to the bytecode currently in `out/`.
- **Pure/unit**: native arithmetic or a library harness, not integrated money-path
  execution. Unit external dependencies are identified where relevant.
- **Partial**: concrete assertions exist but do not establish the whole row.
- **Withdrawn**: no replacement positive test and no execution-pass credit.
- **Record**: a reporting boundary, not an executable economic success.

### Exact hook matrix keys

Each file below is under HT; its contract is exactly its filename without
`.t.sol`. The listed tests execute the shown bodies; similar historical names
are not used as evidence without reading their bodies.

| Key | Exact file | Source assertions read |
| --- | --- | --- |
| H1 | `single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | `test_row_fixtureProductionBinding` 52-79; `test_row_bind_deploysThroughPackage` 93-110; `test_row_poolManagerSwap_bothDirections_noFaceResidual` 156-167; `test_row_previewMatchesExecution` 223-233; `test_composedRouteGasFitsCeiling` 236-240. |
| H2 | `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | `_seed` 57-69; `_cpDirections` 106-127; `test_row_rateTarget_currency1` 79-104; `test_row_faceProductIndex0/1` 264-278; `test_localPoolManagerExactOutputUsesNoSe` 169-179; `test_composedRouteGasFitsCeiling` 298-306. |
| H3 | `dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | `_seed` 401-414; `_crossVaultDirections` 416-455; `test_row_rateTarget_currency1` 457-472; `test_row_index0/1` 474-480; `test_row_identity_thisVault` 483-487; fixture tests 490-587; `test_row_nonmemberShareBinding_reverts` 611-619; `test_composedRouteGasFitsCeiling` 739-748. |
| H4 | `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | `_seedMixed` 103-116; `_directions` 118-152; `test_row_identity_pairToken` 155-159; `test_row_rateTarget_currency1` / `test_row_rateTarget_currency1_index1` 160-184; `test_row_index0/1` 185-200; `test_composedRouteGasFitsCeiling` 329-337. |
| H5 | `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | `_seedWeighted` 117-128; `_weightedDirections` 130-163; `test_row_rateTarget_currency1` 165-182; `test_row_index0/1` 183-198; `test_row_bind_deploysThroughPackage` 201-215; `test_composedRouteGasFitsCeiling` 284-292. |
| H5N3 | `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` | `_seedThree` 107-118; `_threeDirections` 120-157; `test_row_identity_pairToken` 160-164; `test_row_poolManagerSwap_bothDirections_noFaceResidual` 230-244; `test_row_previewMatchesExecution` 247-251; `test_composedRouteGasFitsCeiling` 266-274. |
| H6 | `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | `_seedCurve` 112-122; `_curveDirections` 124-157; `test_row_identity_pairToken` 160-164; `test_row_rateTarget_currency1` / `test_row_rateTarget_currency1_index1` 165-190; `test_row_index0/1` 191-210; `test_composedRouteGasFitsCeiling` 321-329. |
| H7 | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | `_seedBalancer` 148-159; `_balancerDirections` 161-196; `test_row_rateTarget_currency1` 198-215; `test_row_index0/1` 216-233; `test_row_bind_deploysThroughPackage` 236-244; `test_composedRouteGasFitsCeiling` 345-353. |
| H7N5 | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` | Entire 1-54; `test_row_identity_pairToken` 25-34, `test_row_rateTarget_currency1` 37-42, `test_composedRouteGasFitsCeiling` 45-53. The method named currency1 actually retains currency0; it is not second-target evidence. |

H3's same file contains `FullSpreadV4MatrixChecks:72-325`: independent membership
checks (234-238), share-funded seed preparation/actual burn and custody checks
(88-142), transaction gas measurement (148-168), actual refund transfer checks
(174-188), and negative hook exact-output custody checks (190-208).
`assertSeed` requires a positive floor and positive local receipt, but does not
independently calculate each family's rate-free seed function or exact fee
recipient balance. Those stronger assertions must come from other tests.

### Shared behavior and exact concrete component adapters

`HB` = `HT/HookComponentAccountingBehavior.sol`:
`HookComponentCustodyBehavior:9-30`,
`HookComponentAccountingBehavior:36-386`, and
`HookExactNetComponentAccountingBehavior:391-413`.

All references to HB LP tests below mean inheritance by the following exact
contracts, not independent execution of an abstract contract:

| Key | Exact file under HT | Exact concrete contract and applicable route |
| --- | --- | --- |
| CA1 | `single/UniswapV4SingleSEBufferHook_ComponentAccounting.t.sol:24-215` | `UniswapV4SingleSEBufferHook_ComponentAccounting`; inherits custody only. No LP product. |
| CA2 | `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ComponentAccounting.t.sol:16-121` | `UniswapV4SingleStandardExchangeBufferConstantProductHook_ComponentAccounting`; share deposit / ordinary deposit / withdraw; exact-net extension. |
| CA3 | `dual/UniswapV4DualSEBCPHook_ComponentAccounting.t.sol:22-322` | `UniswapV4DualSEBCPHook_ComponentAccounting`; share-flagged `depositFlexible`, ordinary `deposit`, `withdraw`; explicit unsupported exact-net rejection. |
| CA4 | `orbital/UniswapV4StandardExchangeOrbitalBufferHook_ComponentAccounting.t.sol:21-416` | `UniswapV4StandardExchangeOrbitalBufferHook_ComponentAccounting`; three-leg flexible/add/remove; explicit unsupported exact-net rejection. |
| CA5 | `weighted/UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting.t.sol:31-493` | `UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting`; two-leg proportional flexible joins/exits; exact-net extension. |
| CA5N3 | Same file `496-524` | `UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting_N3`; inherits CA5 tests on three legs. |
| CA5N8 | Same file `527-692` | `UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting_N8`; separate eight-leg setup, one FullSpread leg and seven raw legs; inherits shared exact-net behavior, not all CA5-specific alias tests. |
| CA6 | `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_ComponentAccounting.t.sol:26-789` | `UniswapV4StandardExchangeCurveQuadStableBufferHook_ComponentAccounting`; four-leg proportional flexible joins/exits; exact-net extension; additional alias tests. |
| CA7 | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting.t.sol:25-403` | `UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting`; two-leg LiquidityUnits flexible joins/exits; exact-net extension. |
| CA7N5 | Same file `405-410` | `UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting_N5`; inherits CA7 tests after `_initializeBalancer(5)`. |

Other exact keys:

- **DA**: `HT/dual/UniswapV4DualSEBCPHook_ComponentAliases.t.sol:16-393`,
  contract `UniswapV4DualSEBCPHook_ComponentAliases`. Real ERC4626 SE proxies,
  not FullSpread SEs; separate alias control.
- **OB**: `HT/orbital/UniswapV4StandardExchangeOrbitalBufferHook_ComponentBoundaries.t.sol:13-161`,
  contract `UniswapV4StandardExchangeOrbitalBufferHook_ComponentBoundaries`.
  Family TestBase, not the FullSpread matrix adapter.
- **FC**: `HT/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FeeCapital.t.sol:13-224`,
  contract `UniswapV4SingleStandardExchangeBufferConstantProductHook_FeeCapital_Test`.
  Family TestBase, not the FullSpread matrix adapter.
- **L**: `test/foundry/spec/hooks/uniswap/v4/libs/UniswapV4HookComponentAccounting.t.sol`,
  contract `UniswapV4HookComponentAccountingTest`. Pure arithmetic and external
  dependency harness; not a live hook.
- **LL**: `test/foundry/spec/hooks/uniswap/v4/interfaces/UniswapV4SeBufferHookLegLib.t.sol`,
  contract `UniswapV4SeBufferHookLegLibTest`; helper harness, not a live hook.

Important oracle limit: `HB._hbSnapshot:71-96` reads **physical ERC20 balances**,
LP/share supply, actor balances, and allowances. It does not read every family's
separate stored local/share books. `HB._hbAssertContributions:245-258` independently
checks ceil and nondilution on those physical quantities in fixtures without
ambient custody. Ambient tests compare excess physical custody against a control.
Do not describe HB alone as a complete independent ghost-book proof.

## Exhaustive 48-row source inventory

| Acceptance | Exact current source tests and assertions actually enforced | Missing load-bearing assertion / source limitation | Pure/live-proxy status and supersession |
| --- | --- | --- | --- |
| FS-A01 | P.`test_everyPackageSelectorIsInstalledOnItsDeclaredFacet` (210-241) checks 12 cuts, 45 selectors, unique routing, vaultTokens-only basic facet and custom reserve routing. P.`test_reviewedSelectorManifestIsComplete` (244-296) independently lists current product selectors. P.`test_selectorCutAndCraneGetters` (386-466), `test_pairedPreviewsAndRemainingSySelectorsAreAbsent` (121-141), `test_getRateAndAssetAreAbsent` (143-148), `test_craneAwareGettersMatchPackageAndPositionBindings` (318-333), and `test_packageMetadataConfigAndSaltMatchBindings` (299-315) enforce omitted old routes, factory/proxy separation, callable factory introspection/loupe, and Crane getter bindings. | The 45-selector manifest includes route presence/routing, not successful execution of every mutator with valid arguments. The temporary postDeploy route is checked absent/unusable after initialization, not claimed permanently callable. No additional manifest gap identified in the named bodies. | Live-proxy source plus real facet declaration checks. Legacy 61-selector count and family getRate/SY expectations are superseded; do not restore them. A12-A16 receive no passing credit. |
| FS-A02 | P.`test_bindingHashChangesWithAnyBinding` (468-563), `_changed` (687-700) mutate all 12 facet inputs, seven protocol addresses, registry, oracle, WETH, diamond factory, and six libraries. Each coherent changed package is deployed through the manager and compared with `keccak256(abi.encode(init_))`; linked family facets are relinked for changed libraries. | No additional binding-input gap identified. Not evidence that old runtime artifacts match current source. | Real package construction, not pure hash-only coverage. No superseded current test identified. |
| FS-A03 | P.`test_invalidComponentRevertsBeforeDiamond` (565-585), `test_missingComponentsRevertBeforeDiamond` (588-607), `test_mismatchedLinkedComponentsRevertBeforeDiamond` (610-616) reject selected infrastructure/link mutations through the real registry. `_expectComponent` (748-763) asserts no package code and unchanged vault registry. P.`test_badPoolWrongCallerAndSecondInitRevert` (619-633) rejects hooked/uninitialized pools, wrong caller and registry-in-wrong-account processArgs; `_assertDeployReverts` (635-648) checks predicted vault has no code/package registration. P.`test_noUnprivilegedPostDeployInitializationSurface` (362-384) rejects direct lifecycle entrypoints. | **Missing actual second initialization attempt reaching `AlreadyInitialized`.** Line 618 explicitly says redeploy is idempotence, not this coverage. Constructor invalid-component loops cover six ancillary infrastructure fields and six linked mismatches, not an individually invalid/missing test for every facet/core binding. No forbidden-selector injection test was found in P. Do not equate direct `InvalidInitializationContext` with double-init coverage. | Live package/proxy negatives, partial. Misleading `SecondInit` test name is retained but is not proof of second-init rejection. Removed rateAsset/wrappedNative/zap argument negatives are superseded. |
| FS-A04 | P.`test_storageSlotIsNotPairTokenOrWings` (650-659) derives the three namespace constants, asserts FullSpread differs, and checks against the actual imported repo constants. H3.`test_fixture_twoFullSpread_deploymentsAndMembership` (490-514) additionally observes distinct live vaults and positions. | Literal PRD slot inequality is asserted. **Authorized plan's stronger multi-instance storage-isolation test is missing:** mutate one deployed instance via a money/book operation and assert the other's supply, books and configuration unchanged. Distinct addresses/positions alone do not establish that. | Pure slot proof; live fixture observation only. No superseded test identified. |
| FS-A05 | P.`test_bootstrapBundleDepositMintsShares` (54-73) is a broad smoke. O.`test_M14_genesisFloorPositionAndFeeAreNotExtraIssuance` (942-963) asserts exact zero-address 1000 floor, totalSupply equals actual added liquidity, clamped 30% fee from gross excluding floor, full-range salt-zero diamond position and pool liquidity. O.`test_M04_firstMintFloorIncludesZeroAndPretransferOvermax` (518-539), `test_M04_firstUnwantedBoundaryAndOutsideMintRevertsFloor` (542-560), `test_inventory034_preexistingBalancesDoNotInflateGenesis` (1232-1253) enforce floor rejection/empty state and ambient exclusion. | Genesis exact fee equation is exercised through the bundle route; the first one-sided mint does not get the same independent genesis fee/floor equation in the named test. That route remains a concrete integration assertion to add, not a new Hook 5% rule for this vault. | Live-proxy source. Broad `totalSupply > depositor` smoke alone is insufficient; exact O test supplies stronger evidence. Hook LP FS-A48 genesis is a different product. |
| FS-A06 | Q.`test_bundlePreviewMatchesExecution` (80-104), `test_bundleExitPreviewParityBothCallerOrders` (175-195); M.`test_bundleOutPaysBothFaces` (130-146), `test_bundleOutMinimumUsesCallerIndex` (198-209); O.`test_M10_bundleOutBothOrdersAndEachMinimumIndex` (776-807) and `test_M11_bundleBooksFeesAndRefundsInVaultTokenOrder` (810-842). O checks zero swaps on both bundle entry and exit, indexed minima rollback, ordered recipient deltas, refund tuple and pair markers. | Q parity uses the SUT preview as expected output; it is not by itself an independent FS-OWN-30 amount oracle. O's no-swap/order checks close that distinct requirement. An independent fee/book formula for a nonzero-fee bundle exit is not present in these bundle-specific tests (see A08). | Live-proxy source. Old depositPair/redeemPair selectors are superseded, not missing positives. |
| FS-A07 | O.`test_M01_P01_eachFaceMintUsesWhole49PercentAndNetPreview` (444-475) checks both faces, one actual 49% swap, add consumes swap output, full pull and payer refund, recipient net. `test_M03_collapsedAndPartialQuoteRefundWholeInput` (500-515), `_collapsedMint` (1319-1329) require no swap/add and full refund when unusable. `test_M07_partialPassThroughRefundsUnusedInputBothWays` (701-731) requires real partial spend/refund and unchanged supply/liquidity. `test_M11_bundleBooksFeesAndRefundsInVaultTokenOrder` and `test_M15_pullFullDeclarationBeforeRefundToPayer` (1008-1022) check fee booking, raw-liquidity gross issuance, refund recipient/order and no extra mint. `test_M15_pretransferMaximumAndOvermaxDoNotSpendBookedInventory` (1025-1054), bundle pretransfer tests (1057-1113), and F.`testFuzz_oneSidedPreviewMatchesExecution` cover maxima, full refunds and output-token isolation. | No additional load-bearing refund gap identified in these source bodies. Refund-preview equality in fixed-state tests is stronger than the PRD's general promise and must not be generalized across changed availability. | Live-proxy source; F is integrated fuzz source, not a pure proof. Quadratic optimal split, IncompleteConversion, and booking unused user input are superseded. |
| FS-A08 | O.`test_M09_exitBothFacesPaysFourPartExecutedReceipt` (752-773), `_exitClaim`/`_fourPartExit` (1399-1444) independently compute floor principal/fee/book claims, read actual executed swap receipt, assert full opposing claim sold, requested recipient paid, staying holders' exact booked remainder, supply burn after receipt, and minimum rollback. O.`test_M08_incompleteExitBothFacesDoesNotBurnOrSwapStayingInventory` (734-749) hashes custody/position/pool state across incomplete conversion rejection. Q.`test_exitPreviewParityWithBookedAndUnpaidFees` (147-172), U.`test_borrowedExitToken0ReceiptMatchesLockedFromSameState` / `test_borrowedExitToken1ReceiptMatchesLockedFromSameState` (264-374) add preview and dispatch parity. | Bundle exits with independently calculated nonzero booked + unpaid fee claims are not separately asserted by M10/Q's preview-only bundle oracle. Add that concrete two-token claim test; it must assert no swap and the continuing-holder remainder. | Live-proxy source, strong one-token coverage; bundle amount-oracle gap. The earlier principal-only `_assertExitReceipt` helper (1641-1689) is not used as the four-part proof. Principal-only receipt economics are superseded. |
| FS-A09 | M.`test_enabledExchangeOutIsAbsent` (190-196); Q.`test_getRateAndExchangeOutAreAbsent` (317-339) records caller/vault both-face balances and caller shares, zero inverse preview, expected enabled `ExchangeOutNotAvailable`, and unchanged custody. O.`test_M13_disabledRouteMatrixAndEnabledOutRollback` begins with enabled exact-out and `_custody` equality (883-890). | Typed one-word inverse signatures exercise the existing ABI; no low-level return-length assertion specifically pins inverse preview to 32 bytes. No new refund ABI should be inferred. | Live-proxy source. Disabled exact-out is not the enabled-negative fixture. Old exact-output success expectations are superseded. |
| FS-A10 | N.`test_publicMoneyRejectsValue` (90-104), `test_wethFaceDepositsAgainstNativeCurrency` (106-118), `test_allPublicRouteBoundariesAreNonpayable` (170-205) cover WETH face deposit, no caller ETH movement, all 12 route/view/appointment value dispatches rejecting with empty returndata, unchanged vault ETH. N.`test_borrowedNativeCreditPaysWethOnly` (150-167) verifies actual WETH payment and zero raw ETH to caller/vault. | No caller-facing native-success requirement exists. These bodies do not separately exercise a native-pool share redemption to WETH with a distinct payout recipient; tested native-credit payout is pass-through. | Live native-pool/proxy source. Raw-native input/payout success and wrappedNative getter expectations are superseded. |
| FS-A11 | O.`test_M09_exitBothFacesPaysFourPartExecutedReceipt` checks exact remaining books; `test_M11_bundleBooksFeesAndRefundsInVaultTokenOrder` asserts fees stay locally booked and issuance excludes them; `test_M07_passThroughBothWaysAndMinimumRollback` (667-698) asserts no collect/add/remove, no supply/fee-LP/book change. U exit parity tests compare exact receipts and post-state across dispatches. | Named deposit/withdrawal tests do not explicitly `expectCall` zero compound calls or reject a `Compounded` marker on those routes. Their amount/position/book assertions constrain unintended deployment; add direct no-maintenance-dispatch/event assertion if closing the entire "do not call compound" claim rather than only economic effects. | Live-proxy source, economically strong but no direct compound-call-count assertion. Automatic compound and sleeve fallback expectations are superseded. |
| FS-A12 | **Withdrawn.** No positive test is assigned. P's selector exclusions belong to A01. | No replacement test is required or permitted to restore SY exchangeRate. | Withdrawn, not passed. |
| FS-A13 | **Withdrawn.** No positive test is assigned. P/Q/B's getRate absence tests belong to A01/A29. | No vault rate implementation or former one-share formula is required. | Withdrawn, not passed. |
| FS-A14 | **Withdrawn.** No positive test is assigned. | Do not add InsufficientRateSupply behavior or below-one-share rate tests. | Withdrawn, not passed. |
| FS-A15 | **Withdrawn.** No positive test is assigned. | Do not observe planner failures through getRate. | Withdrawn, not passed. |
| FS-A16 | **Withdrawn explicitly on 2026-11-06.** No positive test is assigned. | Do not add an issuance-does-not-read-exchangeRate test. GetRate absence is not this row. | Withdrawn, not passed. |
| FS-A17 | C.`test_lockedMintOneUnlockAndConsumedCallbackPerAction` (96-108), `test_lockedExitOneUnlockAndConsumedCallbackPerAction` (111-125), `_expectTwoLockedActions` (180-186), `observeSettlement` (149-173), `_assertGuardAndCommitmentLifetime` (189-216) assert two unlocks; two successful callbacks plus two deliberate rejected replays; one swap/modify; exact payload replay rejection; one guard lifetime and two commit/consume cycles. C.`test_borrowedMintDoesNotDispatchUnlockOrCallback` (128-146) expects one outer caller unlock and zero vault callback. U same-state exits also expect only the outer unlock and no vault callback (317-330). | No additional dispatch-count gap identified. Callback count four must not be reported as four successful callbacks. Borrowed count one is the outer router's unlock, not a vault unlock. | Live proxy/real PoolManager with non-SUT transfer probe; storage is observed, not injected. Old one-unlock-per-public-call assumption is superseded by per-action dispatch. |
| FS-A18 | C.`test_strangerCallbackReverts` (75-86) expects SettlementMismatch and checks supply, position liquidity and both vault token balances. `test_uncommittedPayloadReverts` (88-93) impersonates the real manager and rejects uncommitted data. `observeSettlement` rejects exact payload replay after consume while guard remains held. | Stranger case asserts vault custody but not caller/manager token balances; uncommitted case asserts only revert, not full state equality. Concrete strengthening: compare caller, vault, manager custody and position before/after both direct callback negatives. | Live-proxy source, partial atomic-restoration assertion. No superseded test identified. |
| FS-A19 | U.`test_borrowedExchangeInMintsAndClearsDeltas` (167-186) verifies real minted receipt, only outer unlock, zero callback. `test_borrowedExchangeLeavesForeignDebtOpen` (189-202) records zero vault delta, nonzero global count and manager still unlocked at inner return. Same-state exit tests (264-374) verify diamond full-range salt-zero position, exact receipt, and both touched delta zeros. | In `test_borrowedExchangeInMintsAndClearsDeltas`, delta checks happen after outer unlock; the foreign-debt helper records at inner return only the context currency's vault delta. Add an inner-return observation of **both** vault backing-currency deltas for mint and exit to prove the entire before-return claim directly. | Live-proxy source. No nested-unlock or global-delta-zero requirement is introduced. |
| FS-A20 | U.`test_borrowedPretransferReverts` (510-523) pins InvalidUnlockedContext; `test_borrowedUnfundedCallerAndUnownedSharesRevert` (447-464) rejects unfunded mint despite allowance. N.`test_allPublicRouteBoundariesAreNonpayable` verifies empty ABI-boundary rejection for value. | Value negatives in N are ordinary calls, not an already-unlocked contract forwarding value. Add that borrowed-context value case if claiming both dispatch contexts explicitly. It must not expect an invented internal msg.value error. | Live-proxy source, partial context combination. No superseded funding rule is credited. |
| FS-A21 | U.`test_borrowedUnfundedCallerAndUnownedSharesRevert` asserts unfunded mint rejection, exact ERC20InsufficientBalance on unowned share exit, unchanged supply and zero attacker LP. O.`test_M15_directAndStagedTransfersDoNotCreateLaterCallerCredit` (1091-1113) separately protects parked vault-held shares and unbooked faces from an unfunded later caller on locked dispatch. | U's negative does not separately park another holder's shares on the vault before the borrowed call; the locked parked-share test cannot be called borrowed-specific coverage. Add that concrete combination for complete cross-context authority coverage. | Live-proxy source. Unlock is not funding authority; parked-share credit success is superseded/forbidden. |
| FS-A22 | U.`test_borrowedBundleRevertsAlreadyUnlocked` (493-508), `test_borrowedBundleOutDonateAndCompoundReject` (467-484) pin all four ManagerAlreadyUnlocked negatives. Maintenance caller is actually appointed by live feeTo first. P selector exclusion tests cover removed pair/SY routes. | Revert tests do not compare a complete custody/position snapshot for each of the four rejects; no such equality should be inferred from the test names. | Live-proxy source. Removed pair/SY mutators require absence, not borrowed success. |
| FS-A23 | U.`test_caughtBorrowedMinimumFailureRestoresVault` (220-242), `test_outerFailureRestoresBorrowedSwap` (245-261), `test_borrowedSettlementMismatchRestoresAllVaultEffects` (404-444) check restored supply/liquidity/shares, caller and vault/pool balances for their respective failure modes. SettlementMismatch uses a non-SUT token making a real sync clobber call. | Caught minimum test does not compare caller token1 (which includes its intentional outer debt transfer), allowance, or both inner per-address deltas; outer-failure test omits vault local token balances. Extend the exact snapshots, preserving the outer caller's intentionally retained prior effects. | Live-proxy source, partial full-state inventory. No sleeve rescue or swallowed vault failure is accepted. |
| FS-A24 | HB custody `test_HB40_memberPairsSeparateFromImplicitShares` (14-29) verifies real pair membership and absent own-share membership across CA1-CA7 topologies. H3.`test_fixture_twoFullSpread_publicSharesAndRedemption` (517-545) loops both members of both real vaults, mints publicly, burns exact shares, pays a different recipient and checks positions/deltas. H3.`test_row_identity_thisVault` now invokes `_crossVaultDirections`, not an identity reject. H1 binding/swap tests and CA1.`test_HB41_conversionPreservesAttributedAndAmbientCustody` (133-167) verify actual own-share mint/redemption with valid pair. | A direct same-token share-to-share revert in B.`test_identityAttemptDoesNotBurnCallerPosition` (205-225) is only an invalid-route negative; it cannot replace this positive. No additional own-share positive gap identified in the named source. | Live-proxy source. Self-membership requirement and asset wrapper exception are superseded. Historical identity test names remain, but their bodies now prove valid member bindings. |
| FS-A25 | H1 both-direction swap/preview bodies; H2 `_cpDirections`; H3 `_crossVaultDirections`; H4 `_directions`; H5 `_weightedDirections`; H5N3 `_threeDirections`; H6 `_curveDirections`; H7/H7N5 `_balancerDirections` assert recipient deltas, real SE supply increase/decrease or explicitly local-only payment, preview/execution parity. `VT/BufferHookIntegration.t.sol` contracts `UniswapV4FullSpreadStandardExchangeVault_{Single,Dual,Orbital,Weighted,WeightedThree,Curve,Balancer,BalancerFive}Unwrap_Test` have exact `test_{single,dual,orbital,weighted,weightedThree,curve,balancer,balancerFive}UnwrapApprovesAndCompletesExit` bodies (229-306), using `FullSpreadUnwrapChecks:42-74` to check approval event, actual SE burn and face payment. | Unwrap helper only checks positive payment/burn/approval, not exact fee/book entitlement, manager call counts, ticks/salt or both positions. H3 has stronger separate position/delta assertions; do not copy that strength onto every family. Family `_directions` branches allowing local-only output do not prove an SE redemption in that branch. | Live-proxy source, partial full cross-family position/fee assertions. B's comment at 77 and DualUnwrap comment at 239 still describe the retired identity blocker; current H3 fixture no longer uses that invalid bind. |
| FS-A26 | H3.`test_row_index0`, `test_row_index1`, `test_row_rateTarget_currency1`, `test_row_identity_thisVault`, `test_row_bind_deploysThroughPackage`, `test_row_poolManagerSwap_bothDirections_noFaceResidual`, `test_row_previewMatchesExecution` reach `_crossVaultDirections:416-455`. It asserts forward mint primary/burn sibling, reverse burn primary/mint sibling, recipient output parity, primary diamond-owned full-range salt-zero position, and a 5-by-5 address/currency delta grid. Fixture test 490-514 explicitly checks distinct hookless backing keys and each position/provider. | `_crossVaultDirections` itself checks the primary position after execution, not a before/after identity snapshot of both positions. Fixture checks both before use; add post-operation sibling position identity checks for the full two-position assertion. No same-backing-pool implication follows. | Live two-FullSpread proxy source. The 12 old dual identity-gated instances and inherited copies now have positive bodies; no runtime migration count is claimed here. |
| FS-A27 | All nine H matrix keys have source-backed positive seeding/binding and swap bodies listed above. H1 has one conversion leg, H2 one SE plus raw, H3 two SEs, H4 three legs, H5 two, H5N3 three, H6 four, H7 two, H7N5 five. CA5N8 extends shared component cases to eight legs. `test_row_identity_pairToken` in H4/H5N3/H6/H7N5 now calls membership + positive seed/directions. | This is topology source coverage, not complete execution of all inherited cases or every facade. No early identity reject is accepted as positive coverage. The raw leg is not another vault conversion. | Live-proxy source, runtime pending. Conversion-only H1 LP cases are structurally inapplicable, not early-returning passing LP tests. Old invalid sibling prerequisites are superseded. |
| FS-A28 | CA1.`test_HB41_retainedCustodyDoesNotInventExactOutputRoute` (75-90) expects the wrapped FullSpread ExchangeOutNotAvailable in both directions and compares custody. B.`test_exactOutHookPaysNeitherToken` (183-203), H3 `_exactOutNegative` (676-686), and `FullSpreadV4MatrixChecks.hookOut` (190-208) assert no payment/custody change for deliberately unavailable output. H2.`test_localPoolManagerExactOutputUsesNoSe` (169-179), CA3.`test_H3_exactLocalEqualityLeavesMixedZeroComponent` (166-189), CA4/5/6/7 equality cases prove available local output without an SE burn; CA4 additionally expects zero SE exchangeOut calls. | Broad `expectRevert()` in B/H3/helper can also pass on sizing/budget rejection before the SE call. For those families add a negative that proves the unavailable SE selector is actually reached (expected wrapped error/call), then checks all books/supply/custody. B's fixed 1-token request is not guaranteed to exceed today's local book. | Live-proxy source, strong H1 selector-specific negative, partial other-family reachability. Blanket "all hook exact-output must fail" is superseded; local-only exact-output success is allowed. |
| FS-A29 | P/Q getRate absence; B.`test_getRateAbsentAndProviderReadsTuple` (148-153) checks absent vault getRate and positive external currency0 provider. H3.`test_fixture_twoFullSpread_deploymentsAndMembership` and `test_fixture_memberOrientationsAndTargets` (548-566) check real provider address, reserveVault, target and two separate hook pools. H2/H3/H4/H5/H6/H7 `test_row_rateTarget_currency1` bodies configure the second provider and execute positive routes; H4/H6 also exercise index1 explicitly. | Positive provider result proves successful consumption, not a low-level 64-byte-width assertion on the provider itself. H7N5's method named currency1 actually asserts currency0 (37-42); second-target proof comes from H7, not that method. H1 does not have a second-target rebind operation in its inspected matrix body. Do not count a filename or method name as that missing H1 execution. | Live provider/vault/hook source, partial per-configuration target coverage. Vault getRate and full-book provider-as-vault-rate are superseded. |
| FS-A30 | H3 fixture explicitly asserts distinct backing keys (497-501); shared pair helper (219-231) enforces disjoint faces/keys. This audit records their scope. | **Same-backing-pool sequential composition remains unverified.** It is not a missing required positive test to invent here; the row requires accurate reporting, not claiming that composition passed. Parent must preserve this boundary in runtime evidence. | Record; no runtime pass claimed. No superseded test identified. |
| FS-A31 | Every H1-H7N5 `test_composedRouteGasFitsCeiling` listed in the matrix key table calls shared `coldSwap:148-168`, requires isolate mode, adds calldata intrinsic gas to actual router frame gas, verifies measured SE supply increases, and caps at 12m. B override 80-91 does the same. M `test_gasOneSidedMintFitsCeiling`, `test_gasOneTokenExitFitsCeiling`, `test_gasPassThroughFitsCeiling`, `test_gasBundleInFitsCeiling`, `test_gasBundleOutFitsCeiling`, `test_gasDonateFitsCeiling` (213-265), MG.`test_gasCompoundFitsCeiling` (335-341), and Q preview gas tests (198-209,287-315) provide vault-only ceilings. | Source is not gas evidence. Composed gas tests measure one exact-input mint direction per configuration, not a separate cold composed redemption transaction. Family swap preview calls in `_directions` are not independently capped at 5m in the inspected matrix bodies; Q's vault preview cap is not a hook-preview cap. Parent must supply those missing route measurements or record them unresolved. | Live measurement source only; no numeric runtime result. Setup gas, warm quote measurements and failed prerequisites cannot be substituted. |
| FS-A32 | Q.`test_economicViewsDisabledAndUnlocked` (212-225), `_assertEconomicViews` (227-251) independently compute deployed principal + unpaid fee, compare reserves/per-token reserves, nonmember zero, positive mint/exit/pass previews, then repeat disabled and inside manager unlock. `test_unsupportedPreviewIsZero` (106-109) checks output and refund zero. A09 supplies unsupported inverse view. | Nonzero booked/unbooked local custody is not staged for the reserve-exclusion assertion. Bundle economic previews are not exercised by `_assertEconomicViews` while disabled/unlocked. Add those concrete cases, rather than interpreting ordinary bundle parity as busy-context coverage. | Live-proxy source, partial full economic-view inventory. No last-committed local snapshot or getRate view is required. |
| FS-A33 | U.`test_borrowedExitToken0ReceiptMatchesLockedFromSameState`, `test_borrowedExitToken1ReceiptMatchesLockedFromSameState` and `_assertExitReceipt` (272-331) restore one economic snapshot, compare both actual recipient receipts and refund words, supply/liquidity, requested principal+fee+book+executed swap, and reject minimum+1 atomically. U.`test_borrowedPassThroughBothDirectionsMatchesLockedReceipt` (377-401) compares actual output/refund and unchanged supply/liquidity in both directions. | No same-state **mint** comparison of locked and borrowed receipt/refund/gross-fee supply was found in U. The borrowed mint positive and ordinary mint preview tests are separate states, not dispatch-parity proof. | Live-proxy source, exit/pass-through coverage; mint parity gap. Sleeve/collection-only/performance-fee behavior is superseded. |
| FS-A34 | U.`test_borrowedNonzeroOwnDeltaBareReverts` (205-217) creates actual vault credit through settleFor and expects bare rejection; `test_borrowedExchangeLeavesForeignDebtOpen` (189-202) records foreign debt at inner return, zero context-currency vault delta, global count one, unlocked flag true, and outer caller settles its own debt. | Nonzero own **credit** is exercised, not own negative debt. Both touched currency deltas are not simultaneously recorded at the inner-return boundary (see A19). Add that second-sign/context observation if closing all nonzero-own-delta cases. | Live-proxy source, partial sign/boundary matrix. Global count zero is not required. |
| FS-A35 | N.`test_borrowedNativeDebtPreservesForeignCreditAndBacking` (121-147) creates a real foreign 3 ETH-equivalent ERC20 credit and stale ERC20 sync, expects one native sync/value settle, verifies exact WETH debit, exact output excluding foreign credit, single pool-native increase, unchanged vault WETH/native. N.`test_borrowedNativeCreditPaysWethOnly` plus `_assertNativeContext` (215-220) verify WETH-only credit payout, zero vault touched deltas at inner return, foreign credit preserved and global count one. | No additional load-bearing native sync/credit-isolation gap identified in these source bodies. They are pass-through settlement tests; native share exit is a separate A10 limitation. | Live native-pool/proxy source. No raw ETH caller payout success is claimed. |
| FS-A36 | U.`test_outerFailureRestoresBorrowedSwap`, `test_caughtBorrowedMinimumFailureRestoresVault`, caller machinery `UnlockedExchangeCaller:67-141`, and `test_borrowedSettlementMismatchRestoresAllVaultEffects` prove propagated/caught/sync-clobber scenarios. Caller records debt and unlocked state before repaying its own debt with exact settle amount. | Caught test records the intentional debt but does not assert every prior token1 delta and both vault deltas at the inner boundary; propagated failure does not hash all vault local custody. Complete the state comparisons named in A23 rather than claiming the entire state inventory from selected balances. | Live-proxy source, partial full restoration inventory. No "catch relocks manager" assumption. |
| FS-A37 | U.`test_borrowedExchangeInMintsAndClearsDeltas` uses a newly deployed funded `UnlockedExchangeCaller` with actual approvals; C borrowed mint also uses that non-hook caller. No allowlist is configured by these test setups. | No additional funded-contract-success gap identified. This does not waive funding/approval/context checks or prove code-less callers can borrow the unlock. | Live-proxy source. A new allowlist is not required. |
| FS-A38 | M.`test_disabledVaultBlocksDepositAndAllowsExit` and `test_deadlinePrecedesDisable`; O.`test_M13_disabledRouteMatrixAndEnabledOutRollback` (883-939) checks disabled pass-through/bundle deposit/inverse rejects, withdrawal and maintenance success, auth/recipient/minimum checks, deadline-before-disable and live views. B.`test_disabledBufferedWithdrawalApprovesAndCompletesExit` (94-101) checks real burn/approval/payment; HB disabled address/package flows (348-376) and CA1 disabled conversion bodies check positive local booking/permitted exits. | **B.`test_disabledBufferedMintRevertsWhileUnlockedAndRollsBack` (104-122) is stale:** it still requires blanket disabled-hook input failure, contrary to FS-HOOK-06 local input booking. Replace with positive local hook execution plus a distinct direct disabled-SE nonwithdrawal negative. Vault O's address-disable matrix does not itself cover package-disable or a direct prohibited SE call made inside an outer unlock. HB only checks underlying supply unchanged, not explicit zero forbidden-deposit call count. | Live-proxy source, partial; stale current negative is not acceptance. Enabled exact-out remains its separate A09 negative. No cleanup redeposit should be required for disabled pair exits. |
| FS-A39 | O.`test_M16_liveFeeToAndGlobalAndFunctionOperators` (1116-1162) uses actual manager feeTo, grants global/donate-only/compound-only, checks both global operations, selector separation, stranger compound rejection, operator cannot appoint, old owner loses appointment rights after real feeTo update, new owner revokes and appoints, revoked global fails. O.`test_M12_M17_emptyFreshAndRevertingMaintenanceMarkers` supplies stranger donate rejection. | **Direct maintenance authorization after feeTo change is not asserted:** old owner's donate/compound should fail and new owner's funded donate/compound should succeed. Current test proves live appointment authority, then succeeds through an appointed operator, not direct new-owner maintenance. Add those exact calls. No separate Permissions.t.sol exists; that filename's absence is not itself a gap because this test is in Money.t.sol. | Live-proxy source; partial owner-transition maintenance matrix. Do not describe a stored-owner check as equivalent. No superseded test identified. |
| FS-A40 | LL.`test_pairMembership_ownShareIsImplicitAndSeparate` (160-170), `test_pairMembership_nonmemberAndUnavailableListReject` (172-180) and `test_addPairSe_assetAnswerDoesNotWaiveMembership` (148-158) cover helper membership, implicit shares, missing/reverting lists and an asset-answering nonmember. HB custody test runs through CA1-CA7. H3.`test_row_nonmemberShareBinding_reverts` pins package TokenNotInVaultTokens. Seven family round-trip tests are named below. FullSpread positive matrices use a vault with no asset selector. | Seven family round-trip tests call the SE directly and observe valid membership; they are not seven independent bad-binding/probe-negative package tests. LL's fixture has reverting asset(), but successful views cannot prove a static probe never occurred and was caught. Concrete missing matrix: pass absent/reverting-list and asset-answering-nonmember bindings through **each** family's package validator, asserting no deployment; use a probe-sensitive dependency to distinguish no probe from a swallowed probe if claiming that exact absence. | Mixed unit helper and live proxy source; partial all-validator-negative coverage. Wrapper/asset shortcut and self-member rejection are superseded. |
| FS-A41 | HB.`test_HB41_ambientPairTransfersDoNotFundLaterJoin` (279-304), genesis ambient case (218-243), snapshots and minimum rollback; CA1 refund/ambient/outer rollback cases (41-105,133-167); CA3.`test_H3_realFullRefundBecomesPoolLocalInput`, `test_H3_realPartialRefundIsBookedOnceNotPaidToSwapper`, `test_H3_bookedLocalCannotSatisfyUnfundedOrShortPretransfer`, `test_H3_ambientSharesCannotSubsidizeLaterJoin`, `test_H3_outerUnlockFailureAndCaughtFailureRestoreBothBooks` (115-164,247-307). CA4 partial/all refund/late ambient/outer failure (146-179,360-415); CA6 partial/all refund (238-292); CA7 full/partial refund/outer rollback (150-199). | HB snapshot is physical custody, not an independent read of all stored books; it does not prove intermediate pending/refund reservations cannot be spent during reentry. Add a callback/reentry case at pending-intake/book-commit boundary with exact rollback and stored-book assertions through each applicable family. Full zero/partial/all refund distinctions are family-specific; do not infer all three from one shared test. | Live component proxies plus L receipt arithmetic unit tests. No complete stateful ghost-book proof claimed. Old whole-balance dust sweep and double refund credit are superseded. |
| FS-A42 | HB.`test_HB42_localOnlyOutputDoesNotRedeemSe` (306-319), `test_HB42_outputDeficitRedeemsOnlyAfterLocalBook` (321-333), disabled flow (351-376); CA3 exact equality (166-189), CA4 `test_component_exactLocalEqualityNeedsNoSeExactOutput` (124-144), CA5 `test_HB42_exactLocalEqualityUsesNoUnavailableExchangeOut` (156-177), CA6 `test_H642_exactLocalEqualityNeedsNoSeExactOutput` (435-452), CA7 `test_component_localEqualityExactOutDoesNotCallUnavailableSeOut` (201-224). Matrix direction tests compare quoted and delivered output and real supply changes. | Shared deficit case checks local exhaustion and exact SE burn delta, but does not independently calculate the deficit-to-share rounded spend. CA2 has below/above through HB and local PoolManager route, not an explicit equal-to-book boundary in its component adapter. Mixed-decimal normalization is not established by 18-decimal FullSpread rows; a separate scale test cannot be assumed without its assertions. Add the equality/independent-unit tests rather than generalizing parity. | Live-proxy source, partial numerical independent swap oracle. H1 is a conversion hop, not a synthetic CP reserve product. |
| FS-A43 | HB.`test_HB48_laterJoinUsesCurrentComponents` (175-184), `test_HB43_pairInputConversionBacksEveryAcceptedComponent` (186-198), `_hbAssertContributions` check exact ceil inputs for gross supply increase and incumbent nondilution in CA2-CA7. DA.`test_H3_allFlexibleInputAndOutputFlags` / `test_H3_proportionalAndUnbalancedAliases` check common fractions. CA4 proportional/flexible/unbalanced/Permit2 cases (197-232), CA5 proportional alias case (237-253), CA6 ordered/listed basket cases (565-600) add real selector assertions. | **Pending interpretation for traded aliases.** DA.`test_H3_singleInputSeAndNativeSyAliases` and `_postTradeComponents` (133-250), CA4 single facades and post-trade oracle (234-340), CA5.`test_HB43_aliasBackingUsesPostTradeComponentSnapshot` / `test_HB43_shareAliasesPreservePostTradeBackingWhileDisabled` (345-450), CA6 traded-join oracle (27-193,294-377), CA7 `_postConversionBook`/alias test (264-337) use an incumbent book after internal swaps. They cannot settle the owner question. Also missing a live existing-supply same-component/same-caller-basket comparison before/after a real external rate movement across every adapter; HB rate-only test merely shows no LP was minted without a join. | Live-proxy source, plus L pure ceil/maximality proof. A43 full alias acceptance remains pending, not pass/fail decided here. Rated LP entitlement is superseded, but this audit does not choose the internal-swap snapshot order. |
| FS-A44 | HB.`test_HB44_twoHoldersExitOnlyTheirComponentFractions` (260-277) checks floor physical component debits, supply/balance burn and no protocol mint; it adds Bob but exits Alice once. CA3 disabled share-request rollback/pair success (191-206); DA flexible output masks (81-100) and protocol LP exit (354-374); OB.`test_component_shareRequestedExitIncludesAllocatedLocal` (91-108), protocol fraction (110-127); CA5 cross-leg aliases (304-324), CA6 exact-token and SE/SY exits (223-236,539-563), CA7 requested-share claim (226-242) and disabled share rollback (244-256) add output-mode coverage. | Shared test does not execute a second holder's later exit or reverse exit order, and only asserts recipient pair payout is positive, not independently its local+actual-redemption sum. Add repeated two-holder exits and independent exact payout/remaining-book assertions, including conversion/minimum failure, for the mapped family exits. Cross-leg tests mostly check output/supply/fee, not full reconstructed remaining components. | Live-proxy source plus L pure split-burn property. Swap-style rated local-first whole-LP payout is superseded. |
| FS-A45 | HB.`test_HB45_preownedSharesJoinWithoutDisabledMint`, `test_HB45_disabledAddressBooksInputAndPermitsExit`, `test_HB45_disabledPackageBooksInputAndPermitsExit` (335-376) cover both disable axes, permitted pair exit and non-mutating re-enable. CA1 both disabled axes/re-enabled wrap (169-205); CA3 pair-only disabled join reject/direct SE reject (208-221), equality zero-local (166-189); OB all-local disabled leg/re-enable next join (59-89); CA5N3.`test_HB43_partialBookCanAddAndOwnAnAllLocalDisabledLeg` (502-523); CA6 disabled pair join/reenable and share exit cases (195-208,386-433) add live zero/mixed books. | HB re-enable only observes no immediate book change; it does not run a later incoming join in every family. All-local/zero-share live coverage exists in OB and CA5N3, not every adapter. Share-funded disabled genesis is explicit in CA5/CA6, not part of the shared HB bootstrap tests. Add those concrete absent adapter scenarios; do not use a zero provider rate as a disabled-state oracle. | Live-proxy source, partial full family/zero-component matrix. H1 has custody/disable cases only, no LP-floor or genesis obligation. |
| FS-A46 | HB.`test_HB47_rateOnlyMovementMintsNoLp` (122-134) uses each adapter's real underlying market movement, asserts rate changed but hook physical S/L, LP supply and fee LP did not. `test_HB48_seedLpIndependentOfRedemptionPrice` (200-216) compares genesis LP across differing actual receipts. `HT/HookLiquidityInvariantHandler.sol:137-269,404-524` tracks actual actor LP, join/exit delivery, rollback and supply partition; dual/Curve concrete invariant wiring is cited below. | **Required sequence is not implemented by these tests:** same actor Hook join -> external underlying price/liquidity change -> Hook exit -> underlying-position unwind, with independent per-component ownership and separate conversion PnL. Handler `cycle` exits before its supplementary market/trade action; `_poolTrade` trades the hook product key, not the FullSpread backing pool; it has no per-component ghost entitlement/unwind oracle. Add the explicit production sequence for applicable families. Do not call LP balance conservation alone component-manipulation protection. | Live source and stateful source, partial; no complete A46 proof. No broader swap-manipulation safety claim. H1 has no Hook LP ownership sequence. |
| FS-A47 | L.`test_fee_workedExamplesAndGenesisFloor`, `test_fee_activationAndLimits`, `testFuzz_fee_splitAndExactNet`, `test_fee_fullWidthBoundary` (145-213) independently check split/inverse/minimality/floor/dust/limits. HB.`test_HB47_mintFeeSplitsBackedGross`, `test_HB47_rateOnlyMovementMintsNoLp`, exact-net extension `test_HB47_exactNetGrossUpMatchesExecution` (113-134,395-413) run on CA2/5/5N3/5N8/6/7/7N5; CA3/4 have `test_HB47_exactNetRejectedAndRollsBack` (310-321 / 111-122). FC new-capital tests (22-101), growth scaling tests (132-158), positive minimal exact-net (193-224), and infeasible full fee (177-190); DA all flexible/Permit2/protocol/inactive cases (56-131,285-392); CA4/5/6/7 additional alias and inactive/zero recipient cases assert fee+net=gross and no extra supply. | **Pending interpretation for single-input aliases that back against a post-trade snapshot**, as in A43; fee-split correctness does not resolve gross backing authority. HB checks exact fee arithmetic but no fee setting variation, fee dust, or zero-recipient branches itself. Family-specific tests cover subsets (CA5N8 only inherits shared cases). All-alias fee-off/dust/minimum-failure/genesis guard matrix is not supplied by one HB inheritance. No test assertion in this audit establishes that every obsolete production growth checkpoint or separate fee reserve consumer is gone; a no-deposit rate-move test does not inspect those consumers. | Mixed pure/unit and live-proxy source; full alias acceptance pending. H1 inapplicable. FC formerly no-fee-on-new-capital / deposit-size-independent fee expectations are superseded; current FC bodies now check scaled backed-mint fees. Never credit old growth issuance as passing A47. |
| FS-A48 | HB.`test_HB48_genesisRedeemsFivePercentOfShares`, `test_HB48_genesisFailureRollsBackEveryLeg`, `test_HB48_initialPairInputRejectedAtomically`, `test_HB48_seedLpIndependentOfRedemptionPrice`, `test_HB48_ambientCustodyDoesNotBecomeGenesisBacking`, `test_HB48_laterJoinUsesCurrentComponents` (136-243) run through CA2-CA7 and listed larger adapters. They assert actual SE supply burn A/20, retained shares, actor intake, positive pair receipt, raw exception, exact fee split and max-LP-minimum rollback. OB 19/20/21-share and below-floor tests (19-57) independently assert retained-share seed total. CA3 second-leg dust rollback (223-231), CA5 disabled/dust seed (194-213), CA6 disabled/dust/four-SE seed (386-408,624-664), CA7 dust/deadline rollback (357-374) strengthen integration. L.`test_bootstrap_actualReceiptAndRounding` / `test_bootstrap_incompleteOrShortReceiptReverts` (216-245) test incomplete/zero/false receipt arithmetic. | Shared tests don't independently calculate geometric/weighted/stable family seed outputs; equality under changed redemption price is not the whole seed-function oracle. Incomplete or zero actual proceeds are **unit receipt** negatives, not integrated partial-redemption rollback on every family. Explicit disabled initial redemption, mixed share/raw decimals, alias-first-pair rejection and failing-later-leg rollback remain incomplete across the mapped adapters. Add these exact FS-A48 scenarios, not new genesis economics. Share-funded aliases successfully seeding do not prove all pair-input aliases reject at T=0. | Live-proxy positive/rollback source plus pure receipt unit tests; partial complete family/alias matrix. H1 explicitly has no LP genesis. Former pair-funded/rated genesis and continuing 5% target are superseded; FullSpread vault genesis remains raw V4 liquidity, not this hook rule. |

## Additional exact binding-test identities

These seven methods share the exact name
`test_binding_memberPairAndImplicitOwnShareRoundTrip`. Their bodies were read;
each checks pair membership, omitted own share, positive direct SE mint,
exact caller share change, full share consumption on redemption, and actual
paired-token receipt. They call the SE directly, **not a hook swap or package
negative**:

| File under HT | Exact contract | Lines read |
| --- | --- | --- |
| `single/UniswapV4SingleSEBufferHook_Deploy.t.sol` | `UniswapV4SingleSEBufferHook_Deploy_Test` | 31-63 |
| `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy.t.sol` | `UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy_Test` | 34-86; also genesis test 35-53 |
| `dual/UniswapV4DualSEBCPHook_Core.t.sol` | `UniswapV4DualSEBCPHook_Core_Test` | 28-60 |
| `orbital/UniswapV4StandardExchangeOrbitalBufferHook_Binding.t.sol` | `UniswapV4StandardExchangeOrbitalBufferHook_BindingTest` | 17-136 |
| `weighted/UniswapV4StandardExchangeWeightedBufferHook_Deploy.t.sol` | `UniswapV4StandardExchangeWeightedBufferHook_Deploy` | 22-54 |
| `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_Deploy.t.sol` | `UniswapV4StandardExchangeCurveQuadStableBufferHook_Deploy` | 19-51 |
| `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Deploy.t.sol` | `UniswapV4StandardExchangeBalancerQuadStableBufferHook_Deploy` | 19-51 |

## Concrete findings to carry into task 18

1. **A03 repeat initialization is not tested.** P:618-633 labels the second deploy
   idempotent and never exercises AlreadyInitialized. Wrong-context init tests
   are not its replacement. Required test: an authorized initialization-context
   replay through the real package/factory path, with rejected second init and
   unchanged instance state.
2. **A04 has a valid pure namespace proof, not plan-required live isolation.**
   P:650-659 proves constants differ; H3 proves two instances exist. Required
   plan test: change one vault via real calls and assert the other vault's
   configuration, supply and booked state unchanged.
3. **A38 retains a superseded blanket hook revert.** B:104-122 requires disabled
   buffered input swap to revert. The current rule permits local input booking.
   Keep direct disabled-SE rejection, but test it separately from a successful
   hook-local operation. This is a source conflict, not a claimed runtime failure.
4. **A39 live appointment coverage is real and already in Money.t.sol.**
   Do not file "missing Permissions.t.sol" as a functional gap. The missing part is
   direct old-owner/new-owner maintenance execution after changing feeTo, not
   appointment or function-selector separation.
5. **A33 missing same-state mint dispatch parity.** Exit parity includes real
   four-part receipts in both faces and pass-through parity covers both directions.
   Add locked-versus-borrowed mint net/refund/fee/supply comparison from one snapshot.
6. **A08 bundle fee/book entitlement lacks an independent amount oracle.**
   One-token M09 coverage is substantially stronger than the preview-only
   bundle output check. Add exact nonzero booked + unpaid claim and continuing
   remainder assertions to bundle exit in both caller orders.
7. **A31 source measurements are not runtime receipts, and their scope is narrow.**
   Cold helpers measure one composed mint transaction, not all composed exits.
   Ordinary family preview parity does not assert the 5m gas ceiling. Parent
   needs route-specific executed measurements before closing this row.
8. **A43/A47 traded-alias acceptance is pending owner interpretation.**
   DA, orbital, weighted, Curve and Balancer tests intentionally use a post-trade
   book. Their existence and independent arithmetic are recorded, not endorsed.
   No test rewrite or product answer is authorized by this audit.
9. **A46 full manipulation sequence and component ghost oracle are missing in
   the mapped source.** Handler records real LP delivery and supply partition,
   but performs join/exit before its supplementary action and does not unwind an
   external underlying position. HB market motion checks no unsolicited mint;
   that is not the requested sequence or same-basket entitlement comparison.
10. **A40-A48 shared coverage must not be multiplied beyond its assertions.**
    Physical-balance snapshots, generic minimum failures and positive receipts
    do not prove every stored book, callback boundary, alias, decimal case or
    incomplete-redemption rollback. The row-specific missing tests above are
    requirements already in the PRD/authorized matrix, not speculative additions.

## Superseded and misleading source evidence

- `QR.test_quadraticRootMatchesLockToken0`, `test_quadraticRootMatchesLockToken1`,
  `test_quadraticIsZeroOutsidePosition`,
  `test_quadraticIsZeroWhenActiveLiquidityIsZero`,
  `test_quadraticCapIsSegmentBoundary` at Q source lines 358-426 test helper
  quadratic math (and a real external-liquidity setup for the cap case).
  They do **not** enforce the current 49% product rule and must not be credited
  as current one-sided sizing acceptance. O's M01/M02/M03 tests read above
  exercise the current money route. No tests were removed in this audit.
- B's comment that A26 remains open on PairToken identity (77), and DualUnwrap's
  identity-blocker comment (239), are stale descriptions of the current H3
  valid two-FullSpread fixture. The retained `identityAccepted` assertion in
  DualUnwrap:242 is set after successful valid deployment in H3:388; it is not
  proof of self-membership.
- The method names `test_row_partialConsumption_bookedNotRefunded` remain in the
  matrices, but their FullSpread overrides now assert refund receipt/custody.
  Do not interpret their names as a vault booking-unused-user-input rule.
- H7N5.`test_row_rateTarget_currency1` is a currency0 control in its actual body.
  H7, not the five-leg method name, supplies second-target execution.
- The fee-capital suite's present tests assert a new-capital fee and larger
  backed deposit -> larger fee (FC:22-101,132-158). Former yield-growth issuance
  and deposit-size-independent expectations are superseded by FS-OWN-36.
- Withdrawn A12-A16 are not mapped to passing absence tests. Selector absence
  evidence is attributed to A01/A29 only.

## Source inspection record and limits

Source ranges actually read include:

- `CLAUDE.md:1-143`; `.github/ASSISTANT_RULES.md` and
  `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_DEPLOYMENT.md`,
  `.github/ASSISTANT_TESTS.md` in full;
  `.agents/skills/indexedex-testing/SKILL.md:1-180`.
  Task-specific prohibition on runtime work takes precedence over build/test
  workflow requirements; no PR or code change is being prepared here.
- Authorized implementation/testing plan `1-587`, its acceptance/failure ledgers,
  task 18 and final gates; initial acceptance ledger in full. Some first
  multi-file tool output was truncated, so subsequent bounded reads recovered
  the specific requirement and source portions used for this audit.
- Sole FullSpread PRD `1-815`, with bounded, line-referenced reads of `241-815`,
  including all acceptance rows and hook formulas. Earlier long owner-lock
  paragraphs were also read in the initial authority read; no historical
  research report or other PRD was substituted.
- P `1-778`; M/O/MG source `1-1873`; Q/QR source `1-595`;
  C `1-217`; U `1-524`; N `1-236`; F `1-72`; B/unwrap source `1-306`;
  canonical vault TestBase `1-117`.
- HB `1-414`; CA1 `1-233`; CA2 `1-121`; CA3 `1-322`;
  CA4 `1-416`; CA5/CA5N3/CA5N8 `1-692`;
  CA6 `1-789`; CA7/CA7N5 `1-424`; DA `1-175,185-393`;
  OB `1-161`; FC `1-240`; L `1-330`; LL `1-218`.
  Unread tail helper code is not asserted as coverage.
- H1 `38-241`; H2 `39-307`; H3 shared helpers `60-325` and row
  `328-749`; H4 `37-201,293-338`; H5 `117-296`;
  H5N3 `107-171,230-281`; H6 `112-216,283-330`;
  H7 `148-248,309-354`; H7N5 `1-54`. These are the actual matrix bodies used
  above. Untouched/undetailed inherited methods are not silently credited.
- `HT/HookLiquidityInvariantHandler.sol:72-269,404-525`;
  `HT/dual/invariant/UniswapV4DualSEBCPHook_Invariant.t.sol:1-75`,
  contract `UniswapV4DualSEBCPHook_Invariant`, exact tests
  `invariant_liquidityAccounting` and `test_deterministicLifecycle`;
  `HT/stable/quad/curve/invariant/UniswapV4StandardExchangeCurveQuadStableBufferHook_Invariant.t.sol:14-72`,
  contract `UniswapV4StandardExchangeCurveQuadStableBufferHook_Invariant`,
  same exact test names. Their assertions delegate to handler
  `assertAccounting`/`assertCampaign`, not a new independent S/L ghost oracle.
- Seven additional binding-test file ranges in the table above. Text searches
  enumerated current vault tests, all nine matrix configurations, component
  adapters, membership tests, and invariant callers. Searches for
  AlreadyInitialized/storage isolation within VT found the explicit idempotence
  comment, not a second-init test. Searches are navigation/negative-scope
  evidence, not substitutes for assertion bodies.

The workspace is shared and was not frozen or fingerprinted by this child.
References describe the source observed during this inspection; parent must
reconcile any subsequent changes. No old log, artifact, test count, initial
ledger baseline, or unexecuted body is treated as proof of runtime passage.
No source absence outside the inspected scope is asserted as a whole-repository
fact. Hook family-specific suites not read in full may contain additional narrow
controls; none is credited without its body. This audit is exhaustive over the
48 acceptance IDs, not a claim that every unrelated family test file was read.

Stop condition: complete source-only inventory delivered. No implementation,
owner-question answer, additional review round, or change to existing evidence
is authorized or performed by this artifact.
