# Wings PRD v0.2 — Kimi K3 original: questions vs obligations

**Author:** Kimi K3 (independent first pass; no peer artifacts). **Date:** 2026-10-05. Read: `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` v0.2 (412 lines), plus retained primary-source context. Research only; no execution. Settled items (§15.1 `:364-366`) are not reopened.

## Verdict

v0.2 is internally coherent on strategy and honestly marks the mint formula as a candidate (`:170-178`). The remaining owner-visible content is smaller than the register suggests: **two economic policy choices are currently disguised as verification work**, one capacity policy needs explicit acceptance, and everything else is either a small parameter batch or genuine engineering/proof obligation.

## A. Genuine owner questions (ranked; blockers first)

### OQ-1 (blocker) — Valuation manipulation policy, hidden inside RV-2 (`:373`)

`V` is a **current-state** hypothetical liquidation (`:140-148`). Spot is movable: an attacker pushes the pool so the vault's opposing inventory converts cheaply, lowering `V_before`, mints shares against the deflated rate, lets price revert, redeems at restored `V`. SEC-08 (`:301`) requires the witness but selects no mitigation, and §11 (`:311`) explicitly selects no oracle rule either. This is an **economic policy choice**, not a proof task:

- **(a) Accept** spot-liquidation valuation; extraction is bounded per operation by `|price move| × opposing share × size − costs`, and pool manipulation has real cost. Cheapest; honest disclosure.
- **(b) Reference gate:** reject mints/redeems when current liquidation deviates from a specified reference (units/window/failure mode all required); costs route availability during volatility.
- **(c) Size caps** on per-transaction mint/redeem (bounds bleed without gating availability).

Recommendation: decide explicitly among (a)/(b)/(c) or a composition; engineering then quantifies bounds. Do not let "validate the formula" (RV-2) silently settle it.

### OQ-2 (blocker) — Incomplete-liquidation valuation policy, hidden inside V2/RV-1 (`:152-158`, `:372`)

When opposing inventory cannot be fully converted in simulation (vault owns all depth, traversal/representability limits), V2 forbids crediting an assumed output — but does not say what V does instead, and each resolution transfers value differently:

- **(a) Exclude the unsellable remainder from V:** lowers V — **helps new depositors, hurts redeeming holders** (redeem at `floor(s·V/S)`).
- **(b) Block affected routes** until conversion is computable: no mispricing, but deposits/redemptions freeze exactly in stress states; conflicts with "not permission to … freeze all ordinary routes by default" (`:156`).
- **(c) Bounded partial valuation with an explicit, approved haircut convention** — currently not approved (`:156`).

Recommendation: (b) for quotes/rate-provider reads, with (a) or (c) for issuance/redemption only if the owner accepts the stated transfer direction. This cannot be delegated to the implementation plan as an algorithm detail.

### OQ-3 (blocker for formula freeze, small decision) — Fee conventions

V4/V5 assume "explicitly attributed operation fees" (`:174`) and warn against double-charging costs already inside V (`:186`), but no fee presence/rate/destination is selected anywhere. Decide: do deposits/redemptions carry a protocol fee (usage/dex via fee oracle), who receives it, and confirm simulated liquidation costs inside V are never re-charged at settlement. Without this, RV-2/RV-3 formulas cannot be frozen.

### OQ-4 (acceptance, not design) — Blocked-capacity policy

`F_target = p·D_target` (`:220-228`) implies blocked redemption capacity collapses when `D_target ≈ 0` — early bootstrap (target-only deposit, empty core) and price extremes (all-opposing states). S4 (`:253-255`) discloses this, but the **policy acceptance** should be explicit: consumers (Weighted/Orbital hooks buffering into this SE mid-outer-swap) will see atomic reverts in those states, failing their whole outer transaction. Options: accept with published cover semantics; or require a minimum funded-sleeve bootstrap condition before the vault is consumer-eligible. Recommend the latter as an eligibility note, not a mechanism change.

### OQ-5 (small) — Harvest scheduling (RV-4, `:375`)

Options: observe-only on user routes + separate permissionless rebalance (recommended: keeps user-route gas bounded, matches §1.1 `:32-33`), or bounded harvest inside idle user calls (adds bounded but nonzero cost to every route). Recommend observe-only; needs owner confirmation because it shifts harvest cost/latency to whoever calls rebalance.

### OQ-6 (parameter batch, not blockers)

Sleeve `p` and deadband (`:232` — 20%/5% are marked proposals, correctly), bootstrap scale/minimum/sink constants (V3 `:160-164`, RV-6), gas margin (`:348` — 90% of verified cap), target chains, native ETH (`:277`), exact-output domains (`:268`), SY lists (RV-8). One approval batch; no single value is load-bearing for the architecture.

## B. Engineering/proof obligations (do NOT ask the owner)

1. **RV-1 algorithm** (`:372`): the exact ordered liquidation simulation — collect E once, remove all three positions with exact rounding, convert opposing through post-removal external depth, bounded traversal, projected-state correctness in nested contexts (`:150`, `:281-284`).
2. **RV-2 formula validation (proof part):** state ordering, contribution never double-counted (`:168`, `:373`), zero-mint atomic rejection (`:176`), integer bounds.
3. **RV-3 coverage/non-dilution proof** (`:190-198`, `:374`): show staged real execution covers `floor(s·V_before/S)` within bounded overshoot. Note the favorable structural fact the proof should exploit: the V simulation removes **all** own liquidity before converting (`:148`), while the real priority sequence converts the opposing wing **before** touching the core (`§7A :206-207`) — so real conversion depth includes the vault's own remaining core liquidity, a strictly better rate than simulated under ordinary AMM concavity. The proof must still cover fees, integer rounding, tick granularity and extremes; a favorable-CP example alone is explicitly insufficient (`:192`).
4. **SEC witnesses** (`:292-309`), especially SEC-03 (target-donation inflation against the V-based mint: donating target raises `V_before` and cuts the victim's mint — the sink/minimum conventions must be proven, RV-6), SEC-13 (no fabricated proceeds), SEC-14 (terminal V/share).
5. **Rate-provider semantics** (`:285`): one-share rate = canonical `V/S`, not a single-share liquidation; consumers' providers must honor the economic-rate vs executable-cover distinction — integration verification.
6. **Gas evidence** (`:338-350`): canonical V is recomputed by rate providers per read; `:347`'s warning (quote cost can recreate the composability failure without any swap) is an acceptance-measurement obligation.

## C. Document contradictions / unapproved assumptions to flag (not owner decisions)

1. **RV-2 and RV-1 contain policy choices** (OQ-1, OQ-2) while §15.2 frames them as validation work (`:372-373`, `:381`). Reword so engineering doesn't "resolve" them by choosing a convention.
2. **S1 numeric text reads settled but is marked proposal** — `:228` "At illustrative p=20%…" vs `:232` "20% and 5%… remain proposals". Keep the marking; ensure the acceptance checklist (`:391`) doesn't hardcode 20%.
3. **G2 opposing-excess placement timing gap** (`:106`): "put eligible opposing excess into its appropriate wing" — but the opposing slot may currently be in-range/mixed (its inner bound was fixed at an older price), and G3/§7A correctly classify by current composition (`:112`, `:210`). Between eligibility observation and close/reopen, the only legal destination is local retention (`:108`); the PRD should say that ordering explicitly rather than imply immediate wing placement.
4. **§1.1 priority vs §7A stage 2 wording:** `:29` "consume target-token wing" and `:206` "out-of-range wing currently holding the target token" are consistent only because composition classification (`:210`) governs; fine, but the checklist (`:390`) should test a target-opened wing that has partially converted (now mixed/in-range) to lock the classification rule.
5. **V3 "proposed convention"** (scale target units into share units, lock explicit minimum, residual value to sink, `:164`) is unapproved — correctly parked in RV-6; ensure no test plan treats it as selected.
6. **Wings are half-range, not concentrated:** G1 (`:95-96`) extends each wing from just outside current price to the usable limit — wide, low-density, one-sided-at-creation. Document is consistent about this; just don't let migration notes or gas estimates import historical "concentrated wing" assumptions (`:50-52` already bars that).

## D. What is NOT a question (settled, §15.1)

Target-only flows and activation; whole-vault liquidation basis; full-range core + nearest-outside-to-limit wings; observation-triggered harvest eligibility; separate rebalance may zap; target-only sleeve on owned deployed target principal; opposing-wing before core; sufficient realization with retained overage; typed requested/available blocked error (`:249`); FullSpread untouched.

## Honest scope

Static reading only; no execution, no simulation of V; the OQ-1 extraction sketch is analytical; no formula here is claimed safe; parameter recommendations (observe-only harvest, block-quotes-on-incomplete-liquidation) are reviewer recommendations for owner decision, not ratification.
