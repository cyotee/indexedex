# MiniMax M3 — combined cross-review (Astra, Grok replacement, Kimi)

**Date:** 2026-10-03. **Pass:** combined cross-review after four originals. **Original:** `minimax-original.md` preserved unchanged. **Inputs to this review:** Astra original, Grok replacement original, Kimi original — all read as UNTRUSTED ATTRIBUTED MODEL EVIDENCE. No cross-review, synthesis, or status artifact was read. No implementation, no delegation, no shell/test/deploy/config edits.

## 1. Verifying my own errors against source

**My original error, on which the prompt explicitly probed me:** I described "search-free for every ordinary deposit/redemption/quote by routing the conversion through `Quotes._exactOutput` (`QuoteService.sol:113–141`) plus the existing closed-form `_closedPlacement` and `_tryTargetLiquidity`" (my §1, §2, §5). I conflated a **known-output swap quote** with **choosing the swap size for a deposit**. Source check:

- `QuoteService._exactOutput` is the F4/R2 one-step inverse. Given a target output, it returns the required input (`:122–141`). It does not choose a swap amount for an input-anchored caller. The constraint that produces a closed form is `output = amount`; for a deposit, the constraint is alignment at the user's chosen `amountIn`, which has no closed form because the post-swap incumbent `B_i'(x)` is path-dependent across tick bitmap boundaries (Kimi §0).
- `_inventoryDeposit` at `.../InQueryTarget.sol:163–178` calls `Planner._composition` (`TransitionPlanner.sol:73–108`) for any idle single-token `quoteTransition(DepositExactIn, …)`. That is the call Orbital's `planDeposit` issues via `previewBufferClaimIn` (`OrbitalBufferHookClaimLib.sol:300–312`). My "one-step closed-form composition" claim was wrong: it does not exist in source. **I correct this.**
- My §5 also overclaimed: "`Planner._maintenance`'s refinement loop … Callers must use the new `Quotes._exactOutput + Planner._closedPlacement + Inventory._targetLiquidity` path" — true for the **deposit side**, but maintenance's swap direction still needs a chosen `amountIn` to break the post-swap incumbent ratio into the band. `_repairCandidate` (`TransitionPlanner.sol:216–238`) is given an amount and evaluates one forward swap; that one-shot forward call is bounded, but the choice of `amountIn` is itself the search the prompt asks us to remove. The fixed-budget repair I described still requires a non-search budget function; that is a derived claim, not a closed-form source primitive.

**My original's path:line references for the search loops were correct.** The diagnoses of the two loops are right; the prescriptions were not.

## 2. Cross-review of Astra original

**Agree (high confidence, source-checked):**
- Two-loop diagnosis (`HTransitionPlanner.sol:73–156` composition, `:168–214` maintenance). Matches my own. Confirmed by reading.
- External library search identification (`UUniswapV4ZapQuoter.sol:166–228`) — Crane's zap is a binary search; not adopted in H. Confirmed by reading.
- Held reservations on the "outer Orbital searches" claim (`OExitQuoteLib.sol:347–374`, `OClaimLib.sol:250–275`). Confirmed by reading `ClaimLib.sol:250–276`: outer expand-and-bisect, up to 64 expansion + 8 bisection probes.
- Conservation statement at fixed external state (`B′0 B′1/(S′)² ≥ B0 B1/S²`) for the proportional core. Matches the PRD plan §2.0 and CP:singleExit. The same inequality does **not** hold across maintenance or pool repricing; Astra's note that fixed-state invariant ≠ economic safety across cycles is right.
- Astra's "unilateral activation rejected" and "deposit into empty leg rejected" rules match PRD §6.1 and `StandardExchangeConstantProduct.sol:43–51`.

**Disagree (with reason):**
- Astra's preferred Rank 1 ("uniform internal constant-product settlement for single-token … internal market against holders") is a genuine economic shift, not just an interface change. The PRD §6.2 assigns a swap's repricing to incumbents; Astra's proposal explicitly re-prices single-token entries/exits at the *book's* internal ratio, which creates a cross-market between internal CP and external V4 pool. The 50 bp pool-impact reinterpretation ("movement of `B1/B0` by `max(P'/P,P/P')−1≤.005`") is a **new** owner decision, not D20, and Astra acknowledges this. **I rank this option second, not first**, because it materially changes single-token economics.
- Astra's claim that "Option 1 is a candidate product change, not a demonstrated economically safe replacement" is true but should not block the redesign: the question is what *can* be redesigned search-free, not what is "safe." Safety is an owner decision.

**Dissent to record:** Astra rejects Rank 3 (domain-restricted external conversion) as "insufficient for ordinary two-legged Orbital traffic." I disagree: domain-restricted external conversion matches R2 in the PRD plan (§4 row 2), which is closed-form when the swap provably fits one core step. The "insufficient" judgment assumes autonomous scalar Orbital buffering; the PRD route matrix already says R2 is a supported closed-form exact-output path. **Astra's Rank 3 is also my second choice, ahead of Astra's Rank 1.** Kimi agrees on the priority of dual-only.

## 3. Cross-review of Grok replacement original

**Agree (high confidence):**
- The five "cannot preserve without search or an explicit reject" items are correct. In particular (1) "Universal idle single-token alignment to the post-swap incumbent book" and (4) "Interleaved holder swap-repair inside quotes" — both are sizing decisions, not executable primitives; the swap size must be chosen somewhere, and on-chain that choice is the search.
- The continuous-vs-integer distinction (one-step continuous alignment is degree-2 if fee and `ρ=l/L` constant; integer predicate requires floors, ticks, own-LP accrual, placement rounding — the polynomial is not the integer predicate). I agree and previously underweighted this. Grok's conclusion: "A quadratic may propose a candidate. It cannot be the sizing equation. Ranking it as the design that keeps single-token entry overclaims." **This is the core correction to my original.**
- The replacement-of-the-replaced-Grok stance on the quadratic. The replaced Grok's quadratic-plus-one-check is a single-check reject policy, not a sizing identity. Grok replacement is right to reject it.
- Idle redemption-of-known-share-amount is sized: burn `floor(l*r/S)`, pay the pro-rata slice, swap the known other entitlement with one forward simulation. Tick traversal of an already-sized swap is permitted by the prompt. I agree.
- The "calls that become invalid while idle" list (`exchangeIn(token→shares)`, `previewExchangeIn`, `quoteTransition(DepositExactIn)`, `quoteExternalDeposit`, `quoteInputForExactShares`) matches the source.
- Charm Alpha Pro: "proportional `deposit` is retained until a separate `rebalance`; full range is a manager-set weight, not the product." Same caveat as Astra.

**Disagree (with reason):**
- Grok replacement's Rank 1 ("proportional basket core + algebraic sleeve placement + idle redemption of known share amount") is **the same as Kimi's Rank 1** in everything except naming. They converge on dual-only on-chain deposits with the conversion moved to caller/Orbital. The disagreement is cosmetic.
- Grok replacement's Rank 2 ("uniform internal constant-product settlement") is Astra's Rank 1 — also agrees with Astra. So Grok replacement, Astra, and Kimi all propose the same fallback option, just at different positions in the ranking.
- Grok replacement's note on "Outer searches that survive a Hookless solver deletion" is correct that they survive, but understated the count: `_invertBufferForEffective` (`ClaimLib.sol:250–276`) is also an outer search (up to 64 expand + 8 bisection probes = up to 72 probes), and `quoteExternalExchange` (`InQueryTarget.sol:70–85`) calls `_inventoryRebalance` → `Planner._maintenance` which is a separate search. **Grok replacement's list is incomplete; mine was too.**
- Grok replacement's "fixture vault type is no longer an open gap" with `deployUniv4Vault` (`UniswapV4DetfProductionSeDeployLib.sol:591–597`) was a useful correction that I had recorded as missing. The replacement path's note does not depend on that gap being closed for the redesign.

**Specific objection to record:** Grok replacement claims "Idle redemption of a known share amount is already sized." Source check: `_inventoryRedeem` (`Common.sol:168–196`) for idle calls `_inventoryRedemptionSwap` which calls `Quotes._redemptionForward` (`:47–62`). `_redemptionForward` is bounded at 64 core steps; it does not probe. The path is sized given `r` (shares). The tick-traversal is bounded, not a search. **Grok replacement is correct.** My original underweighted this; I now upgrade it.

## 4. Cross-review of Kimi original

**Agree (high confidence):**
- "Composition ≠ maintenance" is the correct distinction. The two loops have different ownership and different admissible solver bounds. Confirmed by source.
- Single-token idle deposit being removed from on-chain is the cleanest search-free path. Kimi's "excess leg refunded exactly" preserves the 1 bp alignment without an internal market.
- "On-chain single-token→shares composition is **removed** (idle `exchangeIn(token→shares)` becomes `InvalidRoute`; blocked F1 linear mint stays)" — matches PRD plan §6.4 family invariant for blocked and current Orbital-state acceptance.
- The exact refund `r_i = a_i − C_i ≥ 0` requires explicit settlement. PRD §6.2 currently retains excess as sleeve; Kimi's refund changes D7 (or its product equivalent). **This is an explicit owner decision** that Kimi flags.
- Outer Orbital sizing loops named: `zapSplitWad` (64), `_faceForClaim` (8), `_invertBufferForEffective` (64+8). Kimi's list matches Grok replacement's and mine, modulo completeness (Kimi does not separately call out `quoteExternalExchange → _inventoryRebalance → Planner._maintenance`).
- The Rank 3 (NAV mint) rejection is correct: same-pool NAV is a manipulable valuation in one transaction; Charm's "range orders can only be manipulated higher" comment covers proportional dual deposit, not single-sided NAV.

**Disagree (with reason):**
- Kimi's Rank 2 ("narrow-domain closed-form zap (sketch 3)") requires a "domain certificate" that is itself derived from a sizing search unless stated otherwise. Kimi acknowledges the fragility ("Fragile domain checks; do not gate the redesign on it"). The PRD plan §6.4 / R2 already covers the one-step closed-form exact-output path. **The R2 one-step domain can be Rank 2** (closed form for known-output exact-output, plus closed-form placement) — but the prompt's "ordinary deposit" use case is single-token input, not known-output. **R2 doesn't cover single-token deposit.**
- Kimi says "Blocked single-token exits stay (linear CP valuation against local cover — closed form, not a search)" — matches my §3 and PRD plan §2.3 F2.
- Kimi's "UX/liquidity regression: single-token entry now costs the user an external swap; Orbital preserves it for nested flows. This is the honest price of removing the search." This is the trade-off the owner must explicitly accept; I record it as an owner decision.

**Specific correction to record:** Kimi attributes the new "excess refunded, not retained" behavior to D7. The current PRD §6.2 / §12 says identified excess is retained and fully booked, and D8 says "Proportional ownership takes precedence over forced deployment within the deposit route. Retain and disclose placement residuals." The D7/D8 wording covers placement residuals, not dual-deposit declared-max excess. **Kimi's refund is a **new** product behavior, not a reading of current PRD.** I flag it as a separate amendment.

## 5. Cross-review on the prompt's assessment dimensions

### Placement equations and rounding conservation
- `_tryTargetLiquidity` (`InventoryMath.sol:216–245`) is closed form via `LiquidityAmounts.getLiquidityForAmounts`. Confirmed.
- `_closedPlacement` (`TransitionPlanner.sol:49–67`) evaluates at `L*`, `L*−1`, and current; first passing wins. Not a search. Confirmed.
- Rounding loss: `roundingLoss[i] = beforeTotal − afterTotal` (`InventoryMath.sol:281`); caller-attributable on addition, incumbent-attributable on removal (`TransitionPlanner.sol:135–143`). Confirmed.
- Conservation: post-success local mint gives `B' = B + C`, `S' = S + m`; placement moves `F↔D` inside that book; full booking enforced via `_syncVaultReserves` (`Common.sol:514–524`). Confirmed. **No asset is created.**

### Blocked entitlement vs local cover
- `E` (uncollected fees) is included in incumbent backing `B` but **not** spendable cover. Confirmed: `_freeBalancesForShareMath` adds `E` to `F` for share math (`Common.sol:534–539`), but `_localBalance` (`Common.sol:1146–1150`) reads only actual ERC-20 balances plus native. `_previewZapOutExactIn` (`InBase.sol:106–124`) checks `available = _localBalance(tokenOut)` and reverts `InsufficientLocalReserve` on `output > available`. Confirmed.
- F2 (`StandardExchangeConstantProduct.sol:98–110`) outputs `u + floor((Bout−u)*v/Bother)`; pay only from local `F_out`. Confirmed.
- "Earned fees are backing, not local cover." Matches PRD §5 ("Uncollected fees remain in share backing but are not spendable sleeve cover. Collection moves fees from `E` into `F` once; it does not create an accounting gain.").

### Refund law
- Pretransfer: credit = declared amount if `declared ≤ unbooked`; refund unused credit only for false-flag exact-out (`OutBase.sol` semantics). Confirmed at `Common.sol:900–922, 941–949`.
- Pull exact-in: credit exact delivery; no refund.
- True exact-out: refund `credit − used` only. Booked inventory cannot fund refunds. Confirmed.
- Kimi's refund `r_i = a_i − C_i` for dual deposit is a **new** refund surface (declared-max, not exact-out). Distinct from current pretransfer law.

### Scalar SY vs basket interfaces
- SY `deposit`/`redeem` map to the same share routes (R9 in PRD plan §4). Confirmed via `IStandardExchangeTransitionQuote` and `_inventoryDeposit` / `_inventoryRedeem`. `NativeStandardYieldTarget.sol:20–77` semantics preserved. External routes delegate with `pretransferred=false`; internal-balance redeem uses fixed proxy self-call. Confirmed.
- The new design does not introduce a new scalar SY: scalar SY on Hookless is `quoteTransition(DepositExactIn, …)` for a token → SE shares, which is what my original wrongly claimed to be closed-form.

### All outer Orbital sizing loops
Verified by source reads:
1. `OExitQuoteLib.zapSplitWad` callsite via `OExitQuoteLib._depositSales` (`ExitQuoteLib.sol:297–330`) → 64-probe binary search (`Math.sol:321–364`).
2. `OExitQuoteLib._faceForClaim` (`ExitQuoteLib.sol:347–374`) — up-to-8-probe bisection.
3. `OClaimLib._invertBufferForEffective` (`ClaimLib.sol:250–276`) — up-to-64 expand + up-to-8 bisection.
4. `OExitQuoteLib.planDeposit` (`ExitQuoteLib.sol:241–330`) orchestrates all of the above plus Hookless `quoteTransition(DepositExactIn, …)`. With Hookless preview search-free, this orchestration remains a 64-probe loop calling Hookless preview at O(1) each.
5. `HInQueryTarget.quoteExternalExchange` (`InQueryTarget.sol:70–85`) → `_inventoryRebalance` → `Planner._maintenance` (`:184–188`). Even with H deposit search-free, **Orbital's "external exchange" preview invokes holder repair**. If the owner wants Orbital previews truly search-free, this branch must revert `InvalidRoute` while idle maintenance is not requested (or be removed from the SE interface).
6. `OExitQuoteLib.preview` (`ExitQuoteLib.sol:29–47`) calls three `_withdraw` then up to two `_swap` plus an optional `quoteTransition`. Not a probe; sized.

**No Orbital preview path becomes search-free under any H-only redesign.** This is the unresolved outer-loop problem and it is not in scope for this round, but the prompt asks us to name it. **Flagged as remaining outer search.**

### Economic risks across internal/external routes
- Donation: pretransfer law unchanged. Unbooked surplus cannot fabricate caller credit.
- Internal-vs-external market (Astra/Grok Rank 2): a depositor can buy the cheap internal leg and redeem the other leg up to sleeve cover, or wait for maintenance to trade toward the pool. Fixed-state `K/S` inequality does not cover this cycle. Confirmed by my §6.
- Same-pool incumbent repricing: swap moves the vault's own position (`Planner._afterSwap` `TransitionPlanner.sol:158–166`). Belongs to incumbents.
- Tick initialization forcing a rank-1 redemption revert at the work limit (Grok replacement §8): real; do not solve by searching a smaller swap.
- "minOut = 0" forbidden; gas-cap raises forbidden. PRD §9.
- Pons D26 binding fixed to `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`; family separation D22; not merged by this redesign.

## 6. Corrected ranked recommendation

I correct my original ranking in light of the cross-review.

1. **Kimi Rank 1 + Grok Rank 1 (proportional dual core, single-token on-chain `InvalidRoute`, conversion moved to caller/Orbital).** Genuinely search-free; preserves full-range liquidity, fungible shares, blocked single-token mint (F1 linear), blocked single-token exit (F2), F3 dual exit, F4 one-step external exact-output, sleeve reservation, 25/10/1 bp protections. **The owner must approve removal of idle single-token `exchangeIn(token→shares)` and accept the explicit refund-or-retain choice for declared-max excess.**
2. **Astra Rank 1 / Grok Rank 2 (uniform internal constant-product settlement, both manager states).** Search-free, but introduces an internal market against holders. 50 bp pool-impact bound becomes inapplicable; new owner-approved internal-price/rounding bound. Cross-market economic objections stand. Accept only if the owner chooses this product change.
3. **R2 one-step closed-form external exact-output (PRD plan §4 row 2 / "domain-restricted external conversion").** Already closed form via `QuoteService._exactOutput` (`:113–141`) for known-output. Add as a separate rank-2-or-3 optimization for **exact-output** only. Not a search-free solution for **single-token deposit**.
4. **Oracle-NAV (rejected).** Same-pool NAV manipulable in one transaction; oracle introduces availability/freshness/governance decisions.
5. **My original "one-step closed-form composition" — REJECTED.** It conflated known-output (`_exactOutput`) with chosen-input deposit sizing. There is no such closed form on-chain. Removing the loop requires either dropping single-token on-chain (Rank 1) or switching to an internal market (Rank 2).

## 7. Concrete owner decisions (PRD D1–D31 amendments)

- **D1**: amend — `exchangeIn(token→shares)` idle path reverts `InvalidRoute`; dual-token proportional join is the only on-chain single-call mint. **Owner must explicitly approve.**
- **D2**: amend — composition-swap funding rule vacuous for deposits; retain for maintenance.
- **D4**: amend — order becomes fund → allocate → mint, no composition swap.
- **D5**: amend — post-swap whole-book targeting repealed for deposits; pool repricing still belongs to incumbents in any external operation.
- **D6**: amend — failed or removed zap cannot fall through to one-sided growth.
- **D7 / D8 wording**: amend — explicit owner choice between (a) refund declared-max excess exactly (Kimi) and (b) retain as sleeve (current PRD §6.2). Either choice is acceptable; the choice must be recorded.
- **D17, D18, D19**: amend — composition exact-output / interleaving become moot for deposits; R2 remains as the supported closed-form exact-output route; R3 idle single-token → `InvalidRoute`.
- **D20**: amend — 50 bp composition bound vacuous for deposits; 25 bp on separate repair, 10 bp on any executed swap, 1 bp on basket rounding (per Grok §7 and PRD §9). Internal-price bound (Astra/Grok Rank 2) requires separate owner decision.
- **D22 / D26 / D28 / D29**: unchanged — Pons family separation, fixed hook binding, no H→P dispatcher.
- **D25**: unchanged — fixed constants, no setters, no relaxation for liveness.
- **D27 / D30**: refresh for every changed route (preview == execution at integer equality).

## 8. Remaining proof / benchmark gates (later implementation agent, not this round)

1. **Route matrix parity**: for every R1–R11 cell, ordinary preview, transition preview, and execution agree on the exact integer result (preview == execution).
2. **Search counters zero on deposit, redeem, quote paths.** `Planner._composition` and `Planner._maintenance` refinement counters must read `0` for `exchangeIn`, `exchangeOut`, `quoteTransition(DepositExactIn)`, `quoteTransition(RedeemExactIn)`. Maintenance refinement counter may read >0 on a separate `rebalanceLiquidReserve` call (D11).
3. **Conservation tests**: `B' / S'` non-decreasing across deposits; full booking after settlement and refunds; fees counted once; `E` not booked as local cover.
4. **Blocked cover**: blocked withdrawals revert atomically on shortfall; blocked deposits book `C` into `F` only.
5. **Refunds**: declared-max excess either refunded exactly or retained-and-disclosed (owner choice D7/D8); exact-out refund bounded by `credit − used` only; booked inventory never refunded.
6. **Outer Orbital previews**: even with H search-free, the following remain Orbital-side sizing loops and **do not become search-free**: `zapSplitWad` (64-probe), `_faceForClaim` (8-probe), `_invertBufferForEffective` (up to 64+8 probes), and the Orbital `quoteExternalExchange → _inventoryRebalance → Planner._maintenance` chain. Record that these are out of scope for H and require a separate Orbital-side redesign to make Orbital fully search-free end-to-end.
7. **Live `p` and deadband tests**: `p = 0, 0.2, 1`; live inherited fee-oracle changes do not use pre-placement principal.
8. **Adversarial**: donation/re-credit negatives; cross-mode cycles (deposit → external swap → maintain); same-tx price-manipulation against the join (expected: no extraction vs. baseline); sandwich protection via `minShares`/`minOut` and 10 bp shortfall; never `minOut = 0`.
9. **Pons parity**: family separation maintained; Pons family gets the same single-token `InvalidRoute` amendment or explicit owner opt-in for an internal-market variant; H is bounded to `poolKey.hooks == address(0)`.
10. **No `viaIR`**; hermetic profile only; `forge build` then `forge test` (CLAUDE.md §10); no profile or config workaround.
11. **No measured gas claim in this round.** Bench is later; do not assert a gas improvement.

## 9. Confidence and gaps

Confidence: **high** in the diagnoses of the two refinement loops, in the closed-form status of `Quotes._exactOutput` (known-output only), in `_closedPlacement`/`_tryTargetLiquidity`, in F0/F1/F2/F3/F4/F6 closed-form status, in the search-loop status of `_faceForClaim`/`_invertBufferForEffective`/`zapSplitWad`/`_inventoryRebalance`, in pretransfer/blocked-cover/refund law. **Medium** in end-to-end integer workflow feasibility of the corrected Rank 1 design until the §8 suites run. **Lower** in autonomous Orbital-callable search-free properties for Orbital's own sphere residual balancing — that is **out of scope** for this round and **must be addressed in a separate Orbital-side redesign**.

**Gaps (from my original, unchanged):**
- `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol` — directory does not exist in this revision; not retried.
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Univ4Se.sol` — directory does not exist in this revision; not retried.

**Additional finding during cross-review:** Grok replacement (and Kimi) note `deployUniv4Vault` (`UniswapV4DetfProductionSeDeployLib.sol:591–597`) closes the previously logged fixture gap. The closing of this gap does not change the redesign.

**No consensus, no measured gas claim.** This is a cross-review of three originals; disagreements and corrections are attributed above, not averaged. The 19.97M gas / 11-`quoteTransition` / 547-`extsload` trace note remains unverified historical per the prompt; not relied upon. The owner must select the rank and approve the amendments before any implementation; this memo does not authorize code, tests, deployment, configuration, or deletion.

Stop for human selection. No implementation authorized.