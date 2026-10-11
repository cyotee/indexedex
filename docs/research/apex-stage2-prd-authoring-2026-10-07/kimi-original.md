# Kimi K3 original — recommended Stage 2 PRD content

Independent first pass, 2026-10-07. Citations: **R** = `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`; **P** = its `.plan.md`; **A** = `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` (locked plan, D1–D69, criteria R1.1–R14.x, 108 total); **RC** = `docs/agent/REVIEW_COUNCIL.md`. No peer artifacts read. Recommendations for the moderator-authored `docs/plans/APEX_STAGE2_REVIEW_PRD.md`; not a draft of that file.

## 1. Header and authority clauses
Mirror the Stage-1 handoff posture: Status DRAFT; "this document does not authorize code changes, test execution, test authoring, deployments, or config changes"; executing it requires a separate explicit request naming a capable coordinator (R:8; P:6). State plainly that the PRD describes a *future* workflow with real concurrent sub-agents, and that the current synchronous four-reviewer council and the `/review-council` default (RC:24-31, :57-62) are **not** permission to silently substitute for it. No plugin/config edits are authorized to create that capability.

## 2. Required outcome
Reconcile the full original APEX acceptance program against the post-Stage-1 tree: all 108 criteria (A:456-632, stable `R#.#` IDs per A:13, :458), a current hook × SE matrix count (R:320), and the changed/new vaults — FullSpread V3, V4 hookless, V4 Pons-family, and the wings vault (R:140, :185; P:34). Deliverable is one consolidated review report for owner discussion; a remediation PRD follows only if the owner requests it after that discussion. The report is not security certification and not audit submission (R:162, :369).

## 3. Entry gate (settled; restate, don't reopen)
Stage-1 evidence note exists (P:91-95), owner satisfaction recorded, separate launch authorization issued (R:162; P:114-116). The PRD should name its input snapshot by revision plus dirty-file hashes (A:463 R1.3), since HEAD alone does not identify inspected files (A:58).

## 4. Inputs
Locked plan A and its PRD; the seven findings + two retractions (A:67-79); follow-up record labeled claims-not-proof (R:31, :37); OD-01–OD-08 (R:85-186); Stage-1 evidence note; wings PRD (`docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md`, R:103); adversarial catalog classes A–K/A0/L/M/N/O (R:22).

## 5. Coverage lanes (recommended partition)
Lanes are review assignments, scaled to whatever roster the authorized coordinator actually has; one variant never proves another (R:185).

- **L1 Findings & retractions:** re-validate APEX-2026-001-M/M2, 003, 008, 009, 004B, 005 and both retractions against current source (dispositions at R:350-360; criteria A:476-559).
- **L2 FullSpread family:** V3, V4 hookless, V4 Pons-family packages; verify the REQ-08 source map and selector evidence match the tree (R:308-321); confirm the three outside-trade tests exist and assert the OD-04 property (R:263-265).
- **L3 Wings vault:** against its own PRD, including its outside-trade test and hookless pool binding (R:140, :153).
- **L4 Matrix recount:** derive one current hook × SE count from current tests; treat 195/1/7 and 165/3/7 as historical until one is tied to the submission tree (R:320); INCOMPATIBLE/DEPRECATED rows never count as passing integrations (R:251; A:553 R10.3).
- **L5 SE-family backlog:** receipt-backed dispatch, Morpho burn sites, Stata/Aave loop capacity, Lido/Rocket/EtherFi prechecks (R:343).
- **L6 DETF surfaces:** D16 pretransfer inventory (R:344), prepaid entries beyond the residual helpers, the deferred `TokenStakingTarget.sol:452` catch — reported as-is, not removed absent a D16/D37 ruling (R:333).
- **L7 Balancer rate/transition quotes:** D48/D49 exceptions intact, REQ-07 branch removed, D68/D69 transition quotes (R:291-304, :343).
- **L8 Evidence & Stage-1 repair verification:** each REQ-01–REQ-08 repair site re-read against its OD; OD-08 consistency rulings hold; historical sections remain labeled historical (R:318).

Each lane maps applicable catalog classes to its surfaces and records classes considered and rejected (R:345).

## 6. Disposition and evidence schemas
**Per criterion:** ID; file:line; disposition ∈ {CONFIRMED, REFUTED, UNVERIFIED, SUPERSEDED-BY-OD (cites OD), ACCEPTED-RESIDUAL (D12/D57/4663 only, R:76-79)}; evidence citation (document path + exact test name where a test is cited, per A:458); reviewer identity; confidence. **Per finding:** RC:64-69 fields — title, severity (all severities reported, per owner), file:line, intended behavior, broken invariant, impact class, fix direction, confidence; no exploit procedure/PoC/payload (R:175). **Execution claims:** unexecuted evidence (34,909 tests, 33 campaigns, fork inventory; R:37, :340-342) is recorded UNVERIFIED; it can block a readiness conclusion but is not automatically a code defect (owner-settled). Suggested report path: `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE2_REVIEW_REPORT.md`.

## 7. Acceptance gates for the review itself
1. Every one of the 108 criteria dispositioned with a citation; zero undispositioned.
2. One current matrix count, or an explicit recorded blocker (A:490 R4.5 blocker rule).
3. All four vault variants and the wings vault covered by named lanes.
4. Every Stage-1 repair site re-read; any drift reported as a finding, not silently re-fixed.
5. Report includes disagreements, blockers, residuals, and dissent — and stops for the owner even if no defects are found.
6. Report states it is not audit submission and does not close OD-07's executable-test bar (R:162, :177).

## 8. Pitfalls / non-goals to encode
No fixes, test execution, or test authoring in Stage 2; no red runs demanded on old source (R:176); no reconstructing stored-total cases (R:139, :268); no merging hookless/Pons or wings↔Pons binding decision (R:151-153); no `supportsInterface` probe ruling (R:203); no treating historical green counts or Stage-1 pass as criterion closure (R:17, :319); no silent evidence carryover where files changed post-Stage-1; no claiming live-instance remediation (R:77); no consensus-as-proof (R:369). Where the inspection-only default leaves a criterion's execution prong unverifiable, mark UNVERIFIED rather than weakening the criterion.

## 9. Open items the PRD should name but not decide
Execution-evidence regeneration (a separately authorized run session); fork/chain-4663 re-query; owner sign-off format for the report; remediation-PRD trigger discussion after owner review.

**Confidence:** high on structure, lanes, schemas, gates; medium on lane granularity (moderator may merge L5-L7 by capacity).
