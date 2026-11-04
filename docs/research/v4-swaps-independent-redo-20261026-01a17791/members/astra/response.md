# Astra independent first pass: swaps, issuance, and proportional exits

Date: 2026-10-26.

## Conclusion

**Actual swaps are not a sufficient ownership invariant.** A literal executed-price mint, including a corrected post-swap inventory version, can admit a profitable round trip even when the exit withdraws only a proportional slice and actually sells that slice. Section 5 gives an exact, closed, three-position concentrated-liquidity counterexample: the attacker finishes with `360/247` additional target tokens, the same opposing-token balance as initially, no shares, no LP positions, and no debt. It accounts for the incumbent LP's inventory changes. Its swap fees are explicitly zero.

**This is not a production Wings exploit reproduction.** The example uses rational range endpoints, exact real-arithmetic liquidity, no automatic harvest/placement, and zero fees. It does not establish lifecycle reachability, integer execution, or profitability at the production fee configuration. It disproves the general accounting argument that executing the entry and slice-exit swaps is itself sufficient. The positive case for protection is an exact, price-free, proportional **position-vector** mint, with unmatched input refunded and a correct fee cutoff. That theorem concerns ownership allocation; it does not immunize LPs against adverse trading.

| Alternative | Independent conclusion |
|---|---|
| Current whole-book quote mint and quote payout | The temporary-depth entitlement problem is present in the inspected source. Audit APEX-012 reports a production-code PoC; I did not rerun it. [S1-S4] |
| Add real swaps but retain quote-priced entitlements | Not a sufficient fix. Buying assets does not validate the number of shares minted, and real sales do not validate a quote-based reserve top-up. |
| `m = S D / (A_T + p_exec A_O)`, pre-swap book | No general safety theorem. The denominator can be stale, fees can be misallocated, and even when those two errors cancel exactly, scalar valuation can transfer inventory between cohorts. Sections 3 and 5. |
| Post-swap/fee-aware/final-contribution scalar mint | Can preserve a specified linear mark at the mint instant. Does not establish reference-independent ownership conservation or round-trip unprofitability. The counterexample also defeats this correction. |
| Proportional position-vector mint and slice-only exit | Exact ownership allocation invariant, subject to the accounting, execution, and rounding conditions below. Section 4. |
| Correct historical same-pool TWAP | Potential execution/reference constraint, not an ownership invariant. The inspected oracle is not such a historical TWAP across idle gaps. [S7] |

Independence: I read the brief, repository router, production files, the specified audit, and vendored pool arithmetic. I did not read prior council reports, prior research models, handoff conclusions, or peer responses. No shell, project tests/builds, installations, Git, deployments, production edits, or delegation were used. I checked the rational ledger in a resident Python kernel with `fractions.Fraction`; that is arithmetic evidence, not EVM execution.

## 1. What the current code actually does

`Money._deposit` authenticates/pulls input, harvests, quotes incumbent whole-book liquidation value, calls `Accounting.issue(S,V,D)`, books the deposit, mints, and places. Ordinary harvest and placement do not perform a balancing swap. `Accounting.issue` floors `S*D/V`. This is not the proposed executed-price entry. [S1, S2, S5]

`Money._redeem` computes `s*V/S` from the same whole-book quote. Its funding procedure can close entire positions and `_swapDeficit` can sell the entire local opposing balance. An unlocked-manager path instead pays from the local target sleeve. Neither is a proportional position-slice exit. [S1]

`LiquidationQuote` removes all vault-owned positions in its simulation, includes their principal and accrued fees, and sells opposing inventory against the remaining live pool depth. It reads live price, active liquidity, and tick liquidity. Therefore temporary foreign liquidity changes the quote without necessarily changing the vault's owned token/position vector. [S3]

For current quote accounting, let `V0` be pre-deposit liquidation value, and let `V1` be the entire post-deposit book's quoted value at redemption after temporary depth is installed. Ignoring integer rounding:

```text
m = S D / V0
z = m / (S + m) = D / (V0 + D)
payout = z V1
profit = D (V1 - V0 - D) / (V0 + D)
```

This is the entitlement amplification described by APEX-012. The audit's reported in-unlock PoC obtains `70,634,405,953` raw token0 profit; its settled-depth variant is a separate path. Those are reported audit outputs, not independently rerun results. Its settled variant's displayed profit uses a mark, so I do not promote that number into independently closed target profit. [S4]

**What slice-only settlement removes:** an exiter cannot demand `z*V_whole` from an incumbent sleeve merely because foreign depth made a hypothetical whole-book sale look better. It also removes the need to sell staying holders' entire opposing inventory to fund that entitlement, the mechanism identified in APEX-024. [S1, S4]

**What remains:** an overminted `z` can still transfer an excessive fraction of actual positions; the slice's real sale can trade against staying LPs; JIT LPs can earn fees or sell inventory; maintenance can trade at manipulated prices; donations and rounding can still matter. APEX-025, 026, and 040 are not closed by naming the exit a slice. [S4]

## 2. State, principal, and the accounting cutoff

Take target `T = token0`, opposing `O = token1`, and native-unit sqrt price `q = sqrt(O/T)`. Thus a price `p` used in `T + p O` has units **target per opposing**, not the pool's token1/token0 price.

For a position with liquidity `L`, sqrt endpoints `a < b`, and `c = min(max(q,a),b)`, ideal principal is:

```text
T(L,a,b,q) = L (1/c - 1/b)
O(L,a,b,q) = L (c - a)
```

Production uses Q96 prices, round-down removal, round-up addition, and integer fee growth. `Inventory.principal` implements these principal amounts through `SqrtPriceMath`; `earnedFee` uses Q128 growth. [S2, S8]

Separate these objects:

```text
B0 = incumbent book before the entrant's swap
B1 = incumbent book after that swap, before accepting/minting for contribution
C  = the entrant's final accepted contribution, net of refunds and actual costs
S  = incumbent supply
lambda = m/S
```

`B1` must include:

- Every old position at the actual post-swap price, not its old token composition.
- Old local balances and earned fees through the cutoff.
- Fees earned by old vault LPs from the entrant's swap.
- All out-of-range positions and unsold assets; they do not disappear because a liquidation quote assigns them zero sale value.
- Liabilities excluded from spendable backing.

Pending caller assets are not `B0` or `B1`. A swap output received from an old vault LP is a caller asset, but the LP's opposing principal decreases at the same time. Counting the output without that decrease invents backing.

For an entry swap spending actual gross `x` target and receiving `y` opposing, with no other cost/refund:

```text
C_T = D - x
C_O = y
p_gross = x/y
C_T + p_gross C_O = D
```

If `p_net = (x - fee)/y`, then `C_T + p_net C_O = D - fee`. Using the net price with an unchanged numerator `D` overcredits the caller. Conversely, gross price makes the numerator identity true but does not make that price a trustworthy valuation of the entire old opposing inventory.

For multiple swap intervals, let `h_k` be old vault active liquidity divided by total active liquidity in interval `k`. Its swap-induced principal/fee changes are, before rounding:

```text
delta B_T = sum_k h_k (netTargetInput_k + lpFee_k)
delta B_O = -sum_k h_k opposingOutput_k
```

Protocol fees are not vault LP fees. When wings activate or foreign/JIT ranges change the active fraction, `h_k` changes. No single self-fill percentage generally replaces this sum. Production accumulates fee growth per step and realizes position fees at checkpoints. [S3: `_accrue`, `projectSwap`; S8: `Pool.swap`]

## 3. Exact scalar-mint result, and its limitation

For a two-token view of the post-swap book, incumbent ownership immediately after mint is:

```text
incumbent claim = (B1 + C)/(1 + lambda)
incumbent claim - B1 = (C - lambda B1)/(1 + lambda)           (1)
```

Therefore:

```text
exact token-vector conservation <=> C = lambda B1
componentwise no reduction      <=> C >= lambda B1
```

For a selected linear mark `v_p(X) = X_T + p X_O`, the corrected scalar formula is:

```text
N = v_p(C)
V1 = v_p(B1)
m = S N/V1                                                   (2)
```

It gives `v_p(incumbent claim) = v_p(B1)`. This is an exact algebraic result, but only at that chosen `p`.

For the literal pre-book formula `lambda = D/v_p(B0)`, the scalar transfer is:

```text
v_p(incumbent claim - B1)
  = [v_p(C) - D*v_p(B1)/v_p(B0)] / (1 + D/v_p(B0))             (3)
```

This shows both its required conditions and its failure modes. A post-swap book and final-contribution numerator fix equation (3)'s timing/fee errors. They do **not** force the vector residual in equation (1) to vanish.

For any other price `p_ref`, when equation (2) holds:

```text
v_pref(incumbent claim - B1)
  = (p_ref - p) (C_O - lambda B1_O)/(1 + lambda)                (4)
```

No independent price source is assumed here. `p_ref` may be a correctly sampled historical same-pool reference; equation (4) also simply describes different realizable future compositions/prices. The counterexample below requires no reference mark to calculate profit.

**Important favorable special case:** if old vault LPs supply a constant fraction `h` of the entire entry swap, protocol fees are zero, and gross price is used, then:

```text
delta B = (h*x, -h*y)
v_p(delta B) = h*x - (x/y)*h*y = 0
```

Thus pre-swap and post-swap scalar denominators can be exactly equal even with self-fill. It would be wrong to dismiss every pre-book formula solely as stale. The counterexample deliberately satisfies this favorable cancellation and still profits.

**Historical-reference scalar variant:** `m = floor(S*v_pref(C)/v_pref(B1))` can preserve a fixed historical mark at issuance. Separately, protecting old holders through the entry trade requires a bound on `v_pref(B1)-v_pref(B0)`. The issuance identity alone does not bound losses already incurred while trading old LP positions. Comparing against a new spot produced by the operation can conceal that loss.

## 4. The price-free position-vector theorem

Use a vector of actual owned claims, not just aggregate token totals:

```text
Z = (local T, local O, L_core, L_upper, L_lower,
     separately accounted fee claims and other attributable claims)
```

Each position coordinate retains its exact range and identity. Collecting fees into local balances first is a clean way to avoid creating fictitious transferable fee-growth coordinates.

After all caller preparation swaps and incumbent fee recognition, accept only an actual addition `DeltaZ` satisfying:

```text
DeltaZ = lambda Z
m = lambda S
Z_after = (1 + lambda) Z
S/(S+m) * Z_after = Z                                         (5)
```

This preserves every incumbent claim coordinate at the issuance cutoff, independent of spot, TWAP, foreign liquidity depth, or a scalar quote.

In exact arithmetic with available additions `U`, the maximum proportional addition is:

```text
lambda = min_{i: Z_i > 0} U_i/Z_i
accepted addition = lambda Z
refund = U - lambda Z
```

`U_i` must be an actually constructible claim addition. For Wings this means funding proportional liquidity additions to **each existing range**, plus matching local balances. Merely taking `min(C_T/B_T, C_O/B_O)` and leaving the matched tokens local preserves only the current token vector, not future LP exposure. Zero coordinates, uncollected fees, position capacity, and required liquidity budgets need explicit treatment.

In integer implementation, choose integer `m`, fund each required coordinate at conservative ceil costs, floor released entitlements, and verify the cross-multiplied inequalities:

```text
S * DeltaZ_i >= m * Z_i
```

These inequalities protect incumbents; depositor rounding protection is a separate requirement. Placement loss must not be silently charged to incumbent reserves if the advertised invariant is exact conservation. Refunds cannot include old fees.

### Slice exit

For `z = s/S`, detach only:

```text
z * local balances
z * each position's liquidity
z * fees earned before the exit cutoff
```

Remaining ownership at that cutoff is `(1-z)Z`. Burn the exiting shares and keep the detached inventory in a separate operation ledger. Sell only its opposing inventory. Payout is detached target plus **actual** target sale proceeds, less explicitly attributed exit costs. Do not top up from the incumbent sleeve to meet a whole-book quote.

`modifyLiquidity` can return all checkpointed position fees even on a partial liquidity removal; `PoolManager` includes those fees in `callerDelta`. The exit must allocate only its proportional old-fee claim and retain the rest. Adding `feesAccrued` again would double count. [S6, S8]

The still-invested incumbent positions can participate in the exit swap. Their fee earnings and changed principal remain incumbent assets. This is actual AMM trading, not an entitlement to debit additional incumbent cash.

For a target-only interface, an incomplete opposing sale must cause a revert or use a separately approved residual/queue policy. Paying an assumed sale price is not allowed. At the final exit, all own liquidity is gone; if no external liquidity can buy the opposing inventory, swaps cannot manufacture target liquidity. Proportional ownership does not prove universal target-only exit availability.

Equation (5) proves allocation, not universally nonnegative holder wealth. Manipulation before the cutoff, ordinary adverse selection against an LP, a sandwich of a vault-funded maintenance swap, and fees paid to an attacker-controlled LP remain separate concerns.

## 5. Exact closed counterexample and matched control

### 5.1 Domain and starting state

This is a three-position concentrated-liquidity **arithmetic model**, not a deployed Wings fixture. It uses the principal formula in section 2, exact rational arithmetic, zero swap/protocol fees, and no automatic portfolio reshaping. All swaps use the same pool.

Take `q=1`. The vault has `S=100` shares held by incumbents and:

| Owner/position | Sqrt range | Liquidity | Target | Opposing |
|---|---:|---:|---:|---:|
| Vault core | `[1/10, 10]` | `50` | `45` | `45` |
| Vault upper | `[4, 10]` | `400/3` | `20` | `0` |
| Vault lower | `[1/10, 1/2]` | `250` | `0` | `100` |
| External core LP | `[1/10, 10]` | `50` | `45` | `45` |

Vault totals are `(65 T,145 O)`. The attacker starts with `(100 T,100 O)`, no shares, no LP, and no debt. This is funded capital, not a hypothetical lender. Total system tokens are `(210 T,290 O)`.

The active core liquidity is `100`. For a fee-free swap within these active ranges:

```text
O in: q' = q + O_in/L;  T_out = L(1/q - 1/q')
T in: 1/q' = 1/q + T_in/L; O_out = L(q - q')
```

Both wings remain out of range throughout this particular path. The vault core is active and owns half the active liquidity during the front trade and entry swap.

### 5.2 Manipulation and literal executed-price mint

1. Attacker swaps `100 O` into the pool: `q: 1 -> 2`, receiving `50 T`. Its wallet is now `(150 T,0 O)`. Incumbent core becomes `(20 T,95 O)`, so the pre-entry vault book is `B0=(40 T,195 O)`.
2. Attacker deposits `D=100 T`. The proposed entry swaps exactly 50%: `x=50 T`, receiving `y=100 O`, restoring `q: 2 -> 1`. Caller contribution is `C=(50 T,100 O)`, and attacker wallet outside the vault is `(50 T,0 O)`.
3. Gross executed price is `p=1/2 T/O`. Literal valuation is:

```text
V = 40 + (1/2)*195 = 275/2
m/S = 100/(275/2) = 8/11
m = 800/11
z = m/(100+m) = 8/19
```

The old vault book after the entry swap is exactly `B1=(65 T,145 O)`. Therefore:

```text
v_p(B1) = 65 + (1/2)*145 = 275/2 = v_p(B0)
v_p(C) = 50 + (1/2)*100 = 100
```

**The corrected post-swap/final-contribution scalar mint produces exactly the same shares.** There is no neglected old LP composition change and no missing fee in this example.

The combined vault before exit holds `(115 T,245 O)`: its original three positions at `q=1`, plus caller local assets. Nevertheless, contribution ratios differ:

```text
C_T/B1_T = 10/13
C_O/B1_O = 20/29
m/S      = 8/11
```

The scalar mint permits an inventory exchange between cohorts, rather than proportional ownership funding.

### 5.3 Actual proportional exit, actual sale, and same-pool buyback

Burn all attacker shares and withdraw exactly `z=8/19` of every position and local balance:

```text
detached T = 920/19
detached O = 1960/19
remaining active liquidity = 100 - 50*(8/19) = 1500/19
```

The vault actually sells **all** `1960/19 O` for target, as a target-only slice exit requires:

```text
q_exit = 1 + (1960/19)/(1500/19) = 173/75
target sale output = (1500/19)*(1 - 75/173)
```

The attacker then buys exactly `100 O` back through that same pool, restoring its original opposing-token capital:

```text
q_final = 173/75 - 100/(1500/19) = 26/25
target spent buying O = (1500/19)*(25/26 - 75/173)
```

The sale and buyback target flows telescope:

```text
net target from those two swaps
  = (1500/19)*(1 - 25/26)
  = 750/247

attacker final T = 50 + 920/19 + 750/247 = 100 + 360/247
attacker final O = 100
```

This is `360/247`, approximately `1.45749`, **realized target profit with opposing capital restored**, not a marked residual and not a sale at an independent price. All swaps stay between the wing boundaries `1/2` and `4`.

### 5.4 Closing every ownership and token ledger

| Entity | Initial target | Final target | Initial opposing | Final opposing |
|---|---:|---:|---:|---:|
| Attacker | `100` | `100 + 360/247` | `100` | `100` |
| Incumbent vault | `65` | `16170/247` | `145` | `143` |
| External LP | `45` | `560/13` | `45` | `47` |
| Total | `210` | `210` | `290` | `290` |

Final incumbent vault composition:

```text
core L = 550/19, same range
upper L = 4400/57, same range
lower L = 2750/19, same range
local T = 550/19
local O = 1100/19
q = 26/25
```

The external LP still has `L=50`, same range. Final attacker shares, LP, and debt are all zero. All fee ledgers are zero by construction. The incumbent token vector changes by `(+115/247 T,-2 O)`; the external LP changes by `(-25/13 T,+2 O)`. Their total target reduction is exactly the attacker's target gain.

I do not assign all attacker profit to the vault: the external LP also participates. The explicit incumbent vector is the ownership evidence; there is no external-price liquidation of that vector.

### 5.5 Fixed 49%, 50%, and 51% swaps

Keep the same starting positions, front trade, and `D=100`; let the entry fraction be `alpha` and `u=1/2+alpha`. The exact family is:

```text
q_entry = 1/u
x = 100*alpha
y = 100*(2 - q_entry)
p = u/2
z = 40/(56 + 39u)
T_book = 165 - 50u
O_book = 295 - 50/u
L_remaining = 100 - 50z
q_exit = q_entry + z*O_book/L_remaining
q_final = q_exit - 100/L_remaining

profit_T = 50 + z*T_book
           + L_remaining*(1/q_entry - 1/q_final) - 100
```

Resident exact-rational evaluation:

| Entry swap fraction | Closed target profit |
|---|---:|
| `49/100` | `14719031429/7357450721` |
| `1/2` | `360/247` |
| `51/100` | `18861631/20785481` |

All three are positive. Changing the fixed percentage slightly is not an ownership proof.

Size and depth matter through the swap equations and `z`. Scaling every token amount, position liquidity, and supply by the same factor scales this ideal profit by that factor; changing deposit size without changing depth changes the result. No fee/depth-independent safe percentage follows.

For a separate favorable control, an unbounded fee-free constant-product book with virtual reserves `(X,Y)`, of which the vault owns fraction `rho`, accepts target deposit `D` and swaps `x`. Exact post-swap proportional funding requires:

```text
(D-x)/(rho*(X+x)) = [Y*x/(X+x)]/[rho*X*Y/(X+x)]
D = 2x + x^2/X
x = sqrt(X^2 + X*D) - X
```

The required fraction tends to 50% only for small `D/X`. This is a single-interval control, not Wings sizing logic; sleeves, finite bounds, both wings, fees, and tick crossings change the equation.

### 5.6 Proportional position-mint control

Repeat the front trade and entry swap, then accept only a proportional addition to the old post-swap positions:

```text
lambda = min(50/65,100/145) = 20/29
accepted target = 65*lambda = 1300/29
accepted opposing = 145*lambda = 100
target refund = 50 - 1300/29 = 150/29
m = (20/29)*100
```

Actually add `lambda` times each old position's liquidity, rather than leaving the matched assets as a differently invested book. The addition costs exactly those accepted tokens. On immediate proportional exit, remove those additions; the original LP vector is restored. The detached basket is `(1300/29 T,100 O)`.

The target-only exit sells its `100 O` through the original `L=100` pool, receiving `50 T`, moving `q` to `2`. The attacker buys `100 O` back for `50 T`, returning `q` to `1`.

```text
final attacker T = outside wallet 50 + refund 150/29
                   + detached target 1300/29 + sale 50 - buyback 50
                 = 100
final attacker O = 100
profit = 0
```

Incumbent and external LP positions, inventories, and price return to the initial state. This is a control for the mechanism in this witness, not a universal absence-of-MEV theorem.

### 5.7 Reproduction code

This is the complete resident-kernel arithmetic used for the three swap fractions. It imports only Python's standard library and does not read repository state:

```python
from fractions import Fraction as F

def ledger(alpha):
    q_entry = 1 / (F(1, 2) + alpha)
    x = 100 * alpha
    y = 100 * (2 - q_entry)
    p = x / y
    z = 100 / (F(40) + 195 * p + 100)
    exit_t = z * (50 / q_entry + 15 + 100 - x)
    exit_o = z * (50 * q_entry + 95 + y)
    remaining_l = 100 - 50 * z
    q_exit = q_entry + exit_o / remaining_l
    q_final = q_exit - 100 / remaining_l
    exit_sale_t = remaining_l * (1 / q_entry - 1 / q_exit)
    buyback_t = remaining_l * (1 / q_final - 1 / q_exit)
    final_t = 50 + exit_t + exit_sale_t - buyback_t
    return {
        "alpha": alpha, "q_entry": q_entry, "p": p,
        "fraction": z, "q_exit": q_exit, "q_final": q_final,
        "exit_t": exit_t, "exit_o": exit_o,
        "profit": final_t - 100,
    }

for fraction in [F(49, 100), F(1, 2), F(51, 100)]:
    print(ledger(fraction))

incumbent_t = (
    F(550, 19) * (F(25, 26) - F(1, 10))
    + F(220, 19) + F(550, 19)
)
incumbent_o = (
    F(550, 19) * (F(26, 25) - F(1, 10))
    + F(1100, 19) + F(1100, 19)
)
external_t = 50 * (F(25, 26) - F(1, 10))
external_o = 50 * (F(26, 25) - F(1, 10))
print(incumbent_t, incumbent_o, external_t, external_o)
print(100 + F(360, 247) + incumbent_t + external_t)
print(100 + incumbent_o + external_o)
```

The final three outputs are `16170/247 143 560/13 47`, `210`, and `290`.

## 6. Wings activation, JIT depth, and positive fees

The real geometry is a full usable-range core plus an upper wing extending to the maximum tick and a lower wing extending to the minimum tick. New wing inner boundaries are immediately outside current price; existing unconverted wings retain their old ranges. On conversion, ordinary harvest can close and replace a wing. These rules are materially different from an arbitrary fixed-range arithmetic fixture. [S5]

A token0-in leg moves `q` downward and can activate/cross the lower wing. The reverse leg can activate/cross the upper wing. The source's stored tick, not an inferred inverse sqrt-price tick, controls activity at directional boundaries. A production witness must sum principal changes and fee growth across every active interval; the counterexample above does not exercise these crossings. [S3, S5, S8]

The position-vector proof is unchanged by any number of activation intervals **provided its cutoff book is the actual resulting book**. A proof using a constant old-LP share `h`, or the unbounded CP sizing formula, is not unchanged.

JIT liquidity has two distinct roles:

1. Under current whole-book quote entitlement, it can raise an accounting payout without being consumed by an equivalent real trade. This is the APEX-012 defect. [S4]
2. Under real slice sales, a JIT LP is an actual counterparty. Its capital, returned principal, earned fees, and changed token composition must be included in a closed ledger. It may still manipulate execution price or earn a trading profit, but gross output is not free value and gross LP withdrawal is not profit.

My witness uses no attacker LP and needs no JIT borrowing. It therefore neither proves nor disproves additional attacker-LP variants.

For positive swap fees, use actual gross inputs, net curve inputs, output rounding, and LP/protocol fee destinations separately. Before mint, old vault LP fees belong to `B1`; after burning a slice, fees on its conversion belong to the remaining LPs. The example's positive zero-fee margin implies persistence for some sufficiently small fees in the continuous model, but it does **not** quantify a bound or prove profitability at 3000 pips. I have not run a fee-aware production or integer model.

## 7. Same-pool TWAP: useful distinction, broken current implementation

A genuine historical cumulative tick is:

```text
C(t) = integral_0^t tick(u) du
meanTick = [C(t)-C(t-W)]/W
p_ref(T/O) = 1.0001^(-meanTick), with explicit native-unit conventions
```

A timestamp-instant push/restore cannot rewrite an already accumulated interval. A manipulation maintained for a fraction `d/W` of the window can affect the mean; a same-pool TWAP is not an independent truth oracle.

The inspected implementation instead does:

```text
recordedTick = truncate(currentLiveTick, previousRecordedTick)
C_new = C_last + recordedTick * (now - lastTimestamp)
```

Its read-side `transform` also extrapolates with a supplied live/truncated tick. `UniswapV4MultiPoolTwapOracleTarget.update` reads live `slot0` permissionlessly, and `writeAge` measures time since that write. Consequently a new poke can assign the just-observed manipulated tick to an earlier idle interval and make write age fresh. This directly matches APEX-050. [S7, S4]

Using the previous recorded tick for the elapsed interval removes that particular retroactive-current-tick bug. However, a permissionlessly sampled, hookless pool oracle cannot reconstruct every unobserved historical swap from two endpoint observations. A sample-and-hold estimator is not automatically the exact tick integral. A corrected design must specify observation production, covered history, warm-up, sampling error, stale failure, and how it prevents the newly recorded manipulated anchor from dominating a later idle gap.

A historical reference can bound entry/exit/maintenance execution and can define equation (2)'s mark. It does not measure persistent depth, ensure a complete target-only exit, or replace equation (5). The reference must be frozen independently of the current operation's manipulable observation; spot deviation and maximum trade impact require explicit units and thresholds, not merely a `writeAge == 0` check.

## 8. Strongest counterargument and response

**Counterargument:** in a single venue, swapping against the real curve establishes a legitimate exchange price. With correctly checkpointed self-fill and fees, a scalar mint can be equivalent to buying proportional LP exposure. Real slice settlement prevents payment from fictional depth. A price-free vector requirement may be unnecessarily restrictive, expensive, and inconsistent with target-only UX.

**Response:** that argument is valid when the complete route enforces `DeltaZ=lambda Z`, or in a special state where the scalar formula and actual placement are proved equivalent to it. Equation (5) and the matched control demonstrate that case. Target-only input can remain the user interface if a router performs swaps, funds the proportional claim vector, and refunds unmatched input.

It is not valid merely because one finite swap produced `p_exec`. The closed counterexample has actual self-fill, exact fees, an actual target-only slice sale, full same-pool restoration of opposing capital, and identical pre/post scalar values. Its failure is the unmatched ownership vector, not a missing swap or a hypothetical external liquidation.

The important limitation cuts both ways: this model is enough to reject an unconditional mathematical claim; it is not enough to declare a particular future Wings implementation exploitable. If its placement step enforces proportional positions, if a reference guard rejects the front trade, or if fees/limits make the route unprofitable, this exact witness may not execute.

## 9. Recommendations and what remains unproved

For an exact ownership claim, prefer the proportional position-vector invariant and operation-local slice settlement. If a scalar design is chosen instead, name the weaker claim precisely: conservation at a particular mark, with separately bounded execution loss and a separately justified reference. Do not describe it as price-free ownership conservation.

These are **proposed requirement changes**, not implementation authorization:

- Replace quote-priced issuance and whole-book entitlement funding if adopting vector entry/slice exit.
- Allow explicit matching/refunds and decide whether swap/placement costs are caller-funded; exact conservation conflicts with silently socializing those costs under PRD O4.
- Specify target-only partial-fill failure and the terminal/no-external-liquidity case.
- Change preview/exact-output semantics to mirror the final route and integer funding.
- Preserve the requested `getRate` meaning: normalized actual one-whole-share withdrawal-and-sale preview, separate from issuance. The inspected `EconomicTarget.getRate` currently computes whole-book `V*1e18/S`, and the older PRD explicitly selects that meaning. That is a documented mismatch with the current brief, not permission to redefine the requested rate. [S6, S9]

Unproved or unexecuted:

1. No exact-integer production Wings counterexample for the proposed executed-price entry/slice-exit redesign exists in this pass; that redesign is not the inspected implementation.
2. No claim that the rational ranges and supplied three-position state arise through the actual Wings lifecycle. Its usable tick extremes, nearest wing boundaries, harvest, placement, sleeve floor, and fee configuration must be reproduced.
3. No production two-wing-crossing or attacker/JIT-LP closed ledger for the redesign.
4. No 3000-pip profitability threshold, flash-finance availability assertion, gas proof, tick-work bound, Q96/Q128 rounding proof, or complete state-space search.
5. No availability proof for proportional vector funding when a required position is at capacity, cannot be funded with the caller budget, or includes economically owned but currently unsellable inventory.
6. No TWAP parameter calibration or proof against sustained same-pool manipulation. Fixing retrospective attribution is necessary, not sufficient.
7. No general claim that vector issuance eliminates adverse selection, permissionless-rebalance sandwiches, donation/low-supply rounding, or fees earned by malicious LPs.

The decisive verified results are narrower: equation (5) gives a precise allocation invariant; equations (1)-(4) delimit scalar guarantees; the fully closed rational witness shows that real entry and slice-exit swaps, even with the corrected scalar cutoff, do not by themselves imply round-trip safety.

## Sources

Paths are relative to the repository root. `W/` expands to
`contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`.
`P` expands to `UniswapV4UpperLowerWingsStandardExchangeVault`.

- **[S1]** `W/PMoney.sol` (expand `P` as above): `begin`, `_harvest`, `_place`, `_deposit`, `_redeem`, `_fund`, `_swapDeficit`, `preview`; especially lines 41-48, 94-105, 120-181, 190-233.
- **[S2]** `W/PAccounting.sol`: `issue`, `entitlement`, `liquidTarget`; `W/PInventory.sol`: `principal`, `earnedFee`, `harvestEligible`. The shortened filenames mean the prefix substitution, not literal on-disk filenames.
- **[S3]** `W/PLiquidationQuote.sol`: `quote`, `_prepare`, `_removeOwned`, `_sell`, `_accrue`, `projectSwap`; especially lines 119-153, 253-334.
- **[S4]** `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`: APEX-012 lines 266-326; APEX-025 starting 1109; APEX-026 starting 1173; APEX-024 starting 1605; APEX-040 starting 2141; APEX-050 starting 2763. Reported PoCs were not executed.
- **[S5]** `W/PGeometry.sol`: `ranges`; `W/PHarvest.sol`: `snapshot`, `totalInventory`, `harvest`, `place`, `_add`. Full prefix substitution as defined above.
- **[S6]** `W/PExecutionDelegate.sol`: `unlockCallback`, `_modify`, `_settle`; `W/PEconomicTarget.sol`: `getRate`, `quoteRate`, `positionInventory`.
- **[S7]** `contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol`: `update`, `observe`, `consult`, `writeAge`; `contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol`: `write`, `observe`, `observeSingle`, `transform`, `consult`.
- **[S8]** `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol`: `modifyLiquidity`, `swap`, `_swap`, settlement functions; `libraries/Pool.sol` under that same directory: `modifyLiquidity`, `swap`, `getFeeGrowthInside`; `libraries/SwapMath.sol`: `computeSwapStep`. Primary dependency code governs principal/fee accounting here. Official Uniswap documentation also describes net flash-accounting settlement: `https://developers.uniswap.org/docs/protocols/v4/concepts/flash-accounting`.
- **[S9]** `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md`: controlling O1-O7/A1-A5 addenda; sections 4-8, 10-11; especially C5, V4-V6, SEC-08/13/14. Read as product requirements, not prior council conclusions. `CLAUDE.md` was read as the repository router.
