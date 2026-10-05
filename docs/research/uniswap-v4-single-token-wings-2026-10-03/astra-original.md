# Astra — scalar routes and one-sided wings: original

**2026-10-03.** Retained Astra session; earlier discussion remains in history, but no prior or new peer artifacts were read for this question. Research only. No execution, implementation, gas measurement or consensus claim.

## 1. Recommendation and governing distinction

**Scalar entry and exit can be search-free, but wings solve placement, not fungible valuation.** If incumbents own both tokens, depositing token0 in a token0-only range still gives `C1=0`; the current positive-two-leg min-ratio formula mints zero. Changing ticks cannot repair that ownership equation.

Ranked investigation:

1. **Controlled valuation admission, local-inventory-first; separately managed core plus optional wings.** A direct, oracle-referenced share rule admits either token synchronously. Idle redemption removes a predetermined proportional slice and forward-swaps its other-token entitlement; blocked redemption uses a conservatively charged local settlement. No user supplies an opposite asset. This best separates scalar service from position management. Adoption is conditional on approving and validating oracle, spread and inventory-risk policy—not an assertion that current policy permits NAV.
2. **The same valuation with immediate one-sided wing placement.** Productive placement becomes possible without a composition swap, but introduces rounding attribution, more state and boundary-dependent admission. It does not improve the valuation problem. Prefer rank 1's deferred placement before considering this optimization.
3. **Explicit internal invariant market plus bounded wing management.** Existing F1/F2 provide direct scalar arithmetic and local-cover settlement. This avoids an admission oracle but exposes holders to book-price/external-price arbitrage; adding wings increases inventory-price divergence. It needs an economic decision, not merely extending the blocked branch to idle.
4. **Restricted analytic external conversion.** Useful additional domain, not a complete scalar product: supply one direct candidate and verify exact post-swap alignment, rejecting without refinement. One-step `SwapMath` evaluates an already chosen amount; it does not supply that amount.

Separately owned wing receipts or epochs can avoid immediate common-book valuation, but fail synchronous fungibility unless a market-maker finances immediate conversion into the common share. That market-maker still needs pricing/capital. Raw liquidity units from different ranges are not economically interchangeable. Basket-only and asynchronous-only products are not recommended.

Replacing binary search with secant/Newton/interpolation changes the algorithm, not the sizing problem. The proposal below has no ordinary sizing probes; bounded position enumeration and one already-sized forward swap remain.

## 2. Exact scalar accounting proposal

Notation: `H` = `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault`; `O` = `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook`. Suffixes concatenate literally.

Actual backing is

`B_i=F_i+Σ_j D_ij(q,l_j)+Σ_j E_ij`, with `E_ij=floor(l_j*ΔgrowthInside_ij/2^128)` using core checkpoint/wrap semantics.

F excludes caller credit and liabilities. Collection moves E→F once; principal remains at PoolManager, not local ERC20 custody. Let positive `p_i` be common-numeraire prices **per raw unit**, decimal-adjusted once; `V=Σp_i B_i`. Treat products as exact wide integers/rationals until specified rounding.

**Proposed admission controls:** fresh independently sourced reference prices, explicit maximum age/confidence and market-liquidity requirements; a fixed spot/reference deviation gate; fixed directional entry/blocked-exit charges `f_i,g_i<W=10^18`; and terminal inventory-concentration limits. These are new owner decisions. A TWAP-only variant is possible but has stale-price and prolonged-manipulation risk. Existing same-pool truncated TWAP is not independent evidence (`contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol:32–44,82–97`). No suitable production independent feed was established here.

**Deposit, either manager state:** freeze prices, policy and incumbent V before funding/collection. All c stays local:

```
n = floor(c*(W-f_i)/W)
m = floor(S*p_i*n/V)
B' = B+c*e_i; S'=S+m
```

`c-n` is a disclosed retained dilution/imbalance charge, not a second external token transfer. Require positive m, minShares, deadline and inventory-domain checks. Exact-share input is search-free:

`n_req=ceil(m_req*V/(S*p_i)); c_req=ceil(n_req*W/(W-f_i))`.

Mint exactly the requested shares on exact-output; retain rounding surplus. At fixed prices and no placement, `(V+p_i*c)/(S+m)≥V/S`. This proves valuation non-dilution **at that snapshot**, not market-value safety.

**Idle scalar redemption:** for known r shares, collect accrued fees, remove `l_j^-=floor(l_j*r/S)` for every position, and form

`A_i=floor(r*(F_i+ΣE_ij)/S)+Σ actualPrincipalProceeds_ij(l_j^-)`.

Swap the already known `A_other` once, quoted against the pool **after all removals**, and pay `A_out+actualSwapOutput`. Existing LP/protocol swap fees apply once. New fees on remaining positions belong to remaining holders. Retain and book terminal-limit unspent input under existing residual law; work-limit truncation away from the terminal limit reverts. No maintenance tail. No new idle exit surcharge is assumed.

**Blocked scalar redemption:** proposed replacement for F2 is

`y=floor(r*V*(W-g_i)/(S*p_i*W))`; require actual `F_i≥y`, positive payout and supply bounds. Never substitute `floor(r F_i/S)` for entitlement. Its local exact-output inverse is `r_req=ceil(y_req*S*p_i*W/(V*(W-g_i)))`, with exact requested payout and maxShares. This changes economics from current F2 explicitly. General idle exact-output redemption still has no adopted inverse; keep it invalid except the existing genuine one-leg linear domain. Keep the existing one-core-step direct token swap domain separately.

**Zero domains:** retain dual-funded F0 minimum/dead-sink issuance and residual-sink shares (current implementation plan `:43–56`). Nonzero S with V=0 rejects new issuance; it is not a new bootstrap. One-backed-leg deposits/withdrawals use the same valuation equations; admitting the other token is now explicitly valuation-priced, not an accidental free mint. No zero prices or gas-dependent fallback.

## 3. Wings: precise mechanics and bounded management

Let Q=2^96, q=current sqrt price, spacing s, `k=floor(tick/s)*s` using mathematical floor for negative ticks. Proposed deterministic gap g≥1 spacing and width w≥1 spacing:

* Token0 wing: lower `k+g*s`, upper `k+(g+w)*s`, entirely above q.
* Token1 wing: upper `k-g*s`, lower `k-(g+w)*s`, entirely below q.

Validate actual sqrt comparisons, usable tick bounds and positive width; never clamp into an in-range position. If a valid wing is unavailable, keep funds local. Boundary equality is economically one-sided but active-tick bookkeeping differs; strict separation avoids relying on equality.

For Q96 endpoints a<b and available one-token budget c:

```
token0: l = floor(c*floor(a*b/Q)/(b-a))
token1: l = floor(c*Q/(b-a))
```

These reproduce Crane `LiquidityAmounts.sol:19–44`. Add debt is source-exact `SqrtPriceMath.getAmount{0,1}Delta(a,b,l,true)`; removal proceeds use false (`:186–209,237–289`). Cap l arithmetically by representable liquidity, signed delta and remaining per-tick capacity. Verify debt≤budget once; failure leaves funds local, not a search for a better l. Residual c−debt stays booked.

**Hard cap: three owned positions**—one fixed full-usable-range core, one wing slot per orientation. Core remains double-sided away from extreme prices; its full range avoids repeated discretionary recentering. No per-user salt, range, NFT or linked list. Aggregate into an existing slot only when it remains validly one-sided. An occupied/in-range wing cannot receive unilateral additions; new inflows stay local until maintenance frees it. Slot salt is deterministic and fixed; changing ticks only after complete removal and fee settlement. Core position identity uses owner/ticks/salt, so historical zero-liquidity keys are not an iterable active inventory.

A token0 wing starts all token0, becomes mixed as price enters, and becomes token1 above its upper bound; token1 is symmetric. Conversion can reverse before withdrawal. Out-of-range capital earns no swap fees; entry into range is not guaranteed profit or completion.

**Consolidation:** one permissionless bounded call examines at most two wings, removes selected crossed/mixed wings completely, collects each fee once, then adds to the fixed core from available budgets. Use `getLiquidityForAmounts(q,coreLower,coreUpper,budget0,budget1)` once, settle rounded-up debts, retain limiting-leg excess. Being inside a wing does not give the core's required token ratio. If insufficiently funded, keep the proceeds local; do not force a swap or resize through probes. Remaining excess can later occupy a vacant correctly oriented wing. Holder-funded management costs and rounding accrue to then-current shareholders. Zero-improvement churn must not repeatedly burn dust; no caller reward, no donation-created slot and no forced per-deposit management.

Keep live sleeve p/default 20% and deadband, now against **aggregate** deployed principal. After collection, reserve `t_i=floor((D_i+F_i)*p/(W+p))`; deploy only `max(F_i-t_i,0)`. Recompute final D/F and bands including rounding; do not freeze a pre-placement D denominator. Deficient cover can require an explicitly sized removal; ordinary deposits need not repair it. Inventory/value concentration caps are static state-risk limits, not forbidden temporal turnover quotas; they nevertheless need approval.

## 4. Conservation and economic objections

For a no-swap placement with signed custody change dF:

`loss_i=D_i_before−D_i_after−dF_i≥0`; `B_i_after=B_i_before−loss_i`.

For the complete workflow add caller funding, subtract actual payouts/refunds, and include separately tracked swap deltas, position repricing and own fees. A rounding loss is not an owned residual. Deferred placement keeps deposit accounting simple. Immediate wing placement must deduct caller-attributable loss before mint and rederive the exact-share inverse; therefore rank 2 cannot blindly reuse rank 1's inverse.

The central attack is **cheap oracle admission followed by market-priced exit**. Independent p does not itself fix manipulation of `D(q)`: moving pool spot changes incumbent holdings and NAV. Narrow wings make the issue more acute. Gates and charges need adversarial calibration across the entire permitted spot interval; a 1 bp mint-floor bound is not a valuation-error bound. One possible conservative extension prices incumbent positions at an upper value envelope over the accepted price interval and payouts at a lower envelope. That needs separate integer derivation and cost/liveness evaluation, not silent adoption here.

Other attacks: stale feed arbitrage; capital supplied immediately before favorable fee/checkpoint events; keeper sandwiched removal/redeployment; crossing-and-reversing wings; dust forcing work; donation-induced inventory shifts; minimum supply inflation; callback/reentrancy and native-face double counting. A wing value cap bounds exposure but cannot guarantee keeper availability or prevent loss. Gate failure may reject deposits/blocked conversion; idle proportional liquidation should not be unnecessarily hostage to an unavailable admission oracle.

Rank 3's source CP mint uses `K=ceil√(Bin*Bother)`, `A=floor√((Bin+c)*Bother)`, `m=floor(S*(A−K)/K)`; its source inverse is direct. F2 uses `u=floor(Bout*r/S)`, `v=floor(Bother*r/S)`, `y=u+floor((Bout−u)*v/Bother)` when v>0. Both preserve a frozen-book invariant conservatively, but book ratio is not market price. An imbalance fee, external price gate, or explicit acceptance of paid arbitrage is still necessary economically. CP local cover can exhaust even idle; broad external exits restore liveness but expose the cross-market pricing difference. Wings do not remove it.

## 5. Autonomous Orbital/SY and remaining searches

Retain `exchangeIn(token,c,share,minShares,recipient,pretransferred,deadline)` and `exchangeIn(share,r,token,minOut,...)`. Native SY already delegates these scalar routes (`contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:20–76`). Transition snapshots must include all three positions/checkpoints, excluded credit, reference-price observation/version, fees, supply and manager state. The same operation at the same state must produce exactly identical integers.

Extend `quoteInputForExactShares(state,m)` to rank 1's direct inverse in both manager states; current source explicitly rejects idle (`HInQueryTarget.sol:22–32`). Orbital converts desired rated claim to shares with `sharesForNativeUp`, then calls that inverse once. Use exact-share execution where modeled; exact-input execution can mint extra shares and must project them honestly. Keep positive, meaningful inner minima, not `minOut=0`.

This eliminates `_faceForClaim` (`OExitQuoteLib.sol:347–374`) and `_invertBufferForEffective` (`OClaimLib.sol:250–275`) **for supported direct-inverse legs**. Eight interpolation attempts are not eight total probes. Reject zero-mint/zero-rated substitutions for face input (`:309`, ExitQuoteLib `:379–381`).

`OMath.sol:321–364` still searches the outer sphere split. To remove it requires an **explicit Orbital product change**: deterministic fixed sales, e.g. floor(c/3) to each other leg, execute two already-sized sphere swaps sequentially, then compute the proportional raw-reserve LP join from resulting offered assets using direct per-leg inverses. Refund caller-attributed unused face under Orbital's own dust/refund law; alternatively disclose retained excess. This sacrifices optimal/full consumption, requires exact post-swap state accounting and may reject on sphere/cover/minimum constraints. It is autonomous, not an off-chain planner, but is an unimplemented proposal requiring parity/economic proof. Without this change, claim only Hookless search freedom.

Keep Orbital held-rate valuation and B6 raw-share liquidity law (`Orbital PRD:828–835`; B6 PRD `:35–42`). Rate is proportional accounting value, not a trade-sized unwrap quote. New multi-position valuation requires updating its configured provider and transition-rate projection, never falling back based on gas.

## 6. Amendments, evidence and later gates

**Owner amendments:** D1 retains mandatory scalar selectors; D2/D4–6 replace composition funding/order/min-ratio admission with the selected valuation; D3 aggregates principal across positions; D7–8 retain whole local contribution/residual booking with disclosed charges; D9–12/D21 define wing consolidation, progress and stopping; D17 refreshes exact-output domains; D18–19 remove ordinary maintenance interleaving. D20/D25 need explicit new admission/spread policy: existing 50 bp composition bound is not an oracle gate; existing 1 bp alignment cannot apply to Cother=0. Keep 25 bp on management swaps and 10 bp fee-inclusive execution shortfall where applicable. Preserve D13–16, D22–24/D26/D28–29/D31; update D27/D30 matrices. Amend DETF alignment D57–58 for ranges/accounting, preserve D59 activation and scalar routes. Pons orchestration/fees remain unchanged. Source-agnostic eligible pretransfer, exact-in no refunds and full booking remain.

**Direct evidence:** H stores only one center position (`HPositionRepo.sol:9–22`), and snapshots one range (`HCommon.sol:125–145`). Crane quoter overlays one liquidity change (`lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol:46–50,79`); three-position removal needs a bounded multi-range overlay, not summing incompatible liquidity units. Current composition searches (`HTransitionPlanner.sol:73–108`); Crane ZapQuoter also searches (`:166–228`). The utils single-step quote assumes unchanged active liquidity, not a sizing solution (`UniswapV4Utils.sol:32–62`).

Primary URLs, accessed **2026-10-03**, after Context7 `/uniswap/v4-core`: https://docs.uniswap.org/concepts/protocol/range-orders (single-sided orders can reverse before removal); https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/Position.sol (owner/ticks/salt and fee checkpoints). These describe mechanics, not audited compatibility of this proposal. Main is unpinned; local liquidity math pragma ^0.8.24, repository compiler 0.8.35/optimizer 1/no via-IR (`foundry.toml:29–36`).

**Later gates:** approve valuation/feed/charges/limits first; prove inverse minimality and bounds, three-slot conservation, boundary rounding, partial conversion and reversal, fee attribution, keeper failure, dust/churn, manipulated spot/reference cycles, and exact ordinary/transition/SY parity. Use real registry proxies and refreshed artifacts, then replay `V4FundedBindings.t.sol:243–272` including seed 16222 and same-manager two-vault fixture `TestBase_UniswapV4Detf_Orbital_Univ4Se.sol:36–61`. Bound ordinary enumeration to three positions and forward swaps to an explicit step cap; measure complete nested calls, not isolated helpers, under unchanged gas limits.

No new ordinary path failed. Previously missing wrong `.../v4/libraries/LiquidityAmounts.sol` and `.../standard/yield/NativeStandardYieldTarget.sol` paths were not retried; canonical paths were used. Confidence high in placement/API mechanics and direct arithmetic, medium in structural feasibility, unresolved in oracle economic safety, outer redesign parity and measured liveness. **Stop for owner decisions; no implementation authorization.**
