# C03 - V4 hookless FullSpread independent original

## Identity, scope and conclusion

- Reviewer: C03, Sisyphus-Junior; assignment/session attribution supplied by `REVIEW_MANIFEST.md:149`: `bg_7b3d0456`, `ses_ee93e2459ffe8sh0oMgsj0FPiQ`. No independent scheduler/timing certification is made here.
- Snapshot: IndexedEx `5709cb3507a9df72b11ec476d27b79ef88696c3a` **plus the working tree**, including the modified hookless `AttributionAndBooking.t.sol` and shared rate provider. The manifest identifies Crane `b35609951b4951a3c107e267e22844a50c4dc043`; its contract bodies were not reviewed. Dirty-file content hashes are unavailable (`REVIEW_MANIFEST.md:32-44,48,82,99`). This is not an immutable release attestation.
- Authority: `docs/plans/APEX_STAGE2_REVIEW_PRD.md`, the run manifest, current readiness PRD OD-02/04/05/07/08, and the hookless family documents cited below. The manifest records owner acceptance and authorization at `:9-30`.
- Method: working-tree Read/Grep/Glob inspection only. No shell, Forge, builds, tests, simulations, RPC, source edits, peer reports, or cross-review. The only authored file is this original.
- Report state: **PARTIAL_REPORT for the wider hookless family; assigned primary outside-trade source/test inspection completed.** The named test and local delivery implementation support the narrow outside-trade property, subject to assertion and execution-evidence limits. They do not close every original R3 route, analytic-math domain, or release criterion.
- Supported findings: **one Medium code defect, one Low quote-contract mismatch, one Low test deficiency, and one Informational evidence gap.** No supported Critical/High finding or demonstrated asset loss in this inspection. Readiness is not established.

## Citation key

All paths are repository-relative. To keep the source references legible, the following exact expansions apply throughout:

- `H/` = `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`.
- For names `Common`, `InventoryMath`, `ProtectionMath`, `TransitionPlanner`, `QuoteService`, `RouteTypes`, `ExecutionContextRepo`, `InBase`, `InTarget`, `InExecutionDelegate`, `InQueryTarget`, `InQueryFacet`, `InMultiQueryTarget`, `OutBase`, `OutExecuteTarget`, `OutExecutionDelegate`, `DFPkg`, and `ComponentFactory`, the file is `H/UniswapV4FullSpreadHooklessStandardExchangeVault<Name>.sol`; the exception is `ComponentFactory`, which is `H/UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService.sol`.
- `AnalyticComposition` = `H/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol`.
- `Acceptance` = `H/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol`; `FamilyBase` = the adjacent `TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol`.
- `T/` = `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`.
- `QuantityChecks` = `contracts/test/bases/TestBase_UniswapV4FullSpreadExactOutputQuantity.sol`.
- `RateChecks` = `contracts/test/bases/TestBase_UniswapV4FullSpreadRateContext.sol`.
- `RateProvider` = `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`.
- `Readiness` = `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`.
- `Stage1` = `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md`.
- `OriginalPlan` = `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md`.
- `FamilyPRD` = `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`.
- `FamilyPlan` = `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md`.
- `AnalyticPRD` = `docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md`.
- `ContextAddendum` = `docs/plans/UNISWAP_V4_FULLSPREAD_CONTEXT_QUOTE_ADDENDUM.md`.

## Primary: S2-ADD-005 outside-trade custody and subsequent credit

### Production path and exact observations

1. **Correct family and deployment.** `FamilyBase:59-109` sets up a real PoolManager artifact, real oracle and hookless components, and deploys the package through `indexedexManager`. `ComponentFactory:176-190,246-252` routes package deployment through the registry and checks its binding hash. `Acceptance:52-59` creates a pool with a zero hook, funds independent external liquidity, and deploys the vault through its package; `DFPkg:365-368` delegates instance deployment to the registry. `DFPkg:394-401` rejects nonzero hooks and uninitialized pools. This is not the Pons fixture, V3, or the deleted historical unsegmented package.
2. **The outside trade is not a vault operation.** `T/AttributionAndBooking.t.sol:34-42` bootstraps, records both custody books and total supply, calls `_externalSwap`, and asserts all three are unchanged. `Acceptance:95-104,106-137` shows the test contract unlocking the manager, calling `poolManager.swap`, and settling/taking against the test contract. The vault is called only in the separate nested-operation branch, not this outside-swap branch.
3. **Pool valuation and delivery are separate.** `Common:312-320,434-450,527-551` reads live local custody, position principal and earned fees separately. `Common:514-523` writes both ERC-20 balances and self-share custody to the reserve book. `Common:900-921` authenticates push delivery as local balance minus booked custody, or pull delivery as the exact measured transfer delta. No deployed-inventory subtraction authorizes caller input. `contracts/utils/LocalCreditLib.sol:13-27` supplies the saturating availability, capped budget and contract-caller check.
4. **Following deposit fixes caller credit before fee collection.** `InTarget:71-80` securely receives the input before delegating. `InBase:279-307` snapshots with that input excluded from incumbent free balances, plans composition, collects fees, executes swap/placement, mints the planned shares, reconciles state, and synchronizes custody. The exclusion is explicit at `Common:986-1009`; collection moves earned fees to free assets once at `InventoryMath:62-67`. The analytic contribution is remaining caller input plus caller swap output, while repriced principal/own fees remain backing (`AnalyticComposition:329-383,503-511`). This supports the delivery/ownership separation, independently of the quote-protection defect below.
5. **Following redemption is funded, on the inspected scalar routes.** `InBase:153-227` requires local cover in blocked mode; idle mode uses measured withdrawal/conversion deltas and checks the final output against actual local balance before paying. `OutExecutionDelegate:25-56` checks delivery/burns only the selected shares, checks local output cover, caps any self-share refund to delivered minus used, and rebooks. This is source inspection, not an outside-trade redemption test result.

### What the named test actually establishes

`T/AttributionAndBooking.t.sol:43-48` performs a funded **pull deposit**, asserts return equals preview and actual share-balance increase equals the returned mint, then `_assertBooked()` checks both tokens, self-shares and no leftover native ETH (`Acceptance:86-90`). Adjacent tests strengthen the coverage: repricing without delivery expects exact `TransferDeltaInsufficient` (`:51-55`); prior fees cannot be reused as credit (`:24-31`); underclaimed surplus is booked without a refund and cannot be reused (`:11-21`); pull/push execution and custody are compared from a restored state (`:58-69`).

Limits: the primary test uses one direction and one following deposit, not a redemption; it does not independently compute the share entitlement, measure the caller's token debit, assert nonzero price/position movement, or assert positive minted shares. Preview/execute equality alone could miss a common-mode valuation error. The helper does visibly call and settle a real manager swap against a seeded pool, and the production pull path independently enforces exact input, so these limits are **not** a claim that the outside trade is fictitious or that the deposit has free credit. No missing-test claim is inferred for uninspected suites.

**Narrow conclusion:** no outside-trade-triggered book refresh or valuation-derived pretransfer credit was found in the inspected path. Source behavior matches the replacement custody property. Do not describe this as a rerun or exhaustive R3 closure. OD-04/08 (`Readiness:130-151,179-186,255-268`) replaces obsolete stored-total cases; none were reconstructed.

## Criterion disposition

Each row separates applicability, review state, inspection, runtime evidence and readiness. Supplemental labels below the primary row are local C03 subrows, not new coordinator acceptance IDs.

| Criterion / authority | Applicability | Owner / review state | Inspection result and evidence | Execution evidence | Supplied outcome | Readiness effect |
| --- | --- | --- | --- | --- | --- | --- |
| **S2-ADD-005**; Readiness REQ-05, OD-04/08 | APPLICABLE to hookless independently | C03 / INSPECTED for named test and deposit path | MATCHES narrow book/delivery property; assertions and limits above; `T/AttributionAndBooking.t.sol:34-55` | INCOMPLETE_PROVENANCE; Stage1:4,28,34 | PASS claimed for named outside-trade test | BLOCKS an independently source-bound runtime-closure claim until provenance is supplied; does not reopen owner acceptance or imply a code defect |
| R3.2, R3.5, R3.6, hookless portion; OriginalPlan:478,481-482 | APPLICABLE under current local-custody model | C03 / PARTIAL across full route set | MATCHES inspected scalar delivery, refund and custody code; Common:900-968; InBase:279-307; OutExecuteTarget:86-113,138-179; uninspected routes below | MISSING for complete route set in this lane; narrow outside-trade claim as above | UNKNOWN beyond named claim | BLOCKS complete R3 closure, not narrow source consistency |
| R3.1 and stored-total equality/greater-than portions of R3.3; OriginalPlan:477,479 | SUPERSEDED as a new-vault reproduction obligation by OD-04; remaining directional/lifecycle controls still applicable | C03 / INSPECTED applicability; remaining R3.3 breadth PARTIAL | MATCHES applicability amendment; no old arithmetic reconstruction | NOT_REQUIRED for reconstructed old cases; MISSING for full remaining breadth | UNKNOWN | Old-case reconstruction DOES_NOT_BLOCK; remaining uninspected breadth blocks full coverage |
| R3.4/R3.7 route and callback breadth; OriginalPlan:480,483 | APPLICABLE | C03 / PARTIAL | Callback caller/action/budget binding inspected at Common:583-594,683-700,784-796 and ExecutionContextRepo:10-105; complete adversarial/route suites not inspected | MISSING for full breadth | UNKNOWN | BLOCKS complete coverage; not proof of a missing guard |
| C03 protection/quote seam; FamilyPRD D20/D30; AnalyticPRD A8-A10 | APPLICABLE | C03 / INSPECTED identified defect | CONTRADICTS: C03-F01 | MISSING for defect-specific runtime case | UNKNOWN | BLOCKS quote/protection-parity closure |
| C03 quantity surface; ContextAddendum:126-138,164-167 | APPLICABLE | C03 / INSPECTED selected scalar quantity methods/tests | CONTRADICTS: C03-F02; meaningful supplied-state and funded blocked positive assertions remain | MISSING for named quantity suite on selected snapshot | UNKNOWN | BLOCKS positive idle-domain contract/test closure |
| C03 provider consumer seam; Readiness OD-02 | APPLICABLE; older self-snapshot parity policy SUPERSEDED | C03 / INSPECTED relevant provider branch and shared test | Production matches OD-02, but inherited shortage test contradicts it (C03-F03) | MISSING for this hookless parity suite; Stage1 only names other provider regressions | UNKNOWN for hookless suite | BLOCKS claim of coherent/current passing family regression coverage; not a reason to restore self-snapshot |
| R12 / Readiness REQ-08 hookless package/selector/size evidence | APPLICABLE | C03 / PARTIAL; C13 release seam | Split source and query selectors mapped; DFPkg:167-188,222-230; InQueryFacet:19-37; C03-F04 | INCOMPLETE_PROVENANCE | PASS claimed for aggregate comparison | BLOCKS family-specific release certification |

## Findings

### C03-F01 - Analytic certification loses the pre-swap price through memory aliasing

- **Class / severity / confidence:** CODE_DEFECT / **Medium** / high for the ineffective comparison; medium for the extent of affected positive quote domains without execution.
- **Origin / snapshot / surface:** new Stage-2 discovery in the selected working tree; hookless analytic composition feeding ordinary deposit previews, transition deposits and execution planning. Not identified as a Stage-1 repair regression.
- **Authority:** `FamilyPRD:49,59`; `AnalyticPRD:79-81,179-188,264-274` require the composition price bound and exact supported/rejection parity.
- **Observed source:** `AnalyticComposition:333` assigns `Types.Snapshot memory original = walk_.state`. That is a memory reference, not a deep copy. `_afterSwap(original, plan_.swap)` at `:343` mutates the same state, including `position.sqrtPriceX96` (`:503-511`). The comparison at `:348` therefore compares `walk_.state.position.sqrtPriceX96` with its own already-updated value. For a positive price, `ProtectionMath:98-103` accepts equal values; this check no longer certifies price movement from the start of composition.
- **Reachability:** `TransitionPlanner:74-85` invokes this planner and returns its valid plan. Ordinary deposits use it at `InBase:264-270`; supplied-state deposits use it at `InQueryTarget:161-168`. The stale `AnalyticComposition:24` comment saying "Not production dispatch" is not a reachability barrier.
- **Impact:** a plan satisfying the other conditions is not screened here for the required start-to-finish composition price impact. This permits a misleading accepted quote/transition where execution's independent impact guard would reject. The exact affected successful-candidate set was not demonstrated in a run; no successful over-limit settlement or theft is claimed.
- **Counterevidence:** `InBase:293` passes `COMPOSITION_IMPACT_BPS` to execution, and `Common:1101-1117` separately records the live starting price, executes, and enforces price impact and exact settlement. Atomic rollback protects the money path. The defect is not removal of that execution guard. `T/ProtectionAndInventoryMath.t.sol:91-102` tests the arithmetic predicate, but not preservation of its two inputs through this planner.
- **Linked criteria:** C03 protection/quote subrow; applicable original R3.4 quote/execution controls; catalog N2. No assertion that the historical 001-M accounting defect returned.
- **Readiness:** BLOCKS deterministic quote/protection closure, not evidence of present fund loss. Corrective objective: preserve a distinct pre-swap price for certification and demonstrate protected rejection/acceptance parity through the real hookless proxy in separately authorized work.
- **Attribution/disposition:** C03 original; not cross-reviewed; coordinator disposition pending.

### C03-F02 - Positive idle exact-share quantity returns zero while its contract and test require domain rejection

- **Class / severity / confidence:** CODE_DEFECT (quote contract mismatch) / **Low** / high for source/test contradiction; no financial impact demonstrated.
- **Origin / snapshot / surface:** new Stage-2 discovery, hookless `quoteInputForExactShares`; no Stage-1 repair continuity claim.
- **Authority:** `ContextAddendum:126-130,164-167` requires blocked-state positive exact-share quantities and lists idle mint rejection; `FamilyPlan:202` distinguishes unsupported positive requests from zero-amount view behavior. Execution retains unsupported idle exact-share mint (`AnalyticPRD:304-311`).
- **Observed:** `InQueryTarget:25-30` decodes a valid state, then returns `0` for a positive request whenever `q.idle`. `QuantityChecks:90-100`, inherited by `T/ExactOutputQuantityQuote.t.sol:5-10`, instead expects exact `InvalidRoute` for that same valid idle-state request. The execution inverse rejects idle at `OutBase:63-68`. The installed query selector is explicitly declared at `InQueryFacet:36` and included through `DFPkg:227-230`.
- **Impact:** unsupported positive input-quantity queries can be represented as zero input instead of the declared domain failure. The checked-in regression expectation and production behavior cannot both be satisfied. No caller was shown accepting zero as a funded mint.
- **Counterevidence:** real execution still rejects; zero-quantity calls validate the supplied state first; the interface's short NatSpec does not itself specify an error (`contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol:5-13`). Ordinary exact-input preview code deliberately uses zero for several failures (`InMultiQueryTarget:19-35`, `InBase:264-275`), but that is not a documented amendment to this positive exact-output quantity contract. If zero is intended for this optional endpoint too, record an explicit reconciliation rather than asserting the existing rejection regression passes.
- **Linked criteria:** C03 quantity subrow; applicable R3.4; catalog N2/J. Execution evidence MISSING, supplied outcome UNKNOWN for the named suite; this is not a freshly observed failing test.
- **Readiness:** BLOCKS this endpoint's contract/test closure. Corrective objective: reconcile the endpoint, its declared positive-request semantics and inherited test without opening unsupported exact-output execution.
- **Attribution/disposition:** C03 original; not cross-reviewed; coordinator disposition pending.

### C03-F03 - Hookless rate-context shortage regression retains superseded self-snapshot expectations

- **Class / severity / confidence:** TEST_DEFICIENCY / **Low** / high for the stale expectation and zero-versus-revert mismatch; actual suite outcome unexecuted.
- **Origin / snapshot / surface:** Stage-2 discovery of a consumer test left inconsistent with current OD-02 behavior. It is not evidence that the Stage-1 provider repair is absent or regressed.
- **Authority:** `Readiness:99-111,291-304` requires empty-state live preview with no self-snapshot and preserves supplied-state quotes separately. This supersedes the self-snapshot policy in `ContextAddendum:144-160`.
- **Observed:** `T/RateProviderContextParity.t.sol:7-18` inherits `RateChecks`. Its shortage test at `RateChecks:88-118` requires a genuine quantity greater than local cover, expects executable preview to revert, then requires the live rate to equal the unfunded snapshot quantity without shrinking that probe. Current `RateProvider:45-47,67-87,148-161` selects ordinary preview for empty state and snapshot quantity only for nonempty state. Current blocked scalar preview returns **zero**, not the expected `InsufficientLocalReserve` error (`InMultiQueryTarget:31-32` -> `InBase:114-119`). The test forces the shortage branch with `shortageExercised` and `assertTrue` at `RateChecks:107,117`.
- **Impact:** this inherited test cannot substantiate current hookless rate-provider acceptance under OD-02. It tests an earlier policy, and its rejection assertion also disagrees with the current vault preview. Treating the named suite as current green coverage would overstate validation.
- **Counterevidence:** explicit post-state supply/rate checks and genuine manager-unlock contexts in `RateChecks:47-85` remain useful. Removing the provider self-snapshot is the owner-directed repair, not a bug to undo for the old test. The accepted Stage1 note names `test_emptyGetRate_ignoresQuoteStateFailure` and `test_failedCallerSnapshot_isNotReportedAsLiveRate` at `:32`, not this shortage test; therefore no false Stage-1 pass claim for this exact test is inferred.
- **Linked criteria:** C03 provider seam, applicable R12 regression validity and S2-REQ-08 assertion review. Shared base is a seam for C11-C12; no Pons result is imported here.
- **Readiness:** BLOCKS coherent hookless rate-context regression closure. Corrective objective: align this consumer test and maintained context-policy text with OD-02 and the specified executable-preview semantics, keeping caller-supplied projection coverage distinct.
- **Attribution/disposition:** C03 original; not cross-reviewed; coordinator disposition pending.

### C03-F04 - Supplied narrative and aggregate comparison do not bind hookless runtime claims to an immutable dirty snapshot

- **Class / severity / confidence:** EVIDENCE_GAP / **Informational** / high for the bounded evidence limitation, not a claim that runs were absent or unsuccessful.
- **Origin / snapshot:** Stage-2 provenance limitation on current hookless acceptance; not automatically STAGE1_OPEN. Owner Stage-1 satisfaction remains recorded in the manifest.
- **Authority:** Stage-2 PRD S2-REQ-03/09 and `Readiness:308-321` require current-source and execution provenance, independently of source inspection.
- **Evidence:** `Stage1:4` expressly says the HEAD-plus-uncommitted citation is not a release identity; `:28` reports only the artifact-test command shape, not the complete per-test invocation/toolchain/log; `:34` claims all four outside-trade tests passed. `:43-55` reports the aggregate selector/size comparison and caveats. The manifest records no dirty content hashes (`:34-44`). The supplied `selector-size-compare-stage1-current.json:1-6` contains aggregate totals. A bounded whole-file Grep for `Hookless`/`hookless` found no named hookless row; aggregate zero-oversize and missing-artifact counts therefore do not independently identify these new family runtimes.
- **Impact:** C03 cannot upgrade the outside-trade narrative to `SUPPLIED_SOURCE_BOUND`, nor certify each hookless deployed component size/selector set from the aggregate counts. This does not establish stale artifacts, missing compilation, fabricated results or excessive bytecode.
- **Counterevidence:** source map and exact test name exist, the dirty test is listed in the manifest, the supplied outcome is PASS, and the owner accepted Stage 1. The comparison JSON and note agree on the reported top-level totals. The earlier comparison files are explicitly stale, not contradictory current runs (`Stage1:43`).
- **Linked criteria:** S2-ADD-005 execution dimension, R12/REQ-08 hookless evidence, C01/C13 provenance seams; historical audit item 001-M replacement evidence, not historical reproduction status.
- **Readiness:** BLOCKS a source-bound runtime/release-certification claim, even at Informational severity; does not block preserving an inspection report. Verification need: supply matching source/test/dependency identities, exact named-run records and hookless-specific runtime/selector records. Any fresh execution requires separate authorization.
- **Attribution/disposition:** C03 original; not cross-reviewed; coordinator disposition pending.

## Evidence ledger (no command below was executed by C03)

| Artifact / origin | Reported selection and command | Source/toolchain binding | Evidence state | Supplied outcome / limit |
| --- | --- | --- | --- | --- |
| Stage1:26-35, accepted Stage-1 author narrative | Four named outside-trade tests; command shape `python3 scripts/forge-artifacts.py test`, named `--test-root` and `--match-test` | Stage1:4 gives abbreviated HEAD plus edits; complete invocations, dirty identities, toolchain versions and per-test log not present in that note | INCOMPLETE_PROVENANCE | PASS claimed, not rerun; only hookless test is assessed here |
| Stage1:41-55 and adjacent `selector-size-compare-stage1-current.json` | `python3 scripts/r12_selector_size_compare.py`; reported exit 0 | Aggregate counts, skipped deleted baseline paths; no named hookless row found in bounded file search; not an installed-proxy certification | INCOMPLETE_PROVENANCE | PASS claimed for comparison, not full release |
| RateProviderContextParity / ExactOutputQuantityQuote / PretransferCallerLifecycle source | Test bodies and inherited helpers inspected | Working-tree source only, no matching named result supplied in the inspected note | MISSING | UNKNOWN; source expectations are not test outcomes |
| Historical full-suite/campaign claims mentioned in readiness documents | Not adopted as this lane's result | Historical or insufficiently bound; underlying logs not inspected | HISTORICAL_ONLY for carryover claims | UNKNOWN for this snapshot |

## Catalog and audit mapping

- **A/A0, E/E6, I/K/FH1:** applicable custody, surplus, zero-supply and refund classes. Scalar credit/refund and zero-supply sink code inspected (`InBase:326-363`, `OutExecuteTarget:138-179`, `Common:900-968`); underclaim, reuse and funded controls read. This is not complete class coverage.
- **B/L3:** applicable pool repricing; primary outside-trade test inspected. No free-credit defect found; no bound on all economic round trips is claimed.
- **C/N:** applicable callback/operation scope and preview/execute parity. Context binding inspected; C03-F01 concerns N2. Reentrancy campaigns were not inspected/executed.
- **J/F:** applicable package/proxy/immutable binding. Query exposure and package cuts inspected; runtime loupe, all component declarations, instance isolation and constructor-negative suites remain outside completed coverage.
- **D/G/H:** applicable imported-position authority, nested consumers, and atomic failure/liveness. Scalar failure guards inspected, not full NFT/consumer/DoS coverage.
- **L2:** forbidden FoT/rebasing-underlying policy applies (`docs/agent/INDEXEDEX_AGENT_LAW.md:89-101`). Exact pull-delta enforcement inspected; configured-token rejection suite not reviewed.
- **M:** no user-selected arbitrary target/payload on the inspected scalar entrypoints; execution delegates are immutable constructor bindings. Package Permit2 allowances exist (`DFPkg:378-384`), so broader allowance/dependency behavior is not declared globally inapplicable.
- **O:** package installs permit infrastructure (`DFPkg:82-84,173,207-211`); signature internals are outside this IndexedEx-only lane, not certified here.
- **001-M:** historical allegation remains CLAIM_UNVERIFIED by C03 because historical source/PDF/reproduction logs were not reviewed. Current replacement conclusion is separate: local custody credit appears consistent, with limited test/evidence closure as above. **005:** concrete hookless LocalCreditLib calls inspected; helper agreement does not close all consumers. **004B:** scalar residual booking and refund boundaries inspected; historical allegation not adjudicated. Other audit entries/retractions are not independently dispositioned in C03. No withdrawn issue is reinstated.
- **D12 residual:** code-bearing contract/delegated callers may consume available unbooked pretransfers without sender attribution; OriginalPlan:102,105 permits this at integrator risk. `T/PretransferCallerLifecycle.t.sol:13-51` checks constructor rejection, real delegated account credit and reuse rejection. No new provenance or atomicity requirement is invented.

## Coverage inventory and exclusions

### Bodies read in full

- Hookless production: Common (both returned sections), InventoryMath, ProtectionMath, TransitionPlanner, QuoteService, RouteTypes, ExecutionContextRepo, InBase, InTarget, InExecutionDelegate, InQueryTarget, InQueryFacet, InMultiQueryTarget, OutBase, OutExecuteTarget, OutExecutionDelegate, DFPkg, AnalyticComposition.
- Hookless fixture: Acceptance and FamilyBase. ComponentFactory was searched throughout and read at :170-262, not fully audited.
- Named tests: `T/AttributionAndBooking.t.sol`, `T/RateProviderContextParity.t.sol`, `T/ExactOutputQuantityQuote.t.sol`, `T/PretransferCallerLifecycle.t.sol`; also `T/QuoteExecutionParity.t.sol`, `T/ProtectionAndInventoryMath.t.sol`, and `T/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticCertification.t.sol`.
- Shared IndexedEx bodies: LocalCreditLib, RateProvider, QuantityChecks, RateChecks and `IStandardExchangeExactOutputQuantityQuote.sol`. Reading inherited shared test bodies is not a substitute product result.
- Full controlling review PRD, manifest, Readiness, Stage1, ContextAddendum and AnalyticPRD were read. OriginalPlan and FamilyPlan were inspected at cited controls/search results; FamilyPRD at :1-100 plus targeted control search; full agent law at :1-130. IndexedEx testing/adversarial skills were read, and relevant Crane skill guidance sections were read directly without auditing Crane contracts.

### Not inspected / not closed

The file inventory was bounded to H and T with Glob; no reviewer directory was read or searched. Everything in those inventories not in the full-read list above remains **UNINSPECTED**, not implicitly approved. In particular:

- `analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath.sol`, its full-width root/domain proof, analytic reference/executor harness bodies, traversal/corpus tests and exhaustive coverage. AnalyticComposition was read, but this is not complete analytic-system certification. Its crossing/discovery behavior and projected-state dependency overlays remain a follow-up boundary; the independently defensible alias defect is reported without claiming domain completeness.
- Hookless PositionImportTarget/Facet, LiquidReserveTarget/Facet, InMultiTarget/Facet, OutMultiTarget/Facet, OutMultiQueryTarget/Facet, OutQueryTarget/Facet, OutTarget/Facet, InFacet, InMultiQueryFacet, family storage repositories, package interface/binding interfaces, decimal fixture variants, consuming-hook harness and production-binding probe. Shared imports such as `StandardExchangeConstantProduct.sol`, `NativeStandardYieldTarget.sol`, `MultiAssetBasicVaultRepo.sol`, registry/core manager bodies and oracle bodies were not independently audited; their call-site boundaries were inspected.
- Remaining T tests: AdmissionAndIdentity, Adversarial, AdversarialReentrancy, BlockedFormulaReference, BlockedYieldEquivalence, ConsumingHook, CoreSettlement, CrossModeStatefulCampaign, EquivalentInterfaces, FormulaDomains, GuardClosure, ImportDeploymentClosure, MaintenanceObservedProgress, MaintenanceProgress, NativePositionImportFunding, NativeSettlement, NestedAndConsumer, OneBackedLeg, PositionImport, ProductionConstructorBindings, RegistryMaintenanceObservation, RouteFundingClosure, RuntimeAndWork, TransitionLifecycleClosure, UnlockContextQuote, ZapAndPlacement, and remaining analytic tests. Their existence is not execution evidence or a missing-test finding.
- Actual deployed proxy cuts, current artifact freshness, individual hookless runtime byte sizes, full selector diffs, native/import/dual-route security closure, consumer matrix and full fuzz/campaign controls remain unverified. The comparison JSON was read only at :1-65 plus targeted whole-file search, not independently recomputed.
- Pons-family and V3 source/tests, including Pons AttributionAndBooking, were not used or read as substitutes. Wings and live immutable instances were not reviewed. No old stored-total equality/greater-than cases were reconstructed.

## Handoff

Preserve this as the independent original. C03-F01 needs a second source inspection during the separately scheduled cross-review; C03-F03 belongs at the hookless/provider seam, and C03-F04 overlaps provenance/release ownership. These are handoff requests, not cross-review performed in this session. Stop for coordinator/owner discussion; no remediation PRD, source patch, test run, deployment or audit-submission authorization follows.
