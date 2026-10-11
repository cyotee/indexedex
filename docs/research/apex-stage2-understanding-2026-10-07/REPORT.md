# Council interpretation: APEX readiness Stage 2

Date/access date: 2026-10-07. Research and document interpretation only. No source implementation, tests, builds, chain queries, or deployments performed. This report does not authorize implementation or attest to current readiness.

## Sources and scope

- R: `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`, DRAFT dated 2026-10-03, updated 2026-10-06, OD-01–OD-08.
- P: `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.plan.md`, dated 2026-10-06, Stage 1 only.
- Moderator directly read `CLAUDE.md`, R, P, and relevant portions of `.claude/skills/indexedex-adversarial-testing/SKILL.md`. Researchers' additional source reads are attributed in their originals. No external API claims or dependency-version validation was needed for this interpretation.

Question: What does Stage 2 mean? Assumption: interpret the current owner decisions, rather than determine whether Stage 1 is complete or execute a fresh security audit.

## Consolidated understanding

**Stage 1 asks whether the specifically identified repairs are correct. Stage 2 asks whether the broader current APEX implementation, including changed and new vaults, meets the APEX security and evidence standard well enough to claim completed remediation for submission.**

### Explicit requirements

1. Both stages happen in order. Stage 2 begins only after owner satisfaction with Stage 1 results and is a separate request. A green Stage 1 is not authorization to submit. R:155–164; P:110–116.
2. Stage 1 already includes REQ-01–08, outside-trade tests for V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread and wings, and the current-source map/build/selector/size/named-regression evidence run. None can be deferred to Stage 2 to call Stage 1 complete. R:179–186,316–321; P:19–31,85–95.
3. Stage 2 reopens the APEX program and checks broader changes and new vaults against the same standard. That standard is the locked plan, seven findings, both retractions, and applicable named adversarial classes—not every imaginable attack. R:22,162,177.
4. Tests must exercise real production paths and assert the locked outcomes, including prohibited credit/refund/payout not occurring. Passing tests are not proof of every unreviewed path. A red run on preserved old source is not required. R:166–177.
5. Accepted D12 limitations, immutable chain-4663 instances, and Slipstream deprecation remain documented distinctions, not automatically reopened source defects. No deployment/migration authority follows. R:75–79,362–369.

### Moderator inference: the intended broader review

The strongest reading is a program-wide reconciliation of the 108-criterion ledger, current hook × SE matrix and unverified evidence against the post-Stage-1 tree, applying current owner rulings rather than mechanically restoring superseded requirements. P:31 explicitly separates the ledger/matrix reopening from Stage 1; R:336–360 identifies unverified families and audit dispositions. This is stronger than a review limited only to the new FullSpread split and wings.

That does **not** establish that every historical test must be rerun unchanged, that all unverified entries are defects, or that every deferred design question becomes Stage 2 work. A useful future work breakdown would map applicable requirements to current variants, tests and source-bound evidence; document accepted residuals and superseded/nonapplicable requirements; and identify remaining blockers. This is an interpretation/recommendation, not an approved Stage 2 implementation plan.

Stage 1 evidence remains an input and may need refreshed execution if subsequent changes invalidate it. Its being due in Stage 1 does not prohibit later reruns.

## Council attribution and cross-review

Original final answers are preserved in the four adjacent `*-original.md` files, without preparatory drafting commentary. Those answers are model evidence, not source authority.

| Researcher | Original position | Cross-review result |
|---|---|---|
| Astra | Broad APEX revalidation; criterion reconciliation is inferred, not an enumerated Stage 2 work plan. | Retained broad reading; rejected treating Stage 1 evidence as excluded from Stage 2; cautioned against asserting repository-wide absence of a Stage 2 plan. |
| Grok | Same gate and sequencing; entertained a narrower changed/new-vault reading and distinguished inferred ledger scope from explicit instructions. | Corrected its “explicitly not Stage 2” list: evidence is due earlier but reusable; undecided items need later rulings. Kept exact breadth unresolved. |
| MiniMax M3 | Initially presented 108 criteria and full matrix recount as explicit Stage 2 scope. | Withdrew that certainty; agreed detailed operational scope is inferred. Still overstates evidence for absence of an authored Stage 2 plan and speculates wings/Pons will arise; moderator does not adopt those claims. |
| Kimi K3 | Initially called the unverified section the de facto must-close backlog. | Reclassified that backlog as inference; agreed Stage 1 evidence can feed Stage 2 and undecided items are not permanently excluded. Its continued no-Stage-2-PRD/plan-pair assertion is not established by the files read. |

All four agree on ordering, owner gate, broader revalidation, production-route test discipline, and no submission entitlement from Stage 1 alone. No unanimous detailed Stage 2 checklist was established. Grok retains a possible narrower reading; Astra considers that reading too weak given “reopens the APEX program” and P:31. Moderator favors the broader interpretation while leaving the exact execution inventory for owner scoping.

Cross-review corrections must themselves be checked: MiniMax misattributes an implementation-test-dod point to Astra and describes a narrower scope as established; neither is adopted. The PRD has a substantive acceptance standard even though it does not enumerate Stage 2 steps. Kimi and MiniMax's repository-wide nonexistence claims remain unsupported. The safe statement is that **the linked implementation plan deliberately omits Stage 2 steps** (P:116).

R:20 allows source delivery to an auditor with open work, explicitly distinguished from completed remediation acceptance. Read together with R:162, this does not permit describing a Stage-1-only result as completed readiness. Some researchers flagged terminology ambiguity; the moderator adopts that explicit distinction.

## Evidence gaps and confidence

- High confidence: stage boundary, owner gate, OD-08 allocation, production-route requirements and submission dependency.
- Moderate confidence: concrete Stage 2 work inventory and ledger/matrix reconciliation mechanics.
- Unresolved: exact reruns/evidence reuse, adaptation of old criteria to new vaults, fork/precheck re-execution and owner sign-off format.
- Not assessed: current implementation correctness, Stage 1 completion, historical passing counts, current matrix disposition, or audit readiness.
- Source review does not establish absence of any other Stage 2 document elsewhere in the repository.

## Session continuity

Four independent first passes, then one combined cross-review per original session, each reading only the other three originals. Eight synchronous task calls completed; no replacements.

| Researcher | Session |
|---|---|
| Astra | `ses_ee9d2201effevgSSQAK1CynPS0` |
| Grok | `ses_ee9cfa4a2ffeZ4Hf1NLbN0301b` |
| MiniMax M3 | `ses_ee9ccf532ffe7kBBq6lhXrOnHr` |
| Kimi K3 | `ses_ee9cb8cc7ffej454Wuz3lXnR2P` |

## Human checkpoint and separate implementation handoff

Resolved by owner clarification below. This research neither establishes Stage 1 completion nor authorizes Stage 2 execution or implementation.

## Owner clarification — Stage 2 review orchestration

Recorded 2026-10-07, following the council interpretation. The owner confirmed the broader interpretation and stated:

> Yes, your understanding is correct. Stage 2 should be a coordinating agent spawing several sub-agents to review the code in parallel and gather the results into a report that I can review with an agent to write a remeidation PRD if any errors are found.

Stage 2 is therefore a coordinated, parallel code-review program over the broader APEX acceptance scope, not an immediate implementation campaign:

1. After the existing Stage-1 owner gate and separate authorization, a coordinating agent assigns review work to several sub-agents in parallel.
2. The reviewers assess current code against the applicable original APEX requirements and current owner rulings, including changed and new vaults.
3. The coordinator gathers the findings into a consolidated report for the owner.
4. The owner reviews that report with an agent. If errors are found, that subsequent review informs a remediation PRD.
5. Writing the report or remediation PRD does not authorize implementing fixes or submitting the source as completed remediation.

Recommended reporting structure (moderator recommendation, not additional owner rulings): explicit coverage mapping; source-bound findings with file/line evidence and the violated requirement; reviewer attribution; duplicates and conflicting interpretations reconciled without suppressing dissent; accepted residuals separated from defects; and unreviewed or unverified areas identified. Exact reviewer assignments, runtime/tool permissions, and execution-evidence requirements remain to be specified in a separately requested review plan.

This clarification resolves the intended breadth and report-first workflow. No Stage 2 reviewers were launched in response to it. The present council's synchronous, fixed-roster research protocol is distinct from the future parallel code-review workflow and is not changed by recording that design.
