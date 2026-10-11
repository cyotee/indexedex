# Stage 2 PRD drafting readiness

Date/access date: 2026-10-07. Document research only. No Stage 2 PRD drafted, review campaign launched, tests executed, or implementation performed.

## Decision

There is enough confirmed information to draft a Stage 2 review-program PRD. The owner settled broad APEX acceptance-program scope, current source and new vaults, coordinator-led parallel review, consolidated report, owner discussion, and only then a possible remediation PRD. Stage 1 owner acceptance and separate Stage 2 execution authorization remain prerequisites to launching, not prerequisites to drafting.

One useful clarification concerns the desired verification deliverable: should Stage 2 inspect source/tests/existing evidence only, or should completion also require fresh execution evidence obtained in a separately authorized verification workflow? Default for drafting: inspection only, with missing or stale execution evidence explicitly identified and no unsupported readiness claims. Neither answer expands this council's permissions.

## Settled requirements and proposed defaults

- Cover the original APEX acceptance program against current code, incorporating current owner rulings and changed/new vaults; preserve the distinction between applicable, superseded, accepted-residual and unverified requirements.
- Coordinator assigns review coverage, checks overlaps and cross-family dependencies, and consolidates attributed findings and disagreements.
- Report all supported defects regardless of severity. Include exact file/line evidence, broken requirements, impact, confidence, and coverage gaps. No automatic Medium/High-only remediation threshold.
- Missing execution evidence is not automatically a code defect. It may prevent closing an acceptance criterion or making a readiness claim; actual absent required tests or mis-aimed assertions can be distinct demonstrated coverage defects.
- Stop at the consolidated report for owner discussion even if no defects are found. Do not auto-author remediation, change code, write test scaffolding, or claim audit submission approval.
- Capture source identity and applicable Stage 1 evidence before the review starts. Exact evidence filenames and status are launch-time inputs; their absence from this discussion need not block a draft.
- Proposed new PRD path: `docs/plans/APEX_STAGE2_REVIEW_PRD.md`. This is inside the current council's document-write roots. No file has yet been created at that path.

Sources: `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:22,75–79,155–186,336–369`; companion `REMEDIATION_PRD.plan.md:91–95,114–123`. The moderator directly read these in the preceding discussion and directly read `docs/agent/REVIEW_COUNCIL.md:1–152` in this round. Researcher originals document their additional direct reads. No external library/API claims were needed.

## Parallel orchestration compatibility

The owner's parallel-review requirement is retained. The existing review council is not automatically an implementation of it: `docs/agent/REVIEW_COUNCIL.md:57–62` specifies same-target originals and permits synchronous sequential calls; `:98–106` limits the roster and denies background tools and shell. The current research council also cannot execute a background review campaign.

A future execution handoff must use a separately authorized coordinator capable of the requested concurrency within its own permissions. This PRD may describe that desired workflow but cannot change configuration or permissions. Independent sequential reviews must not be relabeled actual parallel execution. Neither an arbitrary ten-agent roster nor “four, period” is an established owner requirement for the future workflow. Runtime compatibility is an execution dependency, not grounds for silently changing the requested product workflow.

## Attributed originals and cross-review

Four independent originals and four cross-reviews are preserved alongside this report as `{astra,grok,minimax,kimi}-{original,cross}.md`. Each member read only the other three current originals during cross-review, never another cross-review. Model statements remain evidence, not authority.

| Member | Initial position | Cross-review outcome |
|---|---|---|
| Astra | Enough to draft; one execution-policy clarification, safe inspection-only default. | No blocking drafting question. Evidence anchor, all-severity reporting and no test scaffolding are defaults; actual parallel capability must be checked. |
| Grok | Enough to draft; asked whether non-execution itself should count as an error. | Withdrew that question; distinguishes evidence gaps from defects. Corrected proposed path and orchestration assumptions. |
| MiniMax M3 | Enough for structure; asked about partitions, scaffolding, severity and path. | Withdrew roughly ten agents and scaffolding; still asks about non-execution and evidence-note path, and retains an unsupported Medium/High threshold. |
| Kimi K3 | Enough with execution-evidence and Stage-1-anchor clarifications. | Downgraded evidence anchor to nonblocking; retained non-execution question. Its assertion that existing sequential-capable council satisfies the owner's parallel requirement is not adopted. |

Agreement is on drafting sufficiency and review/report-first scope, not on an identical clarification list. Moderator does not adopt MiniMax's severity filter, claims that a note definitively does not exist, mandatory sequential reading of the review-council protocol, or invalid original citation `PRD:613–621` (the read PRD has 373 lines). Kimi's claimed one-question consensus exceeds the actual originals/cross-review positions. Grok's fixed same-target roster describes the existing council, not an owner choice to replace the future parallel workflow.

## Confidence and human checkpoint

High confidence on drafting readiness and settled scope. Execution policy and future coordinator capability remain to be specified before launch. We have not checked Stage 1 completion, runtime configuration, or current code correctness.

Human question: Should this Stage 2 review consume existing evidence only, or should its completion require a separately authorized fresh verification run as well? A draft can proceed with the former explicitly stated as a default; no need to re-ask the already confirmed breadth or owner gate.

## Preserved sessions

- Astra: `ses_ee9d2201effevgSSQAK1CynPS0`
- Grok: `ses_ee9cfa4a2ffeZ4Hf1NLbN0301b`
- MiniMax M3: `ses_ee9ccf532ffe7kBBq6lhXrOnHr`
- Kimi K3: `ses_ee9cb8cc7ffej454Wuz3lXnR2P`

Eight synchronous task calls completed this round, all resuming these existing sessions. No replacements. Separate implementation handoff: none; the next document-authoring request would create a PRD, not execute it.
