# MiniMax M3 — v0.2 PRD questions for owner review

- **Date:** 2026-10-05
- **Author:** MiniMax M3 (independent first pass; no peer artifacts, no prior council files read this round; PRD v0.2 + CLAUDE + canonical skills + the historical full-range PRD cited in §2 re-read directly)
- **Inputs read directly:** `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` (v0.2, 412 lines, observed 2026-10-05); `CLAUDE.md`; `.claude/skills/indexedex-testing/SKILL.md` lines 25–37, 152–186; `lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md` lines 86–105, 180–238, 352–368; the prior PRD's own pointer to `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md:66–114` (historical reference, not restored).
- **No** shell, git, tests, code, config, instruction, or PRD edits performed.
- **Status:** v0.2 supersedes the older full-range / finite-center / pricing assumptions used in prior rounds. Earlier geometric-invariant pricing discussions are research history, not the selected valuation basis (v0.2 line 15). I do not reopen the owner's settled choices below.

## 0. Owner-settled choices from v0.2 §1.1 (NOT questions)

- Target-only user flows and target-only activation (line 28).
- Each instance binds one immutable target token (line 25).
- Full-range core + nearest-boundary-to-extreme wings (lines 26, 31, 90–98).
- Shares referenced to current hypothetical whole-vault liquidation into the target token (line 27, V1 line 140).
- Opposing-wing liquidation **before** core (line 29; §7A line 206).
- Sufficient realization/retained overage (line 30; §7A line 212).
- Observation-triggered harvest eligibility upon actual conversion (line 32; §5 G3 line 112).
- Separate permissionless rebalance allowed to zap (line 33; §8 S2 line 238).
- Target-only sleeve on owned deployed target principal, no required opposing sleeve (line 224; §8 S1 line 228).
- Blocked-state atomic revert with typed error carrying both amounts (line 249).
- Existing FullSpread Hookless + Pons-family preserved unchanged (line 24).

## 1. Genuine owner questions — ranked

I separated these into **blockers** (release-stopping, must be answered before the implementation plan can start) and **parameters** (numeric / categorical choices the owner can delegate to a future plan if the default is acceptable). I also flagged contradictions and unapproved assumptions separately in §3.

### Blockers (Q1–Q5)

**Q1 — Gross-vs-net fee convention on redemption.** The PRD defines `grossTarget = floor(s · V_before / S)` (V5 line 184) and says the user "bears the specified operation fees" while "simulated liquidation costs already reflected in V must not be charged again under another name" (V5 line 186). It does not name the operation fee base. Two interpretations:
- (a) The operation fee is a separate charge on the share-burn side, paid in target-token units on top of `grossTarget`. Net = `grossTarget - operationFee` (target units).
- (b) The operation fee is a separate charge on the credited-input side, paid outside the vault before the burn.
- **Why this matters:** under (a) the redeemer's net is `gross - fee`; under (b) the redeemer's net is `gross` and the caller paid the fee pre-call. The PRD's wording ("specified operation fees" with no base) is ambiguous. Suggested default: **(a)** because it matches the prior-round convention of "initiator pays operation fees" and avoids the on-the-side dual charge. Owner to confirm.

**Q2 — Exact-output support in v1.** §9 line 268 says "Exact-output target/share routes: Specify supported integer inverse and caller maximum; do not infer support from approximate linear arithmetic." The PRD has not yet specified whether v1 supports exact-output target or exact-output share. Suggested options:
- (a) v1 supports exact-input target deposit and exact-input share redemption only; exact-output is out (matches §3 line 65 "public opposing-token routes and a proportional basket-exit fallback" as out-of-scope, but exact-output share on the same target token is not explicitly excluded).
- (b) v1 supports exact-input target deposit and exact-input share redemption; the later plan proves exact-output share redemption by an integer bisection on the forward function (analogous to `StandardExchangeConstantProduct._sharesForSingleExit:113–129`), and the corresponding maximum-shares-burned ceiling is bounded.
- **Why this matters:** the route table in §9 line 261 needs an explicit yes/no for "Exact-output target/share routes" and a bounded integer inverse if yes. Without this, the route contract is incomplete.

**Q3 — Harvest scheduling on normal idle user calls.** §1.1 line 32 says "Recognize a wing as harvest-eligible upon actual conversion, on a subsequent transaction that observes it; no autonomous execution or full-crossing requirement." §5 G3 line 114 says "Whether every eligible idle user transaction must also perform a bounded harvest remains an explicit scheduling decision in §15." This is owner-routed. Suggested options:
- (a) Idle user calls only **observe** eligibility and never perform a harvest. The rebalance is the only path that performs a harvest. (Cheapest idle path; bounded rebalance may stall and overshoot accumulates.)
- (b) Idle user calls **observe** by default but perform a bounded opportunistic harvest when a single eligible wing can be settled in a bounded number of operations (e.g., 1 swap + 2 liquidity removals/adds). The rebalance still handles core-addition and complex multi-wing sweeps.
- (c) Idle user calls always perform a bounded harvest before proceeding to the user's deposit/redeem (most expensive; defeats the "ordinary entry must not invoke the expensive zap" spirit of line 108).
- **Why this matters:** (a) leaves the harvest work to the rebalance and may cause larger per-rebalance transactions; (b) keeps the user's path bounded but adds slight cost; (c) re-invokes the expensive zap on user paths that the PRD explicitly excludes (line 108).

**Q4 — Native ETH support in v1.** §1.1 does not list native ETH as settled. §3 line 65 says "Native ETH/WETH treatment must be resolved in §15; do not silently advertise it." §9 line 277 says "Native ETH decision must explicitly define WETH face, PoolKey order, `msg.value`, wrapping/refunds, surplus native custody and receiver reentrancy. ERC20-only v1 may not claim native compatibility." Suggested options:
- (a) ERC20-only v1: the pool currency is the ERC-20 token at the address in the PoolKey; no `msg.value` path; no native ETH accepted (matches "ERC20-only v1 may not claim native compatibility").
- (b) WETH-wrapping v1: native ETH is accepted on deposit (wrap to WETH), paid on redemption (unwrap to native), with explicit face accounting, no surplus native held outside the wrap.
- **Why this matters:** without an owner ruling, the implementation cannot decide whether to support a `msg.value` path, native-ETH accounting, and receiver reentrancy protection. (a) is the smaller, safer choice for v1.

**Q5 — Mint formula ratification.** §7 V4 line 170–174 names a candidate: `m = floor(S · (V_after − V_before) / V_before)`, and line 178 says "This candidate is not an owner-ratified formula." §7 V4 line 178 also says "No min-ratio across both currencies, internal-CP mint or oracle-NAV substitute may be silently selected instead of the whole-liquidation value basis." The candidate is described, the substitutes are forbidden, and the ratification is pending. Owner decision: **ratify the V-growth candidate, ratify a different whole-liquidation value formula, or defer ratification pending an engineering exercise.** If deferred, the PRD cannot ship to an implementation plan because the mint math is the primary interface.

### Parameters (Q6–Q11) — owner can delegate or pick a default

**Q6 — Sleeve numeric defaults.** §8 S1 line 232 says "Numeric default, bounds and absolute/relative deadband require approval; 20% and 5% relative deadband remain proposals, not owner-confirmed numbers." Owner to confirm:
- `pWad` default (proposed 0.20e18 / 20%): confirm, change, or specify type-default + per-vault override.
- `ABSOLUTE_FLOOR` formula (proposed `10^max(0, decimals - 6)` from local liquid buffer PRD): confirm or change.
- `RELATIVE_TOL_WAD` (proposed 0.05e18 / 5% relative): confirm or change.
- Effective-zero behavior: if `D_target = 0` (no target deployed), the target relation alone does not guarantee cover; line 230 says "account for retained local inventory without calling it an opposing sleeve or promising continuous capacity." Confirm the policy: "if `D_target = 0`, sleeve target is `F_target` floor of `F_target·p/(1+p)` and cover-or-revert is the rule" — owner to confirm or specify differently.

**Q7 — Bootstrap constants for target-only activation.** §7 V3 line 164 proposes: "initially scale target units into share units and permanently lock an explicit small share minimum, while assigning pre-existing liquidatable residual value to the sink rather than the first depositor. Exact constants/formulas remain in §15." Owner to confirm or specify:
- Target-to-share decimal scaling (the proposed convention suggests 1e18 WAD or a token-specific scale).
- Permanent share minimum (analogous to FullSpread's `MINIMUM_LIQUIDITY = 10^(mean(decimals)-3)` but for a single token).
- Pre-existing-residual treatment: "assign to sink" is a proposal; the alternative is to refund the residual to the caller or to credit it as the first deposit (each has different economic consequences).

**Q8 — Withdrawal overage placement when rebalance is not called.** §7A line 212 says retained overage "is placed in the appropriate one-sided wing subject to sleeve/rounding constraints." If no rebalance is called for a long time, overage accumulates in the target sleeve. Once the sleeve hits its target, additional overage has no placement path short of a rebalance. Owner to confirm: the overage stays in the local target sleeve above the configured target until a rebalance runs. (This is implied; confirm explicitly so the implementation doesn't try to auto-place.)

**Q9 — Stage 4 deterministic removal priority among mixed wings and core.** §7A line 210 says "Within stage4, the deterministic removal priority among mixed wings and core must be specified and tested; do not silently reverse stage3 versus core." The order stage3 → stage4 is settled. The within-stage4 order is not. Suggested deterministic order: "out-of-range mixed wings first (in salt order), then core; mixed in-range wings are part of stage4, ordered by salt." Owner to confirm or specify a different deterministic rule.

**Q10 — Gas acceptance ceiling.** §13 line 348 says "Proposed acceptance ceiling is at most 90% of the verified transaction cap for required successful production workloads, subject to owner approval." 90% is a proposal. Owner to confirm or specify (e.g., 80%, 95%, or "must fit inside EIP-7825 with no margin").

**Q11 — What counts as "actual conversion" for harvest eligibility.** §1.1 line 32 says "Recognize a wing as harvest-eligible upon actual conversion" and §5 G3 line 112 says "Compare precise principal amounts and actual price/range state, including integer dust and reversals. A pending eligible wing must never be treated as still one-sided for additions." The threshold of "actual" is undefined. Suggested default: a wing is harvest-eligible when the **opposing-token principal of that wing exceeds a configured minimum (e.g., 1% of the wing's `D_target` at creation, or a token-floor absolute amount, whichever is larger)**. Owner to confirm the threshold rule.

## 2. Unapproved assumptions and questions buried in the PRD that the implementor would otherwise have to interpret

These are not full owner questions but places where the text reads as if a default has been adopted when it has not:

- **§9 line 272** "Sleeve/position views: Custody distinct from backing, three identities, principal/fees, effective target and output cover" — no view selector list is enumerated. The owner-routed prior round named `reserveOfToken`, `localReserve`, `deployedReserve`; the v0.2 plan does not lock the view surface. **Engineering obligation, not an owner question**; flagging for completeness.
- **§10 line 286** "Required rate-provider failure behavior is fail-closed where rates are required" — the v0.2 design does not require any rate provider (no oracle, no NAV; whole-liquidation uses the AMM for opposing-token conversion). The phrase "where rates are required" is conditional on a rate being used; v0.2 currently uses none. **Confirm** that no rate provider is in v1, or specify if a fee-oracle `liquidReservePercentageOfVault(this)` rate is in scope.
- **§11 SEC-08** "Manipulate hypothetical whole-liquidation depth by temporary liquidity/price changes; deposit/redeem/rebalance/blocked cycles, JIT and keeper sandwiches" — the adversarial manipulation test is enumerated; the **bounds of accepted manipulation** (e.g., what divergence vs. external price is acceptable) are not. The v0.2 PRD does not name a divergence gate. **Confirm** that the engineering plan must bound the manipulation window, not the PRD.
- **§13 line 347** "Measure balancing-solver cost separately from mandatory valuation cost. A costly whole-liquidation quote repeated by rate providers can recreate the original composability failure even if entry never swaps." — this is a real concern. **Confirm** that the V1 liquidation simulation is **bounded work**, not a full sweep of external liquidity, and that the implementation plan must define the bound (e.g., finite tick traversal budget, max swaps per quote).
- **§7A line 212** "No dust burn or public surplus refund." This is a settled owner choice. **Flagging** that this means the bounded overshoot may be retained permanently if no rebalance runs; it does not auto-refund.

## 3. Contradictions and unapproved assumptions I am flagging for the moderator (not owner questions)

These are inconsistencies or implicit defaults the PRD reads as if they are settled but are not. They are engineering fixes unless the owner wants a different direction.

- **§1.1 line 27** "Shares reference current hypothetical whole-vault liquidation into the target token" vs **§8 S1 line 224** `F_target = p · D_target` (sized on **target-token deployed principal**, not V). These are **decoupled by design**: sleeve capacity is not payout capacity, and payout capacity is not sleeve capacity. The user-visible "I have a sleeve" means "I have a buffer for blocked exits" only; the user-visible "V is the share value" is the dynamic liquidation quote, which is not the sleeve. The PRD should not advertise the sleeve as a redemption guarantee. The v0.2 wording is consistent with this but a casual reader could conflate them. **Recommend** adding a §6 or §7 sentence: "Sleeve `F_target` is capacity, not share value. Share value is `V/S` per target units. The two are decoupled; a full sleeve does not guarantee a full liquidation, and a full liquidation does not require a full sleeve."

- **§7 V1 line 145** step 4 requires the simulation to include "tick traversal, price movement and settlement rounding" but **§10 line 288** says "Three owned positions do not bound the number of external initialized ticks a swap can cross" and **§13 line 347** says "A costly whole-liquidation quote repeated by rate providers can recreate the original composability failure." The V1 simulation is **expensive by design**. The PRD does not bound the simulation work. **Recommend** a single line: V1 simulation has a bounded tick-traversal budget per V call; outside that budget the quote is rejected (not partial, not stale-fallback). This is engineering, not an owner question, but it is the single most important performance/cost risk in the v0.2 design.

- **§7 V1 line 142** "Exclude the pending caller contribution from pre-entry valuation" vs **§7 V4 line 168** "A target contribution must never be included both in V_before and as new credit." These are consistent. The V1 simulation is defined to use **pre-credit** state. **Confirm** in the implementation plan that the V_before snapshot is taken **before** the credit delta is applied to `F_target`; otherwise V_after − V_before would double-count.

- **§5 G3 line 112** "Compare precise principal amounts and actual price/range state, including integer dust and reversals." A wing that briefly has 1 wei of opposing token from rounding is **not** converted. Q11 proposes a 1%-or-absolute-floor threshold. **Flag** that "actual conversion" is not defined in absolute terms.

- **§1.1 line 28** "No opposing-token deposit or withdrawal route is implied" vs **§7A line 206** step 3 "If still insufficient, realize the out-of-range opposing-token wing before touching the core, and swap as needed into target." The vault internally swaps opposing tokens from a wing into target during withdrawal. This is **not** a public opposing-token route; it is an internal realization step. The wording is consistent but a casual reader could mistake the internal swap for a public route. **Recommend** a clarifying line.

- **§10 line 286** "Required rate-provider failure behavior is fail-closed where rates are required" — v0.2 has no rate provider in the pricing or sleeve math (V1 uses the AMM directly; sleeve uses `liquidReservePercentageOfVault(this)` from the existing fee oracle). **If** the fee-oracle rate is treated as a rate provider for sleeve-target failure semantics, the fail-closed rule applies; if it's treated as a configuration, the rule doesn't. **Recommend** the PRD specify which it is. This is a v0.2 ambiguity, not a v0.1 leftover.

- **§3 line 61** "Wing bounds may change only through the controlled close/settle/reopen lifecycle below. No public arbitrary delegatecall, arbitrary position salt, user-selected swap target or administrative asset withdrawal." This is a strong design constraint. The "reopen" in §5 G3 is described as "fully close and settle its old position and fee entitlement ... then create a new wing at the new outer edge." This is a vault-controlled lifecycle, not a public-API lifecycle. **Flag** that the rebalance is the only path that performs the close/settle/reopen; the user paths do not.

## 4. Engineering / proof obligations (NOT questions for the owner)

The PRD's §15.2 RV-1 through RV-8 are the engineering obligations. Per the prompt, the user should not be asked to supply proofs. The engineering plan must produce, not the user:

- **RV-1** Liquidation algorithm: exact ordered simulation, fee conventions, completion domain, integer rules, bounded traversal.
- **RV-2** Mint formula: validate the V-growth candidate or propose an alternative, prove state ordering and fee/loss attribution.
- **RV-3** Redemption funding: prove the prioritized execution covers the V proportion, bound the overshoot, specify stage4 mixed-wing/core order.
- **RV-4** Harvest scheduling: the engineering plan must either implement the owner-routed answer to Q3 or implement a default; not an owner proof.
- **RV-5** Sleeve parameters: once Q6 is answered, the engineering plan implements the values.
- **RV-6** Bootstrap: once Q7 is answered, the engineering plan implements the constants.
- **RV-7** Maintenance protections: the engineering plan must enforce limits; the owner does not need to design them.
- **RV-8** Surface, chains, gas margin: the engineering plan chooses within the owner's confirmations of Q4, Q10.

## 5. Summary of what I am asking the owner

Five **blockers** (Q1, Q2, Q3, Q4, Q5) and six **parameters** (Q6–Q11) need owner input. The blockers are: (1) gross-vs-net fee convention, (2) exact-output route support, (3) harvest scheduling on idle user calls, (4) native ETH support, (5) mint formula ratification. The parameters are: (6) sleeve numeric defaults, (7) bootstrap constants, (8) overage accumulation policy, (9) stage4 within-stage deterministic order, (10) gas acceptance ceiling, (11) "actual conversion" threshold. Everything else is engineering.

I also flag seven places where the PRD reads as if a default is adopted when it is not, and recommend moderator-side edits to disambiguate the V-vs-sleeve decoupling, V1 simulation work bound, pre-credit V snapshot, "actual conversion" threshold, internal-swap vs public-route wording, rate-provider interpretation, and the rebalance-only close/settle/reopen lifecycle.

**No mathematical proof is requested from the owner.** Every blocker is a single sentence of policy choice with a default proposed. Every parameter is a number or a small categorical choice. Engineering obligations are explicitly separated from owner questions in §4.

---

*Saved to `docs/research/uniswap-v4-upper-lower-wings-prd-2026-10-05/v02-questions/minimax-original.md`. No shell, tests, code, config, instruction, or PRD edits performed.*