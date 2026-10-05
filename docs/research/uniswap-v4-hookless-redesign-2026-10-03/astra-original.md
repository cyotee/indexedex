# Astra — immutable independent first pass

2026-10-03. Research only; no implementation, execution, measurements, or consensus claimed. Recommendations below require owner approval. No peer originals were read.

## Finding and ranking

**Yes, but not with all existing economic behavior preserved.** Removing holder maintenance does not remove caller-composition sizing. Nor does making Hookless search-free make the current Orbital composition search-free.

1. **Preferred conditional design: proportional core plus uniform local invariant-settled single-token routes, with separate maintenance.** Extend the existing blocked constant-product settlement model to idle single-token operations too. Deposits stay local; single-token redemptions require local cover even when idle. Preserve full-range deployed backing, fungible shares, and autonomous scalar SE/SY calls. This is an explicit internal market against holders, NOT the existing external-pool proportional zap. Recommend this only if the owner accepts its economic and liquidity restrictions.
2. **Safest accounting baseline: proportional basket core, in-kind exits, no automatic single-token deposit.** Fewer valuation assumptions, but not a drop-in Orbital buffer. B6 flexible share deposits/withdrawals remain useful; pair-token buffering and general single-token SY cannot be promised. A separate search-based converter does not cure this incompatibility.
3. **Domain-restricted external conversion.** Retain post-swap proportional issuance only where a directly sized conversion passes an exact certificate; otherwise reject, without retry. Full-range LP math alone supplies no whole-book zap equation. A zero-swap one-backed-leg route is a genuine search-free subset, but insufficient for ordinary two-legged Orbital traffic.
4. **Oracle-NAV arbitrary deposits.** Algebraically simple, economically highest-risk: stale/or manipulated valuation transfers value to informed traders; holders fund later imbalance repair. Reject same-pool spot NAV as the default. A robust independent oracle introduces availability, freshness, denomination and governance decisions—not a free optimization.

Dissent from the tentative lean: option 2 alone does not meet autonomous scalar buffering. Option 1 is a candidate product change, not a demonstrated economically safe replacement. If unrestricted idle single-token liquidity or unchanged post-swap min-ratio ownership is mandatory, this evidence does **not** establish a complete search-free solution.

## Current-source findings

Notation: `H` = `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault`; `O` = `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook`; `U` = `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/`; suffixes below concatenate literally.

* `HTransitionPlanner.sol:73–156` searches caller swaps and prices against repriced incumbent backing; `:168–214` separately searches holder repair. `HInQueryTarget.sol:163–178` invokes composition when idle and invariant issuance when blocked. `:150,184–187` adds maintenance to redemption transitions.
* **Additional outer searches:** `OExitQuoteLib.sol:347–374` discovers face amounts for desired claims; `OClaimLib.sol:250–275` brackets then refines buffer input. These survive simply deleting Hookless's solver. `OExitQuoteLib.sol:85–125` already expresses exact-input output legs through directly sized SE-share redemptions.
* `UUniswapV4ZapQuoter.sol:166–228` searches and checks neighbors. `UUniswapV4Quoter.sol:172–176,233–239` traverses ticks for an already-sized swap. Those are different operations. `UUniswapV4Utils.sol:41–62,95–117` assumes constant active liquidity and targets global price limits; its comments do not establish boundary checking or whole-book alignment.
* Current protection is real arithmetic: `HProtectionMath.sol:98–133`; placement uses signed settlement and explicit losses, `HInventoryMath.sol:253–292`. Neither establishes search-free scalar entry.

## Exact candidate accounting and domains

Raw token units throughout. Let `S>0`, `B_i=D_i+F_i+E_i`, excluding caller credit and liabilities. `D` uses finite usable full-range ticks, not infinite-range reserves. Collection: `(F,E)→(F+E,0)`; no gain. `E_i=floor(liquidity*feeGrowthInsideDelta_i/2^128)` with core checkpoint/wrap semantics. No new entry/exit fee is proposed; existing internal settlement is fee-free. External maintenance pays actual protocol/LP fees; own LP recovery belongs to holders once.

**Proportional core.** Exact shares `m` require `C_i=ceil(m B_i/S)` for positive legs; mint exactly `m`, leave all received contribution local. Given exact-in basket `C`, mint `min_i floor(S C_i/B_i)`. Retain identified excess and rounding surplus, fully booked; never present a materially unbalanced basket as protected alignment. Enforce `10000 m B_i≥9999 S C_i` for protected joins. Intentional Multi excess remains separately disclosed under existing policy. No placement before mint; hence no deposit-placement rounding charge.

**Candidate single-input route, both manager states.** Reuse the actual integer model in `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:58–95`:

```
K = ceil(sqrt(Bin*Bother))
A = floor(sqrt((Bin+c)*Bother))
m = A>K ? floor(S*(A-K)/K) : 0
Areq = K + ceil(mRequested*K/S)
cRequired = ceil(Areq²/Bother) - Bin
```

Reject zero issuance. Exact-share mode mints exactly the request; input rounding surplus remains backing. These are arithmetic square roots, not exploratory swap/share quote probes. Guard intermediate widths and source representability.

Single-output exact-input redemption reuses `StandardExchangeConstantProduct.sol:98–110`:

```
u=floor(Bout*r/S); v=floor(Bother*r/S)
y=u + (v==0 ? 0 : floor((Bout-u)*v/Bother))
```

Require `0<r<S` for positive opposite backing and `Fout≥y`; otherwise reject atomically. **General two-leg exact-output redemption stays unsupported**: the existing inverse at `:113–128` searches. Do not replace its nested floors with a radical inverse.

**Conservation:** local mint gives `B'=B+C`, `S'=S+m`; redemption gives `B'=B-y e_out`, `S'=S-r`. No invented opposing transfer. At fixed external position state, conservative rounding gives `B'0 B'1/(S')² ≥ B0 B1/S²` for these scalar operations and proportional joins/exits. This blocks a costless fixed-state invariant round trip; it does NOT prove external-market value preservation or safety across maintenance/repricing.

**In-kind exit:** blocked, pay `floor(r B_i/S)` only with both local covers. Idle, collect fees, remove `l_r=floor(l*r/S)`, pay `floor(r*(F_i+E_i)/S)+proceeds_i(l_r)`, with F/E snapshotted before collection. Remaining book is `B_i-payment_i-removalRoundingLoss_i`; fees are not added twice. These explicitly different idle/blocked realizations require separate previews. Position and share rounding remain holders' residual, never unbooked.

**Empty/one-sided:** retain dual-funded F0: `raw=floor(sqrt(C0*C1))`, caller `raw-minimum`, dead-sink minimum plus existing residual-sink equation from implementation plan §2.1. Nonzero supply with both backing legs zero rejects. With only one positive backing leg, accept only that leg linearly: `m=floor(S c/B)`, inverse `ceil(m B/S)`, exit `floor(r B/S)` with cover. Reject contributions to the empty leg rather than silently donating them. No unilateral activation.

Option 3 retains the original equations `C=(c-x,Q(x))`, `B=B_after(x)`, then min-ratio mint. A formula must include active external liquidity, finite endpoints, own fees and arbitrary F/E; no such general equation was established here. Option 4 instead uses `V=Σp_i B_i`, `m=floor(S Σp_i C_i/V)` and proportional exits, with an explicitly fixed, independently validated valuation snapshot. That is a different ownership admission rule.

## Sleeve, protections, and economic objections

Choose **reserved placement plus separate maintenance**, not accidental leftovers. Read live `p`; target `floor((D_i+F_i)*p/(1+p))`, default `p=.20`, existing absolute/5%-of-target deadband. Placement must evaluate final deployed principal and exact debts, retaining the limiting-leg excess. Both targets need not be attained simultaneously. Pure residual-only placement can leave one sleeve token zero; maintenance-only restoration has a keeper-liveness dependency. Combining reservation with maintenance is preferable, not continuous rebalancing.

Ordinary option-1 calls neither place nor repair. Full-range liquidity remains deployed, but new inflows earn no LP fees until maintenance. Sleeve exhaustion blocks scalar exits even idle; users can take in-kind or wait for independent maintenance. Earned fees are backing, not local cover. Existing permissionless repair may retain bounded search; search-free maintenance is not necessary to answer the ordinary-operation question.

Keep 25 bp maintenance and 10 bp execution-shortfall guards. For internal scalar settlement propose a **new, owner-approved interpretation** of 50 bp: bound movement of internal marginal price `B1/B0` by `max(P'/P,P/P')−1≤.005`. Apply 1 bp to integer loss versus ideal invariant issuance, not nonexistent caller-basket alignment. This admits only small relative trades; it is not a silent preservation of D20. Enforce nonzero meaningful minOut/maxIn and deadlines. Repeated operations remain unrestricted by time/campaign budgets.

Risks: external trades change D and E; asymmetric donations change the internal price; holders subsidize or profit from arbitrage between internal and external markets. Separate maintenance realizes trading losses and MEV exposure. A fixed-state invariant proof does not cover those cycles. Source-agnostic surplus claims remain authorized; freeze credit before fee collection, absorb unclaimed surplus consistently, then fully synchronize local snapshots. No minOut-zero planned execution, gas-dependent valuation, or endorsement of speculative `sharesJ/sharesK` bookkeeping.

## Orbital/SY replacement contract

Preserve scalar `exchangeIn(token,c,share,minShares,...)` and its exact-input redemption alias for SY using the option-1 equations. Extend `quoteInputForExactShares(state,m)` to the same idle and blocked domain. Replace outer `_faceForClaim` and `_invertBufferForEffective` with: desired rated-native amount → `sharesForNativeUp` → exact-share input formula → one validation, no retry. Freeze the leg's rate for that conversion and project the subsequent rate/book normally. Zero minted/rated output must reject, not substitute face amount (`OClaimLib.sol:309`; `OExitQuoteLib.sol:379–381`).

Exact-input sphere output already chooses share quantity before redemption; use that quantity with a binding payout minimum. Required exact-output unwrap routes still reject under Orbital D31a; route discovery must disclose this. A proportional-only core would invalidate pair→SE buffering (`OCommon.sol:518–535`), not merely change a router. Flexible share-basket entry/exit is its search-free replacement, but it does not recreate scalar SY automatically. Outer zap sizing/parity still needs independent proof; no full composability claim follows from these inner formulas alone.

Keep configured rate providers and projected rates; never value held reserves via trade-sized SE quotes. Orbital PRD addendum `:828–835` overrides older optional-provider text. Do not merge Pons V2 orchestration, fee models or admission with Hookless; Pons receives no automatic accounting-policy change.

## D1–D31 amendment ledger

For every ranked design, keep D13–16, D22–26, D28–29, D31; retain D9–12 and D21 for separate maintenance. D3 retains its live denominator but states best-effort timing. D17 remains closed-form/domain-only. Refresh D27 route/accounting tables and D30 identical-state parity for all changed routes.

* **Option 1:** amend D1, D2, D4–8 to local scalar settlement plus proportional basket core; D18–19 to remove mandatory interleaving; D20/D25 applicability to explicitly approved internal-price/rounding guards. D7/D8 still fully credit/retain local contribution. D58–59 of DETF alignment need corresponding clarification.
* **Option 2:** amend D1/D2/D4/D5 and D18–19; D6–8 retained for baskets. D20 composition bound becomes inapplicable, not disabled protection on a supported zap; min amounts remain. Narrow D17 and SY discovery.
* **Option 3:** retain D2/D4–8 and D20 when certified; amend D1 liveness/domain and D18–19 separation. No hidden fallback.
* **Option 4:** replace D5–6 and scalar D20 alignment with explicit oracle valuation policy; amend D1–4, D7–8 timing, D18–19. All oracle costs/limits require approval.

## Evidence, confidence, later acceptance

Access date for all evidence: **2026-10-03**. Context7 `/uniswap/v4-core` preceded Uniswap API verification. Primary source: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol — `unlock` rejects AlreadyUnlocked; `modifyLiquidity` returns principal-plus-fees. Upstream main uses Solidity 0.8.26, not a deployment pin. Local `foundry.toml:29–36`: 0.8.35, optimizer runs 1, no via-IR. Local revision/runtime equivalence unverified.

Primary economic precedent: https://learn.charm.fi/charm/technical-references/core/alphaprovault — Alpha Pro documents proportional deposits retained until rebalance, proportional fee-inclusive exits, configurable full-range weight. It is **not inherently full-range-only**, nor evidence of autonomous unilateral conversion. No Arrakis/Gamma/Range claim or exploit history is relied upon.

Later acceptance: owner approves amended economics first; then independent integer references/exhaustive small domains, mixed-decimal/extreme-tick tests, donation and same-pool manipulation cycles, fee/checkpoint attribution, failed-cover atomicity, live-p changes, residual conservation, and exact SE/SY/transition parity. Use real registry-deployed proxies and canonical Crane/IndexedEx TestBases; build artifacts before tests. Replay `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol:243–272,333–400`, including seed 16222 and 31M-call caps; fixture `TestBase_UniswapV4Detf_Orbital_Univ4Se.sol:49–61` uses two same-manager position vaults. Measure end-to-end gas, quote counts, storage reads and runtime sizes on pinned comparable states; do not raise caps.

Confidence: high in identified searches and accounting/domain distinctions; medium in candidate fixed-state mathematics; low-to-medium in economic acceptability and end-to-end Orbital liveness until independently validated. No ordinary-file read failed. Missing evidence: fresh traces/tests, pinned deployed versions, exhaustive cross-mode economics, and proof of outer zap parity after inverse substitution. **Stop for human selection; no implementation authorized.**
