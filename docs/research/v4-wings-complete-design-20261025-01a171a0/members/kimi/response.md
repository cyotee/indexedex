# Member response — kimi — complete V4 Upper Lower Wings vault design

- Run: v4-wings-complete-design-20261025-01a171a0
- Member: kimi (initial independent response; no peer outputs or coordinator draft read)
- Runtime identity (exposed via process environment only): provider `kimi-coding`, model `k3`, reasoning level `high`, task `st_01a1752a`. Effective provider payload, account, and billing source: not exposed. Coordinator synthesis metadata: not exposed.
- This is a research recommendation. It is not implementation authorization, not a security proof, and not council consensus.

## Question

Recommend the entire replacement design for the Uniswap V4 Upper Lower Wings Standard Exchange vault: ownership, deposits, share issuance, fees, compounding, maintenance, withdrawals, previews, `getRate`, and use of shares in external liquidity pools, with full economic credit for imbalanced contributions and freedom to change any prior expectation.

## Evidence read

Source observations (read in full unless noted), classified as source observation (SO), coordinator-supplied evidence (CE, the brief), or inference (IN):

- SO: `docs/research/v4-wings-complete-design-20261025-01a171a0/brief.md` (this run's brief, complete).
- SO: `CLAUDE.md` (family routing; legacy V4 SE and both V4 FullSpread families retired and not to be restored).
- SO: `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md` — APEX-2026-012 (anchor `#apex-2026-012`), 024 (`#apex-2026-024`), 025 (`#apex-2026-025`), 026 (`#apex-2026-026`), 040 (`#apex-2026-040`). Locators verified by direct read on 2026-10-25.
- SO: full current V4 Wings source family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`: `Money`, `LiquidationQuote`, `Accounting`, `Harvest`, `Projection`, `Geometry`, `Inventory`, `Repo`, `Common`, `Types`, `EconomicTarget`/`EconomicFacet`, `QueryFacet`/`QueryTarget`/`QuoteBase`, `InFacet`/`InTarget`/`InExecutionBase`, `OutFacet`/`OutTarget`, `SYFacet`/`SYTarget`, `TransitionFacet`/`TransitionTarget`, `RebalanceFacet`/`RebalanceTarget`/`RebalancePlanner`, `ExecutionDelegate`, `DFPkg`, and `interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol`.
- SO: `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` (full). It derives its rate from a full-supply exit preview (`_safePreviewExchangeIn(totalShares)`), not from the vault's canonical `getRate`.
- SO: rate consumption in the V4 SE buffer hooks, e.g. `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:438-447` (`_rate` staticcalls `IRateProvider.getRate`), `:426-436` (`ratedReserve` values the hook's whole SE share balance at that rate). Same pattern in dual CP, orbital, weighted, and quad stable ClaimLibs (grep: 13 files under `contracts/hooks/uniswap/v4/standardExchange/`).
- SO: `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md` (full), `docs/security/audit/second_review/APEX-2026-012-OPEN-QUESTIONS.md` (full), `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` §10–13 (partial read of the quotes/rates, security, consumer and gas sections), `docs/reviews/apex-012-design-recommendation-20261024/REPORT.md` (full, prior run).
- Not read: current-run peer responses and coordinator draft (forbidden on this pass); the Wings test base and audit PoC sources beyond the audit's quoted outputs (not needed for a static design; their absence is a stated limitation).

## Assumptions

1. The vault remains bound to one hookless V4 `PoolKey` with one designated target token; shares keep target-token decimals (`DFPkg.initAccount` already does this). (SO: DFPkg.)
2. No external price oracle is assumed to exist for an arbitrary pair. (CE: brief item 8.) My preferred design therefore uses no oracle at all; the reference it uses is produced by real execution.
3. `getRate` is retained as the decimal-normalized one-whole-share target exit quote — a preview of an actual withdraw-and-sell, not a NAV and not a promise of executed proceeds. (CE: brief item 7; consistent with the standing owner correction that NAV issuance accounting and exit quotes are separate.)
4. The owner rulings preserved in `APEX-2026-012-OPEN-QUESTIONS.md` remain the baseline unless I name a change: other token converts only on the acting holder's entry or exit; harvest and rebalance do not sell the other token; a share is a fraction of every position including idle; a later deposit does not open a new range.
5. ERC20 tokens only, no fee-on-transfer, no rebasing underlyings (repo-wide weird-token law; SO: CLAUDE.md).

## Conclusions up front

1. The exploitable element in APEX-2026-012/024/025 is not the existence of a price; it is that **mint and redeem sizes are set by a view that simulates a sale through live depth**. The fix is to move every money-path quantity to (a) token amounts the vault actually holds or actually receives, and (b) prices produced by the acting holder's own executed swap — never by a simulation.
2. A pure proportional-mint design (no price anywhere) cannot fully credit an imbalanced contribution: with no numeraire, an overage in one token is either shared (partial silent donation) or refunded (not a deposit). The user explicitly rejected both outcomes. The cheapest correct numeraire that temporary liquidity cannot fabricate is the entrant's own executed entry-swap price. That is the core of my preferred design.
3. `getRate` as a one-share exit preview remains a live-state execution quote and is therefore manipulable as a *price oracle*. It must be retired as an accounting input everywhere (already true on the money path in this design) and its consumers (buffer hooks) must stop paying against it without redeeming, or bound it. A single scalar rate cannot equal per-share executed proceeds at every size; the rate's quote size is defined as exactly one whole share.
4. The on-chain iterative solver that made exact zap-in too expensive is unnecessary: sizing is computed off-chain (or by the view `Projection` via `eth_call`), and the vault verifies the result in closed form over three positions.

## Preferred complete design: "Executed-price proportional entry, slice-actual exit, one-share exit-preview rate"

One sentence: a share is a fixed fraction of the whole book (three positions, idle balances, uncollected fees); deposits are target-only but, whenever the book holds the opposing token, swap an externally sized fraction into the opposing token through the real pool and mint against the post-harvest book valued at the price that swap actually executed at; exits burn the holder's exact fraction of everything, sell only that fraction's opposing token, and pay actual proceeds; `getRate` previews exactly that exit for one whole share.

### 1. Units, state, fungibility, ownership, bootstrap, decimals, rounding, dust, donations, liabilities

- **Asset/share units.** One fungible ERC20 (`UV4W` today), decimals = target decimals (SO: `DFPkg.initAccount`). State is the existing `Repo.Storage`: booked locals `local0/local1`, three positions `(core full-range, upper wing, lower wing)` with geometry-derived ranges (SO: `Repo`, `Geometry.ranges`). No new share class, no per-section claims.
- **Ownership fraction.** Holder of `s` shares out of supply `S` owns exactly `s/S` of every position's liquidity, of both idle balances, and of all uncollected and collected-but-unplaced fees. Ownership is established at the mint/burn instant; placement of tokens into ranges afterward is inventory management and changes no claim. (This is the apportioned-PRD ownership model; SO.)
- **Token custody vs reference-valued composition.** Booked custody (`local0/local1`, position liquidity) is the only balance sheet. The reference price `p_e` (below) is used once per deposit, to denominate the pre-entry book in target units for the mint ratio; it never changes custody and is never stored.
- **Bootstrap.** First deposit (S = 0): no entry swap (book is empty), mint = D shares 1:1, subject to a minimum bootstrap size `B_min` (owner-set PkgArg; recommend ≥ 10^6 target units) and the round-trip guard below. Rationale: APEX-2026-040 (SO) shows dust-supply activation plus `PoolManager.donate` fee inflation rounds later deposits to 1 share; the guard makes that revert.
- **Rounding.** Every split floors in favor of the remaining holders: mint floors (`S·D/V_pre` rounded down), slice liquidity `⌊L_i·s/S⌋` floors, fee/local slices floor. Residual dust accrues to stayers. `V_pre` divisions round up (against the entrant).
- **Direct donations.** Direct token transfers are excluded from the book: locals are booked and `Money._requireBacking` only checks `balanceOf ≥ booked` (SO: Money.sol:54-63); the excess is never credited, satisfying SEC-01. `PoolManager.donate` raises fee growth, which enters the book at the next harvest; under the new mint formula that raises `V_pre` proportionally (the donation is valued like any other book content), and the round-trip guard catches residual dust-supply traps. A donation can no longer mint free shares or trap a victim (closes the APEX-2026-040 mechanism; runtime evidence still required).
- **Fees and liabilities.** Collected fees are book assets like any other. There are no liabilities besides shares; the fee-oracle USAGE fee plumbing (SO: `DFPkg.vaultFeeTypeIds`, `Accounting.liquidTarget`) is unchanged.

### 2. Share issuance equations — exact

Let the checkpoint book (post-harvest, pre-entry, at current sqrt price `√P`) be, in native units:

```
A0 = local0 + Σ_i ( principal_i(√P).amount0 + fee_i0 )      // target  = token0 WLOG
A1 = local1 + Σ_i ( principal_i(√P).amount1 + fee_i1 )      // opposing = token1
```

`principal_i` is the existing deterministic `Inventory.principal` (SO); fees are the harvested actuals. This is arithmetic over three positions — no tick walk, no simulation.

Entry swap (only when `A1 > dustThreshold`, a small owner-set constant): exact-in `x` target → opposing, size `x` supplied by the caller (off-chain solver result; on-chain default `x = D/2` when the caller passes 0 — the candidate "≈49–51%" split is the special case where the book is balanced). Executed actuals: spent `x_s ≤ x` (partial fill at the caller's price limit refunds the unspent target to locals), received `o`. The **executed entry price** is:

```
p_e = x_s / o        (target per opposing, fee-inclusive, from real settlement)
```

Issuance (supply `S > 0`):

```
V_pre = A0 + mulDivUp(A1, x_s, o)              // book valued at the executed price
C     = (D - x_s) + mulDiv(o, x_s, o)  =  D    // identity: full credit, nothing donated, nothing priced twice
mint  = floor( S * C / V_pre ) = floor( S * D / V_pre )
require mint ≥ minimum_  (entrant's slippage bound, in shares)
require roundTrip: floor( mint * (V_pre + D) / (S + mint) ) ≥ D - max(1, D / 10_000)   // APEX-040 guard
```

Properties:

- **Full imbalance credit (the user's headline ask).** The numerator is identically `D`: every retained wei — kept target, bought opposing, overage of either token — is credited at exactly the price it was actually acquired at. Nothing is silently donated; nothing needs refunding. The "deposit overage into the appropriate wing" candidate (brief item 2) is subsumed: after the mint, ordinary placement puts residual token0 into the upper wing and token1 into the lower wing, and it is already paid for.
- **Manipulation shape.** Temporary (JIT) liquidity does not enter `V_pre` at all — only the book's own amounts and the entrant's own executed fill do. Pushing the executed price moves numerator and denominator in the same direction for the entrant's own tranche (`C = D` invariant), so the entrant's mint falls when their execution is worsened — the loss is bounded by their own `minimum_`, the classic sandwich bound. The residual attack (a shareholder deliberately worsening the *denominator* via their own large deposit) is analyzed in §10; it is not closed by construction and is the strongest objection to this design.
- **Old-holder invariance (exact).** Valued at `p_e`, incumbent claims are unchanged by any deposit: `(S/(S+mint))·(V_pre + D) = (S/(S + S·D/V_pre))·(V_pre + D) = V_pre`. Rounding makes it ≥. This is the testable conservation law replacing the quote-equality checks.
- **Single-sided book (`A1 ≤ dust`).** No swap, `V_pre = A0`, `mint = floor(S·D/A0)` — pure target pro-rata, identical to today's formula but with no quote.
- **Ownership point.** The mint above establishes ownership. Placement (`Harvest.placement`) runs after the mint, as today (SO: Money.sol:142).
- **Blocked context (manager already unlocked by an outer caller).** A nested unlock cannot run the entry swap (SO: `Common.execute` reverts `ManagerAlreadyUnlocked`), so `p_e` cannot be produced honestly. Rule: **deposit and redeem revert while `isUnlocked()` whenever the book is two-sided (`A1 > dust`)**; when the book is single-sided in target, both work pro-rata in target only (deposit `mint = S·D/A0`; redeem pays `⌊s/S⌋` of local target subject to sleeve cover, no sale). This deletes the in-unlock JIT variant of APEX-012 by removing its pricing surface, rather than by keeping sleeve-limited redemptions priced by the same contaminated quote (SO: Money.sol:167-177 does that today). Named as a requirement change in §14.

### 3. Full deposit sequence

`exchangeIn(target → shares, D, minimum_, recipient, pushed, deadline)`:

1. `Money.begin(deadline)` — initialized, non-reentrant, deadline, backing check (SO, unchanged). Registry-disabled check rejects inbound (SO: Money.sol:126; SEC-10 exits preserved).
2. Pull `D` (transferFrom or authenticated pre-transfer), measure actual received (SO: `_pull`; FoT would revert the delta check).
3. `S == 0` → bootstrap branch (§1). Otherwise continue.
4. **Harvest checkpoint:** `Harvest.harvest(Harvest.snapshot())` — collects accrued fees of both tokens into locals and closes fully converted wings (SO: Harvest.sol:104-115). Effect: fees accrued before this entry belong to incumbents and enter `V_pre`; the entrant does not buy them cheap. Converted-wing closure also means `A0/A1` reflect actual post-close locals.
5. **Reference production:** if `A1 > dust`, execute the entry swap (exact-in `x`, caller `minSwapOut`, price limit = caller-supplied or derived from the stepper quote of size `x`). The swap's LP fees are paid by the entrant through execution (brief question 4: entry costs are the entrant's). Fees the vault's own in-range positions earn on this swap accrue to the book *after* `V_pre` is fixed — they belong to incumbents, and the entrant's marginal share of them is negligible and not credited twice (IN: the mint ratio uses only pre-swap `A0/A1`; the swap's fee output lands in fee growth, i.e. post-mint book). If the vault's own liquidity fills part of the swap, that is the same trade any LP takes (owner ruling, apportioned PRD).
6. **Credit and mint** per §2 equations; `minimum_` and the round-trip guard; mint to `recipient`.
7. **Placement:** `Harvest.placement` — sleeve floor first, core, then wings; opposing residuals go to their geometric wing (SO: Harvest.sol:117-153, Geometry note "Token0 inventory uses the upper wing"). Placement never prices anything.
8. Failure handling: any unmet minimum, deadline, disabled registry, failed delta settlement (`SettlementMismatch`, SO: ExecutionDelegate) reverts the whole transaction atomically — no partial state, no stuck credit. Partial swap fills are not failures: actuals feed the formula.
9. `Money.end()` — backing check and reserve sync (SO, unchanged).

Exact-output in-routes (`exchangeOut` target → exact shares): `requiredInput` becomes a simulation (view `Projection`) of the stateful path including the entry swap; the stateful route pulls the simulated input (rounded up), executes, and refunds the unused pre-transfer budget exactly as today (SO: OutTarget.sol:15-23). Because `p_e` is only known after execution, the pull is an upper estimate; unused target is refunded. Exact-output where the caller insists on an exact share count with no estimate tolerance is not supportable without an iterative solver and is explicitly dropped (see §14).

### 4. Entry execution costs — allocation

The entrant bears: their swap's LP/protocol fees and price impact (embedded in `p_e`, hence in `V_pre`), and the gas of the shared harvest/placement their call triggers (current behavior, kept). Incumbents keep: all pre-entry accrued fees (harvested into `V_pre` before the mint), and all fees earned during the entrant's own swap (post-checkpoint fee growth). Nothing is double-counted: the entrant's credit identity `C = D` contains no fee component, and the denominator contains only pre-swap amounts. I recommend no different allocation.

### 5. Full withdrawal sequence

`exchangeIn(shares → target, s, minimum_, recipient, pushed, deadline)`:

1. `begin`, registry/pushed/recipient checks, balance check (SO: Money.sol:150-158).
2. **Harvest checkpoint** (as deposit step 4). All fees are now locals.
3. **Slice:** `f = s/S`. For each slot `i`: burn `ΔL_i = ⌊L_i·s/S⌋` via `modifyLiquidity` (actual principal received `r_i0, r_i1`; fee growth checkpoints update but fees were already harvested). Exiter claim:

```
c0 = ⌊s·local0_postharvest/S⌋ + Σ_i r_i0
c1 = ⌊s·local1_postharvest/S⌋ + Σ_i r_i1
```

   (`c_target`, `c_opp` = the two components by target0.) Burns execute before any sale — order matters for the sale limit below.
4. **Sale:** if `c_opp > 0`, sell exactly `c_opp` exact-in through the same pool. Price limit: derived from the (view) stepper quote of selling exactly `c_opp` — the limit is set to the quote's own end price, so the sale can traverse exactly the depth the quote walked and no further. This kills the APEX-2026-024 whole-balance MIN/MAX dump twice over: the size is the slice, not the book; the limit is the slice's own quoted end price, not `MIN/MAX±1`. The remaining vault position (and any external LP) may fill the sale — intended (owner ruling). The sale's LP fees accrue to the post-burn book, i.e. to stayers.
5. **Payout:** `payout = c_target + actualProceeds`. Require `payout ≥ minimum_` (the exiting holder's total-slippage bound, covering the sale). Burn `s`. Transfer actual `payout` with delta verification (SO: `_payTarget`).
6. **Residuals:** if the sale cannot complete within its limit (shallower book than the quote saw — possible only if state changed mid-transaction, i.e. nested-context interference, which §2's blocked rule prevents; or dust-tick exhaustion, fixed per §12/026), the whole redemption reverts; the holder retries with a smaller `s` or waits for depth. **In-kind fallback:** not required for correctness; I recommend an optional `acceptOpposing` parameter (default false) that pays any unsold opposing slice in kind. This changes the "pays only target" rule and is listed in §14; default keeps PRD :98's exclusion of basket exits.
7. **Last-holder exit:** `s == S` → `f = 1`, all three positions close, the whole opposing balance sells (that *is* the slice now), payout = entire book proceeds; supply → 0. No remaining-holder checks apply.
8. **Remaining holders:** no `HolderValueLoss` check (SO: Money.sol:174-177) — deleted. It compared two quotes of the same manipulated state and is the reason 012/024 passed their own guards. Under slice-actual exits, stayers' token claims change only by the fill of the exiter's sale, which is the intended trade. The conservation test becomes: stayer share counts unchanged; stayer fraction of remaining liquidity exactly preserved; stayer token deltas equal the sale fill, nothing else.
9. **Liquidity failure / depleted sleeve:** covered by atomic revert; there is no `InsufficientLocalTarget` sleeve-only path for two-sided books anymore (§2 blocked rule). Disabled registry still permits exits (SO + SEC-10).

### 6. Quote implementation and getRate

- **`getRate()`** = preview of the §5 exit for exactly one whole share (`q = 10^decimals`), normalized to 1e18: simulate harvest checkpoint + slice `f = q/S` + sale of `c_opp` through the stepper; `rate = mulDiv(payoutPreview, 1e18, q)`; `S == 0 → 1e18`. This is the owner's retained preference: a decimal-normalized one-whole-share target exit quote from an actual withdrawal-and-sale *preview*. It is an execution quote at one fixed size — it is not NAV (issuance never reads it) and not a promise of proceeds for any other size (price impact is size-dependent; brief's own warning). A rate read never executes the quoted swap.
- **Arbitrary-size previews quote their actual size.** `previewExchangeIn/previewExchangeOut`, `quoteTransition`, `quoteAssets`, `quoteRate(exchange, asset, state)` all run the projected stateful path — including the entry swap simulation and the slice-sale simulation — at the requested amount, reusing `Projection`/`Quote.projectSwap` (SO: Projection.sol `projectSwap` already projects a real swap through external liquidity plus owned positions with fee accrual). The one change: projected issuance uses the *projected executed* price from the simulated entry swap, mirroring §2 exactly, so preview/stateful parity holds by construction (PRD §10 same-state parity requirement).
- **Exact-input/exact-output interfaces:** unchanged selector surface; exact-output in-routes are simulation-estimated pulls with refunds (§3); exact-assets out burns the ceil-computed shares from the projected path and pays actual (≥ requested or revert).
- **Projected-state rate queries** (`quoteRate` with state) project the one-share exit over the supplied sequential state, as `Projection.value` does today for whole-book value (SO: EconomicTarget.sol:33-41), now over the new machine.
- **Consistency rule:** preview and stateful flow share one implementation (Projection mirrors Money); a parity test matrix replaces any prose claim.
- **Liveness:** the one-share sale is tiny, and the stepper is fixed per §12, so `getRate` no longer inherits the whole-book 512-step freeze (APEX-026 mechanism; the freeze came from selling the *entire* opposing inventory — SO: `Common.quoteRequest` + `LiquidationQuote._sell`).

### 7. Fee compounding and maintenance

- **Collection:** `Harvest.harvest` collects both tokens' fee growth into locals; converted wings (fully crossed, holding only the wrong token) close into locals (SO: `Inventory.harvestEligible`, `Harvest.harvest`). Never swaps (owner ruling kept).
- **Compounding target/opposing fees:** placement re-deploys locals: sleeve floor in target stays liquid; target surplus pairs into the full-range core; opposing-token residuals (including opposing fees) go to their geometric wing — token0 to the upper wing, token1 to the lower wing (SO: Geometry.sol:40-43). This is the user's "compound fees into the appropriate upper and lower wings," with one explicit ownership statement: **all reinvestment is book property of all holders pro-rata; there is no per-section or per-cohort attribution of compounded fees.**
- **Range creation/replacement:** ranges derive from current price via `Geometry.ranges`; wings are recreated at the current geometry when their old range is converted and closed; a deposit never opens a range for itself (owner ruling kept — placement is shared inventory policy, identical ranges for everyone).
- **Rebalance (maintenance swap):** the permissionless `rebalance` (sells pending target cash to build core; SO: RebalanceTarget/Planner) is kept but its loss cap is re-measured at the **pre-call price**: record `sqrtPriceBefore`; in `_validate`, value the post-reshape inventory (locals + principal + fees) at that recorded price — deterministic principal math, no re-quote at the vault's own post-swap spot — and charge realized impact `input − output·P(sqrtPriceBefore)` against the cap. Clamp `bestSwap`'s `priceLimit` to a fixed deviation band around `sqrtPriceBefore`; cap per-call input. This is the audit's own smallest-change fix (SO: APEX-025 Fix section) and closes both R1 (self-moved spot cancels out) and R2 (front-run inflated baseline) at the measurement level; runtime evidence pending.
- **Who bears costs / forced actions:** transacting users pay the gas of the harvest/placement their call triggers (kept). Rebalance is permissionless but progress-gated: `NoRebalanceProgress` when nothing improves (SO), loss cap now measured at pre-call price, and caller-supplied `minimumValueAfter_` retained. A caller cannot force a sale of the opposing token at all (only acting-holder entry/exit swaps sell, and only their own tranche/slice) — this is the owner ruling, and it is what makes the maintenance surface safe to leave permissionless modulo the 025 guard.

### 8. Gas

No gas was measured in this assignment (research pass; no tests run). Structural statement only:

- **Deposit:** O(1) storage + harvest (three positions × two tick reads each, SO: `Harvest.loadCapacities`/snapshot) + one *real* swap whose cost is actual tick traversal proportional to initialized ticks crossed — this is real execution the caller sized, not a quote walk + ≤ 3 `modifyLiquidity` + mint. **No on-chain solver loop.**
- **Redeem:** harvest + ≤ 3 partial burns + one real slice sale + transfer. Burns of a fraction of L are constant work each.
- **`getRate` / previews:** view-only stepper walk for a one-share (tiny) sale with the dust-skip fix; bounded by price distance, not by foreign tick count.
- **Where solving happens:** the zap split `x` is solved off-chain (UI/keeper calls the view `Projection` via `eth_call`, or a quoter service) and passed in; on-chain verification is the closed-form `V_pre`/`mint` arithmetic — three positions, no iteration. This removes the original gas objection to exact proportional zap-in (brief item 1) without moving any pricing onto a manipulable view. The only remaining on-chain search is `RebalancePlanner.bestSwap`'s 12-iteration binary search inside the separate, permissionless, progress-capped rebalance (SO) — not on the user path.

### 9. Independent price: what is used and why

- **Issuance reference:** the entrant's own executed entry-swap price `p_e`. It is not an oracle, not `slot0`, not a TWAP, and not a simulation — it is a settlement result. Honesty requirement (brief question 9): I do **not** claim this is spot-independent. It is live-execution-derived. Its security argument is (i) numerator invariance (`C = D` regardless of `p_e`), (ii) victim-side bounding by `minimum_`, (iii) exit-side neutrality because exits realize actuals, (iv) the vault's own in-range liquidity earning fees on any push (the pusher pays the book). The residual self-deal denominator attack is in §10 and is the reason §13 mandates the APEX-012 round-trip suite before any deployment.
- **No external oracle:** none is required at any point; deployment eligibility is therefore any hookless V4 pair (the brief's warning about arbitrary pairs is honored). **Optional** per-instance clamp: if the owner configures an external reference for a covered pair, `p_e` is clamped to a deviation band around it and the deposit reverts outside the band; default off. I recommend shipping without it — an optional clamp that is usually absent must not be load-bearing.
- **No TWAP:** a self-maintained V4 tick accumulator over the vault's own pool is manipulable between touches when the vault is the dominant LP, and stale otherwise; rejected (IN).
- **Valuation at the reference:** `V_pre` values the whole book — including LP principal inside ranges — at `p_e` via deterministic principal decomposition at the *current* tick. The range principal amounts are read at the live tick (unavoidable: the tick decides the token split), but the conversion rate between the two tokens is the executed `p_e`, not the live marginal price; a crossed-tick push changes `A0/A1` composition, which is exactly what §10 analyzes.

### 10. Attacker economics (illustrative, not demonstrated)

Labels: IN throughout; none of this is runtime evidence. Existing demonstrated exploits are the audit PoCs (SO: APEX-012/024/025/026/040 with passing test output); this design must be re-measured against those PoCs (§13).

1. **In-unlock JIT depth (012 variant 1).** Deposit adds depth unsettled, redeems at inflated quote. Here: redeem pays slice actuals — an unsettled position cannot be burned by the vault inside a foreign unlock at all, and two-sided books revert while `isUnlocked()` (§2). The pricing surface (quote-valued redeem) is gone. Status: mechanism removed by construction; confirm by re-running `test/apex_audit/wings-spot-nav` against the new machine.
2. **Settled JIT / depth add-remove around a deposit.** `V_pre` contains no external depth. Adding/removing liquidity around the call changes nothing in the mint formula except the entrant's own swap execution (JIT depth *improves* the entrant's fill at the JIT provider's expense; JIT removal worsens it, bounded by the entrant's `minimum_`/`minSwapOut`). The 012 mint-then-redeem loop needs the *redeem* to pay the inflated mark; slice-actual redeem cannot. Expected unprofitable; must be demonstrated.
3. **Spot push round trip against the denominator (the residual attack, strongest case).** Attacker holds shares, pushes the tick (real capital, real fees both ways, vault LP collects part), which changes `A0/A1` and the entrant-set `p_e`, then deposits `D` (possibly flash-borrowed) at a depressed `V_pre = A0 + A1·p_e`, restores price, exits later at fair state. Gain ≈ `D·δ·γ` where `δ` is the relative book-value depression and `γ` the opposing share of the book; cost ≈ push round-trip fees + impact + the fact that their own exit sells actual inventory into the pool. Profitability is parameter-dependent (pool fee, external depth, `γ`, available flash capital vs book size) and **cannot be excluded by static argument** — the same is true of every AMM-executed-price mint. Mitigations shipped: entrant `minimum_` (protects third-party victims), vault fee capture on pushes, no quote anywhere on the money path, optional external clamp (§9). Honest position: if the owner requires this attack to be impossible rather than bounded-and-tested, the fallback is Alternative B (pure proportional mint, price-free by construction), which pays for that guarantee by refunding dust overage instead of crediting it.
4. **Exit-side dump (024).** Slice-sized sale with slice-derived price limit; a back-runner of a large exit now trades against a sale whose size is the exiter's own inventory — the sandwich edge is the exiter's `minimum_` tolerance, paid by the exiter, not by stayers. Stayers' loss beyond the intended fill: none by construction; demonstrate with the 024 PoC re-pointed.
5. **Rebalance sandwich (025 R1/R2).** Loss cap measured at pre-call price (§7) makes the pushed baseline and the self-moved spot invisible to the measurement; clamp band bounds the sale. Demonstrate with both PoCs.
6. **Dust-tick liveness (026).** §12 fix; the money path no longer sells the book at all, so even a reverting whole-book view cannot freeze exits. Demonstrate: dusted pool still deposits, redeems, and answers `getRate`.
7. **Donation inflation (040).** Donated fees raise `V_pre` proportionally (no cheap shares for the donor) and the round-trip guard reverts dust-supply traps; the donor recovers only their own pro-rata share of the donation. Demonstrate `attackerProfit ≤ 0` on the seed-10 PoC.
8. **Read-only reentrancy / nested contexts.** All economic views revert while `busy` (SO: EconomicTarget `_ready`, Money `preview`/`requiredInput` guards) and two-sided money ops revert while `isUnlocked()`; the vault's own `unlock` is hash-authenticated single-use (SO: `Common.execute`, `ExecutionDelegate.unlockCallback`). Kept.

### 11. getRate consumers — what can honestly be guaranteed

Observed consumer reality (SO): the V4 SE buffer hooks value share balances at `IRateProvider.getRate()` **without redeeming** — e.g. `ratedReserve()` prices the hook's whole SE holding for swap math (`UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:426-447`; same pattern in dual CP, orbital, weighted, quad stable libs). The Balancer `StandardExchangeRateProviderFacet` separately derives its rate from a **full-supply** exit preview of the SE (`_getRate`/`_safePreviewExchangeIn`), i.e. it already does not consume the vault's canonical `getRate` unchanged.

Honest guarantees and requirements:

1. A one-share exit-preview rate is an execution quote at one size at one instant. It is **not safe as a pricing oracle for any pool that pays out without redeeming**, because temporary liquidity and in-transaction price moves can move the preview (the 012 lesson, applied to consumers). No redesign of the vault's internal accounting changes this; it is a property of quoting a live hookless pool.
2. Therefore, for buffer-hook integrations the rate path must be one of: **(a) actual-size settlement** — the hook redeems/wraps shares by real `exchangeIn` at the traded size (atomic, pays actuals; the `pushed_` pre-transfer machinery already exists for this, SO: `LocalCreditLib`/`Money.pretransferBudget`); or **(b) bounded reference** — the hook consumes `quoteAssets`-style *actual-size* projections (not the scalar rate) and clamps them with an independent bound (deviation vs a stored/last-settlement rate, or an external reference where one exists). Scalar `getRate` remains for display/compat and for consumers that only need a one-share quote.
3. The rate provider facet's full-supply exit preview is a *different* number from `getRate` (whole book vs one share) and is itself a live-depth quote; under the new machine it becomes a whole-book slice-actual preview, which is better bounded (the whole-book sale's own impact is included) but still live-state. It must not be treated as manipulation-proof either.
4. **Raw target and shares are not economically identical.** A share carries unconverted opposing inventory, uncollected fee claims, and exit price impact; raw target does not. They may be treated as identical only after full conversion (i.e., never, for a live holding). Any integration that equates them (identity-leg shortcuts) inherits the 028-class of bugs (SO: audit 028, identity-leg zero payout) and the rate-risk above.
5. Fail-closed is kept: hook `_rate` reverts on failed/zero rate reads (SO: ClaimLib `:442-445`), matching PRD §10's no-substitution rule.

### 12. APEX-012/024/025/026/040 disposition (static; none closed without runtime evidence)

- **012:** money path no longer reads `LiquidationQuote.quote` or any live-depth view; mint numerator manipulation-proof; exits actual; two-sided ops revert in nested unlock. Closure claim requires the 012 PoC suite re-run (§13).
- **024:** `_swapDeficit`'s whole-balance MIN/MAX dump is deleted with the quote-priced redeem; slice-sized, slice-limited sales replace it. `HolderValueLoss` is deleted, not repaired.
- **025:** pre-call-price validation + band clamp + per-call input cap (audit-endorsed smallest fix).
- **026:** stepper fix: initialized ticks whose `liquidityNet` is negligible relative to active liquidity are skipped under a separate, much larger iteration budget, and the primary budget is re-cast as price-distance (the owner's "exhaustion must revert, not market-limited" rule is preserved for *real* work — SO: 026 design note). Deploy-time: `DFPkg._validate` additionally enforces `887272/(256·tickSpacing) < stepLimit` equivalent under the new distance budget, and I recommend a minimum `tickSpacing` (≥ 10) for cost reasons. Independently, deposit/redeem/`getRate` no longer depend on the whole-book walk, so 026's freeze vector is gone from the money path even before the stepper fix.
- **040:** round-trip guard + minimum bootstrap + donation-neutral mint (§1/§2). No dead-share sink and no virtual offset, per owner rulings O3/A2 (SO: 040 fix section) — the guard is the compatible fix the audit itself suggests.
- **Reentrancy/read-only reentrancy/nested unlock:** §10.8. Quote liveness and dust ticks: above. No static proposal closes a finding; each closure sentence above is a hypothesis for §13.

### 13. Production-first validation plan (to be run at implementation, not in this assignment)

Harness law (SO: CLAUDE.md): production-first, no mocks of the SUT, gold TestBases, `forge build` before `forge test`, hermetic default profile; deploy through `indexedexManager.deploy*DFPkg`. Extend `test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol` (SO: exists).

1. **Invariants (state and property):** (a) deposit conservation — incumbents' claim valued at the entry's executed `p_e` never decreases (rounding-exact, tolerance 0 in the favorable direction only); (b) exit conservation — stayer share counts constant, stayer fraction of remaining liquidity exact, stayer token deltas equal the slice-sale fill; (c) custody — `balanceOf ≥ booked` always, sum of holder entitlements at any executed price ≤ book at that price + bounded rounding; (d) fee-counting — growth counted exactly once across collect/add/remove (SEC-06).
2. **Attacker round trips (re-pointed audit PoCs):** wings-spot-nav (JIT and settled variants), wings-forced-dump, fz-wings-rebalance-sandwich + backrun-cap, wings-quote-cap-dos (now: assert deposit/redeem/getRate succeed dusted), dry-r5 donate-inflation (assert `attackerProfit ≤ 0` and victim round-trip within tolerance). New: self-deal denominator-manipulation round trip (§10.3) across a fee × depth × opposing-share matrix, asserting attacker net ≤ 0 *or* publishing the exact parameters where it is positive — that result gates the Alternative-B fallback decision.
3. **Equivalence/parity:** preview vs stateful same-state parity for every quote selector (PRD §10); `quoteTransition` sequential composition; exact-output refund exactness (SEC-02/SEC-04).
4. **Integration:** buffer-hook rate consumers under both §11 modes (actual-size settlement; bounded reference), two Wings instances on one PoolKey with opposite targets (PRD §12 cross-instance), DETF/SY paths, registry-disable exit preservation (SEC-10), blocked/unlocked context matrix (SEC-16 successor).
5. **Geometry/fee fuzzing:** SEC-07 tick/extrema matrix and wing conversion cycles under the new mint/exit; dust and `B_min` boundary; native-decimal extremes.
6. **Gas acceptance:** PRD §13 receipt-level measurements on the required case list, including the entry-swap deposit and slice-sale redeem across price regions; no via-IR.

### 14. Explicit changes from current expectations, limitations, owner decisions, simplest surface

**Explicit requirement changes I recommend (each with its cost):**

1. **Issuance is priced at the entrant's executed entry-swap price.** Changes: apportioned-PRD "no price is required / mint from liquidity actually added" (SO) and the older PRD's default rejection of reference-priced valuation (SO: 012 fix note citing PRD l.351). Cost: a residual live-execution manipulation surface (§10.3) that must be bounded by tests and optional clamps, versus a price-free mint that cannot fully credit imbalance. This is the price of the user's full-credit requirement.
2. **Deposits perform an entry swap whenever the book is two-sided** (externally sized, on-chain verified). Changes: the current target-only no-swap deposit (SO: Money._deposit; owner correction recorded in OPEN-QUESTIONS §1 kept the no-sale deposit as reference). Cost: entry gas + MEV surface on every two-sided deposit. Kept ruling honored: conversion happens only on the acting holder's entry/exit.
3. **`getRate` = one-whole-share exit preview (execution quote).** Changes: apportioned-PRD's settled-counter rate ("does not preview that swap and does not read the current tick"; SO) and PRD §10's "do not value a share by independently liquidating only one share's basket" (SO). Cost: the rate is a manipulable view and must be quarantined from accounting and from naive consumers (§11). This matches the user's explicitly retained preference; the older rules are the ones being amended, and I say so plainly.
4. **Two-sided books revert deposit/redeem while the PoolManager is unlocked.** Changes: current sleeve-only blocked redemption (SO: Money.sol:167-170) and the "spec F2 blocked zap-out" direction referenced in the audit's 012-adjacent fix text. Cost: nested-context integrations lose blocked-mode exits for two-sided books; gain: the in-unlock JIT class loses its pricing surface entirely.
5. **`HolderValueLoss` and the quote-priced `HolderValueLoss`/`costBound` machinery deleted.** Changes: PRD's liquidation-proceeds share valuation (:107/:181 as cited in SO: 024 design note). Cost: none to holders — the check compared two readings of the same manipulated state.
6. **Rebalance loss cap measured at pre-call price + clamp band.** Changes the 025 status quo; permissionless rebalance retained.
7. **Quote stepper: dust-skip + price-distance budget + deploy-time spacing validation.** Modifies the "exhaustion reverts" rule only in that negligible-liquidity ticks no longer count as work (owner's anti-market-limited ruling preserved for real work).
8. **Bootstrap: minimum first deposit `B_min` + round-trip guard.** No sink, no virtual offset (O3/A2 respected). Cost: a first-deposit floor.
9. **Optional `acceptOpposing` in-kind exit fallback** (default off). Would change "pays only target" (PRD :98 basket-exit exclusion). I recommend default off; listed because the brief asks whether in-kind fallback is necessary — it is not.
10. **Exact-shares output routes become estimate-pull-refund**; a strict no-estimate exact-output deposit route is dropped. Cost: one UX affordance; gain: no on-chain iterative solver.

**Practical limitations:** `p_e` issuance inherits live-execution manipulation risk (§10.3); blocked-mode exits are lost for two-sided books; entry swaps add gas; `getRate` cannot serve as a redemption-free pricing oracle (no design can make a live hookless-pool quote safe for that); the whole-book `liquidationValue` view remains manipulable and must be documented as integrator-only.

**Deployment eligibility:** any hookless V4 pool (`hooks == 0`, spacing within validated bounds — recommend ≥ 10), either target side; immutable DFPkg via the manager registry, unchanged; no oracle prerequisite; two instances may share a PoolKey with opposite targets.

**Decisions left to the owner:** `B_min`; `dustThreshold`; the rebalance clamp band and per-call input cap; whether to ever enable `acceptOpposing`; whether to configure external-reference clamps for oracle-covered pairs; minimum tickSpacing; whether the residual §10.3 risk, once measured, is accepted or triggers Alternative B.

**Simplest implementation surface:** rewrite `Money._deposit`/`_redeem` to §2/§5 (delete quote calls, add entry swap and slice accounting); delete `HolderValueLoss`/`_swapDeficit`; extend `Projection` with the entry-swap and slice-sale steps (its `projectSwap` already exists); keep `Harvest`/`Geometry`/`Inventory`/`Repo`/`Common`/facet surface essentially as-is; repurpose `LiquidationQuote` to integrator-views and sale-limit construction only, with the stepper fix; `_validate` additions in `DFPkg`; `RebalanceTarget._validate` repricing. V3 is explicitly out of scope for this run.

## Alternatives compared, and the strongest objection

**Alternative A — fungible shares + true independent-reference (external oracle) valuation for issuance, actual-proceeds exits, execution-quoted getRate** (the parent's proposal, which the user agreed to modulo the getRate correction). Issuance: `V_pre = A0 + A1·P_ref` with `P_ref` from a configured oracle. Cleaner than my `p_e` *where an oracle exists*: denominator manipulation removed entirely. Rejected as the default because no oracle exists for arbitrary pairs (brief item 8) and restricting Wings to oracle-covered pairs destroys long-tail deployment eligibility; my design is literally Alternative A with `P_ref := p_e`, so an oracle clamp can be layered on per instance later without restructuring.

**Alternative B — oracle-free strictly proportional ownership + externally supplied zap sizing + on-chain closed-form verification/refund.** Mint `f·S` with `f = min(t/A0, o/A1)` against post-harvest totals (all off-chain sizing, on-chain min — no solver loop); the non-binding overage is refunded in kind (or, if target, simply never pulled via estimate-pull). **Strongest point in its favor — and the strongest objection to my preferred design:** it is manipulation-proof by construction, with no executed-price denominator at all; incumbents are exactly preserved token-by-token (`t ≥ f·A0 ∧ o ≥ f·A1`), not merely value-preserved at a manipulable price. **Why I still prefer the preferred design:** refunding the overage fails the user's headline requirement — full credit for imbalanced contributions, retained in the vault — and refunding the opposing token violates "accepts and pays only the target token" (SO: apportioned PRD). Crediting the overage into a wing without a price reintroduces the silent donation the user explicitly rejected. Alternative B is the correct fallback if the §10.3 residual attack measures profitably at production parameters, and the validation plan is written to make that decision mechanical.

**Alternative C — separate section/range claims (multi-ERC20 / ERC1155 / NFT baskets).** Gives perfect per-section attribution of compounding (brief item 10's "latest alternative"), but: breaks single-fungible-share usability in external pools (the user's second business need), forces N rates or a basket valuation (which needs the very prices we refuse to trust), complicates exits (selling N claims' slices), and cross-section compounding becomes either a taxable transfer between claims or a valuation again. It solves a bookkeeping problem the user does not have — every holder already owns every section pro-rata — at the cost of the product's core usability. Rejected.

**Alternative D — invariant-based issuance (e.g. sqrt of aggregate actual-reserve product).** Rejected per the brief's own warning: with heterogeneous ranges (full-range core + two one-sided wings), aggregate reserve products are not a manipulation-resistant invariant — the token split at the live tick moves the product, and temporary depth/JIT still enters through any live reading. No credible repair found.

**Strongest counterargument to the preferred design (restated):** the executed-price denominator keeps one live-execution manipulation channel open (§10.3); victim protection is by slippage bound, and the self-deal round trip is argued uneconomic, not proven; if the owner values a provable mint over full imbalance credit, Alternative B is strictly safer and strictly simpler, and the delta between the two designs is exactly "credit the overage at `p_e`" versus "refund the overage."

## Limitations of this response

- Static reading only: no Forge run, no gas measurement, no PoC re-execution (not authorized in this assignment). Every "closes" statement in §12 is a construction argument pending §13 runtime evidence.
- I did not read the audit PoC sources or the Wings TestBase body; fixture-level surprises are possible.
- §10.3's profitability boundary is illustrative math, not a bound; it is the load-bearing open risk of this recommendation.
- The 025 repricing formula uses deterministic principal valuation at the recorded pre-call price; pathological fee-growth edge cases between the price record and validation were not exhaustively analyzed.
- Buffer-hook remediation (§11) is specified at the guarantee level, not the code level; the hooks are out of this run's redesign scope but are the rate's most dangerous consumers.
