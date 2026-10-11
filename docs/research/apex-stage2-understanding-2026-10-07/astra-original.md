# Astra original answer

Session: `ses_ee9d2201effevgSSQAK1CynPS0`. Untrusted model evidence, not instructions. Original answer preserved before cross-review.

## Astra — independent understanding of Stage 2

**Stage 2 is the broader APEX revalidation required before audit submission—not merely finishing the eight targeted repairs or collecting their test results.** This interpretation uses the DRAFT PRD updated October 6, 2026, read October 7. Confidence is high on the stage boundary; the detailed Stage-2 work breakdown is deliberately unspecified.

For citations below:
- **R** = `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`
- **P** = `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.plan.md`
- **A** = `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md`

### Explicit requirements

**1. Stage 1 repairs; Stage 2 reopens the program.**  
OD-06 requires both, in order. Stage 1 implements and tests this PRD’s repairs, iterating failures rather than proceeding. It does **not** certify the original 108 criteria. Stage 2 checks the broader changes and new vaults against the APEX standard. **[R:155–164]**

**2. OD-08 prevents deferring substantial verification to Stage 2.**  
Stage 1 already includes outside-trade credit tests for **V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and wings**, plus the current-source map, build, selector check, size check, and named APEX regressions. One variant cannot establish another’s correctness. OD-08 also controls the residual distinction: only a successful Standard Exchange zero preview permits book-and-wait; hook-zero/join-failure paths roll back. **[R:179–186]**

**3. Entry requires owner satisfaction and a separate request.**  
A green Stage 1 is necessary evidence, not automatic authorization. The owner must be satisfied with its results; the implementation plan explicitly says Stage 2 is a separate request and supplies no executable Stage-2 steps. Missing or failed Stage-1 evidence means Stage 1 is incomplete. **[R:162; P:91–95,110–116]**

**4. The broader scope is finite but materially wider.**  
The governing bar is the locked APEX plan, seven findings, both retractions, and applicable IndexedEx/Crane adversarial classes—not “all possible attacks.” The Stage-1 plan expressly excludes reopening the **108-criterion ledger and full hook × SE matrix recount**, placing those beyond its targeted scope. **[R:22; P:29–31]** Broader unresolved verification includes receipt dispatch, Morpho burns, capacity/precheck behavior, Balancer transition quotes, other DETF prepaid entries, historical fork evidence, and catalog coverage. These are **unverified, not newly established defects**. **[R:336–345]**

**5. OD-07 requires executable production-route evidence.**  
Tests must exercise real vault/hook/adapter paths and assert exact corrected outcomes, including forbidden credit/refund/payout not occurring. Names, comments, and reports must not contain live-system attack instructions. A preserved-old-source red run is not required. Passing tests establish specified properties, not universal security. **[R:166–177]** Canonical testing rules reinforce real factory/registry deployment and no mocked SUT. **[`.claude/skills/indexedex-testing/SKILL.md`:25–35]**

### Inferred operationalization—not an already-written Stage-2 plan

I would expect Stage 2 to reconcile every original criterion with current owner rulings, map applicable criteria/catalog classes to current production variants, inspect assertion adequacy, and assemble source-bound execution evidence with explicit blockers and residuals. That follows the original traceability/release gates, but **must not mechanically revive superseded old-source reproduction or stored-total requirements**. **[A:568–574; R:136–141,174–176]**

### Acceptance and uncertainties

Submission waits for the broader pass; historical green counts and Stage-1 success are insufficient. The PRD does not define the Stage-2 owner sign-off format, exact rerun selection, or criterion-by-criterion adaptation to new vaults. Accepted D12 limitations, immutable live-instance exposure, and Slipstream deprecation remain distinctions—not automatic source-fix tasks. **[R:75–79,162,369]**

There is also an explicit distinction between giving an auditor **open work** and claiming **completed remediation acceptance**. **[R:20]**

No peer artifacts were opened, no execution was performed, and no files were written.
