# Council recommendation: complete V4 Wings vault design

## Question, result and authority

- Run: v4-wings-complete-design-20261025-01a171a0, 2026-10-25.
- Question: recommend the entire fee-earning V4 vault, including deposits, full credit for imbalance, ownership, compounding, withdrawals, quotes, getRate and liquidity integrations.
- Profile/result: research, full four-member council.
- Authorization: the current user's explicit council request and freedom to recommend changes to previous expectations.
- Final status: coordinator revision after one advisory pass. The reviewed [r1 draft](coordinator/draft.md) is preserved unchanged. Final wording is **not newly member-approved**.
- Implementation authority: none. No production edits, project tests, builds, deployments, wallets or project Git operations were performed.

## 1. Recommendation in plain terms

**Use one fungible ERC20 share of the whole portfolio. Mint it from independently reference-valued assets actually contributed. Redeem it by withdrawing the holder's actual proportional portfolio and selling only that holder's opposing token. Keep getRate as the real one-whole-share target-exit preview.**

The complete preferred product:

| Component | Recommended behavior |
| --- | --- |
| User ownership | The same fraction of core, both wings, both idle balances and all fees |
| Target-only deposit | One approximately half-sized swap of the entrant's funds; matched core add; overage into eligible wings or credited idle |
| Full contribution credit | Value final deposit-funded liquidity increments and retained idle at one qualified independent reference |
| Fees from existing positions | Existing holders' equity, including fees earned during the entrant's own swap |
| Normal withdrawal | Remove the holder's fraction from every asset; sell its opposing amount; pay actual target received |
| Escape withdrawal | Explicit proportional two-token in-kind redemption, independent of a price feed or swap quote |
| getRate | Exact normalized preview for one whole share, not NAV, not a clamp and not a whole-book average |
| Compounding | Collect both fee tokens; reinvest into their eligible wings under the communal reference/loss policy |
| Rebalance | No portfolio-funded swap rebalance in the first release |
| External liquidity | Initially trade the share as a distinct asset in a price-discovering pool; separately validate NAV-rated or actual-redemption integrations |

**The price-reference prerequisite is real.** The preferred product is not eligible for arbitrary pairs without a qualified independent reference. For those pairs, the recommended alternative is a separate oracle-free proportional-join/refund product, not a same-pool price fallback.

**The user's original liquidity ambition is narrowed explicitly:** an execution-quoted getRate does not make unredeemed shares economically identical to raw target. Ordinary share trading is supported conceptually; unrestricted target/share parity buffering is not certified or preserved.

**The exit-liveness tradeoff also needs explicit acceptance:** in-kind is the quote-independent exit. A strict target-only exit and getRate may truthfully fail for insufficient buyers, execution limits or quote work. This is not a claim that the original target-route APEX-026 obligation has been closed.

## Participation and advisory result

Native routing evidence is in [RUN.md](RUN.md); model signatures are not the identity source.

| Member | Actual exposed route / requested reasoning | Original | Advisory disposition on r1 |
| --- | --- | --- | --- |
| Astra | chatgpt-subscription/gpt-6-astra; high resolved | [response](members/astra/response.md) | [requested-changes](members/astra/feedback.md) |
| Grok | xai/grok-4.7; xhigh resolved | [response](members/grok/response.md) | [requested-changes](coordinator/received-feedback/grok.md) |
| MiniMax | minimax/MiniMax-M3; configured adaptive, effective payload not captured | [response](members/minimax/response.md) | [support-with-reservations](coordinator/received-feedback/minimax.md) |
| Kimi | kimi-coding/k3; high resolved, global route | [response](members/kimi/response.md) | [support-with-reservations](coordinator/received-feedback/kimi.md) |

All four initial turns settled before synthesis. All four original conversations were continued once, at epoch 1, on the same r1 draft. All advisory turns settled; none is missing. No provider/model fallback or replacement was observed. The invoking coordinator, gpt-6.1-sol as exposed in its environment, is not a fifth vote.

All four advisory responses favor the broad selected architecture with corrections. That does not erase the requested-changes dispositions, prove security, or make these revised final bytes unanimously approved. Every substantive concern is mapped in [the resolution](coordinator/resolution.md).

## 2. Ownership, balances and token units

Use one ERC20 with **18-decimal shares** for new deployments. Both underlying tokens retain their native decimals; fee-on-transfer and rebasing underlyings remain unsupported. A token pause or blacklist can still prevent transfers.

Let h be a user's raw share balance and S total raw supply:

```text
user ownership fraction = h / S
```

That fraction covers every shareholder-owned asset. A user does not have a fixed personal target/opposing balance, and different users do not secretly own different sections behind identical transferable shares.

Store:

- Actual liquidity, immutable-current bounds/salt and fee checkpoints for core/upper/lower.
- Two **net shareholder-owned** idle balances.
- Explicit operation-local entrant funds, refunds and exit escrow.
- Immutable pool, target orientation, independent reference and risk configuration.
- Share supply, a common operation/callback guard and bounded-maintenance state.

Deployed token composition is derived from positions and current pool conditions. It is not a fixed stored reserve counter that must be manually updated on every outsider swap.

### One accounting partition

Use net-owned equity throughout. Entrant funds, unpaid refunds and exit escrow are excluded before calculating shareholder value. Do not deduct an excluded liability again.

Collected fees move into owned idle and leave the uncollected-fee term. Never count them twice. The first release has no vault performance/entry/exit/keeper fee or debt payable. Pool LP/protocol trading fees remain real execution costs. This is a proposed new-family fee policy; existing registry/wrapper fee defaults must not silently add another charge.

### Donations and empty-state surplus

At positive supply, donations observed at a clean checkpoint are common old equity, never an authorized caller contribution. Measure an authorized pull by its own delta. Pool fee-growth donations are real assets too; the rounding/inflation policy must handle them rather than pretending they are not present.

Simplify empty-state handling: before bootstrap, require no old shareholder positions/escrows, and transfer pre-existing unowned token surplus to an immutable deployment-designated recipient. This cleanup is permissionless but may send only empty-state unowned surplus to that fixed recipient. It is blocked while busy or while shareholder equity exists; it is not an owner's discretionary withdrawal method.

Do **not** carry that surplus as a senior claim against the subsequent live vault. Cleanup failure prevents bootstrap rather than reducing the new seed's equity.

Fix the donation observation point before an ownership cut. Unexpected positive/negative deltas during the locked operation must be attributable under the same partition or cause atomic rejection; they are not automatically entrant credit or a new recipient entitlement.

## 3. Reference valuation, full credit and share issuance

### Reference unit and position valuation

Use a common high-precision accounting unit:

```text
W = 10^36 accounting units per whole target token
P = independent reference price in whole token1 per whole token0
```

Convert P to the raw token1-atoms/token0-atom ratio using both decimals before using Q96 range math. All implementation operations need checked full-precision evaluation and documented error intervals; these explanatory formulas are not permission to use floating arithmetic.

For liquidity L, square-root bounds a,b and raw-unit reference price p:

```text
zP = clamp(sqrt(p), a, b)
x0_ref = L * (1/zP - 1/b)
x1_ref = L * (zP - a)
```

Convert these two reference amounts into W target units. For idle and already accrued fee amounts, convert the actual token amounts directly.

```text
N(book;P) =
    reference value of net-owned idle and uncollected fees
  + sum(reference value of each owned L/range evaluated at P)
```

Reference composition is a valuation basis for an LP claim. It is **not** the quantity presently obtainable from that claim. Actual additions/removals always use live pool math.

Do not evaluate principal at current slot0 and merely multiply its opposing amount by an independent price while claiming spot-independent issuance.

### Exact entrant partition and ownership cut

For each token i, using actual settled amounts:

```text
availableEntrant_i =
    authorizedReceived_i + entrantSwapReceived_i - entrantSwapSpent_i

availableEntrant_i =
    principalFundingPaid_i + retainedEntrantIdle_i + refund_i
```

Old LP fees returned during a liquidity add are **not** entrant funds. The entrant pays full principal, even when the manager nets it against an old fee credit in the aggregate settlement delta.

After the entrant swap and final old-fee checkpoint, before adding entrant liquidity:

```text
S = old share supply
A = N(old equity including its entry-earned fees; frozen P)

E = {
    each deposit-funded deltaL at its fixed lower/upper bounds,
    retainedEntrantIdle0,
    retainedEntrantIdle1
}
C = N(E; frozen P)
```

Refunds have already been excluded from retained idle. There is **no second subtraction of refunds** from C. Old ranges/liquidities are not removed or re-centered as part of entry.

Mint after placement and actual settlement:

```text
m = floor(S * C / A)
```

In integer implementation use conservative old-equity upper value A_hi and contribution lower value C_lo:

```text
m = floor(S * C_lo / A_hi)
```

For positive supply and nonpositive/invalid old equity, reject issuance; do not invoke bootstrap.

At fixed reference and ideal arithmetic:

```text
N_after = A + C
oldReferenceClaimAfter = S/(S+m) * (A+C) >= A
```

This is the chosen meaning of fair entry. It is not a guarantee that old actual token quantities, current market mark, or liquidation proceeds are unchanged.

Every retained core, wing and idle increment enters C. No limiting-token minimum silently donates overage. If a liquidity placement has lower reference value than its input tokens, C is the resulting lower value. Do not add that shortfall back or reimburse it from old equity.

Illustration, not a test:

```text
old supply 1000; old equity before entrant swap 1000
old LPs earn 2 during the swap
entrant spends 100; final retained contribution has reference value 97
A = 1002; C = 97
m = 1000 * 97 / 1002, before rounding
```

The entrant is credited for 97, not merely the core portion, not gross 100 and not 102 including old fees.

### Outlay, reference mark and actual composition are different

Expose both expected final credit C and reference-valued net outlay in the entry quote. Their difference is not assumed to be rounding.

Here is the exact continuous per-range comparison, expressed in raw token1-equivalent units with positive raw reference price p and live price q:

```text
zP = clamp(sqrt(p), a, b)
zq = clamp(sqrt(q), a, b)

G_j = actualPrincipalValueAtReference - referenceRangeValue
    = L_j * [p * (1/zq - 1/zP) + (zq - zP)]
    >= 0
```

For target token0 divide by p, then normalize both token decimals. Integer amounts introduce documented rounding bounds. If both prices are inside a range:

```text
G_j = L_j * (sqrt(q)-sqrt(p))^2 / sqrt(q)     in token1 units
```

This corrects the different linear formula in MiniMax's feedback. For example, L=1, sqrt bounds [1/2,2], p=1, q=9/4 gives reference value 1, actual tokens marked at p worth 7/6, and gap 1/6—not 2/3.

Because reference range value minimizes that range's token mark over possible pool compositions, the following conservative continuous bound holds for the same p,q:

```text
eta = max(q/p, p/q) - 1
0 <= G_j <= eta * referenceRangeValue_j
```

For q>p, integrate the LP relation dY=-price*dX: the gap is at most (q-p) times reference token0 holdings, which are part of reference value. For q<p use the symmetric token1 argument. Clipping at range boundaries preserves the bound. Sum per range and include the numerical error allowance.

**Domain:** this is a conditional spot/reference composition bound at a validated state, not a universal market/liquidation bound. Enforce deviation after final settlement as well as before/after the entrant swap. Outside the gate, no small-gap claim is made.

Let M(book;q,P) be the actual removable token amounts valued at P. The conservation pair is:

```text
N_after = A + C
M_after = M_old_at_the_same_cut + M(E;q,P)
M(book;q,P) = N(book;P) + sum(G_j)
```

All are subject to documented integer quantum. Token-funding conservation is the separate exact tray identity above. Additions round funding up and removals round down, so actual principal paid may exceed immediately removable principal by the measured funding quantum.

The entrant's difference between retained token outlay and final C is a reference-valued allocation discount/cost, not a loss top-up owed by old holders. Entry execution and LP asset risk remain real. **Even at q=p, no external buyer may exist for a full target-only exit.** The composition bound does not guarantee a sale price or make getRate a safe oracle.

## 4. Deposit from start to finish

1. **Validate.** Check initialization, enabled inbound route, recipient, deadline, nonzero input and vault lock. Require the manager locked before the public call. Validate and freeze one independent price/reference round, freshness/error/deviation limits and cumulative entry capacity.
2. **Checkpoint incumbents.** Collect old fees and recognize donations without range closure, re-centering or communal placement. The old book is not mutated merely because a deposit arrived.
3. **Pull caller assets.** Use authenticated transfer/Permit2 and measure exact receipts into entrant credit. No arbitrary public pretransfer claim on unbooked vault balances.
4. **Approximate swap.** Target-only convenience entry initially swaps 50% of its input. A bounded caller/solver plan can supply another amount. Dual-token entry can skip it. The percentage decides execution, not share value.
5. **Execute only entrant funds.** Use the configured pool, finite price limit and swap-output minimum; verify reference deviation before and after. Default requires full specified consumption or atomic revert. An explicit partial-fill plan keeps unused funds in entrant credit, for retention or refund.
6. **Finalize old fees.** Account all fees old liquidity earned during this swap before changing its liquidity. Old fee growth, separate principal/fee deltas and actual custody must reconcile. Donation-inflated growth is not cured by recomputing it; backed donations are old equity, never caller input.
7. **Deploy only entrant inventory.** Fund matched full-range core liquidity using live token amounts. Put excess token0/token1 into eligible upper/lower ranges. At unavailable, mixed, full or overly expensive ranges, retain overage as credited idle or refund it under the chosen plan. Do not overwrite a live range slot.
8. **Measure final increments.** For every add, separate full principal funding from old fee credit. Record actual deltaL at fixed bounds, retained idle and refunds. No communal cash completes a caller contribution.
9. **Settle and check.** Reconcile token trays/custody, reference-mark identity, final spot deviation, C and m. Enforce minimum shares, optional minimum credit and the protocol precision guard. Unexplained deltas revert.
10. **Commit ownership.** Merge E, mint m, pay only entrant refunds, emit actual contribution/reference identifiers and release the lock after final backing checks.

All failure is atomic. The contract's own authenticated callback may perform this ordered work during its own unlock. A foreign unlock does not authorize skipping a checkpoint or paying a quoted entitlement from local cash.

The first-release public routes use ordinary payer/allowance authorization. Existing contract-bytecode-only pretransfer checks are not payer authentication. Public pushed balances and SY internalBalance shortcuts are disabled unless replaced by an operation-bound authenticated receipt; internal engine consumption must identify the actual authorized holder/amount and cannot expose a public surplus flag.

## 5. Bootstrap, precision, empty and worthless states

- Cleanup empty-state unowned surplus before accepting the seed. No senior surplus liability carries into a positive-supply vault.
- Require valid reference, actual seed assets and meaningful real pool/core liquidity for the pair. Target-only seed needs executable external depth; otherwise supply both tokens.
- Value the **final** seed contribution C after its swap/placement:

```text
U = 10^18 raw shares per whole share
S_initial = floor(C * U / W)
require C >= W and S_initial >= U
```

- Initial accounting price is one whole target per whole share. This is an issuance convention, never an empty execution getRate.
- No permanent dead-share sink or fictional virtual asset is proposed.
- Precision policy proposed for validation: minimum ordinary mint of 10^12 raw share atoms, relative rounding-loss tolerance epsilon<=10^-12 plus a documented Q_W in W accounting units. Do not interpret the tolerance in raw token atoms.
- Use conservative intervals for A and C. A lower bound on the new reference claim, compared with the contribution upper bound, must satisfy the relative-plus-quantum loss rule. A victim choosing minShares=1 cannot waive that protocol rule.
- Seed/minimum sizes alone do not close donation inflation. Test tiny supply, huge donated NAV, repeated round trips and mixed-decimal valuation quantum.
- Later redemption can leave 0<S<U; canonical getRate is then unavailable. This is a real integration state, not just launch.
- Ordinary redemption whose actual token outputs are both zero reverts; preview reports matching dust/unavailable behavior. Do not burn a nonzero claim for zero merely because user minima are zero.
- Positive-supply zero/invalid NAV does not accept a new seed. No silent worthless-share retirement is included; transfer/aggregation remain possible, while any explicit abandonment design is separate work.
- Terminal redemption takes all real shareholder positions and owned idle, without fractional floors or a retained one-target-atom rule.

## 6. Withdrawal from start to finish

The in-kind primitive and normal target route use the same ownership slice:

```text
f = q / S
liquidityRemoved_j = floor(q * L_j / S)
idleRemoved_i = floor(q * ownedIdle_i / S)
```

For q=S, remove all real equity rather than repeating floors.

1. Authenticate holder/allowance, amount, recipient and deadline; apply common operation and manager guards. Disabling deposits does not disable exits.
2. Collect pre-exit fees without compounding/re-ranging. Fix the slice of each position and both idle balances. These fees are included once.
3. Burn/reserve q and segregate the slice inside the locked operation before recipient callbacks. No public economic view may observe a misleading supply/assets intermediate state.
4. Remove only the assigned liquidity. Use actual principal deltas; attribute collected fees separately. Never close everyone else's core to fund a target quote.
5. **In-kind:** transfer the two actual token outputs under per-token minima. No oracle, swap quote, opposing buyer or tick-walk dependency.
6. **Strict target:** place that slice in exit escrow and exact-input sell only its opposing amount with a finite limit. Remaining vault liquidity may fill it and earns fees for remaining holders.
7. Pay:

```text
actualTargetPaid =
    actualTargetRecoveredFromSlice + actualTargetReceivedFromSliceSale
```

8. Enforce the user's fixed minTargetOut and full opposing consumption. A short sale cannot be completed by selling communal opposing or topping up from communal cash.
9. Unsold opposing makes strict mode revert. A separately explicit residual-return mode, if exposed, returns both outputs and has its own preview; no silent retention or zero valuation of the exiter's residue.
10. Transfer, settle/reconcile and release the lock. Failure rolls back burn/removals/swaps. Reject zero-output ordinary burns.

The exit sale's fees on remaining vault LP belong to stayers. Its intended market trade can change their token mix; ownership/escrow attribution, not constant target balance, is the invariant.

**Last holder:** removing the last LP can remove the only buyer for opposing inventory. Target-only exit may fail even with correct accounting. The holder can instead take the actual two-token assets in kind. This promises neither a buyer nor transferability of an issuer-frozen token.

## 7. Fees, first wing creation, compounding and maintenance

One common share means core fees placed into a wing still belong to all shareholders in unchanged fractions. No separate section ownership is required.

### Lifecycle

- **Bootstrap:** derive the core and upper/lower range records from the valid reference, with outward tick alignment and a fixed wing gap wider than permitted live/reference deviation. Create/fund the first actual wing positions only from the seed's inventory. All seed funding is measured in final C; no incumbent equity exists to subsidize it.
- A zero-liquidity range record is not a fictitious funded LP. A later deposit may fund an already established eligible record, but cannot invent new live-spot bounds or overwrite an existing range.
- **Later creation/replacement:** a deterministic maintenance plan may initialize an empty slot or replace a converted/obsolete wing under reference, movement and epoch rules. Close and collect an old position before reusing the slot; never orphan fees.
- Range extreme/capacity/unavailable cases leave assets idle. Full credit is not a promise that every atom earns fees continuously.

### Collection versus placement

Pure collection can move actual owed fees into common idle without an oracle or range mutation. It does not create a new relative-value exchange.

**Every communal liquidity placement/reallocation**, including fee compounding into an unchanged wing, requires:

1. A fresh frozen independent reference and valid live/reference relationship.
2. Actual funding/removal amounts from live pool principal math.
3. Before/after value of the whole affected book at the SAME reference.
4. A debit of any reference-value loss from the cumulative maintenance budget.

No alternate compound/harvest entrypoint bypasses the controls. No-swap does not mean zero allocation cost.

Reinvest fee token0 into an eligible upper wing and fee token1 into an eligible lower wing. Keep them idle when eligibility/reference/budget fails. Recovered communal principal may be paired into the core by the deterministic maintenance plan. First-release maintenance performs no portfolio-funded swap.

### Explicit budget

At the first valid action in an epoch:

```text
epochBudget_W = beta_epoch * N(epochStartBook; epochStartReference)
```

This is an absolute amount in W target-accounting units fixed for that epoch, not a percentage recomputed upward after each deposit. Every action's loss is valued at its own single validated reference:

```text
loss_W = max(0, N_before(P_action) - N_after(P_action))
loss_W <= min(remainingEpochBudget_W, beta_action * N_before(P_action))
```

Loss consumes budget; gains and new deposits do not replenish it. On a withdrawal of q/S, reduce remaining budget by that same fraction; a terminal exit leaves zero. The current-equity per-action cap also prevents an old absolute allowance becoming an unlimited fraction of a much smaller book.

Require non-dust progress, reference-based movement threshold and at most one creation/replacement per slot per epoch. Caller minima can tighten, never loosen, protocol limits. No keeper bounty in the initial product.

During a reference outage, issuance and all communal placement/range replacement stop. Existing positions can remain converted/unrotated; collected fees stay idle. Proportional in-kind exit remains available. Do not force a sale/recenter at the attacker's live spot merely to keep the strategy visually active.

## 8. Quotes, getRate, SY, rate units and unsupported routes

### Actual-size preview

Simulate the actual withdrawal: collection, q/S removals, fees/rounding, post-removal pool state, opposing sale, price limit and residual policy.

For a small slice retain the remaining vault LP as swap depth. The current quote removes ALL owned liquidity, so dividing that result by S is not the new preview.

Report target output, opposing residual/completion, work and policy identifiers. A strict scalar preview returns the full strict-route output or reverts. It must not hide an incomplete sale.

### Canonical rate

Let dS=18, dT=target decimals, U=10^dS and T(q)=raw target output of the canonical strict exit:

```text
rate(q) =
    floor(T(q) * 10^dS * 10^18 / (q * 10^dT))

getRate() = rate(U)
```

**Units:** whole target tokens per whole share, multiplied by 10^18. No NAV clamp, full-supply average, cached substitution, smaller-quote extrapolation or synthetic zero/par.

The canonical route has immutable full-consumption and finite movement/work policy. User exits may be stricter. It does not need a healthy independent issuance oracle.

S<U, including zero supply, has no real one-whole-share slice: getRate reverts/unavailable. A separate initial issuance-price query is not relabeled getRate. Initial buffer binding under the legacy D60 empty-rate convention is not supported by this new canonical quote.

Generally T(q)/q differs from T(U)/U. Arbitrary-size previews quote their actual input.

### Three different rate contracts

For N_W total accounting NAV:

```text
normalizedNavRate =
    floor(N_W * 10^dS * 10^18 / (W * S_raw))

SY exchangeRate =
    floor(N_W * 10^dT * 10^18 / (W * S_raw))
```

The local SYUtils converts raw units as:

```text
targetRaw = floor(shareRaw * syExchangeRate / 10^18)
```

Therefore SY exchangeRate is a raw-share/raw-asset conversion rate, not the whole-token normalized NAV rate or the execution getRate.

Example: 18-decimal shares, 6-decimal target, one whole share worth one target in NAV:

```text
normalizedNavRate = 10^18
syExchangeRate = 10^6
SYUtils(shareRaw=10^18) returns 10^6 target atoms
```

Canonical getRate equals 10^18 only if the actual one-share exit also delivers 10^6 target atoms. SY assetInfo reports the target address and **target decimals**, not share decimals. NAV-based SY exchangeRate fails closed on invalid reference/zero supply; do not advertise/install the integration until this contract and its actual-proceeds redemption behavior are accepted and tested.

The existing generic StandardExchangeRateProviderFacet._normalise already uses whole-token normalization, out*10^(18+dS-dT)/shares, with ceil rounding. It does NOT have the 10^12 unit mismatch alleged in one advisory concern. Its **full-supply quote source/size** differs, and the old vault's raw V*1e18/S expression needs correction when decimals differ. Revalidate each adapter rather than rewriting a correct normalizer on that false premise.

### Guard and projection contract

Every public economic read, including live NAV/getRate/preview, quoteState and projected queries using a live baseline, requires:

```text
initialized && !vaultBusy && relevantManagerLocked
```

A projection blob cannot bypass those guards. Bind projected state to the vault, asset/pool configuration, schema and baseline; reject mismatches rather than returning an unrelated live rate. Internal calculations inside the vault's authenticated callback use its explicit operation state; no public-view exception is keyed merely to msg.sender.

Carry all relevant pool/tick overlays, range/idle/fee changes and supply through sequential projections. Actual stateful execution never trusts caller-provided book balances as settlement authority.

### Exact-output and held-share paths

First release supports exact input plus minimum output. Do not advertise arbitrary swap-dependent exact-output deposit/withdrawal routes or reuse their linear inversions. The old exact-output push-budget/refund helper path is not a supported new-family surface.

A later exact-output implementation is possible with a correct inverse or verified candidate, proper maximal-input bounds and explicit surplus/refund rules; it is not mathematically impossible. Keep any sizing search off-chain where practical.

SY wallet-held redemption uses the same engine. A vault-held/internal-balance path, if retained, needs operation-bound holder/amount authorization. Current LocalCreditLib checks only caller bytecode, and NativeStandardYieldTarget retains the original caller through its internal hook; neither proves a self-call or ownership. Do not preserve public consumption of anonymous held shares as an “already authenticated” path.

## 9. Gas, dust ticks and honest liveness

Distinguish three failure classes:

| Surface | Work/depth dependency |
| --- | --- |
| Reference-valued dual-token entry | Fixed-position arithmetic; actual liquidity modifications/settlement still cost gas |
| Default target-only entry execution | One specified real swap; it need not first execute a view quote walker or iterative zap solver |
| Swap-entry preview | May simulate the specified swap and exhaust its own work budget |
| Target exit execution | Actual swap gas and available depth inside its limit; no sale-quote walker is inherently required before swapping |
| Target-exit preview/getRate | Faithful post-removal simulation can hit quote work or market limits |
| In-kind exit | Position removal/transfers, not a sale walker or opposing buyer |

Three positions do not imply cheap arbitrary swaps. One share does not imply a universally short tick walk.

Never skip small-liquidity initialized ticks while promising exact parity. A price-distance restriction by itself does not prove a cheap traversal when spacing/density are unspecified.

Deploy-time policy must select tick spacing, maximum canonical tick/price movement and work budget together. Verify feasibility over **all relevant initialized boundaries and empty bitmap steps** in the intended finite interval, not merely a full-domain empty-word heuristic; reject infeasible configurations. Then measure actual full transactions and consumer call graphs. This is a required future validation, not a numerical gas result from this council.

Keep work exhaustion distinct from market-limited incomplete fill. Strict target quotes/routes fail honestly; in-kind does not depend on either sale failure class. Underlying token/manager execution failure remains possible.

## 10. Independent reference and failure policy

Deployment requires a qualified pair/chain source with explicit ratio direction, decimals, timestamps/round identity, max age, uncertainty/confidence, cross-feed skew and relevant outage/sequencer rules. Qualified independent token feeds can form a cross-price. A TWAP name alone does not establish independence or economic manipulation resistance.

Do not use own-pool spot/depth, own getRate, an entrant's self-selected execution price or a circular adapter as the issuance reference.

Use the same validated snapshot throughout each operation. Check deviation at final settled state, not only before the swap. Cap cumulative accepted entry credit per reference interval; withdrawals do not restore capacity.

That cap is griefable: an attacker can consume the interval allowance with its own deposits and block other entries until reset. The owner chooses this entry-liveness versus stale-reference-exposure tradeoff. It is not proof that an oracle is correct.

On invalid/stale reference, reject issuance and every communal allocation/re-range. Pure collection and in-kind exit remain. Target execution quotes can remain available if their own pool/state/policy conditions hold.

No same-instance switch to an unpriced ownership rule on oracle failure. No preferred full-credit launch for a pair whose reference has not been qualified.

## 11. Liquidity use and manager integration

An accurate getRate is still a live execution quote. A pool multiplying its held shares by it has not executed that conversion. Redeeming a different output leg at actual size does not validate every rated reserve that informed its price.

### Initial listing

Trade the actual ERC20 as a distinct asset in an ordinary price-discovering pool. Users buy shares carrying inventory/fee/liquidity risk, not a target-token peg.

### Advanced integrations, separately gated

- **NAV-rated:** a separately named adapter uses independent accounting NAV with freshness/exposure/size controls. It is not canonical getRate and does not guarantee liquidation.
- **Execution-backed:** redeem the relevant actual-size shares and settle target proceeds, with no other manipulated unredeemed-rate input in the trade.
- **Legacy generic adapter:** its full-supply preview is not a transparent forwarding of canonical getRate. Explicitly choose/rewrite and validate its intended source, quote size, rounding and failure contract.

Same-manager nested redemption during a foreign unlock is unsupported. A router may complete the vault's own manager session and later open a separate outer session **sequentially within one atomic transaction**; this is not inherently two transactions. Such a router must be separately specified and validated. It does not make current hooks that expect nested calls automatically compatible.

No raw-getRate parity/buffer registration is approved simply because supply currently exceeds one share. The rate can later revert on low supply/work/depth, freeze a fail-closed consumer or be manipulated while available. Initial unsupported integrations include fresh zero-supply binding, arbitrary raw-rate parity, nested same-manager buffering and exact-output-dependent consumers.

## 12. Explicit changes from earlier expectations

These are recommendations for owner acceptance, not retroactive edits to historical rulings.

| Earlier expectation | Recommended change | Consequence |
| --- | --- | --- |
| No independent price / whole-book zap-out issuance / settled counter | Independent reference-evaluated LP NAV for issuance | Oracle trust and pair-eligibility restriction |
| Full retained imbalance without a valuation policy | Credit all final retained increments at the selected reference | Net reference credit, not guaranteed gross input or exit value |
| getRate as requested one-share exit | Preserve its semantics; correct current scaled-whole-book implementation | Rate remains live and potentially unavailable/manipulable |
| Empty rate=1e18 and D60 fresh-buffer binding | No synthetic executable quote at S<U; separate issuance convention | No legacy zero-supply rate binding for this family |
| Target-only exit always preserved, including historical APEX-026/SEC-10 posture | Explicit in-kind route is the quote-independent preservation path | Strict target conversion and rate may fail; owner must accept this narrowed guarantee |
| Target-decimal shares | New 18-decimal shares with explicit rate/SY scaling | New instances and integration revalidation, not an in-place denomination change |
| Exact-output and push-budget compatibility | Exact-input first release; no anonymous public pretransfer/internal balance | Some routers/hooks remain ineligible |
| Sleeve O5 and local one-native-unit floor O7 | No fixed-price cash facility or mandatory target atom; idle is ordinary equity | No cash-only foreign-unlock exit promise |
| O1/O3 zero-supply residual/first-minter benefit | Clean empty unowned surplus to fixed recipient before seed | Explicit new surplus policy; no senior live-vault claim |
| Portfolio-funded permissionless rebalance | Remove swap rebalance; budget every communal allocation | Less aggressive core optimization, safer initial surface |
| Live-spot wing creation/recentering | Reference-derived bootstrap bounds and epoch-gated lifecycle | Idle/parked assets during ineligibility or outage |
| No-swap compounding assumed costless | Same reference/cumulative-loss control as all other placements | Fees may wait idle |
| Shares treated as raw target through any rate provider | Distinct-asset listing first; advanced integrations separately gated | Original unrestricted parity-composability ambition is not met |

## 13. Validation gates and audit implications

**No audit finding is closed.** The source still implements the old machine. This report proposes changes, not passing evidence.

| Finding | Structural change proposed | Evidence still required |
| --- | --- | --- |
| APEX-012 | No live liquidation issuance/target liability; independent range valuation; final contribution; guards | Settled/unsettled JIT, spot/reference and full attacker/holder ledgers |
| APEX-024 | Actual proportional removal; only exit escrow sold; no top-up | Majority/terminal/sandwich cases with stayer ownership attribution |
| APEX-025 | No portfolio-funded swap rebalance; every placement budgeted | Churn, timing, epoch, large-withdrawal and compound-placement attacks |
| APEX-026 | In-kind/dual-token accounting avoids sale walker; quotes fail truthfully | Real dust/spacing/gas cases; in-kind liveness; target/rate failures remain disclosed |
| APEX-040 | Precision, donation partition, seed/rounding guards | Donation/front-run bootstrap, one-atom mints, repeat rounding and rebootstrap |

Use real manager, manager-registry package deployment, facets, reference adapter and direct integrations; no SUT mocks. A future authorized implementation must build changed production artifacts before tests.

Required acceptance scope:

1. Exact token tray conservation and single refund/liability exclusion; partial fills, netted fee/principal deltas and custody checks.
2. Reference identity N_after=A+C within its numerical interval, incumbent reference preservation and credit of every core/wing/idle component.
3. Actual-token identity and clamped composition-gap bounds; reference/live prices straddling each boundary in both directions, at deviation edges and both target orientations.
4. Old fees before entry and during entrant swap, actual donated fee growth, collect/add/remove rounding; no fee rebate masquerading as caller principal.
5. All share/target decimal combinations and signed-delta/overflow limits; SY raw conversion and adapter normalization examples.
6. Actual-size preview/stateful parity, remaining-owned-liquidity overlays, projected sequential state, limits, residuals and every unsupported-selector path.
7. Small, majority and complete exits, no external buyer, zero-output dust, S<U, S=0, invalid/zero NAV and terminal/empty surplus cleanup.
8. Parameterized fee/depth/position-mix/entry-size/reference-update matrix for manipulation/deposit/unwind/exit, settled/unsettled JIT and self-deal attempts.
9. Close attacker LPs and debts and count both wallet tokens, borrow costs and all inventory once at a common independent comparison price. Compare with matched controls; report gas separately.
10. Publish profitable incumbent-dilution/misattribution cases and their parameters; these fail release beyond the documented arithmetic quantum. Genuine market arbitrage and oracle-latency exposure must be distinguished, quantified and explicitly accepted, not mislabeled proof of safe accounting.
11. Stale/cross-feed/skew/outage/reference-update/deviation-edge and interval-cap exhaustion/griefing; no same-pool fallback.
12. Compound into unchanged ranges as well as create/replace; cumulative budget, gains not replenishing, withdrawal shrinkage, current-equity cap, epoch boundaries and no-progress/dust calls.
13. Real initialized dust ticks/empty words, intended finite-limit work feasibility, actual swap out-of-gas/depth, in-kind independent of quote failures, and consumer fail-closed versus zero-price behavior.
14. Facet-wide/state/read-only reentrancy, malicious callback/unauthorized held-share consumption, foreign unlock, unexpected token deltas, Permit2/allowances and registry inbound-disable with exits preserved.
15. Real price-discovering share trading, negative raw-getRate parity tests, separately qualified NAV and sequential execution-backed integrations. Inspect every rate input, not just the final output redemption.
16. Proxy/package selector surface, immutable configuration, full transaction gas receipts, repeated integration quotes and deployed bytecode sizes. No viaIR and no fictitious raised harness cap.

Equal gross deposits need not mint equal shares if real execution produces different contributed assets. Hold final assets/reference constant or account for the difference and JIT provider inventory. Likewise, intended exit trades need not leave stayer token composition constant.

## 14. Alternatives, remaining decisions and limits

### No-reference alternative

If arbitrary-pair eligibility is more important, use a separately specified proportional portfolio join. After fee collection match the vector:

```text
(L_core, L_upper, L_lower, ownedIdle0, ownedIdle1)
```

For shares m, fund each coordinate's rounded-up m/S addition at unchanged ranges; verify actual funding on chain. An off-chain solver/router can size its swap, avoiding iterative sizing inside the transaction. Refund unmatched tokens. Matching only aggregate token balances and then changing range allocation is not the same position-vector guarantee.

This sacrifices retaining all imbalance as common shares. It is the preferred alternative to a self-executed-price denominator, not a proof that every oracle-free AMM design is impossible.

### Separate section claims

Multiple real ERC20/ERC1155/NFT section claims can credit destination-specific exposure without collapsing every contribution into one common share. Cross-section compounding must preserve source ownership. Internal section books alone do not solve fungible-share valuation. A fixed-basket wrapper restores proportional-entry constraints; a changing basket requires valuation/rebalance pricing.

Use this design when investors deliberately choose range exposure, not as hidden bookkeeping behind the common fungible product.

### Decisions genuinely left to the owner/deployer

- Launch chain/pair and qualified reference, scaling/confidence/freshness and adverse-selection acceptance.
- Entry-deviation/cumulative-credit caps and accepted griefing/liveness exposure.
- Actual seed/pool liquidity; W-unit numerical quantum and verified rounding policy.
- Tick spacing, finite canonical movement/work limits and receipt-level feasibility.
- Reference wing gap, creation/replacement trigger/epoch and beta budgets.
- Fixed empty-state surplus recipient.
- Acceptance of in-kind preservation, unavailable empty/sub-one-share rate, independent share denomination, no initial exact-output or foreign-unlock buffering, no portfolio-funded swap rebalance and restricted initial listing.

These require market data and risk acceptance not supplied here. If no independent reference is available, do not launch the preferred full-credit product with a circular substitute.

### Limitations

- Static source analysis, member reasoning and coordinator exact arithmetic, not a security proof or runtime test.
- No pair-specific feed, chain deployment inventory, launch parameters or full consumer matrix verified.
- Existing deployment immutability/recovery is separate; no migration or upgrade is authorized.
- Shared live sources, not an atomic Git snapshot.
- Original and advisory disagreements and corrected claims remain in the artifacts; no missing participant was treated as agreement.

## Evidence, coverage and publication

Key local evidence actually examined in this run:

| Source | Classification / coverage |
| --- | --- |
| CLAUDE.md and required V4 Wings sources | Source observation; complete money/accounting/inventory/geometry/harvest/rate/quote surfaces covered across originals and coordinator checks |
| docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md, APEX-012/024/025/026/040 | Source observation of reported audit/PoC results; no rerun |
| LiquidationQuote._removeOwned/_sell/_next | Coordinator source check: all-owned removal and exact boundary processing need new slice semantics |
| PoolManager.modifyLiquidity and IPoolManager documentation | Coordinator source check: combined principal/fee delta, separately returned fee information and donation warning |
| StandardExchangeRateProviderFacet._getRate/_normalise | Source observation: full-supply preview, correct whole-token normalization, ceil rounding |
| Direct CP/weighted rate consumers and shared LegLib | Partially examined: non-redemption reserve valuation established, not exhaustive consumer review |
| SYUtils, Wings SYTarget, NativeStandardYieldTarget and LocalCreditLib | Coordinator source check: raw SY units, target/share metadata mismatch after decimal change, held-share authorization context |
| Existing production-first Wings base | Source examined by Astra; not executed |
| Historical PRDs/records/prior council | Differing partial member coverage; current changes named explicitly, not treated as immutable authority |
| Official Uniswap flash-accounting page in Astra original | Public primary source fetched by that member; provider searches/PDF open yielded no usable text and were not relied on |
| Composition-gap and normalization examples | Coordinator inference/exact arithmetic only; not a pool simulation |

The LSP reference lookup for the SY hook timed out; actual source was read directly. No diagnostic/build/test pass is claimed.

Publication: this new research root only. No existing PRD, audit, tracker or implementation file was edited. [Brief](brief.md), [run record](RUN.md), four originals, immutable [draft](coordinator/draft.md), all feedback and [resolution](coordinator/resolution.md) are retained. Three initial members used their ordinary writer before the patch-only clarification; that disclosed method deviation is not rewritten out of the record. Their advisory feedback was returned inline and preserved by the coordinator with apply_patch. Astra and coordinator artifacts used apply_patch.

No project Git actions. No model work was repeated for publication. This report and its parameter/validation recommendations do not authorize implementation.
