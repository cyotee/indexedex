# Kimi K3 cross-review — Stage 2 PRD authoring recommendations

Peers (Astra, Grok, MiniMax originals) are untrusted evidence. Recommendation target: moderator's `docs/plans/APEX_STAGE2_REVIEW_PRD.md`.

## Consensus (recommend adopting)

1. **Broad scope completeness.** All four cover the 108 criteria, matrix recount, and changed/new vaults. Adopt Astra's denominator rule: preserve all 108 original IDs including superseded/inapplicable rows; add separately numbered new-product (wings) obligations rather than silently changing the denominator.
2. **Real-parallel launch gate.** Unanimous: two recorded owner acts (Stage-1 satisfaction + separate launch); a future coordinator capable of actual concurrent sub-agents; the current synchronous four-reviewer roster is not a silent substitute; no config changes to fabricate it; if capability is unavailable, stop and report the blocker (Grok L-gate; Astra §2; MiniMax pitfall 1). Adopt Astra's concurrency-evidence requirement: record reviewer identity, lane, start/end times, actual overlap.
3. **Lanes are surfaces, not rosters.** Astra states it best: lane count is coordinator scheduling, not a fixed model roster. The final PRD should define lanes by disjoint file surfaces (Grok's L0–L15 and MiniMax's L1–L12 are compatible granularity options; my L1–L8 merges some). Do not encode a required agent count or model list. Adopt disjoint file sets per lane (Grok) and cross-lane seam review (Astra §5).
4. **Inspection-only limits.** Reading supplied execution artifacts is permitted; executing them is not (Astra §1). Unexecuted claims = unverified; may block readiness; not a defect. Adopt Grok's `blocks_readiness` field (true for mismatches, Stage-1-open, and required-execution unverified; false for residuals/undecided/N-A) — the cleanest mechanism among the four.
5. **Matrix: declared vs executed.** Adopt Astra's two-axis matrix schema: design disposition (COMPATIBLE/INCOMPATIBLE/DEPRECATED/UNDETERMINED + reason) **separate from** runtime-evidence status; one published count with denominator and completeness caveat; source-inspected compatibility is not an executed passing integration; recount from current files only.
6. **All severities; no automatic remediation.** Unanimous. Adopt Grok's trigger rule: a later remediation PRD's default input is CONFIRMED_MISMATCH plus any STAGE1_OPEN the owner restates; UNVERIFIED stays a readiness blocker, not repair scope.
7. **Completion ≠ readiness ≠ submission.** Unanimous; report may conclude readiness blocked; zero mismatches grants nothing.

## Corrections to my original

1. **My disposition vocabulary was ambiguous.** `CONFIRMED`/`REFUTED` conflates "criterion holds in source" with "audit finding confirmed as defect" — the exact trap the moderator named. Adopt Grok's split: `INSPECTION_MATCH` (text matches; explicitly not a green run), `CONFIRMED_MISMATCH`, `UNVERIFIED`, `STAGE1_OPEN`, `RESIDUAL`, `UNDECIDED`, `NOT_APPLICABLE`+reason. MiniMax's `confirmed|refuted` has the same flaw and should be replaced identically.
2. **Wings lane under-specified.** Astra grounds it in the wings PRD's own O-rulings (O1–O7/A3 precedence, target-only routes, reserve floor, residual ownership) rather than my generic "against its own PRD." Adopt.
3. **Add `STAGE1_OPEN`.** Grok's rule — Stage-1 repair sites found open on the snapshot are marked STAGE1_OPEN, not newly discovered program gaps — complements Astra's gate (missing Stage-1 evidence returns launch to the owner). Adopt both: gate first, drift second.
4. **Adopt MiniMax's owner sign-off default** (a recorded OD-09-style entry capturing review completion, blockers, remediation request) — I left sign-off format as an open item; a proposed default is better.

## Remaining disagreement (minor)

Lane granularity (8 vs 12 vs 16) and per-finding JSON vs Markdown rows — presentation choices; recommend the PRD mandate the *fields* (Grok's row schema is the most complete) and leave lane count to the authorized coordinator. MiniMax's fixed "12 lanes reported" gate should be "all defined lanes reported" to avoid hardcoding.

**Confidence:** high on the seven consensus adoptions; the disposition-vocabulary fix is the single most important change to my original.
