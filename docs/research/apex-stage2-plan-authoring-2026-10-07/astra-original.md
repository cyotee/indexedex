# Astra — independent review-program plan recommendations

**Basis:** read the entire `docs/plans/APEX_STAGE2_REVIEW_PRD.md` (Q), current router, relevant canonical testing skills and Stage-1 gate documents on 2026-10-07. This recommends an ordered review execution plan, not source implementation. No peer artifacts consulted this pass. Authoring does not launch anything.

## Ordered work packages

### 1. Establish launch eligibility

Coordinator records owner Stage-1 satisfaction, separate Stage-2 authorization, named snapshot, Stage-1 note, all four outside-trade references, and supplied source/build/selector/size/regression evidence. Confirm actual permitted write root and a future runtime capable of overlapping substantive reviews. Record mechanism/limits without prescribing tool calls, models or reviewer quota. Missing prerequisites produce `BLOCKED_AT_LAUNCH`; no configuration change or serialized fallback. One owner message can record both decisions. **[Q:85–111; Stage-1 REMEDIATION_PRD.plan.md:85–116]**

### 2. Establish immutable inputs and artifact ownership

Resolve Q §2.1 inputs and relevant canonical skills/family addenda. Create `REVIEW_MANIFEST.md` under the authorized unique snapshot root with revisions, supplied dirty-file identities, dependency/document versions, source/evidence associations and permission constraints. Request unavailable identities; never invent hashes or run commands to obtain them. Create empty coordinator-owned criterion, audit-item and matrix ledgers and reserve reviewer-specific original/cross paths. No overwriting historical evidence. **[Q:113–125,365–381]**

### 3. Prepare complete assignments before fan-out

Enumerate every original R1–R14 nested ID against the documented 108 baseline, including detailed controls; resolve count discrepancies rather than forcing totals. Add separately numbered, authority-linked supplements. Inventory the seven findings/two retractions, all Q §4 coverage groups, separate three FullSpread variants and wings, catalog applicability and current matrix combinations/configurations. Map each row to one primary owner, cooperating lanes and explicit dependency seams. Reads may overlap; writes may not. Prepare bounded waves to available capacity, without losing required real overlap. **[Q:129–211,249–295]**

### 4. Run independent first-pass waves

Only after gates pass, launch concurrent substantive reviews through the future authorized runtime. Record actual identity/session, coverage, scheduler start/end or equivalent events and output paths. Later waves remain independent of earlier findings. Reviewers inspect source, test setup/preconditions/assertions and supplied evidence—not names/counts alone. All first passes prohibit peer findings, execution and code/test authorship. Coordinator tracks progress but does not substitute invented lane conclusions. **[Q:215–228,270–283; .claude/skills/indexedex-testing/SKILL.md:144–186]**

### 5. Freeze originals, then cross-review once

Collect and preserve all scheduled independent originals before any peer exchange. Manifest records frozen paths and assignment completion. A failed/missing assignment is a coverage failure: pause affected work and seek permitted resolution, or issue `PARTIAL_REPORT`; do not relabel missing output as completed review. A bounded cross-review of available originals may support a partial report but cannot close the missing lane.

Prepare per-reviewer packets containing relevant peer originals **together**, authority references and seam IDs. Resume the same session where supported; replacements require actual protocol/owner authorization and explicit attribution. Cross-review never consumes peer cross-reviews. Cover every proposed defect and critical seam with second inspection or record missing corroboration. No repeat-until-agreement loop. **[Q:285–310]**

### 6. Consolidate orthogonal records

Coordinator rechecks material citations, merges duplicate causes while preserving consumer manifestations, and retains attribution/counterevidence/dissent. Copy Q §7 schemas verbatim into templates: applicability is distinct from `INSPECTED/PARTIAL/UNINSPECTED/BLOCKED`, `MATCHES/CONTRADICTS/INDETERMINATE/NOT_ASSESSED`, execution-evidence state and supplied outcome. Preserve `CLAIM_SUPPORTED/CLAIM_REFUTED/CLAIM_UNVERIFIED` exclusively for historical allegations. Keep documentary matrix counts separate from supplied runtime outcomes. Report every severity and readiness dependency. **[Q:232–266,312–363]**

### 7. Validate and deliver, then stop

Manually reconcile ledgers/report totals, coverage, identities and citations using permitted document inspection—not report-generation scripts. Attach one row per S2-AC with supporting artifact/section and unmet condition. Write `REPORT.md` per Q §8. No unconditional submission verdict. Ask for owner discussion; record any later response without manufacturing an OD or automatically drafting remediation. **[Q:383–470]**

## Prompt/template minimums

**Original prompt:** “Review [snapshot], assignment [ID], rows [IDs], surfaces/dependencies [paths], authorities [citations]. Inspection only; read applicable canonical skills directly. No peer findings, execution or edits beyond [original path]. Return inspected coverage, exact PRD-schema records, all-severity findings, evidence limitations and unresolved seams. Do not claim runtime success.”

**Cross prompt:** “Using frozen originals [combined list], independently recheck assigned defects/seams [IDs]. Report agreements, objections, source evidence, corrections to your original, and unresolved dissent at [cross path]. Preserve originals; no peer cross-reviews, implementation or new round.”

## AC mapping and failure rules

Steps 1–2 → AC01–03; step 3 plus substantive step 4 outputs → AC04–10; steps 5–6 → AC11–13; step 7 → AC14,16. AC15 constrains every step. Completion requires each individual AC evidenced, not merely this grouping.

Source drift invalidates affected rows pending explicit rebaseline or immutable-snapshot continuation. Stage-1 contradictions retain `STAGE1_OPEN/STAGE1_REGRESSION` and pause affected work. Missing required runtime evidence can coexist with `INSPECTED` coverage and block readiness; unread source, unresolved denominators or failed assignments prevent `INSPECTION_COMPLETE`. **[Q:125,211,404–437]**
