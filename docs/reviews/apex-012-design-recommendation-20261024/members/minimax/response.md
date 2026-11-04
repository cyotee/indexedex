# Member response

## Identity

- Run ID: apex-012-design-recommendation-20261024
- Member label: minimax
- Profile: research
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-design-recommendation-20261024/members/minimax/response.md
- Requested role: council-member
- Requested model and reasoning: minimax/MiniMax-M3
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Recommend one vault design that (1) holds a reserve exposed to trading volume that earns swap fees, and (2) lets a holder be priced and exited into one target token, where the price is a view returning one `uint256` at 18 decimals that a rate provider can consume. Deposit, redeem, and the rate must follow one rule. The recommendation must also name what the design refuses to do.

Constraints I treated as fixed (from the brief):

- A live same-pool liquidation quote is not the share price; temporary liquidity and an in-transaction price move must not mint shares or move the rate.
- No split: one price for the rate, a different zap-out for redemption.
- A single-sided target range is not a fee-earning reserve by itself.
- The current Wings deposit does not sell target for the other token; any conversion in a future design must be justified by the goals.
- `getRate` may not execute a sale, and may not preview a sale through current depth.
- Deposit, exit, and rate must be stated as one rule, with the value that is absent from the rate until a real conversion settles.
- One mechanism for V3 and V4 unless a protocol difference forces a split, and any split must be named.

The old PRD (`APEX-2026-012-APPORTIONED-RESERVE-PRD.md`) is the design under reconsideration, not a binding spec.

## Evidence

Admitted sources, read in full:

- `docs/reviews/apex-012-deposit-process-20261024/REMEDIATION_PRD.md`. Establishes that the "deposit sells target" premise is false in code: that sentence is not in `_deposit`; the real order is pull target, harvest, read `Quote.quote`, compute shares, credit gross target, mint, place; an ordinary harvest never swaps; `_swapDeficit` sells the other token for target and only a redeem reaches it. It also records four member positions on entry (gift of the pre-existing other token versus proportional addition) and three owner options, none selected. My recommendation has to pick one of those options and defend it.
- `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`. Supplies the reworked accounting: a share is a fraction of the whole position (core plus wings), `getRate` is `settledTarget * 1e18 / supply`, entry converts only when the position is already two-sided, exit removes the slice and sells only that slice's other token, and the remaining position is intended to absorb the fill. It also fixes the boundaries I must respect: no oracle, no sale of the other token outside the acting holder's own entry or exit, no new range on deposit, rebalance out of scope, a new V3 Upper Lower Wings family required (no V3 Wings source exists in this repository), and 024/025/026/040 left open.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`. The money path today: `_deposit` calls `Quote.quote(Common.quoteRequest())` and feeds it to `Accounting.issue`; `_redeem` computes `Accounting.entitlement` from the same quote and then re-quotes for the `HolderValueLoss` check; `_swapDeficit` sells the entire opposing local balance (`opposing = state.target0 ? state.local1 : state.local0`), which is the whole-book sale shape that 024 flags; `_fund` closes slots to raise target; `_harvest` and `_place` both return early when `state.manager.isUnlocked()`, so any conversion and placement in V4 must be composed inside one unlock; `Harvest.placement` and `Common.Operation`/`Kind.Modify`/`Kind.Swap` show the existing plumbing for routing idle balances into slots and for swapping in-pool; `preview` and `requiredInput` also read the quote.
- `.omo/ulw-research/20261023-171500/SYNTHESIS.md`. No inspected production Uniswap vault both earns swap fees and exposes a spot-free one-token rate; Wings, Gamma, Arrakis, Charm, Steer, and Visor all read pool spot. The pattern that survives is stored single-token accounting, with the other token kept out of the rate until a separate conversion credits target. The GUni cached-poke oracle is noted as precedent for staleness, not as the recommendation. The Visor and Gamma postmortems are the excluded class: a mint priced off the pool's current price.

One orientation grep outside the admitted set (symbol index only, no file bodies read): `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` exists, and `IRateProvider` is already imported by `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol`. That is the landing surface for a rate provider, and it expects a 1e18-scaled target-denominated number.

The structural conclusion the evidence forces: a fee-earning reserve is two-sided, so the position's value in target terms depends on the other token, and no store of target tokens alone prices that position. Every design that avoids a live price therefore has to declare which part of the position the rate covers.

## Assumptions

- The vault accepts and pays one target token, and the paired token is a normal volatile asset, so the other side of the position is material in value.
- The vault trades in the same pool it provides liquidity to, and its liquidity is small relative to pool depth; otherwise an in-pool conversion has unbounded impact and no design here is safe.
- A rate consumer (the existing Balancer-style `IRateProvider` surface) treats the rate as a conservative valuation it may haircut, not as an exact net asset value.
- The owner accepts a rate that is a settled, conservative figure rather than an exact mark. This is the ruling I need, and I flag it below as an open decision.
- No keeper acts in the money path; rebalance stays out of scope, per the PRD.
- The V3 Upper Lower Wings family is new work. This design does not convert V3 FullSpread and does not touch deployed vaults.

## Coverage

I read the brief, both admitted PRDs, the V4 Wings money library, and the ULW synthesis, then worked the design by hand: I traced the deposit, redeem, and rate rules against the position-fraction accounting, checked the entry rules against the four positions in the deposit-process council, and worked through what happens to the rate when an outsider swaps the pool or inserts liquidity. I did not read peer responses, run Forge, change any contract, search the public web, or implement anything.

## Conclusions

One recommendation, in the order the brief asks for.

### The position

One Uniswap position per vault, structured as a core range with an upper and a lower wing, sized so the position stays in range across the intended band. The core is two-sided while price is inside it, so the reserve is continuously exposed to swap volume and earns swap fees in both pool tokens. This is the fee engine and it is deliberately two-sided: a single-sided target range only earns while price is inside it and then it holds the other token, so it cannot be the reserve on its own. The vault's assets are exactly that position plus idle balances of the two tokens. Shares are a fraction of the whole position, core and wings together, not of a single slot.

### The deposit

Target only, no price, no quote. The vault pulls the target, adds liquidity to the existing ranges (it never opens a new range), and mints shares in proportion to the added target measured against the target leg of the position that already exists. The new holder's slice of the pre-existing other token is therefore exactly the other token their own add bought, and nothing is gifted to them.

That proportionality is only achievable if the added pair matches the composition of the position it joins. An in-range add requires both tokens, so when the vault holds no idle other token it must convert part of the deposit in the same pool, with a bounded minimum on what it receives. This is the conversion the goals require, and it is not the rejected premise: the rejected premise was that the deposit sells target *to price the entry*. Here the conversion exists only to make the add proportional, and the share count is computed from token amounts, not from a price. My choice among the three owner options is the third (conversion plus proportional addition), because the first two either gift the pre-existing other token or shut the vault to new deposits whenever the position is two-sided, which is the normal state.

### The exit

The holder's slice is removed across core and wings. Only that slice's other token is sold, in the same pool, sized to the slice. The holder is paid the target removed plus the target the swap delivered, and nothing else. The remaining position is intended to absorb the fill and to keep the fee. This is deliberately not the current behavior: `_swapDeficit` sells the entire opposing balance, which is the 024 shape, and `_fund` closes whole slots to raise target, which is a book liquidation rather than a slice removal.

The holder's protection is a minimum target out. If the swap cannot deliver it, the exit reverts and no shares are burned. The design refuses to promise a constant target payout, because that promise is only obtainable from a book quote.

### The rate

`getRate() = settledTarget * 1e18 / supply`, where `settledTarget` is a stored counter of target tokens the vault has actually received and not yet paid out: deposits in, target harvested in, target realized from the vault's own conversions, minus target paid to redeemers. It is a view over stored state. It does not read `slot0`, does not call the liquidation quote, does not simulate a sale, and does not preview depth.

What is absent from the rate until a real conversion settles: the target-equivalent value of the position's other token, the unrealized fee accrual on that token, and the drift between the position's current composition and the composition the counter last saw. The rate is therefore a conservative floor on the position's target value, not an exact mark. That is the deliberate cost of refusing every price source the brief bans.

### The refused behavior

The design refuses to publish a price it cannot compute without trusting a live quote, which means it refuses to price the other token at all until the vault itself converts it into target. It also refuses to let temporary liquidity or an in-transaction price move mint shares, since the mint is computed from token amounts; to let an outside swap move the rate, since the rate moves only when target crosses the vault's boundary in a vault operation; to sell the position's other token outside the acting holder's own entry or exit, so no keeper rebalance and no harvest-time liquidation of principal; to open a new range on a deposit; to treat a donation as inventory; and to guarantee a fixed target payout on exit.

### The cost

The rate under-reports the position for as long as the other leg is material, so a rate consumer must haircut it, and the vault's shares look cheaper than the position is. The rate converges toward the true position value only as holders exit and the other leg is converted, so a vault with no exits has a flat rate that does not track its position. Every deposit that needs an add-side conversion, and every exit, trades against the vault's own pool: the depositor and the redeemer pay the pool's fee and price impact, and the remaining holders take the fill, which is intended but is a real transfer from the redeemer to the pool. Entry conversion gives the deposit an extra manipulation surface, bounded by the minimum received and by the vault's share of pool depth. The implementation cost is not symmetric either: the V4 family needs the quote removed from the money path and a new settled-target counter, and the V3 Upper Lower Wings family does not exist and would have to be built to the same accounting.

### One rule, stated once

A share is a fraction of the position. Deposit and redeem allocate that fraction, and the rate is the target-denominated form of the same fraction: the target the vault has actually settled per share. There is no second price and no zap-out, because there is no price at all in the money path.

### Rejected alternatives, one sentence each

- Keep the liquidation quote as the share price and add a settled counter beside it, because that is the banned split and it leaves the manipulable number in the product.
- Mark the other token with a TWAP or a Chainlink price, because the rate would then be a price the vault cannot settle against, and the rate and the exit would be priced by two different mechanisms.
- Restructure the reserve as a single-sided target range with a passive fee claim, because a one-sided range earns only while price is inside it and the reserve would stop earning exactly when it is not needed.
- Move the fee engine into a separate protocol position so the vault holds only target, because the fee engine would no longer be backed by the vault's own reserve and the claim would stop being a claim on the earning position.
- Mint at the settled rate instead of at the position fraction, because a rate-denominated mint silently gifts the depositor a slice of the pre-existing other token.
- Let a keeper rebalance and convert the other token on a schedule, because it needs a price to decide when to trade and adds a second accounting for realized PnL, and rebalance is out of scope.
- Make the deposit a sale of target for the other token as the pricing step, because that makes the entry price-dependent and re-creates the rejected quote in the entry path.

### V3 and V4: one mechanism, no split

The accounting is identical on V3 and V4, and I do not split it. The protocol differences are execution plumbing, not accounting:

- V4 composes everything inside one `PoolManager` unlock, so a conversion and the liquidity modification must be in the same unlock; the existing code already reflects that, since `_harvest` and `_place` both bail out while `state.manager.isUnlocked()` is true. On V3 the same sequence is `swap` plus `mint`/`burn`/`collect` with no unlock requirement.
- Fee realization differs: V3 accumulates fee growth per position and pays it out on `collect`, while V4 realizes fees through the `modifyLiquidity` delta set. The settled-target counter must therefore be credited at different points in the two protocols.
- V3 needs `collect` before `burn` to avoid burning accrued fees, and V4 does not have that ordering constraint in the same shape.

Neither difference changes what a share is or what the rate reports, so the rule stays single.

### Two rulings I need from the owner

1. Whether the rate may be a conservative settled-target floor rather than an exact mark. I recommend yes, and it is the price of every constraint the brief lists. If the answer is no, the only remaining door is a mark, and that door should be opened deliberately or not at all.
2. Whether the deposit may convert part of the target in-pool to make the add proportional. I recommend yes, with a bounded minimum received, and I note that this is new behavior relative to the current deposit, which does not sell target.

## Limits

Static reading and design work only. No Forge build, no test, no implementation, and no contract change; the numbers in the deposit and exit rules are illustrative and unverified by simulation. I did not read peer responses, and I did not search public sources, so the protocol differences in the V3 and V4 sections are stated from the admitted sources and from the V4 library, not from a V3 Wings implementation, which does not exist in this repository. I did not verify the tick-level mechanics of a proportional add against either protocol's position math. The claim that the settled-target rate is a conservative floor rests on the position's other leg being worth something; that is a property of the position, not something the code enforces, and it is the point where a future review should look hardest.
