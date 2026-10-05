# Astra — Aperture PRD requirements cross-review

**2026-10-03.** Read Grok replacement and Kimi's complete originals, together with the complete MiniMax returned original supplied in chat. MiniMax's quoted write denial is evidence about its session, not a guard event in this session. I did not attempt to read, recreate or retry its denied output. No peer reviews/syntheses read; all originals and the target PRD remain unchanged. Research only; no execution, implementation or consensus claim.

**Target T:** `docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md` (334 lines).

## 1. Final assessment and correction to my original

**Ready for implementation-plan authoring, with a short acceptance/isolation addendum; not execution authorization. Blocking owner questions now: none.**

I revise my original classification of the baseline-defect question. Whether to record **Gate M passed / Stage 2 blocked** is chiefly a dependency-status clarification already consistent with T:187–223, not an undecided economic choice. My recommended outcome remains: permit independently completed Stage 1; do not declare Stage 2 complete without its mandatory success criteria. A later request to waive those criteria or expand repair scope would require an owner decision supported by evidence.

I also narrow my original suggestion to inventory every baseline failure “before Stage 1 implementation.” It must not force the full Stage 2 consumer suite into a prerequisite for isolated math development. Freeze source/artifact identities early; collect applicable isolation baselines before changing corresponding dependencies, and establish consumer baselines before integration/benchmark comparisons.

## 2. Attributed review

| Researcher | Agreement | Correction or dissent |
|---|---|---|
| **Grok replacement** | Stage 1 can validate actual core settlement in a harness; separate work counters; preserve maintenance; no routine widths/filenames questions for owner. | Its proposed Stage 2 “only new/worsened failures” rule and “gas reduction not required” delete substantive acceptance at T:232–235. These are not editorial corrections. Its φ objection confuses a continuous nominal rate with realized integer rounding. Its blanket no-stencil/clean-room defaults go beyond the PRD. |
| **Kimi K3** | No blocking owner questionnaire; permit unchanged-library reuse; enumerate transition snapshot versus live/overlay state; bound Gate M isolation tests. | Both β/γ directions are already written at T:126–127, contrary to F1's premise. An explicit role-rebinding sentence remains useful. The proposed rule failing Gate M for every uncharacterized outside-corpus miss risks an unbounded gate; classify relevance rather than demand universal coverage. Its clean-room default is not recorded owner policy. |
| **MiniMax M3** | Clarify analytic-domain predicates, failure classification, transition surface scope, exact certification and dependency licensing. | Numerical bitmap caps, corpus size, license-memo format and routine rounding classification are plan details, not three new blocking owner decisions. Its suggested 128–256 bitmap range is unsupported. Blanket owner approval before every Gate M rerun is unnecessary. Blocked positive previews and no arbitrary-router adoption are already settled. |

The target already forbids hidden router payloads (T:56,283), preserves local settlement (T:73,262–270), and defines a math gate rather than authorizing implementation. Repeating these as unanswered requirements would reopen settled scope without evidence.

## 3. φ semantics: preserve the distinction, do not change the polynomial

**Priority P1; engineering clarification.** Fresh direct reads:

* `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol:35–46`: combined pips `q=p+lp−floor(p*lp/10^6)`; p is the selected direction's protocol field.
* `.../libraries/Pool.sol:389–410`: for gross step input U, protocol take is `floor(U*p/10^6)`, except when q=p, when the entire step fee goes to protocol. LP growth then uses the remaining fee.

In T's **continuous approximation**, `phi=p/10^6` is the nominal protocol fraction of gross input; `f=q/10^6`, `g=1−f`. Own principal plus own LP fees gives

`rho*g*U + rho*(f−phi)*U = rho*(1−phi)*U`.

Thus Grok's assertion that implementers **cannot** use protocol pips/10^6 for explanatory φ is incorrect. In exact core settlement, realized `protocolTake/U` can differ through floors and the zero-LP-fee special branch. Defining the polynomial's constant φ as that amount-dependent realized ratio would obscure, not fix, the continuous/integer boundary.

**Suggested addition after T:145:**

> In the explanatory smooth model, phi is the selected directional protocol-pip rate divided by 10^6, and f uses the source combined fee. Exact certification separately reproduces per-step protocol take, including the zero-LP-fee special branch, and subsequent LP-growth/position floors. The continuous coefficient is not an instruction to replace those integer operations with multiplication by phi.

Also append:

> The A/B/C expansion applies to both directions using the stated beta/gamma and input/output role rebinding. The plan shall state all positivity, supply, representability and segment predicates; degenerate cases are classified separately.

This supports Kimi's useful clarification without claiming the second direction is missing.

## 4. Gate M isolation: enough real evidence, no premature vault integration

**Priority P1; engineering/editorial.** T:199–202 and 211–217 already support a real-core harness. Agree with Kimi and my original that the positive permission should be explicit. Grok's “diff plus compile” alone is insufficient evidence for all applicable isolation checks; conversely, a full Orbital proof belongs to Stage 2.

**Suggested addition after T:202:**

> Stage 1 may reuse unchanged pure math, quoter and placement components and use a test-only executor owning real V4 positions/local inventory. Execute the selected swap and placement against real core, and independently verify backing, checkpoint/fee attribution and modeled share issuance. No new planner is installed into production vault dispatch. Unchanged baseline proxies may be instantiated. Required isolation checks cover affected dependencies and baseline surfaces; full integrated consumer acceptance belongs to Stage 2.

Do not require a “pure replica” as Grok suggests if unchanged production placement math can be exercised as the SUT: copying it increases divergence risk. Expected values must still be independently derived; two calls to that same implementation do not provide independent proof. Canonical `crane-testing/SKILL.md:11–29` supports real protocol code and independent controls, not mocked SUTs.

**Dependency disposition clause:**

> Record existing failures, newly exposed correctness defects and refactor-induced regressions separately. Unrelated consumer failures do not prevent an otherwise valid Gate M report. Required Stage 2 failures remain integration blockers until separately authorized corrections or an explicit owner-approved scope change resolve them. A nonregressing pre-existing failure is not consumer success. Neither this classification nor source investigation authorizes its repair.

This preserves T:272's treatment of pre-existing unsafe shortcuts without importing all surrounding repair work into Stage 1.

## 5. Corpus, unknown reference outcomes and missed solutions

**Priority P1; engineering acceptance.** Agree with all three that the corpus must be concrete; disagree that the human must choose its numeric size now. T:175–183 delegates that specification to the plan while reserving domain changes for escalation.

**Suggested replacement/addition at T:183/214:**

> Freeze versioned generators, required positive/negative classes, seeds, supported-state predicates and work-domain definitions before candidate-specific tuning. Retain discovered counterexamples; removing or relabeling a required case needs a recorded specification disposition. Gate M requires zero unresolved reference-confirmed feasible-solution misses in the mandatory corpus, or an explicitly approved domain amendment. A bounded reference that did not establish feasibility or infeasibility reports unknown, not no solution; unknown cannot discharge a required success case. Every new outside-corpus witness is triaged against the supported domain and added to relevant regressions; it is not silently excluded, nor does the gate purport to exhaust all possible states.

Distinguish **reference search cost** from **the supported swap's execution/traversal budget**. A witness does not cease to be feasible merely because finding it exhaustively cost more than the production planner permits. Conversely, an output requiring more actual swap steps than the supported route permits is not evidence that the route must accept it.

Routine bug fixes and better reference coverage can rerun Gate M without new owner permission. A changed economic requirement, reduced mandatory service domain or exploratory production stencil needs the existing amendment/escalation process. MiniMax's “owner approval before any A1–A15 amendment before rerun” is too broad if it captures engineering/editorial corrections; no permission is needed to repair an implementation to satisfy unchanged A1–A15.

## 6. Exact parity versus old/new identical sizing

**Priority P1; editorial clarification of settled law.** My original's distinction remains necessary and neither peer refutes it.

**Suggested clause:**

> Exact parity compares the new planner's preview/transition to its actual execution from identical starting state. Old/new differential comparison reports differences in swap amount, shares, incumbent fees, residuals and rejection domains; it does not require identical candidate choice merely because both succeed. Independently check each against preserved ownership/protections. Old success/new failure in a required supported case is a coverage regression requiring disposition; old failure is not an infeasibility oracle.

**Adopt Kimi F5, with stronger precision:**

> For each preview surface, identify supplied snapshot fields, live dependency reads and projected overrides—including pool tick/liquidity, bitmap and liquidityNet overlays, fee state and checkpoints. Simulated earlier transitions must override affected live values consistently. A snapshot is not permission to reuse stale pool state, and live reads must not overwrite the projected transition.

This belongs in the API/verification plan and Gate M's expected transition model; it must not wait until Stage 2 discovers missing state representation.

## 7. Work caps, rounding and performance acceptance

**Priority P1; engineering.** Preserve T:162: start from the 64-core-step forward envelope, then specify separate numerical caps/counting rules. Do not prematurely decree that 64 is exclusively the final discovery ceiling, or choose MiniMax's 128–256 word cap without evidence.

Named dimensions should cover discovery steps, bitmap accesses/cache misses, certification forward steps/replay, placement evaluations and complete quote/call aggregation. Cache efficiency does not change logical core rounding targets. Preserve searched holder maintenance and outer searches; measure their remaining costs rather than rewrite them here.

**Rounding clause:**

> A proved deterministic correction and its bound may be developed/tested during Stage 1 under T:169. A stencil exploring economic swap amounts is not adopted without the stated design amendment. “One candidate” concerns swap sizing, not removal of the preserved finite placement evaluation. Changes to correction policy, caps, dependencies or verification reopen affected Gate M evidence before integration continues.

Grok's prohibition on any rounding stencil in Stage 1 unnecessarily blocks test/reference investigation; the key boundary is production adoption, not whether tests may explore why a candidate failed.

**Performance:** reject Grok's proposed removal of the performance objective. T:235 expressly requires demonstrated representative performance and rejects larger overall nested cost. “No fixed speedup percentage” does not mean “only report anything and pass.”

**Suggested clarification:**

> The plan shall operationalize representative workload and aggregate/per-case performance acceptance before tuning, with matched compiler/artifact/state/caller and cold/warm conditions. Report successful comparable calls separately from failures and changed domains. A capped baseline failure provides no successful-call speedup denominator. Gate M assesses library/work evidence; Stage 2 retains mandatory consumer success and performance acceptance under unchanged caps. Changing those requirements requires an owner decision, not an editorial interpretation.

Do not count a smaller isolated helper as sufficient while a required complete consumer remains slower or fails. Equally, preserve a completed Gate M result when an unrelated integration dependency blocks Stage 2.

## 8. Settled blocked routes and license wording

MiniMax's question about deterministic-empty versus positive blocked previews is answered by T:262–270 and source: `HInQueryTarget.sol:163–176` uses the existing local mint when `q.idle=false`; `:130–137` checks requested local cover on redemption. Here H is the full Hookless prefix under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`. Returning zero or InvalidRoute for all blocked calls would change settled scalar service. The abstract ability to read sizing state during an unlock is not an execution grant; T:270 already says so. Grok's proposed broader idle-only view wording is unnecessary.

Agree with all three that license/dependency clearance needs an auditable record. Disagree with importing a new **“clean-room default.”** Reviewers and future implementers have read upstream source; independence of authorship is not by itself a legally established clean-room process.

**Suggested clause:**

> Before source reuse, record the exact source/dependency identities, per-file licenses, intended use and review disposition. The Stage 1 plan shall select permitted source reuse or independently authored implementation using approved primitives. Do not label a process clean-room without a documented, reviewed separation procedure. Record dependency/combined-work clearance before Gate M passage and integration; equations written independently do not by themselves resolve derivative-work questions.

Memo format and designated review process are engineering/project-governance deliverables, not requests to have the owner interpret GPL during this requirements review. No categorical source-copy prohibition or license clearance is supplied here. MiniMax's Pons concern should map actual dependencies: Orbital common and generic SY are consumer/shared surfaces, not by name “Pons libraries.” A14/T:202 already prohibit smuggled shared behavior changes.

## 9. Questions, readiness and evidence

**Actual blocking owner questions now: none.** The PRD already selects bounded discovery, one-candidate certification, useful scalar domains, math-first delivery and preservation. The plan must settle counters/caps, finite corpus/reference method, state projection, correction policy, reuse choice and gate identity.

**Only return later for evidence-driven decisions:** a required domain cannot be served without a policy change; a necessary correction exceeds authorized scope; or performance/consumer acceptance cannot be met. Recommended default for each is stop the affected gate, preserve earlier valid evidence, and present quantified alternatives—never silently waive the requirement.

No source or target PRD edited. Fresh local reads on **2026-10-03** substantiate the φ split, blocked routes and current Gate M/Stage 2 wording. These are code/requirements review claims, not new external API documentation assertions. No ordinary file was missing and no guard/SDK denial occurred in this session. MiniMax's denied artifact remains unrecreated. Confidence high in these scope/acceptance corrections; feasibility, baseline failures and gas remain unmeasured. **Return to moderator/human and stop. One review only.**
