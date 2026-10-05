# Astra — Round 2 independent original

2026-10-01. Human-selected scope now includes finite-capacity splitting and NET-funded SE zap-in. My earlier whole-fill recommendation is superseded by that selection, not rewritten. No peer artifacts read this round. Research only; this report is the sole write.

**Recommendation:** support split NET→USDG sales, including LP/SE-share→USDG exits, and jointly optimized NET→LP/SE-share zap-ins. Use one explicit execution policy initially: **at most one buyback, then at most one canonical swap, then proportional deposit where applicable**. This supports splitting, not merely whole fills. It is not a claim of global optimality over arbitrary call sequences. Integer-optimal allocation remains a specific proof/engineering gap below.

## 1. Source baseline and exact capacity

Notation: **N/** = `lib/crane/contracts/protocols/pol/net/src/`; **U/** = `lib/crane/contracts/protocols/dexes/uniswap/v2/`; **V/** = `contracts/protocols/dexes/uniswap/v2/`; **M/** = `lib/crane/contracts/utils/math/`.

Read current CLAUDE, canonical architecture/adversarial skills, PRD **v0.34**, and plan **v0.10** requirements. NetNet `VENDOR.md:5–18,39` attributes sources to the 2026-08-28 verified-source dump, deployed compiler **0.8.30**, Crane **0.8.35**. No live equivalence or liquidity observation was performed.

**Observed:** `N/InverseBond.sol:68–89,108–139` permits contract callers, pulls/burns nominal NET, pays caller USDG, uses live NAV price, and uses TWAP only as an availability gate. Capacity is WAD USDG, snapshotted on first fill of the genesis-anchored eight-hour epoch. No partial-fill or exact-output ABI exists; splitting is SE orchestration.

For positive price `P` (WAD USDG/NET), `U=1e9`, raw USDG scaling `F=10^(18-decimals)`, remaining WAD capacity `C`:

```
w(b) = floor(b*P/U)
q(b) = floor(w(b)/F)
bCap = ceil((C+1)*U/P) - 1
```

**Derivation:** `floor(bP/U)≤C` iff `bP<(C+1)U`. Bound `b` by operation-owned NET and burnable supply; use full-precision, overflow-safe arithmetic. `floor(C*U/P)` is safe but not always maximal. Capacity debits **w**, not `q*F`. Zero-output/dust fills should not execute merely to affect later prices. `active()` is necessary screening, not proof that the requested fill or treasury withdrawal succeeds.

NET transfer receipt is `T(g)=g-floor(g*t/10000)` on taxable hops, otherwise `g`; minimum gross for positive net `n` is `floor((n-1)*10000/(10000-t))+1`. Resolve actual endpoints (`N/NET.sol:121–145`); neither endpoint mapped suffices for an untaxed buyback hop. Factory validation prevents arbitrary runtime vault mapping (`:201–219`). Do not assume an LP burn or subsequent NET deposit is exempt.

## 2. Clean continuous model — not production arithmetic

Assume synchronized positive pool reserves `X NET,Y USDG`, no integer floors, no protocol-fee mint, fixed buyback price `p`, untaxed buyback, swap NET receipt fraction `a`, deposit NET receipt fraction `h`, AMM multiplier `γ=.997`, and operation budget `A` already held NET. Define:

```
f(m) = Y*γ*a*m/(X+γ*a*m)
```

For a sale, allocate `b` to buyback and `m=A-b` to AMM. Maximize `p*b+f(m)`, subject to `0≤b≤min(A,C/p)` in consistently normalized units. Interior optimum satisfies **marginal** `f'(m)=p`, where

```
f'(m)=Y*γ*a*X/(X+γ*a*m)^2
m0=(sqrt(Y*γ*a*X/p)-X)/(γ*a)
```

Clamp `m0` to `[max(0,A-C/p),A]`. Comparing average prices, or automatically filling capacity first, is not generally optimal. If the buyback beats the pool's initial marginal return, capacity-first is optimal in this simplified sale model.

**Zap-in has a different objective.** Choose `b,m,d≥0`, `b+m+d=A`. After conversion:

```
Q=p*b+f(m); X'=X+a*m; Y'=Y-f(m)
L=S*min(h*d/X', Q/Y')
```

Maximize final LP `L`, then actual recipient SE shares—not intermediate USDG. Balanced interior deposits satisfy `h*d/X'=Q/Y'`. Eliminating `b` gives:

```
b(m)=[h*(A-m)*(Y-f(m))-f(m)*(X+a*m)]
     /[h*(Y-f(m))+p*(X+a*m)]
L(m)=S*h*[p*(A-m)+f(m)]
     /[h*(Y-f(m))+p*(X+a*m)]
```

Optimize this objective over feasible `m`, including capacity boundaries and one-venue endpoints; interior condition is `dL/dm=0`, **not** the sale's `f'=p`. For buyback-only conversion, `m=0` and `b=h*A*Y/(p*X+h*Y)`. Selling all available capacity can leave too little NET to deposit. Gross deposit ratio is `d/Q=X'/(h*Y')`, not `X'/Y'`.

These equations establish the right optimization problem; they do not prove an integer candidate neighborhood sufficient.

## 3. Ordering and repeated fills

**Observed dependency:** treasury POL RFV uses current reserves, treasury LP balance and pair supply (`N/Treasury.sol:94–117`). An AMM swap grows k through its retained fee; consequently pool-first can increase the later buyback price. NET transfer tax goes to TaxCollector, not directly to treasury (`NET.sol:136–140`), so it does not automatically increase liquid capacity. Pure swapping ordinarily leaves the liquid-cap base unchanged; explicit treasury flows or aliases require separate treatment.

Thus pool-first sale objective is `f(m)+(A-m)*p(m)`, whose derivative includes `(A-m)*p'(m)`. Reusing the fixed-p optimum is invalid. LP burn must precede the exit's comparison, including fee mint, actual NET receipt and treasury valuation changes. Deposit should follow conversion; depositing early changes custody, backing and mint sequencing.

Repeated buybacks are economically different. Ignoring rounding/Morpho, with treasury value `R`, supply `S`, discount `δ`, after buying `b`:

```
p=δR/S; next NAV=(R-p*b)/(S-b)>R/S   (δ<1,b>0)
```

Later fills can pay more, consuming capacity differently. Therefore no unlimited micro-fill loop and no claim that a one-call optimizer is globally best. **Product choice:** approve the recommended one-buyback-first policy, or explicitly expand sequence optimization. **Engineering:** project Morpho unwind/haircut effects where applicable (`Treasury.sol:135–145`), not simply `RFV-=quotedWad`.

## 4. Executable integer transition and reuse boundaries

For each candidate `(b,m)` under the recommended order:

1. Snapshot full raw/booked balances, pool reserves/balances/supply/kLast/feeTo, vault fee checkpoints, tax predicates, oracle availability, treasury/supply/cap state. Credit only this operation's input. Realize reference SE fee shares before user-share conversion.
2. Evaluate `w(b),q(b)` exactly; reject capacity excess, taxed nominal-burn hop and zero-output buyback. Execute typed `swap(b,minRaw)` with bounded approval; measure USDG receipt.
3. Compute swap input `T(m)` and canonical integer output `floor(997*T(m)*Y/(1000*X+997*T(m)))` in the clean synchronized case. Execute via tax-aware direct-pair or supporting-FoT routing and verify deltas. Update reserves by **full received input**, not fee-adjusted input.
4. For zap-in, retain `d=A-b-m`. Compute fee-adjusted pair supply `S'`, then `L=min(floor(T(d)*S'/X'),floor(Q*S'/Y'))`. For target `L`, minimal net deposits are `ceil(L*X'/S')`, `ceil(L*Y'/S')`; gross up NET with the exact tax inverse. Transfer only required amounts and call pair mint; measure minted LP and final shares.

The evaluator must handle unsynchronized balances and pre-existing pair-held LP explicitly, not credit donations twice. Existing `V/…QuoteTarget.sol:18–48,212–270` already tracks these distinctions. The clean formulas alone are insufficient there.

**Do not feed gross NET/USDG into stock addLiquidity and assume proportional receipt.** Router selection is nominal (`U/stubs/UniV2Router02.sol:41–84`), while pair mint uses actual balance increases (`U/stubs/UniV2Pair.sol:255–295`). Existing `U/services/UniswapV2Service.sol:156–169,339–414` and `M/ConstProdUtils.sol:374–474` assume canonical swap balancing; they are reuse references, not the split solver.

Reuse exact fee mint `M/ConstProdUtils.sol:984–995`; protocol fee occurs before LP mint/burn, separately from 0.3% swap fee and NET tax. SE usage-fee dilution remains `V/…Common.sol:125–191`; mint user shares against **pre-zap LP backing and fee-adjusted share supply** (`V/…InTarget.sol:706–762`). Audit source parity: local pair fee-off branch writes local `kLast_` (`:249–250`), whereas upstream clears storage `kLast`; do not certify the port as an exact runtime oracle.

**Optimizer gap:** exhaustive integer `(b,m)` evaluation defines a correctness oracle but is not a viable production algorithm. Continuous stationary points/cap endpoints plus neighboring integers are candidates, not a proof amid tax/payout floors. A gas-bounded solver with certified bounds/rounding regret, or a proven exact optimizer, remains necessary. Always include the tax-aware canonical-only candidate and reject a proposed improvement that lowers final output/shares.

## 5. Residuals, exact output, fallback and accounting

Reference residual semantics are not uniform: exact-input pretransfer refunds no unused maximum; exact-output refunds bounded credited-minus-used (`contracts/vaults/basic/BasicVaultCommon.sol:108–137`; plan:331–335). Exact-output vault zap mints only requested shares, leaving rounding backing for holders; pass-through zap sends all minted LP (`V/…OutTarget.sol:922–981`). Preserve those distinctions.

New split-zap NET/USDG conversion leftovers need an **explicit ownership policy**. Recommend returning operation-attributable leftovers to its funding caller, with net-transfer accounting; this is a proposed amendment, not existing blanket exact-in refund permission. Never sweep booked inventory or unclaimed pretransfer surplus. Specify dust and tie-breaking rather than silently donating a badly balanced leg.

Exact-output buyback alone needs `ceil(y*F*U/P)` NET. Split exact-output minimizes **total gross input** over venue allocations; LP/share exact-output additionally inverts the complete zap. Existing `M/ConstProdUtils.sol:579–654` binary-searches a different forward function; comments calling it closed form do not make it reusable unchanged. Minimality/monotonicity and integer forward replay remain proof obligations, not grounds to remove existing canonical routes.

At execution, re-read capacity and replan before effects. Depletion routes remaining input through canonical execution only within original deadline/max-input/min-output or min-shares. If a buyback call reverts, its subcall rolls back; a specified fallback can recompute the entire remaining zap. Never reuse the old sold amount or silently lower limits. Failed final settlement reverts **all** prior legs.

Execution-transition quotes must project capacity, NET supply, treasury value, taxes, pool and vault mutations. Accounting valuation excludes the unowned buyback option. The existing sampled rate provider calls execution previews/quoteAssets (`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:85–120,160–173`), requiring explicit decoupling.

Custom **SE NET zap-in** does not reroute **DETF NET/sNET input**, which remains Keep-YT; USDG DETF input still enters SE, and USDG exits benefit from split NET sales (plan:28–35). No new liquid DETF issuance or HLP unwrap right.

## 6. Evidence, confidence, remaining choices

Context7 `/uniswap/v2-core` consulted first. Primary sources fetched **2026-10-01**:

- https://raw.githubusercontent.com/Uniswap/v2-core/master/contracts/UniswapV2Pair.sol — upstream Solidity 0.5.16, unpinned master.
- https://raw.githubusercontent.com/Uniswap/v2-periphery/master/contracts/UniswapV2Router02.sol — Solidity 0.6.6, unpinned master.
- https://docs.netnet.capital/treasury — publication; its “TWAP-settled” wording does not override inspected live-NAV pricing.

**High confidence:** ABI, capacity inequality, tax/deposit distinction, sequence dependencies and reference call paths. **Medium:** proposed bounded policy and continuous derivations. **Not established:** deployed equivalence, current liquidity, integer global optimum, gas bounds or profitability. Product decisions remaining: call-order/call-count policy, residual recipients, fallback and acceptable optimization guarantee. Engineering obligations: exact solver proof, coherent projections, source-parity checks and eventual adversarial/integer differential validation. No shell, tests, RPC, browser or implementation performed.
