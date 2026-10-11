# MiniMax M3 — Stage 2 PRD authoring cross-review

**Sources:** `astra-original.md`, `grok-original.md`, `kimi-original.md` (verbatim); my own `minimax-original.md`. No cross artifacts.

## Consensus (all four)

Inspection-only review; report-only deliverable; remediation is a separately owner-requested PRD; owner-satisfaction entry gate; current snapshot identity required (HEAD insufficient); no silent evidence carryover when files changed; catalog A–K/A0/L/M/N/O ceiling; OD-08 controls over older OD text; OD-07 production-route test bar is **not** closed by inspection; real concurrency preserved as future requirement, current synchronous council not a substitute; unverified execution evidence blocks readiness, is not a defect; all severities reported including Low/Informational; no new feature scope in Stage 2.

## Material disagreements and corrections

**1. CONFIRMED-status ambiguity (Grok + Kimi flag, mine weak).** A bare `CONFIRMED` collides two truths: criterion truth ("source matches the locked property") and finding truth ("source contradicts it"). Recommendation: split into **CONFIRMED_MISMATCH** (defect) and **INSPECTION_MATCH** (compliance; does **not** clear an execution criterion, per Grok:50). Add **STAGE1_OPEN** for items left open from Stage 1, so they are not silently reclassified as new program defects. Keep **SUPERSEDED-BY-OD** for amendments; **ACCEPTED-RESIDUAL** strictly for D12/D57/immutable chain-4663; **NOT_APPLICABLE** only with reason.

**2. New-product obligations vs 108 denominator (Astra + Kimi).** Stage 1 added obligations not in the original 108 (REQ-04 wings outside-trade, REQ-07 rate provider, REQ-08 source map). Recommendation: preserve all 108 IDs verbatim (including superseded rows) and add new-product obligations under **separately numbered IDs**, never silently changing the denominator.

**3. Lane count is not a PRD-fixed number (Astra + Kimi).** My 12, Grok's 16, Kimi/Astra 8. Consensus across peers: PRD defines lane **boundaries** and disjoint file sets; the authorized coordinator schedules the roster. PRD must not impose an arbitrary number or model.

**4. Test scaffolding vs test authoring (Astra).** My original said "no test authoring"; peer consensus is "no test scaffolding either" (reports deliver **fix_direction prose**, never code or PoC, per `R:175`).

**5. Owner sign-off format is an open item (Kimi).** My original did not name it; Kimi correctly flags that the PRD should request owner input rather than invent a sign-off shape. Recommendation: PRD lists `OD-09 (proposed): report sign-off format` as an owner decision.

**6. Matrix declared-vs-executed (all four).** Consensus: COMPATIBLE on inspection does not equal executed passing. Recommendation: matrix row schema includes a separate `execution_status` field distinct from `design_disposition`; an inspected row without a tied execution claim is UNVERIFIED, not COMPATIBLE.

## My corrections to my original

- **Lanes:** drop the fixed count; describe boundaries and disjoint file sets.
- **Dispositions:** replace 5-class with the 7-class set above.
- **Test policy:** add explicit no-scaffolding rule.
- **Owner sign-off:** name as open item requesting owner ruling.
- **New-product obligations:** preserve 108 denominator; add separate numbering.
- **Matrix schema:** add `execution_status` distinct from `design_disposition`.

## Unresolved dissent

None material after corrections. Mild: peers differ on lane count, but consensus is that count is coordinator-scheduled, not PRD-fixed.

## Confidence

High on consensus and the six concrete corrections; high that the input locks in a sharper PRD than any single original.