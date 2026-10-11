# Grok cross-review — Stage 2 PRD authoring

**Consensus to write.** Inspection-only review of the 108 R-ids, the current hook × SE inventory, and V3, V4 hookless, V4 Pons-family, and wings. No fixes, test runs, test authoring, deploys, or config edits. Launch needs recorded Stage-1 satisfaction, the Stage-1 note as a read-only input, and a separate authorization of a coordinator that can overlap lanes. If that capability is absent, stop and report the blocker. Do not substitute the synchronous four-reviewer council (`REVIEW_COUNCIL.md:57-62`, `:102-106`). Lane count and models are scheduling, not a completion quota (Astra; Kimi). Review completion, evidentiary readiness, audit submission, and live-instance status stay separate (`astra-original.md:11`). Missing execution blocks readiness and is not a code defect. All severities are reported. No remediation PRD is produced by the review.

**Own corrections.** Drop “16 lanes must report” and bare `CONFIRMED_MISMATCH` as the remediation input. Completion is every R-id owned, not a lane total. A mismatch is not automatically a later PRD. Adopt Astra’s split: design disposition is not an executed pass (`astra-original.md:36`).

**Status rule.** Do not use bare `confirmed` / `refuted` (Kimi §6; MiniMax §3–4). Keep three ledgers:

- Criterion: `INSPECTION_MATCH`, `INSPECTION_MISMATCH`, `UNVERIFIED_EXECUTION`, `SUPERSEDED_BY_OD`, `NOT_APPLICABLE`, `RESIDUAL`. Preserve all 108 IDs, including inapplicable rows. Do not change the denominator. Wings obligations, if any, are extra rows from its existing PRD, not new features.
- Audit item: `CLAIM_SUPPORTED`, `CLAIM_REFUTED`, or `CLAIM_UNVERIFIED` for the seven findings and two retractions only. A historical finding can be real while the current R-id is superseded.
- Finding: `CODE_DEFECT`, `TEST_DEFICIENCY`, `DOC_GAP`, `EVIDENCE_GAP`, `DECISION_NEEDED`, with every severity. `UNSUPPORTED_USE` stays D12 only.

**Matrix.** One current documentary count. `COMPATIBLE` / `INCOMPATIBLE` / `DEPRECATED` / `UNDETERMINED` is a source disposition. Executed-pass is a separate field and stays unverified if not run. Do not adopt 195/1/7 or 165/3/7. An INCOMPATIBLE row is not a green integration (`REMEDIATION_PRD.md:320`; `plan.md:553`).

**Reject.** MiniMax’s “all 12 lanes” gate and Medium+ remediation filter (`minimax-original.md:54-59`). That drops Low findings from the only downstream path and pre-decides the owner discussion. MiniMax’s `release/v3/` and `ponsFamily/` paths are not locked production roots (`plan.md:167-194`). Bind packages at launch. Slipstream is a deprecation residual, not a full rewrite lane (`REMEDIATION_PRD.md:79`). Do not require a new OD-09; name the owner discussion and stop. Kimi’s bare `CONFIRMED` would collapse criterion truth into audit-item truth (`kimi-original.md:32`).

**Gates.** Report accepted when every R-id and the four vault identities have a row, the matrix has a count or an explicit blocker, concurrency is evidenced or the launch blocker is recorded, and disagreements remain. `UNVERIFIED_EXECUTION` blocks a readiness claim and does not open remediation scope. `INSPECTION_MISMATCH` and `CODE_DEFECT` / `TEST_DEFICIENCY` are discussion inputs, all severities, still not an automatic PRD. Zero findings is not submission permission (`REMEDIATION_PRD.md:162`, `:369`).

**Unresolved.** Whether the owner later wants a separately authorized execution session. That is outside this PRD. Wings PRD detail (Astra §3.3) is an input, not a license to add product scope the wings PRD does not already state.
