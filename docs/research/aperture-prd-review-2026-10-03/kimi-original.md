# Kimi K3 original — requirements review of the Aperture refactor PRD

**Date:** 2026-10-03. Independent first pass; no peer artifacts read. Target: `docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md` (334 lines, read in full), checked against current law (Zap-In PRD D1–D31, FullSpread impl plan §6.3, Orbital held-rate/B6, local source) and the pinned-Aperture derivations verified in my prior passes. Research only; no consensus, no gas/security claims.

## 0. Overall assessment

This PRD is unusually well-hardened — it has visibly absorbed the prior rounds' lessons (residual law vs Aperture refunds, blocked-state policy, one-step milestone trap, old-planner-as-oracle trap, gasleft-dependence, upstream uncapped loops, license nuance, preview parity). I found **no contradiction with settled law and no P0 defect**. Findings are P1/P2 sharpenings. **Blocking owner questions: none** — the PRD already records defaults consistent with the safest reading of each would-be question, and the review brief warns against offloading engineering detail.

**Math verification (§6, lines 123–143):** I independently re-expanded the alignment equation. The PRD's `A/B/C` are correct for token0→token1, and `B_in = a + ρ(1−φ)u`, `B_out = b − ρv` correctly encode principal conversion plus own-LP fee on gross input net of protocol take (consistent with `ProtocolFeeLibrary.sol:37–40` combined fee and three independent prior derivations). The monotonicity claim (:145) holds within a constant-`L`,`l` segment: `C_in·B_out − C_out·B_in` is strictly decreasing in `u` on a funded positive book, which justifies bracketing. Continuous layer: sound. Integer layer: correctly disclaimed (:145–147).

## 1. Findings

| # | PRD section:line | Finding | Class / Priority |
|---|---|---|---|
| F1 | §6 :126–143 | Only the token0→token1 `β/γ` and one `A/B/C` expansion are written. The text implies direction-parameterization (`a,b` = input/output backing; `d,e` = caller input/output) but never states that the *same* formulas apply to token1→token0 under role swap. Mis-derivation risk is real (the directions are not symmetric in `s` powers: `β = L·g·s²` vs `L·g/s²`). | Engineering detail / **P1** |
| F2 | §7.3 :179–183; Gate M :214 | Case-2 (valid integer exists but analytic candidate fails) must be "resolved within the target corpus," but "resolved" is undefined. Read strictly this could demand zero misses over an unrealistic corpus (the review brief's "unrealistic exhaustive coverage" trap); read loosely it allows silent acceptance of routine-deposit rejections. | Editorial — acceptance / **P1** |
| F3 | Gate M :217 | "Baseline vault paths remain unchanged and their applicable isolation/regression checks pass" can be read as requiring the full baseline regression suite at Gate M — Stage 2 consumer proof creeping into Stage 1. :202 already permits instantiating the unchanged baseline; the check's *scope* needs bounding. | Editorial / **P1** |
| F4 | §8 :202 | The isolation clause is purely prohibitive. Stage 1 must model "terminal placement" (Gate M :212) and checkpoints; without an explicit *positive* permission to depend on **unchanged** existing pure math/quoter/placement libraries, an implementer may either re-implement them (new divergence risk) or read any reuse as "smuggling." | Editorial / **P2** |
| F5 | A9/A10 :71–72; §8 Stage 1 :198 | Exact same-state parity is required for transition previews, but traversal needs bitmap words/`liquidityNet`/checkpoint state that a transition *snapshot* may not carry. Whether transition previews project supplied snapshots or read live chain state is unspecified; parity is otherwise unverifiable for that surface. | Engineering detail / **P2** |
| F6 | §7.1 :162 | The 64-core-step envelope is correctly flagged as a starting hypothesis, not a total budget. Still unnamed: the counter *dimensions* the plan must budget separately — discovery core steps, bitmap word reads (incl. empty-word scans), certification forward steps, placement evaluations, quote-path reads. | Engineering detail / **P2** |
| F7 | §11 :284; §13 :312–314 | License clause is correctly nuanced ("changed BUSL/GPL date is neither MIT permission nor a categorical no-port rule"). Gap: research record identifies the math dependency `uni-v3-lib` as GPL-2.0-or-later; Gate M's "licensing and dependencies cleared" (:216) should name it explicitly so clearance can't pass on the repo-level LICENSE alone. | Editorial / **P2** |
| F8 | §10 :257–268 | Route matrix correctly keeps idle token→exact-shares unsupported (forward solver ≠ inverse) and two-leg exact-output exit rejected. Consistent with D17; no action — recorded so the later plan does not "discover" an inverse by accident. | Settled / do not reopen |

**Verified-as-consistent (no change needed):** residual law (:100 retain-and-book vs Aperture refunds — matches D8/D16); placement ordering/attribution (A6 vs current planner `TransitionPlanner.sol:135–143`); blocked-state sleeve-only (A11, :270 — correctly states a sizing view *may* run in-session without authorizing pool actions); protection values/units (A8 vs D20/D25); outer-search honesty (:53, :300 — no search-free claim for the whole system); no gas-win promise (:235); no `minOut=0`/gas-conditioned quote/:272 pre-existing-behavior reporting; Pons separation (A14, D22–D29 ledger); narrow precedence (:29, :298 — only the Hookless composition row of old §6.3 replaced, Pons/repair prescriptions intact).

## 2. Stage 1 isolation and Gate M

The two-stage structure is sound: Gate M requires multi-step cases (:210 — blocks the one-segment narrowing trap), exact settlement parity at identical state (:211), complete placement+issuance within bounds (:212), quantified coverage (:214), adversarial work-limit enforcement (:215), license clearance (:216), and unchanged baselines (:217), with stop-and-record failure semantics (:219) and reopen-on-material-change at Stage 2 entry (:223). Nothing in Gate M requires Orbital/DETF consumer proof — consumer regression sits entirely in Stage 2 (:232). The isolation boundary (:202) correctly prohibits dispatch/facet/storage/DFPkg changes while permitting baseline instantiation. Two soft spots are F2 (undefined "resolved") and F3 (regression scope), both fixable with one clause each.

On "universal rejection cannot satisfy acceptance" — covered by :175–176 (positive success matrix frozen before tuning) and :214 ("universal or trivially narrow rejection cannot pass"). Good.

## 3. Traversal, work and gas acceptance

:160–162 correctly ban copying upstream's uncapped `crossTicks`/empty-word scan and gasleft-dependent bounds; :215 requires enforcement under zero-`L`, sparse-bitmap and adversarial cases; the 31M/32M nested caps appear only in Stage 2 performance (:251) — correct placement. No invented speedup (:235); matched-state benchmarking against the frozen original planner is Stage 2 (:233) with a library baseline in Stage 1 (:200, :251). Measurable without a gas claim: yes. The one missing piece is counter dimensionality (F6).

## 4. Suggested exact clauses (smallest sufficient changes)

**F1 (P1):** append to §6 after :143 —
> "The `A/B/C` formulas apply per swap direction with `(a, b)` re-bound to (input-leg, output-leg) incumbent backing and `(d, e)` to (caller input remaining, caller output accumulated). The implementation plan must independently expand and cross-check both directions against an independent reference derivation before Gate M; a direction shared by transcription is a defect."

**F2 (P1):** replace Gate M :214 with —
> "Candidate rejection/coverage is quantified against the frozen corpus: (i) zero case-2 missed solutions inside the frozen core corpus (both directions, sleeve `p ∈ {0, default, 1}`, LP-only and LP+protocol fees, the plan's core-step bound, mixed decimals); (ii) any case-2 outside the core corpus is reported with its characterized sub-domain and measured rate. A core-corpus miss fails the gate; an uncharacterized outside-corpus miss fails the gate."

**F3 (P1):** append to Gate M :217 —
> "Scope: checks sufficient to prove isolation (compilation of dependents, unchanged-library dependency tests, baseline behavior spot-checks on the affected surfaces). The full baseline/consumer regression suite is a Stage 2 obligation, not a Gate M obligation."

**F4 (P2):** append to §8 :202 —
> "Stage 1 may depend on unchanged existing pure math, quoter and placement components by reference; modifying any of them is a shared hot-path change and outside Stage 1."

**F5 (P2):** new bullet in §10 —
> "The implementation plan must enumerate the state fields every preview class requires (including bitmap words, `liquidityNet` at boundaries and fee checkpoints), and state for each preview class whether it projects the supplied transition snapshot or reads live state; parity claims are void for any class whose projection is unspecified."

**F6 (P2):** append to §7.1 :162 —
> "Budget separately, with named counters: discovery core steps; bitmap word reads including empty-word scans; certification forward steps; placement evaluations; total storage reads per quote path. The 64-core-step figure is the discovery-step starting hypothesis only."

**F7 (P2):** append to Gate M :216 —
> "Clearance must name each dependency and license, including `@aperture_finance/uni-v3-lib` (recorded in research as GPL-2.0-or-later) and the repo-level BUSL→GPL-2.0-or-later change; equation-level reimplementation remains the default absent counsel."

## 5. Owner questions

**None.** Candidates considered and discharged: final-product traversal semantics — already decided by A3 (bounded discovery; one-step is milestone only); case-2 tolerance — the PRD's own resolve-or-return default is the safe one and F2 merely makes it concrete; residual semantics — already fixed at :100; discovery-vs-strict-no-discovery — the owner's recorded direction (:35) already selects bounded discovery with a math-first gate. Asking any of these again would reopen settled direction without new evidence.

## 6. Readiness and what the later implementation plan must settle

**Recommended status: ready to drive implementation-plan authoring** once F1–F3 (P1) are folded in; F4–F7 are plan-level and can land in the plan itself. The plan must settle: per-direction coefficient expansions and width/discriminant/root-selection rules; the frozen corpus and named work counters; preview projection classes (F5); positive-permission reuse list (F4); named license clearance (F7); Gate M records format; and the Stage 2 matched-state benchmark corpus. No test execution, gas claim, or passing-tests-implies-safety claim is made here.
