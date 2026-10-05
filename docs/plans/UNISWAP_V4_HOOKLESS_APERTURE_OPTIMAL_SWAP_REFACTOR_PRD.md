# PRD: Uniswap V4 Hookless SE — Aperture-Inspired Analytic Swap Refactor

**Date:** 2026-10-03  
**Updated:** 2026-10-04 — owner removed the Gate M limitation. It is not a stop and does not block vault integration.  
**Status:** in implementation  
**Target:** Existing `UniswapV4FullSpreadHooklessStandardExchangeVault` family.  
**Required delivery order:** math library and validation tests, then vault integration and consumer validation. There is no Gate M between them.  
**Authorization:** Document authoring only. A separately authorized implementation agent executes the plan. No test execution, deployment, live-instance migration, source deletion, or configuration change is authorized by writing this PRD.

## Execute

Implementation plan: ./UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.plan.md

Run: Execute the implementation plan at docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.plan.md

## 1. Purpose

Replace the existing Hookless exact-input deposit-composition binary search with an **Aperture-inspired bounded segment-discovery and analytic sizing process**, adapted to the vault's complete incumbent book and source-exact V4 execution.

The product must continue to accept one underlying token and mint fungible vault shares, and to redeem shares into a requested single underlying token within the existing supported domains. These are essential SE/SY and buffered-pool capabilities; basket-only or asynchronous-only replacements are not acceptable.

This is primarily a **sizing-algorithm refactor**, not a change to who owns funds or how shares are priced. Preserve post-swap proportional whole-book admission, caller-only composition funding, incumbent ownership of repricing and own LP fees, the useful sleeve, full booking and existing protection constants.

The research has established continuous fixed-segment quadratics. It has **not** established a complete integer implementation, supported-domain coverage, end-to-end parity or measured gas improvement. Stage 1 exists to establish whether the proposed library can meet those requirements **before changing vault execution or quote dispatch**.

## 2. Authority and relationship to existing documents

Read alongside:

- [Proportional Zap-In PRD](UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md), especially D1–D31.
- [FullSpread Implementation and Test Plan](UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md), including its route/formula matrix and accounting requirements.
- [Uniswap V4 Vault Research](../research/UNISWAP_V4_VAULT_RESEARCH.md).
- [Aperture feasibility synthesis](../research/aperture-v4-hookless-feasibility-2026-10-03/COUNCIL_SYNTHESIS.md) and preserved originals/reviews linked there.
- Current `CLAUDE.md`, canonical Crane/IndexedEx skills and affected family product law.

**Narrow precedence:** for the planned Hookless deposit-composition refactor, this PRD replaces the older plan's §6.3 prescription to perform up to 32 candidate-amount refinements with bounded segment traversal and analytic candidate generation. It does not supersede Pons behavior, the ownership rules, protection values, funding law, supported exact-output rules or public-maintenance policy.

Until Stage 2 is authorized and integrated, the existing deployed/tested behavior is not represented as changed. Historical research suggesting NAV admission, uniform idle internal-CP admission, basket-only entry, refundable exact-in or mandatory wings is not adopted by this PRD.

### Owner direction recorded

The owner selected Aperture as the best candidate. On 2026-10-04 the owner removed the Gate M limitation. Library validation and vault integration are both in scope. Gate M is not a prerequisite and not a reason to stop.

The owner subsequently approved the moderator's recommended clarifications recorded in [the partial requirements-review report](../research/aperture-prd-review-2026-10-03/REVIEW_STATUS_AND_PARTIAL_FINDINGS.md). They are incorporated here without weakening Stage 2 consumer-success or performance acceptance. The underlying council review stopped on a reported attribution guard failure; this approval and document amendment do not claim completion of that review or authorize resuming/replacing its participants.

## 3. Scope and non-goals

### In scope

- A reusable, deterministic analytic sizing library and bounded V4 pool-state traversal needed to evaluate it.
- Exact whole-book candidate verification, including fees, incumbent position repricing, placement loss and share flooring.
- Standalone mathematical tests, independent integer references, and real V4 core settlement tests before vault integration.
- Replacing Hookless caller-composition sizing in execution, ordinary previews and transition quotes with one authoritative implementation.
- Regression closure for scalar SE/SY, dual routes, supported exact-output domains, native currency, imports, sleeve settlement and affected Orbital/DETF consumers.
- Matched-state work/gas evidence and runtime-size evidence at the appropriate stages.

### Out of scope unless separately approved

- Replacing proportional share pricing with NAV, oracle-value issuance or an idle internal-CP market.
- Deploying wings or changing the managed full-range strategy. Multiple-range algebra is useful research, not permission to expand position storage or deployment policy in this refactor.
- Rewriting public holder-repair sizing or silently changing D18–D19 interleaving rules.
- Removing or redesigning Orbital's `_faceForClaim`, `_invertBufferForEffective` or `zapSplitWad` algorithms. They remain measured consumer dependencies, not problems this library automatically solves.
- New exact-output numerical inversion or a claim that a forward quadratic supplies an exact-share input inverse.
- An active-session PoolManager execution adapter in place of the current already-unlocked sleeve-only policy.
- Pons Family V2 changes, shared Hookless/Pons fee dispatch, new hooks, arbitrary routers or user-supplied executable swap payloads.
- Live deployment, upgrade, migration, registry action or legacy removal. Existing separate readiness/removal requirements remain intact.

## 4. Product decisions

| ID | Requirement |
|---|---|
| A1 | Preserve synchronous single-token exact-input entry and single-token exact-input exit within documented, useful supported domains; no basket-only substitute. |
| A2 | Refactor the existing Hookless route rather than introducing an opt-in analytic route beside a still-searching canonical deposit. |
| A3 | Use bounded, progressing, core-compatible segment discovery followed by an analytic solve. A certified one-step implementation is a Stage 1 milestone, not sufficient by itself to silently narrow the final product. |
| A4 | Remove candidate-amount bisection/refinement from adopted Hookless composition sizing. No hidden legacy solver fallback, off-chain amount requirement or repeated trial-quote rescue. |
| A5 | Preserve caller-credit exclusions, post-swap incumbent whole-book proportional minting, own-fee ownership and exact local booking. |
| A6 | Preserve composition → required allocation → final share mint ordering and the current placement-loss attribution. Do not defer placement or change its payer silently. |
| A7 | Preserve full-range core, live sleeve percentage/default/deadband, dual initial funding and dead-sink shares. |
| A8 | Preserve 1 bp depositor alignment/share-flooring, 50 bp composition price impact, 25 bp holder-repair price impact and 10 bp fee-inclusive execution shortfall with current meanings and no new setters. |
| A9 | Preserved execution, ordinary preview and transition preview must share the same adopted integer planner and supported/rejection domains. |
| A10 | Same-state parity is exact; the 10 bp execution guard is not a permitted preview mismatch. |
| A11 | Keep already-unlocked calls on existing funded local-settlement paths. No nested unlock; deployed principal and E are not local cover. |
| A12 | Preserve route-specific exact-output eligibility. An exact-input analytic solution does not authorize a new inverse. |
| A13 | Keep public maintenance and its separate ownership/progress rules. Report residual searched work honestly; do not describe the entire protocol as search-free. |
| A14 | Preserve Pons separation and prevent changes in shared generic dependencies from silently altering its behavior. |
| A15 | Implement and validate the complete intended math/traversal/verification capability before refactoring any production vault money or quote path. |
| A16 | Stop at a failed math gate. Do not relax protections, waive failed tests, switch economic models or shrink essential scalar service to make integration proceed. |

## 5. Required accounting model

All amounts remain native raw token units. Let:

- `S`: pre-operation share supply.
- `D_i`: owned deployed principal using exact finite-range math.
- `F_i`: spendable local incumbent assets, excluding current caller credit and payout/refund liabilities.
- `E_i`: earned uncollected own LP fees.
- `B_i = D_i + F_i + E_i`: complete incumbent backing.
- `C_i`: caller's net contribution after the caller-funded swap and attributed required-placement cost.

Preserve measured pull funding, eligible declared pretransfer credit within unbooked availability, contract-caller restrictions, no provenance requirement, and full synchronization of the expected held-token set. Fix caller credit before fee collection. Collection moves E to F once; it does not create contribution. Position repricing cannot create local pretransfer credit.

For positive incumbent legs, after actual/properly projected swap, fees and placement attribution:

```
m = min(floor(S*C0/B0), floor(S*C1/B1))
10000*m*B_i >= 9999*S*C_i   for each positive contribution/backing leg
```

Use exact overflow-safe comparisons and explicit zero-domain handling. Preserve existing one-sided and activation rules rather than manufacturing ratios. Reject zero successful issuance. Existing exact-in retains and books sleeve/residual contribution; do not copy Aperture's refund-all scratch-router behavior.

Any no-swap placement/removal must explicitly reconcile loss:

`loss_i = (F_i+D_i)_before - (F_i+D_i)_after`

after excluding transfers and fee collection. Required caller-funded addition loss reduces C under current policy; holder-funded removal loss reduces B. Fees and repricing from the caller swap belong to incumbents. No lost amount may remain an asset, and no protocol fee may be booked as earned LP fees.

## 6. Mathematical basis to validate, not blindly transcribe

The selected approach is **inspired by Aperture's walk-plus-root process**, with a whole-book equation rather than its single-position ratio equation.

For one continuous segment with no liquidity change inside it:

- `L>0`: total active pool liquidity.
- `l`: vault-owned active liquidity; `rho=l/L`.
- `s`: segment-start sqrt price, normalized out of Q96 for these explanatory equations.
- `f<1`: combined swap fee; `g=1-f`.
- `phi`: directional protocol fraction of gross input.
- `a,b`: incumbent input/output backing at segment start, including F/prior E and committed prefix changes, excluding caller credit.
- `d,e`: remaining caller input and accumulated caller output.
- `u`: additional gross input within this segment.

```
v(u) = beta*u/(L+gamma*u)

token0 -> token1: beta=L*g*s², gamma=g*s
token1 -> token0: beta=L*g/s², gamma=g/s

alpha = rho*(1-phi)
B_in  = a + alpha*u
B_out = b - rho*v(u)
C_in  = d-u
C_out = e+v(u)
```

With `P=b*L`, `Q=b*gamma-rho*beta`, alignment reduces to:

```
A*u² + B*u + C = 0
A = Q + alpha*beta + e*alpha*gamma
B = beta*a - d*Q + P + e*(a*gamma + alpha*L)
C = e*a*L - d*P
```

This continuous derivation includes arbitrary F/prior E and own LP recovery after protocol take. In a funded positive domain the pre-placement ratio comparison is continuously monotone. Neither fact establishes exact integer behavior after Q96/Q128 floors, checkpoint collection, share rounding or placement.

**Direction and domain:** the same A/B/C expansion applies to both directions using the stated beta/gamma and rebinding input/output quantities a, b, d and e. Validate both directions independently. The ordinary positive-segment derivation assumes `s>0`, `L>0`, `0<=l<=L`, `0<=phi<=f<1`, `a,b>0`, `d>0`, `e>=0`, `0<=u<=d`, nonnegative remaining incumbent output and no active-set change inside the segment. Zero-liquidity gaps, one-sided/empty books, endpoints, coefficient degeneracies, supply and integer representability require separate explicit classifications; these assumptions do not silently eliminate their existing route behavior.

**Nominal versus realized protocol fee:** in this explanatory smooth model, `phi` is the selected directional protocol-pip rate divided by `10^6`; `f` uses the source combined fee. Exact certification separately reproduces per-step protocol take, including the zero-LP-fee special branch, and subsequent LP-growth/position floors. Do not replace exact integer operations with multiplication by phi, or redefine the polynomial's constant phi as an amount-dependent realized protocol-take ratio.

**Stage 1 must independently validate these coefficients and their domains.** The implementation plan must choose a consistent fixed-point scale, signed widths, discriminant computation, stable physical-root selection and deterministic integer conversion. Linear/zero-coefficient degeneracies, negative constants, negative discriminants, representability errors and out-of-domain roots require explicit classifications. Do not inherit upstream unchecked arithmetic assumptions without a width proof.

The solver must not require F=0 or “negligible fees” as an undeclared shortcut. Scalar deposits into a live vault with a material sleeve and positive own LP fee accrual are required positive test cases. The existing single-core deployment is the first product target; external ticks still change L and own-range boundaries change l.

## 7. Traversal, integer certification and failure requirements

### 7.1 Bounded monotone traversal

- Maintain separate caller and incumbent state through each committed prefix.
- Advance in one swap direction; classify budget exhaustion, impact limit, segment bracket and unsupported/work-limit conditions explicitly.
- Use V4 core-compatible step boundaries, including empty bitmap-word computational boundaries. Cache reads without skipping rounding semantics.
- Update pool L and vault-owned l separately. Respect own boundaries/checkpoints even where aggregate liquidityNet cancels.
- Bound core steps and storage/bitmap work explicitly. Zero-liquidity traversal and missing initialized ticks must not rely on input consumption to terminate.
- Do not copy the upstream uncapped `crossTicks` or uncapped empty-word scan.

The future implementation plan must state numerical caps and their counting rules **before the Stage 1 gate corpus is finalized**. Start evaluation from the current 64-core-step forward-work envelope; do not infer that one total 64-step budget covers discovery plus certification plus all quotes, or that this value is already proven sufficient. Final bounds require measured later evidence and must not be hidden runtime/gasleft-dependent choices. Raising transaction/chain caps is not an acceptable fix.

The plan must separately define and instrument discovery core steps, bitmap accesses and actual word-read/cache-miss counts (including empty-word scans), certification/replay forward steps, placement evaluations, and aggregation across the complete quote/call and nested consumer. State which logical count and which actual-read count each cap limits. Cache reuse does not remove core rounding boundaries. Do not select arbitrary numeric bitmap limits or reinterpret 64 as a proven discovery-only or total-call bound without evidence.

### 7.2 Exact certification

An analytic candidate must be evaluated with source-exact V4 forward math, actual fee splitting and checkpoint semantics, actual position principal, required placement and final share calculation. This verification is not another optimization loop.

Certification explicitly includes funded deltas, positive supported-domain issuance, user minima/maxima, the §5 share-loss inequalities and the 50 bp composition impact bound on **price, not sqrt price**. Execution subsequently enforces the 10 bp fee-inclusive fill-shortfall guard without using it as a parity-test tolerance. The plan maps invalid arithmetic domains, invalid roots, work exhaustion and protection failures to the existing suitable errors or an explicitly specified error extension; no silent clamping to a successful economic result.

- Initial production design: one deterministically selected integer candidate for the located segment, plus exact certification.
- A rounding correction is permitted only when its bound and purpose are independently justified and specified. A trial stencil choosing among economic amounts is not silently relabeled a proof; if Stage 1 shows it necessary, report it and amend the design before adoption.
- On failure, return/revert through the documented domain/protection/work error. Do not fall back to the old search, internal CP while idle, NAV issuance or a materially lossy mint.
- An incomplete quote cannot be accepted as a complete fill. Preserve applicable terminal partial-fill/residual behavior for other routes without inventing it for composition.

Stage 1 tests and independent references may investigate neighboring integer amounts and derive correction bounds. This is not production adoption of a search stencil. A proved deterministic correction may be developed and validated under this specification; an exploratory economic-amount stencil requires the stated design amendment. “One candidate” refers to swap-input sizing, not removal of preserved finite placement evaluation. Changes to rounding/correction policy or its assumptions must be revalidated. They do not reopen a Gate M stop.

### 7.3 Liveness is an acceptance requirement

“Every returned result is safe” is insufficient if the library rejects routine useful deposits. The plan must freeze a meaningful supported-domain matrix with positive success cases before tuning, including both directions, nonzero sleeves, existing fees, positive LP/protocol fee combinations, multiple core steps, external liquidity changes and mixed decimals.

Use an independent test-side exhaustive/reference solver to distinguish:

1. No valid protected solution exists within the specified work/domain.
2. A valid integer solution exists but the analytic candidate fails.
3. The old planner accepts an invalid result or its own work limit misses a valid result.
4. The reference is incomplete and has established neither feasibility nor infeasibility: **unknown**.

Freeze versioned generators, seeds, required positive/negative classes, supported-state predicates and work-domain definitions before candidate-specific tuning. Retain discovered counterexamples. Removing or relabeling a required case requires a recorded specification disposition; a reduced mandatory service domain requires explicit owner approval, not a convenient test-filter change.

Case 2 is a recorded coverage defect, not automatically an acceptable product restriction. Acceptance requires **zero unresolved reference-confirmed feasible-solution misses in the mandatory corpus**, or an explicitly approved domain amendment followed by the applicable validation. Case 4 is not evidence of “no solution” and cannot discharge a required positive-success case. Every new outside-corpus witness must be triaged against the supported domain and added to relevant regressions: it is neither silently excluded nor an assertion that a finite gate exhausts all possible states.

Reference search expense is distinct from the supported swap's execution/traversal budget. A feasible witness does not become infeasible merely because finding it exhaustively was expensive. Conversely, a swap requiring more actual core steps than the declared supported route allows does not prove that route must accept it.

The old binary planner is a comparator, **not the mathematical oracle**. Test-side references may search; adopted production composition must not use candidate-amount search/refinement. Bounded monotone segment discovery remains the selected process under A3.

### 7.4 Exact parity versus old/new differential comparison

Exact parity compares the **adopted planner's** preview/transition with its actual execution from identical starting state. Old/new differential comparison reports swap input/output, shares, incumbent fees, residuals, placement effects and rejection domains. It does not demand identical candidate choice merely because both algorithms succeed; each result must independently satisfy the preserved ownership and protection requirements.

Old success/new failure in a required supported case is a coverage regression requiring disposition under §7.3. Old failure is not an infeasibility oracle, and two matching calls to the same new helper are not execution proof.

## 8. Required staged delivery

The future implementation plan must retain these two major stages. It may subdivide them, but **must not overlap Stage 2 production integration with an unpassed Stage 1 gate**.

### Stage 1 — Implement the library and prove its practical domain

**Goal:** build and test the solver, bounded traversal and exact candidate verification in isolation from the production vault routing.

Required deliverables:

1. Pinned source/dependency/license record and an explicit choice of permitted reuse versus independent implementation.
2. A reviewed library API separating pure arithmetic, read-only V4 state/traversal and whole-book verification. Reuse canonical Crane primitives where correct; keep family-specific ownership/orchestration outside generic protocol math. Exact paths and names belong in the later plan and must follow current full-name conventions.
3. Both-direction analytic coefficient/root implementation, starting with one core step and extending to the intended bounded multi-step domain.
4. Source-exact fee, word/tick, liquidity, checkpoint, backing and terminal-placement models needed to verify intended vault deposits.
5. Test harnesses using real V4 core and production math, independent expected results, fuzz/exhaustive small-domain checks and realistic state fixtures.
6. Work counters, failure classification, feasibility/missed-candidate evidence, initial library gas/runtime measurements and frozen gate report.

The source/license record must identify exact source and dependency revisions, per-file licenses, intended use, dependency/combined-work review and disposition, including `@aperture_finance/uni-v3-lib` and its GPL-2.0-or-later source headers. Before source reuse, select permitted reuse or independently authored implementation using approved primitives. Do not describe that choice as “clean-room” without a documented, reviewed separation procedure; prior source access and independently written equations do not by themselves resolve derivative-work questions. Record the chosen use. The plan owns the memo format. This PRD grants no legal clearance. Gate M is not a clearance gate.

**Isolation boundary:** do not change Hookless `_composition` dispatch, installed facets, execution delegates, public quote dispatch, DFPkg wiring, storage layout, generic SY behavior or current production money paths during Stage 1. New isolated helpers and test harnesses are the subject of Stage 1. Reading/instantiating an unchanged baseline vault in local tests is allowed in the future implementation task. Shared hot-path changes that would affect existing money paths cannot be smuggled in as “library preparation.”

**Permitted Stage 1 validation:** reuse unchanged pure math, quoter and placement components, and use a test-only executor owning real V4 positions and local inventory. Execute the selected swap and placement against real core; independently verify backing, fee/checkpoint attribution and modeled share issuance. No new planner is installed into production vault dispatch. Expected values must be independently derived, not obtained by calling the same component twice. Do not require a duplicated placement implementation merely to avoid exercising unchanged production components.

Freeze baseline source/artifact identities early. Obtain applicable isolation baselines before changing affected dependencies and consumer baselines before integration/benchmark comparisons. Stage 1 isolation checks cover affected dependencies and baseline surfaces; a diff or successful compilation alone need not establish those checks. Conversely, running the entire Stage 2 Orbital/DETF consumer matrix is not a prerequisite to starting isolated math development.

#### Gate M — removed

On 2026-10-04 the owner removed Gate M. It is not a limitation, not a prerequisite for vault integration, and not a reason to stop. A production edit to `TransitionPlanner._composition` does not fail this work. Do not recreate the stop under another name.

The following remain acceptance criteria, not a gate:

- Required analytic suites pass.
- Both directions, fees, sleeve, multi-step cases, and PoolManager settlement are demonstrated.
- No unresolved reference-confirmed feasible miss in the mandatory corpus. `unknown` does not discharge a required success.
- Work ceilings are enforced.
- The provenance memo records independent implementation and grants no legal clearance.

#### Baseline defects and dependency status

Record **pre-existing failures**, **newly exposed correctness defects** and **refactor-induced regressions** separately. Unrelated consumer failures are named. They are not a Gate M result, and “Stage 2 blocked” is not a status this document uses.

Required Stage 2 consumer failures remain integration blockers until separately authorized corrections or an explicit owner-approved scope change resolves them. A nonregressing pre-existing failure is not consumer success. Recording or investigating a defect does not authorize repairing it outside this refactor's scope, and does not waive its eventual required acceptance. Preserve earlier valid stage evidence while the affected gate is blocked.

### Stage 2 — Refactor the existing Hookless vault to use the validated library

**Entry condition:** the implementation task authorizes integration. Gate M is not an entry condition. Material arithmetic, traversal, fee, placement, cap, or corpus changes are revalidated. They do not reopen a removed gate.

Required outcomes:

1. Replace canonical idle exact-input caller composition with the validated analytic planner; no hidden legacy fallback.
2. Route execution, ordinary numeric previews and transition previews through the same deterministic behavior.
3. Preserve all caller funding, fees, placement ordering, share minting, residual booking and settlement invariants.
4. Keep blocked-state routes and scalar exits operational; retain truthful route discovery and existing exact-output eligibility.
5. Preserve factory/registry/proxy interfaces and existing storage unless a separately justified migration-free requirement is approved. Updating deployment artifacts for new test instances is not live-instance migration.
6. Close full vault, native/SY, import/Multi, actual outer-unlock, Orbital and affected DETF regression suites through production-path proxies.
7. Benchmark matched states against the frozen original planner and complete nested consumers, with fresh runtime artifacts. Report gas, quote count, word/core-step work, rejection-domain differences and deployed code sizes separately.

**Integration gate:** require exact parity, accepted domains, accounting/protection correctness and consumer success under unchanged constraints. Demonstrate the performance objective on representative composition workloads and report regressions. A faster helper that causes consumer failures, unacceptable deposit rejection or a larger overall nested cost is not a successful refactor. No fixed speedup percentage is invented before measurement.

The implementation plan must operationalize representative workloads and aggregate/per-case performance acceptance **before tuning**, using matched compiler settings, fresh artifacts, starting state, caller/funding mode and cold/warm conditions. Report successful comparable calls separately from failures and changed service domains. A capped or otherwise failing baseline call provides no successful-call speedup denominator. Quantify composition cost, preserved maintenance cost and outer consumer cost separately as well as in total.

Library tests do not replace the Stage 2 nested benchmark. Stage 2 retains mandatory consumer success and representative performance acceptance under unchanged caps. Do not replace these requirements with “only no new failures,” waive performance because an isolated helper is faster, or raise caps. If acceptance cannot be met, stop the affected gate and present quantified alternatives for an owner decision.

## 9. Test acceptance matrix

| Suite area | Stage 1 requirement | Stage 2 requirement |
|---|---|---|
| Coefficients/root math | Independent both-direction expansion; zero/protocol fees; rho=0/interior/1; signed/linear degeneracies; root-domain checks | Integrated result uses same validated arithmetic |
| Integer/overflow | Wide products/discriminant/sqrt; Q96/Q128 boundaries; tiny/large raw amounts; no approximate-parity waiver | No truncated/cast-dependent execution discrepancy |
| Fee ownership | LP/protocol separation; per-step floors; prior E and collection/checkpoint order; own-liquidity fraction | Caller never receives incumbent fee/repricing as contribution |
| Traversal | Empty words, zero L, initialized boundaries, own/external crossings, price limits, explicit counters | Real quote and execution use matching projected state |
| Placement/sleeve | Exact debt/proceeds and caller/holder loss attribution; final denominator; p=0/default/1 and live inheritance | Full required placement before mint and complete booking |
| Domain/liveness | Independent feasible-solution comparison; positive mixed-decimal multi-step cases; truthful failures | Required user and consumer route matrix remains useful |
| Funding/custody | Modeled exclusions, donations and refund liabilities not confused with backing | Pull/pretransfer/native/internal-share paths through real proxies |
| Economic/adversarial | Fee/donation/repricing cycle references and malformed state rejection | Real round trips, callbacks/reentrancy, stale quotes, rollback and booked-credit negatives |
| SE/SY/transition | Expected transition model with all integer fields | Exact result/state parity at identical snapshots; no duplicated SY math |
| Nesting | Known manager-state domain classification | Actual outer unlock, local-cover success/failure and no nested unlock |
| Performance | Solver/read/step bounds and library baseline; no gas claim before run | Full transactions, worst-case supported cases, nested 31M/32M constraints and code-size checks |

Use current production-first Crane/IndexedEx TestBases, real protocol ports and registry-deployed vault proxies. Do not mock the subject under test. Independent reference math is allowed and necessary; do not use the production helper itself to generate expected answers. Refresh runtime artifacts before dependent tests under the current CLAUDE workflow. Keep default hermetic/standard fork profiles, current compiler settings and no via-IR/config workaround.

The plan must state finite exhaustive-test domains, reference independence, generator/seed versions and failure classifications; it must not use an arbitrary case count as a substitute for the required classes and coverage. Apply §7.4 for old/new differential results and §8 for stage-appropriate baseline checks and benchmarks.

## 10. Interfaces, manager state and route preservation

The later plan must supply a complete selector/direction/exact-in-or-out/manager-state matrix anchored to the existing R1–R11 specification. At minimum:

| Route | Required behavior |
|---|---|
| Idle token → shares, exact input | New whole-book analytic composition, same final ownership/protection law |
| Already-unlocked token → shares | Existing covered local-admission formula/domain, no external composition |
| Shares → one token, exact input | Existing correct removal/conversion or local-settlement domain; no basket-only replacement |
| Token → exact shares while idle | Remains unsupported absent its own established complete inverse; not created by this forward solver |
| Supported blocked exact-share input | Preserve current source-backed inverse and funding semantics |
| General two-leg exact-output share exit | No numerical inverse; retain current rejection unless a separately established eligible formula is approved |
| Direct swaps, dual joins/exits, SY and imports | Preserve current route-specific behavior and guards; test shared-dependency impact |
| Public maintenance | Preserve existing permissionless/progress/stopping and bounded solver policy unless separately amended |

No nested unlock is attempted. A sizing view can technically run during an unlocked session, but that does not authorize pool actions in the blocked product path. This PRD does not add an active-session adapter or change position ownership/settlement law.

“Transition quotes” refers to the existing Hookless SE transition surfaces consumed by Orbital/SY and other callers, not a new Orbital-side interface or permission to change outer allocation. A blocked-state preview must model its existing supported local-settlement operation and cover/domain conditions; do not replace all blocked previews with zero or `InvalidRoute` merely because analytic external composition is idle-only.

For **each** ordinary and transition preview surface, the Stage 1 API/verification specification must enumerate supplied snapshot fields, live dependency reads and projected overrides. Include pool price/tick/liquidity, bitmap and liquidityNet overlays, fee state, position checkpoints, supply, caller-credit exclusions and relevant manager/rate context. Earlier simulated transitions must override affected live values consistently: live reads must not silently overwrite projected state, and a supplied snapshot does not authorize using stale incompatible dependency state. Carry this contract through Stage 2 and test composed transitions, not only isolated previews.

Preserve meaningful inner minima and configured rate-provider state projection. Do not substitute minOut=0, raw face amount for zero minted/rated shares, a gas-conditioned quote, or unreviewed speculative share quantities to make Orbital tests pass. Any such pre-existing behavior encountered must be reported and handled under a separately specified correctness change, not silently blessed by the solver refactor.

## 11. V4 and Aperture compatibility requirements

- V4 exact-input `amountSpecified` is negative; V3's positive input convention must not be copied.
- V4 negative caller delta is debt; positive is receivable. ERC20 settlement snapshots with sync before payment transfer, then settles. Native settlement differs appropriately.
- Read live directional protocol fee and LP fee. Use source-exact combined pips and fee splitting; zero hooks does not imply zero protocol fee.
- Preserve within-word core rounding targets, correct negative-tick compression and direction-correct liquidityNet crossing.
- `modifyLiquidity` caller delta includes fees; informational fee output is not additional cash.
- Aperture's predicted final sqrt price is not its router's execution limit. Its global extreme limits do not satisfy our 50 bp price-impact requirement by themselves.
- Caller-supplied ranges/upstream NFTs become the existing vault's configured managed range/custody, not a new range-selection feature.
- No arbitrary-router payload or upstream governance/service-fee surface is introduced merely to reuse the math. Aperture's allowlisted-router execution branch is not adopted by this PRD.
- Review pinned source and dependencies for license compatibility; a changed BUSL/GPL date is neither MIT permission nor a categorical no-port rule.

## 12. Baseline-law amendment ledger

| Existing decisions | Disposition under this PRD |
|---|---|
| D1–8 | Preserve scalar route, caller budget, sleeve, ordering, post-swap proportional ownership and residual law. Change the sizing mechanism, not economics. |
| D9–12, D21 | Preserve public repair and no-throttle/progress rules. Do not confuse caller composition with holder repair. |
| D13–16 | Preserve direct manager/admission, source-agnostic pretransfer and full local booking. |
| D17 | Preserve formula-backed exact-output support and exclusions; new forward solution grants no inverse. |
| D18–19 | Preserve current interleaving/route exception policy unless future plan explicitly identifies and obtains approval for a necessary amendment. |
| D20, D25 | Preserve values, units, fixed-constant/no-setter policy and exact parity distinction. |
| D22–24, D26, D28–29, D31 | Preserve Pons separation, bindings, generic-reuse boundary, evidence/removal gates. No deletion or Pons refactor in this task. |
| D27, D30 | Specify the new analytic mechanism, work domains and staged proof/parity obligations. |
| Prior implementation plan §6.3, Hookless composition row | Replaced for this refactor by bounded traversal plus analytic candidate and exact certification; Pons/repair prescriptions not replaced. |

A later plan must not label all ordinary operations or the full Orbital system search-free. This scope removes **Hookless caller-composition amount refinement**; approved holder repair and outer consumer searches can remain. Measure them separately and report whether they dominate the remaining cost.

## 13. Evidence, provenance and source baseline

Research access date: **2026-10-03**. No new benchmark or executed test is claimed by this PRD.

Primary reference:

- Aperture repository commit `c40aaa98cf49baf454fbb7a8ee6709862e27038e`.
- [OptimalSwap.sol](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/src/libraries/OptimalSwap.sol): `getOptimalSwap`, `crossTicks`, `solveOptimalZeroForOne`, `solveOptimalOneForZero`.
- [SwapRouter.sol](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/src/base/SwapRouter.sol): direct autonomous sizing/execution path and V3 conventions.
- [TickBitmap dependency v3.0.3](https://raw.githubusercontent.com/Aperture-Finance/uni-v3-lib/v3.0.3/src/TickBitmap.sol): separate empty-word scan and compression behavior.
- [Pinned LICENSE](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/LICENSE): BUSL document, stated 2026-07-01 change date, GPL-2.0-or-later change license. Record dependency/combined-work clearance before reuse.

Aperture package 2.0.1 declares math dependency 3.0.3; other dependencies include semver ranges not fully lockfile-attested in the research. Pinned upstream compiler is 0.8.26/Paris, optimizer runs 4,294,967,295, via_ir=false. Local observed baseline is 0.8.35, optimizer runs 1, via_ir=false (`foundry.toml:29–36`). Preserve local configuration. Upstream approximate tests and vendor gas comments do not meet local acceptance automatically.

Local source evidence:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol:73–108,110–165` — current amount-refinement loop, fee/repricing attribution, placement loss and shares.
- Same family `InventoryMath.sol:216–244,253–292` — liquidity target and explicit settlement loss.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol:35–46` — live combined fee equation.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol:143–185,196–225,233–288` — source-exact step/fee/overlay behavior to preserve.
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:20–76` — scalar aliasing.
- Orbital `...ExitQuoteLib.sol:347–374`, `...ClaimLib.sol:250–276,315–329`, `...Math.sol:321–364`, under `contracts/hooks/uniswap/v4/standardExchange/orbital/` — remaining outer sizing and rate semantics.
- Existing real consumer fixtures: `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol` and `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Univ4Se.sol`.

Exact local baseline revisions and artifact identities must be recorded when the implementation plan begins; line numbers are research pointers, not immutable deployment evidence. Current source/PRDs supersede older narrative examples.

## 14. Completion criteria and handoff

This PRD is complete when it records the selected algorithmic direction, preserved economics, integration acceptance and unresolved engineering deliverables. Gate M is not part of completion. It does not require choosing unmeasured constants or claiming proof prematurely.

The **future implementation plan** must provide the exact file/component map, library interfaces, scaled arithmetic specification, numeric traversal/read caps, deterministic rounding policy, frozen test/domain matrix, independent reference methodology, benchmark corpus and explicit gate records. These engineering details must be decided before the relevant stage executes, not improvised during vault integration.

No further owner questionnaire is required to choose routine filenames, arithmetic widths, numeric work limits, corpus sizes or record formats. Return for an evidence-driven decision only when a required service domain needs a policy change, necessary corrective work exceeds scope, or required consumer/performance acceptance cannot be met. Preserve valid completed-stage evidence, stop the affected gate, and present quantified options rather than silently amending the requirements.

**Current status:** Gate M removed by the owner on 2026-10-04. Integration is in scope. The partial council review remains incomplete. Passing tests are necessary evidence, not proof of economic soundness or security.
