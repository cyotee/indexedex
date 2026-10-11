# PRD: APEX Stage 2 — coordinated parallel code review

- **Date:** 2026-10-07
- **Status:** Stage 1 complete and accepted; Stage-2 execution authorized by the owner on 2026-10-07 and in progress. See the recorded owner authorization in the companion plan; do not ask again for Stage-1 acceptance or Stage-2 launch approval. Read-only shell source inspection is authorized for this execution.
- **Type:** Review-program PRD, not a remediation PRD or code implementation plan.
- **Target:** An explicitly identified post-Stage-1 IndexedEx/Crane source snapshot, including applicable broader changes and new vaults.
- **Deliverable:** One consolidated review report with attributed reviewer originals, coverage ledgers, evidence limitations, and unresolved disagreements.
- **Execution policy:** Inspection of source, tests, documentation and supplied evidence only. No fresh builds, tests, simulations, forks, RPC calls, or test authoring.
- **Human checkpoint:** Owner reviews the report with an agent; a remediation PRD may then be separately requested if errors or other approved corrective work are identified.
- **Authorization boundary:** Writing this PRD does not launch the review, implement fixes, change agent configuration, authorize verification execution, or approve audit submission.

## 1. Purpose and required outcome

Stage 1 repairs the specific issues in the second-audit-readiness remediation PRD. Stage 2 reopens the broader original APEX acceptance program against the current code and applies the same relevant security standard to changed and new vaults.

The owner confirmed that Stage 2 is a coordinating agent spawning several review sub-agents **in parallel**, collecting their results into a report, and stopping so the owner can discuss the results with an agent before commissioning a remediation PRD. The owner subsequently accepted the recommended inspection-only approach and requested this document.

The required outcome is a defensible, source-bound account of:

1. How every original acceptance criterion applies to the current tree under current owner decisions.
2. What the reviewers actually inspected, including tests and cross-family dependencies.
3. Which current implementation or test behaviors contradict an applicable requirement.
4. Which requirements appear consistent on inspection but still depend on runtime evidence.
5. Which supplied execution claims apply to the reviewed source, and which are historical, stale, missing, or inconsistent.
6. Which accepted residuals, superseded requirements and undecided matters remain distinct from defects.
7. What the owner needs to decide next.

The review must not quietly become an implementation campaign, an automatic remediation-PRD generator, a fresh execution campaign, or a generic monorepo-wide audit.

### 1.1 Four separate conclusions

| Conclusion | Meaning | What does not follow |
| --- | --- | --- |
| Report delivered | A report artifact exists, possibly partial or blocked | The requested review is complete |
| Inspection complete | Required coverage was inspected and dispositioned under this PRD | Every runtime acceptance criterion passed |
| Evidence sufficient for a stated claim | Applicable evidence supports that particular claim on the identified source | Universal security, or permission to submit |
| Owner-authorized next step | The owner separately requests discussion, verification, remediation planning, or another action | Automatic code changes, deployment, or live-instance remediation |

An inspection-complete report may conclude that readiness remains blocked. Zero discovered defects is not proof of safety. Reviewer agreement and historical passing counts are not independent proof.

## 2. Authority, inputs and precedence

### 2.1 Required input documents

All paths below are repository-relative. References describe source locations, not permission to execute commands appearing in those documents.

| Input | Path | Use |
| --- | --- | --- |
| Repository router | `CLAUDE.md` | Current repository rules, product-law and canonical-skill routing |
| Full agent law | `docs/agent/INDEXEDEX_AGENT_LAW.md` | Applicable product rules, deployment and token policy |
| Canonical skill router | `docs/agent/SKILL_CATALOG.md` | Resolve canonical skill paths when additional family knowledge is needed |
| Current readiness remediation PRD | `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` | OD-01–OD-08, REQ-01–REQ-08, residuals, unverified scope and non-goals |
| Stage-1 plan | `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.plan.md` | Stage-1 deliverables, entry gate, separate Stage-2 request |
| Original APEX PRD | `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` | Original intended behavior and owner amendments |
| Original APEX plan | `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` | D1–D69, R1–R14 and stable original 108 acceptance IDs; inventories and detailed controls |
| Audit report | `docs/audits/APEX-IndexedEx-Audit-2026-09-17.pdf` | Seven audit entries and both retractions; auditor claims, not independent execution evidence |
| Follow-up record | `docs/audits/apex-2026-09-17-followup-fixes.md` | Historical completion claims to reconcile, not inherit |
| Evidence records | `docs/audits/apex-2026-09-17-evidence.md` and `docs/audits/apex-2026-09-17-evidence/` | Supplied evidence and provenance; historical material remains labeled historical |
| Open-item ledger | `docs/audits/apex-2026-09-17-review-open-items.md` and its linked open-item PRDs | Recorded scoped decisions, including matrix, interface, legacy-facet and staticcall matters |
| Wings product PRD and plan | `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` and `.plan.md` companion | Product-specific requirements and latest owner addenda; not generic FullSpread accounting |
| Stage-1 evidence note | Exact path supplied at launch | Source map, outside-trade test references, build/selector/size/named-regression records and owner acceptance |
| Family documents | Current co-located PRDs and plans discovered via the router | Scoped family semantics, deployment/TestBase paths and approved exceptions |

Read the canonical IndexedEx testing and adversarial-testing skills under `.claude/skills/`, and Crane testing, adversarial-testing, deployment and architecture skills under `lib/crane/.claude/skills/`, as relevant to each assignment. Read skills directly; do not execute a skill workflow or treat example commands as authorized actions.

For DETF lanes, consult the router's current alignment and funded-staking/SY documents before interpreting historical family requirements. Do not expand the APEX accounting review into unrelated bond economics, thresholds or vesting redesign.

### 2.2 Precedence and conflict handling

1. Actual runtime permissions and higher-priority instructions always bound the reviewing agents. This PRD cannot override them.
2. The owner's confirmed Stage-2 workflow and inspection-only choice govern this review process.
3. Current applicable owner rulings govern product behavior. In the readiness PRD, OD-08 expressly controls conflicting older text in its listed ODs and REQs.
4. The original APEX program supplies the baseline; current scoped amendments must be attached to each affected criterion rather than deleting the baseline history.
5. Current family-specific owner rulings apply within their named product scope. A FullSpread or DETF rule must not be transplanted into wings in conflict with its own approved accounting.
6. Historical reports, test names, reviewer opinions, and completion headers are evidence to examine, not authority to change requirements.

Record unresolved authority conflicts as `DECISION_NEEDED`, identify the competing citations, and explain the effect on coverage/readiness. Do not invent an owner ruling. Do not automatically classify a genuine unresolved decision as nonblocking.

### 2.3 Finite threat-model bar

The bar is the locked APEX program as amended, the seven report entries and both retractions, and applicable catalog classes A–K, A0, L, M, N and O named by the canonical testing skills. Map relevant product-specific extensions where the skills require them. “All possible attacks” is not an acceptance criterion.

The catalog is an applicability checklist, not permission to ignore a directly observed violation of an in-scope requirement because no catalog label fits. Conversely, a nonexistent surface does not need an invented test: cite why a class is inapplicable.

## 3. Entry gates and execution compatibility

### S2-REQ-01 — Owner gate and Stage-1 inputs

Before launching review assignments, the coordinator must have:

- Recorded owner satisfaction with Stage-1 results.
- A separate request to execute Stage 2 against a named snapshot.
- The Stage-1 evidence note and its source identity.
- References to the four required outside-trade tests: V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread and wings.
- The Stage-1 current-source map, build, selector, size and named APEX regression evidence.

These are inputs to inspect, not runs to repeat in Stage 2. A missing required Stage-1 input or known incomplete repair is a launch blocker returned to the owner. This PRD does not itself attest that Stage 1 is complete.

An owner message may record both satisfaction and launch authorization; two separate messages or a newly numbered OD are not required. The two decisions must be unambiguous.

### S2-REQ-02 — Genuinely concurrent reviewing capability

The future coordinator must be both permitted and capable of running multiple independent review assignments concurrently. Record the available delegation mechanism and its limits before promising parallel execution.

- Real parallelism means overlapping substantive review work by multiple sub-agents, not a list of sequential calls described as parallel.
- Several lanes may run in bounded waves. This PRD does not prescribe agent models, a fixed reviewer count, or one model per family.
- Record reviewer identity, session/task identity where available, assigned coverage, start/end or equivalent scheduler events, completion state and output path. Use actual metadata; do not fabricate timing.
- Preserve independent first-pass findings before sharing peer conclusions. Shared primary source inputs are allowed.
- If the authorized runtime cannot supply concurrency, stop with an execution-compatibility blocker. Do not silently replace the workflow, change configuration, install tools or switch models to manufacture capability.

The existing research council used to author this PRD is synchronous and fixed-roster. `docs/agent/REVIEW_COUNCIL.md:57–62` describes same-target originals and permits synchronous sequential calls; `:98–106` restricts delegation and denies background tools. Neither profile is automatically a suitable executor for this program. A future coordinator must satisfy its own actual permissions; this document grants none.

### S2-REQ-03 — One source identity

Before first-pass review, create a snapshot manifest identifying:

- IndexedEx revision and Crane revision, including the full dependency identity when available.
- Tracked modifications and relevant untracked source/test files, with supplied content identity or immutable snapshot references. HEAD alone is insufficient for a dirty tree.
- Selected family PRD versions and applicable owner rulings.
- Test/build artifact provenance and relevant compiler/runtime/dependency versions **as reported by supplied evidence**, with verification status.
- Which evidence belongs to historical audited source, Stage-1 source, and the Stage-2 review snapshot.

Use permitted reads and operator-supplied manifests. Do not run shell or inspect secret files to obtain identity. If required identity cannot be established, request it and mark the gate blocked; do not invent hashes or versions.

The source snapshot must remain stable during the review. If an in-scope file or dependency changes, identify affected criteria, invalidate stale conclusions, and request an explicit rebaseline or finish against an available immutable original snapshot. No silent merging of findings from different trees.

## 4. Scope inventory and coverage ownership

### S2-REQ-04 — Preserve the original acceptance denominator

Create `CRITERIA_LEDGER.md` from the original plan's stable nested acceptance IDs across **R1–R14**, not just R3–R14.

- Preserve all 108 original IDs, including rows later superseded or made inapplicable.
- Cite the original criterion text and detailed linked controls; a short label does not replace its substance.
- Attach current amendments and applicability reasoning to each row.
- If discovery yields a count other than the documented 108, record the discrepancy with source references. Do not fabricate rows or drop criteria to force a number.
- Map one primary coverage owner and any cooperating lanes to every row.
- Add current Stage-1 and new-product obligations as separately identified supplemental rows, for example `S2-ADD-001`, linked to their existing authority. Do not renumber the original ledger or treat supplements as permission for new features.

Completion requires accounting for the entire baseline and applicable supplements. An `UNINSPECTED` placeholder is a visible coverage gap, not completion by disposition.

### S2-REQ-05 — Audit-item reconciliation

Create a separate ledger for all seven report entries and both retractions:

| Audit item | Required review coverage |
| --- | --- |
| APEX-2026-001-M | Current replacement custody/credit properties and outside-trade coverage; distinguish old stored-total accounting from new implementations |
| APEX-2026-001-M2 | Documentary instance/implementation inventory and source-version mapping; no fresh chain inventory or live-remediation claim |
| APEX-2026-003 | Custody SE/SY share ownership, refunds/pretransfer and tests that reach the intended guard |
| APEX-2026-008 | Orbital operation-scoped refund/credit and the reported reachable sites; direct-call versus callback settlement |
| APEX-2026-009 | ERC-4626/Morpho share-burn/refund accounting and affected route coverage |
| APEX-2026-004B | Idle-underlying and exact-input refund behavior, replacement residual booking |
| APEX-2026-005 | Canonical local-credit arithmetic **and its consuming families**; helper correctness alone does not close consumers |
| `beforeSwap` retraction | Retained caller/context controls; do not invent a missing-guard fix from a withdrawn claim |
| Weighted dust retraction | Buffer-first/residual behavior and meaningful rounding controls; do not reinstate a retracted vulnerability by assumption |

A historically valid allegation may have no current equivalent after replacement. Keep historical-claim status and current-remediation assessment separate.

### S2-REQ-06 — Required coverage groups

The following are required coverage groups, not a fixed number of agents. The coordinator may split or combine assignments while preserving separate product conclusions and complete ledger ownership. Discover exact current paths at launch; historical filenames and proposed shorthand are navigation aids, not a verified current inventory.

| Group | Required surfaces and boundaries |
| --- | --- |
| Provenance and original program | R1/R2 evidence quality, all D/R mappings, historical versus current source identity, audit inventory and accepted residuals |
| V3 FullSpread | Own accounting/quote/execution paths, local and deployed inventory, outside-trade credit test and applicable original controls |
| V4 hookless FullSpread | Current split implementation and package, inventory/protection/transition/quote/execution dependencies, outside-trade credit, selectors and supplied size evidence |
| V4 Pons-family FullSpread | Separate package, hook binding, fee/protection/registration behavior, shared and distinct dependencies, outside-trade credit; do not infer closure from hookless |
| Wings | Current `upperLowerWings` product against its own PRD and applicable amended APEX properties; see §4.1 |
| Shared credit and custody | `LocalCreditLib`, concrete consumers, RebasingAware custody SE/SY, supported pretransfer entries and exact negative assertions |
| Receipt and lending | Shared receipt-backed adapter, generic ERC-4626 SE, Aave Stata, Morpho, Aave Cross-Version Loop, dispatch/caps, cross-interface books, capacity and payout rules |
| AMM and staking SE | Uniswap V2, Camelot V2, Aerodrome; Lido, Rocket Pool, EtherFi; relevant routes, sleeves, capacity/prechecks, residuals, wrapping and propagation. Slipstream is inventoried as deprecated, not reopened for feature work |
| Seven SE buffer-hook families | Orbital, weighted, curve quad, Balancer quad, single-CP, dual-CP and non-CP single. Include preview/execute, direct/callback settlement, buffer/residual rules and actual test assertions |
| Hook × SE matrix | Current hook/family/configuration/route inventory, row test coverage, declared compatibility and separate execution-evidence reconciliation |
| Balancer integrations | In-scope SE and native-BPT boundaries, buffer-pool packages, standard/wrapped rate providers, D41/D48/D49 exceptions and D68/D69 transition quotes; current OD-02/REQ-07 also applies |
| DETF accounting consumers | Named D16 exchange and prepaid entries, Uni V4 DETF residual helpers, single/multi-vault/mixed/composed/rebasing families, relevant mint/donate/bond prepaid and staked/rebasing token surfaces; do not redesign unrelated economics |
| Cross-cutting release/test surfaces | Production deployment paths, facet/Target/package/proxy exposure, registry integration, interfaces/NatSpec, assertion quality, fuzz/campaign adequacy, supplied selector/build/size evidence and shared-dependency seams |

Mandatory shared-dependency reads may overlap. Assign disjoint **write targets and primary responsibilities**, not artificially disjoint read sets. The coordinator must assign explicit seam review where accounting, quoting, callbacks, rate providers, deployment or cross-interface books span lanes.

#### 4.1 Wings-specific review obligations

Read the current wings PRD, including controlling O1–O7 and A3 rulings, before applying generic residual or donation expectations. Review the applicable existing requirements for:

- Immutable hookless pool/target binding and target-only entry/exit routes.
- Whole-vault realizable liquidation valuation, market-limited conversion, and separation of calculation failure from genuinely unsellable inventory.
- Accurate custody despite valuation exclusion; approved zero-supply residual and first-depositor ownership behavior, without inventing a recovery ledger or permanent sink.
- Inbound-credit isolation before mandatory interleaved harvest; matching preview/transition sequencing.
- Already-unlocked manager sleeve-only behavior, no nested unlock and covered target payouts.
- Oracle-selected sleeve, positive-value local reserve floor while shares remain, and final-redemption release.
- Vault-funded execution costs, fee integration, funding of entitlements, and existing loss/progress bounds.
- Required integer exact-output behavior, consumer integration, deployment surfaces and existing gas/test evidence.
- Its own outside-trade credit test, separate from every FullSpread variant.

This is inspection of the existing product requirements, not authorization to add routes, bind wings to a Pons-configured pool, or port FullSpread accounting into wings. See the wings PRD:13–36,54–75,87–98.

### S2-REQ-07 — Stage-1 repair continuity

Inspect all eight Stage-1 requirements on the selected snapshot and reference their supplied evidence:

1. **REQ-01:** only successful SE zero preview authorizes the specified book-and-wait path; hook zero/join failure semantics follow OD-08.
2. **REQ-02:** direct residual preview and distinct successful-zero/revert caller behavior; no invented holder-reserve update or public sweep.
3. **REQ-03:** custody ownership, reentrancy and minimality tests reach the intended condition with exact errors/state assertions; scanner scope matches the required inventory.
4. **REQ-04:** seven matrix behavior families have meaningful rounding, partial-consumption, share-movement and pre-existing-inventory assertions rather than catch-all success.
5. **REQ-05:** four independent outside-trade credit tests; custody synchronization is not mislabeled stale-reserve proof.
6. **REQ-06:** share-first redemption cap, `maxWithdraw` relationship and payable non-integral/receipt-limited behavior under OD-03, without a wholesale adapter redesign.
7. **REQ-07:** plain empty-state rate uses live preview without gas-gated self-snapshot; caller-supplied projected state and D48 length behavior remain distinct.
8. **REQ-08:** current split package/source/test map and source-bound supplied build/selector/size/named-regression evidence.

If a Stage-1 issue remains or has regressed, mark its origin `STAGE1_OPEN` or `STAGE1_REGRESSION`, retain its original ID, and notify the owner. Do not silently rename it a new Stage-2 discovery or repair it. If it contradicts the accepted entry baseline, pause affected work for an owner decision and preserve a partial report.

## 5. Inspection and evidence requirements

### S2-REQ-08 — Production-route assertion review

For each cited security test, inspect setup, actual call path, branch preconditions and assertions—not just its name or a passing total. Check, where applicable:

- Real facets/packages/proxies through the production CREATE3/FactoryService and manager/registry paths; real hook package/factory binding.
- No mocked SUT, bypassed security path or fixture-induced unrelated revert masquerading as the intended protection.
- Exact expected errors and affected state; expected successful outcomes as well as rejection controls.
- Conservation and operation-scoped credit/refund/burn/book changes, not ranges that admit the forbidden outcome.
- Preconditions that actually establish the rounding, under-consumption, prior-reserve, external-trade or reentrancy state being asserted.
- Correct fixture boundaries versus production behavior; approved external dependency stubs are not automatically mocked SUTs.
- Target methods exposed through facet declarations, package cuts and proxy interfaces, with supplied callable evidence separately identified.
- Fuzz/invariant targets, success counters and non-vacuous assertions; release-count claims remain evidence claims until tied to the correct source/run.

Do not run or modify the tests. A present test that fails to assert its named property may be a supported test deficiency even without executing it. An absent run is an evidence gap, not automatically a defective test.

### S2-REQ-09 — Evidence provenance and limitations

Every relied-on execution artifact must record its path, origin, source identity, command as reported, toolchain versions as reported, test selection, outcome and limitations. Reviewers do not execute recorded commands.

Use these evidence states independently of inspection conclusions:

| State | Meaning |
| --- | --- |
| `SUPPLIED_SOURCE_BOUND` | Supplied artifact identifies a matching source/test/dependency snapshot; outcome reported separately, not independently rerun here |
| `HISTORICAL_ONLY` | Artifact applies to an earlier snapshot or historical reproduction |
| `SOURCE_MISMATCH` | Known relevant differences invalidate direct carryover |
| `INCOMPLETE_PROVENANCE` | Necessary identity, command, selection or result detail is unavailable |
| `MISSING` | No usable artifact supplied for the required assertion |
| `NOT_REQUIRED` | This row has no runtime-evidence obligation; cite why |

Separately record supplied outcome as `PASS`, `FAIL`, `PARTIAL` or `UNKNOWN`. A source-bound failed run is not positive evidence. Supplied source-bound evidence is not a claim that Stage 2 independently verified execution authenticity or reran it.

Do not inherit the historical 34,909 passing tests, 33 campaigns, 37 fuzz properties, or conflicting matrix counts as current results. Review the claim, its provenance and its coverage. Historical tool versions, including versions mentioned in the original plan, are not asserted to be the current environment.

### S2-REQ-10 — Current matrix reconciliation

Re-derive the current documentary hook × SE inventory from current packages and tests. Include all seven SE-buffer hook families and distinguish relevant configurations and routes rather than collapsing variants into one row.

Each matrix row must contain:

- Stable row key: hook family/package, SE family/package/variant, relevant configuration and route/control set.
- Inclusion authority, current source paths and test file/function references, or explicit missing references.
- Declared design disposition: `COMPATIBLE`, `INCOMPATIBLE`, `DEPRECATED` or `UNDETERMINED`, with reason and source.
- Whether inspection supports that declaration or finds a contradiction.
- Separate execution-evidence state and supplied outcome under S2-REQ-09.
- Coverage owner, linked criterion/finding IDs and readiness implications.

Publish one current **documentary** count with its defined denominator and treatment of configuration variants. Separately count rows with applicable supplied runtime evidence. Missing or ambiguous combinations remain explicit rows or inventory blockers; they must not vanish from the denominator.

`COMPATIBLE` design disposition is not an executed passing integration. `INCOMPATIBLE` and `DEPRECATED` are not passing integrations. Do not adopt either 195/1/7 or 165/3/7 merely because it occurs in an old narrative. A catch-all rounding control alone does not substantiate compatibility.

New-vault integration applicability must be assessed from approved routes and consumer requirements. Do not fabricate unsupported combinations to force a Cartesian count, or omit supported combinations because an old test matrix predates them.

## 6. Review orchestration

### S2-REQ-11 — Bounded assignments and independent originals

The coordinator prepares an assignment manifest before fan-out. Every assignment includes:

1. The same source snapshot and authority hierarchy.
2. Primary surfaces, original/supplemental criterion IDs and relevant catalog classes.
3. Required family PRDs, shared dependencies and seam partners.
4. Explicit inspection-only permissions and no-fix/no-execution rules.
5. Distinct original and cross-review output paths.
6. Required schemas, completion criteria and a bounded review scope.

Sub-agents write only their assigned outputs. During first passes they must not read peer findings, including through artifact discovery searches. They may read shared source evidence and supplied historical records, labeling historical opinions as such. Preserve each attributed original before any revision or peer exchange.

Run substantive independent first passes concurrently in the authorized future runtime. The coordinator tracks coverage and failures but must not fill an unread lane with an invented reviewer conclusion.

### S2-REQ-12 — Cross-review and seam reconciliation

After the relevant originals are collected, perform one bounded cross-review wave:

- Each reviewer receives the relevant peer **originals** together, especially shared-dependency and neighboring-surface findings, not a chain of earlier cross-review opinions.
- Resume the same reviewer session where supported. Preserve attribution and explicit replacement history if the runtime/owner separately authorizes a replacement.
- Ask reviewers to challenge requirement precedence, source reachability, fixture assumptions, duplicate causes, evidence provenance and severity—not to vote a vulnerability into or out of existence.
- Ensure every proposed defect and every critical shared seam receives a second inspection or is explicitly marked as lacking that corroboration.
- The coordinator rechecks material citations, merges duplicate manifestations without losing affected consumers, and preserves unresolved disagreement and counterevidence.

No autonomous repeat-until-green loop. Additional review rounds, replacement reviewers or expanded scope follow the actual runtime protocol and owner authorization; this PRD does not bypass identity/guard constraints.

### S2-REQ-13 — Partial failures and stop conditions

Distinguish a missing ordinary source read from a failed reviewer session. Record a missing path and find a supported current locator when permitted; do not label an entire lane failed just because one historical filename moved.

Stop or pause affected work and preserve a partial report when:

- Launch authorization, source identity or actual concurrency capability is missing.
- A reviewer session/identity guard fails under the executor's protocol.
- Source drift invalidates assigned evidence.
- Required documents or coverage cannot be resolved within the assignment.
- A Stage-1 baseline contradiction requires an owner decision.
- An authority conflict prevents a supported conclusion.

Do not impersonate a missing reviewer, silently restart a failed identity, substitute models, claim complete coverage, or weaken criteria to finish. A serious supported finding may be surfaced promptly to the owner with defensive file-level evidence; it does not authorize live probing or an immediate fix.

## 7. Required schemas

Use Markdown tables or structured records embedded in Markdown. Field completeness and consistent semantics matter more than serialization. Do not require executable report-generation code.

### 7.1 Criterion ledger

Each original and supplemental row must include:

| Field | Required content |
| --- | --- |
| `criterion_id` | Stable original R ID or separately numbered supplemental ID |
| `requirement_reference` | Original text location and detailed controls |
| `controlling_authority` | Current D/OD/family ruling and citations; unresolved conflicts explicit |
| `applicability` | `APPLICABLE`, `SUPERSEDED`, `NOT_APPLICABLE` or `UNRESOLVED`, with rationale and replacement link if relevant |
| `product_and_surface` | Current variants, entrypoints and source paths |
| `owner_and_review_state` | Lane/reviewer/session; `INSPECTED`, `PARTIAL`, `UNINSPECTED` or `BLOCKED` |
| `inspection_result` | `MATCHES`, `CONTRADICTS`, `INDETERMINATE` or `NOT_ASSESSED`; never a runtime pass |
| `source_and_test_evidence` | File/line citations, test functions, inspected assertions and missing coverage |
| `execution_evidence` | State and supplied outcome from S2-REQ-09; artifact/source identity references |
| `origin_and_residual` | Original-program, supplemental, `STAGE1_OPEN`, `STAGE1_REGRESSION`; accepted residual authority where applicable |
| `linked_findings` | Stable findings and related rows, including cross-family consumers |
| `readiness_effect` | `BLOCKS`, `DOES_NOT_BLOCK` or `UNDETERMINED`, with the specific acceptance dependency |
| `confidence_and_limits` | Confidence in the stated inspection conclusion and remaining uncertainty |

Applicability, source consistency and execution evidence are independent dimensions. A source match may coexist with missing execution evidence. An accepted residual is not a claim that all associated tests passed. Missing required runtime evidence blocks the corresponding closure claim without automatically establishing a code defect.

### 7.2 Audit-item ledger

For each of the seven entries and two retractions, record original allegation/retraction, affected historical identity, supplied historical evidence, current implementation mapping, linked R/supplemental criteria, current findings and limitations.

Historical claim disposition is `CLAIM_SUPPORTED`, `CLAIM_REFUTED` or `CLAIM_UNVERIFIED`, explicitly tied to the historical claim and available evidence. It must not be reused as the status of a current acceptance criterion. Preserve reported severity separately from the reviewer's current impact assessment.

### 7.3 Finding record

Each finding includes:

- Stable ID, title, class and origin.
- Class: `CODE_DEFECT`, `TEST_DEFICIENCY`, `DOCUMENTATION_GAP`, `EVIDENCE_GAP` or `DECISION_NEEDED`.
- Severity: Critical, High, Medium, Low or Informational; confidence independently stated.
- Snapshot, affected packages/consumers, exact file/line citations or a bounded documented absence search.
- Intended behavior and controlling requirement/invariant.
- Observed behavior and reason it conflicts, or the precise evidence/decision missing.
- Impact class and scope, without inventing demonstrated fund loss.
- Supporting evidence, counterevidence and competing interpretations.
- Linked criterion/matrix/audit rows and Stage-1 relationship.
- Readiness effect with rationale.
- Suggested corrective objective or verification need in prose—not implementation code.
- Original reviewer attribution, cross-review response and coordinator disposition.

Report every supported severity. Do not suppress Low findings or automatically send only Medium/High findings to later remediation planning. Reserve `UNSUPPORTED_USE` for the accepted D12 residual, not as a generic label for missing coverage.

Do not include exploit procedures, proof-of-concept code, payloads or attack parameters in reports, titles or comments. Explain the violated property and affected path with enough defensive evidence for review without live-system attack instructions.

## 8. Output contract and ownership

### S2-REQ-14 — Durable report package

Proposed future output root: `docs/research/apex-stage2-review/<snapshot-label>/`. The launch request must resolve a unique label and confirm the future coordinator's permitted write roots. If that profile requires a different root, record the substitution before work; do not silently write outside permissions.

| Artifact | Owner | Purpose |
| --- | --- | --- |
| `REVIEW_MANIFEST.md` | Coordinator | Authorization, snapshot, inputs, assignments, sessions, concurrency record and limitations |
| `reviewers/<assignment>-original.md` | Assigned reviewer | Preserved independent first-pass findings and coverage |
| `reviewers/<assignment>-cross.md` | Same reviewer | Bounded cross-review corrections and dissent |
| `CRITERIA_LEDGER.md` | Coordinator | All original IDs and supplemental obligations, consolidated without losing attribution |
| `AUDIT_ITEM_LEDGER.md` | Coordinator | Seven entries and both retractions, historical/current distinction |
| `MATRIX_LEDGER.md` | Coordinator | Current documentary inventory/count and separate runtime evidence |
| `REPORT.md` | Coordinator | Human-readable consolidated decision report |

The coordinator owns consolidated files; reviewers have distinct assigned write targets. Never overwrite historical audit logs, original reviewer findings, Stage-1 evidence, source/configuration, instructions or secret files. No symlink/hardlink targets. Existing artifacts remain provenance inputs, not files to “clean up.”

### S2-REQ-15 — Consolidated report contents

`REPORT.md` must include:

1. Executive summary: source identity, inspection scope, actual concurrency and review status.
2. Explicit statement that Stage 2 did not run builds/tests/forks/chain checks.
3. Coverage accounting: baseline 108 reconciliation, supplements, missing/blocked coverage and matrix denominator.
4. Findings grouped by impact/severity with every severity represented when present.
5. Stage-1 continuity issues, if any, distinguished from new findings.
6. Evidence sufficiency assessment: source-bound supplied outcomes versus historical/missing/mismatched evidence.
7. Audit-item mapping, residuals, deprecated/incompatible surfaces and open product decisions.
8. Attributed agreements, cross-review corrections, unresolved dissent and coordinator reasoning.
9. Proposed next actions split into owner decisions, separately authorized verification needs and possible corrective objectives.
10. A human decision checkpoint and explicit stop: no remediation PRD or implementation automatically follows.

The executive summary must not headline “all criteria passed” when the actual result is inspection complete with unverified execution. Do not publish an unconditional “ready to submit” verdict from this review alone.

## 9. Acceptance criteria and completion states

### S2-REQ-16 — Review completion checklist

The coordinator may mark `INSPECTION_COMPLETE` only when all applicable conditions below are satisfied:

| ID | Acceptance condition |
| --- | --- |
| S2-AC-01 | Owner Stage-1 acceptance and separate Stage-2 launch request are recorded; required Stage-1 inputs identified |
| S2-AC-02 | Authorized real concurrent first-pass review occurred and is evidenced, with preserved reviewer/session attribution |
| S2-AC-03 | One review snapshot and relevant document/evidence identities are recorded; source drift is resolved or affected coverage remains incomplete |
| S2-AC-04 | All original R1–R14 nested IDs are reconciled against the documented 108 baseline; discrepancy, if any, is resolved rather than hidden |
| S2-AC-05 | Applicable Stage-1/current-product supplements are separately identified and inspected without changing the original denominator |
| S2-AC-06 | Three FullSpread variants and wings each have separate source/test/evidence conclusions; no variant substitution |
| S2-AC-07 | Every required coverage group and assigned shared seam has substantive review; uninspected assignments prevent full completion |
| S2-AC-08 | Seven audit entries and both retractions have evidence-qualified historical/current mappings |
| S2-AC-09 | Current matrix documentary inventory and counts are reconciled with denominator and unresolved combinations; no executed-pass claim derived from a source recount |
| S2-AC-10 | Relevant catalog applicability, production-route setup, assertion quality and supplied release evidence have been reviewed |
| S2-AC-11 | Findings contain complete evidence fields, all severities, attribution and counterevidence; unresolved corroboration limits are visible |
| S2-AC-12 | Independent originals are preserved; bounded cross-review and coordinator reconciliation completed without circular peer-consensus proof |
| S2-AC-13 | Accepted residuals, undecided policy, evidence gaps and actual defects remain distinct; readiness effects cite specific dependencies |
| S2-AC-14 | Report and ledgers agree on totals, source identity, statuses and limitations |
| S2-AC-15 | No production/test/config edits, test authoring, shell/execution, deployment or live operations were performed under Stage 2 |
| S2-AC-16 | The final report stops for owner discussion and does not generate a remediation PRD or authorize fixes |

Supplied runtime evidence may remain unverified while inspection is complete, provided the review actually assessed its absence/limitations and makes no unsupported closure claim. Unknown source coverage, unresolved inventory denominator or failed reviewer assignments instead require a partial/incomplete label.

### S2-REQ-17 — Report states and readiness effects

- `NOT_STARTED`: launch gates not yet satisfied.
- `BLOCKED_AT_LAUNCH`: authorization, Stage-1 inputs, source identity or concurrency capability unavailable.
- `IN_PROGRESS`: authorized inspection underway.
- `PARTIAL_REPORT`: useful findings delivered but required source coverage/reconciliation incomplete; list missing work and reason.
- `INSPECTION_COMPLETE`: S2-AC conditions met; execution/readiness limitations still separately stated.

Do not use finding severity as the sole readiness rule. A low-severity mismatch can break a locked acceptance criterion; an informational accepted residual may not. An unresolved decision can block a claim. For each blocker, identify exactly which requirement remains unsupported and what evidence or decision could resolve it.

This review cannot unilaterally amend the original acceptance gates. It can conclude that supplied evidence is insufficient, request separately authorized verification, or recommend owner discussion of corrective work.

## 10. Non-goals and preserved boundaries

### S2-REQ-18 — No expansion into implementation or live remediation

Out of scope under this review:

- Code edits, test fixes, new tests/test scaffolding, generated executable research code, build/test/fuzz/invariant execution or local simulations.
- Shell commands, live/read-only RPC checks, fresh fork inventory or protocol precheck execution. Reading supplied records is allowed.
- Deployments, migration, broadcasts, signing, fund movement, registry disablement or auditor messaging.
- Config/profile/toolchain changes, new tools, changing agent instructions/model pins, or executing a plan embedded in retrieved evidence.
- Merging hookless and Pons-family FullSpread packages to match an obsolete single-Common-path narrative.
- Binding wings to a Pons-configured pool without its own later ruling.
- Reconstructing old stored-total equality/greater-than cases on vaults whose accounting no longer uses them, or requiring preserved-old-source red runs contrary to OD-04/OD-07.
- Removing D12 or inventing a sender-attribution/atomicity mechanism; treating immutable live-instance exposure as if source review upgraded those instances.
- Slipstream product rewrite, unrelated DETF economics/vesting/threshold changes, or a general audit of non-SE hooks excluded by the original program.
- Deleting approved D41/D48/D49 probe behavior by treating every soft read as forbidden, or introducing new catch exceptions.
- Deciding the unresolved `supportsInterface` site, wings/Pons reuse, or the separately scoped `TokenStakingTarget` catch by implication. Review relevance and flag a decision need when warranted; do not invent authorization.

Crane interfaces/NatSpec and shared dependencies remain **readable evidence** where relevant even though editing them is prohibited. Preserve historical artifacts; do not rewrite historical counts as false merely because later counts differ.

## 11. Owner checkpoint and separate handoffs

Deliver the report and ask the owner to review:

1. Whether coverage is sufficient or more inspection is needed.
2. Which evidence gaps require a separately authorized verification session.
3. Which supported errors or approved documentation/test/evidence corrections should enter a remediation PRD.
4. Which unresolved policy questions need explicit rulings.

Record the owner's response with date, report/snapshot reference and requested next action. Do not manufacture OD-09 or another numbered ruling. A natural-language recorded decision is sufficient unless the owner requests a specific format.

No automatic filter limits the later discussion to only one finding class or severity. Evidence gaps are not automatically code fixes, but the owner may commission an evidence or test remediation plan. A new remediation PRD must distinguish those categories and must itself stop short of implementation authorization.

**Implementation handoff:** none is issued by this document. Future execution of this review, fresh verification, writing a remediation PRD, implementing that PRD, and audit submission are distinct decisions.

## 12. Drafting evidence, council review and confidence

### 12.1 Primary source anchors inspected during this discussion

Access date: 2026-10-07. These anchors support the requirements; line numbers are drafting-time locators and must be re-resolved if documents move.

| Source | Anchors |
| --- | --- |
| Readiness remediation PRD | :18–22 finite bar/stages; :75–79 residuals; :85–186 OD-01–08; :190–321 REQ-01–08; :325–369 dissent, unverified items and non-goals |
| Stage-1 plan | :19–40 scope; :85–95 outside-trade/evidence deliverables; :110–123 stage gate and open items |
| Original APEX plan | :13 stable 108 acceptance IDs; :15–36 original scope and exclusions; :67–79 audit entries/retractions; :85 onward locked decisions and scoped inventories |
| Wings PRD | v0.4, :13–36 controlling owner addenda; :54–75 product boundaries/precedence; :87–98 identity and integration boundaries |
| `CLAUDE.md` | :26–61 deployment/testing/product rules; :65–85 canonical skill and family routing |
| IndexedEx adversarial skill | `.claude/skills/indexedex-adversarial-testing/SKILL.md:19–45,146–174` scope, production paths and catalog applicability |
| Crane adversarial skill | `lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md:20–38` production-route and catalog review principles |
| Review-council documentation | `docs/agent/REVIEW_COUNCIL.md:57–69,98–106` existing protocol/permission limitations, not a parallel execution authorization |

No independent external library/API claims, current runtime-version certification, builds, tests or deployments were needed to author this PRD. Historical toolchain identities in inputs remain historical. Final source inventory and evidence manifests are launch deliverables, not claimed completed here.

### 12.2 Attributed drafting review

Original recommendations and cross-reviews are preserved under `docs/research/apex-stage2-prd-authoring-2026-10-07/` as `{astra,grok,minimax,kimi}-{original,cross}.md`.

- **Astra:** emphasized preserved 108-ID denominator, product-specific wings law, genuine concurrency, provenance and independent applicability/inspection/execution dimensions.
- **Grok:** emphasized explicit launch capability, current consumer inventory, Stage-1 continuity markers, and separating review delivery from execution and submission.
- **MiniMax M3:** proposed detailed lanes and evidence schema; cross-review corrected ambiguous statuses and fixed lane-count assumptions. Its proposed Medium+ filter, catalog “ceiling,” mandatory OD numbering and several shorthand source locators are not adopted.
- **Kimi K3:** emphasized matrix/current-variant coverage and runtime-evidence separation; cross-review corrected bare confirmed/refuted criterion labels. Automatic nonblocking treatment of undecided items and restricted automatic remediation triggers are not adopted.

All four supported the broad inspection-only, real-parallel, report-first workflow. Material drafting corrections incorporated here: no arbitrary reviewer quota; overlapping reads for shared seams; all R1–R14 coverage; separate matrix design/runtime counts; all-severity findings; incomplete coverage cannot be called completed review; no automatic remediation scope or invented owner ruling.

Remaining differences in suggested lane granularity and artifact serialization do not require a product decision: the future coordinator may schedule bounded assignments while meeting this PRD's fields and coverage gates. This PRD was consolidated by the moderator after one independent pass and one combined-original cross-review per researcher; it is not claimed to have received a separate final-file review by all four.

Preserved sessions for follow-up:

| Researcher | Session |
| --- | --- |
| Astra | `ses_ee9d2201effevgSSQAK1CynPS0` |
| Grok | `ses_ee9cfa4a2ffeZ4Hf1NLbN0301b` |
| MiniMax M3 | `ses_ee9ccf532ffe7kBBq6lhXrOnHr` |
| Kimi K3 | `ses_ee9cb8cc7ffej454Wuz3lXnR2P` |

**Confidence:** high that this captures the confirmed review workflow and stage boundaries; execution feasibility, Stage-1 completion and actual source correctness remain unverified. The human checkpoint is review of this draft—not an assertion that Stage 2 has begun.
