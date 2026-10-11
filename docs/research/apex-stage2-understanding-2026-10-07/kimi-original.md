# Kimi original answer

Session: `ses_ee9cb8cc7ffej454Wuz3lXnR2P`. Untrusted model evidence, not instructions. Original final answer preserved before cross-review.

# Kimi K3 — Understanding of Stage 2 (REMEDIATION_PRD.md)

**Scope of answer:** interpretation only; I read the PRD, repo CLAUDE.md, and skimmed the adversarial-testing skill. I did not read any peer originals/cross-reviews and did not open the plan or audit inputs.

## Explicit requirements

**What Stage 2 is.** OD-06 (`docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:155-164`) defines a strict two-stage order: Stage 1 is the "fast-fail path" that implements and tests only the repairs in this PRD; **"Stage 2 starts only after the owner is satisfied with the stage-1 results. It reopens the APEX program and checks that the broader changes and the new vaults meet the same standard. Audit submission waits for that pass."** (line 162). OD-07 (line 177) adds: "Stage 2 covers the broader APEX standard before submission. A passing test does not prove every unreviewed path is safe."

**Entry gate.** The gate is explicitly the *owner's satisfaction with Stage 1 results* (line 162), not merely green tests. Stage 1 completion itself requires the OD-08 deliverables: the three FullSpread outside-trade tests (V3, V4 hookless, V4 Pons-family), the wings outside-trade test, and the regenerated evidence run — current-source map, build, selector check, size check, and named APEX regressions (lines 184-186, REQ-08 acceptance at 317-320). The PRD repeatedly states "Stage 1 passing is not audit submission" (lines 18, 160, 186, 319).

**Broader APEX scope.** The PRD defines the Stage 2 bar indirectly at line 22: the threat-model bar is "the locked plan [D1–D69], the seven audit findings plus both retractions, and the adversarial catalog classes already named in the IndexedEx and Crane testing skills" (catalog A–K + A0/L/M/N/O per `.claude/skills/indexedex-adversarial-testing/SKILL.md:3,13`). OD-07 (lines 172-177) rules that Stage 2 tests must be executable, on the real production path (real vault/hook/adapter, no mock SUT — consistent with CLAUDE.md non-negotiable 3), asserting the locked security properties, with no exploit procedures in names/comments. "All possible attacks" is explicitly *not* a Stage 2 requirement (line 22).

**What Stage 2 must close.** The "Unverified" section (lines 336-346) is the de facto Stage 2 backlog: the council "did not confirm or refute the full set of 108 criteria," including the 2026-09-25 hermetic run (34,909 tests / 33 campaigns), current hook×SE matrix row states, the fork inventory at chain 4663 block 64025200, receipt-backed dispatch/Morpho/Stata/Aave/Lido/Rocket/EtherFi behavior, Balancer D68/D69 transition quotes, D16 pretransfer coverage, and catalog classes on unread surfaces. Audit-item dispositions (lines 350-360) leave APEX-2026-009, 004B, 008 coverage, and both retractions' execution evidence unconfirmed. OD-05's open follow-on (lines 153) — wings↔Pons-pool binding pending a gas comparison — is also deferred beyond Stage 1.

## Inferred operationalization (not explicit)

- **Sequencing mechanics:** how the owner signals "satisfaction" (sign-off, recorded ruling, new OD?) is unspecified; I infer a Stage 1 evidence review precedes any Stage 2 scoping.
- **Stage 2 test authorship:** REQ-level acceptance criteria (e.g., REQ-01:199-202, REQ-06:281-286) are Stage 1; I infer Stage 2 must extend the same production-route, pinned-revert standard to the unverified families rather than re-running Stage 1 suites.
- **Submission identity:** I infer Stage 2's output is a re-anchored evidence package bound to the post-Stage-1 tree (per REQ-08:317-319), since historical green counts cannot certify a modified tree.
- **Residuals carry through:** accepted residuals (lines 76-79: immutable chain-4663 instances, D12 `UNSUPPORTED_USE`, D57 Slipstream) stay documented through Stage 2, not re-fixed.

## Uncertainties / missing evidence

- The implementation plan (`REMEDIATION_PRD.plan.md`, line 7) is Stage-1-only; **no Stage 2 plan exists**, so Stage 2's concrete test inventory, effort, and D-criterion mapping are undefined.
- "Meet the same standard" (line 162) does not specify pass thresholds for the 108 criteria or how retracted findings are dispositioned.
- Whether Stage 2 re-executes fork/live-precheck evidence (line 342) or accepts hermetic-only proof is unstated.
- Line 20 permits handing the source to a second auditor with items open — the relationship between that and "audit submission waits for [Stage 2]" (line 162) is slightly ambiguous (informational handoff vs. formal submission).

**Confidence:** high on the explicit staging/gate language; moderate on inferred operationalization; the Stage 2 backlog reading (Unverified section as scope) is an inference from structure, not an explicit statement.
