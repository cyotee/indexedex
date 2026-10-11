# C04 - V4 Pons-family FullSpread independent original

## Identity, scope and result

- Reviewer: C04, Sisyphus-Junior; assignment/session attribution recorded by the coordinator in `REVIEW_MANIFEST.md:146-150` (session `ses_ee93e1344ffeDWTDAjyaGYyHis`). Independent first pass, 2026-10-07.
- Assigned snapshot: IndexedEx HEAD `5709cb3507a9df72b11ec476d27b79ef88696c3a` **plus the uncommitted working tree**, not HEAD alone. Identity is supplied by `REVIEW_MANIFEST.md:32-99`; this reviewer did not independently hash or run git. The Pons attribution test is explicitly dirty at manifest line 83. Crane identity is recorded by the manifest, not audited here.
- Report state: **`PARTIAL_REPORT`**. All six expressly named production files and all three expressly named test files were read in full, including the complete outside-trade fixture chain within the Pons package. Additional binding, credit, planning and execution files were inspected. Full family lifecycle, every shared arithmetic dependency, and all required program documents were not inspected; the missing reads are listed below.
- Primary criterion: **S2-ADD-005, Pons package slice only**, including the assigned distinct binding, fee, protection and registration checks. Requirement anchors are Stage-2 PRD `:166-180,198-228`, readiness PRD OD-04/OD-05/OD-08 and REQ-05, and the current family PRD cited below. No new original R IDs are invented or closed by this report.
- **Hookless closure is not used.** No reviewer originals, peer findings or cross-review artifacts were read. Reading a pure helper imported by Pons is not adopting a hookless implementation or test conclusion. No cross-review was begun.
- No shell, builds, tests, simulations, RPC, source edits, or exploit procedures. Only this assigned Markdown artifact was written. Runtime outcomes below are supplied claims, not reruns.

**Bottom line:** the inspected Pons paths preserve the separation between local delivery credit and live pool inventory, enforce a distinct registered singleton binding, and explicitly model the Pons fee side and separate rounding floors. No supported `CODE_DEFECT` was established in the inspected slice. This is not a family-wide safety or readiness verdict. One evidence-provenance finding limits runtime closure; uninspected route/dependency coverage separately prevents an inspection-complete label.

## Citation key and authority

All paths are repository-relative. The following aliases expand mechanically to exact file paths; a reference such as `P/Common.sol:514-524` means the path obtained by the prefix rules below, not an unverified historical locator.

| Alias | Exact expansion |
| --- | --- |
| `P/<suffix>.sol` | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHook<suffix>.sol` |
| `T/<file>` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/<file>` |
| `B/<suffix>.sol` | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook<suffix>.sol` |
| `Protection` | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol` |
| `Family PRD` | `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` |
| `Family plan` | `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md` |
| `Readiness PRD` | `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` |
| `Stage-1 note` | `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md` |
| `Stage-2 PRD` | `docs/plans/APEX_STAGE2_REVIEW_PRD.md` |
| `Manifest` | `docs/research/apex-stage2-review/indexedex-wt-5709cb35-2026-10-07/REVIEW_MANIFEST.md` |

Controlling precedence:

1. Owner narrows review to IndexedEx and accepts Stage 1: `Manifest:9-30`. Crane bodies remain outside this review, including the manager, quoter, Pons hook and escrow.
2. OD-04/OD-08 require an actual outside-pool trade for **each** implementation, not a transplanted hookless proof: `Readiness PRD:130-153,179-186,255-268`. OD-05 ratifies the split, not either package's security.
3. Pons uses its own fees, quotes, execution and fixed hook: `Family PRD:43-60,353-394`. The Hookless analytic-sizing amendment expressly does not change Pons (`Family PRD:11`; `Family plan:251`, located by targeted grep).
4. Credit-before-collection, incumbent ownership, fixed protection, and full booking: `Family PRD:165-208,313-349,400-452`.
5. Stage-2 states are independent dimensions, and no run is authorized: `Stage-2 PRD:213-245,316-336,427-455`.

## Criterion ledger

The rows below are **slices of the assigned S2-ADD-005**, not additional acceptance IDs or a replacement denominator. All have origin `supplemental`, with Stage-1 continuity linked to REQ-05/REQ-08 where specified. Owner is C04. `MATCHES` means the bounded inspected source/assertions match, never runtime PASS.

| criterion_id / slice | applicability and controlling requirement | owner_and_review_state | inspection_result | source_and_test_evidence | execution_evidence / supplied outcome | readiness_effect and limits |
| --- | --- | --- | --- | --- | --- | --- |
| S2-ADD-005 / outside trade | `APPLICABLE`; Readiness PRD OD-04/OD-08, REQ-05 `:255-268` | C04 `INSPECTED` | `MATCHES` for the observed local-credit separation and regression assertions | `T/AttributionAndBooking.t.sol:37-59`; `B/_Acceptance.sol:82-103,109-151`; `P/Common.sol:514-551,900-922,986-1010`; `P/InBase.sol:279-307` | `INCOMPLETE_PROVENANCE` / `PASS`, Stage-1 note `:4,28-34` | `BLOCKS` source-bound runtime closure, C04-E01; does not establish a Stage-1 regression. Test limitations described below. |
| S2-ADD-005 / singleton binding and registration | `APPLICABLE`; Family PRD D14/D22/D23/D26/D29 and `:370-394` | C04 `INSPECTED` for admission and factory call sites | `MATCHES` | `P/DFPkg.sol:108-154,291-329,374-378,403-428`; `P/FeeService.sol:36-54`; `T/AdmissionAndIdentity.t.sol:32-54,108-146` | `MISSING` / `UNKNOWN` for these tests in the inspected Stage-1 note | `UNDETERMINED` package-wide readiness: real deployment execution and deeper registry/dependency behavior not established. |
| S2-ADD-005 / fee semantics | `APPLICABLE`; Family PRD D22/D30, `:384-394,486`; Family plan `:105-113,337-339` | C04 `INSPECTED` for local model and named controls | `MATCHES` | `P/FeeService.sol:10-59`; `P/QuoteService.sol:72-151`; `T/PonsFeeSemantics.t.sol:17-72`; `T/CoreSettlement.t.sol:48-99,186-217,298-305` | `MISSING` / `UNKNOWN` for fee/core suite execution in inspected evidence | `UNDETERMINED`: local reference-hook bodies and underlying quoter are not audited; core harness is not full vault acceptance. |
| S2-ADD-005 / fixed protection and callback funding | `APPLICABLE`; Family PRD D2/D20/D25, `:167-188,313-349` | C04 `PARTIAL` | `MATCHES` for inspected enforcement; complete protection coverage `INDETERMINATE` | `P/TransitionPlanner.sol:18-23,110-166,216-257`; `P/Common.sol:583-595,683-719,784-806,1101-1122`; `P/ExecutionContextRepo.sol:10-105`; `Protection:98-133`; `T/AdmissionAndIdentity.t.sol:56-62` | `MISSING` / `UNKNOWN` for protection runtime evidence in inspected note | `UNDETERMINED`: shared inventory math and comprehensive boundary/hostile-token tests remain unread. |
| S2-ADD-005 / exact-out funding and quote transitions | `APPLICABLE`; Family PRD `:210-240,425-452,475-486` | C04 `PARTIAL` | `MATCHES` for inspected direct-out and linear-exit accounting; full route parity `INDETERMINATE` | `P/OutExecuteTarget.sol:138-179`; `P/OutExecutionDelegate.sol:25-56`; `P/InQueryTarget.sol:43-82,97-187`; `P/Common.sol:1051-1082` | `MISSING` / `UNKNOWN` for complete route parity | `UNDETERMINED`: OutBase, Multi, position import, SY and consumer routes not closed. |

For each row, confidence is high in the cited local control flow and moderate in its bounded requirement interpretation. Confidence in full end-to-end behavior is limited by the explicit unread dependencies and absence of independently source-bound execution material. C04-E01 is linked to the outside-trade row and the broader evidence qualification, not a claim that all other tests lack artifacts anywhere in the repository.

## Independent technical observations

### 1. Outside-trade continuity and operation-scoped credit

`T/AttributionAndBooking.t.sol:37-52` records both durable token books and total supply after bootstrap, invokes `_externalSwap`, then asserts both books and supply remain unchanged. It follows with a pull-funded token1 deposit, checks exact preview/mint equality and recipient share delta, and calls `_assertBooked`.

This is genuinely an outside-pool-trade fixture path: `B/_Acceptance.sol:101-103,109-138` enters the manager from the **test driver** and calls `poolManager.swap`; only operation 1 in that driver calls the vault. Swap settlement pays/takes the driver's tokens (`:141-150`), not a disguised vault trade. `_assertBooked` compares both ERC-20 balances and self-shares with the durable book, and requires no leftover ETH (`:92-97`).

The production funding path is separately supported by source. `P/Common.sol:900-921` measures a pull's actual balance delta, or derives prepaid availability solely from token balance less booked local reserve. `contracts/utils/LocalCreditLib.sol:13-26` clamps that difference and budget and enforces the code-bearing caller rule at its call site. The snapshot then removes current-call credit from incumbent free inventory (`P/Common.sol:986-1010`), while deployed principal and earned fees are read separately (`:527-551`). `P/InBase.sol:284-307` plans against that snapshot before collection, executes composition/placement, mints the planned shares, verifies the result and books custody.

The adjacent independent negative `test_poolRepricingDoesNotCreatePretransferCredit` expects the exact insufficient-delivery error after a direct external trade (`T/AttributionAndBooking.t.sol:54-59`). The prior-fee test explicitly uses a core donation because the Pons swap itself has no LP fee, preventing the fee-attribution control from relying on zero earned fees (`:24-35`). The underclaim and pull/push controls add no-refund/re-credit and identical-state comparisons (`:11-22,61-72`).

**Limits:** the newly named outside-trade test does not itself assert a nonzero price/deployed-principal change, token spending delta for the later depositor, or an independently derived share quantity. Preview and execution share planning logic; their equality alone is not an independent ownership equation. The companion no-credit rejection, fixture route and production arithmetic materially support this slice, so this review does not label those omissions a demonstrated Stage-1 contradiction. They do limit what the one test can establish alone. No redemption-after-outside-trade claim is made; the requirement permits deposit or redemption.

### 2. Pons binding, registration and package identity are distinct

The DFPkg derives the expected hook from `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` outside the two hermetic chain IDs, requires code and equality with `PkgInit.expectedHook`, and checks the hook's manager (`P/DFPkg.sol:108-120`). Non-hermetic construction also pins chain and manager; TWAP/position-manager consistency is independently checked (`:121-149`). Instance args are checked both through registry-only `processArgs` and initialization (`:291-308`).

Pool validation requires the exact expected hook, currency ordering, usable spacing, zero LP fee, distinct ERC-20 faces, registered launch terms and initialized price (`P/DFPkg.sol:403-412`). `P/FeeService.sol:39-54` checks the manager getter, fixed return sizes, registration, memecoin/quote-currency orientation and fee bounds. This is not admission by flags or ABI alone. Malformed ABI fields may decode-revert rather than return false; no permissive fallback is visible.

The family FactoryService constructs family-specific delegates and verifies installed delegate getters (`P/_Component_FactoryService.sol:27-48,73-95,259-263`). Package deployment calls the registry and checks the occupied identity against `bindingHash` (`:177-191,248-254`). The DFPkg checks facet code, nonempty selectors and family names (`P/DFPkg.sol:415-428`). These are configured-component checks, not claims of arbitrary-bytecode authentication; no codehash pin is required by Family PRD D29.

Tests separately address wrong/malformed keys, independently initialized vaults, occupied package identity, a second real same-ABI/flags singleton, and unregistered/nonzero-fee keys (`T/AdmissionAndIdentity.t.sol:32-54,108-146`). The production-constructor test explicitly discloses that rejection at the earlier hook pin does **not** isolate the later canonical manager-address branch (`T/ProductionConstructorBindings.t.sol:11-13,24-39`). Its registry count rollback and positive construction control are present (`:42-57`); its Launch fixture and probe body were not read here, so this test is not credited as fully inspected production-binding proof.

### 3. Per-launch fees and exact-output domain

`P/FeeService.sol:44-59` reads per-pool launch values and computes two separately floored charges, not a combined basis-point product or a mutable global default. `P/QuoteService.sol:100-112` subtracts the charge from exact-input gross output. Its exact-output path computes core input plus core fee, then adds the Pons charge to input (`:115-145`). The exact-output domain is deliberately strict: no projected liquidity change, nonzero active liquidity, representable amounts, and no first-target crossing. It does not use the traversing quoter or numerical inversion.

`T/PonsFeeSemantics.t.sol:17-43` checks separate floors, both directions and modes, actual pending hook fees and creator tax, and zero LP growth attributable to hook charges. `:45-57` changes defaults/recipients/buyback and compares both quote encodings before settling; `:59-72` contains a bounded test-side search and a non-vacuity assertion for the rounding control. These are stronger than test-name-only evidence.

`T/CoreSettlement.t.sol:27-28` correctly identifies itself as core settlement rather than deployed-vault acceptance. Its `_assertSwap` checks exact input/output, price, tick and active liquidity (`:298-305`); setup registers a real-hook fixture key (`:48-62,229-232`). It supplies useful local model/reference controls without replacing the registered-vault acceptance test. Crane reference behavior remains an external boundary under the owner scope.

### 4. Protection and funding are enforced, not only reported

The family planner fixes 25/50/10/1/1 bp constants (`P/TransitionPlanner.sol:18-22`), checks composition price and post-placement contribution/share alignment (`:131-155`), and evaluates maintenance funding, price and actual final progress (`:216-257`). The imported pure protection helper squares sqrt prices before comparing the price-impact bound, retains an inclusive 1 bp share inequality, and uses the 10 bp shortfall inequality (`Protection:98-133`). Its code contains no Pons/hookless dispatch.

Execution applies the composition impact limit at the Pons deposit consumer (`P/InBase.sol:287-297`), the repair limit in maintenance (`P/Common.sol:634-647`), and checks observed signed deltas and final price/tick/liquidity (`:1101-1117`). Exact equality checks after the shortfall check are stronger for deterministic parity; a diagnostic constant alone was not used as proof.

The family-local transient context requires an active operation and committed plan, binds a callback to manager/payload/plan/liabilities, consumes it once, checks settlement budgets and clears the context (`P/ExecutionContextRepo.sol:10-105`). Common checks the callback caller and consumes authorization before core actions (`P/Common.sol:683-719`); actual settlement spends the authorized currency budget (`:784-806`). This preserves caller/context checks rather than resurrecting a historical missing-callback-guard allegation. Liability commitments are not themselves proven to subtract every liability from every budget: this pass relies only on the explicit checks and action sequencing inspected, not a stronger inferred guarantee.

### 5. Exact-out and projected quotes retain separate domains

Direct exact-out captures prepaid credit before fee collection, excludes it from the snapshot, rejects input exceeding maximum/credit, pulls exactly used on the false-flag path, pays exact requested output, refunds only prepaid provided-minus-used, then places/verifies/books (`P/OutExecuteTarget.sol:153-179`). `_refundExcess` protects the pre-operation token balance before a refund (`:138-143`). The exact-output share exit similarly burns only calculated shares, optionally refunds unused prepaid shares, pays requested output and finishes booking (`P/OutExecutionDelegate.sol:25-56`). This review does not generalize those reads to every Multi/SY/import route.

The transition target binds supplied snapshots to the vault and valid holder-share/tick fields (`P/InQueryTarget.sol:154-159`), explicitly projects unavailable unlock only for the same manager (`:43-49`), and rejects external pool exchange while projected blocked (`:68-82`). Deposits use the Pons planner while idle and sleeve-only math otherwise (`:161-177`). Exact-output asset withdrawal is constrained by the one-backed-leg helper, not a generic two-asset numerical inverse (`:106-117`; `P/Common.sol:1051-1082`). Fabricated quote-state inputs are view-only projections; this pass found no route from them into state-changing execution authorization.

## Finding C04-E01 - Supplied pass narrative lacks complete source/run provenance

| Field | Assessment |
| --- | --- |
| Class / origin | `EVIDENCE_GAP` / supplemental Stage-2 evidence qualification of Stage-1 REQ-05 and REQ-08; **not** `STAGE1_OPEN` or `STAGE1_REGRESSION` |
| Severity / confidence | Informational / high for the limited inspected evidence record |
| Snapshot / affected scope | Named HEAD plus dirty tree; Pons outside-trade runtime closure and Pons-specific interpretation of supplied release evidence |
| Intended requirement | Stage-2 PRD `:113-125,230-247,336`: source/test/dependency binding, reported command/toolchain/selection/result, evidence state independent of outcome |
| Observed gap | Stage-1 note `:4` names HEAD plus unspecified edits and says it is not a release identity; `:28-34` gives a command pattern and reports the four tests passed, rather than complete per-run invocations, immutable dirty-file identity, raw results or compiler/dependency versions. Manifest `:34-44,99` explicitly does not supply content hashes or a stability attestation. |
| Evidence / outcome | `INCOMPLETE_PROVENANCE` / supplied `PASS`; not `SUPPLIED_SOURCE_BOUND`. No matching-source failed run is asserted. |
| Impact | Limits reproducible source-bound execution claims; no fund loss or faulty runtime demonstrated. |
| Counterevidence | Owner expressly accepted the Stage-1 note (`Manifest:9-15`). The note identifies the current Pons root and exact regression name (`:9-16`) and gives a current selector/size summary (`:41-55`). These are useful documentary evidence, not absent evidence. |
| Readiness effect | `BLOCKS` the corresponding fully source-bound runtime-closure claim; does not revoke owner Stage-1 satisfaction or imply permission to rerun. Broader readiness remains with the coordinator/owner. |
| Corrective objective | Associate existing supplied records with the exact source/test/dependency snapshot and complete reported selection/results/toolchain. If unavailable, retain the qualification and seek separately authorized verification rather than manufacture provenance. |
| Attribution / response | C04 independent original; cross-review not begun; coordinator disposition pending. |

The conclusion is bounded to the Stage-1 note and manifest actually read. This is not an absence assertion about every historical log or the unread selector JSON. `T/PonsFeeSemantics.t.sol` and `T/CoreSettlement.t.sol` are not named as fresh runs in that note; their source assertions cannot be promoted to runtime PASS. Historical family closure documents were not used to fill that gap.

## Catalog applicability and seams

- **I1-I3, FH1, E6, K / local ownership:** applicable. Reviewed local-credit and refund consumers plus the attribution controls cited above. Source-agnostic unbooked donation claims remain accepted product behavior (`Family PRD:400-423`), not a new sender-attribution defect. No global helper-consumer closure is claimed; C06 owns the shared seam.
- **B/L3/N2 / repricing and preview parity:** applicable. Real outside-pool path and the Pons core fee/reference tests were inspected. Full consumers and transition lifecycle remain unread; C09-C10 matrix closure cannot be inferred.
- **C/N1 / callbacks and mid-operation effects:** applicable. Inspected the authorization/budget code and entrypoint locks. Hostile-token test coverage was not fully inspected: `T/GuardClosure.t.sol` was read, but its shared `TestBase_FullSpreadG5GuardClosure.sol` was not.
- **J / facet-package-proxy exposure:** applicable. DFPkg cuts and the Pons selector-control test were read (`P/DFPkg.sol:176-280`; `T/AdmissionAndIdentity.t.sol:64-105,148-173`). Declared cuts and a test source are not a supplied callable-proxy or size run; C13 owns release corroboration.
- **A0, decimal/FH2, residual/last-holder, disabled exits, NFT import, SY, permit/O and allowance/M surfaces:** not declared inapplicable. The DFPkg includes permit and SY interfaces and sets Permit2 approvals (`P/DFPkg.sol:176-197,387-394`), so blanket N/A would be unsound. Their complete application/testing is outside this completed read set and remains `UNINSPECTED` here.
- V3, wings, hookless package behavior, broader DETF economics and Crane bodies are out of C04 scope. Generic pure protection code was read solely as a Pons dependency. No conclusion depends on another reviewer's original.

## Read inventory and explicit limits

### Fully read assigned and additional files

- `P/DFPkg.sol`, `P/Common.sol` (all 1,154 lines, including the continuation), `P/FeeService.sol`, `P/QuoteService.sol`, `P/InQueryTarget.sol`, `P/OutExecuteTarget.sol`.
- `P/InTarget.sol`, `P/InBase.sol`, `P/InExecutionDelegate.sol`, `P/OutExecutionDelegate.sol`, `P/ExecutionContextRepo.sol`, `P/TransitionPlanner.sol`, `P/_Component_FactoryService.sol`.
- `B/.sol` (the unsuffixed base), `B/_Acceptance.sol`.
- `T/AttributionAndBooking.t.sol`, `T/PonsFeeSemantics.t.sol`, `T/CoreSettlement.t.sol`, `T/AdmissionAndIdentity.t.sol`, `T/ProductionConstructorBindings.t.sol`, `T/GuardClosure.t.sol`.
- `Protection`; `contracts/utils/LocalCreditLib.sol`.
- `CLAUDE.md`, Stage-2 PRD, Manifest, Stage-1 note, Family PRD, `.claude/skills/indexedex-testing/SKILL.md`.

### Partially read documents

- Readiness PRD `:85-324` (OD-01 through OD-08 and REQ-01 through REQ-08); other sections unread.
- `docs/agent/INDEXEDEX_AGENT_LAW.md:1-230`; remainder unread.
- `.claude/skills/indexedex-adversarial-testing/SKILL.md:1-210`; remainder unread.
- Family plan: targeted grep of PRD/binding/fee/protection references, not a full read.
- `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md`: targeted C04 lookup only.

### Unread required inputs and remaining family coverage

**None of the six production files or three test files expressly named in the assignment remains unread.** Broader PRD-required inputs and coverage remain incomplete:

1. `docs/agent/SKILL_CATALOG.md`; `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.plan.md`; the full original APEX PRD and plan at `docs/audits/apex-2026-09-17-remediation-and-regression-tests{,.plan}.md`; `docs/audits/APEX-IndexedEx-Audit-2026-09-17.pdf`; follow-up, evidence and open-item records named in Stage-2 PRD `:49-62`. Consequently this report does not independently reconcile original R criteria or historical audit allegations/retractions.
2. `docs/reviews/apex-2026-09-17-second-audit-readiness/selector-size-compare-stage1-current.json` and its underlying artifacts; broader historical family execution records. No selector/size certification is issued.
3. Shared imported `UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol`, `UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol`, `StandardExchangeConstantProduct.sol`, the Native SY target, multi-asset repository implementation, registry implementation and TWAP implementation. Their Pons call sites, but not complete dependency behavior, were reviewed.
4. Pons `OutBase`, `OutQueryTarget`, Multi targets, position-import target/repository, pool-key/manager repositories, remaining facet declarations and interfaces, and the Launch fixture/probe used by `ProductionConstructorBindings.t.sol`. No all-entrypoint closure is claimed.
5. Additional discovered family suites remain unread: `Adversarial.t.sol`, `AdversarialReentrancy.t.sol`, `BlockedFormulaReference.t.sol`, `BlockedYieldEquivalence.t.sol`, `ConsumingHook.t.sol`, `CrossModeStatefulCampaign.t.sol`, `EquivalentInterfaces.t.sol`, `ExactOutputQuantityQuote.t.sol`, `FormulaDomains.t.sol`, `ImportDeploymentClosure.t.sol`, `MaintenanceObservedProgress.t.sol`, `MaintenanceProgress.t.sol`, `NativePositionImportFunding.t.sol`, `NativeSettlement.t.sol`, `NestedAndConsumer.t.sol`, `OneBackedLeg.t.sol`, `PositionImport.t.sol`, `ProtectionAndInventoryMath.t.sol`, `QuoteExecutionParity.t.sol`, `RateProviderContextParity.t.sol`, `RegisteredLaunch.t.sol`, `RegistryMaintenanceObservation.t.sol`, `RouteFundingClosure.t.sol`, `RuntimeAndWork.t.sol`, `TransitionLifecycleClosure.t.sol`, `UnlockContextQuote.t.sol`, and `ZapAndPlacement.t.sol`. Discovery is not coverage.
6. Crane instructions/skills and contract bodies were not opened in this IndexedEx-only pass. Imported external implementations, constants and arithmetic are dependency assumptions, not independently audited findings. No request is made to expand owner scope to resolve that boundary.

An initial repository-root glob encountered broken Crane symlinks; it returned errors, not source content. Subsequent discovery was restricted to exact IndexedEx source/test/document directories. No reviewer directory was searched or read. No source drift was observed through these reads, but this is not proof of tree immutability.

## Handoff

Preserve this original. The coordinator can merge the bounded S2-ADD-005 conclusions and C04-E01 without calling this a full Pons inspection or an executed pass. Remaining source reads, shared seams and source-bound runtime evidence must remain visible; a later bounded cross-review requires separate assignment. No remediation PRD, code change, fresh run, live-instance remediation or audit-submission authorization follows from this report.
