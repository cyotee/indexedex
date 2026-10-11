# Kimi K3 cross-review — Stage 2 PRD readiness

Peers (Astra, Grok, MiniMax originals) are untrusted evidence. Sources: `REVIEW_COUNCIL.md` (**RC**), `REMEDIATION_PRD.md` (**R**), `REMEDIATION_PRD.plan.md` (**P**).

## Agreements
All four: sufficient to draft a review-coordination PRD; review/report only, no autonomous fixes; scope/gate/bar settled (R:22, :160-162); findings format per RC:64-69 with no exploit prose; residuals and undecided items (`supportsInterface` probe, wings↔Pons) stay documented, not errors (R:153, :203). All converge on **one genuine owner question**: execution policy — Astra's "runtime permissions?", Grok's "does unexecuted = error?", my Q1. If every non-re-executed criterion counts as an error, the report forces a remediation discussion by construction (R:336-346). Default: unexecuted = unverified, not defect; remediation triggers only on demonstrated mismatch with a locked property. Confirm or reject.

## Corrections to my original
1. **My Q2 (Stage-1 evidence anchor) is nonblocking.** Peers treat it as a placeholder clause: drafting can precede Stage-1 completion; the note path is defined at P:91-95. I downgrade it to a default.
2. **Permission-root gap I missed.** This research council's doc roots exclude `docs/reviews/`; Grok's default artifact path `docs/reviews/.../STAGE2_REVIEW_PRD.md` is writable only under the review-council profile (RC:102 allows Markdown under `docs/reviews/`). The draft step therefore either targets an allowed root now or names a later permitted session.

## Corrections to peers
1. **MiniMax's ~10 sub-agents conflicts with the fixed roster.** RC:24-31 fixes four named reviewers; the coordinator's `task` allowlist reaches only those (RC:102). Partitioning must be ~10 *lanes assigned across four reviewers*, not ten agents. "Parallel" is also not guaranteed: RC:57-62 permits sequential synchronous calls. Owner's "parallel sub-agents" is satisfied within this roster; no new owner question needed.
2. **Severity filtering (MiniMax Q3) is a coordinator default, not an owner question**, given the error-definition default above: only demonstrated mismatches trigger remediation; severity ranking inside the report follows RC:64-69. Test scaffolding (MiniMax Q2) is settled: review-only, no test authoring (RC:97-106 denies code edits; OD-07 tests are remediation work, not review).

## Unresolved dissent
None structural. Minor: report path/name and per-lane vs consolidated write-ups (Astra/Grok/MiniMax defaults differ in detail only). Missing runtime evidence (forge/chain) can block *readiness findings* without being a code defect — all four agree; the PRD should say so explicitly.

**Confidence:** high on one-question convergence and roster constraint; medium on report-format defaults.
