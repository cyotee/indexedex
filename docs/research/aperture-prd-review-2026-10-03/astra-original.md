# Astra — Aperture refactor PRD requirements review

**2026-10-03. Independent first pass.** Retained history acknowledged; no peer artifacts or linked research syntheses read. Target PRD read directly and left unchanged. Research only; no execution, tests or implementation. No consensus claim.

**Readiness:** the direction, preservation rules and math-first gate are sufficiently clear to author a Stage 1 plan. Recommend the small acceptance/isolation additions below before implementation authorization. Nothing here reopens mandatory scalar service, whole-book proportional ownership, full-range placement, protections, Pons separation or blocked-state policy.

Notation: **T** is `docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md`; target citations are section:line. **H** is `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault`.

## Prioritized findings

| Priority | Classification | Evidence | Finding |
|---|---|---|---|
| P0 | Owner decision, conditional integration blocker | T §8:232–235; §10:272; §3:53 | Consumer-success acceptance and separately scoped pre-existing correctness defects need an explicit dependency disposition, not an implied mandate to repair everything. |
| P1 | Engineering detail for later plan | T §8:191–217; §9:249–253 | Clarify how real-core whole-book/placement tests demonstrate Gate M without installing new vault dispatch or requiring Stage 2 consumer success. |
| P1 | Engineering detail for later plan | T §7.3:175–183; Gate M:214 | Freeze the corpus and classify reference uncertainty explicitly; do not let a bounded reference miss become “no valid solution.” |
| P1 | Editorial clarification of settled law | T A9–10:71–72; §8:233–235 | New preview/execution parity is exact; equality to the old planner's chosen swap/share output is a different, generally unjustified requirement. |
| P1 | Engineering detail for later plan | T §7.1:159–162; §9:251 | Work caps need a counting contract covering discovery, certification/replay, bitmap/cache work and nested amplification; 64 is not a transaction budget. |
| P1 | Engineering detail for later plan | T §7.2:168–169; A6:68 | Identify what “one candidate” governs and prevent rounding correction from changing accepted economic input or deleting preserved placement behavior. |
| P1 | Engineering detail for later plan | T §8:206–223; A14:76 | Gate identity must include dependencies/verification policy, not just the root solver; shared changes require re-entry and Pons impact evidence. |
| P2 | Editorial clarification | T §2:31; §13:326 | “Existing deployed/tested behavior” should not imply the current checkout or frozen comparator is validated/deployed. |

## 1. Consumer scope versus pre-existing failures

T requires full consumer success, but forbids blessing known shortcuts and puts correctness changes under a separate specification. These are compatible only if blocked dependencies have a named disposition.

Source illustrates why this is concrete: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:518–534` can pass zero inner minOut when `quoteMin_` is false. That is a static path observation, **not** a demonstrated failure or exploit. T §10:272 correctly requires reporting such behavior rather than silently adopting it. No fresh baseline test results establish which consumer failures exist today.

**Proposed addition after T:235:**

> Before Stage 1 implementation, record applicable baseline pass/fail results and known policy violations by source/test/artifact revision. Distinguish refactor-induced regressions, pre-existing failures, and failures exposed by stronger validation. Gate M may pass with unrelated consumer integration blocked, provided Stage 1 obligations pass and isolation is demonstrated. A required Stage 2 consumer blocked by a pre-existing out-of-scope defect remains an integration dependency: obtain a separately specified and authorized correction, or return for an explicit scope decision. Do not waive required consumer success or silently broaden this refactor.

**Consequence:** the math effort can complete independently; integration cannot claim completion merely because failures predate it. This is the only policy question below.

## 2. Make Stage 1 executable without crossing the isolation boundary

T:199,202 permits isolated harnesses/unchanged baseline instances; T:253's general registry-proxy wording could nevertheless be read as requiring new vault integration for every Stage 1 assertion. Gate M should test the actual new library against real core settlement, not pretend a modified proxy is “only a harness.”

**Proposed clarification after T:202:**

> Stage 1 may use a test-only executor owning real V4 positions, funded local inventory and explicit fee/checkpoint snapshots to execute the library's selected swap and placement. Independent reference arithmetic verifies the resulting backing, attribution and share quantity. This is not a mock vault substituted for Stage 2 acceptance. No new planner is installed into a production vault or consumer. Gate M requires actual core token/position/fee reconciliation and independently verified modeled share issuance; installed-selector, real-vault custody and end-to-end Orbital/SY proofs belong to Stage 2. Unchanged baseline proxies remain permitted comparators.

This preserves production-first testing while avoiding a circular requirement: integrate the vault to prove that integration is allowed. Existing Crane/IndexedEx skills require real protocol implementations and prohibit mocking the SUT; independent math references are not prohibited.

## 3. Liveness corpus, reference completeness and counterexample retention

The existing “useful, not universally rejecting” requirement is good. The missing operational rule is how a corpus becomes binding and how uncertainty is reported. Exhausting every 256-bit input is neither possible nor demanded.

**Proposed addition after T:183:**

> The plan shall freeze versioned state generators, mandatory success/rejection classes, deterministic seeds, amount scales, fee/decimal combinations and work-domain definitions before candidate-specific tuning. Keep an exploratory set separately. Newly found counterexamples are appended to the regression corpus; removing or relabeling a mandatory case requires a recorded specification decision. Exhaustive reference conclusions apply only to their explicitly finite domains. A bounded/incomplete reference result is “unknown,” not “no protected solution”; unknown cannot discharge a mandatory success case. Every discovered feasible-solution miss records state, a valid witness amount, rejection reason and disposition.

Require zero unresolved feasible-solution misses **in the frozen mandatory corpus**, not a claim of universal completeness. This follows T:183 rather than creating an arbitrary success-rate threshold. Ordinary coefficient widths, seed counts and domain partitioning are plan engineering—not questions for the owner.

## 4. Parity is not old-planner economic identity

Current `HTransitionPlanner.sol:80–104` tries endpoints/midpoints, breaks once a valid result exists, then checks bracket endpoints. Its output is not a universal optimum. `:124–153` defines contribution, required placement losses and protected min-ratio shares. An analytic route can choose a different valid swap and therefore different shares, incumbent fees and final pool state.

**Proposed addition after T:233:**

> Exact parity compares the adopted planner's preview/transition against its execution from identical input state. Differential comparison with the frozen old planner reports swap, shares, fees, backing, residuals and rejection differences; identical old/new output is not required solely because both succeed. Both successful outputs must independently satisfy preserved accounting/protection laws. Any old-success/new-failure within the mandatory domain is a liveness regression requiring a witness-based disposition; old failure is not evidence that a new rejection is correct.

Do not invent a requirement to maximize minted shares over all valid amounts; do not let “different algorithm” excuse lost essential service.

## 5. Work and performance acceptance

T:162 wisely does not confuse a 64-step forward cap with total planning work. Make its measurements reproducible.

**Proposed clause:**

> Before freezing the gate corpus, specify separate caps/counters for logical core steps, bitmap-word accesses, underlying storage reads/cache misses, candidate generations, and exact forward/placement certifications. State whether certification reuses a prefix or replays it; count replay work. Report per-planner invocation and aggregate complete-call work, retaining maintenance and outer calls in end-to-end measurements. Do not hide work through helper calls, cached test setup or gas-dependent behavior.

For benchmarks, freeze compiler/artifact identities, starting states, caller route/amount, external fee state and warm/cold setup. Compare only semantically matching successful operations; rejected calls are a separate category, never a claimed speedup. If the old transaction fails its cap, do not calculate a successful-transaction speedup against that failure.

T:235's “performance objective” should be operationalized by the later plan **before tuning**, with per-case limits and aggregate reporting; no invented percentage is needed now. Report composition and whole-transaction changes separately so preserved outer searches cannot conceal regressions or falsely invalidate a useful isolated result. Final integration must still honor unchanged caps: `V4FundedBindings.t.sol:385–400` applies 31M to actual SY calls; that is not itself measurement of a complete 32M chain transaction.

## 6. Rounding and Gate M re-entry

**Proposed addition after T:169:**

> “One candidate” refers to swap-amount generation. It does not remove the currently required finite placement evaluation. Any rounding correction shall specify a mathematical error bound, deterministic selection rule, maximum work, and the economic amount being corrected before it is admitted to the frozen gate design. Candidate failure cannot silently trigger neighbor trials, a smaller deposit or changed placement payer. A necessary trial stencil follows the amendment procedure already stated here.

**Proposed addition after T:223:**

> Gate M's identity includes root arithmetic, traversal, fee/checkpoint model, exact verifier, placement policy, dependency revisions, work caps and mandatory corpus. Changes to any relied-on behavior reopen the corresponding obligations and dependent tests; unchanged suites may retain evidence only with an explicit impact justification. Once reopened, further integration of the changed capability stops until the affected gate requirements pass.

Stage 1 shared hot-path fixes remain forbidden by T:202. If a canonical primitive defect blocks validation, record it as a prerequisite correction under separate authorization, then rebase/freeze the baseline and run affected family regressions. Do not force an implementation agent to choose between duplicating bad math and silently changing Pons.

## 7. Settled law and editorial cleanup

**Do not reopen:** scalar entry/exit; min-ratio post-swap admission; credit-before-collection; own fees/repricing incumbent-owned; composition/allocation/mint ordering; full-range-only scope; exact-in no refunds; existing exact-output exclusions; local cover/no nested unlock; protection values/units; Pons separation. T states these clearly. Public maintenance and outer Orbital searches remain; their presence is not failure of A4.

Replace T:31's opening with:

> Until separately authorized Stage 2 integration, this PRD does not change current source execution or any deployed instance. Record actual baseline validation status rather than assuming the checkout or its artifacts are tested or deployed.

The older implementation plan now contains an explicit Hookless-only supersession at §6.3:251. Do not delete its Pons/repair prescriptions or revive a research narrative as product law. Target T:26 links research syntheses; I did not follow them because this round forbids peer-artifact reading.

## Genuine owner questions

**One, conditional on the baseline inventory:** If a mandatory nested consumer remains blocked by a pre-existing correctness defect outside this refactor, may this effort finish with **Gate M passed / Stage 2 blocked**, while a separately authorized correction is tracked as a dependency?

**Recommended default: yes for Stage 1 completion, no for declaring integrated delivery complete.** This preserves the owner-selected sequence and consumer acceptance without silently authorizing unrelated repairs. No other blocking owner question is necessary now. Widths, filenames, counter implementation, finite reference domains and initial cap calibration belong in the later plan.

**Evidence/read limits:** all local accesses 2026-10-03; target/source line citations reflect direct reads. No fresh external API claim required Context7. Current CLAUDE and canonical Crane/IndexedEx testing guidance were read directly. No missing ordinary path, guard denial or SDK failure occurred. Confidence high in scope/gate interpretation; baseline failures, performance and practical liveness remain unmeasured. **Ready for Stage 1 planning with these clarifications; not ready to execute or integrate.**
