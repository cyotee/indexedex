---
slug: dtf-migration-conformance-remediation-20261114
status: delivered
intent: clear
review_required: true
plan_path: .omo/plans/dtf-migration-conformance-remediation-20261114.md
plan_sha256: 31a0f3daff03b0e51830f5428168656eaeb19f81f40dee6f3e7f619be7230683
review_round_id: weighted-plan-r1-20261115-31a0f3da
review_round_limit: null
round_status: approved
pending-action: none; approved planner handoff delivered and hyperplan team disbanded; execution requires separate user instruction
implementation_tasks: 15
final_verification_tasks: 4
implementation_waves: 5
final_verification_waves: 1
structural_check: passed
review:
  plan_consultant:
    status: findings-addressed
    owner: lead
    session: st_01a1dc8e
    model: chatgpt-subscription/gpt-6-astra
    launch_note: default provider chain unavailable; native role launched with connected model override, no configuration change
    amendment_date: 2026-11-15
    result: three concrete gaps and four bounded clarity notes addressed in the plan; not native plan-reviewer approval
  plan_reviewer:
    status: approved
    owner: lead
    workspace_root: /Users/cyotee/Projects/indexedex
    runtime_home: null
    target: .omo/plans/dtf-migration-conformance-remediation-20261114.md
    round_id: weighted-plan-r1-20261115-31a0f3da
    plan_sha256: 31a0f3daff03b0e51830f5428168656eaeb19f81f40dee6f3e7f619be7230683
    launch_id: weighted-plan-r1-launch-20261115-31a0f3da
    session: st_01a1dc9d
    result: "[OKAY] No blocking contradictions; valid references, concrete QA, IS-1 through IS-7 mapped; source facts and runtime results remain execution gates"
    receipt_verified: true
    live_digest_verified: 31a0f3daff03b0e51830f5428168656eaeb19f81f40dee6f3e7f619be7230683
    completion_date: 2026-11-15
approach: reuse ordinary Uniswap V4 DETF machinery and add explicitly Weighted-specific compensation calculation from manually configured pricing inputs; remove setters at activation
approval_granted: true
owner_decision_pending: null
pricing_decision: manually configured static Weighted Hook calculation inputs, editable until the activation cut
---


# Draft: dtf-migration-conformance-remediation-20261114

Planning only. The owner approved the updated brief with "Yes, proceed with writing the plan." This authorizes one executable remediation plan and its required review, not implementation. The executable plan exists at `.omo/plans/dtf-migration-conformance-remediation-20261114.md`: 15 implementation tasks and 4 final verifiers in 5 implementation waves plus 1 final verification wave. The complete manual Weighted delta and prior conformance bundle were formalized. The 2026-11-15 correction pass addresses plan-consultant `st_01a1dc8e` findings; native plan-reviewer remains pending with the lead. No reviewer or advisory team was launched by the dedicated planner.

The previous off-chain-only credit-loading brief is superseded by the owner's later Weighted Hook/manual-input clarification. The prior full-conformance hyperplan remains authoritative for unrelated conformance and delivery obligations; its actual-live-composition/capture prerequisite is superseded. The formalization reads were limited to the approved inputs, repository rules and narrowly necessary source/ABI/operator/QA details. Only this draft and its plan were written. No implementation, requirements edit, test/build/install, RPC or Git mutation occurred.

## Affected user and ideal state

Owner decisions in the current discussion:
- Migration modifies the ordinary DETF under contracts/vaults/detf/protocols/dexes/uniswap/v4 and reuses its reserve machinery.
- The owner selected the Weighted Hook and requested that the coupled migration facet's name identify that compatibility.
- The owner wants to manually set all variables needed by the Weighted Hook compensation swap calculation, using either actual pool-state values or deliberately adjusted values. These are compensation-pricing inputs, not a claim of authenticated historical state.
- The pricing setters belong to the removable migration configuration facet. They remain editable during Stage1 and are removed with the other administration selectors at activation, after initialization and the successful owner-paid first ordinary bond. There is no separate earlier pricing lock.
- The owner explicitly approved the updated brief: "Yes, proceed with writing the plan." This approves plan creation and review only; no implementation, actual allocation or public transaction is approved.

Precedence: the owner's earlier selection of per-original calculated credit is preserved as per-original economic grouping, but its off-chain-only implementation interpretation is superseded. Do not reintroduce two linear ETH/DTF credit-rate setters, an actual-reserve-composition interview, or a universal nested-vault evaluator. Do not require manually supplied state to equal live reserve observations. No product requirements file has yet been amended.

Affected users are eligible original contributors, the current Migration owner/operator, and maintainers executing the remediation. Contributors need correct source-bound compensation and funded bonds; the owner needs explicit adjustable Stage1 pricing with irreversible removal; maintainers need complete, tested and delivered changes rather than an apparently passing subset.

| Ideal state | Property and reason |
| --- | --- |
| IS-1 | Every accepted legacy category retains configured original-wallet custody, source units and nonduplicating proportional credit. |
| IS-2 | An explicitly Weighted-specific component calculates compensation from stored manual inputs with canonical math, units, fees and rounding; live pool changes do not affect those inputs. |
| IS-3 | Current-owner setters work during Stage1 and are removed atomically with all configuration authority at activation; no extra lock, readiness flag, or restoration path. |
| IS-4 | Existing real registry/child behavior preserves paid owner-first activation, funded fresh90-day compensation cliffs, reward gates and ordinary-family behavior. |
| IS-5 | Routine repeated harvesting retains matured old principal and NFTs; typed recovery and any permanent-custody exception remain source-specific and evidence-based. |
| IS-6 | Operator preparation, pricing readback, configuration, resume and weighted NFT3's two-original flow agree with the revised ABI and accounting. |
| IS-7 | Every accepted requirement, missing named record, retained task-created program and actual verification result is reconciled and delivered without silent omissions. |

| Gap | Current difference | Closure |
| --- | --- | --- |
| GAP-1 | Current code automatically captures one immutable live quote book; the previous draft instead proposed externally loaded arbitrary numerical credits. Neither matches the latest manual-state direction. | Replace only the migration pricing boundary and explicitly amend conflicting requirements. |
| GAP-2 | Pricing-coupled migration naming does not expose Weighted specificity. | Choose narrowly scoped Weighted-specific names and update real factory/package/ABI references together. |
| GAP-3 | New Stage1 input updates require explicit separation from stored entitlement credits. | Owner selected keep-until-reloaded: setters affect new quotes/loads, not existing configured credits or issued bonds. |
| GAP-4 | Price setter removal and setter/payload/resume handling are not part of the current interface/census. | Integrate with current ownership/activation/operator machinery; no parallel lifecycle. |
| GAP-5 | Weighted NFT3 can omit its required two-original mode, and final operator rehearsal omits that special case. | Existing-boundary validation and existing-harness configure/resume/activate/two-bond coverage. |
| GAP-6 | Source manifests omit some exact runtime/facet/schema/unit/witness relationships; earlier NFT IDs0-2 remain a factual source-role question. | Recover existing raw evidence first and make only fact-required source-specific changes. |
| GAP-7 | Retained source, verification, recovery records and two verification programs were omitted from main; surrender-spec/package-evidence are absent. | Complete inventory and substantive delivery, with source qualifications. |
| GAP-8 | Descriptions of source support, selector counts and pending tests are stale. | Reconcile historical and current observations without changing working behavior to match old prose. |
| GAP-9 | Nondeployment loading/issuance/harvest gas and batch limits remain distinct from two passing deployment examples. | Measure applicable admitted operations and fix actual mismatches only. |
| GAP-10 | Named adversarial TestBase and full original-obligation execution mapping remain incomplete. | Real shared adversarial setup, regression-first checks, complete acceptance and delivery. |

## Components (topology ledger)

| Component | Outcome |
| --- | --- |
| C1 | Explicit requirements reconciliation and complete task-created work inventory. |
| C2 | Weighted manual pricing data, canonical calculation, queries and semantic naming. |
| C3 | Owner-only configuration, credit storage/update policy, real selector removal and package composition. |
| C4 | Operator schemas, price/configuration identity, readback, resume and weighted NFT3 integration. |
| C5 | Source conservation/recovery proofs and remaining adversarial/gas demonstrations. |
| C6 | Full regression/integration verification and complete linear-history delivery when execution/commits are authorized. |

This is one remediation plan, not a new product or a rewrite of the existing ordinary DETF. Dependencies are C1 -> C2/C3 -> C4, with existing evidence recovery and C5 proceeding independently where interfaces permit, followed by C6.

## Open assumptions (announced defaults)

- Intent remains clear; high-accuracy plan-reviewer review remains required after approval.
- Ask one owner question at a time, following the user's explicit iterative discussion. Questions seek genuine behavior choices, not discoverable code facts.
- Test strategy remains regression-first through real production proxies, manager, reserve, children and legacy forks, as required by the original plan. No tests/builds run during planning.
- Retain the original compensation mint-equivalent arithmetic unless the owner changes it: per-original grouping, liquid-mint-equivalent uplift and depositor split, not a new ordinary purchase-duration bonus. Compensation principal does not create an additional reserve-liquidity mint merely because an old asset is surrendered.
- Manual state affects compensation pricing only. Ordinary DETF minting, ordinary bond purchases and reserve management continue using ordinary reserve behavior.
- The exact tuple, validation, naming, hashes, loader signatures and operator format are resolved in the executable plan. The completed focused hyperplan, not an unreviewed flat-rate simplification from an earlier adviser, governs those details.
- Existing source-specific custody, actual funding and issued-bond facts remain authoritative. Adjusting pricing changes previews and subsequent explicit loads only. Existing configured credits and configuration identities remain unchanged until explicit replacement; already-issued bonds and issuance history remain unchanged.

Extrinsic constraints are unchanged: Solidity/Foundry Solar/Crane and current TypeScript tooling; no new paid provider, public transaction, financial dataset or refused historical trace retry. Measured batch capacity is an execution obligation; do not invent a universal gas limit or mutable gas registry. Scope remains original acquiring wallets and accepted legacy categories.

## Findings (cited - path:lines)

Current direct reads:
- contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol:44-52 captures a live book once;55-96 computes and stores credit during configuration. Current implementation has no mutable manual pricing book.
- contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshotLib.sol:135-184 computes full original ETH/DTF separately, applies uplift, fee, rated inflow, canonical exact-input budget/output and user split. Its live acquisition and buffered-deposit dependency model must not silently persist as a prerequisite to manual state.
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol:47-108 defines decimal/rate scaling and fee rounding;197-216 exposes the canonical weighted exact-input calculation and its domain checks.
- contracts/vaults/detf/common/core/DETFMintSplitLib.sol:19-26 supplies the liquid-mint depositor/reward split. Ordinary bond purchase arithmetic differs and was explained separately in the user discussion; no owner change to the compensation bonus formula has been made.
- Original requirements still prohibit a contribution-price setter and mandate automatically captured frozen-state calculation. These clauses must be explicitly reconciled to the latest manual-state decision during later authorized execution, while retaining IDs and unrelated requirements.

Retained evidence and conformance findings remain in .omo/drafts/hyperplan-dtf-conformance-insights-20261114.md and the original REMEDIATION_PRD.md, subject to this newer pricing decision. Do not reinterpret missing summaries as absent adapters or stale literals as failed transactions. The earlier successful local receipts and tests remain reusable only where the resulting code/behavior matches.

## Decisions (with rationale)

- Weighted-specific compensation calculation from owner-supplied static variables replaces the draft's external-credit-loading approach and the code's compulsory live-capture approach.
- Manual values may intentionally differ from actual reserve state. Validate mathematical/domain/unit correctness, not equality to live pool balances or providers.
- Pricing setters use existing current-owner Stage1 authority and become unreachable in the same atomic activation cut. No earlier freeze, extra switch, external pricing oracle or new lifecycle gate.
- Owner reply "Repricing: Keep until reloaded (Recommended)" resolves Q1. A pricing update does not reprice, invalidate or require reload of existing configurations. Explicit replacement computes under the new pricing inputs while preserving independent issuance facts and stable original identity. No all-records-current activation condition is authorized.
- Retain all unrelated original accepted requirements: original-wallet configuration, actual Stage2 surrender, zero-credit rejection, proportional remaining-Q/remaining-C accounting, separate economic originals, exact funding, fresh90-day compensation cliffs, paid owner-first bond, complete reward closure, irreversible activation, and typed bounded recovery.
- Preserve weighted NFT3's two separately quoted and funded contributions; preserve TokenStaking's one conserved original and distinct original/eligible weights and measured SY. Do not introduce raw-weight ERC20 pulls.
- Preserve routine reward-only harvesting and source-specific conditional authority/permanent custody. No public governance change is authorized.
- Preserve every in-scope task-created file, including retained verifier/recorder programs and records; proposed exclusions must be explicit before delivery. Complete substantive missing original-plan outputs and real adversarial fixtures rather than empty aliases or copied inventories.
- Do not restore zero direct-pair returns, silently change earlier-ID eligibility, invent approved awards, introduce arbitrary execution, or weaken failing tests.

## Scope IN

Full original migration plan as explicitly amended for manual Weighted pricing, all relevant interfaces/factories/operator stages/tests/docs, required source/recovery closure, complete named records and retained-work integration, applicable gas measurements and final verification. New plan tasks will specify exact paths, math/unit contracts, dependencies, success criteria, regression cases, commands and commit dispositions.

## Scope OUT (Must NOT have)

No implementation or original-requirements edits in this planning session. No automatic live pool binding, universal nested evaluator, two linear credit rates, setter CAS, separate pricing lock, new activation readiness flags, automatic repricing, changes to existing funded bonds, ordinary-family pricing redesign, public execution, new paid services, or silent omission of task-created work. The approval gate was satisfied; native review is pending with the lead and execution remains separately authorized.

## Open questions

No owner product question remains. Q1 is resolved by "Repricing: Keep until reloaded (Recommended)": Alice retains her configured100 credit after pricing changes; an explicit reload may compute120. Already-issued bonds and issuance history are not altered. The settled setter-removal/freeze point is activation.

Both narrow advisory lanes returned: st_01a1dc05 (architecture) and st_01a1dc06 (detail). Their recommendations are not owner decisions. The lead directly verified two load-bearing findings: MigrationLegacyNftLib.originalId currently includes the pricing snapshot ID, and Claim.exactInputBudget/rawOutput provide the canonical weighted domain and native-reserve checks. Q1 is resolved as above.

Settled engineering contract from the completed delta:
- Reshape the existing pricing interface/library in place. `Inputs` contains swap fee, seigniorage, three role indices and ordered `Leg[]`; each leg retains raw/SE inventory, weight, decimal scales, stored rate and the existing `Frozen.Inputs` V3 operands. The closed modes are Raw, RawRate, DisabledBuffer and EnabledV3Buffer. Derived rated balances are never editable. The complete field order and validations are in the plan.
- One `setMigrationWeightedPricing(Inputs)` setter belongs to the existing removable allocation surface. It handles empty initial storage and complete overwrites, has no CAS argument/counter, stays callable after the paid owner-first bond, and disappears at activation. No pricing-ready or all-records-current gate is added.
- Preserve exact native18/full-original mapping, fee/uplift/user split, raw-provider floor-before-scale, disabled-buffer net inflow, enabled-V3 amount dependence, checked arithmetic and canonical output/max-in failures. The existing pure V3 evaluator has zero refund; retain its handling without an editable refund field.
- Book format 2 hashes `abi.encode("IndexedEx.manual-weighted-original-credit", Book-with-zero-id)` including chain/proxy and bound WETH/original DTF. Configuration reuses its existing domain/book/input preimage. All twelve quote-sensitive loaders append scalar `bytes32 expectedBookId_` and compare it before quotation or mutation.
- Stable NFT economic identity is `keccak256(abi.encode("migration.nft",chainId,proxy,collection,tokenId))` in Solidity, TS and active exposure consumers. Preserve consumed guards and historical records.
- Rename the retained facet/target to `UniswapV4DetfMigrationWeightedHookFacet/Target` and the pricing interface/library to `IUniswapV4DetfMigrationWeightedPricing` / `UniswapV4DetfMigrationWeightedPricingLib`. Update artifact strings, name-derived salts, package references, ABI/cuts/interface support and operator removability together. Keep package, other facets, children and adapters named as they are.
- One retained `migrationWeightedPricing()` getter replaces both capture-era getters; `previewOriginalCredit` remains. No old/new aliases or misleading live-capture assertion remains in active execution.
- Operator v2 rows carry their own book and explicit load/retain directive. Accepted configurations and issued history retain their own original execution/prepared manifests and journal-domain FileRefs, so each historical intent's domain hash is independently recomputable. Canonical transaction-specific events and necessary local evidence prove A even when B replaces the same key later in that block; block-end state is used only for surviving facts. `issuedHistory` separately binds a recipient's A issuance when its current configuration is B. Rehydration does not regenerate old records at current prices. Already-mined A receipts reconcile before new nonces; unsent stale A loads fail. Preserve the existing donation-specific operation IDs, book/input hashes, source claims/signatures and complete configured-SY census.
- Source facts, recovery, all original acceptance obligations, NFT 3 two-original flow, gas and complete delivery remain in scope. The real retained helper is `migration/resumed-integration/verify-bounded-deployments.ts`, alongside `record-verification.ts`. The plan corrects that locator and requires all retained work, substantive missing records and the named adversarial base.
- Narrow source inspection found `rehearse.ts:113-125` consumes weighted NFT 3 for setup funding. The plan explicitly preserves its principal for the positive two-bond witness and requires a separate authenticated local funding acquisition; it does not invent financial allocations.
- The strongest required counter-case is one recipient with current configuration B and immutable issuance A while other accepted records remain under A at activation. It is explicitly specified in the data format, verifier and real rehearsal.

## Approval gate

status: plan-written-review-pending
approval_granted: true

The approved updated approach: preserve ordinary DETF machinery and the existing supported Weighted calculation; make its pricing-coupled facet names explicit; accept complete manually configured pricing inputs without compulsory live-state capture; keep setters editable throughout Stage1 and remove them at activation; keep existing credits until explicit reload; preserve stable economic-original identity separately from pricing provenance; adapt operator preparation/resume and complete every remaining conformance and delivery obligation. The exact input schema will preserve supported buffer-deposit/refund math rather than silently replacing it with a flat rate, and will not add a universal nested-model engine.

Approval covers writing and reviewing one executable remediation plan only, including explicit later requirements amendments and regression-first production-proxy checks. No product code, original requirements, tests/builds or public state is changed in this planning session. This is approval of the manual Weighted brief, not the superseded external-credit-loading brief.

The dedicated planner ran the required scaffold script successfully in the original writing pass; it preserved this draft and created the plan. The complete plan and its 2026-11-15 corrections are written. The lead's plan-consultant findings are recorded below as addressed. The next action belongs to the lead: bind the amended plan for native plan-reviewer, record the exact review receipt, and return any corrections for a minimal plan-only amendment. No native approval is claimed, no duplicate review was launched, and no execution started. After native review and separate execution authorization, use `/ulw-execute dtf-migration-conformance-remediation-20261114`.

## Plan-consultant correction ledger

Source: the lead's 2026-11-15 correction request for native plan-consultant `st_01a1dc8e`. The planner narrowly read `execution-domain.ts:36-60`, `journal.ts:24-82`, `execution-plan.ts:18-48` and `execution-state.ts:25-47` and amended only this draft and its plan. No broad research or approval request was repeated.

| Finding or clarity note | Plan correction | Disposition |
| --- | --- | --- |
| Historical configure/issuance `domainHash` lacked its original execution context | Added original execution-manifest/journal-domain FileRefs and an independent issuance prepared-manifest reference; reconstruct the exact original manifest/preparedHash/payloadHash domain with all bindings. Tasks 7/12 reject altered domainHash even after surrounding file hashes are recomputed, before signing/nonce allocation. | Addressed |
| Receipt-block state can contain later same-block B rather than A | Transaction calldata, canonical transaction/log ordering and necessary transaction-local evidence prove historical A; block-end equality applies only to surviving facts. Tasks 7/10 recover missing A completion once after same-block B without resend or B mutation; tampered order/events fail. | Addressed |
| Default operation-ID formula would erase donation identities | Preserved both exact existing donation approval/donation fingerprints. Tasks 7/10 cover distinct donation IDs with identical calldata and same-ID no-resend recovery. | Addressed |
| Unset pricing could accidentally require preparation for owner-bond/activation | Explicit authenticated empty-census branch accepts null pricing and null preparedManifest; task 10 exercises real paid owner purchase/resume/activation without setter or quote preparation. | Addressed |
| Tasks 10/12 and 11/12 shared files | Task 10 is sole Wave 4 writer of rehearsal-proof.ts; task 11 owns execution.test.ts after task 7. Task 12 depends on both and consumes serialized integration. Counts/waves are unchanged. | Addressed |
| Final verifier reports did not yet exist at task 15's delivery audit | Final-wave coordinator emits an additive delivery inventory after F1-F4 reports exist, preserving the baseline and hashing all four reports. | Addressed |
| Extra implementation-completion acknowledgement gate | Removed the final-wave acknowledgement sentence and clarified task 15 completion; separate execution, commit and public-action authorization remains. | Addressed |

These are plan corrections, not implementation or native plan-reviewer approval. No owner product question was introduced; all manual Weighted, source/recovery, NFT 3, gas, acceptance and complete-delivery obligations remain.

## Structural verification receipt

The original in-memory structural check passed on 2026-11-14 for SHA-256 `3b7c06e6faf7e9b9ca73b5f3f8a66784ecbc4282191c59ca59ddee84bbcebeeb`. A fresh check passed on the amended 2026-11-15 plan. It verified all eight scaffold headings in order, column-zero task grammar/placement and contiguous numbering, required per-task fields, matching acyclic dependency rows including task 12's new integration dependencies, all 53 MIG-AC rows, unchanged task/wave/category counts, presence of all requested corrections, removal of the extra acknowledgement gate and consistent consultant/reviewer status. No product tests or implementation were run.

- Implementation tasks: 15.
- Final-verification tasks: 4.
- Waves: 5 implementation plus 1 final verification, 6 total.
- Implementation category mix: 9 deep-low, 2 deep-high, 3 writing, 1 quick.
- Amended plan SHA-256: `31a0f3daff03b0e51830f5428168656eaeb19f81f40dee6f3e7f619be7230683`.
- Owner product questions or unresolved formalization blockers: none.
- Native plan-consultant `st_01a1dc8e`: findings addressed as recorded above. Native plan-reviewer: pending with the lead; no approval receipt.
- Product tests, builds, installs, RPC and implementation: not run or started.

This receipt validates plan structure and scope formalization, not implementation correctness or native review approval. The lead must bind any later review receipt to the plan bytes it actually reviews.
