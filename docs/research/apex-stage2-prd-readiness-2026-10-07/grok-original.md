# Grok — Stage 2 PRD readiness

Independent first pass. No peer artifacts. No Stage 2 PRD drafted. `apply_patch` was not available; this file was written with the allowed document writer.

## Sufficiency

Yes. Enough to draft a review-coordination PRD, not a remediation PRD and not an implementation plan. Not re-asked: broad original APEX acceptance-program scope, the current tree, the new vaults, and the Stage 1 owner-satisfaction gate (`docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:160-162`; `REMEDIATION_PRD.plan.md:7`, `:31`).

The new shape is also settled: a future coordinating agent spawns parallel sub-agents to review code and gather one report. The owner then reviews that report with an agent and may request a remediation PRD only if errors are found. No autonomous fixes.

This research session cannot spawn those agents or run tests. Writing the PRD would not grant that permission (`docs/agent/REVIEW_COUNCIL.md:96-106`).

## Defaults, unless corrected

1. **Artifact.** `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE2_REVIEW_PRD.md`: partition, report schema, and stop rules. No code edits.

2. **Protocol.** A later `/review-council` coordinator uses its existing `task` allowlist to the four named reviewers (`REVIEW_COUNCIL.md:24-31`, `:102`). It does not auto-write `REMEDIATION_PRD.md`. That is a program-specific override of the council default (`:16-23`).

3. **Review, not execution.** Reviewers read current source and cited tests against the locked acceptance criteria, OD-01–OD-08, and the named adversarial catalog. They do not run forge, shell, or broadcasts. An unrun proof is **unverified**, not a confirmed defect (`REMEDIATION_PRD.md:22`, `:336-346`). The report does not close OD-07’s executable-test bar (`:166-177`) and does not authorize audit submission (`:162`).

4. **Error.** A later remediation discussion is triggered only by a demonstrated mismatch between current source or a cited test and a locked property, including a mis-aimed test. Accepted residuals and undecided items are separate and do not by themselves require a remediation PRD (`:75-79`, `:153`, `:203`, `:362-369`). Open Stage 1 items stay Stage 1.

5. **Report.** Criterion ID, file:line, disposition, impact class, fix direction. No exploit procedure, payload, or attack parameter (`:175`; `REVIEW_COUNCIL.md:65-69`). No submission verdict.

6. **Partition.** Bounded R-groups plus the current FullSpread hookless, Pons-family, and wings trees. One variant does not prove another (`REMEDIATION_PRD.md:185`).

## Essential question

One. If “error” also includes every criterion that was not re-executed, the report always forces a remediation discussion and the done-condition changes. The default treats non-execution as unverified, not as an error. Confirm or reject that default. No other scope or gate question.

**Confidence:** high that the review PRD can be drafted on these defaults. The execution-versus-error point is the only structural unknown.
