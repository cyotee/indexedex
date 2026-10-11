# Astra — independent Stage-2 PRD recommendations

Read 2026-10-07. These are proposed requirements for the moderator's `docs/plans/APEX_STAGE2_REVIEW_PRD.md`, not execution authorization or findings about current code. No peer artifacts consulted this pass.

**Citation keys:** R = `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`; P = its `REMEDIATION_PRD.plan.md`; A = `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md`; W = `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md`.

## 1. Purpose, authority, boundaries

Require an inspection-only, genuinely parallel review of the broad original APEX acceptance program against the identified current tree, including changed/new vaults. Output a consolidated report for owner discussion; a remediation PRD is a subsequent possible request. No autonomous remediation, test scaffolding, builds/tests, chain queries, deployments, configuration edits, or source changes. Reading supplied execution artifacts is permitted; executing their contents is not. Owner clarification controls workflow; current OD rulings control older conflicting acceptance text. **[R:155–186; CLAUDE.md:12–13]**

Keep separate: review completion, evidentiary readiness, audit-submission authorization, and immutable live-instance status. A completed report may conclude readiness blocked. Missing runtime evidence is not automatically a code defect. **[R:338–369]**

## 2. Launch and provenance gates

- Require recorded owner satisfaction with Stage 1 and separate Stage-2 launch authorization. Require the Stage-1 note, four outside-trade tests, current-source map, and build/selector/size/named-regression evidence as identified inputs; do not rerun them here. Missing evidence returns the launch to the owner rather than silently completing Stage 1. **[P:91–95,114–116; R:184–186]**
- Require an authorized coordinator capable of real overlapping sub-agent review. Record reviewer identity, assigned lane, start/end times, outputs and actual overlap. The current council's synchronous roster is not a substitute. If capability is unavailable, stop and report that blocker; do not change configuration or fabricate concurrency.
- Pin IndexedEx/Crane source identities and dirty-source manifest supplied through permitted evidence. HEAD alone is insufficient. Every lane reviews that snapshot. Changed relevant files invalidate affected coverage pending reinspection; unrelated changes require recorded impact assessment. **[R:311–320; A:111]**

## 3. Coverage lanes

Lane count is coordinator scheduling, not a fixed model roster. Assign each criterion a primary owner and cross-lane dependencies; no unowned rows. Suggested independently reviewable lanes:

1. **Provenance/program reconciliation:** 108 original R IDs, D1–D69 amendments, seven findings/two retractions, source/evidence mapping, historical instance inventory and residuals.
2. **FullSpread:** separate V3, V4 hookless, V4 Pons subassignments; outside-trade credit, quotes/execution, reserve custody, shared dependencies and package differences. Never infer one variant proves another. **[R:140,185,317]**
3. **Wings:** target-only routes, held-credit isolation, liquidation valuation, harvest/unlock lifecycle, costs, exact-output behavior, reserve floor, residual/zero-supply ownership, registry and consumer integration. Apply O1–O7/A3 precedence, not FullSpread ownership assumptions. **[W:13–36,54–75]**
4. **Receipt/custody/lending:** ERC-4626/Stata shared adapter and dispatch, custody SE/SY, Morpho burns, Aave loop capacity/unwind, cross-interface books and caps. **[R:113–128,343; A:135,151–152]**
5. **AMM/LST SE families:** Uni V2/Camelot/Aerodrome, Lido/Rocket/EtherFi capacity/sleeves, native wrapping and errors; document Slipstream deprecation, not a rewrite. **[A:129–137,147]**
6. **Hooks/matrix:** seven SE-buffer hook families, current SE combinations, operation-scoped refunds, rate providers, transition projections and reachable rounding/partial-consumption controls. **[A:110,140–158,550–558]**
7. **Balancer/DETF:** native-BPT boundaries, buffer pools, D68/D69 quotes, DETF prepaid/exchange entries and dependency propagation; preserve D32 and D41/D48/D49 exceptions. **[A:122,128,131,138–139; R:332–344]**
8. **Cross-cutting test/surface review:** independent check of production deployment routes, Target→facet→package→proxy coverage, assertion precision, non-vacuous fuzz/campaigns, size evidence and integration documentation. **[A:560–584; .claude/skills/indexedex-testing/SKILL.md:25–35,144–184]**

## 4. Required evidence schemas

**Criterion ledger:** original ID/text reference; controlling amendment; current applicability and rationale; package/source paths; lane/reviewer; inspected test names/assertions; execution-evidence reference/source identity; conclusion; gaps; linked findings. Preserve all 108 IDs, including superseded/inapplicable rows; add separately numbered new-product obligations rather than silently changing the denominator.

**Matrix:** hook/SE/configuration/route key; source and test references; design disposition (`COMPATIBLE`, `INCOMPATIBLE`, `DEPRECATED`, `UNDETERMINED`); reason; separate runtime-evidence status. Recount documentary rows against current inventory, including new variants. Publish one count with denominator and completeness caveat; source-inspected compatibility is not an executed passing integration. **[R:320,341; A:553]**

**Finding:** stable ID, all severities, confidence, affected source/lines, authority/invariant, observed mismatch, impact, supporting/counterevidence, classification (code defect/test deficiency/documentation/evidence gap/decision needed), suggested corrective objective—not code or exploit instructions. Reserve `UNSUPPORTED_USE` for D12. **[A:102; R:368]**

## 5. Consolidation and acceptance

Preserve attributed lane originals; coordinator deduplicates without erasing disagreement and checks cited source/authority. Review cross-lane seams explicitly. Accept the report when all criterion/matrix/new-product rows are dispositioned, concurrency is evidenced, findings are traceable, missing reviews are visible blockers, and historical/unverified execution is unmistakably separated from inspected assertions. Include executive readiness assessment, coverage ledger, findings, residuals, dissent, and proposed verification needs.

Do not equate unanimous reviewers, old green totals, bare reverts, or test names with security proof. No suppression of Low findings; no automatic remediation document. Deliver report, request owner discussion, and stop. **[R:174–177,338–369]**
