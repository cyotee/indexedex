# MiniMax M3 — cross-review, Stage 2 PRD readiness

**Sources:** `astra-original.md`, `grok-original.md`, `kimi-original.md` (verbatim); `REVIEW_COUNCIL.md:57-62, 96-106`. No cross artifacts.

**Permission-asymmetry correction.** Current session writes to `docs/research/`; future Stage-2 workflow writes to `docs/reviews/` (`REVIEW_COUNCIL.md:102`). My original missed this — the drafting PRD must distinguish "this session" from "future review workflow."

**Roster/parallel.** `REVIEW_COUNCIL.md:57-62` mandates four named reviewers, **synchronous sequential**, not parallel. My "≈10 sub-agents" overstates — four reviewers, partitioned prompts, coordinator schedules.

## Minimal genuine owner questions

1. **Does non-execution trigger a remediation PRD?** Default: **no** — non-execution is *unverified*, not a defect (`REMEDIATION_PRD.md:22, 336-345`; `REVIEW_COUNCIL.md:68`). All three peers converge. Missing execution evidence blocks readiness without being a code defect.
2. **Stage-1 evidence note path/status.** `plan.md:91-95` orders a note that does not yet exist. Default: placeholder clause — Stage 2 review does not begin until that note exists and owner is satisfied.

## Coordinator defaults (no re-ask)

- **Deliverables:** findings only — severity, file:line, broken invariant, impact class, fix direction; no PoC, no executable test scaffolding (`REVIEW_COUNCIL.md:64-69`; `REMEDIATION_PRD.md:166-177`).
- **Severity → remediation trigger:** Medium/High with verified cite.
- **Report path:** `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE2_REPORT.md`.
- **Sharding:** four reviewers, prompts partitioned by R-group/finding/catalog; sequential.
- **Source authority:** one post-Stage-1 tree snapshot; dirty-file identity recorded; no silent Stage-1 evidence carryover (`plan.md:93-95`).
- **Forbidden rework:** no merge hookless+Pons, no wings↔Pons binding, no `supportsInterface` probe ruling, no old stored-total reconstruction (`plan.md:118-123`).

## My corrections

- **Q1 partitioning:** withdraw "≈10 sub-agents." Four, period.
- **Q2 scaffolding:** align with Grok/Kimi — fix-direction prose only.
- **Q3 severity:** misframed. Real question is non-execution → remediation; severity is downstream.
- **Q4 path:** kept.

## Unresolved dissent

None material. Kimi Q2 overlaps Q2 above. Settled: owner-satisfaction gate, threat-model bar, OD-07 rule, accepted residuals (`REMEDIATION_PRD.md:22, 75-79, 162, 166-177`).

**Confidence:** high on defaults and the two genuine questions; high on permission-asymmetry correction.