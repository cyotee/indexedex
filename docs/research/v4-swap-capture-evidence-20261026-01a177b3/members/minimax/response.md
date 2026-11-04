# Identity

- Model: **minimax/MiniMax-M3**. Runtime exposes this as `PI_MODEL=MiniMax-M3`, `PI_PROVIDER=minimax`, `PI_REASONING_LEVEL=high`; adaptive reasoning is exposed as a level, not a selectable depth. No other MiniMax model was substituted.
- Role: council-member, run `v4-swap-capture-evidence-20261026-01a177b3`, slot `minimax`. Owned artifacts: `members/minimax/response.md`, `members/minimax/model.py`. I wrote no peer file, no draft, no resolution, no final, no `RUN.md`, no project code, no configuration.
- Independence: initial pass. **Peers read before submission: no.** I did not read `docs/reviews/apex-012-*` (any prior council report, member response, coordinator draft or `REPORT.md`), nor `docs/research/v4-*` artifacts other than this run's own `brief.md`, nor any handoff conclusion. I started from production source, the named audit text, and pool math.
- Native identity not supplied to me in the brief beyond the requested model (coordinator session id, other members' task ids, the invoking session's model): **not exposed**.
- No Foundry test, transaction script, or deployment procedure is produced. This is accounting research on the user's own unpublished vault; the negative evidence below is a closed numerical ledger.

# Question and targets

**Question.** When the target token's only liquidity is the underlying pool and the only reference is this project's TWAP of that pool, do actual swaps during deposit and during exit eliminate APEX-2026-012? State the exact mint equation, fee cutoff, inventory cutoff, and execution rule for every answer. A safety claim needs an invariant and its domain; a negative claim needs a closed token ledger.

**Answer in one line: No.** Swapping during deposit and during exit does not eliminate APEX-2026-012. It relocates the exploitable surface from the manipulable quote to the actual execution, and it introduces a **new manipulation-free extraction** whose closed ledger I give below.

**Targets read.**

| Target | Path |
| --- | --- |
| Money | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol` |
| Accounting | `.../UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol` |
| LiquidationQuote | `.../UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol` |
| Inventory, Geometry, Harvest, ExecutionDelegate, EconomicTarget, Common, Repo, Types | same directory |
| Audit APEX-2026-012 (and 024/025/026/040/050 as context) | `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md` |
| TWAP target + lib | `contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol`, `contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol` |
| Vendored V4 swap math | `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol`, `.../Pool.sol`, `.../ProtocolFeeLibrary.sol` |

# Evidence

## E1. Production money path, read from source

`Money._deposit` (`Money.sol:120-142`):

```
_pull(assets_)                       // :127  D target transferred in; state.local* NOT yet updated
supply = ERC20Repo._totalSupply()   // :129
if (supply == 0) _bootstrapBacking(...)  // :130
_harvest()                           // :131
uint256 value = Quote.quote(Common.quoteRequest()).value;   // :132
shares_ = Accounting.issue(supply, value, assets_);          // :133
_changeTarget(assets_, true)        // :136  D booked AFTER the mint
ERC20Repo._mint(recipient_, shares_)// :137
```

`Money._redeem` (`Money.sol:153-181`):

```
_harvest()                                    // :159
uint256 supply = ERC20Repo._totalSupply();    // :159
uint256 value = Quote.quote(Common.quoteRequest()).value;   // :160
assets_ = Accounting.entitlement(supply, value, shares_);    // :161
... costBound = _fund(required, remaining == 0);             // :170
ERC20Repo._burn(holder, shares_);                           // :171
_changeTarget(assets_, false);                              // :172
_payTarget(recipient_, assets_);                            // :173
if (remaining != 0) { afterValue = Quote.quote(...).value;  // :175
    if (afterValue < value - assets_ && value - assets_ - afterValue > costBound) revert HolderValueLoss(...); }
```

`Accounting` (`Accounting.sol:18-26`): `issue = supply_ == 0 ? credit_ : FullMath.mulDiv(supply_, credit_, value_)`; `entitlement = FullMath.mulDiv(shares_, value_, supply_)`.

`Common.quoteRequest()` (`Common.sol:23-35`) fills `local0/local1` from `state.local0/state.local1` (the **booked** idle balances) and `stepLimit = 512`.

Consequences, all exact:

- **No entrant swap exists on deposit.** `_pull` only transfers tokens; the vault never trades the entrant's target into the pool.
- **The quote used at mint time excludes the entrant's own deposit**, because `state.local0/local1` are not updated until `Money.sol:136`. So `V0` is the *pre-deposit* book value.
- `getRate` (`EconomicTarget.sol:27-31`) is `FullMath.mulDiv(Quote.quote(...).value, 1e18, supply)`, or `1e18` at zero supply. It is a separate object from issuance and I do not touch it.
- The only execution on exit is `_swapDeficit` (`Money.sol:219-237`): an exact-input sale of the vault's **entire** opposing balance at a MIN/MAX price limit, used only when the local target sleeve cannot fund the payout, bounded by `Quote.swapCost`.

## E2. What the quote actually is

`LiquidationQuote._quote` (`LiquidationQuote.sol:120-135`):

```
total0 = request_.local0 + context.collected0;    // booked idle + removed positions' principal+fees
total1 = request_.local1 + context.collected1;
result_.value  = request_.target0 ? total0 : total1;   // :128  the TARGET side, counted 1:1
result_.unsold = request_.target0 ? total1 : total0;   // :129  the OPPOSING side, to be sold
_sell(context, result_, request_.stepLimit);           // :132  simulated sale into external depth
result_.value += result_.proceeds;                     // :133
```

`_prepare` reads the live `slot0` (`:146`), the live `getLiquidity` (`:151`), and subtracts **only this vault's own** liquidity (`:152`, `_removeOwned`). `_sell` (`:265-300`) walks the live tick bitmap and simulates an exact-input sale of the whole opposing inventory into the remaining external depth.

So `V` is a **whole-book liquidation value of the entire vault at one live pool state**: target-side inventory at par plus the proceeds of liquidating the entire opposing side into whatever depth exists at that instant.

The audit's algebra follows and is exact: with `S` supply, `D` deposit, `V0` honest and `V1` manipulated,

```
m      = S*D/V0
payout = m*V1/(S+m) = D*V1/(V0+D)
profit = payout - D = D*(V1 - V0 - D)/(V0 + D)
```

and `profit > 0` iff `V1 - V0 > D`. Because the quote's `V` is a liquidation value, the attacker's free liquidity removes the bookits own liquidation haircut, so `V1 - V0` is bounded by that haircut `h`, and the attack needs `D < h`. No external price is used anywhere: `h` is computed from the pool itself.

## E3. The project TWAP oracle, read from source

`UniswapV4TruncatedTwapOracleLib`: `MAX_ABS_TICK_MOVE = 9116` (`:17`), `truncate` clamps the recorded tick to `prevTick +/- 9116` (`:27-36`), `write` accepts at most one write per block (`:82`) and `update` is permissionless (`UniswapV4MultiPoolTwapOracleTarget.sol:32,47`). `observeSingle` (`:200-238`) calls `getSurroundingObservations` → `transform` (`:239-250`), which extrapolates the **live** tick backwards over any idle gap.

## E4. Model, instance, and the closed witness

`members/minimax/model.py` (exact `Fraction` arithmetic) implements: the V4 exact-input swap step on a constant-product-equivalent single range (a full-range V4 position has `x = L/sqrt(P)`, `y = L*sqrt(P)`, hence `x*y = L^2`, so the pool is exactly CP with `k = L^2`); the production quote; the production control; Rule 2; Rule 3; and a faithful port of `consult`/`observeSingle`.

**Named instance.** `A_T = A_O = x = y = S = 1000e18`; fee `f = 3000` ppm; `D = 100e18`; single range; no hooks; no external price anywhere.

### E4.1 Control — production rule, source-exact convention

Convention: the mint quote uses the **booked** idle balances, so `V0` excludes the pulled-but-unbooked deposit, matching `Money.sol:127` vs `:136`; `V1` is quoted after the deposit is booked.

| JIT depth added after the deposit | `V0` | `V1` | minted `m` | payout | **attacker net target** | audit algebra `D(V1-V0-D)/(V0+D)` | both tokens conserved |
| --- | --- | --- | --- | --- | --- | --- | --- |
| none | 1499.248873 | 1599.248873 | 66.700067 | 100.000000 | **+0.000000e18** | +0.000000e18 | yes |
| x10 | 1499.248873 | 2006.610894 | 66.700067 | 125.472084 | **+25.472084e18** | +25.472084e18 | yes |
| x100 | 1499.248873 | 2087.158034 | 66.700067 | 130.508645 | **+30.508645e18** | +30.508645e18 | yes |

The honest round trip under the source-exact convention returns **exactly zero** (row 1) — a clean control — and the attacker's profit equals the auditor's closed form to the last digit (rows 2-3). My ledger closes on token0 and token1 in every row: attacker wallet + vault idle + pool reserves + LP fee pot is invariant.

### E4.2 Rule 3 — closed ledger of a manipulation-free extraction

Rule 3 as the brief states it: on deposit the vault actually swaps `s = alpha*D` of the entrant's own target through the pool; the mint uses the executed price; on exit the holder takes its fraction of each position and both idle balances, only that slice's opposing tokens are sold, and the target actually received is paid. No top-up from other holders.

`alpha = 1`, `D = 100e18`, no manipulation of any kind, no capital beyond the deposit:

```
q_exec            = s/w = 1.103009027        (target per opposing, average of the vault's own sale)
V_ref (mint denom)= 2103.009027081e18       = A_T + q_exec*A_O   (pre-swap naming)
m                 = 47.550913340e18 shares
phi               = 0.045392460390          = m/(S+m)
slice target      = 45.392460390e18
slice opposing    = 49.507790299e18
actual proceeds P = 56.618847425e18
payout            = 102.011307814e18
```

**Closure (both tokens conserved: true):**

| Party | Target | Opposing |
| --- | --- | --- |
| attacker, end | +2.011307814 (net of the 100e18 deposit) | 0 (shares 0, LP 0, debt 0) |
| vault idle, end | 954.607539610 | 1041.153299089 |
| pool reserves, end | 1043.081152575 | 958.698177540 |
| LP fee pot, end | 0.300000000 | 0.148523000 |

| Incumbent closure | Target |
| --- | --- |
| vault book realizable value, before | 1499.248873 |
| vault book realizable value, after | 1496.869356 |
| **incumbent loss** (incumbent holds 100% of supply after the round trip) | **2.379517** |
| attacker gain | 2.011308 |
| LP fee pot | 0.448523 |
| residual = change in the vault's own liquidation haircut on the retained opposing inventory | 0.080314 (disclosed, not called profit) |

The incumbent's loss is **2.379517e18**; the attacker takes **2.011308e18** of it; the LPs take **0.448523e18** in fees; the remaining **0.080314e18** is the change in the vault's own liquidation haircut and is disclosed rather than claimed. A deposit of 100e18 target returns 102.011307814e18 target with **zero manipulation, zero price move, zero borrowed capital** (except the 100e18 deposit itself, which is returned).

**Cutoffs for this extraction** (same instance; the profit function is the ledger above with `alpha`, `f`, `D`, `A_O` varied):

| Cutoff | Equation | Value | Evidence |
| --- | --- | --- | --- |
| swap-fraction | `P(alpha) = 0`, `P = payout - D` | **alpha\* = 0.579815732950** | alpha=0.5 → −0.358973302e18; alpha=0.58 → +0.000837449e18; alpha=1 → +2.011307814e18 |
| fee | `P(f) = 0` | **f\* = 20802.214799 pips (2.080221%)** | f=20000 → +0.090449747e18; f=21000 → −0.022297604e18 |
| deposit size | `P(D) = 0` | between `D/x = 0.01` and `D/x = 0.02` | D/x=0.01 → −0.005571e18; D/x=0.02 → +0.037199e18; D/x=0.1 → +2.011308e18 |
| inventory ratio `r = A_O/y` | `P(r) = 0` | no root in `r ∈ [0.01, 5]`; the profit peaks near `r ≈ 0.5` | r=0.01 → +0.823059e18; r=0.1 → +1.295413e18; r=0.5 → +2.046035e18; r=1 → +2.011308e18; r=2 → +1.550991e18; r=5 → +0.683940e18 |

The 49%/50%/51% entry-swap parameters are indeed parameters, not thresholds: in my sweep 0.49 and 0.50 are **below** `alpha*` (negative) and 0.51 is also below it (negative). The threshold is 0.5798, not 0.5.

**Inventory reachability caveat, stated because it changes the sign.** The extraction above needs the vault to hold **idle** opposing inventory. Repeating the same ledger with the vault holding a full-range-equivalent LP share `psi` of the pool (Model B) gives:

| `psi` (vault's LP share) | Rule 3 honest round trip | tokens conserved |
| --- | --- | --- |
| 0 | **+2.011307814e18** | yes |
| 0.25 | −16.494260e18 | yes |
| 0.50 | −29.317725e18 | yes |
| 0.75 | −38.727350e18 | yes |

With the vault holding LP, the Rule 3 mark applies `q_exec` to the LP's opposing principal, which the exit does not realise at that price, and the honest round trip becomes a loss. So this particular extraction is gated on the vault holding idle opposing inventory (a non-zero liquid sleeve, or the post-harvest idle state between `_harvest()` and `_place()`). It is **not** gated on the attacker's manipulation, and it is not gated on the attacker's capital.

### E4.3 Rule 2 — the manipulation survives adding a swap

Rule 2 keeps the whole-book quote for both mint and payout and only adds the deposit-side swap. Same instance, same auditor ordering (deposit, then add free depth, then redeem), source-exact convention, ledger closed on both tokens in every row:

| `alpha` | depth x10 profit | depth x100 profit | production (Rule 1) at the same depth |
| --- | --- | --- | --- |
| 0.49 | +30.428900e18 | +36.733000e18 | +25.472084e18 / +30.508645e18 |
| 0.50 | +30.534200e18 | +36.866000e18 | " |
| 0.51 | +30.639600e18 | +36.999200e18 | " |
| 1.00 | +36.005700e18 | +43.818400e18 | " |

In every row `profit == D*(V1-V0-D)/(V0+D)` exactly. Rule 2 is **worse than production** in this instance, because the deposit-side swap moves the pool price up and the whole-book quote then marks the vault's opposing inventory at the post-swap price, which raises `V1 - V0`.

### E4.4 Rule 5 — the project's TWAP is not a usable gate as written

Faithful port of `UniswapV4TruncatedTwapOracleLib.consult` → `observe` → `observeSingle` → `getSurroundingObservations` → `transform` for a stale (cardinality 1) oracle, with `t0 = 0`, `prevTick = 0`, `now = 100000`, window `W = 3600`:

| live tick | `consult(3600)` | truncated live tick |
| --- | --- | --- |
| 0 | 0 | 0 |
| +900 | **900** | 900 |
| +9116 | **9116** | 9116 |
| −9116 | **−9116** | −9116 |

`consult(W) == truncate(liveTick, prevTick)` **exactly**, for every `W`, whenever no observation lies inside the window: the whole idle gap is credited with the live (poked) tick. The magnitude of one write is bounded by `MAX_ABS_TICK_MOVE = 9116` ticks = `1.0001^9116 = 2.488187224469637x` price, `update` is permissionless, and `write` accepts at most one observation per block.

### E4.5 Rule 4 — price-free proportional position-vector mint

I did not model this numerically; the argument below is exact and does not need a simulation.

A price-free mint cannot compute "what fraction of the book does `D` target buy", because the book's value is the sum of a target-denominated and an opposing-denominated quantity. It can only do one of two things, and both change the product:

1. Define the fraction over the **target sleeve only** (e.g. `f = D/(A_T + D)`) and grant the entrant `f` of everything. The entrant then receives a claim on a **mixed basket** (target, opposing, and per-range LP claims) whose target-equivalent value is determined later, by the market, at exit. The vault becomes a basket-share issuer, not a target-denominated SE vault.
2. Define the fraction over the whole book using a **price** — which is Rule 3 and reintroduces the manipulable mark.

**Are liquidity units in disjoint ranges one scalar? No.** `L` units in `[a,b)` and `L` units in `[c,d)` are different claims: at a given price their token composition differs (`Inventory.principal` returns different `amount0/amount1` per range), their fee growth is per-range (`getFeeGrowthInside`), and their value responds differently to price. The Wings vault has at most three disjoint ranges (`Repo.positions[3]`: core, upper wing, lower wing) plus two idle balances. So "the same fraction of every existing position" is a **vector** of per-range fractions plus per-balance fractions, not one scalar ratio. A single ERC20 supply can represent it only if the per-range fractions coincide, which they do not in general.

The price-free mint therefore removes the manipulable mark **at the mint** but cannot remove the price exposure **at the exit**: the exit must still convert the holder's slice of the basket into target, and that conversion is a market trade whose price the redeemer can move. It relocates the exposure rather than removing it, and it converts a target-denominated product into a basket product.

# Assumptions

1. **No independent price.** Every number in E4 comes from the pool. The incumbent's loss is measured as the change in the vault's own **realizable liquidation value** (target-side inventory at par plus the proceeds of liquidating the opposing side into the pool's remaining depth), which is the same function `LiquidationQuote` uses, evaluated on the final pool state. No external fair price is imported and no leftover token is marked as profit.
2. **Pool reduction.** A single range, constant-product equivalent. A full-range V4 position satisfies `x = L/sqrt(P)`, `y = L*sqrt(P)`, hence `x*y = L^2`, so the pool is exactly CP with `k = L_total^2` and every operation is exact. The production Wings pool is **bounded-range**, hence piecewise, and the production quote walks ticks (`:265-300`). My single-range model is a labelled reduction, not a Wings lifecycle result.
3. **JIT liquidity mechanics.** Adding liquidity at the current price scales both reserves by the same factor and leaves the price unchanged (full-range property). This is the exact V4 add/remove-liquidity mechanic for the depth manipulation, which is the auditor's own mechanism.
4. **Concentrated-range capture is not modelled.** The audit's PoC adds a *narrow* range around the current price (`modifyLiquidity(key, -887220, 887220, +1e22, salt)`). A narrow range captures the price impact as extra target, which a full-range position does not. My model therefore **understates** the attacker's take in the depth-manipulation scenarios, and I flag any residual opposing balance in the attacker's wallet as a disclosed leftover rather than as profit.
5. **Bookings.** The mint quote uses the booked idle balances, so `V0` excludes the pulled-but-unbooked deposit (`Money.sol:127` vs `:136`). At redeem time the deposit is booked. Rule 3's mint denominator is written on the same convention.
6. **Rule 3 semantics as modelled.** The exit pays the holder's fraction of the target idle **plus** the actual proceeds of selling that slice's opposing. The narrower reading (pay proceeds only) is strictly worse for the redeemer and only enlarges the extraction reported in E4.2.
7. **Fee treatment.** `f` is the V4 LP fee charged on the input token; the fee leaves the trader's balance and accrues to a separate LP fee pot, as in V3/V4, and is never destroyed. Protocol fee is assumed zero (`ProtocolFeeLibrary.calculateSwapFee` returns the LP fee when the protocol fee is zero); the production quote requires `key.hooks == address(0)`.

# Coverage

**Analyzed end to end, with a closed ledger and a control:** production rule 1 (mint and redeem equations, quote semantics, the auditor's algebra, the haircut bound); Rule 2; Rule 3 (deposit-side swap + executed-price mint + pro-rata actual exit), including its fee, swap-size, deposit-size and inventory cutoffs and its reachability with and without the vault holding LP; Rule 5 (the project's own TWAP, as written, by faithful port); Rule 4 (exact argument, no simulation).

**Not modeled, and therefore not claimed:** both-wing activation; the harvest → place cycle as a lifecycle (I treat the book as idle inventory plus an LP share, with one `Harvest`-shaped state transition assumed to have already happened); rebalance; `Projection`; hooks (excluded by the production quote anyway); `depositExactShares` / `redeemExactAssets` / `requiredInput` / `preview` variants; the `HolderValueLoss` re-quote as an attacker lever; the `unlock`-during-caller variant of the PoC (my depth manipulation is not tied to a single `unlock`); multi-pool or multi-venue books.

**Reachability labelling.** The production finding is a latent, not-deployed code path per the audit. Every statement I make about "the mitigation" is a statement about a *hypothetical* implementation of the mitigation, since the production source contains no entrant swap on deposit.

# Conclusions

### Overall

**No — actual swaps during deposit and during exit do not eliminate APEX-2026-012.** Three independent results:

1. The auditor's manipulation survives Rule 2 unchanged (E4.3: +30.4e18 to +43.8e18 where production gives +25.5e18 to +30.5e18, closed ledger, exact algebra).
2. Rule 3 introduces a **manipulation-free extraction** that production does not have: a deposit of 100e18 target returns 102.011307814e18 target with no price manipulation, no borrowed capital and no leftover position (E4.2, closed ledger, incumbent loss 2.379517e18, of which the attacker takes 2.011308e18 and the LPs take 0.448523e18 in fees, residual 0.080314e18 disclosed).
3. Rule 3 leaves the exit's realized price exposed: the exit is a real sale, so whoever controls the pool state at exit controls the payout. The extraction in (2) is the visible part of this; the depth-provision variant at exit is quantified in E4.2's footnote set but I did **not** close that ledger (see Limits).

### The invariant production satisfies, and the one Rule 3 breaks

**Production invariant (verified, domain: single pool, no external price, whole-book liquidation accounting).**
For every holder `h`, at every pool state,
`payout_h + claim_h = the vault's realizable liquidation value at that state`,
and the aggregate over all holders equals the realizable liquidation value. Equivalently, the incumbent's loss equals the attacker's gain plus the LP fees plus the change in the vault's own liquidation haircut. The token ledger closes on both tokens in every production row (E4.1); the value-level identity is computed term by term in E4.2, where it closes to the last digit.

**Rule 3 breaks it**, because the mint and the exit use **different price functions over the same inventory**:

- the mint marks the *whole* opposing inventory at `q_exec`, the average execution price of a sale of size `s` (a quantity that did not trade), while
- the exit realises only the holder's *slice*, at the pool's own liquidation price for that slice.

The sentence "a swap prices the quantity that traded; it does not price inventory that did not trade" is therefore exactly the defect: the mitigation prices `A_O` at the price of `s`. The mismatch is an unconditional transfer from the incumbent to the entrant whenever the sign conditions of E4.2 hold; it is not a price move and not a fee.

**Domain of the Rule 3 defect:** any state where the vault holds non-zero idle opposing inventory, the pool has non-zero depth, and the deposit-side swap is large enough (`alpha > alpha*`) relative to the fee (`f < f*`). It does not require the attacker to move the price or to supply liquidity.

### Rule-by-rule, with the four required elements

**Rule 1 — current production (no entrant swap).**

- *Mint equation:* `m = FullMath.mulDiv(S, D, V)` (`Accounting.sol:21`), `V = LiquidationQuote.quote(Common.quoteRequest()).value` (`Money.sol:132-133`) = `(local_target + removed positions' target principal + uncollected target fees) + proceeds(exact-input sale of the whole opposing side into the pool's depth after removing this vault's own liquidity)`.
- *Fee cutoff:* not binding. The exploitable gap is the book's own liquidation haircut `h`, which is **price-impact dominated and nearly fee-independent** (`h` at the named instance: 500.751127e18 at f=3000 ppm; 500.000000e18 at f=0; 507.6e18 at f=30000 ppm). There is no fee below 100% at which `V1 - V0 > D` stops being attacker-chosen.
- *Inventory cutoff:* `D < h`, i.e. the deposit must be smaller than the haircut the attacker's free depth removes. At the named instance `h = 500.751127e18` and `D = 100e18` satisfies it.
- *Execution rule:* no swap on deposit; on exit the only execution is `_swapDeficit` (`Money.sol:219-237`), an exact-input sale of the **entire** opposing balance at a MIN/MAX price limit, used only when the local target sleeve cannot fund the payout.
- *Verdict:* the finding stands, reproduced exactly (E4.1).

**Rule 2 — real swaps added, mint and payout still use the live whole-book quote.**

- *Mint equation:* unchanged from Rule 1, but `V` is now quoted **after** the deposit-side swap, so the swap's own price impact is inside the mark.
- *Fee cutoff:* not binding, as in Rule 1.
- *Inventory cutoff:* as in Rule 1, plus the swap's impact term (the swap raises the mark of the untraded opposing inventory by `A_O*(q_exec - q_spot) ≈ A_O*s/y`).
- *Execution rule:* add an exact-input swap of `s = alpha*D` target at a price limit before the mint; keep the whole-book quote for both mint and payout.
- *Verdict:* **does not eliminate the finding** (E4.3). The swap does not touch the property that makes the quote manipulable — the quote is still a function of live external depth that the attacker can change for free.

**Rule 3 — literal executed-price mint plus actual exit sale.**

- *Mint equation:*
  `m = S*D / (A_T + q_exec*A_O)`, with
  `A_T`, `A_O` = the **full pre-swap inventory** (booked idle + LP positions' principal + uncollected fees; the LP must be included, otherwise the mint omits most of the book and over-issues massively),
  `q_exec = s/w` = target per opposing, the average executed price of the vault's own exact-input sale of `s = alpha*D` target,
  **post-swap naming (identical value):** `m = S*D / ((A_T + D - s) + q_exec*(A_O + w) - D)`.
  *Fee-aware variant:* `m = S*D / (A_T + q_exec*A_O - f*s)` — this **lowers** the denominator and therefore makes the mint more generous to the entrant; it does not repair the mint/exit price mismatch.
- *Fee cutoff:* `f* = 20802.214799 pips (2.080221%)` at the named instance (`alpha = 1`, `D = 100e18`, `A_O/y = 1`); above it the manipulation-free extraction is negative.
- *Inventory cutoff:* the swap fraction `alpha* = 0.579815732950`; the deposit size lies between `D/x = 0.01` and `D/x = 0.02`; the opposing-to-depth ratio `r = A_O/y` has no root in `[0.01, 5]` (the extraction is positive across that band, peaking near `r ≈ 0.5`) but the extraction additionally requires the vault to hold **idle** opposing inventory: with a vault LP share `psi` of 0.25/0.50/0.75 the honest round trip is a loss of 16.494260e18 / 29.317725e18 / 38.727350e18.
- *Execution rule:* deposit side — exact-input sale of `s = alpha*D` target at a MIN/MAX price limit, executed before the mint; exit side — the holder takes `phi = m/(S+m)` of every position and of both idle balances, **only that slice's opposing tokens** are sold (exact input, price limit), and the holder is paid `phi*A_T' +` the actual proceeds, with **no top-up from other holders**.
- *Verdict:* **does not eliminate the finding.** It relocates the exploitable surface from the quote to the execution and adds a manipulation-free extraction (E4.2). The three 49/50/51% entry-swap parameters sit *below* the threshold at which the extraction turns on; the threshold is 0.5798, and the parameters are not safety thresholds.

**Rule 4 — price-free proportional position-vector mint.**

- *Mint equation:* there is no price-free mint of a target-denominated book. It must be either `m = S*D/(A_T + q_exec*A_O)` with `q_exec` from the vault's own trade (Rule 3), or a fraction defined over the target sleeve only, `f = D/(A_T + D)`, granting the entrant `f` of every position and balance and making the share a claim on a **mixed basket**.
- *Fee cutoff:* no swap-side fee applies to a price-free mint; the incumbent's residual loss becomes the fee the vault pays on the exit-side conversion, `≈ 2*f*D` (0.6e18 at f=3000 ppm on D=100e18) instead of the production haircut `h = 500.751127e18`.
- *Inventory cutoff:* the residual loss scales as the exit conversion's price impact, `≈ D^2*(1/x + 1/y)*(1+f)^2`, against the production `h ∝ (A_O/(y+A_O))^2`.
- *Execution rule:* the exit sells only the redeeming holder's slice of the opposing inventory at a price limit and pays the actual proceeds; no top-up; the mint grants a **vector** of per-range and per-balance fractions, not one scalar.
- *Verdict:* **this is the only candidate that removes the manipulable mark**, and it removes it only at the mint; the exit's conversion price remains exposed and the product changes from a target-denominated SE vault to a basket share. *Are liquidity units in disjoint ranges one scalar?* **No** — the entitlement is a vector over at most three disjoint ranges plus two idle balances, because the per-range token composition, fee growth and price response differ.

**Rule 5 — same-pool TWAP as a gate or mint reference.**

- *Mint equation:* `m = S*D / max(V_live, V_ref)` and redeem at `min(V_live, V_ref)`, with `V_ref` from the TWAP. For a TWAP over a pool with ticks, `V_ref` must be built from `UniswapV4TruncatedTwapOracleLib.getQuoteAtTick` applied to the target side and the opposing side of the book.
- *Fee cutoff:* not applicable (no entrant swap in this variant); the binding parameter is the reference's freshness and its truncation bound, not the fee.
- *Inventory cutoff:* not applicable in the same form; the reference must bound the honest value on both sides, which requires the TWAP to be fresh.
- *Execution rule:* no entrant swap; the reference must be observation-backed for the whole window.
- *Verdict:* **as written, this project's TWAP is not a usable gate** (E4.4). `consult(W) == truncate(liveTick, prevTick)` exactly whenever no observation lies inside the window, so a stale oracle returns the live spot and the gate collapses back to Rule 1. Even with the idle backfill removed, one write may move the recorded tick by up to 9116 ticks (2.488187x price), `update` is permissionless, and at most one write lands per block. The invariant a TWAP gate needs is: `V_ref` must upper-bound the honest value at mint and lower-bound it at redeem, with the freshness bound stated; the as-written oracle supplies neither. This is the same weakness the audit already records as APEX-2026-050.

### What would have to change

The evidence says the defect is not the quote's *formula* but the fact that one manipulable, pool-state-dependent scalar prices the entrant's claim at the mint and a different one settles it at the exit, while the incumbent's claim is the residual. Two things must hold together, and neither alone suffices:

1. **Mint and exit must use the same price function over the same inventory**, or the difference between them is a transfer. Rule 3 breaks this; Rule 4 breaks it at the exit.
2. **The price function must not be attacker-chosen for free.** The quote fails this (free depth), and the TWAP fails this (idle backfill, ±9116 per write).

A mint and an exit that both execute against the pool, with the incumbent's residual loss bounded by the fee plus price impact rather than by the book's liquidation haircut, is the shape of a real fix; I have not designed one here and this council is not authorized to.

# Limits

1. **The single-range constant-product reduction.** The production Wings pool has at most three disjoint bounded ranges and the quote walks ticks; my model is one range with CP depth. A bounded-range pool has *less* usable depth near the edges, which changes the magnitude of both `h` and the mitigation's mismatches. Numbers are therefore indicative of mechanism and sign, not of production magnitude. I did not re-run the auditor's reported output, as instructed.
2. **Concentrated-range capture is not modelled.** A narrow-range JIT position captures the price impact as extra target; my full-range depth does not. Any depth-manipulation profit I report is therefore a **lower bound** on the attacker take for that shape, and the attacker's residual opposing balance is disclosed, never counted as profit.
3. **The exit-side depth-provision ledger is not closed.** I computed the increase in a redeemer payout when free depth is present at exit (a haircut reduction on the sold slice, +3.04e18 in the Model A instance and +1.11e18 to +2.05e18 for `psi` 0.75 to 0.25 in Model B), but I did not close the attacker's liquidity funding and unwind ledger for that scenario, so I do **not** claim it as attacker profit. It is stated as a residual exposure of Rule 3, not as a witness. The closed witness in this response is the manipulation-free extraction of E4.2 and the production control of E4.1.
4. **Rule 4 is argued, not simulated.** The argument is exact (a price-free mint of a mixed book is impossible without either a price or a change of product), but no closed ledger is offered for a Rule 4 implementation.
5. **Reachability of the manipulation-free extraction depends on the vault holding idle opposing inventory.** With a vault LP share `psi >= 0.25` the honest Rule 3 round trip is a loss. Whether a live Wings vault holds idle opposing inventory at deposit time depends on the sleeve percentage (`Harvest.liquidFloor`) and on the `_harvest()`/`_place()` cycle, which I did not model. I therefore label E4.2 as a *closed ledger for a reachable parameterisation*, not as a guaranteed production exploit.
6. **Single-venue premise.** Everything assumes the pair has no other venue and that no outside arbitrageur is present, as the brief requires. If an external venue exists, the pool's price is pinned to it, `h` collapses toward zero, and both the production finding and the Rule 3 extraction become small — the premise is load-bearing for both the finding and the mitigation.
7. **Not claimed.** No consensus, no vote, no implementation, no test, no script, no deployment procedure, and no statement about the other members' work. I did not read peer responses.
