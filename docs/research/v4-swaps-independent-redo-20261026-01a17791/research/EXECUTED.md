# Coordinator execution record

Executed on 2026-10-26 in the resident Python kernel. All arithmetic assertions
completed normally. No Forge, PoolManager transaction, deployment or production
test was run. This is economic-model evidence, not production audit closure.

## New exact rational model

Source: `exact_ledger.py`, SHA-256
`cd6324d757083c1514180889c1c66da1030b150a11279809f75c865e63b0689b`.
Executed using `compile`/`exec` in a module namespace, then `main()`.
Reproduce with the command in the source docstring. Only standard-library
Python is required; the program prints results and never writes files.

Domain: one active full-range interval, infinite-range limiting arithmetic.
Both assets have the same unit convention. Initial sqrt price 1; vault core
liquidity 100; old share supply normalized to 100. The entrant owns target
only. LP fees accrue separately. Matched input adds core; excess is retained
idle, equivalent to a dormant wing only while that range never activates.
The pool can have ambient liquidity belonging to others.

The execution-price rule uses POST-swap old principal plus ALL incumbent
entry-swap fees in the denominator:

```
p_exec = target_spent / opposing_received
V_old = old_target_after_swap + old_target_fee + p_exec * old_opposing_after_swap
C = retained_target + p_exec * retained_opposing
m/S = C/V_old
```

This is not the literal pre-swap-book variant. All retained tokens receive
credit, there is no donation, and the old vault fills its share of both swaps.
Exit burns the entrant's entire share and removes only that share of core
and idle inventory, then actually sells all its opposing tokens.

### Closed witness, 0.3% fee

Vault owns 100% of the active interval. Deposit 200 target, swap half.

| Event/claim | Exact number | Decimal |
|---|---:|---:|
| Initial incumbent opposing/target | 100 / 100 | 100 / 100 |
| Initial attacker opposing/target | 0 / 200 | 0 / 200 |
| Entry target spent | 100 | 100 |
| Entry opposing received | 99700/1997 | 49.924887330996494742 |
| Entry target fee, all credited to old vault | 3/10 | 0.3 |
| Execution price, target per opposing | 1997/997 | 2.003009027081243731 |
| Old book marked at that price | 299400/997 | 300.300902708124373119 |
| Minted shares / old shares | 997/1497 | 0.665998663994655979 |
| Added core liquidity | 100000/1997 | 50.075112669003505258 |
| Added dormant opposing inventory | 99100900/3988009 | 24.849718242862541183 |
| Burned slice opposing | 49850/1247 | 39.975942261427425822 |
| Burned slice target | 149550/1247 | 119.927826784282277466 |
| Exit opposing fee | 2991/24940 | 0.119927826784282277 |
| Actual exit target from swap | 17785045871101949229/210758608401740140 | 84.385857384296080896 |
| Final attacker target | 43060867752802220229/210758608401740140 | 204.313684168578358362 |
| Final attacker profit target | 909146072454192229/210758608401740140 | **4.313684168578358362** |
| Final incumbent opposing | 100 | 100 |
| Final incumbent target | 20166714767719821771/210758608401740140 | 95.686315831421641638 |
| Opposing and target conservation errors | 0 / 0 | 0 / 0 |

Attacker final opposing, shares, LP and debt are all zero. No borrowing or
external sale is used. No prior manipulation trade is needed: the actual
entry swap itself moves price. Gas is excluded. Incumbent opposing is
unchanged and incumbent target loss exactly equals attacker target gain,
so the result does not depend on an outside price or a residual-token mark.
It is not claimed that final pool spot returns to its initial value.

At zero fee the same rule yields exactly **80/17 target profit**. This gives
an exact non-rounding counterexample; the positive fee row shows a margin
survives 0.3% on both actual swaps.

### Matched controls

With identical initial pool, input and fees:

- No vault join, just swap and reverse: `-8973027/19940090` target,
  approximately `-0.449999322971962514`.
- Strict proportional core-plus-idle-fee join, refund excess, immediate
  proportional burn, then sell withdrawn plus refunded opposing together:
  the SAME exact loss, `-8973027/19940090`.

The control uses `m/S = min(d_O/A_O, d_T/A_T)` only because this specific
old book has one core and target-only fee idle. It scales that core and
the fee idle by the same ratio. It is not a claim that aggregate token
min-ratios replicate arbitrary multi-range books.

The control's single combined opposing sale differs from the old integer
model's two sequential sales. Both are disclosed and both are negative.

### Finite search, not a proof

288 cases = 6 vault fractions (1%, 10%, 50%, 90%, 99%, 100%) x 4 fees
(0%, 0.05%, 0.3%, 1%) x 3 entry fractions (49%, 50%, 51%) x 4 deposits
(2, 20, 200, 2000 target).

- Execution-price rule: **155 strictly positive** cases.
- Proportional control: no positive case; every case asserted `profit <= 0`.
- Every executed case asserted exact opposing AND target conservation and
  nonnegative funding/refunds.

For deposit 200, 50% swap, 0.3% fee:

| Vault fraction | Profit target |
|---:|---:|
| 1% | -0.5934328680539559 |
| 10% | -0.3690289125385237 |
| 50% | +1.8642191241760497 |
| 90% | +3.9032607466373532 |
| 99% | +4.274379513378682 |
| 100% | +4.313684168578359 |

At 100% ownership, the 49% and 51% entry rows are respectively
`+3.9722992981261647` and `+4.653799034585403`.

## Re-execution of previous integer model

Read and executed the previous `research/model.py` under
`../../v4-same-pool-swap-evidence-20261026-01a171a0/`, SHA-256
`d5eeb576065b125d013a8343144e66755fd52d53186adb3e560a772b91e5f698`.
Called `research_results()` afresh rather than accepting its JSON outputs.
This checks a prior artifact; it is not an independently authored second model.

The integer model uses Q96/Q128 math, spacing 60, core [-887220,887220],
and a funded upper wing beginning at tick 13860. That wing lies strictly
above post-entry price; exit sells opposing downward and never activates it.
No existing lower wing is funded. This is still not the complete production
Wings lifecycle or an EVM run.

Selected row: executed-average actual-composition mint:

```
entry target in       100000000000000000000
entry opposing out     49924887330996494742
entry target fee          300000000000000000
old collected fee        299999999999999999
core added             50075112669003505279
upper wing added       49690400545676484087
shares minted          66599866399465597919
slice opposing         39975942261427425805
slice target          119927826784282277489
exit target out        84385857384296080868
exit opposing fee        119927826784282278
net target profit       4313684168578358357
opposing ledger error                    0
target ledger error                      0
```

The net is `+4.313684168578358357` target, about 4.522 target atoms below
the infinite-range exact result. The difference is small relative to the
4.313 target margin; it is not asserted to be solely rounding, because
finite-range boundaries also differ.

Other freshly executed selected rows:

| Rule | Net target |
|---|---:|
| Post-swap spot, actual composition | +13.806210641635458117 |
| Executed-average reference ranges | +5.534210681947098083 |
| Ideal fixed historical price 1, reference ranges | -1.138885969136707947 |
| Proportional vector/refund | -0.449999322971962518 |

All five selected rows have zero native-token conservation errors and zero
final attacker opposing. `research_results()` also completed its 120
fee/depth rows and 12 size/split rows.

## Source and execution limits

Source equations checked against vendored V4 `SwapMath.computeSwapStep`,
`SqrtPriceMath` input movement, and production `Geometry.ranges`. The
whole-book live quote and gross target-credit mint are separately visible
in production `Money._deposit`, `Money._redeem`, and `Accounting.issue`.
Those are NOT this hypothetical protective-swap mint.

No standalone model proves current on-chain reachability, both-wing
crossing safety, hook/dynamic-fee correctness, JIT safety, downstream rate
safety or audit closure. Those remain separate evidence requirements.
Python LSP could not run: `basedpyright-langserver` is not installed.
No dependency was installed to alter the research environment.

## Fresh Astra original, independently re-executed

After Astra settled, read its complete `members/astra/response.md` and
executed its section 5.7 Python snippet in a separate module namespace.
The three fixed rational positions include both wings, neither activated on
this path. Target is token0 in this witness, unlike the coordinator model.
Fees are zero; no production range/lifecycle reachability is claimed.

Initial attacker has 100 target and 100 opposing as owned capital.
It sells 100 opposing to move price, deposits 100 target (half swapped),
receives scalar-priced shares, exits only its actual slice, actually sells
all slice opposing, and buys back its original 100 opposing through the
same pool. Final attacker has 100 + profit target and exactly 100 opposing,
zero vault shares, zero LP and zero debt.

| Entry fraction | Re-executed exact target profit |
|---:|---:|
| 49% | 14719031429/7357450721 |
| 50% | 360/247 |
| 51% | 18861631/20785481 |

The coordinator asserted all three profits positive; asserted the 50%
profit equals 360/247; and independently asserted the supplied final entity
claims sum to the initial 210 target and 290 opposing.

At 50%, final incumbent vector is `(16170/247 target, 143 opposing)`;
external LP vector is `(560/13 target, 47 opposing)`. Do not attribute all
profit to incumbent target loss: incumbent target increases while opposing
falls, and the external LP also participates. This contrasts with the
coordinator's all-vault case, which isolates unchanged incumbent opposing
and an exact incumbent target loss equal to attacker profit.

Astra's scalar witness leaves entrant contributions local; its proportional
control actually adds the same fraction of each existing position. That
control ends with zero profit and restored initial pool/LP state in exact
zero-fee arithmetic. The response's proof of that control was read; the
supplied code snippet does not execute the control, so it is not labeled
coordinator-executed.

## Fresh Grok original, independently re-executed

Grok delivered complete inline text because patch was unavailable.
Recovered its complete completion-result artifact, preserving the original
at `coordinator/received-originals/grok.md` and its Python code at
`coordinator/received-models/grok.py`. The completion notice shown in chat
was clipped inside code; the retained result file contained the remaining
source and its final code fence.

Executed the complete `main()` in a separate module namespace:

```
control       -1
jit1e6        295
jit5e6        508
design2_50    343
spot20k       125
spot100k     1014
pexec_skew   1087
vector20k    -121
```

All eight expected values matched. The underlying model asserts total
native-token conservation before and after the repayment calculations.
Explicitly inspected full returns for four cases:

| Rule | Target wallet minus debt | Opposing wallet minus debt |
|---|---:|---:|
| Whole-book quote, JIT L=1e6 | +295 | 0 |
| Quote plus 50% entry swap | +343 | 0 |
| Literal executed-price, skewed dormant inventory | +1087 | 0 |
| Proportional dormant-inventory control | -121 | 0 |

The literal row has external L=100000, vault idle/dormant inventory
50000 target and 400000 opposing, D=20000, S=50000, opposing push=20000,
50% entry swap and 3000-pip fee. It mints 2760 shares at V=362256.
Final vault token vector is `(56862 target,391215 opposing)`.

Limits: the profitable literal row has no active vault core or actual
wing-position object in code; the opposing wing is represented as dormant
local inventory. Its opposing flash liquidity is assumed available. The
quote-plus-swap routine additionally parks all remaining vault liquidity
before repayment; it is not an unchanged production money-path trace.
The fee allocation is simplified per trade, not a full Q128 checkpoint
implementation. These examples support accounting-mechanism claims, not
production Wings reachability.

Grok's claim that every protective design MUST remove remaining vault
liquidity before swaps is not validated by these rows. The original admits
no closed profitable vector-rule self-fill witness. That proposed execution
restriction will be carried into the draft as disputed, not as a theorem.
