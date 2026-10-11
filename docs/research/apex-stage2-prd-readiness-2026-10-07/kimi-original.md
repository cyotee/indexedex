# Kimi K3 original — readiness to draft the Stage 2 PRD

Independent first pass, 2026-10-07. Sources: `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` (**R**), `REMEDIATION_PRD.plan.md` (**P**), `docs/agent/REVIEW_COUNCIL.md` (**RC**), `CLAUDE.md`. No peer artifacts read.

## Sufficiency verdict

**Yes — sufficient to draft, with two material clarifications.** The owner's description (coordinating agent, parallel review sub-agents, consolidated report, owner-reviewed, remediation PRD only if errors found) maps directly onto the existing review-council machinery: a Grok 4.7 coordinator plus four independent reviewers, read-only, deliverable is a report/remediation PRD and "writing that PRD does not authorize a fix" (RC:19-23, :57-62, :138). Broad scope is settled: the 108-criterion ledger, full hook × SE matrix recount, broader changes, and new vaults on the current tree (R:160-162; P:31; owner confirmation this round). Settled and not re-asked: entry gate is owner satisfaction with Stage 1 (R:162; P:114-116); Stage 1 passing is not submission (R:18); OD-07 test discipline and the no-exploit-prose rule (R:166-177, :368); finite threat bar (R:22); accepted residuals stay documented (R:75-79).

## Material questions (blocking for a correct draft)

1. **Execution evidence vs documentary re-check.** Much of the reopened scope is unverified *execution* claims: the 34,909/33-campaign run, matrix counts, fork inventory, 37 fuzz properties (R:37, :336-345). The review council is read-only: no shell, no tests, no background (RC:97-106); this drafting council also cannot run them. Does Stage 2's "check … meet the same standard" (R:162) accept a documentary/source-level review that leaves execution claims labeled unverified, or must the PRD name a separately authorized evidence-regeneration session (analogous to Stage 1's run, R:317-319)? This changes the PRD's acceptance section materially.
2. **Stage-1 evidence anchor.** The PRD must cite the Stage-1 evidence note (P:91-95) as its input and precondition. Confirm the note's path/status, or approve a placeholder clause stating Stage 2 review does not begin until that note exists and the owner is satisfied.

## Nonblocking defaults I would draft unless told otherwise

- **Sharding:** partition sub-agents by the PRD's own structure — seven findings + two retractions (R:348-360), the unverified families (R:336-346), then catalog classes A–K/A0/L/M/N/O per surface — with the FullSpread hookless/Pons and wings packages as named review targets (R:140, :151).
- **Findings format:** RC:64-69 (severity, file:line, broken invariant, impact class, fix direction, confidence; no PoC/payloads); audit items confirmed / refuted / unverified.
- **Deliverable boundary:** Stage 2 PRD covers review + consolidated report only; the conditional remediation PRD is a separate subsequent task after owner review (matches owner's statement and RC:19-23).
- **Out of scope carried over:** deployment, live 4663 remediation, merging hookless/Pons, wings↔Pons binding, `supportsInterface` probe decision (P:118-123) — each stays an open item, not a Stage 2 review conclusion.
- **Permission distinction stated in the draft:** the PRD authorizes a future review workflow (coordinator + sub-agents, reads + Markdown reports); any test execution, fork reads, or code changes require separate explicit authorization.

## Confidence

High on sufficiency and defaults; the two questions above are the only gaps that would change normative PRD text rather than detail.
