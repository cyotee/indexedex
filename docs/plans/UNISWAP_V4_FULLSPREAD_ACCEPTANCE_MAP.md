# FullSpread acceptance and pre-retirement regression map

**Reconciled 2026-09-30. G1–G6 scoped implementations and closure tests are present and passing at the checkpoints below. Final QA/readiness and retirement remain pending.** This replaces the initial inspection's blanket FAIL/open-work descriptions with actual predicate mappings. It does not turn earlier results into a final-current-tree pass.

The PRD has **29 acceptance requirements (§13)** and **31 decisions (D1–D31)**, not 31 acceptances. This map covers **R1–R11**, **F0–F6**, the **350 direct legacy test definitions** inventoried in O/L, and their shared/inherited assertions. “350” is a definition inventory, not an assert-call count or 350 new test instances.

## 1. Authority, revision and execution evidence

Authority: `CLAUDE.md`; [current PRD](UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md); [implementation/test plan](UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md); [context/quantity/residual amendment](UNISWAP_V4_FULLSPREAD_CONTEXT_QUOTE_ADDENDUM.md); [finite removal manifest](UNISWAP_V4_FULLSPREAD_REMOVAL_MANIFEST.md). Detailed closure records: [G3](UNISWAP_V4_FULLSPREAD_G3_CLOSURE.md), [G4](UNISWAP_V4_FULLSPREAD_G4_CLOSURE.md), [G5](UNISWAP_V4_FULLSPREAD_G5_GUARD_CLOSURE.md), [G6](UNISWAP_V4_FULLSPREAD_G6_CLOSURE.md). Their latest execution checkpoints supersede their older “prepared/unexecuted” sections.

Observed HEAD remains **`b019f232a1a109868da81be2d81f94d00a8a0be7`**. Replacement sources, helpers, tests and consumer changes are dirty/untracked. This SHA preserves the tracked legacy baseline; it is **not an immutable revision of the implementation tested below**. Preserve final dirty-tree/source/artifact manifests and untracked candidate evidence before retirement. No production/test edit, Forge/build/LSP invocation or delegation occurred in this reconciliation.

Tool logs below are under `/Users/cyotee/.local/share/opencode/tool-output/`; temporary logs are under `/var/folders/28/y_7zd8pd2sl_jtwdj8y7hbb00000gn/T/opencode/`.

| Checkpoint | Result and exact qualification |
|---|---|
| Full family | **436 passed, 0 failed/skipped, 89 suites, fuzz 128**, `tool_0f28e99a80017hutLncSKOzlpl`. Result/fuzz lines read directly. **Before the final native DFPkg contents-ID fix and later test enhancements**. Includes corrected G3. |
| Enhanced G5/G6 and prior G4 | **66 passed, 0 failed/skipped**, `tool_0f2ac962b001saQBFZEqpb2RyO`: G5 14×2 + G6 lifecycle 8×2 + then-current G4 11×2. Actual G5 fuzz lines say **16**, not 128. Mixed-history positives and stronger ledgers are included. |
| Latest G4 | **28 passed, 0 failed/skipped**, `tool_0f2c329e50011839URdKreiEXa`: 14 per family, including native discovery/money ordering, oracle fault/changed-manager and imported core/SY enhancements. Final result read directly. |
| G6 work exhaustion | **2 passed**, parent-reported dedicated work-limit cases; no separate log ID supplied in this handoff. Actual both-face assertions inspected. |
| G1 six-AMM same-manager EO | **78 passed**, parent-reported; actual six-AMM source assertions inspected. Ordinary/native/mixed-decimal H/P suite variants are separately identified below. |
| G1 natural-linear buffered output | **14 passed**, parent-reported; six AMM positives plus foreign-context control per H/P family. |
| G2 independent core | **16/16**, `fullspread-maintenance-observed-final.log`, preceding accepted focused result retained from the map's G2 checkpoint. |
| G2 independent registry proxies | **7/7**, `fullspread-registry-maintenance-observed.log`, preceding accepted focused result retained; six H/P cases plus H pending-own-fee case. |
| Broad prod-SE | **12,050 passed, 0 failed/skipped, 482 suites**, `tool_0f21c621b001ItRzzIYg3Q1Fl3`, final result read directly. **Before the F6 production correction**. Parent is running refreshed broad validation; no new result is claimed here. |
| F6 security | Independent security **PASS**, parent-reported for the bounded F6 correction. Not a completed protocol audit or final whole-tree QA verdict. |
| Final combined family | **Expected 450**, not an executed result. Refreshed **128-run** validation of the final enhanced tests remains pending. Do not add overlapping focused totals to 436. |

Historical 270/313/315-family results, the 12,044-pass/5-fail broad checkpoint, and its focused repairs remain provenance in [execution status](UNISWAP_V4_FULLSPREAD_EXECUTION_STATUS.md), [P status](UNISWAP_V4_FULLSPREAD_PONS_EXECUTION_STATUS.md), and [consumer status](UNISWAP_V4_FULLSPREAD_CONSUMER_STATUS.md). The five old failures were `test_T7_10_laterBond_joinUnbalanced_unboostedG` in CP/Univ4 product-law H6, P18_R6, P6_R18, P6_R9 and P9_R6. They are not current failures after the 12,050 checkpoint. H6 `test_alignmentResidualRetainedBookedAndRetried` proves retained/booked capital and later full-amount retry; P18_R6 `test_T7_10_selectedAlignmentResidual_booked_noIssuance_retry` additionally proves funded retry acquires LP without DETF issuance. Preserve those distinct predicates.

The old PID 82893/compile-only QA observation belongs to the initial 2026-09-29 inspection, not this current execution status. Final handoff requirements are in [draft readiness](UNISWAP_V4_FULLSPREAD_READINESS.md).

## 2. Paths and exact assertion locators

| Alias | Repository-relative expansion |
|---|---|
| T | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` |
| H / P | `T/hookless/` / `T/ponsFamilyV2Hook/` |
| FH / FP | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/` / sibling `ponsFamilyV2Hook/` |
| B | `contracts/test/bases/` |
| C | `test/foundry/spec/hooks/uniswap/v4/standardExchange/` |
| O | `test/foundry/spec/protocol/dexes/uniswap/v4/` — singular `protocol` |
| U | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/` |
| L | `U/release/v4/` |

**Mapped** means the specified predicate is checked by the named current tests, possibly by complementary unit/reference/integration cases rather than a copy of the old fixture. **Superseded** applies only to the conflicting expectation and names its authority. **Historical** preserves the old source/finding, not current correctness. **Unmapped** is reserved for an actual retained predicate for which a current assertion was not found; the finite list is in §7. No implicit requirement is added for every native×decimal×actor×funding×route Cartesian product.

H/P means separately instantiated family proxies. Test-only common observers do not dispatch production H/P economics. Pull = `pretransferred=false`; push = actual unbooked delivery by an eligible code-bearing caller. EI refunds nothing; pull EO spends only used; push EO refunds only `min(unbooked,max)-used`. Prior out-of-call transfers survive a rejected call; atomic funding rolls back. SY internal redemption uses its existing context/self-share custody rules.

### G1 — contextual consumers

`C/FullSpreadSameManagerConsumers.t.sol` now includes:

- `test_sameManager_realOwnerEiBothDirectionsBothUnderlyingFaces`: Single-CP ordinary/owner/PM flows, including helper assertions for idle EO preview versus blocked quote and actual router input/output/share issuance.
- `test_sameManager_weightedIdleExactOutputMatchesRouter`, `test_sameManager_dualIdleExactOutputMatchesRouter`, `test_sameManager_orbitalIdleExactOutputMatchesRouter`, `test_sameManager_curveQuadIdleExactOutputMatchesRouter`, `test_sameManager_balancerQuadIdleExactOutputMatchesRouter`: real funded AMM instances, positive buffered input/raw output, **idle PM quote equals actual blocked quote and execution**, used-input/exact-output deltas, real SE share issuance, nonunit projected-rate equality, settled manager deltas, cleared approvals and booking. Dual/Single-CP overload parity is asserted.
- `_assertAmmContextRate`, `_assertAmmFlat`, and two-leg EO rejection helpers assert actual rate, manager relock/nonzero-delta count zero, no stranded router/hook deltas and exact rollback. `test_foreignManager_cpExactOutputPreservesActualIdleDomain` keeps foreign-manager/direct economics ordinary. Wrapper EI/EO, shortage and opaque-decoder controls are retained, including the newly explicit idle wrapper EO equality in `test_sameManager_blockedExactShareMintRemainsSupported`.

Concrete variants: Hookless/Pons ordinary, native and mixed decimals. These supply the parent-reported 78 checkpoint; they are not merely six variants of the old wrapper-only test.

`C/FullSpreadSameManagerLinearOutput.t.sol`: `test_linearOutput_{singleCp,dualCp,weighted,orbital,curveQuad,balancerQuad}` and `test_linearOutput_foreignContextIsOrdinary`, each H/P. Actual zero opposing backing/local cover; independent ceiling share debit; idle projected EO=blocked EO; exact payout, supply burn and local subtraction; separately isolated insufficient cover, entire-held-share reserve boundary and one-more-than-held share failure with full rollback/settlement. These 14 positives/negative-containing cases preserve supported buffered-output EO without inventing a two-leg inverse.

### G2 — independent maintenance, not comparator self-reference

H/P `MaintenanceObservedProgress.t.sol` inherit `B/TestBase_FullSpreadMaintenanceObservation.sol`: `test_observedMaintenance_usefulBothDirections`, `test_observedMaintenance_partialBothDirections`, `test_observedMaintenance_fundingRemovalBothDirections`, `test_observedMaintenance_noTradeAndPlacementPreference`, `test_observedMaintenance_priorFeesBothDirections`, `test_observedMaintenance_realThresholdNeighborsBothDirections`, `test_observedMaintenance_referenceArithmeticControls`, plus leaf controls included in the 16 checkpoint.

Expected metrics use **`contracts/test/utils/FullSpreadMaintenanceReferenceMath.sol`**, independent base-2^32 products/subtraction/rational comparison, not production Inventory/Protection. Core placement-only counterfactuals actually execute on restored state. Terminal principal is measured by full removal minus separately collected fees. The hard funding-removal witness uses owned L=`1_000_000e18`, external L=`100_000e18`, directional excess=`1_000e18`, and requires full owned removal and reduced active liquidity before swapping. Useful/partial witnesses, immediate repeats and adjacent natural 1 bp books are non-vacuous. P protocol fee rounding follows gross minus floored net, without a one-wei tolerance.

H/P `RegistryMaintenanceObservation.t.sol` inherit `B/TestBase_FullSpreadRegistryMaintenanceObservation.sol`: `test_registryMaintenance_usefulBothDirections`, `test_registryMaintenance_partialBothDirections`, `test_registryMaintenance_withinBandsNoTrade`; H adds `test_registryMaintenance_pendingOwnFeesBothDirections`. P uses the real launch/graduation fixture. The proxy baseline is **predictive core signed-settlement arithmetic**, not an executed proxy counterfactual: actual custody, liquidity, fee growth and price feed an independently calculated no-trade placement baseline. Actual public repair must improve terminal `(compositionExcess,sleeveExcess)` strictly when trading; otherwise exact no-trade book equality. Tests count ≤1 swap, enforce 25 bp squared-price impact, no mint/burn/reward, complete books, zero ETH and exact allowed approval configuration. Configured ERC20-to-Permit2 maximum is intentionally preserved; it is not falsely required to be zero.

The older `RuntimeAndWork::test_referenceCandidateSelectionAndWorkUnchanged` still reuses production financial/comparator helpers. It remains optimization-equivalence evidence; G2's independent observers now close the former proof gap. The existing `CoreSettlement::test_sharedFullEndpointsOptionalMaintenanceDefers` supplies the explicit Deferred/no-swap/no-placement control. No duplicate native/mixed-decimal/full-endpoint reference campaign is made a new gate.

### G3 — route and funding predicates

H/P `RouteFundingClosure.t.sol` use `B/TestBase_UniswapV4FullSpreadG3RouteFunding.sol`, including its separate natural-linear adapter. Eight definitions, 16 instances:

| ID | Actual test | Exact added predicates |
|---|---|---|
| G3.1 | `test_blockedDirectExactInputRejectsBothDirections` | EI preview and push/pull execution, exact interaction-blocked error; complete atomic funding/custody rollback. |
| G3.2 | `test_blockedFirstDualActivationThenIdlePlacement` | First-ever dual funding, independent minimum/sink, exact payer/recipient/supply/allowances; zero owned liquidity while blocked, then idle placement with unchanged bounds/price/supply. |
| G3.3 | `test_blockedF1AtomicPushEqualsPullOnRestoredState` | Both faces, independent inverse input, prior unprepaid quote, exact requested shares/recipient, used-only pull, exact bounded push refund and restored full ledger equality. Only known funding-mode allowance difference is normalized in comparison; actual allowances each asserted exactly. |
| G3.4 | `test_F3PushAndPullBudgetMatrix` | Idle/blocked, independent equal-ceil burn, 31 already-booked self-shares; pull exact/fat max, push exact/used-only/excess/over-max credit, short delivery/max and separate pull short max. Exact payout/burn/refund/retained surplus and all books. |
| G3.5 | `test_F3EachLocalLegShortageRollsBack` | Each leg independently short, other funded, equal burn valid; exact cover error from preview and both execution flags, whole ledger restored. |
| G3.6 | `test_multiMalformedVectorsAndMissingSecondCredit` | Reversed/duplicate/nonpool/wrong share face/wrong amount length/each zero leg; preview and actual idle/blocked rejection; missing second pushed leg rolls back first transfer. |
| G3.7 | `test_idleSYAliasesBothFaces` | Restored SE/SY deposit/external/internal redemption, both faces, exact quote/recipient/share/supply/allowances/whole ledger; retained internal surplus. |
| G3.8 | `test_linearExactOutRefundMatrixBothOrientations` | Real naturally one-sided 6/6 books, independent ceil, both orientations, same complete budget matrix with booked shares preserved. Blocked matrix; existing idle linear+CC positives remain complementary evidence. |

G3 observes both selected snapshots, token/share/recipient/manager custody, local/self-share reserves, actual ERC20/Permit2 allowances, native residue and P fee ledgers. Crane consumes even maximum ERC20 allowance; Permit2's configured but unused layers remain unchanged. There is no invented infinite-allowance exemption.

### G4 — import, deployment, native discovery and TWAP

H/P `ImportDeploymentClosure.t.sol` inherit `B/TestBase_UniswapV4FullSpreadG4ImportClosure.sol` and `B/TestBase_UniswapV4FullSpreadG4DeploymentClosure.sol`, **14 per family**:

| ID | Actual test | Exact predicates |
|---|---|---|
| G4.1 | `test_G4_importTrustMatrix` | Wrong supplied manager, independently unbound real package, forged owner and wrong actual NFT owner; exact trust errors, NFT/approval/liquidity/custody/supply unchanged, no attacker shares. |
| G4.2 | `test_G4_importUnfundedSideRollbackBothOrientations` | Actual withdrawn NFT has one zero contribution despite both donated local faces; exact zero-amount rejection, full NFT/custody rollback. |
| G4.3 | `test_G4_importBelowFloorRollback` | Independent raw sqrt of measured NFT proceeds, exact minimum error, restored owner/liquidity, zero supply and local custody. |
| G4.4 | `test_G4_importEarnedFeesOnceAndApprovalsZero` | Actual fee-only then principal removal versus restored full withdrawal, exact issue/sink/supply; expected+1 minimum failure/retry; zero PositionManager ERC20 and Permit2 spend entries, cleared NFT approval, empty NFT retained, repeat import rejected. H actual LP fees positive; P LP fees zero, not confused with hook charges. |
| G4.5 | `test_G4_importCannotManufacturePretransferCredit` | Both faces after actual import: booked positive sleeve cannot fund a code-bearing zero-delivery claim; distinct EOA guard, exact errors and unchanged fingerprint/attacker assets. |
| G4.6 | `test_G4_packageRegistryMetadata` | Exact family name, 20 interfaces, 15 expected facet addresses/order, getters/config/cuts/Behavior_IFacet consistency; package/per-token membership, contentsId, names, UV4X and 18 decimals. Admission's Target-derived selectors remain independent controls. |
| G4.7 | `test_G4_packageAndComponentAbiNameSalts` | All ten family facets, both execution delegates and package actual CREATE3 addresses equal independently encoded full-name salts, differ from raw-name hash addresses, runtime nonempty. |
| G4.8 | `test_G4_nativeRegistryPreservesPoolKeyOrder` | Deliberate pair<WETH; stored/public/config faces stay `[WETH,pair]`; independent sorted contents hash; actual vault discoverable through both token permutations; names/per-token membership. Real WETH funding and four restored WETH/pair direct-swap/deposit paths assert exact input/output/share/supply, unchanged caller/recipient ETH and all books. |
| G4.9 | `test_G4_twapInvalidConstructorBindingsDoNotRegister` | Zero and real foreign-manager oracle fail real registry/CREATE3 construction; package count unchanged. Actual outer error is `ErrorCreatingContract`, not a claim to see masked inner constructor payloads. |
| G4.10 | `test_G4_launchActivationReplayDoesNotReseed` | Actual PoolSeedLib helper, exact two debits/receiver/sink, cleared allowances; replay leaves ledger unchanged; later positive unilateral intake pays receiver exactly. |
| G4.11 | `test_G4_twapBoundPoolObservationAndNonwritingPolicy` | Bound manager/oracle, first cardinality/tick/prevTick/cumulative; transfer does not poke; foreign pool isolated; same-time false return allows funding; explicit foreign update; second proxy shares package oracle. |
| G4.12 | `test_G4_twapUpdateFaultRollsBackFundedOperation` | Controlled external counterparty updates genuine oracle then reverts; exact error propagates and rolls back payer/allowance/vault/pool/fees/position/oracle observation/ETH; clearing fault permits exact funded retry. |
| G4.13 | `test_G4_twapChangedManagerRejectsInstanceWithoutRegistration` | Real package initially valid; external advertised manager changes; exact `processArgs` mismatch, no global/package vault registration; restored advertisement permits actual registered vault. |
| G4.14 | `test_G4_importCoreCheckpointAndSyLifecycleBothFaces` | Actual NFT PoolKey/ticks and entire core tuple after control withdrawal equal imported empty position including fee checkpoints; both-face SY exact payout/burn/recipient/booking/ETH; NFT owner/approval/tuple remains unchanged. |

**Native fix:** each family DFPkg hashes a **fresh sorted copy** for contentsId. Original PoolKey-ordered token storage, names and approvals are preserved. `calcSalt`, package/component salts and PoolKey remain unchanged. This fixes new-deployment discovery in both permutations; it does not rewrite existing deployed instances or turn occupied CREATE3 reuse into an upgrade.

**TWAP authority:** PRD §3 and plan §1 select **F (unsegmented FullSpread)** as baseline, not O. F directly propagates `update` failure; F's misleadingly named `test_H16_pokeRevertFailOpen` expects a revert. G4.12 validates that preserved policy. O's conflicting fail-open success is specifically superseded; no new owner choice or blanket waiver of custody assertions is needed.

### G5 — guards and meaningful three-actor histories

H/P `GuardClosure.t.sol` inherit `B/TestBase_FullSpreadG5GuardClosure.sol`; real external token/callers are `contracts/test/stubs/FullSpreadG5{GuardToken,CreditHandler}.sol`.

| ID | Actual test | Preserved predicates |
|---|---|---|
| G5.1 | `test_G5_bootstrapMinimumPlusOneIdleAndBlocked` | Exact minimum failure/atomicity and minimum+1 one-share success, sink/supply/input debits in idle and real blocked contexts. |
| G5.2 | `test_G5_bootstrapMetadataFailureAndRetry` | Exact real metadata dependency error, zero issuance/custody changes, later successful retry; no decimal fallback. |
| G5.3 | `test_G5_bootstrapDonationCannotBeCaptured` | Donation each face mints nothing; independent residual sink, exact supply, first-minter per-token entitlement bounded by actual contribution. |
| G5.4 | `test_G5_sharePermitReplayAndSpentAllowance` | Signed owner/spender/value/nonce/deadline, wrong spender denial, exact spend/nonce, consumed signature and spent allowance rejection. |
| G5.5 | `test_G5_ordinarySharePullNeedsAllowanceAndHolderExitUsesOwnShares` | Third-party ERC20 transferFrom requires approval; caller may exit its **own** SE shares without approval; exact distinct-recipient payment. Old own-share allowance gate is superseded by owner-confirmed current `_secureShareDelivery`, not an outstanding code fix. |
| G5.6 | `test_G5_feeOnTransferRollback` | Exact short actual pull in valid blocked mint, full ledger and underlying burn rollback, normal retry. |
| G5.7 | `test_G5_nestedSyAndExchangeCallbackRollback` | Token-held claims, recorded and propagating SY/exchange callbacks reach exact lock; positive outer call, no stolen claims/payout; failed outer call resets callback writes/custody. |
| G5.8 | `test_G5_packageDisablePreservesValidExitsAndReenable` | Package SE/SY inbound disabled, exact valid F3 and SY exits, re-enabled funded SY mint. Address-disable controls remain separate existing tests. |
| G5.9 | `test_G5_removedPreparationAndDiamondCutUnavailable` | Zero loupe targets, no interface advertisement, actual `NoTargetFor` for prepare/cut, share decimals preserved. |
| G5.10 | `test_G5_zeroDeadlineUnsupportedAndRecipientGuards` | Valid-domain zero/deadline/unsupported token and SY receiver errors, full rollback; does not incorrectly reject numeric zero views. |
| G5.11 | `test_G5_idleSyMinimumRetryContextAndBookedSurplus` | Both faces, booked self-shares, failed internal minimum then exact retry, burn once, retained books, ordinary no-share caller and booked-credit theft denied. |
| G5.12 | `test_G5_idleExternalSyMinimumRetryBothFaces` | Both faces, failed minimum rollback, allowance-free exact retry, payer shares/supply/recipient and zero self-residue. |
| G5.13 | `testFuzz_G5_threeActorCreditHistories` | C48: 48 persistent steps, eight credit actions twice per three wallets, all three refund modes, finite approvals, exact attacks/rollback and non-vacuity counters. Latest enhanced run 16; final 128 pending. |
| G5.14 | `test_G5_threeActorMixedMoneyAndReentryHistories` | M: all actors/faces pull/push idle mint/direct EI, idle/blocked share EI, direct EO three credit budgets, staged-short retry, five pre-sync probes after real trade, recorded/propagating callbacks and reuse, late swap rollback, donation/repair and .02/.5/1/.2 sleeve history. Exact money-call counts `[27,26,26]`, 30 expected failures. |

C48/M independently track issued-minus-burned supply, each holder, passive fixture, sink/callback-held shares, zero attacker/handler/self balances, both global custody sums, local books and ETH. Other-holder checks include assets/shares/approvals; rollback digests include wallet self-approvals and individual manager/hook balances. Unexpected positive failures propagate. Existing **C32** (`B/TestBase_UniswapV4FullSpreadCrossModeCampaign.sol`, H/P `CrossModeStatefulCampaign.t.sol`) retains its stronger independent economic attribution over 32 steps/eight modes. These complementary tests replace the **predicates** of the old 24-action handler; a literal 24-action clone is not required.

### G6 — exact transition/lifecycle and bounded partial F6

H/P `TransitionLifecycleClosure.t.sol` use `B/TestBase_FullSpreadG6TransitionLifecycleClosure.sol` plus separate `B/TestBase_FullSpreadG6WorkLimitRollback.sol`. Eight lifecycle tests per family plus one work-limit test per family:

| ID | Actual test | Exact predicates |
|---|---|---|
| G6.1 | `test_externalTransitionsPreserveHolderClaimSequentially` | Both faces, four external deposit/swap projections composed before execution; exact quantities, passive holder claim/shares, distinct recipient, supply and every next-state field. |
| G6.2 | `test_redemptionTransitionAndSYMatchAfterExternalSequence` | Both faces after real trade, restored SE/SY parity, independently removed liquidity/local+earned entitlement and first observed conversion; exact receipt/burn/remaining claim/full book. |
| G6.3 | `test_partialConversionRetainsOpposingEntitlementAndProjectedBook` | Selected token0 positive terminal partial fill; actual consumed input below entitlement, exact payout and independently reconstructed opposing cash/residual, complete projection/live state. |
| G6.4 | `test_partialConversionRetainsOpposingEntitlementAndProjectedBook_token1` | Independent symmetric token1 positive. |
| G6.5 | `test_fullRangeLifecycleActivationWalkBlockedJoinRepair` | Exact full-range bounds/salt, old tight/wing and both alternate salts absent; actual directional walks, blocked join no swap/unchanged own L/fees, then repair signed core liquidity and token settlement ledgers, no reward/issuance. |
| G6.6 | `test_directExactInputStillRejectsPriceLimitedFill` | Both-face direct EI stays strict; exact failure/rollback rather than inheriting redemption's terminal-partial exception. |
| G6.7 | `test_partialConversionLateMinimumRollsBackBothFaces` | Actual positive partial payout control, restore then require payout+1; exact late error restores fields, unbooked donation status, shares/allowances/custody/global growth/own checkpoints/all P ledgers. |
| G6.8 | `test_redemptionAlreadyAtDirectionalLimitRetainsFullOpposingEntitlement` | Exact real endpoint, positive opposing entitlement, zero swap events/charges, selected entitlement only paid, entire opposing entitlement remains backing and exact cash reconciles. |
| G6.9 | `test_F6WorkLimitPrefixRollsBackBothFaces` | Actual spacing-1 post-removal core quote hits exactly 64 steps, partially consumes **without reaching limit**; holder valuation/preview/execution reject QuoteWorkLimit with full rollback. |

Authorized family-local `_redemptionForward` accepts complete fills or actual terminal-price partial fills; execution sends original entitlement budget, verifies consumed input/output/price/tick/liquidity and retains unspent opposing custody. Projection restores that unspent amount. Ordinary `_forward`/`_tryForward` and direct execution remain strict. Independent G6 references reconstruct principal/fees/settlement from real core state/events rather than family planners; the corrected exact opposing-cash assertion is stronger than the old lower-bound-only check. Independent security PASS is bounded to this change. Final post-change runtimes and broad consumers still need their final evidence.

## 3. R1–R11 acceptance mapping

| Route | Domain and formula | Actual predicate mapping / disposition |
|---|---|---|
| **R1** token_i→token_j EI | Idle F4 + bounded repair; blocked rejects | H/P `QuoteExecutionParity::test_directExactInputBothDirections`, CoreSettlement forward both directions; G3.1 exact blocked EI both flags; G5.14 real pull/push swaps/late rollback; G2 terminal observer. Direct terminal partial remains rejected by G6.6. |
| **R2** token_i→token_j EO | One core step + CC idle; blocked invalid | FormulaDomains nonzero/reverse-direction/credit-refund controls; CoreSettlement one-step/word/fee boundary; G5.14 both directions/actors and used-only/full/partial-budget exact output/approval/refund. G1 projects actual forthcoming manager context at consumers without extending the underlying route. |
| **R3** token_i→shares EI | F5/F0 idle, F1 blocked | Repeated both-face composition, CoreSettlement independent caller basket/placement/min-ratio, C32 attribution; G5.13/.14 actual pull/push histories, no refund, finite approvals/recipient/custody; context and G6.1/.5 exact transitions. |
| **R4** token_i→exact shares | Idle invalid, blocked F1 inverse | F1 independent minimality; quantity idle rejection both faces; G3.3 restored both-face push/pull equality and actual mode-specific allowances; G5.13 three refund modes. Idle success explicitly superseded. |
| **R5** shares→token_i EI | F6 idle, F2 blocked with local cover | Both-face QuoteExecutionParity, independent C32 F2/F6 entitlements, G5.14 both funding flags/contexts; BlockedYieldEquivalence shortages; G6.2–.9 partial/endpoint/work-cap/late guard and exact cash/book. |
| **R6** shares→exact token_i | Natural one-backed-leg linear only; CC idle | Existing OneBackedLeg idle+blocked positives and opposing-wei/quantity-not-cover controls; G3.8 both natural orientations/full budgets; G1 six-AMM natural-linear buffered outputs. Two-leg success superseded, not restored through search. |
| **R7** canonical `[token0,token1]`→shares | F0 dual activation/join, local blocked | G3.2 first activation→placement and G3.6 malformed/missing-credit; decimal ZapAndPlacement and F0 pure dual reference; G4 launch/import; G5 minimum/donation/metadata. One retained intentional-unbalanced-vector predicate remains explicitly unmapped in §7; no new Cartesian expansion is requested. |
| **R8** shares→exact canonical vector | F3 equal ceilings; CC or narrow maintenance omission | FormulaDomains exact payout/unequal ceil/R8 exception; G3.4 independent ceilings and full idle/blocked budgets with booked31 shares; G3.5 each-leg cover/atomicity; G3.6 invalid vectors. Required payout/removal/bookkeeping remains mandatory under omission. |
| **R9** SY aliases | Exactly R3/R5, ordinary/internal custody | G3.7 both-face restored whole-ledger equality; blocked SY both faces/native variants; G5.11/.12 internal/external minimum/context/recipient/surplus controls; G6.2 after real fee-bearing trade; G4.14 after import. Exact SY metadata/rate return predicates are separately noted in §7. |
| **R10** import/activation | Actual NFT F0 funding; reject blocked | Existing PositionImport/NativePositionImportFunding; G4.1–.5 and .14 independent withdrawal, trust/minimum/missing-side/fee/approval/checkpoint/no-new-credit; native funds and prior sleeve exclusion remain separate. |
| **R11** public repair | Bounded holder-funded repair idle; reject blocked | G2 independent core/proxy terminal ordering, placement preference, repeats, 1 bp neighbors, fee ownership/25 bp/no reward; existing full-endpoint Deferred; G6.5 actual lifecycle settlement and G5.14 live sleeve histories. Old comparator reuse is no longer the only reference. |

## 4. F0–F6 source and independent-reference map

| Formula | Existing source law and independent control | Qualification |
|---|---|---|
| **F0** | Plan §2.1 / shared StandardExchangeConstantProduct; `BlockedFormulaReference::test_F0DecimalMinimumAndProportionalFloor`, decimal ZapAndPlacement, G3.2, G4 measured import/launch, G5.1–.3 | Exact minimum/sink, actual dual funding, proportional min of both floors; metadata failure propagates. Unit decimal controls plus deployed tests are complementary; no demand for every hostile-token×decimal combination. |
| **F1** | Plan §2.2; `test_exhaustiveF1MinimalInverse` independently enumerates square roots/required input/predecessor, including zero opposing backing; quantity supplied-state reference; G3.3 and C32 mode3 | Blocked only, exact requested shares, residual remains backing; no idle F5 inverse substitution. |
| **F2** | Plan §2.3; `testFuzz_F2ForwardMatchesEntitlementReference`, radical counterexample 6/7/9→0 versus 10→1; blocked SY independent u/v cover; G3.8 linear ceil | Positive two-leg exact-input entitlement retained; general exact-output inverse explicitly invalid. |
| **F3** | Plan §2.4 equal ceil; G3.4/.5 independently calculate both burns and isolate funding/max/cover | Exact two payouts/burn; booked self-shares cannot fund refunds; R8 omission preserves user requirements. |
| **F4** | Plan §2.5 real core forward/one-step EO; CoreSettlement signed deltas/protocol splitting/own growth/word boundary/64-step truncation; PonsFeeSemantics separate floors, registered terms and 50-unit zero-charge vector | Core execution is independent of family quoter, not a separately implemented EVM core. P hook charges are not owned LP fees. |
| **F5** | Plan §2.6; CoreSettlement measured repricing/removal/signed placement and bounded integer inequality; C32 `_assertMintAttribution` independent caller/holder/rounding decomposition | 10000*m*B ≥ 9999*S*C, no dust waiver. Generic core math may be shared, production family planner/protection does not supply expected issuance. |
| **F6** | Plan §2.7; C32 `_assertExitAttribution`; G6 actual post-removal conversion, independent selected payout/opposing cash/fee ownership and full transition | Terminal partial and already-at-limit supported after authorized correction; nonterminal work exhaustion and ordinary direct EI remain strict. No novel EO inverse. |

CC primitive controls (`ProtectionAndInventoryMath::test_closedPlacementNonzeroAndNoTradeSuccess`, signed rounding vectors and CoreSettlement actual placement) remain intact. G2 now supplies the missing independent terminal integration observer. The old optimization reference remains correctly labelled, not deleted or retrospectively called independent.

## 5. All 29 mandatory acceptance requirements

“Mapped” is assertion coverage at the qualified checkpoints, not final-current-tree QA. A26/A27 are explicit later gates. Only actual remaining retained predicates, not optional test expansions, are noted.

| A | Requirement | Current disposition |
|---|---|---|
| 1 | Repeated unilateral productive deposits | Mapped: both-face repeated composition, decimal leaves, real placement, G5 mixed histories. |
| 2 | Complete caller basket/post-swap incumbent backing | Mapped: independent F5 core/C32 attribution and G6 external transitions. |
| 3 | Owned-deployed-principal live sleeve | Mapped: exact target vectors, live zero/.2/1 policy, G2 independently observed metrics, G5 .02/.5/1/.2 history. |
| 4 | Blocked deposits no nested unlock | Mapped: G3.1/.2/.3, consuming hook/G1 real sessions, G6 blocked lifecycle. |
| 5 | Actual local cover for blocked withdrawals | Mapped: G3.5 both legs, BlockedYieldEquivalence, natural linear quantity/cover separation and G1 linear consumer controls. |
| 6 | Actual both-token activation | Mapped: G3.2/G3.6, G4 missing NFT side/actual funding, G5 floors/metadata/FoT. |
| 7 | Bounded repair and immediate repeats | Mapped: G2 actual useful/partial/removal/repeated swaps; existing gas/work gates retained. |
| 8 | Stop trading within both bands | Mapped: G2 exact observed bands/no-trade baseline; natural threshold neighbors. |
| 9 | No temporal/cumulative throttle | Mapped: immediate repeated public calls and persistent live-policy histories; no new history quota. |
| 10 | Correct protection units/fees once | Mapped: independent squared-price/shortfall vectors, protocol/P floors, G2 measured25bp, late rollback tests. |
| 11 | Alignment independent of sleeve band | Mapped: F5 independent inequality, tiny amount control, separate G2 metric/deadband. |
| 12 | Full retained local booking | Mapped across G3–G6 and campaigns; F6 retained partial cash now independently reconciled. |
| 13 | Unbooked claims vs prohibited re-credit | Mapped: G3 booked31 budget matrices, G4 post-import negatives, G5 staged/atomic/partial/payer≠consumer/replay/EOA histories. |
| 14 | Fixed identity/truthful integration quotes | Mapped: Admission, real P registration/fee semantics, G1 contextual quotes; no unknown-hook fallback. |
| 15 | Native/WETH/import/Multi/consumers | G1/G3/G4/G6 mapped; native sorted-copy discovery and reverse-order money paths pass. Retained intentional-unbalanced Multi predicate L1 in §7 is not yet positively mapped. |
| 16 | Adversarial cross-mode cycles | Mapped: C32 independent economics + C48 and G5.14 meaningful three-actor money/reentry history, G3 budgets. Literal old handler shape unnecessary. |
| 17 | Bounded solver and independent outcomes | Mapped: independent G2 core/proxy, F0–F6 references and G6 work-limit rejection; final runtime/work evidence still needs final source qualification. |
| 18 | Formula/domain-specific EO, early rejection | Mapped: selected positive/negative F1/F3/F4/linear domains, quantity controls, G3 budgets and G1 six-AMM context/linear proof. |
| 19 | Combined CC or narrow R8 omission | Mapped: positive CC core/route controls, R8 no-trade exception plus independently exact F3 payouts/cover/booking; no numerical repair tail/invented inverse. |
| 20 | Ordinary/transition/availability/execution agreement | Mapped: context/quantity, G1 idle PM EO parity, G3 aliases/negative domains, G6 complete supplied-state/live transitions and actual failures. |
| 21 | Finite-range inclusive1bp metric | Mapped: independent G2 big arithmetic, natural adjacent books and real terminal observations. |
| 22 | Placement preference/post-cost progress/stop/defer | Mapped: G2 executed core counterfactual + predictive proxy baseline, partial/repeated progress, existing full-endpoint Deferred control. |
| 23 | Hook/manager/impostor/state/reuse/identity | Mapped: Admission/constructor binding and G4 exact package/salts. P wrong-production-manager evidence retains its hook-pin-first limitation plus separate genuine-hook manager mismatch. |
| 24 | Exact family identities/separate economics | Mapped source structure, declared controls and permitted pure reuse; final source/artifact/import audit remains a final validation item, not new architecture work. |
| 25 | Canonical constants/accepted P evidence | Mapped: canonical bindings, real hermetic registration and accepted docs/graduated-pool evidence. No runtime-bytecode equivalence gate or claim. |
| 26 | Readiness before finite removal, durable provenance | **Pending:** final validation/remaining exact legacy disposition, durable dirty-tree preservation and owner readiness checkpoint. |
| 27 | Final post-removal build/regression/import closure | **Pending after owner gate:** no retirement performed; final revision and refreshed artifacts/results required. |
| 28 | Fixed protections/no setter/fixed hook/live sleeve | Mapped constants/declared API, no-cut/removed surface, hook admission, live-policy controls. Final deployed selector/artifact inventory retains this check. |
| 29 | Exact deterministic parity/in-kind aliases | Mapped G1/G3/G6, no tolerance waiver. Exact SY metadata/rate return preservation L2 below is distinct from the now-covered money-path alias parity. |

### Decisions D1–D31

| Decision | Current locator |
|---|---|
| D1 | R3 existing exchangeIn, repeated production composition. |
| D2 | F5 caller-only swap budget, observed core/C32 attribution. |
| D3 | A3/G2 deployed-principal sleeve; native contents fix does not alter it. |
| D4 | F5 allocation/rounding before mint. |
| D5 | Independent post-swap incumbent book. |
| D6 | F0/F5 min proportional floors. |
| D7 | Full contribution including retained sleeve. |
| D8 | F5 residual book and G6 retained entitlement. |
| D9 | G2 holder swap/removal/addition with independent terminal progress. |
| D10 | G2 immediate repeated actual swaps. |
| D11 | No timing/cumulative throttle; bounded work only. |
| D12 | G2 no trade within both bands. |
| D13 | Real direct PoolManager settlement throughout. |
| D14 | Fixed H/P admission; old arbitrary-hook policy superseded. |
| D15 | G3/G5 source-agnostic unbooked credit and existing caller guard. |
| D16 | Complete token/self-share local snapshots G3–G6. |
| D17 | R2/R4/R6/R8 valid EO domains retained. |
| D18 | CC fixed combined action list; no numerical EO repair tail. |
| D19 | R8 vector omission only. |
| D20 | Fixed25/50/10/1bp, independent references retained. |
| D21 | G2 finite-range/progress proof now present. |
| D22 | Separate full-name FH/FP components/economics. |
| D23 | Canonical manager and P V2 generation. |
| D24 | A26/A27 owner-gated retirement. |
| D25 | Fixed protections, no tuning setter. |
| D26 | Fixed current-stack singleton, impostors rejected. |
| D27 | Source-backed R/F matrix, not speculative candidate work. |
| D28 | Only approved pure helpers/types shared across families. |
| D29 | Accepted documentation/graduated pools, no codehash gate. |
| D30 | G1/G3/G6 exact quantity/full-state parity. |
| D31 | Finite manifest, old code-linked docs historical, preserved shared/V3 law. |

## 6. Legacy assertion disposition — 250 O + 100 L definitions

### 6.1 Inventory and interpretation

Each row below includes called assertion helpers and decimal inheritance. Multiple current tests may jointly preserve one old test's predicates; fixture names, exact old amounts, fuzz parameter products and obsolete route positives are not themselves new product requirements. Where a required exact assertion was not found, §7 says so rather than declaring the entire suite closed. None of these mappings authorizes deletion.

O prefix is `UniswapV4StandardExchange`; L prefix `UniswapV4FullSpreadStandardExchangeVault`. O decimal bases append `_Decimals.sol` under `decimals/`; adversarial bases under `decimals/adversarial/`. Eight O configurations exist for all groups except Native: H6,H9,P6_R9,P6_R18,P9_R6,P9_R18,P18_R6,P18_R9. Native O leaves are P6_R18/P9_R18. L FullRangeBook leaves are H6/P6_R18/P9_R18/P18_R6. Existing new decimal/native suites preserve their bounded dimensions; this table does not claim every G4/G5 negative was rerun in each old leaf.

| File suffix/group | O definitions (ordinary + decimal base) | L definitions | Current mapping |
|---|---:|---:|---|
| `DFPkg_Deploy` | 3+3 | 5 | G4.6/.7/.8; new full identities, exact vectors/membership/salts. |
| `Routes_Test` | 23+23 | 23 | §6.2; R1–R6, G3/G5/G6 and explicit EO-domain supersession. |
| `_FullRangeBook` | 27+7 | 30+7 | §6.3; actual full-range lifecycle, funding/fees/import/SY. |
| `_LocalLiquidBuffer` | 27+27 | — | §6.5; exact new sleeve plus blocked funding/progress. |
| `_LocalLiquidBuffer_H2` | 1+1 | — | G1 real funded consuming hooks; actual receipt/SE issuance/manager context. |
| `_MultiJoinExit` | 15+15 | 15 | §6.4; L1 retained unmapped predicate. |
| `_NativeEthWrap` | 3+3 | 3 | G4.8 reverse-order WETH money paths + existing native SE/SY/booking; current route domains. |
| `_TwapPoke` | 7+7 | 7 | §6.6; F propagation supersedes O fail-open only. |
| `_Univ4SeNestedCaller` | 2+2 | — | G5.5; old own-share allowance gate superseded, ERC20 third-party approval preserved. |
| `adversarial/Adversarial_UniswapV4SE_SecurePull` | 19+19 | — | §6.7. |
| `adversarial/Adversarial_UniswapV4SE_E6ImpA0` | 8+8 | — | §6.7. |
| `_ReserveReconcile` | — | 3 | Exact custody books G2/G3/G6/C32, G5 pre-sync attacks/retries; old economic-total/wide approximations superseded. |
| `_PretransferParity` | — | 2 | Idle R4 success superseded; G3.3 restored supported blocked parity/refund. |
| `closed-form/UniswapV4FullSpreadClosedFormPrimitiveParity` | — | 5 | Four historical candidate controls; sleeve predicate maps to independent current vectors, §6.9. |

Each O/L also has eight IFacet files: InFacet, InQueryFacet, InMultiFacet, InMultiQueryFacet, OutFacet (also OutQuery coverage), OutMultiFacet, OutMultiQueryFacet, PositionImportFacet. Current Admission Target/interface-derived controls check every installed selector, declaration consistency and actual proxy calls; G4.6 adds exact current interface vector/facet order/metadata/cuts and G4.7 full-name identities. Old exact names/counts are superseded by D22 and the optional-interface amendment; generic facets retain identities. No nonexistent generic package Behavior test is claimed.

O/L helpers (unlock callers, decimal pool ops/TestBases/helpers) remain dependency containers until consumers are rehomed or archived. They are not additional deletion permission. Tracked historical citations use `b019f232a1a109868da81be2d81f94d00a8a0be7:<path>`; untracked candidate/new source needs separate durable capture.

### 6.2 Routes, deploy, reserve and native predicates

| Legacy names/predicates | Current concrete disposition |
|---|---|
| Deploy `test_packageMetadata_matchesExpectedFacets`, `test_deployVault_registersVaultAndInitializesConfig`, `test_deployVault_nativeEthCurrency0_registersVault` | Mapped G4.6/.8: full metadata vectors, component addresses/order, config/types, package/token/contents discovery and strings. Sorted-copy contents identity corrects native discovery while preserving PoolKey order. |
| L Deploy `test_componentSalts_areAbiEncodedNamesOnFactoryPath`, `test_packageSalt_isAbiEncodedNameOnRegistryPath` | Mapped G4.7 each actual CREATE3 address/raw-hash inequality; Admission occupied-binding guard remains complementary. |
| Routes `test_exchangeIn_zap_secondDeposit_checkpointsAccruedFees_afterRoundTripTrading` | Attribution `test_priorFeesIncludedOnceAndNotCallerCredit`, C32 independent mint attribution and G5.14 actual trade→pre-sync probes→positive deposit; G6 core growth/checkpoints. |
| Routes `test_exchangeIn_zap_secondDeposit_refreshesReserves_afterExternalPriceMove` | G5.14 real trade/presync negatives and funded reuse; G6/C32 real D/F/E/local booking. O economic-total durable-reserve expectation superseded by D16 local snapshots. |
| Routes direct EI token0→1/token1→0 and `test_previewExchangeIn_direct_matchesExecution_token0ToToken1` | QuoteExecutionParity/CoreSettlement both directions, G5.14 both funding modes/all actors/passive isolation and actual receipt/debit; G6 distinct recipient/external transition. |
| Routes direct EO directions/preview, `test_exchangeOut_direct_reverts_whenMaxInputTooLow`, `test_exchangeOut_direct_refunds_excess_input` | FormulaDomains/core one-step positives and negatives; G5.14 both directions/full-partial-used-only credit, exact output/allowance/refund; G3 EO maximum/delivery guard matrices preserve common guard/custody predicates in valid domains. Unrestricted multi-step EO superseded by F4. |
| Routes EI second-deposit preview token0/token1, `test_exchangeIn_zap_token0ToShares_secondDeposit`, `test_exchangeIn_zap_reverts_whenMinSharesTooHigh`, `test_exchangeIn_zap_pretransferred_true` | R3 repeated exact mint, independent F5; G5 C48 minimum failure/atomic retry, G3/G6 recipient/supply, Attribution restored pull/push. Old ±10 comparison replaced by D30 exact equality. |
| `test_twoTokenActivation_token0Dominant_previewAndExecution`, `...token1Dominant...` | F0 independent sqrt/minimum, decimal deployed activation, actual dual debits/sink/recipient G3.2 and G4 launch/import. O sink-free supply superseded. Intentional excess in a **live** dual join is not claimed from bootstrap; see L1. |
| Routes EO share exits both faces/preview, `test_exchangeOut_zap_reverts_whenMaxSharesTooLow`, `test_exchangeOut_zap_pretransferred_true` | Positive two-leg inverse superseded by R6; G3.8 supported natural linear both orientations, independent ceil, exact burn/payout/max/credit/refund/retained booked shares; existing idle CC positive and G1 linear outputs. |
| L `test_atomicMintExactOutMatchesPullAndPriorPreview`, `test_atomicMintExactOutRefundsOnlyUnusedBoundedCredit` | Idle positive superseded by R4; G3.3 exactly preserves prior quote, restored-state supported F1 input/shares/book/refund with honest allowance difference. |
| L three `test_R3_3_*` reserve reconciliation cases/helpers | G2 independently observes custody/principal/fees and exact placement baseline; G6 real lifecycle transfer/liquidity reconciliation; G5 pre-sync exact no-credit and funded staged retry; effective-zero controls retained. Loose unpriced token-sum growth/old sleeve ratio expectations superseded by actual attribution/D3. |
| Native `test_zapIn_nativeEthPool_unwrapsWethAndLeavesNoEthDust`, `test_swap_nativeEthPool_wrapsTakenEthToWeth`, `test_zapOut_nativeEthPool_paysWethNotEth` | G4.8 explicitly reversed WETH ordering, actual WETH→pair/pair→WETH and both deposits with unchanged payer/recipient ETH and zero vault ETH. Existing H/P NativeSettlement inherits EquivalentInterfaces and booked zero-ETH redemption; native blocked SY checks exact ERC20 output. No raw-ETH public entrypoint is invented. |
| Nested caller zero-allowance-reject/after-approve-success pair | **Superseded own-share gate**, owner-confirmed current `_secureShareDelivery` debits caller's own shares. G5.5 separately preserves unauthorized third-party ERC20 denial/approval consumption and exact own-share exit. Not an unresolved request to change production. |

### 6.3 FullRangeBook — all ordinary/decimal definitions

| Legacy test/group | Current concrete disposition |
|---|---|
| `test_accruedFees_rebalancePreservesDepositPrice` | Independent E→F-once vectors, G2 pending-own-fee/terminal accounting, Attribution prior-fee mint and F5/C32 independent same-backing pricing preserve fee ownership. Old “within wide deadband therefore never moves L” is superseded by exact D3/D21 placement/progress conditions. |
| `test_launchHelperActivatesBothTokensAndDoesNotReseed` | G4.10 actual PoolSeedLib receiver/debits/cleared allowances/replay/later unilateral intake. |
| `test_externalDepositTransition_preservesFundedHolderBook`, `test_externalSwapTransition_preservesFundedHolderBook`, `testFuzz_transitionSequence_fundedPool` | G6.1 both faces/all four precomposed external operations, exact next fields/passive holder claim and recipient/supply. C32 complementary independent accounting; no generic book-hash substitute. |
| `test_transitionFullRedemption_retainsUnswappedInput` / `_assertFullRedemption` | G6.3/.4 positive actual partial consumption, exact selected payout, independently reconstructed opposing cash and remaining claim/complete next state; .8 already-at-limit retains full entitlement. |
| `testFuzz_fundedSleeveWithdrawalRounding`, EO branch of `testFuzz_freeInventoryExit_matchesQuote` | Two-leg inverse superseded; independent F2 EI + G3.8 linear ceil/budget/actual receipt/burn. EI branch maps G5 both funding modes/contexts and G6.2 entitlement. |
| `test_accruedFees_blockedDepositMatchesIdlePreview` | Cross-context idle F5=blocked F1 equality superseded by plan §8. Context/quantity/G3 quote within correct mode; G6 exact fees/next state. |
| `testFuzz_zapOut_accruedFees_matchQuote`, `testFuzz_zapOut_previewIncludesRemovedLiquidity` | G6.2 independently calculated removed L/local+fees and actual conversion; every post-removal active-liquidity/own-checkpoint field observed. Core/C32 retain independent rounding controls. |
| `testFuzz_singleDeposit_preservesInvariantPerShare` | Idle invariant-growth formula superseded by D5/D6/F5 proportional issuance. Current core/C32 assert independent min-ratio and flooring-inclusive1bp; blocked F1 reference retained. |
| `testFuzz_firstDeposit_preservesEveryDonatedAsset` | G5.3 both donated legs, exact residual sink and per-token entitlement inequalities; G4 native independent prior-sleeve exclusion. |
| `testFuzz_singleDeposit_roundTripPreservesIncumbentValue` | Nested cross-mode bounded cycles, C32 independent contribution/exit/fee attribution, G5 unchanged passive holders and global custody. Old amounts/leaf Cartesian product are not additional predicates. |
| `testFuzz_zapOut_exactOutputChargesQuotedShares` / `_assertWithdrawalBudget` | Search-based two-leg inverse superseded; G3.8 natural linear exact ceil/output/burn/budget/atomicity and existing idle linear+CC; G1 consumer share-budget boundaries. |
| `testFuzz_directSwap_protocolFeeQuoteMatches` | CoreSettlement actual directional protocol-fee/core signed deltas and independent floors; P fee semantics separate. Original fuzz sample range is not a new mandatory matrix. |
| FR1 center full-range/unused wings; FR2 spot walk; FR3 rebalance preserves ticks; FR4 blocked join→repair | G6.5 explicitly checks full usable bounds/salt zero, old tight/wing positions and both alternate full-range salts absent at activation/walk/blocked join/repair; real owned liquidity, fee/cash ledgers. G2 supplies exact new terminal band proof instead of permissive legacy helper. |
| FR5 actual dual activation then single intake | G3.2/.6 missing credit/zero-leg/first blocked funding, G5 floors/metadata, existing single-sided early InvalidRoute/decimal later composition. Old zero-preview/ZeroAmount/sink-free expectation superseded where current error/domain differs. |
| FR6 actual NFT conversion including fees | G4.4 actual fee/principal/full withdrawal and exact issue; .14 complete emptied core tuple/SY both faces; PositionImport full-range retained NFT; native independent funding/sink evidence. P zero LP fees is the correct F4 model. |
| `test_importRejectsUnfundedSideAndRollsBackNftTransfer` | G4.2 each naturally missing NFT leg despite local donations; precise error and full NFT/custody rollback. |
| `test_importEnforcesOwnershipAndMinimumWithoutCapturingSleeves` | G4.1 owner/manager, .4 expected+1/retry and actual receipt; native donation-exclusion control. |
| `test_nativeSYMetadataRateAndFacetSize` | Facet/delegate/runtime, reward emptiness and selector calls map RuntimeAndWork/Admission; **exact returned yieldToken/assetInfo/geometric exchangeRate values remain L2 below**. Smoke invocation is not exact-value evidence. |
| `test_nativeSYRoutesInternalBalancesAndSlippage`, `test_nativeSYUsesFundedSleeveDuringManagerSession` | G3.7 restored aliases, G5.11/.12 exact minimum/retry/context/recipient/surplus, blocked SY both directions. Embedded two-leg EO positive superseded by R6. |
| L `testFuzz_importedPositionCannotBecomeUnfundedCredit` | G4.5 exact EOA versus code-bearing zero-credit, both faces, full unchanged fingerprint. |
| L `test_M3_noImportedIncrease_permit2AllowanceToPositionManagerStaysZero` | G4.4 zero **PositionManager spend** ERC20/Permit2 entries, cleared NFT approval, empty retained NFT and exact sink/supply; intentional ERC20→Permit2 settlement allowance is not incorrectly zeroed. |
| L `test_A0_importBelowFloor_rollsBack` | G4.3 independently measured proceeds/minimum payload and restored NFT/zero supply/custody. |

### 6.4 Multi — all MJ1–MJ8 and ME1–ME7

| Legacy test | Current concrete disposition |
|---|---|
| MJ1 length; MJ6 unsorted/duplicate/nonpool/wrong output; MJ8 descending | G3.6 actual malformed vectors and both preview/execution modes; valid single EI remains R3. No need to invent a valid reversed vector. |
| MJ2 proportional/full-range/sleeve | F0 activation/dual reference, G3.2, G6.5 exact position and G2 new sleeve observer. |
| MJ3 unbalanced join pays both, excess retained | **L1:** pure min-ratio and scalar surplus references exist, but actual positive intentionally-unbalanced Multi payment/excess assertion not located in replacements. Do not call a balanced G3 join that test. |
| MJ4 blocked first join→placement | G3.2 exact first funding/zero L then idle L/no additional issuance. |
| MJ5 no delivery/no free mint | G3.6 second-leg exact delivery failure with full rollback; existing caller-bytecode guard controls and G5 account isolation preserve EOA/contract distinction. |
| MJ7 idle/blocked preview parity | Existing bootstrap/FormulaDomains/Nested plus G3.2 exact blocked and G3.6 negatives; G6 actual dual-activated book. |
| ME1 invalid vector length/single positive | G3.6 vector negative; old two-leg single EO success superseded, use R5 or natural linear R6 positive. |
| ME2 exact dual outputs/ticks | FormulaDomains payout/supply, G3.4 exact both payouts/full book and blocked unchanged position; G6 canonical managed bounds. No blanket prohibition on permitted subsequent holder placement. |
| ME3 unequal vector no partial payment | FormulaDomains unequal-ceil InvalidRoute; G3.5/.6 and budget rejects full dual payout/share/book atomicity. Old availability classification superseded by current formula-domain error. |
| ME4 each-leg cover/whole transaction | G3.5 specifically isolates each cover failure after proving equal ceil/other leg funded; both flags and preview. |
| ME5 too-low maximum | G3.4 exact max-1 error, push transfer rollback and independent pull negative. |
| ME6 idle/blocked quote parity | G3.4 independent ceilings versus actual execution; both contexts, both funding modes. |
| ME7 oversized maximum/unused shares | G3.4 actual used-only/excess/over-max credit, booked31 untouched, exact burn/payout/net debit and retained surplus. Source supply bounds remain; unused **budget** is not an assumed delivered balance. |

### 6.5 LocalLiquidBuffer — all 27 ordinary/decimal definitions and H2

| Legacy names/groups | Current concrete disposition |
|---|---|
| T9 reserves/free/deployed; T4d donation/supply | G2 actual D/F/E/custody, G5.3 no mint on donation/entitlement, C32 books; O durable-economic-total meaning superseded by D16. |
| T1 sleeve; T1b no EI refund | Exact current target vectors/live oracle/G2; G5/C32 full debit/no refund. Percentage-of-total/wide tolerance superseded by D3/D21. |
| T2/H1 blocked deposit; T3 later repair | G3.2 first blocked activation; G5.13 blocked credit histories; G6.5 blocked join→real repair and G2 independent progress. |
| T4/T4b/T5/H3 blocked payout/wrong-face/short cover | Two-leg EO success superseded; independent F2 and blocked SY real requested-face shortage, G3.5 dual leg isolation, G1 linear cover versus share-budget distinction. |
| T4c idle always-manager/no-sleeve-first | Blanket two-leg EO/mandatory-manager expectation superseded by R6/CC; existing idle natural-linear closed-placement positive retains funded payout. |
| T6 blocked direct; T7 idle direct+repair | G3.1 blocked **EI** exact errors both flags/directions; R1 direct positive and G2 terminal repair. |
| T8/T8b deposit preview/execute | Repeated exact R3, independent F5, G6 complete transition. |
| H4/T11/T10/T11b type/default/override/live cascade | Maintenance zero-inheritance/effective-zero, current `FullSpreadConsumerPolicy::test_T10_policy_storedZeroInheritsLiveTypeDefault`, G5 actual live sleeve history. No new fee domain from family rename. |
| T12 first blocked activation | G3.2 independent sink/supply/local-only then position created. |
| T14 blocked public repair; T4e blocked import | Existing Nested exact interaction-blocked and PositionImport NFT retention. |
| T15 within band; T16 outside band | G2 placement preference/exact no-trade and actual partial/useful terminal improvement; no-trade is not a universal no-unlock promise. |
| T4f “rebalanceNoSwap” | Name is not the predicate: old body only required inventory. Inventory is observed exactly in G2/G6; blanket no-swap policy superseded by D9. |
| T13 blocked reentrancy | G5.7 actual callback count, exact IsLocked, token-owned claim/payout isolation, propagating rollback and later reuse; maintenance-only old coverage no longer sole evidence. |
| H2 real buffer hook mid-swap | G1 actual production consumers, both underlying faces/contexts, exact raw receipt and SE supply/hook holdings; funded callback real manager. Original decimal leaf duplication not a new required cross-product. |

### 6.6 TWAP — all seven tests, including decimal copies

| Legacy test | Current concrete disposition |
|---|---|
| H14 bound pool/oracle/poke | G4.11 actual oracle+manager, cardinality0→1. |
| H15 first tick/cumulative | G4.11 final spot equals recorded/prev tick, initial cumulative zero. |
| H16 misleading fail-open name | **F baseline selected by PRD§3/plan§1.** O fail-open success specifically superseded. G4.12 genuine underlying update then counterparty fault propagates/rolls back every observed economic/oracle field; retry succeeds. |
| H17 no transfer poke/foreign writes | G4.11 transfer unchanged, maintenance no foreign poke, actual foreign explicit update isolated. |
| H27 shared package oracle | G4.11 second actual proxy shares oracle/manager. |
| H29 zero/mismatched constructor | G4.9 real registry/CREATE3 rejection and no registration. Inner historical constructor payload is masked by the required production deployment path; observed boundary error is asserted rather than fabricated. |
| H28 changed-manager instance | G4.13 exact processArgs mismatch/no registration and restored positive. |

### 6.7 O adversarial — SecurePull 19 and E6/Import/A0 8, plus decimals

| Legacy names/groups | Current concrete disposition |
|---|---|
| SecurePull I1 inventory/no-in-call-transfer; claimed≤inventory; honest pull | G4.5 post-import, G5 pre-sync and C48: exact code-bearing zero-credit and distinct EOA errors plus positive actual funding/atomicity. Canonical EOA error precedence supersedes stale old payload only. |
| A1 token donation; A2 donated SE shares; A3 pair donation | G5.3 no issuance/passive ownership, G3 booked31 share budget isolation, G5.11 booked self-share theft denial, full global/share ledgers. D15 valid unbooked claims remain permitted independent of donor. |
| E1 swap roundtrip; E4 victim share balance | CoreSettlement F4 fees and C32 independent economics, nested bounded cycles and G5 mixed opposite swaps/passive-ledger invariance preserve no uncredited gain. No requirement to clone the old amount trace. |
| E5 zero/EI deadline/unsupported token/EO deadline | G5.10 exact valid-domain errors and rollback; numeric zero view behavior remains separate. |
| F1 diamond cut blocked | G5.9 actual NoTargetFor/loupe/ERC165, not merely missing facet in a list. |
| H2 max-input; H3 min-output/max-share atomicity | G3 supported EO max/short-credit full digests, G5 C48 minimum failures and M real late swap, G6.7 partial late minimum; no orphan/attacker shares. Two-leg positive setup superseded as necessary. |
| J1 target declarations/J2 proxy loupe/J3 calls | Current Target controls, Behavior_IFacet/cuts/metadata G4.6, actual proxy query and money tests; D22 identities/optional interface additions supersede old fixed arrays. |
| E6 EO cannot sweep other users' booked shares/exact-used cannot refund leftover | Two-leg EO positive superseded; G3.8 supported linear with booked31, all credit/max modes, exact burn/payout/refund/remaining self-shares; F3 complementary. |
| E6 EI fat share claim | Booked self-share rejection G5.11 and exact actual-share short-credit rollback G3 common share delivery/budget controls preserve no booked subsidy; G5 M actual pushed R5 and share/supply ledgers. |
| IMP wrong manager/unbound manager/wrong owner | G4.1 exact three trust causes and full no-mint/NFT rollback. |
| A0 donate→first mint / dust share→donation→victim | G5.1 minimum floor, .3 per-token first-minter inequality/exact sink, F0 dual reference, independent C32 subsequent issuance/exit ownership and no-zero-share tiny guard. Mapped by ownership predicates, not a claim of an identical combined historical attack trace. |

### 6.8 Shared Delivery/Release/FullSpreadAdversarial assertions

V4 adapters are `U/remediation/UniswapV4FullSpreadStandardExchangeVault_{Delivery,NativeDelivery}.t.sol` and `U/adversarial/{TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial.sol,UniswapV4FullSpreadStandardExchangeVault_Adversarial.t.sol,UniswapV4FullSpreadStandardExchangeVault_NativeAdversarial.t.sol}`. Shared bodies contain **27 Delivery + 12 Release + 44 FullSpreadAdversarial** test definitions. Their V3 users remain maintained.

| Full shared predicate group (including helper assertions) | Concrete replacement / supersession |
|---|---|
| Phantom credit after either real price move, no-position, rebalance, import; EOA and contract negatives | G5 M `_postTradeFiveRejects` before sync, G4.5 after import, Attribution/C32; exact account/quote/custody digests and positive funded reuse. No-position positive bootstrap classification follows current R3/F0 guards. |
| Atomic router funding, pull/push after movement, short/excess delivery, distinct recipient, staged failure and retry | G5 C48/M `_mint`, `_stagedShort`, `_restingPartial`, G3.3/.7 recipient/allowance effects; exact prior transfer persistence versus atomic rollback, no EI refund/replay. |
| Multi missing second credit / one excess leg; dual paid surplus | Missing credit G3.6; exact generic credit/booking controls remain. **Intentional positive Multi excess itself is L1**, not silently mapped from scalar excess. |
| Pushed direct EI, R5 share input, booked self-shares, unpushed direct/EO, replays | G5 M real pull/push EI across actors/faces, C48 replay/false credit; G3 book/refund matrices and G5.11 booked share denial. Funded EO negatives select current eligible domain so unsupported route cannot mask delivery. |
| Pushed direct EO unused credit; all E6 token/share/vector matrices; pull max/allowance modes | G5 M `_directExactOut` and C48 exact-shares three credit modes; G3.4/.8 all exact/fat/used-only/partial/over-max/short modes, unchanged booked31, exact payment/burn. Old own-share allowance consumption expectation superseded by confirmed caller-owned debit; third-party approval tested G5.4/.5. |
| Blocked push deposit and both-entitlement exit; positive/zero sleeve cover failures | Independent F1/F2, G5 actual blocked pull/push histories, blocked SY exact both-face cover, G3 dual/linear matrices. Old ±5 is not retained as a deterministic parity tolerance. |
| Idle/blocked two-leg EO share success | Specifically superseded R6/F2/F6. Corresponding security predicates mapped to natural-linear and F3 valid domains, with old unavailable route asserted negative. |
| Removed prepare, no cut, all declarations/proxy selectors and query/SY calls | G5.9, current Admission Target-derived controls, G4 full metadata/salts and actual financial calls. Exact SY returned metadata/rate values remain L2. |
| Real FoT and recorded/propagating nested money-path callbacks | G5.6/.7/.14, exact short-delivery/IsLocked, token-held claims, callback counter and actual underlying burn/approval/custody rollback, later valid use. |
| Address/package disable, valid exits/SY and re-enable | Existing address disable test + G5.8 package SE/SY blocked inbound, valid F3/SY exits and funded re-enable; obsolete two-leg exit replaced, not blanket disabled. |
| Allowance-free SY caller, internal holder/excess/recipient/insufficient funds/ordinary denial/late failure/context retry | G3.7, BlockedYieldEquivalence, G5.11/.12 and G6.2/.7 exact burns/payments/full state; no caller can reuse completed SY context to claim booked shares. |
| Sleeve choices .02/.2/.5/1 and both-face funded/unfunded histories | G5 M actual live writes/repair/subsequent blocked mint, G2 correct target/bands; old p=1 all-local assumption superseded D3. |
| Permit signed spender, spent allowance, replay | G5.4 exact values/nonce and error selectors/payloads; no arbitrary recovered-signer value invented. |
| A0 decimal floors/minimum+1, metadata failure, dead shares/donations/victim issuance | Independent F0 decimal vectors, deployed decimal ZapAndPlacement, G5.1/.2/.3 and C32 independent issuance/entitlement. Below-six/odd decimal vectors remain source-shared formula evidence, not falsely reported deployed G5 variants. |
| No maintenance reward, no share issuance, full local/self books | Independent G2 proxy/caller/approval observations; G6 actual transfers/liquidity; G5 M complete all-holder history. Old approximately200/1000 local target superseded D3. |

### 6.9 Historical evidence, candidate and exact 24-action disposition

| Source | Disposition |
|---|---|
| `U/remediation/UniswapV4StandardExchange_PreservedBaseline.t.sol` + six `StandardExchangePreservedBehavior.sol` tests | **Historical at baseline SHA**: no-movement rejection, omitted opposing entitlement (100 vs190), both-face phantom mint/redemption and APEX aliases intentionally demonstrate old behavior. Do not retarget and invert exploit assertions. Current negatives/entitlements map G4/G5/F2/C32. |
| `U/adversarial/UniswapV4FullSpreadStandardExchangeVault_F6Diagnostic.t.sol` | Diagnostic positive delivered=returned preserved by G6; logged discrepancy historical. Exact EI parity mapped G6; general two-leg EO positive superseded; valid linear exact burn/output/retained surplus mapped G3.8. |
| Candidate primitive swap/Python vector, fee-bearing miss, 25bp incomplete repair, radical undershoot | Historical unadopted findings, plan§2.8/manifestE4. **Untracked: baseline SHA does not archive them.** No repair/adoption work. Current partial progress G2 is independent of candidate. |
| Candidate sleeve-is-not-total vector | Mapped current `test_sleeveIsFractionOfFinalDeployed`:120,.2→20,1→60,0→0; old24 comparison historical. |
| Old V4 invariant adapter + shared StandardExchangeHandler | Predicate-level mapping below closes former “must clone24” backlog. Keep V3 shared behavior. Archive V4 old fixture only after final gate; C32 alone is not claimed to replace the entire handler. |

| Legacy action | Current actual predicates / source |
|---|---|
| 0 EI deposit pull | C32 independent F5/F1; C48 finite allowance/credit; M `_moneyIn` every actor/face, exact debit/issue/no refund/passive accounts. |
| 1 EI deposit push | C48 actual atomic funding/replay, Attribution restored parity, M every actor/face idle funded push. |
| 2 EI share redemption pull | C32/G6 independent entitlement; M idle/blocked exact owned debit/burn/payout and passive isolation. |
| 3 EI share redemption push | M actual wallet share delivery both contexts/faces, independently tracked burned supply/global custody; G3 self-share retention cases complementary. |
| 4 EO mint pull | Idle success superseded R4; G3.3 independent supported F1/restored ledger; C48 all actors used-only input/finite approval; C32 predecessor minimality. |
| 5 EO mint push | Same supersession; C48 three refund modes and exact shares; G3.3 bounded excess and recipient. |
| 6 EO redemption pull | Two-leg positive superseded R6; G3.8 independent natural-linear ceil, exact/fat/short maximum and booked31; idle CC separate existing positive. |
| 7 EO redemption push | Same supersession; G3.8 full/partial/used-only/over-max/short matrices, exact output/burn/retained booked inventory; G3.4 dual idle/blocked. |
| 8 direct EI pull | Real core F4, G6 external full-state sequence, M all actor/face receipts/passive holdings/approvals. |
| 9 direct EI push | M atomic funded all actor/direction swaps; preview before funding, no refund/issuance, global custody. |
| 10 direct EO pull | Positive first-step/CC required (no swallowed InvalidRoute); M both directions/actors, exact output and maximum-used allowance; existing FormulaDomains/CoreSettlement. |
| 11 direct EO push | M three actor-selected delivered budgets, exact `delivered-used` refund and used net debit/output/passive ledger. |
| 12 share transfer | C48 exact sender/recipient updates, independently maintained each-holder ledger and total supply. |
| 13 external trade then5 pre-sync rejects | M `_postTradeFiveRejects`: real trade, both-face contract EI+supported blocked F1 EO and EOA guard, no successful sync in between, exact15 rejects across3 rounds/digest. |
| 14 donation+repair | M donor debit/no resulting reward/issuance/passive approvals, complete custody; G2 nonzero useful-swap/terminal proof separately. |
| 15 trade then fee collection via deposit | M trade+probes→positive deposit, C32/G6 exact fees/checkpoints/ownership, G2 actual pending H fees; P zero own LP fee correctly distinct. |
| 16 live sleeve changes | M .02/.5/1/.2 writes/repair/positive blocked follow-up, no reward; independent G2 policy. Old total-percentage meaning superseded. |
| 17 contract no delivery | M both-face valid-domain exact zero-credit/digest; G4 imported state and C48 replay. |
| 18 EOA no delivery | M exact guard/no attacker accounts; G4 plus constructor/delegated wallet controls retain bytecode semantics. |
| 19 atomic and staged short delivery | C48 atomic short funding rollback; M `_stagedShort` actual prior transfer survives failure then smaller funded amount succeeds, no refund/passive account change. |
| 20 successful push then replay | C48 positive mint→exact no-credit/digest; exact attempt/success/rejection count per actor. |
| 21 token reentry | G5 deterministic plus M recorded/propagating SY/SE callbacks, real token claims, exact lock/counter rollback/disarmed funded reuse; callback3e18 ledger. |
| 22 resting partial credit | C48 distinct payer/consumer, payer loses2×, consumer token debit/refund0, selected half consumed, remaining booked, minimum failure retains prior transfer and replay denied. |
| 23 atomic late slippage | M actual idle direct swap via pull/approval then exact late failure/full rollback; G6 partial late minimum and G5 SY are complementary, not substituted blocked-only checks. |

Cross-cutting old `assertAccounting`/`assertCampaignCoverage`/`afterInvariant` predicates map to C48 exact48 steps, six attempts/action, all actor/refund modes, M exact scheduled money/reject counts, and independently maintained issued/burned/holder/custody ledgers. Zero attacker/handler/self custody and no swallowed unexpected revert remain explicit. The legacy literal action-array length and fixture-specific allowance model are not extra invariants of H/P.

## 7. Remaining mandatory disposition and validation

**G1–G6 scoped work is implemented and has passing evidence.** The earlier proposed test-name lists are not outstanding implementation instructions. No new whole native/decimal/context Cartesian campaign, literal24-action clone, isolated canonical-P-manager constructor branch, or specially positioned successful64th-step endpoint is made a gate.

Two **retained exact legacy predicates** were not positively located in the inspected replacement tests. They are narrow mapping/coverage items, not demonstrated production defects and not permission to rerun the entire old suites:

| ID | Actual predicate still requiring a current assertion or explicit disposition | Why existing nearby evidence is insufficient |
|---|---|---|
| **L1** | O/L `test_MJ3_unbalancedJoin_paysBoth_surplusStaysSleeve` and shared `test_I2_dualJoinOneExcessLeg_creditsRequestedOnly`: successful intentionally unbalanced live dual funding, both declared amounts debited/no refund, proportional shares and retained excess fully booked. | F0 pure unequal-input arithmetic, balanced dual activation, scalar underclaim and malformed/missing-second-leg failures are mapped, but none is itself the positive excess-vector custody case. Locate an existing actual predicate or add only this bounded case; no all-decimal multiplication. |
| **L2** | O/L `test_nativeSYMetadataRateAndFacetSize`: exact `yieldToken()==0`, liquidity assetInfo manager/18 decimals, and geometric whole-book `exchangeRate` at the observed book. | Runtime/reward/selector and SE/SY money parity are covered. Current Admission merely calls `sy.exchangeRate(); sy.yieldToken(); sy.assetInfo();` without asserting their returns. External StandardExchangeRateProvider parity is a different API. Keep the exact returned-value predicate visible until mapped or explicitly superseded. |

Everything else in the inventory is mapped by its specified predicates or specifically superseded/historical above; this is not a claim that the same350 old functions were executed on each new family. L1/L2 prevent an unconditional “all legacy assertions closed” claim. If the parent supplies an existing exact current assertion, record it rather than duplicate it.

Final validation/retirement requirements (**G7**, see readiness draft):

1. Collect final expected450-family results with refreshed runtime artifacts and **128 fuzz runs**, including enhanced G5 histories, G4 native fix/extensions and both G6 work-limit cases. Old436 and latest16-run G5 are correctly bounded prior evidence.
2. Collect refreshed **post-F6** broad consumer result; 12,050 green predates F6. Match actual final source/artifact/runtime identities, include affected consumer/script/loader checks and collect final combined QA/review disposition. Do not infer failure while the parent's job runs.
3. Resolve L1/L2 and capture final dirty/untracked source and historical candidate evidence durably; complete final active import/artifact inventory. Obtain the owner's audit-submission-readiness/retirement checkpoint.
4. After that gate only, execute the exact finite removal and old-test/aggregate reference disposition; preserve shared V3/helpers/core/new families. Then refresh/retest the **post-removal revision** and identify it in audit handoff.

## 8. Maintained / release / adversarial / invariant / aggregate import split

| Partition | Current disposition |
|---|---|
| Maintained production/deployment/discovery | Consumer ledger enumerates H/P typed FactoryServices, DETF/Pons fixtures, fee accrual, main/testnet Stage05-03, main07-01, local Script12, exports/inventory and rehearsal. Preserve ordinary opaque interfaces and original live deployment identities. Final imports **and artifact strings** need final-tree verification; historical export/address files are not silently relabeled. |
| Maintained consumer tests | Seven old-suffixed SE matrix rows bind H; real Pons tests bind P. New G1 covers all6AMM actual same-manager EO and natural-linear outputs. Old filename suffix does not imply old bytecode. Preserve V3/Morpho/Pons-v1 controls. |
| Legacy release/O/L | Assertion disposition is §6 plus L1/L2. Old SUT leaves stay present until gate; archive only after exact predicate resolution and durable revision capture. |
| Shared adversarial helpers | `StandardExchangeFullSpreadAdversarialBehavior.sol` and `FullSpreadLiquidityProvider` retain V3 users. V4 matrix uses `contracts/test/stubs/UniswapV4FullSpreadConsumerLiquidityProvider.sol`. Preserve shared file; do not delete its V3 behavior to remove a V4 import. |
| Invariants | Old V4 adapter's24 predicates now map C32/C48/M/G3/G6. Preserve shared StandardExchangeHandler and V3 adapter; finite source retirement must explicitly remove/rehome only old V4 compilation roots. |
| Aggregate imports | `test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol` imports old O FullRangeBook/InQuery/InMultiQuery/OutMultiQuery/OutFacet-OutQuery leaves (previously observed128/130/132/154/310); Pons imports288–290 are maintained. Update only old leaf imports after disposition, not unrelated DETF/hooks/Pons. Final audit must verify current line locations/import closure. |
| Historical provenance | Preserve old README/source map/hashes/build context/VALIDATION/REGRESSION_RESULTS/artifact records and six obsolete code-linked documents at qualified revision. Candidate untracked evidence is not archived by HEAD alone. Do not rewrite old results as new-family evidence. |
| Removal boundary | Manifest **44+36 Solidity and6 documents**, both replacement subtrees excluded; shared CP/V3/Crane V4/math/Pons/network constants/unrelated metadata/live instances preserved. Re-enumerate drift, never recursively delete parent directories. |

**Reconciled counts:** 29 acceptances,31 decisions,11 routes,7 formulas indexed;250 O+100 L direct definitions plus shared/inherited predicates dispositioned; all24 legacy handler actions explicitly mapped; G1–G6 scoped passing evidence recorded; **2 narrowly identified retained-predicate mapping items**, final combined validation and owner/post-removal gates pending. This documentation task executed no tests and grants no retirement approval.
