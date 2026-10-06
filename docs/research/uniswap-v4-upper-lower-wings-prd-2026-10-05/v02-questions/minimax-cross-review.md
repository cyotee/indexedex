# MiniMax M3 — v0.2 questions cross-review

- **Inputs read in full:** `v02-questions/astra-original.md`, `v02-questions/grok-original.md`, `v02-questions/kimi-original.md` (untrusted attributed proposals; not authority). **No** peer cross-reviews read. Original preserved at `v02-questions/minimax-original.md`. **No** PRD edit, no shell, no tests, no code, no config, no instruction edit.
- **Method:** peer proposals compared against the current v0.2 PRD text and primary source. The user-specified exclusions (nonzero-conversion threshold, insufficient-sleeve revert, retained overage, permission to zap) are not reopened. Several peer claims are flagged as unproven or as scope creep.

## 1. Consensus on what is settled (do not reopen)

All three peers and my original agree the §15.1 list is settled. Specifically the user said not to reopen: the **nonzero-conversion threshold** for harvest eligibility, the **blocked requested/available atomic revert**, the **retained overage** policy, and the **permission for the rebalance to zap**. I confirm these are settled by §1.1, §5 G3, §7A, and §8 S2 and are not part of the owner-question set below.

## 2. Minimum genuine owner questions — blockers

I converged the three peer blockers onto a smaller set than any single peer raised. Two of the three peer-flagged "blockers" are not actually owner questions; they are engineering/proof obligations that should not be sent to the owner (see §5). The remaining genuine owner questions are:

**OB-1 — Mitigation policy for the manipulation window of V.** All three peers identify this; Kimi frames it as a hidden policy choice inside RV-2 (lines 372–373 of v0.2). The PRD says "current liquidation can be calculated" (line 156) and forbids "no automatic stale-price fallback, emergency basket exit or haircut" (line 156), but does not name a mitigation. An attacker who moves the pool's price can lower V (temporarily), mint at the deflated rate, let price revert, redeem at the restored V. The per-operation impact is real; the **mitigation policy is the owner choice**, not a math proof. Options:
- (a) accept spot V; document the bounded per-op extraction shape (`|price move| × opposing share × size − costs` per Kimi OQ-1) without claiming a global bound; the engineering plan measures and publishes the bound.
- (b) reference gate (pool spot vs TWAP, with units/window/failure mode) rejecting mints/redemptions when |divergence| > X bp; costs route availability during volatility.
- (c) size cap on per-tx mint/redeem; bounds bleed without gating availability.
- **Note:** Kimi's "extraction is bounded per operation by `|price move| × opposing share × size − costs`" is a sketch, not a proof. I am NOT endorsing this as a bound. I am flagging it as a *shape* the engineering plan can attempt to prove.

**OB-2 — Failure policy when complete V cannot be computed.** The PRD forbids both inventing proceeds for unsold opposing inventory (line 155) and freezing ordinary routes by default (line 156). These conflict when the simulated liquidation cannot be completed (e.g., own removal leaves no external depth anywhere, or traversal/representability limits). The owner must pick the failure policy:
- (i) revert the affected mint/redeem with a typed incomplete-liquidation error; block the route until depth returns.
- (ii) exclude the unsellable remainder from V (lowers V; helps new depositors, hurts redeeming holders).
- (iii) bounded partial valuation with an explicit, owner-approved haircut convention.
- **Note:** the "no external depth anywhere" state (after own removal) is different from "zero current active liquidity" (the pool is in an extreme state where the vault's positions are all one-sided and external LPs are also out of range). The mitigation must distinguish these; the engineering plan's state enumeration is engineering, but the *policy* per state is the owner choice.

**OB-3 — Incomplete-valuation policy: which routes freeze, which compute, which fall back.** This is OB-2's operational split. A single value of V drives both mint and redeem (line 168). Different routes have different sensitivity:
- **Quotes and rate-provider reads** (line 285): can revert without losing user value. Recommend (i) for these.
- **Mint and redeem**: cannot revert without freezing the user's operation. The owner must pick (i), (ii), or (iii) for these. The PRD does not pick.

**OB-4 — Mint formula ratification versus validation separation.** Grok asks the owner to "ratify the share-growth formula already written at V4 (line 172): `m = floor(S * (V_after - V_before) / V_before)`." This conflates two things. **Ratification** is the owner's policy choice to adopt whole-vault liquidation value as the basis; the formula is a candidate. **Validation** is the engineering proof that the formula preserves V/S in the actual state-transition (state ordering, contribution never double-counted, fee/loss attribution, integer bounds). I agree with Grok that the *basis* is settled (line 15 settles whole-vault liquidation as the basis) and that the owner should confirm the ratification. I do **not** agree that the owner should ratify the formula before the engineering validation passes; ratifying a formula that fails the validation costs rework. **Recommended order:** owner confirms the basis (a single sentence), engineering validates the candidate, owner ratifies the candidate only if validation passes. The PRD's line 178 wording "This candidate is not an owner-ratified formula" is correct as written; do not advance the ratification until the validation lands.

**OB-5 — Fee conventions: who pays what and where does it land.** All three peers flag this. The PRD requires "explicitly attributed operation fees" (line 174) and warns against double-charging V-internalized costs (line 186), but does not name a fee presence, rate, or destination. Owner must confirm:
- Operation fee: present? rate (e.g., 5 bp on the share-burn side, target units)? destination (feeTo vs incumbent backing)? on the share-burn base or the AMM/V-internal base?
- Entry placement loss: charged to the depositor (pre-mint deduction from credited C, line 174) or absorbed by incumbents (Kimi's recommendation)? Owner confirms.
- Simulated liquidation costs inside V (AMM fee, protocol fee) are **not** re-charged at settlement: confirmed by line 186. This is a hard rule; the owner ratifies it as written.

## 3. Minimum genuine owner questions — parameters (single batch)

I recommend one batch approval after the engineering plan proposes values. The user said not to reopen sleeve-zero confusion, retained overage, or permission to zap; these are out of the parameter batch.

**OP-1 — Sleeve numeric defaults.** §8 S1 lines 220–232 mark `p = 0.20e18` and the 5% relative deadband as proposals. Owner confirms or names different values; type-default + per-vault override pattern is settled.

**OP-2 — Bootstrap constants for target-only activation.** §7 V3 line 164 proposes: target-units-to-share decimal scaling, permanent share minimum, pre-existing-residual-to-sink. Owner confirms or names different constants. (The user said not to reopen the question of whether first entry must be dual-token; it must not. Bootstrap scope is set.)

**OP-3 — Maintenance protections and rebalance loss bound.** §8 S2 lines 236–243; RV-7. The plan must propose impact/holder-loss/progress/no-churn bounds. Copying FullSpread 25/50/10/1 bp is **not** authorized (line 311). Owner confirms the plan's proposed numbers.

**OP-4 — Platform / surface / gas margin.** RV-8 (line 379). Launch chains, native ETH/WETH (the v0.2 PRD defaults to ERC20-only at line 277 but does not ratify it), exact-output domains (line 268, RV-8 — the v0.2 PRD does not specify v1 support), SY lists (line 269), gas margin (line 348 — 90% is a proposal, not ratified). One batch approval; no single value is architecture-load-bearing.

## 4. Unproven peer claims flagged (not owner questions)

- **Kimi OQ-1 "extraction is bounded per operation by `|price move| × opposing share × size − costs`":** this is a sketch shape, not a proof. I am NOT endorsing it as a bound. The engineering plan may attempt to prove it; the owner is NOT asked to confirm the bound.
- **Kimi B3 "real conversion depth includes the vault's own remaining core liquidity, a strictly better rate than simulated under ordinary AMM concavity":** this is a structural argument, not a proof. The claim is that the *real* priority sequence converts the opposing wing *before* touching the core (line 207), so the AMM depth during that conversion includes the vault's own core. Whether this is *strictly better* depends on the actual price impact, fees, and remaining core size; the engineering plan must prove it, not assume it. The PRD itself says "A favorable constant-product example alone does not prove the general case" (line 192). I agree.
- **Kimi OQ-4 "sleeve-zero bootstrap condition":** Kimi conflates the policy and the mechanism. The policy is settled: blocked capacity collapses when `D_target ≈ 0` is a known consequence of "target-only sleeve on owned deployed target principal" (line 220). The mechanism recommendation ("require a minimum funded-sleeve bootstrap condition before the vault is consumer-eligible") is a **scope change** to the v0.2 PRD's "deferred liquidity initialization" thesis (line 13). I do not endorse it as a question for the owner; the engineering plan documents the bootstrap consequence and the consumer hook must already gate against low-cover (a hook-side requirement, not a vault-side change).
- **Astra "do not add another venue" implicit claim that partial V is unsafe:** the PRD already forbids partial proceeds (line 155). The "no other venue" recommendation is a corollary, not a new finding. The owner choice is OB-2/OB-3, not whether to add a venue.
- **Grok 4 "observe only during deposits; withdrawals realize positions only as needed by their settled priority":** the second half is a settled priority (line 206) and the first half is the §1.1 line 32 observation rule. The "withdrawals realize only as needed" is correct under the priority in §7A but the v0.2 PRD also says the withdrawal can use *available local target* (stage 1) before touching wings. I agree with Grok's framing; the owner confirms the observation-only on user deposits (OB-* — same as my prior OB-1/OB-5 here).

## 5. Document contradictions and unapproved assumptions flagged

- **§15.2 RV-1 and RV-2 mix engineering validation with owner policy choice.** RV-1 (line 372) is engineering (liquidation algorithm). RV-2 (line 373) mixes engineering (state ordering, contribution double-count) with the owner choice (basis ratification). I recommend the moderator split RV-2 into "basis selection" (owner choice, settled by line 15) and "formula validation" (engineering). Until split, the engineering plan may silently choose a convention where the PRD asks the owner a question.
- **§7 V3 line 164 "proposed convention"** is correctly parked in RV-6 (line 377). The acceptance checklist (line 385–395) should not pre-empt RV-6; no test plan should treat the V3 convention as selected until the owner confirms.
- **§8 S1 line 228 "At illustrative p=20%, 100 deployed corresponds to 20 local"** reads as a ratified number. The line 232 sentence immediately says "20% and 5% relative deadband remain proposals, not owner-confirmed numbers." The reader-facing text in line 228 should be re-flagged as illustrative so an implementer does not hardcode 20% into the acceptance checklist.
- **§5 G2 line 106 "put eligible opposing excess into its appropriate wing":** the opposing slot may be in-range/mixed at the time of deposit (its inner bound was fixed at an older price). G3 line 112 correctly classifies by current composition. The owner does not need to re-decide; the engineering plan must implement composition classification and the priority queue (stage 2 vs stage 4) explicitly. The owner is **not** asked whether the deposit can place into an opposing slot whose composition has changed; the answer is "no, classify by current composition, retain locally until rebalance."
- **§7 V1 step 4 "tick traversal, price movement and settlement rounding":** the V1 simulation includes tick traversal; §10 line 288 says "Three owned positions do not bound the number of external initialized ticks a swap can cross." The V1 simulation is therefore **expensive by design**. The PRD does not bound the simulation work. This is the single most important performance/cost risk in v0.2. I recommend the engineering plan specify a bounded tick-traversal budget per V call; outside the budget, the V is rejected (not partial, not stale-fallback). The PRD text should be tightened to make this an explicit bound, not an implicit one. This is engineering, not an owner question; I flag it because it materially affects OB-2/OB-3.

## 6. Mitigation policy vs engineers' proof duty (separation)

Kimi's OQ-1 mixes the two. I separate them:

- **Mitigation policy** (owner choice): accept spot V / reference gate / size cap / composition. These are sentences of policy; the owner picks.
- **Engineers' proof duty** (no owner involvement): per-operation bound under chosen mitigation; non-dilution proof; SEC witnesses; gas evidence; tick-traversal bound; rebalance loss bound; mixed-wing/core order within stage 4; full-fill detection in V simulation.

The owner is **not** asked to provide proofs. The owner is asked to pick a policy. The engineering plan then proves the chosen policy under the v0.2 PRD's required evidence standard (line 14).

## 7. Scope-creep flags (peer suggestions that would change v0.2)

- **Kimi OQ-4 "minimum funded-sleeve bootstrap condition":** would change the v0.2 PRD's "deferred liquidity initialization" thesis. Out of scope for owner question; the engineering plan documents the bootstrap consequence.
- **Astra "do not add another venue":** already implicit in line 155. Not a new scope cut.
- **Implicit "no oracle":** the v0.2 PRD does not require a rate provider in pricing or sleeve math. The fee-oracle `liquidReservePercentageOfVault(this)` is a fee-oracle query, not a pricing rate provider. If the moderator wants to keep it that way, the PRD should clarify in §10 line 286 that "where rates are required" applies to the fee-oracle read, with fail-closed semantics. If a rate provider is added later, that is a separate decision. **I am NOT** asking the owner to confirm "no oracle" — that is already the v0.2 design — only recommending the PRD text be tightened to make it explicit. (Earlier rounds' "no oracle prohibition inferred" caution still applies: the user has not prohibited a rate provider; v0.2 simply does not need one.)
- **Astra recommendation "ERC20-only v1":** this is a scope choice the user did not list as settled, but §1.1 line 277 implies it ("ERC20-only v1 may not claim native compatibility"). I keep this as OP-4 in the parameter batch, not as a forced scope cut.

## 8. Summary

**Blockers (4–5):**
- OB-1 Mitigation policy for V's manipulation window.
- OB-2 Failure policy when complete V cannot be computed.
- OB-3 Which routes freeze, compute, or fall back under incomplete V.
- OB-4 Mint formula: ratify basis now; ratify formula only after engineering validates.
- OB-5 Fee conventions: who pays what, where it lands, hard rule on V-internalized costs not re-charged.

**Parameter batch (one approval):** OP-1 sleeve defaults, OP-2 bootstrap constants, OP-3 maintenance protection, OP-4 platform/surface/gas margin.

**Owner is not asked for:** proofs, gas measurements, mixed-wing/core order within stage 4, tick-traversal bound, SEC witnesses, full-fill detection, the V1 simulation algorithm, the V-share effect proof, the harvest-scheduling implementation.

**Flagged unproven peer claims:** Kimi's per-op bound shape, Kimi's "strictly better" structural claim, Kimi's bootstrap-eligibility scope change, Astra's "no other venue" corollary, the V1 simulation work-bound gap.

**Not reopened per user instruction:** nonzero-conversion threshold, insufficient-sleeve revert, retained overage, permission to zap. The v0.2 PRD text on these is treated as final.

**Moderator recommendations:** split RV-2 into basis (settled) and formula-validation (engineering); tighten the "20%" illustrative wording in §8 S1; clarify the rate-provider vs fee-config distinction in §10 line 286; add an explicit V-simulation tick-traversal bound; ensure the acceptance checklist does not pre-empt RV-6 (bootstrap) or the parameter batch.

**Honest scope:** no proof, no simulation, no gas measurement, no measured security result. The five blockers are policy sentences with proposed defaults; the parameter batch is one approval pass. Engineering work is the implementation plan's job.

---

*Saved to `docs/research/uniswap-v4-upper-lower-wings-prd-2026-10-05/v02-questions/minimax-cross-review.md`. Original preserved. No PRD/shell/tests/code/config/instruction edits performed.*