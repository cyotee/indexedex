# MiniMax M3 — Aperture PRD requirements review: combined cross-review

**Date:** 2026-10-03. **Round:** `Aperture PRD requirements review` (current). **Read originals:** `astra-original.md`, `grok-replacement-original.md`, `kimi-original.md` as UNTRUSTED attributed model evidence. **No** peer cross-review/synthesis read. Target PRD (`docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md`, 334 lines) preserved unchanged. No implementation/delegation/shell/test/deploy/config edits. Notation: **T** = target PRD; **H** = current Hookless prefix under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`.

## 1. Attribution table — where the three converge

| Finding | Astra | Grok replacement | Kimi | Mine (chat-returned after denied write) |
|---|---|---|---|---|
| Stage 1 isolation: `consumer success` must not require Stage 2 consumer proof | P0 row 1, §1 | P0 row 1, §Stage 1 | F3, §Stage 1 isolation | Finding 1 (chat) |
| License default = clean-room reimplementation (Aperture BUSL→GPL-2.0-or-later, uni-v3-lib GPL-2.0-or-later) | §6, P2 row | P2 row, §Preservation | F7, §4 (clearance memo) | Finding 3 (chat) |
| Case 2 escalation: "resolved" must be quantified against frozen corpus; case-2 miss in core corpus fails gate | §3, F1 | §Stage 1 last ¶ | F2, §4 | Finding 2 (chat) |
| Bitmap / word / certification / placement-read as separate counters; 64-step = starting hypothesis only | (in P1 row 5 indirectly) | P1 row 2 | F6, §4 | Finding 4 (chat) |
| Rounding correction = owner amendment if introduced; not Stage 1 scope | §6 ("trial stencil follows the amendment procedure") | (P1 row 2 last sentence — "if corpus shows it is required, stop and return to the owner") | — | Finding 12 (chat, less explicit) |
| Direction expansion: token0→token1 only; token1→token0 not written | — | — | F1, §4 | — (I missed this) |
| `phi` vs `f` semantic split (fraction vs combined pip) | — | P0 row 2 | — | — (I missed this) |
| Transition-preview projection: live state vs supplied snapshot, unspecified | — | — | F5, §4 | Finding 13 (chat, weaker) |
| Unlocked-view trap: PRD §10 sentence reads as "view computes `x` then swap" | — | P0 row 3 | — | — (I missed this as P0) |
| `_maintenance` must stay in redeem/external-exchange quotes; A13 + §3 do not remove it | — | P1 row 4 | — | — (I missed this) |
| Old planner is comparator, not oracle; may label case 2/3 only | (implicit in §3) | (implicit) | F8, §1 | Finding 4 (chat) |
| Performance acceptance: gas win is not the pass rule | §5 | §Liveness | §Preservation | Finding 5 (chat) |
| Stage 1 placement = pure replica in harness, not vault call | — | P1 row 3 | — | — (I missed this) |
| Baseline regression check scope: Stage 1 needs only compile + spot-check, not full consumer suite | §2 (implicit) | P0 row 1 | F3, §4 | Finding 2 (chat) |
| Owner questions | **1** (baseline failure gating) | **None** | **None** | **3** (over-cautious) |
| PRD readiness | ready for Stage 1 plan with the clarifications | fit for plan after P0; not fit for Stage 2 | ready to drive plan after F1–F3 (P1) | "mostly authored; clarifications all editorial/owner-decision" |

**Strong convergence**: 4 of the 4 originals agree on Stage 1 isolation, license clean-room default, case-2 quantification, and performance-not-a-pass-rule.

**Key specific corrections my original missed (Kimi/Grok):**
1. Token1→token0 coefficient `β = L·g/s², γ = g/s` not explicitly expanded with its own `A/B/C` (Kimi F1).
2. `phi` is a fraction of gross input; `f` is the combined pip fee; the PRD's symmetric direction formulation risks implementers transcribing `phi` to the raw protocol-fee field (Grok P0 row 2).
3. PRD §10 sentence "A sizing view can technically run during an unlocked session" is ambiguous; reads as "view computes `x` then swap" (Grok P0 row 3).
4. `_maintenance` must remain in redeem/external-exchange quotes until a separate D18–D19 amendment (Grok P1 row 4).
5. Stage 1 placement must be a pure replica checked against `BalanceDelta` in a harness, NOT a vault call (Grok P1 row 3).
6. Transition-preview projection classes (live vs supplied snapshot) must be enumerated per preview class for parity to be verifiable (Kimi F5).

## 2. Withdrawals from my original

I had three owner questions. After convergence with the three originals:

- **Q1 — License / clean-room default**: I had this as an owner question. All three originals record it as a **default** (clean-room; equation-level reimplementation; Gate M fails closed if the diff contains Aperture source without license review). **Withdraw.** Default is locked by Kimi F7 + Grok P2 + my chat F3.
- **Q2 — Bitmap-read cap as separate named constant**: I had this as an owner question. All three originals record it as a **plan-engineering deliverable** (Kimi F6: "the 64-core-step figure is the discovery-step starting hypothesis only"; Grok P1 row 2: "Discovery, word reads, and the one certification forward pass have separate counters. The initial discovery ceiling is 64 core steps and a separate bitmap-word ceiling set in the plan before the corpus freeze"). **Withdraw.** Plan must settle it before Gate M corpus freeze.
- **Q3 — Case 2 escalation gate**: I had this. Astra's Q1 reformulates it as the **single genuine blocking owner question**, with a recommended default (yes for Stage 1, no for integrated delivery). Kimi says "none" with default = PRD's "do not shrink inside Gate M; Stage 2 returns". Grok says "none" with default = "if a frozen positive case that the new library rejects, do not shrink the domain inside Gate M. Return with the counterexamples." **Retain as the single owner question.**

## 3. Single blocking owner question (consolidated, default recommended)

**Q1 (consolidated) — baseline failure gating vs absolute required Stage 2 success.** If a mandatory nested consumer (Orbital or DETF) remains blocked by a pre-existing correctness defect outside this refactor, may this effort finish with **Gate M passed / Stage 2 blocked**, while a separately authorized correction is tracked as a dependency? Equivalent question, also raised by the prompt: should Stage 2 be allowed to start despite a pre-existing consumer fail, or must Stage 2 wait until every consumer integration is fixed?

**Recommended default:** **Yes for Stage 1 completion, no for declaring integrated delivery complete.** Stage 1 may pass Gate M with documented baseline failures in unchanged consumer surfaces. Stage 2 may not begin a "delivered" declaration if a mandatory consumer integration remains blocked. Owner approval is required for any amendment that would change a protected product decision (A1–A15) before Gate M re-runs. The pre-existing consumer failure must be re-expressed as a separate integration gating item with a quantified correction plan; this refactor does not bless it as "search-free" silently.

This is identical to my original Q3 wording, with the addition of the A1–A15 gate-amendment constraint that Astra §6 implies and that the prompt explicitly audits ("preserve... current scalar and ownership choices are settled unless contradiction shown").

## 4. Reconciled P0 / P1 / P2 suggested clauses

Each clause below is prioritized and attributed. Bracketed placement notes show where in T the clause belongs. **None of these is an owner question; all are editorial or engineering-detail per the three originals.**

### P0 — Stage 1 isolation, license clean-room, unlocked view, `phi`/`f` semantic split

**(a) Stage 1 isolation + baseline regression scope** (Astra P0 row 1; Grok P0 row 1; Kimi F3):
> "Before Stage 1 implementation, record applicable baseline pass/fail results and known policy violations by source/test/artifact revision. Distinguish refactor-induced regressions, pre-existing failures, and failures exposed by stronger validation. Gate M's baseline check scope is limited to compilation of unchanged dependents and spot-checks on affected surfaces; the full baseline/consumer regression suite is a Stage 2 obligation, not a Gate M obligation. A required Stage 2 consumer integration blocked by a pre-existing out-of-scope defect remains an integration dependency: obtain a separately specified and authorized correction, or return for an explicit scope decision."

Placement: at T §8:217 (Gate M baseline clause) and T §1:15 (Stage 1 isolation boundary).

**(b) License default + clean-room Gate M fail-closed** (Astra P2 row; Grok P2 row; Kimi F7):
> "Default is clean-room reimplementation of the equations in T §6. Copying Aperture source is forbidden unless a recorded license review clears that exact pin and its dependencies. Gate M's licensing clearance must name each dependency and license, including `@aperture_finance/uni-v3-lib` (recorded in research as GPL-2.0-or-later) and the Aperture repo-level BUSL→GPL-2.0-or-later change license (Change Date 2026-07-01 passed). Equation-level reimplementation remains the default absent counsel. Gate M fails closed if the diff contains that source without the review."

Placement: at T §8:216 (Gate M licensing clause) and T §13 (pinned LICENSE).

**(c) Unlocked view sentence replacement** (Grok P0 row 3):
> Replace T §10 the unlocked-sentence cluster with: "While the manager is unlocked, quote and execution stay on the existing local-admission formulas. The analytic planner is idle-only. A view that reads pool state during an unlock does not authorize `manager.swap` or `manager.modifyLiquidity`. A transition-quote preview that returns a deterministic non-zero value during an unlocked session is an untrustworthy preview and must revert."

Placement: at T §10:270–271.

**(d) `phi` vs `f` semantic** (Grok P0 row 2):
> "`f` is the combined combined-pip fee over 1e6, computed as `protocol + lp − floor(protocol·lp/1e6)` per Crane V4 `ProtocolFeeLibrary.sol:35–46`. `phi` is the directional protocol tokens taken per unit of gross input **after** the core split, i.e., the LP share of V4's gross-input protocol take, not the raw protocol-fee field. Stage 1 must derive both from the core and must reject a transcription that treats the explanatory formulas as already Q96-certified. The token1 `beta`/`gamma` form (`β = L·g/s²`, `γ = g/s`) is checked against `SqrtPriceMath`, not assumed."

Placement: at T §6:118–127.

### P1 — Direction expansion, case 2 quantification, work counters, transition-preview projection, `_maintenance` preservation, Stage 1 placement purity

**(e) Direction expansion (Kimi F1):**
> "The `A/B/C` formulas at T §6 apply per swap direction. For token0→token1 the PRD states `(β = L·g·s², γ = g·s)` and `α = ρ·(1−φ)`. For token1→token0 the symmetric form is `(β = L·g/s², γ = g/s)` with `α = ρ·(1−φ)` unchanged and `(a, b)` re-bound to (input-leg, output-leg) incumbent backing, `(d, e)` re-bound to (caller input remaining, caller output accumulated). The implementation plan must independently derive and cross-check both directions against an independent reference before Gate M; a direction shared by transcription is a defect."

Placement: at T §6 after the `A/B/C` block.

**(f) Case 2 quantification (Astra §3; Grok; Kimi F2):**
> "Case 2 ('valid integer exists but analytic candidate fails') is **not** an automatic acceptable product restriction. Candidate rejection is quantified against the frozen core corpus: (i) zero case-2 missed solutions inside the frozen core corpus (both directions, sleeve `p ∈ {0, default, 1}`, LP-only and LP+protocol fees, the plan's core-step bound, mixed decimals, both active and inactive `l`); (ii) any case-2 outside the core corpus is reported with its characterized sub-domain and measured rate. A core-corpus miss fails Gate M; an uncharacterized outside-corpus miss fails Gate M. The frozen positive-corpus enumeration must precede any candidate-specific tuning."

Placement: at T §7.3:175–183 and T §8:214.

**(g) Work counter dimensions (Grok P1 row 2; Kimi F6):**
> "Budget separately, with named counters: discovery core steps; bitmap word reads including empty-word scans; certification forward steps; placement evaluations; total storage reads per quote path. The 64-core-step figure is the discovery-step starting hypothesis only and does not cover the other counters. Hitting any counter's named cap is a work-limit reject, not a second solve."

Placement: at T §7.1:162.

**(h) Transition-preview projection classes (Kimi F5):**
> "The implementation plan must enumerate the state fields every preview class requires (including bitmap words, `liquidityNet` at boundaries, fee checkpoints, and live pool price), and state for each preview class whether it projects the supplied transition snapshot or reads live chain state. Parity claims are void for any preview class whose projection is unspecified."

Placement: at T §10 (transition-quote row).

**(i) `_maintenance` preservation (Grok P1 row 4):**
> "Replacing `HTransitionPlanner._composition` does not remove `HTransitionPlanner._maintenance` from redeem or external-exchange quotes. Those calls stay until a separate D18–D19 amendment. Their presence in end-to-end measurements is not failure of A4 or A13."

Placement: at T §A13 (or §3 scope preservation list).

**(j) Stage 1 placement = harness-only pure replica (Grok P1 row 3):**
> "Stage 1 placement is a pure replica checked against PoolManager deltas in a harness. It must not call Hookless facets. Gate M's 'match V4 core settlement' means that harness, not a production deposit. Shared hot-path changes that would affect existing money paths cannot be smuggled in as 'library preparation.'"

Placement: at T §8:202 (Stage 1 isolation) and T §8 Gate M 'match V4 core settlement' clause.

### P2 — Rounding correction, license memo format, licensee authority

**(k) Rounding correction = owner amendment (Astra §6; Grok P1 row 2):**
> "'One candidate' refers to swap-amount generation. It does not remove the currently required finite placement evaluation. Any rounding correction shall specify a mathematical error bound, deterministic selection rule, maximum work, and the economic amount being corrected before it is admitted to the frozen gate design. Candidate failure cannot silently trigger neighbor trials, a smaller deposit or changed placement payer. A necessary trial stencil follows the amendment procedure in A16."

Placement: at T §7.2:168–169.

**(l) License memo format (Kimi F7):**
> "Gate M's licensing clearance memo format: pinned Aperture LICENSE text + SPDX headers of all transitive dependencies (V3 core, V3 periphery, OpenZeppelin, Solady, `@aperture_finance/uni-v3-lib v3.0.3`) + combined-work analysis + explicit owner-authorized decision between clean-room reimplementation (default) and source porting (only with counsel sign-off)."

Placement: at T §13.

**(m) Licensee authority** (Astra Q1's phrasing; my original Q1's substance):
> "An owner decision is required to amend any of A1–A15 before Gate M re-runs. Library/specification corrections that do not amend A1–A15 may be applied without owner approval; corrections that would amend A1–A15 must be returned to the human with a quantified domain change before Gate M re-runs."

Placement: at T §8 Gate failure behavior.

## 5. Engineering-detail clarity that does NOT need an owner decision

The three originals agree these belong in the later implementation plan (T §14 already says so):
- Exact file/component map and library interfaces.
- Scaled arithmetic specification, signed widths, discriminant computation (T §6 last paragraph).
- Per-direction coefficient expansions and width/discriminant/root-selection rules (clause (e)).
- Frozen test/domain matrix with named work counters (clauses (f), (g)) and preview projection classes (clause (h)).
- Independent reference methodology and benchmark corpus (T §7.3, §8).
- Explicit Gate M record format (T §8, clause (l)).
- Stage 2 matched-state benchmark corpus (T §8 Stage 2 items).
- Bitmap-read cap as a separate named constant (clause (g), plan-level).

**None of these is asked of the owner.**

## 6. Withdrawals and corrections summary

- **My original chat-returned finding 4 (bitmap cap) → withdrawn as owner question; retained as plan-engineering deliverable.**
- **My original chat-returned finding 3 (license) → withdrawn as owner question; retained as default with clauses (b) and (l).**
- **My original chat-returned finding 2 (case 2 escalation) → retained as the single owner question, reformulated as Q1 with the A1–A15 gate-amendment constraint.**
- **My original missed Kimi F1 (direction expansion) → added as clause (e).**
- **My original missed Grok P0 row 2 (`phi`/`f`) → added as clause (d).**
- **My original missed Grok P0 row 3 (unlocked view) → added as clause (c).**
- **My original missed Grok P1 row 4 (`_maintenance`) → added as clause (i).**
- **My original missed Grok P1 row 3 (Stage 1 placement purity) → added as clause (j).**
- **My original missed Kimi F5 (preview projection classes) → added as clause (h).**
- **My original missed Kimi F4 (positive permission for unchanged-pure reuse) — recorded but I won't add a new clause; T §8:202 + clause (j) already permit it implicitly.**

## 7. Recommended PRD readiness

**Status: ready to drive implementation-plan authoring** once the P0 clauses (a)–(d) are folded in. P1 clauses (e)–(j) are plan-level and can land in the plan itself. **No P0 contradiction with settled law was found.** P2 clauses (k)–(m) are editorial refinements.

**The single blocking owner question** (Q1, §3 above) does not block Stage 1 plan authoring. **It gates Stage 2 start and post-Gate-M domain changes.**

**What the later implementation plan must settle (not this PRD):** exact file/component map; scaled arithmetic specification; per-direction coefficient expansions and width/discriminant/root-selection rules; named work counters including bitmap-read work; preview projection classes; frozen test/domain matrix with explicit corpus size and independence definition; independent reference methodology; benchmark corpus; explicit Gate M record format; bitmap-read cap as a separate named constant; license memo with combined-work analysis. **None of these is a new product decision.**

## 8. Confidence and gaps

**High confidence:** PRD preserves D1–D31, sleeve, blocked-state policy, Pons separation, no hidden legacy fallback, no `minOut=0`/gas-conditioned quote, no NAV/oracle/idle-CP change. Stage 1 isolation is correctly stated. Case 2 quantification, license clean-room default, and Stage 1 placement purity are the right editorial clarifications.

**Medium confidence:** Owner-amendment gate for A1–A15 (consistent across the three originals, but phrasing is editorial; an exact clause added as clause (m) but not yet "owner-signed").

**Lower confidence:** Practical corpus size, exact bitmap-read cap value, transition-preview projection classification completeness — these are plan-level engineering details not yet determined.

**Gaps (not retried):** none local to this round; no peer reads; no missing files; no guard events; no SDK unavailability.

**Stop for human decision; no PRD amendments silently applied.**

**Saved:** `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/research/aperture-prd-review-2026-10-03/minimax-cross-review.md`. Originals preserved unchanged. No consensus, no measured gas claim, no implementation authorization.