# Kimi independent response — v4-swap-capture-evidence-20261026-01a177b3

## Identity

Fresh Kimi council member, independent initial pass. Requested model: kimi-coding/k3:high, global route. Any Native identity beyond that: not exposed. Peers read before submission: no. Prior council reports, handoff conclusions, and other docs/research/v4-* artifacts: not read. All claims below are derived from production source, the audit text, and pool math, plus exact-arithmetic simulation in `members/kimi/model.py` (standalone; no project code was built, tested, or modified).

## Question and targets

Question: when the target token's only liquidity is the underlying Uniswap V4 pool and the only reference is this project's own TWAP of that pool, do actual swaps during deposit and during exit eliminate APEX-2026-012? For every candidate rule, the mint equation, fee cutoff, inventory cutoff, and execution rule are stated separately below.

Sources actually read: `Money`, `Accounting`, `LiquidationQuote`, `Inventory`, `Geometry`, `Harvest`, `Common`, `ExecutionDelegate`, `EconomicTarget` under `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`; the audit finding APEX-2026-012 in `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md` (with 024/025/026/040/050 read as context); `UniswapV4MultiPoolTwapOracleTarget.sol` and `libraries/UniswapV4TruncatedTwapOracleLib.sol`.

Notation: target token = T, opposing token = O, spot p = O per T, q = 1/p = T per O. Book = (A_T idle+removable T, A_O idle+removable O). Supply S. Deposit D. Entrant swap fraction α. ω = q0·A_O / V0 = opposing share of book value at reference spot q0.

**Rule 1 (production, control baseline).**
- Mint equation: `m = S·D / V`, `V = Quote.quote(...).value` taken post-harvest, pre-credit (the pending D is not yet in `local0/local1`; `Accounting.issue = mulDiv(supply, credit, value)`).
- Fee cutoff: the quote collects all uncollected position fees into the book totals; the simulated sale pays the combined LP+protocol fee on every step (reduces `proceeds`); no fee on the payout itself.
- Inventory cutoff: whole book — both idle balances plus full removable principal and fees of all three positions; `_removeOwned` removes only this vault's own liquidity; if the simulated sale exhausts the book, unsold opposing is valued at zero (`marketLimited`).
- Execution rule: deposit executes no swap. Redeem pays the quote entitlement from the idle sleeve; if short, `_fund` closes positions and `_swapDeficit` sells the *entire* idle opposing balance (not the redeemer's slice) at a MIN/MAX price limit; overshoot is retained; `HolderValueLoss` re-quotes the same state and bounds the drop by `swapCost`. Production already executes real swaps on exit and the finding exists anyway — direct evidence that execution alone does not fix it.

**Rule 2 (real swaps added, mint/payout still the live whole-book quote).**
- Mint equation / fee cutoff / inventory cutoff: identical to rule 1.
- Execution rule: entry swap of α·D target executes pre-mint (output booked into local opposing); exit slice sale executes with proceeds retained by the book; the amounts minted and paid remain quote functions of live slot0/liquidity/bitmap.

**Rule 3 (literal executed-price mint, realized slice exit).**
- Mint equation: `m = S·D / (A_T + p_exec·A_O)`, `p_exec = αD/ΔO` = executed T per O of the mandatory entry swap. Pre-swap form uses the pre-entry book. The fee-aware post-swap form uses the retained book `(A_T + D − αD) + p_exec·(A_O + ΔO)`, which is *exactly* `A_T + D + p_exec·A_O` because `p_exec·ΔO = αD` by construction.
- Fee cutoff: entry-swap fee is paid out of the entrant's deposit; exit slice sale fee is borne by the slice (reduces realized proceeds); LP fees landing on retained positions vest to incumbents; the fee-aware variant additionally credits old LP fees into the book.
- Inventory cutoff: the *untraded* opposing inventory A_O is converted to target at `p_exec` — the price of a trade of size αD that did not touch A_O. This is the crux.
- Execution rule: entry swap of α·D target realized pre-mint; exit removes fraction f = m/(S+m) of each position and both idles, sells exactly f·A_O′ opposing realized, pays f·A_T′ plus realized proceeds; no top-up from other holders.

**Rule 4 (price-free proportional position-vector mint, realized slice exit).**
- Mint equation: `f = min_i c_i / (X_i + c_i)` over components i; `m = f·S/(1−f)`; refunds `r_i = c_i − f·(X_i + c_i) ≥ 0` returned to the entrant in kind. Components: idle T, idle O, and *each position's liquidity units per range*. Liquidity units in disjoint ranges are **not** one scalar: equal liquidity in the core, upper wing, and lower wing holds different token amounts and different fee exposure, so a single scalar reintroduces a price (the choice of conversion) through the back door. In my idle-book witness the positioned components are the degenerate case (liquidity 0) and the two idle components carry the algebra.
- Fee cutoff: position fees vest pro-rata to each range's liquidity units, so fee growth is itself a component and cannot be redirected by the mint; the exit slice collects exactly f of each position's uncollected fees.
- Inventory cutoff: none — no cross-token valuation occurs anywhere in the mint or the payout. Only amounts that actually entered custody (realized swaps, actual liquidity units minted) count as c_i.
- Execution rule: entry conversion swap(s) and pro-rata placement realized, not quoted; exit removes f of every component, sells exactly the slice's opposing realized, pays slice target plus realized proceeds, no top-up; unsold slice opposing on a market-limited exit remains in the book (incumbents gain; safe direction) or is paid in kind — a residual policy that must be chosen, disclosed here as open.

**Rule 5 (same-pool TWAP as gate or mint reference).**
- Mint equation (reference form): `m = S·D / (A_T + q_twap·A_O)` with `q_twap = getQuoteAtTick(consult(secondsAgo))` — rule 3's structure with a slower knob. Gate form: operate only when the live quote is within a band of the TWAP mark.
- Fee cutoff / inventory cutoff: as rule 3 — untraded opposing inventory is still priced, now at the TWAP tick.
- Execution rule: as written, the oracle is externally poked: `update(key)` is permissionless and reads live slot0; `write()` credits the *entire interval since the last observation* with the write-time tick truncated to `prevTick ± 9116`; `observe/consult` additionally backfill the gap since the last observation with the *live* truncated tick via `transform()` at read time. The idealized variant assumes dense honest writes and no live-tick backfill.

## Evidence

### Production trace (rule 1), verified in source

`Money._deposit` (Money.sol:120–140): `_pull` → `_harvest` → `value = Quote.quote(Common.quoteRequest()).value` → `Accounting.issue(supply, value, assets_)` → only then `_changeTarget(assets_, true)`. `Money._redeem` (147–181): `value = Quote.quote(...).value`; `entitlement = mulDiv(shares, value, supply)`; `_fund`/`_swapDeficit` (183–215) sells the whole idle opposing balance; `HolderValueLoss` compares two quotes of the same state. `LiquidationQuote._quote` (119–135): value = target total, unsold = opposing total, `_sell` walks the live bitmap with `computeSwapStep` after `_removeOwned`; `value += proceeds`; unsold valued at zero. `EconomicTarget.getRate` = `mulDiv(quote.value, 1e18, supply)` (1e18 at zero supply); getRate stays out of the mint equation and is not redefined here; the one-share withdrawal preview is a different object and is not implemented.

APEX-2026-012 states mint `m = S·D/V0`, redeem pays `m·V1/(S+m)`, `profit = D·(V1 − V0 − D)/(V0 + D)`, with PoC profits 70,634,405,953 (in-unlock JIT) and 74,704,386,253 (settled) raw token0. The PoC outputs were not rerun, per the brief.

### Witness W0 (control): honest round trip under rule 1

Idle book A_T = A_O = 5e11, S = 1e12, standing depth L = 1e12 virtual each side, p0 = 1, fee 0.3%, D = 1e11. Deposit then immediate redeem with no manipulation: payout = D exactly, attacker net = 0, incumbent per-share entitlement unchanged (0.83266600 → 0.83266600). Both tokens conserved exactly (asserted).

### Witness W1: rule 1 JIT inflation reproduces the audit formula exactly

Same book; attacker deposits D at the honest quote, adds settled depth 9×L (the audit's settled variant; the in-unlock variant is strictly cheaper), redeems at the inflated quote, removes the untouched depth.
- V0 = 832,666,000,000; V1 = 1,074,829,700,000 (depth inflates simulated sale proceeds toward the no-slippage ceiling).
- m = 120,096,200,000 shares; payout = 115,242,700,000 target.
- Attacker net = **+15,242,727,659.27 target**, zero opposing leftover, no shares, no LP inventory, no debt.
- Audit formula `D(V1−V0−D)/(V0+D)` = 15,242,727,659.27 — matches to the last digit.
- Incumbent aggregate loss (production quote before/after, supply restored to S) = 15,242,727,659.27 — equals attacker profit exactly; both tokens conserved exactly.
- `HolderValueLoss` passes during the attack because both quotes read the same inflated state.

### Witness W2: rule 1 deflation direction (depth pulled, not added)

Attacker owns 9×L standing depth (part of the baseline state), pulls it (quote crashes 974.83e9 → 832.67e9), deposits D at the crashed quote, restores depth, redeems at V1 = 1,074.83e9, then fully unwinds. Attacker net = **+15,242,727,659.27 target**, leftover opposing exactly 0. Same magnitude, opposite direction: temporary *absence* of depth is as potent as temporary depth. Incumbent loss measured token-wise = payout − D = 15,242,727,659.27 (the quote-based before/after difference is contaminated by the depth change itself — a good illustration of why token-denominated closure is required).

### Witness W3: rule 2 — executed swaps, quote pricing kept — does not eliminate

Entry swap α = 50% executed, exit slice sale executed, mint/payout still the live whole-book quote.
- Control (no JIT): entrant net = **−5,089,304,282.62** (ordinary fee drag; incumbents gain +4.876e9 from the swap fees). This is the baseline cost of execution, not evidence of attack.
- JIT attack (9×L): attacker net = **+10,879,800,366.89** after full flatten to target at real slippage; incumbent loss = 11,093,243,841.02 (loss exceeds profit by the fees leaked to external LPs — conservation holds exactly). The executed swaps perturb the book by fee-sized amounts and do not touch the quote's dependence on temporary depth.

### Rule 3 — executed-price mint: exact first-order boundary and closed counter-witnesses

Derivation (gift form, exact to first order in the manipulation ε = 1 − r, where r = p_exec/q0 < 1 is the executed undervaluation of opposing). To pin the entrant swap's executed price at r·q0, the attacker's depth must supply ΔO = αD/(r·q0) opposing for the vault's αD target; at the reference value that opposing is worth αD/r target, so the attacker gifts `g = αD·(1/r − 1)` to the book. The mint gives `f = D/(V(r) + D)` with `V(r) = V0 − ε·q0·A_O`; the exit at the restored state pays `f·(V0 + D + g)`. Net:

E = D·(V0 + D + g)/(V0 − ε·q0·A_O + D) − D − g  ≈  **ε·D·(q0·A_O − α·V0)/(V0 + D)**  to first order.

E > 0 ⟺ **α < ω = q0·A_O/V0** (the opposing value share of the book). Consequences, each verified numerically:

- On a balanced book (ω = 1/2) the asymptotic boundary is α = 50%; 49/50/51 are parameters, not safety thresholds, because the boundary is ω, not a constant. Exact grid (fee = 0, manipulation t1 = 10% of standing depth, balanced book): α = 0.44 → **+304,786,000**; α = 0.46 → −2,076,180; α = 0.49 → −15,036,000 ≈ the honest drag baseline (−54,028,660 at fee 0; see Limits on the small gap between the asymptotic boundary and the finite-displacement grid).
- An opposing-heavy book breaks "51% is safe": A_T = 2e11, A_O = 8e11 (ω = 0.8), α = 51%, fee 0.3%, t1 = 2e11: attacker net = **+6,462,528,490.26** fully closed (shares 0, LP 0, debt 0, opposing residual flattened at real slippage, both tokens conserved exactly); incumbent per-share production quote 0.643703 → 0.636108 (their loss exceeds the attacker's profit by the manipulation fees paid to external LPs). p_exec observed = 0.6827 (opposing undervalued 32% in the mint).
- The fee-aware post-swap variant (denominator = A_T + D + p_exec·A_O) shifts but does not close the hole: same book, α = 30%, t1 = 4e11 → **+8,638,361,543.10** closed.
- Attacker-chosen size: positive region persists at D = 5e11 (α = 51%, same book, t1 = 2e11 → +3,128,158,354.82 closed); profit is concave in D at fixed manipulation budget, so the attacker optimizes D as well.
- Exit side of rule 3 is sound: inflating *realized* proceeds requires real buy depth for the slice, and when the attacker is the exiter that depth is their own money paid to themselves — circular, net ≤ 0. The hole is mint-side only.

Mechanism confirmation of the brief's hypothesis: a swap prices the quantity that traded (αD), and rule 3 extends that price to inventory that did not trade (A_O). The extraction scales with A_O, not with αD; that is exactly where it fails.

### Rule 4 — price-free proportional mint: invariant, proof, and numeric verification

Invariant (incumbent ownership conservation): for every component i, an entry with `f = min_j c_j/(X_j + c_j)` and refunds `r_i = c_i − f·(X_i + c_i)`, and an exit that removes exactly the holder's fraction of every component, leave every incumbent's per-share claim on every component weakly increased (entry) and exactly preserved except for the exiting slice (exit).

Proof sketch (exact, price-free). Entry: incumbent per-share claim on component i goes from `X_i/S` to `[X_i + c_i − r_i]/(S + m) = [X_i + f·(X_i + c_i)]·(1−f)/S`. This is ≥ `X_i/S` ⟺ `(1−f)(X_i + c_i) ≥ X_i` ⟺ `c_i ≥ f·(X_i + c_i)`, which holds by construction of f; equality on the binding component. Exit: removing f·X_i and f·S leaves `X_i(1−f)/(S(1−f)) = X_i/S` for every component, whatever price the slice sale executes at, because the sale touches only the exiter's slice. No price enters either equation, so there is nothing to manipulate. Domain: any book composition, any price, any depth, any supply; requirements: (i) contributions measured from what actually entered custody (realized conversion and placement, not quotes); (ii) exact refunds in kind, including opposing-token refunds — an interface change, since production flows are target-only; (iii) each position range tracked as its own component; (iv) market-limited exit residual policy as stated above; (v) bootstrap at S = 0 mints m = D with the deposit as the initial vector (matches production `issue(0,0,D)`).

Numeric verification (model.py, exact rationals, conservation asserted):
- Honest control (α = 50%): entrant net = −491,836,743.29 (execution drag only); incumbent per-share ratios: binding component exactly 1 (exact rational equality), non-binding 2643984234/2642930405 ≈ 1.00039873.
- Every rule-3 attack cell replayed against rule 4 loses: balanced book, α = 30%, t1 ∈ {5e10, 1e11, 2e11, 4e11} → net ∈ {−2.65e9, −2.99e9, −3.52e9, −4.63e9}; the rule-3 killer book (80% opposing, α = 30%, t1 = 2e11) → net −4,593,928,324.64 with incumbent ratios T = 1.014822 (up), O = exactly 1. The attacker's manipulation still costs them the round trip, but there is no mispriced denominator to recover it from.

### Rule 5 — same-pool TWAP: source trace

`UniswapV4TruncatedTwapOracleLib.write` records `tickCumulative: last.tickCumulative + int56(recordedTick)·delta` where `recordedTick = truncate(liveTick, prevTick)`: the entire interval since the last observation is credited with the tick read at write time. `observe`/`consult` compute the now-endpoint via `transform(last, time_, tick_)` with the live tick: the gap since the last observation is backfilled with the live tick at read time too. `MAX_ABS_TICK_MOVE = 9116` bounds each recorded step to a factor 1.0001^9116 = **2.4882** per write; `update(PoolKey)` is permissionless and external, so an attacker can poke per block and the recorded tick can follow any sustained manipulation at up to 2.4882× per write — the truncation is a rate limit, not a bound. APEX-2026-050 (read as context) independently documents the write-side backfill and the writeAge reset. As a mint reference, the TWAP still prices untraded opposing inventory — rule 3's hole with a slower knob. As a gate, the band can be held in-range by the same sustained manipulation. Under the premise — no other venue, no outside arbitrageur assumed — holding a dislocated tick for one window costs only the initial move plus whatever organic flow trades against it; in the worst case (attacker-only flow) holding is free after the move. An idealized historical TWAP (dense honest writes, no live backfill) therefore raises the attack cost from zero-capital/single-transaction to one-window holding cost; it does not eliminate the finding.

## Assumptions

- Single tick interval, exact rational arithmetic; production integer rounding (<1 unit per step, conservative direction in `SwapMath`) is omitted and is immaterial at 1e11 scale. LP fee 0.3%, no protocol fee. All sales stay inside the interval; the `marketLimited` unsold-valued-at-zero haircut is never triggered.
- Idle book: no core/wing positions. This is production-reachable at a 100% liquid sleeve or with geometrically unavailable wings; the scripted sleeve is 0% (fully deployed), per the audit's design note. With positions, the mint/payout equations are unchanged and the book's token composition becomes price-dependent (wings convert as price moves), which *adds* attack surface — it cannot close the rule-3 hole. Harvest, both-wing activation, hooks, and multi-interval bitmap walks are unmodeled.
- JIT/standing depth is modeled as settled liquidity (the audit's settled variant). The in-unlock unsettled variant is strictly cheaper for the attacker; modeling settled depth is the conservative choice for the defense.
- Attacker capital is unrestricted but fully accounted: every witness closes both tokens exactly, ends with zero shares, zero LP inventory, zero debt, and the opposing residual flattened to target at real slippage. Honest entrant controls show the baseline drag so ordinary fee/impact cost is separated from incumbent loss.
- The Wings vault is hookless in the quote (`request_.key.hooks == address(0)` enforced in `_prepare`); no hook behavior is modeled.
- getRate is the whole-book quote times 1e18 over supply and stays out of the mint equation; it is not redefined and no preview is implemented.

## Coverage

Rules 1–5 from the brief are each answered with mint equation, fee cutoff, inventory cutoff, execution rule, and a verdict. Covered by exact computation: rule-1 control, JIT inflation, and deflation; rule-2 control and JIT attack; rule-3 α-boundary scan (fee 0), 49/50/51 on balanced and opposing-heavy books, post-swap fee-aware variant, attacker-chosen D; rule-4 control and the full attack battery with the exact invariant check. Covered by source trace plus closed-form argument: rule 5 as written and idealized. Not covered: positioned-book lifecycle simulation (wings/core placement, harvest, fee accrual into claims), multi-pool TWAP aggregation, hooks, the in-unlock variant numerics, and any interaction with APEX-2026-024/025/026 beyond noting their shared root cause. A finite grid is not a universal proof; the rule-3 negative claim rests on the closed ledgers exhibited, and the rule-4 positive claim rests on the stated invariant and its proof, with the grid as confirmation.

## Conclusions

1. **Actual swaps during deposit and exit do not, by themselves, eliminate APEX-2026-012.** Production already executes real swaps on exit (`_swapDeficit` sells the entire idle opposing balance) and pays the quote entitlement; adding an entry swap while keeping the live whole-book quote (rule 2) still leaks +10.88e9 target to the settled-JIT attack in the witness (W3), because the mint and payout remain functions of temporary depth and in-session price.
2. **Executed-price mint (rule 3) does not eliminate it either.** The exact first-order margin is `ε·D·(q0·A_O − α·V0)/(V0 + D)`; the attack is profitable iff the entry-swap fraction α is below the opposing value share ω of the book. ω is book-state-dependent, price-dependent, and computable only with a price — which the premise forbids importing. So no fixed α is certifiable: 51% fails closed-ledger on an 80%-opposing book (+6,462,528,490.26), and the post-swap fee-aware variant fails at 30% on the same book (+8,638,361,543.10). 49/50/51 are parameters whose safety boundary moves with the book, not thresholds.
3. **Price-free proportional position-vector mint with realized slice exit (rule 4) does eliminate it**, with the invariant "every incumbent's per-share claim on every component is weakly increased by entry and exactly preserved by exit" over the domain stated above. Disjoint-range liquidity units are not one scalar; they must be separate components. The cost is interface complexity: opposing-token refunds, per-range contribution accounting, and a disclosed market-limited residual policy.
4. **Same-pool TWAP (rule 5) eliminates nothing.** As written, write-side and read-side backfill credit idle time with the poked/live tick (truncation 2.4882× per write; permissionless per-block pokes make that a rate limit, not a bound). Even idealized, it only reprices the attack from zero capital to one-window holding cost, and under the no-external-arbitrageur premise that cost can be as low as the initial move. It remains a pool-derived price for untraded inventory.
5. Overall answer: the finding's root is not "a view that does not trade"; it is "untraded opposing inventory converted to target at a manipulable pool price." Execution removes the hole only when it removes the conversion — rule 4. The brief's test sentence is confirmed with mechanism: a swap prices the quantity that traded, and rule 3 fails precisely by extending that price to inventory that did not trade, while rule 4 never prices untraded inventory at all.

## Limits

- The model is a single-interval idle book, not the full Wings lifecycle. Magnitudes would shift with positions (composition changes, self-fill, fee accrual); the structural results — quote dependence on temporary depth (rules 1–2), the α < ω boundary (rule 3), the componentwise invariant (rule 4), and the backfill mechanism (rule 5) — do not depend on positions. Both-wing activation, harvest, and hooks are unmodeled and this is not asserted to be a Wings lifecycle result.
- The rule-3 α-boundary scan is a finite grid. The asymptotic derivation puts the balanced-book boundary at α* = ω = 50%; the exact grid at 10%-of-depth displacement finds the crossover between 44% and 46%, with α = 49% at ≈ the honest drag baseline. The gap is second-order manipulation cost at finite displacement, which shrinks as displacement → 0, so the margin just below ω is thin and book-dependent. I do not claim α ≥ 50% is unsafe on a balanced book in my grid; I claim the boundary is ω, that ω is not a constant, and that α = 51% is already profitable on an 80%-opposing book with a closed ledger.
- Rule 4's invariant is proven algebraically per component and verified numerically for the two-component idle book; the multi-component positioned case follows from the same per-component inequality with no interaction terms, but was not simulated. Rule 4's entry conversion can be griefed (sandwiching the entrant's conversion worsens the entrant's realized vector; refunds make incumbents whole, so this is a UX/DoS concern, not extraction).
- The deflation witness (W2) requires the attacker to own a large share of standing depth beforehand; the capital is returned in full, but the capital requirement is real, unlike the in-unlock JIT variant.
- No Foundry test, transaction script, or deployment procedure was produced; the audit PoC was not rerun; no production or configuration file was touched. Standalone arithmetic only (`members/kimi/model.py`, exact rationals, conservation asserted in every scenario).
