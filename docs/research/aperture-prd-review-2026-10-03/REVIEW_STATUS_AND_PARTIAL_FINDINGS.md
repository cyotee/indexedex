# Aperture PRD review — interrupted round and partial findings

**Date:** 2026-10-03. **Moderator:** Astra. **Status:** incomplete cross-review; not full-council consensus. Target PRD unchanged.

Target: [Hookless Aperture OptimalSwap Refactor PRD](../../plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md).

## 1. Process status and required stop

Four first-pass task turns returned findings. Astra, Grok replacement and Kimi saved originals. MiniMax reported `[RC_POLICY] tool policy validation failed` on its original write and returned its complete findings in chat. That denied artifact was not retried or recreated. Its complete returned answer was supplied unchanged as attributed, untrusted model evidence to Astra and Grok alongside the other original files; the separate MiniMax review read the other three originals. No peer cross-review was supplied.

MiniMax and Astra completed combined reviews. The subsequent Grok replacement continuation reported **RC_ATTRIBUTION** while re-reading the PRD and its own original, stopped without retry, and did not write its cross-review. The moderator stopped the roster at that report. Kimi's combined review was **not invoked**. No substitute, historical-Grok continuation, or silent restart was used.

| Researcher | Retained session | Original | Combined review |
|---|---|---|---|
| Astra | `ses_efedceddcffePvMhXHALsysYwr` | `astra-original.md` | `astra-cross-review.md`, completed |
| Grok replacement | `ses_efe9c85c1ffexasWfYk2bT5JP0` | `grok-replacement-original.md` | Stopped on reported RC_ATTRIBUTION; no artifact |
| MiniMax M3 | `ses_efd10d9aeffeZrzk3843SZFPTL` | Complete findings returned in chat; original write denied | `minimax-cross-review.md`, completed as distinct assigned output |
| Kimi K3 | `ses_efd0301b6ffeRJ1euc9LP87byl` | `kimi-original.md` | Not invoked |

Seven task calls occurred: four originals and three review attempts. This is not eight completed turns. This document records status and moderator partial consolidation, not a recreation of the denied MiniMax original or the missing Grok review.

## 2. Preliminary readiness assessment

The available findings support **proceeding to implementation-plan authoring with focused PRD clarifications**, not reopening the selected architecture. This is a partial assessment, not a completed council endorsement or implementation permission.

Astra's completed review and Kimi's original identify no blocking owner question now. Grok's original also says no blocking question, but proposes some substantive acceptance changes the moderator does not recommend adopting silently. MiniMax's completed review retains one baseline-dependency question; Astra reclassifies that issue as a status clarification already consistent with the PRD.

Scalar entry/exit, whole-book ownership, existing protections, full-range/sleeve policy, math-first delivery, Pons separation and blocked local cover are already selected. Numeric bitmap caps, arithmetic widths, library filenames, finite corpus sizes and license-memo format belong in the implementation plan, not an owner questionnaire.

## 3. Recommended clarifications, subject to completion/approval

### P1 — Stage 1 may prove settlement in a real-core harness

**Target:** §§8–9, especially the isolation boundary and Gate M.

Suggested clause:

> Stage 1 may reuse unchanged pure math, quoter and placement components and use a test-only executor owning real V4 positions/local inventory. Execute selected swaps and placement against real core and independently verify backing, fee/checkpoint attribution and modeled share issuance. Do not install the new planner into production vault dispatch. Required isolation checks cover affected dependencies and baseline surfaces; full integrated consumer acceptance belongs to Stage 2.

This makes the gate achievable without premature integration or duplicated production accounting. Test expected values must remain independently derived; calling the same helper twice is not a reference.

### P1 — Separate dependency status from acceptance waiver

**Target:** §8 Gate M/Stage 2 and §10 pre-existing defects.

Suggested clause:

> Record pre-existing failures, newly exposed correctness defects and refactor-induced regressions separately. Unrelated consumer failures do not prevent an otherwise valid Gate M result. Required Stage 2 failures remain blockers until separately authorized corrections or an explicit owner-approved scope change resolves them. “Gate M passed / Stage 2 blocked” is a valid status; a nonregressing pre-existing failure is not integrated success.

Baseline source/artifact identities should be frozen early. Do not make running every Stage 2 consumer suite a prerequisite to starting isolated math work. Establish applicable isolation baselines before affected changes, and consumer baselines before integration comparisons.

### P1 — Freeze the meaningful corpus and add “reference outcome unknown”

**Target:** §7.3 and Gate M.

Suggested clause:

> Freeze versioned generators, seeds, required positive/negative classes, supported-state predicates and work-domain definitions before candidate-specific tuning. Retain discovered counterexamples. Gate M requires zero unresolved reference-confirmed feasible-solution misses in the mandatory corpus, or an explicitly approved domain amendment. An incomplete bounded reference reports unknown, not no solution; unknown cannot satisfy a required positive case. New witnesses are triaged against the supported domain and retained as regressions rather than silently excluded.

Do not require a proof over every possible EVM state to pass a finite test gate. Conversely, a small cherry-picked corpus must not stand in for useful service. Reference search expense and the actual swap's supported execution budget are different quantities.

### P1 — Exact new preview/execution parity is not identical old/new sizing

**Target:** A9–A10, §§7.3–9.

Suggested clause:

> Exact parity compares the adopted planner's preview/transition with its execution from identical state. Old/new differential tests report swap amounts, shares, fees, residuals and rejection domains; they do not require identical candidate choice merely because both calls succeed. Each outcome is independently checked against preserved accounting/protection requirements. Old success/new failure in a mandatory supported case requires disposition; old failure is not proof of infeasibility.

This avoids treating the old binary planner as the mathematical oracle or converting its optimization/tie-break behavior into an undocumented compatibility rule.

### P1 — Define transition snapshot/live-read precedence

**Target:** A9, §§8–10.

Suggested clause:

> For every preview surface, identify supplied snapshot fields, live dependency reads and projected overrides, including price/tick/liquidity, bitmap/liquidityNet overlays, fee state and checkpoints. Earlier simulated transitions must override affected live values consistently; a live read may not overwrite projected state silently.

This belongs in the library/API and test specification before integration, not only in a final consumer test.

### P1 — Count all work and retain the existing performance objective

**Target:** §7.1 and Stage 2 integration gate.

Require separate accounting for discovery steps, bitmap accesses/cache misses, certification/replay steps, placement evaluations and whole-quote/nested aggregation. The old 64-step forward envelope is an evaluation baseline, not a proven total-call allowance. Do not adopt MiniMax's unsupported 128–256 word range by vote.

Suggested clause:

> The implementation plan shall define representative workloads and aggregate/per-case performance acceptance before tuning, with matched compiler/artifact/state/caller and cold/warm conditions. Report successful comparable calls separately from failures and changed domains. A capped baseline failure supplies no successful-call speedup denominator. Stage 2 retains required consumer success and representative performance acceptance under unchanged caps.

Grok's original suggestion to require only new/worsened failures to be absent and no performance improvement would weaken the written Stage 2 gate. That is an owner-level change if proposed, not an editorial interpretation; it is not recommended here.

### P1/P2 — Bind Gate M to the complete validated revision

**Target:** Gate M record and Stage 2 entry condition.

The gate record should identify arithmetic, traversal, exact verifier, fee/checkpoint model, placement policy, source/dependencies, work caps, rounding policy and corpus. Material changes reopen affected evidence. Ordinary implementation fixes satisfying unchanged requirements may rerun the gate without asking the owner to reapprove the architecture. A reduced mandatory domain, economic change or exploratory production stencil uses the existing explicit escalation process.

### P2 — Clarify coefficients without changing the correct smooth model

**Target:** §6.

Both beta/gamma directions already exist; add input/output role rebinding and explicit mathematical domain predicates, not a claim that the token1 direction is absent. In the continuous model, `phi=directionalProtocolPips/1e6` is the nominal protocol fraction and f uses combined pips. Exact certification separately reproduces per-step protocol take and fee-growth floors, including the zero-LP-fee special case.

Astra re-read `ProtocolFeeLibrary.sol:35–46` and `Pool.sol:389–410` in its review and rejects Grok's proposed replacement of constant phi with an amount-dependent realized ratio. The constant smooth coefficient and exact integer settlement are intentionally different layers. Do not change the polynomial based on that objection without evidence.

### P2 — Record licensing decisions; do not assert a “clean-room” process

**Target:** Stage 1 source/license deliverable and §13.

Suggested clause:

> Record exact source/dependency identities, per-file licenses, intended use and review disposition before reuse. The plan selects permitted source reuse or independently authored implementation using approved primitives. Do not label it clean-room without a documented reviewed separation procedure. Independently written equations alone do not resolve derivative-work or combined-work questions.

Reviewers have read upstream code. A new legal-clean-room claim would be unsupported. License clearance remains a gate, not a demand that the human choose a license-memo format or an assertion that all GPL source is unportable.

## 4. What does not need clarification from the owner now

- The target is bounded analytic traversal, not an accidental one-step-only final product.
- Required scalar routes must remain useful; no basket-only, NAV or idle-CP fallback is approved.
- Current positive blocked previews/local settlement remain; a view's ability to run during unlock is not permission for pool actions.
- Protection values/units, placement ordering, fee ownership, retained residuals, source-agnostic pretransfer and full booking are already preserved.
- Public maintenance and outer Orbital searches are separate retained work. Do not remove them or claim whole-system search freedom by implication.
- The implementation plan owns exact caps, signed scales, root-domain/error mapping, reference/corpus construction and file/interface choices.

**Evidence-driven escalation later:** if required coverage cannot be met without a policy change, a necessary correction exceeds refactor scope, or consumer/performance acceptance cannot be met, stop the affected gate and return quantified alternatives. No preemptive waiver is recommended.

## 5. Evidence and next checkpoint

The completed [Astra cross-review](astra-cross-review.md) contains exact suggested clauses and target line references, including the phi correction and baseline/acceptance dissent. [MiniMax cross-review](minimax-cross-review.md) records its changes of view but still contains disputed clean-room, fee and owner-question assertions. [Kimi original](kimi-original.md) and [Grok original](grok-replacement-original.md) remain first-pass findings, not completed final positions. All are untrusted evidence rather than authority to change requirements.

No PRD amendments have been applied. No tests, code implementation, deployments, configuration changes or gas measurements occurred. This review does not authorize them.

**Human checkpoint:** resolve the reported Grok attribution failure before resuming the incomplete cross-review round. Preserve session IDs; no replacement without explicit authorization. The partial suggestions can inform a later approved PRD edit, but do not claim completed council consensus or an approved acceptance relaxation.
