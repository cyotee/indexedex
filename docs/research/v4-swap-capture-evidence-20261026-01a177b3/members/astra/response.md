# Identity

- Council run: `v4-swap-capture-evidence-20261026-01a177b3`.
- Assigned member: Astra, independent accounting research.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Native actual model, reasoning setting, and identity: not exposed.
- Date: October 26, 2026.
- Peers read before submission: no.
- Prior council reports, handoff conclusions, and other `docs/research/v4-*` artifacts read: no. The assignment's `brief.md` is the sole exception.
- Method: production-source reading, exact algebra, and standalone Python `Fraction` arithmetic in the resident kernel. No project tests, builds, installs, Git operations, deployments, transaction scripts, subagents, or production edits.

# Question and targets

**Actual entry and exit swaps do not, by themselves, eliminate APEX-2026-012.** There is a closed, zero-fee example in which a 100-target entrant swaps 50 target, receives shares under the literal executed-average-price equation, immediately exits only its proportional inventory, sells only its own opposing tokens, and finishes with **105 target, zero opposing tokens, zero shares, zero LP positions, and zero debt**. The incumbent can then close for 95 target instead of its initial 100. The underlying pool ends exactly where it started. No independent price, outside arbitrageur, price restoration trade by an outside actor, or marked leftover position is needed.

This is an exact continuous pool-math counterexample to an accounting rule, **not a claim that I reproduced the complete production Wings lifecycle**. I separately give a closed active-vault-LP example, live-quote/JIT examples, fee-bearing calculations, and the precise invariant that a proportional position-vector mint does satisfy.

The five rules examined are:

1. Current production issuance and payout from the whole-book liquidation quote.
2. Real entry/exit swaps with a live whole-book quote retained in issuance or payout.
3. Executed-average-price issuance, separately identifying pre-swap inventory, post-swap incumbent inventory, gross-input credit, and fee-aware retained credit.
4. Price-free proportional copying of every position and both idle balances.
5. The implemented same-pool TWAP, and separately an ideal historical same-pool TWAP, used as a gate or as an issuance reference.

`getRate` is not an issuance equation in this response. The existing implementation and the requested one-whole-share withdrawal-and-sale preview are distinct objects.

# Evidence

**E1. Production-source anchors.**

The following abbreviations refer to the full prefix
`contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVault`.

| Source | Observed behavior |
| --- | --- |
| `Money.sol:94-105,120-140` | Pull caller funds, isolate them from booked inventory, harvest, quote the incumbent book, issue shares, then book the target and place inventory. `_harvest` and `_place` return when PoolManager is already unlocked. There is no entrant swap in `_deposit`. |
| `Accounting.sol:18-27` | Nonzero-supply issuance is `floor(S * credit / value)`; payout is `floor(shares * value / S)`. Bootstrap issuance is one share per native target unit. |
| `Money.sol:147-181,190-233` | Redemption first determines a target entitlement from the whole-book quote. Funding can close whole positions and sell the whole local opposing balance, rather than removing only the redeemer's fraction. The remaining-holder comparison reuses the live quote. |
| `LiquidationQuote.sol:108-153,253-334` | Read live slot0, active liquidity, and tick data; remove this vault's positions; include removable principal and earned fees; simulate selling opposing inventory into the remaining liquidity. Pending caller assets are excluded. Unsold opposing inventory is not assigned a spot value. |
| `Inventory.sol:18-49` | Principal is a function of current square-root price, range, and liquidity. Removals round down; additions round up. Earned fees use liquidity times fee-growth difference. |
| `Geometry.sol:16-40` | Production placement uses a full-range core and separately defined upper and lower wings. |
| `Harvest.sol:118-167` | Harvest closes converted wings and places inventory; ordinary harvest does not swap. Placement tries core, upper wing, and lower wing, while preserving a target sleeve. |
| `ExecutionDelegate.sol:22-77` | Actual PoolManager deltas are settled. Swaps are exact-input operations. LP modifications also settle accrued fees. |
| `EconomicTarget.sol:27-31` | `getRate = floor(wholeBookLiquidationValue * 1e18 / S)`, or `1e18` at zero supply. This is not a normalized one-share slice-sale preview. |

The named audit source is
`docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`:
APEX-2026-012 starts at line 268; contextual findings 025, 026, 024, 040, and 050 start at lines 1109, 1173, 1605, 2141, and 2763. I read those findings. Their reported PoC output was not rerun and is not my evidence of a closed profit.

The contextual findings distinguish whole-inventory execution, same-state valuation, quote work exhaustion, bootstrap rounding, and oracle history from the issuance question. In particular, this research does not use a marked token remainder in the audit as if it were realized target profit.

**E2. Pool math and notation.**

`T` is the target, chosen as token1; `O` is token0. Write `s = sqrt(T/O)`. In one active interval with liquidity `L`, define virtual reserves

```text
x = L*s        (target)
y = L/s        (opposing)
x*y = L^2.
```

For symmetric square-root bounds `[c, 1/c]`, the actual position inventory is

```text
T = L*(s-c),    O = L*(1/s-c).
```

Virtual reserves are not custody balances. Every ledger below either subtracts the constant range offset explicitly or defines a custody normalization that includes a real, fixed LP wallet.

For gross exact-input `q` target, with fee fraction `h` and `g=1-h`, with no crossed liquidity boundary:

```text
x1 = x + g*q
y1 = x*y/x1
u  = y-y1                  opposing received
fee_T = h*q.
```

Selling gross `v` opposing from that state gives:

```text
z  = x1*g*v/(y1+g*v)        target received
x2 = x1-z
y2 = y1+g*v
fee_O = h*v.
```

Fees are separate LP claims, not automatically compounded into virtual reserves. Protocol fee is zero in the numerical examples.

These equations are the continuous counterparts of the inspected vendored
`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol:60-126`
and `SqrtPriceMath.sol:186-259`. The implementation deducts the input fee before moving price, rounds input requirements upward, and rounds outputs downward. `Inventory.principal` uses the same amount-delta math. The local vendored code, not a generic V2 fee-compounding formula, is the computational basis here. A generalized public-documentation search returned no usable evidence; no external search result is relied upon.

**E3. Complete specification of the accounting rules.**

Let `B` denote incumbent inventory at the specified cutoff, `S` incumbent supply, `D` gross target tendered by the entrant, `q=rD` the actual gross target swap, and `u` actual opposing output. The entrant retains
`C=(D-q,u)` before placement. `A_T,A_O` are incumbent removable principal plus idle balances plus owned fees, excluding `C`. `Q(B,pool)` is whole-book liquidation value. All equations below omit integer rounding unless explicitly shown.

| Rule | Mint equation and inventory cutoff | Fee cutoff | Execution rule |
| --- | --- | --- | --- |
| Production | `m=floor(S*D/Q(B,pool))`; `B` is post-harvest, pre-credit/pre-placement. `m=D` at bootstrap. | All incumbent fees counted by the quote belong to the old supply before issuance. There is no entry-swap fee. | No entrant swap. Redemption pays `floor(burnedShares*Q/S)`; funding may close whole positions and sell whole opposing inventory. |
| Swaps, live quote retained | Either `m=S*D/Q(B_before, pool_before)` or `m=S*D/Q(B_after, pool_after)`, where `B_after` excludes the retained entrant assets. These are different rules. | Existing fees, including fees earned by old LP positions during the entry swap in the post cutoff, belong to incumbents. Gross credit still counts `D`; any net-credit replacement must be stated separately. | Entry spends exactly `q`. Exit either pays the live quote entitlement, or pays actual proceeds from a proportional slice. E5 calculates both, including a quote-payout case with a real exit swap. |
| Literal gross executed-price mint | `p_exec=q/u`; `m=S*D/(A_T+p_exec*A_O)`. Specify either the pre-swap or post-swap incumbent `A`. | `q` includes paid fees. Thus `(D-q)+p_exec*u=D` even when some fees went to external LPs. That identity is a definition, not proof of economic equivalence. | Swap `q`; combine `C` with old inventory; on exit remove the holder's fraction of every position and both idle balances, sell only that slice's opposing tokens, pay only its actual target. |
| Fee-aware retained-price mint | Use the **post-swap incumbent book**, including old LP fees. Let `p_net=(q-fee_T)/u`; `C_value=(D-q)+p_net*u=D-fee_T`; `m=S*C_value/(A_T+p_net*A_O)`. | Fee_T is excluded from entrant retained credit. Old LPs' share of it is included in incumbent inventory, not ignored or credited twice. Protocol/external LP fees are not vault backing. | Same slice-only actual exit. A post-swap variant using gross `p_exec` and retained inventory instead has `C_value=D` and reduces to the preceding rule. |
| Position-vector mint | After all entrant conversion and old-fee settlement, accept exactly `C=lambda*B` componentwise and mint `m=lambda*S`. Refund unmatched assets. | All fees accrued before this acceptance cutoff are part of `B`; fees earned while only old shares exist cannot be gifted to the entrant. Existing position fee checkpoints must be settled or separately attributed before adding liquidity. | Acquire and add the same fraction of each individual position and both idle balances without an intervening swap between cutoff and acceptance. Exit first carves out the holder's fraction, then executes only that separated slice. E7 gives the exact invariant and limits. |
| TWAP, gross-credit version | `m=S*D/(A_T+p_bar*A_O)`, with a specified pre/post inventory cutoff; alternatively keep another mint equation and use TWAP only as a gate. | Old fees included at the chosen cutoff; entry fees are still charged to entrant execution, but `D` overstates retained credit if evaluated at a different price. | Specify whether the gate checks before entry only, both endpoints, or the entire permitted execution path. Exit is slice-only in the analysis below. |
| TWAP, retained-credit version | Post-swap `m=S*((D-q)+p_bar*u)/(A_T+p_bar*A_O)`. | Include old LP entry-swap fees in `A`; use actual retained `C`, not gross `D`. | Atomic acceptance at one fixed reference after conversion; slice-only exit. This proves conservation of a fixed-reference **scalar**, not conservation of each position or of executable target proceeds. |

No row silently changes `getRate`. The preview of a normalized one-whole-share removal and sale should describe that slice's executable result; it is not either `Q/S` or a mint oracle merely because all three use target units.

**E4. Closed executed-price witness, with fee and sizing controls.**

Choose a hookless pool, tick spacing 1, one external position with range `[-20000,20000]`, and `L=100`. In the continuous tick-price model let
`c=(10001/10000)^(-10000)`. Initially `s=1`, so virtual reserves are `(100,100)` and actual pool principal is `(100-100c,100-100c)`.

The incumbent vault has **no LP position**, idle `(100 T,0 O)`, and supply `S=100`. The attacker starts with `(100 T,0 O)`, no shares, no LP positions, and no debt. There are no fees initially, no harvest, no placement, and no other actors' trades.

Deposit `D=100`; execute `q=50` target through this pool. The execution output is `u=100/3 O`, and `p_exec=3/2 T/O`. Both pre-swap and post-swap incumbent inventory are `(100,0)`. Thus:

```text
m = 100*100/(100 + (3/2)*0) = 100
f = m/(S+m) = 1/2.
```

The retained-price formula gives the same answer at zero fee:
`C_value=50+(3/2)*(100/3)=100`.

All token inventory in this table is custody, not a price mark:

| Event | Attacker wallet T,O | Vault T,O | External pool principal T,O | Attacker shares |
| --- | --- | --- | --- | --- |
| Initial | `100,0` | `100,0` | `100-100c,100-100c` | `0` |
| Entry swap and deposit accepted | `0,0` | `150,100/3` | `150-100c,200/3-100c` | `100` |
| Burn all attacker shares and separate its slice | `75,50/3` | `75,50/3` | `150-100c,200/3-100c` | `0` |
| Sell exactly attacker slice O | `105,0` | `75,50/3` | `120-100c,250/3-100c` | `0` |
| Optional incumbent final exit | `105,0` | `0,0` | `100-100c,100-100c` | `0` |

In the last row the incumbent wallet receives `95 T,0 O`: its 75 target plus 20 target from selling its remaining `50/3 O`. Supply falls from 100 to zero on that final exit. The external LP's liquidity remains 100 throughout and its final inventory equals its initial inventory. Attacker LP inventory and debt remain zero at every step.

Every row conserves total target `300-100c` and opposing `100-100c`, including the separated incumbent wallet in the last row. The attacker closes with **+5 target**. The incumbent closes with **-5 target**. No token is priced at an assumed external value.

The mechanism has an exact general expression. For an incumbent idle target balance `a`, no incumbent opposing balance, external virtual target reserve `x`, and `f=D/(a+D)`, the gross executed-price rule with an immediate actual slice exit gives:

```text
Payout - D = f*(1-f)*q^2/(x+f*q) > 0
```

for `a,D,q,x>0`, provided the swaps remain within the active range. This is not a claim that a price change alone causes profit: the expression is the final target wallet change after opposing inventory and shares have been fully closed.

At `a=D=x=100`, changing the compulsory swap fraction gives:

| `r` | Zero-fee target profit | Profit with 0.3% LP fee, gross executed-price credit | Profit with 0.3% LP fee, net-price retained credit |
| --- | --- | --- | --- |
| 49% | `2401/498 = 4.821285140562...` | `4.651234817328...` | `4.578456264217...` |
| 50% | `5` | `4.826187467823...` | `4.751961940743...` |
| 51% | `2601/502 = 5.181274900398...` | `5.003693967855...` | `4.928024150907...` |

These are parameters, not a threshold at 50%. If the attacker may choose `q`, it can choose any profitable admissible size. Requiring one of these three fixed ratios does not establish safety.

For reproducibility of the fee-bearing rows, set `h=3/1000`, `g=997/1000`, and use E2. Gross-credit issuance still has `f=1/2`. Net-price retained issuance has
`f=(100-h*q)/(200-h*q)`. In either case, withdraw

```text
t = f*(200-q)
v = f*u
z = (100+g*q)*g*v/(100-u+g*v)
attacker final T = t+z
remaining vault = ((1-f)*(200-q), (1-f)*u)
external principal = (100+g*q-z-100c, 100-u+g*v-100c)
external fee claims = (h*q, h*v).
```

Attacker opposing balance, shares, LP positions, and debt are zero. Adding the displayed custody and fees closes both tokens exactly for every row. These equations specify the entire ledger, not just the decimal profit.

For the 50% gross-credit case, exact intermediate values are:

```text
q = 50
u = 99700/2997
v = 49850/2997
attacker final T = 10470058473/99880180
remaining vault = (75,49850/2997)
external virtual reserves = (599400000/4994009,4994009/59940)
external fee claims = (3/20,997/19980).
```

Subtract `100c` from each virtual reserve for actual pool principal. If the incumbent subsequently sells all remaining O, then:

```text
incumbent final T = 473104196402025/4984035964027
external final virtual reserves = (99900000/998003,998003/9990)
external final fee claims = (3/20,997/9990).
```

Both token conservation identities were checked with exact rational arithmetic. The incumbent's final target loss is not all attacker profit: some goes to the external LP through the fee-bearing execution. That separates ordinary fee drag from the transfer to the attacker.

For gross-credit issuance the exact profitable-size condition is:

```text
Payout-D =
 f*q * [ (g^2-1)*x + g^2*(g-f)*q ] / (x+f*g^2*q).

If g>f:
q > x*(1-g^2)/(g^2*(g-f)).
```

At `x=100,f=1/2,h=0.003`, the threshold is
`599100000/494022473 = 1.212697868503...`. This is a fee-dependent cutoff for this specified book and execution rule, not a universal safe fraction or fee.

**Controls:** With no entry swap, `q=0`, direct mint against the incumbent target balance and immediate exit return exactly 100; `p_exec` is undefined at zero swap and is not evaluated. In a second control, the attacker independently buys and immediately sells the acquired opposing tokens without entering the vault. With zero fees it returns exactly its original 100 target; with positive fees it loses target. The positive vault-cycle result is therefore not an ordinary free standalone AMM round trip.

**E5. Current quote rule and real-swap/quote hybrids, with temporary LP inventory closed.**

Use E4's external range and `L=100`, zero fees, and `s=1`, but give the vault idle `(100 T,100 O)`, no LP positions, and `S=100`. Attacker starting wallet is `(100 T,0 O)`.

For the current no-entry-swap arithmetic:

```text
Q0 = 100 + 100*100/(100+100) = 150
m  = 100*100/150 = 200/3
f  = 2/5.
```

After accepting the deposit the vault has `(200,100)`. Add temporary external liquidity `J=900` at `s=1`, funded by zero-fee loans of `900*(1-c)` of each token. The whole-book quote is now

```text
Q1 = 200 + 1000*100/(1000+100) = 3200/11.
```

A quote-based payout gives `f*Q1=1280/11`. It can be paid from vault idle target, so the temporary position has not traded. Removing it returns both borrowed token quantities exactly. Repay both loans. Attacker ends with `1280/11 T,0 O`, no shares, no LP, no debt: **profit `180/11`**.

The vault remains `(920/11 T,100 O)`. The external pool is unchanged. Incumbent final liquidation yields `920/11+50=1470/11`, versus initial liquidation proceeds 150: loss `180/11`. With `J=0`, the payout is exactly 100 and profit is zero. This reproduces the accounting mechanism in a fully specified idle-book model, not the audit's production fixture or output.

Now require **real swaps on both entry and exit**. Entry executes `q=50`, yielding `u=100/3`, `s1=3/2`. The combined book is `(A,B)=(150,400/3)`. The old-book quote is 150 if sampled before entry, but 190 if sampled after entry while excluding the entrant's retained assets.

After minting, add `J=900` at `s1`. Borrow and provide exactly

```text
J target principal   = J*(s1-c)
J opposing principal = J*(1/s1-c).
```

At exit, actually sell `v=f*B`, with total active liquidity `L+J=1000`, and let:

```text
s2 = 1/(1/s1 + v/(L+J))
z  = (L+J)*(s1-s2)
Q1 = A + (L+J)*s1*B / ((L+J)/s1+B) = 400.
```

Compare payout rules `P=f*Q1` and `P=f*A+z`. The first is the quote-payout hybrid; the second pays actual slice proceeds. In the quote-payout hybrid the actual slice proceeds exceed the quote payout, so this particular example does not require a top-up from other holders; the unused target remains in the vault.

Crucially, the attacker's temporary LP has traded. It has lost target and gained opposing inventory:

```text
delta_J_T = J*(s2-s1)
delta_J_O = J*(1/s2-1/s1).
```

Remove it. Repay its original opposing loan, sell **all** the excess `delta_J_O` through the remaining external liquidity `L=100`, and repay the original target loan:

```text
s3 = 1/(1/s2 + delta_J_O/L)
close_T = L*(s2-s3)
attacker profit = P-D+delta_J_T+close_T.
remaining vault = (A+z-P, B-v).
```

This closes the opposing balance, LP position, shares, and both debts. The final external principal is `(100*s3-100c,100/s3-100c)`.

Exact results:

| Mint cutoff | Payout | `f` | Target profit, `J=900` | Control profit, `J=0` |
| --- | --- | --- | --- | --- |
| Pre-entry quote 150 | Live quote | `2/5` | `140/9` | `0` |
| Pre-entry quote 150 | Actual slice | `2/5` | `80/3` | `80/3` |
| Post-entry old-book quote 190 | Live quote | `10/29` | `104900/44051` | `-400/29` |
| Post-entry old-book quote 190 | Actual slice | `10/29` | `18400/1421` | `18400/1421` |

For the first row, every changing quantity is particularly simple:

```text
v=160/3; s2=25/18; z=1000/9; P=160;
delta_J_T=-100; delta_J_O=48;
s3=5/6; close_T=500/9;
attacker final=(1040/9 T,0 O);
vault final=(910/9 T,80 O);
external virtual final=(250/3 T,120 O).
```

For the post-entry quote/quote-payout row:

```text
v=4000/87; s2=87/62; z=3000/31; P=4000/29;
delta_J_T=-2700/31; delta_J_O=1200/29;
s3=87/98; close_T=78300/1519;
vault final=(97850/899 T,7600/87 O);
external virtual final=(4350/49 T,9800/87 O).
```

For each of the four rows, the exact equations give:

```text
attacker final T + vault final T + external virtual T = 300
vault final O + external virtual O = 200.
```

Subtract the fixed `100c` offsets for actual external principal. All lender balances return to their initial balances. These identities were checked with `Fraction`.

The actual-slice rows are independent of this particular `J` after its inventory is fully unwound. This is useful evidence **for** slice exits: they remove this direct quote-payout benefit from temporary depth. But the rows remain profitable because the live whole-book **mint** discounts old opposing inventory by full-book liquidation impact, then issues a claim that can be exercised as a smaller slice. Fixing execution does not fix that issuance mismatch.

**E6. Active-vault LP self-fill is not omitted.**

The idle-book counterexample suffices to disprove a universal rule, but it does not establish a Wings lifecycle exploit. Here is a separate exact one-range example with active incumbent liquidity and its changing composition explicitly counted.

Use the valid tick interval `[-10000,10000]`, spacing 1, and set
`c=(10001/10000)^(-5000)`. Both the vault and external LP use this range, with `L_v=10`, `L_e=100`, initially `s=1`. Vault supply is 100 and idle balances are:

```text
idle_T = 100 + 10*(c-1/2)
idle_O =       10*(c-1/2).
```

These are positive. The external LP additionally holds a fixed wallet of
`100*(c-1/2)` of each token. Including that wallet, its initial custody is `(50,50)`. Vault initial total inventory is `(105,5)`. This explicit offset normalization gives simple fractions without pretending an unaligned square-root boundary of 1/2 is a V4 tick.

Attacker starts with 100 target, zero opposing, no positions or debt. Pool fee is zero. Swap 50 target, with all 110 liquidity participating:

```text
s1=16/11
u=275/8
p_exec=16/11.
```

The old vault's total inventory, **excluding entrant retained assets**, is now:

```text
A_T=1205/11
A_O=15/8.
```

Thus the executed-price pre-swap and post-swap incumbent denominators agree:

```text
105 + (16/11)*5
  = 1205/11 + (16/11)*(15/8)
  = 1235/11.

m = 22000/247
f = 220/467.
```

Burn all entrant shares. Remove `f*10` incumbent LP units and the same fraction of both idle balances. The separated exit slice is:

```text
T_slice=35100/467
O_slice=7975/467.
```

Sell only this opposing slice through `100 + (1-f)*10` remaining pool liquidity. The remaining incumbent LP participates in that swap; it has not been ignored or frozen at its old composition:

```text
s2=7152/6077
exit swap target output=82963200/2837959
attacker final T=296265900/2837959
attacker profit=12470000/2837959 = approximately 4.394 target.
```

The final complete custody ledger is:

| Owner | Target | Opposing | LP liquidity |
| --- | --- | --- | --- |
| Attacker | `296265900/2837959` | `0` | `0` |
| Incumbent vault, idle plus actual remaining LP principal | `235313195/2837959` | `35815/1788` | `2470/467` |
| External LP, actual principal plus its fixed wallet | `411350/6077` | `62525/1788` | `100` |

Target sums to 255 and opposing to 55, exactly their initial totals. Attacker shares and debt are zero. This is a target-wallet profit, not a marked LP profit.

For a fully closed incumbent comparison, remove its remaining LP and sell all its remaining opposing inventory. It finishes with
`6279625495/59597139` target. Initially it could have removed its LP and sold its five opposing tokens to finish with `2305/21` target. The difference is exactly `12470000/2837959`, the attacker profit. The external LP plus fixed wallet ends with the same inventory in both liquidation comparisons.

The no-entry-swap control is not evaluated using an undefined `p_exec`; a direct target-only mint/exit control applies to E4. E6 instead compares the exact before/after incumbent liquidation ledgers and checks both token totals; its purpose is to test the omitted-self-fill objection to E4, not assert that every unswapped scalar mint is safe.

With an entry fee, active vault LPs receive their proper share before issuance. If they have constant participation fraction `alpha` over the swap, their gross-fee-inclusive inventory change is:

```text
delta A = (alpha*q, -alpha*u)
delta(A_T + p_exec*A_O) = 0,   when p_exec=q/u.
```

The fee component inside `alpha*q` is not missing. Net-price accounting instead credits the LP fee separately to old holders and excludes it from entrant retained value. E4's fee-aware column shows that this correction alone still does not yield a general ownership-conservation theorem. Tick crossings change `alpha` and require stepwise attribution; the constant-alpha identity must not be extended across them without that accounting.

**E7. The price-free vector invariant and its exact domain.**

After entrant conversion and settlement of fees earned before minting, define the old book as:

```text
B = (L_core, L_upper, L_lower, idle_T, idle_O, other separately owned claims).
```

Keep distinct ranges distinct, even if inactive. If fees are not actually collected, the separately owned fee claims must also be preserved componentwise. Let accepted contributions be `C=lambda*B`, and mint `m=lambda*S`. Then:

```text
S/(S+m) * (B+C) = B
m/(S+m) * (B+C) = C.
```

This is an exact invariant of incumbent ownership **at the acceptance cutoff**, requiring no price oracle. Every component of the old book survives for incumbents, not merely the value of a linear combination at a sampled price.

An integer implementation must choose a share amount and charge enough of every nonzero component, rounding contributions upward and accepted shares downward, with unused tokens refunded. Equivalently, candidate contributions cap `m` by the minimum supported component ratio; any zero old component must not silently grant free issuance for new unmatched inventory. Bootstrap requires its own rule. This is an accounting specification, not implementation authorization.

The domain is:

- Atomic acceptance after entry swaps and old-fee attribution, with no intervening swaps, harvest changes, reentrancy, or unaccounted liabilities between the snapshot and matching.
- Same pool key and **each same individual range/position exposure**, not merely equal total liquidity.
- Entrant pays actual conversion and position-addition costs; rounding dust is assigned explicitly.
- Exit removes the same fraction of every position and idle balance, with earned fees attributed at the exit cutoff, before selling only the separated slice. No other-holder top-up.

For a slice fraction `h`, removal gives `h*B` to the exiter and leaves `(1-h)*B` immediately before the exit sale. The sale may subsequently trade against the remaining vault LP, changing its principal composition and earning it fees. The invariant does **not** say the remaining vault's token inventory is frozen during that trade.

Liquidity units in disjoint ranges are not one fungible scalar. A sum of core, lower, and upper liquidity cannot prove the displayed vector equality: the ranges have different active states and different token deltas along a price path.

The E4 proportional-vector control is exact. Since its old book has only idle target, accept only the entrant's retained 50 target, mint 50 shares, and refund its `100/3` unmatched opposing tokens. Its shares redeem for exactly 50 target. Selling the refunded opposing tokens reverses its entry swap and returns the other 50 target at zero fee. It finishes with 100, the incumbent keeps 100, and the pool is restored. With fees the entrant bears the round-trip fee drag.

This establishes elimination of the quote-to-share **ownership distortion** under the stated vector rule. It is not a blanket theorem forbidding every profitable strategy against the vault's AMM positions, future rebalances, other customers' orders, donation rounding, or execution permissions.

**E8. Same-pool TWAP: implemented history, ideal history, and what each can prove.**

The source inspected was:

- `contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol:32-45,60-103,126-133`.
- `contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol:27-35,80-112,137-157,239-251`.

The target reads the live tick for permissionless writes and for read-side extrapolation. The library truncates the current tick relative to `prevTick` by at most 9116 ticks and multiplies that **newly supplied tick** by the whole elapsed observation interval. `writeAge` is reset by the write.

An exact historical-property counterexample: initialize at tick 0; wait `W` with tick 0; at the next write supply live tick `K`, with `0<K<=9116`. The write records cumulative growth `K*W`, although the historical interval was at tick 0 until the write. With suitable retained observations the window mean is K, rather than 0. Read-side extrapolation has the corresponding live-tick dependence. This proves a limit of the implementation as a historical reference; I do not count any hypothetical borrowing or marked inventory as a profit from this example.

An **ideal** historical oracle would record the tick that actually prevailed over elapsed time. It would not give a just-executed atomic spot movement a whole prior window of weight. That distinction is valuable, but does not make its price independent of this pool or value all untraded inventory by execution.

For a concrete gate, write:

```text
abs(currentTick - historicalMeanTick) <= delta.
```

The rule must say when this is checked and whether the swap's permitted path is also bounded. An entry-only check at the initial tick does not constrain the ensuing self-induced movement in E4. Checking both endpoints or limiting the complete path can reject that particular large swap. With zero fees, E4's formula is strictly positive for every positive `q`, so any positive tolerance admitting a sufficiently small swap still admits a positive example in that accounting model. At nonzero fees, the explicit size threshold above can make a sufficiently tight gate exclude that example. This is a bounded-domain result, not a proof about all inventories.

A gross-credit TWAP mint `m=S*D/(A_T+p_bar*A_O)` also gives exactly E4's mint, for **any** `p_bar`, because its old `A_O` is zero. The closed profit therefore does not depend on corrupting the TWAP or moving an outside notion of fair price.

A retained-credit TWAP mint is a different rule:

```text
V_bar = A_T + p_bar*A_O
C_bar = (D-q) + p_bar*u
m = S*C_bar/V_bar.
```

With a fixed `p_bar` and fixed post-swap inventory cutoff, it has the exact scalar invariant:

```text
S/(S+m) * (V_bar+C_bar) = V_bar.
```

But the componentwise residual is:

```text
S/(S+m)*(B+C) - B = (S*C-m*B)/(S+m).
```

It vanishes componentwise only when the contribution vector has the corresponding proportional relationship. The scalar equation alone is not the vector invariant and does not equal executable target value.

I do not claim an unrestricted closed profit against every retained-credit ideal-TWAP policy. Its precise demonstrated limit is scalar conservation at that reference and cutoff, not a proof of ownership-vector conservation or of safe same-pool liquidation. In E4 at `p_bar=1`, retained credit is `250/3`, not 100, so the gross-credit witness must not be relabeled as a witness against this distinct formula.

No outside arbitrageur is assumed to restore price. An ideal same-pool history also cannot itself prove that maintaining a different pool state for a full window has an economic cost sufficient to secure an arbitrary vault; such a claim needs its own capital, fee, timing, and closed-inventory analysis.

# Assumptions

1. All accounting witnesses use ordinary two-token custody without transfer fees, rebasing, hidden liabilities, protocol fees, hooks, or third-party transactions.
2. Amounts are continuous rational token units. The algebra is exact in that domain. Actual Solidity uses fixed-point square-root prices, discrete integer amounts, and rounding; those bit-level effects were not executed here.
3. The stated tick intervals bound the paths. E4/E5 use one external interval; E6 uses one vault and one external interval. There are no liquidity-boundary crossings during their swaps.
4. Fee-bearing examples allocate fees to the external LP as separate claims, consistent with V4 rather than automatic V2-style compounding. E6's numerical witness has zero fees; its fee-attribution identity states its own constant-participation domain.
5. Loans in the JIT examples have zero interest and are fully repaid in both tokens. Positive loan charges reduce the stated margins; no loan remainder is treated as profit.
6. No minimum-output or tick-deviation guard beyond the displayed rule blocks the path. A guard that does block it changes the admitted domain and must be evaluated as such.
7. Idle assets and LP principal are segregated from entrant pending assets at the stated cutoff. Mistakenly including entrant inventory in the denominator is a different equation.
8. Token totals, executable sales, and same-pool benchmark liquidations are used for loss attribution. There is no external fair price.

# Coverage

| Required target or issue | Coverage and limit |
| --- | --- |
| Money, Accounting, LiquidationQuote | Read; current mint, payout, funding, and live-pool quote behavior verified from source. |
| Inventory, Geometry, Harvest, ExecutionDelegate, EconomicTarget | Read; fee ownership, current-price principal, actual settlement, production range structure, and existing `getRate` distinguished from the proposed rules. |
| APEX-2026-012 and 024/025/026/040/050 | Read as required context. Audit numbers not rerun or promoted to my closed-ledger evidence. |
| Vendored pool math | `SwapMath` read; amount-delta implementation in `SqrtPriceMath` read. Exact continuous derivations and rational conservation checks performed. |
| Literal executed-price, pre/post cutoff | E4 and E6; zero and positive fees, actual slice exits, old-LP self-fill, and retained-credit distinction. |
| 49%, 50%, 51%, attacker-chosen size | Explicit calculations and exact profitable-size inequality in E4. |
| Temporary LP inventory | E5 counts composition change, removes LP, sells excess opposing tokens, and repays both loans. |
| Proportional vector rule | Exact componentwise invariant, integer-rounding direction, fee cutoff, disjoint-range distinction, and control. |
| Same-pool oracle as implemented | Source-derived historical-property failure; no monetized oracle attack claimed. |
| Ideal historical oracle | Separately analyzed as a gate, gross-credit mint, and retained-credit scalar mint. No independent-price assumption. |
| Complete Wings lifecycle | **Not established.** Models do not run mandatory harvest, full-range core plus both wings, placement, sleeve floors, all integer guards, or the full public entry/exit surfaces. |

# Conclusions

1. **“Actually swap on entry and exit” is not a sufficient accounting rule.** E4 closes a +5-target cycle without external pricing or leftover inventory. Fee-aware retained credit, as specifically defined above using net executed price, still has positive fee-bearing examples.
2. **A real swap can correctly price what traded yet fail to justify issuing claims over the rest of the book.** The demonstrated failure is the subsequent allocation and nonlinear unwind, not merely a moved price. In the idle-target example no old opposing inventory is even being marked.
3. **Post-swap inventory and old-LP fee attribution are necessary distinctions, not a universal cure.** E6 counts both old LP conversion on entry and the remaining LP's participation in the actual exit sale; the closed target profit remains.
4. **Actual proportional exits do remove an important payout-side defect.** E5 shows the temporary-LP effect cancels after full unwind for its slice-payout rows, while live-quote payout retains a JIT benefit. However, live whole-book liquidation issuance can still overissue shares for a smaller-slice claim.
5. **A price-free proportional position-vector mint has a provable ownership invariant at acceptance.** Its guarantee is componentwise, independent of a same-pool price. It requires matching each position and idle balance and explicit fee and rounding attribution. It does not automatically guarantee all future trading outcomes.
6. **TWAP must be specified as a particular equation and execution gate.** The implemented oracle is not the ideal historical oracle in E8. Even the ideal oracle does not cure E4's gross-credit rule. A retained-credit TWAP formula has a scalar invariant, which should be stated as such rather than advertised as the vector or executable-value invariant.
7. **Production remediation is not delivered or authorized here.** The evidence answers the accounting question and identifies the proof obligations. `getRate` remains separate from issuance, and a one-whole-share preview remains a withdrawal-and-sale quote rather than a substitute mint denominator.

# Limits

The strongest negative claims here concern completely specified continuous accounting models, with exact token conservation and controls, not an executed Solidity reproduction of every Wings path. Positive margins suggest integer scaling can preserve examples, but I did not prove a global rounding-error bound or run the contracts; that is not asserted as production reachability.

The vector theorem establishes preservation of incumbent ownership at one well-defined cutoff. It does not cover economic losses from incumbent LP trades before or after that cutoff, future portfolio reshaping, other users' transactions, malicious token behavior, or availability of target-only liquidation when no executable opposing buyer remains.

The ideal retained-credit TWAP policy is not exhaustively classified. A finite set of arithmetic examples is not a universal theorem. No result here claims council consensus, peer agreement, or an independent external price.
