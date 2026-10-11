# MiniMax M3 — original first pass, Stage 2 PRD readiness

**Question.** Do I have what I need to draft a Stage 2 review/report PRD? Material unanswered requirements? Suggested defaults?

**Sources re-read:** `REMEDIATION_PRD.md` (`:155-186`, `:336-346`), `REMEDIATION_PRD.plan.md:114-123`, `CLAUDE.md:1-109`, `RESEARCH_COUNCIL.md:41-94`. No peer originals or earlier consolidated reports read this pass.

## Sufficiency to draft

Yes, for **structure**. The PRD can adopt the Stage-1 artifact layout: header + Required outcome + Inputs + Owner decisions + Requirements + Dissent + Non-goals + Coordinator note. OD-06 (`PRD:155-164`), OD-07 (`:166-177`), OD-08 (`:179-186`), and the Unverified backlog (`:336-346`) supply binding language. Per owner clarification, Stage 2 is **review/report only**, not implementation; the new PRD adds a **Coordination section** covering sub-agent partitioning, report paths, and the report→remediation trigger.

## Essential questions (need owner ruling)

1. **Sub-agent partitioning.** One per current FullSpread package + wings + each `Unverified` surface? Or by catalog class (A–K + A0/L/M/N/O)? **Default:** one per FullSpread variant (V3, V4 hookless, V4 Pons-family) + wings + receipt/Morpho/Stata/Aave/Lido/Rocket/EtherFi + Balancer D68/D69 ≈ ~10 sub-agents.
2. **Sub-agent deliverables.** Defect findings (file/line, severity, broken invariant, suggested acceptance) only, or also test scaffolding? **Default:** findings only, citing locked properties in `indexedex-adversarial-testing/SKILL.md:146-174`; no test code authored here.
3. **Escalation threshold.** "If any errors are found" — what severity/concreteness triggers a remediation PRD vs in-report acceptance? **Default:** Medium/High with verified file/line and broken invariant triggers a Stage-2 follow-up PRD; Low stays documented.
4. **Report file path and format.** Single report or per-sub-agent write-ups consolidated? **Default:** `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE2_REPORT.md` with REQ-### sections inside if defects found.

## Nonblocking defaults (no re-ask)

- **Entry gate:** owner satisfaction with Stage-1 results (`PRD:163`).
- **Submission identity:** post-Stage-1 tree; snapshot-to-current map required (`PRD:613-621`).
- **Test discipline:** OD-07 production-route rule applies; no exploit-prose in names/comments.
- **Residuals carry through:** immutable chain-4663, D12, D57 Slipstream (`PRD:75-79`).
- **Forbidden rework:** no merge of hookless+Pons, no wings↔Pons binding without separate ruling, no old stored-total reconstruction (`PRD:151-153`, `:362-369`).

## Permission boundary (must distinguish)

This drafting session is read-only/document-authoring per `CLAUDE.md:12` and `RESEARCH_COUNCIL.md:73-75`. It cannot spawn sub-agents, run `forge build`/`forge test`, or invoke background tasks. The PRD will **name** those actions as a **future, separately authorized** session. PRD authorship is not execution authority.

## Settled and not re-asked

OD-06 ordering; owner-satisfaction gate; threat-model bar (`PRD:22`); OD-07 test rule; OD-08 Stage-1 inclusions; accepted residuals; audit submission waits for Stage 2 (`PRD:163`).

## Confidence

High that a draft is possible; medium on defaults 1–4 (owner may refine); high on permission boundary.