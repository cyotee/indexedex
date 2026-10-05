# Astra — mandatory-scalar/wings combined cross-review

**2026-10-03.** Continued Astra session. Read the three complete current originals together: Grok replacement, MiniMax M3 and Kimi K3. They are attributed evidence, not authority. No other reviews/synthesis/status artifacts read. Originals preserved. Research only; no implementation, execution, delegation or gas measurement. This is one review, not consensus.

## 1. Final position

**Retain scalar entry and exit. Separate admission pricing, exit realization and placement.** My preferred conditional architecture remains controlled valuation admission, local-first deposits, a three-position managed core/wing book, idle proportional liquidation plus one already-sized conversion, and covered local settlement while already unlocked. The oracle/fee/risk policy is not approved or proved safe. A correctly charged internal-market architecture is the second candidate, now with a more precise search-free idle funding construction below.

Wings are useful inventory placement, not a share-pricing algorithm. On this central distinction I agree with Grok and Kimi and reject MiniMax's proposed wing mint. I also find material orientation errors in both MiniMax and Kimi, and missing rounding proof in the proposed internal-market exit cascades. Neither a majority nor deterministic arithmetic settles economic acceptability.

Notation: `H` = `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault`; `O` = `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook`; `C` = `lib/crane/contracts/protocols/dexes/uniswap/v4/`. Suffixes concatenate literally.

## 2. Orientation, tick boundaries and unit audit

For sqrt price q and range a<b:

| Price domain | Principal | Correct new one-sided wing |
|---|---|---|
| q≤a | token0 only | Token0 range above current price |
| a<q<b | both tokens | Cannot assume unilateral add |
| q≥b | token1 only | Token1 range below current price |

This follows directly from `C/libraries/LiquidityAmounts.sol:67–76` and the delta equations. **Grok's orientation and mine are correct. MiniMax reverses it throughout. Kimi quotes the correct inequalities, then reverses their English conclusion in §2.** Kimi's later token0 full-cross condition q≥b agrees with the correct, above-spot placement, not that reversed sentence.

Use actual q and both endpoints for admission, not a name such as “Below.” At exact tick boundaries, pool tick bookkeeping can differ from the tick inferred solely from sqrt price after directional crossing; amounts and active-liquidity overlays must use their corresponding source semantics. Strictly separated new wings are simplest. Signed Solidity division truncates toward zero: MiniMax's `(tick/spacing)*spacing` is not mathematical floor for negative nonmultiples. Its range around the current tick is generally active, not one-sided. Multiplying ticks by 80%/120% does not define an 80%–120% price band; zero and negative ticks expose that defect immediately.

**Wing liquidity does not supply a common denominator.** Equal L at different endpoints represents different asset quantities. A token0-only deposit into a positive B0/B1 book cannot use min-ratio issuance without conversion or an explicit admission change.

MiniMax's `m=floor(S*c/(B0+c))` ignores B1 and is not proportional ownership. Hand-checkable example, ignoring placement loss: B0=B1=100,000,000, S=10^12, c=1,000 yields m=9,999,900. It passes its proposed token0 1 bp inequality because `m*B0/(S*c)=0.99999`; the zero contribution leg imposes no useful check. Yet the minted fraction's proportional post-mint basket floors to 999 units of each token. At equal external prices that is value 1,998 for input 1,000, before conversion costs. This is an accounting counterexample, not an executed exploit. The scalar 1 bp check does not validate the admission rule.

## 3. Exact idle exit funding: floor helpers and “+1” are not enough

**Agreement with Kimi:** after an internal payout y is priced, idle liquidity can be removed to fund it without discovering a swap amount. The other-token proceeds stay in the book. **Disagreement with Grok:** restricting this to a still-one-sided wing unnecessarily rejects funded core/mixed-wing inventory. But Kimi's proposed rounded-up helper plus one-liquidity stencil is not established by source.

Let Q=2^96. For the token0-bearing portion of a position, set `u=max(q,a)`, `v=b`, requiring u<v. For token1 use `u=a`, `v=min(q,b)`, again u<v. For integer liquidity l the rounded-down principal proceeds are exactly:

```
R0(l) = floor(l*Q*(v-u)/(u*v))
R1(l) = floor(l*(v-u)/Q)
```

The nested token0 floors in `C/libraries/SqrtPriceMath.sol:202–209` collapse to this rational floor; token1 is direct at `:237–255`. Therefore the minimal liquidity for **at least** integer shortfall z>0 is:

```
l0_required = ceil(z*u*v/(Q*(v-u)))
l1_required = ceil(z*Q/(v-u))
```

These are mathematical inverses of principal proceeds, **not claims that the existing budget helpers compute them**. `getLiquidityForAmount0` first floors u*v/Q (`LiquidityAmounts.sol:26–27`); that information loss cannot generally be repaired by adding one liquidity unit. Near the valid minimum tick, adjacent endpoints have u*v<Q, so that intermediate is zero. The helper returns zero for every budget. Choose z=R0(1)+1 and an owned position with sufficient liquidity: helper+1 still produces only R0(1)<z. This disproves a universal +1 guarantee without running code. `TickMath.sol:18–29` supplies the supported minimum tick/sqrt range. Token0 inverse products can exceed 512 bits; exact wide arithmetic or an independently proved factorization is required.

**Bounded realization algorithm:** collect own fees once first; establish y under the selected accounting rule; use free output currency; visit each of at most three positions in a fixed order. Skip a zero output coefficient. Compute `min(ownedLiquidity, exactRequiredLiquidity)` once, settle its exact principal and fees, update the remaining shortfall. No alternate candidate/probe. Reject if final cover is inadequate or signed-delta/settlement bounds fail. Restrict per-position liquidity at creation if necessary to keep removal within one representable signed operation. Each removal is a real action in a predetermined funding plan, not an exploratory quote loop.

This can fund from mixed positions too, but cannot create missing requested currency. It does not promise unlimited blocked or one-sided-output availability. It may remove more total asset value than the payout because of incidental opposite proceeds; those proceeds remain shareholder backing, not a refund.

**Important limitation:** partial removal has bookkeeping/settlement rounding loss. A pre-removal F2 price plus holder-funded realization loss is not precisely the fee-free frozen-book F2 transition. Preview must model the realized loss, its owner, and the terminal invariant; a later specification may charge it or explicitly accept a bounded realization cost. Do not claim the frozen-book inequality still holds automatically.

My preferred idle exit needs no output-shortfall inverse: remove `floor(l_j*r/S)` from every position, combine with pro-rata local/earned balances, then forward-swap the known opposing entitlement. This retains broader idle scalar service at market execution prices. It requires correct post-removal multi-range quote overlays, not the existing single-range overlay reused unchanged.

## 4. Attributed review of the economic proposals

### Grok replacement

**Agree:** complete-book F1/F2 arithmetic; placement ≠ valuation; local cover while already unlocked; no nested unlock; three aggregated slots; separate maintenance; honest disclosure that `zapSplitWad` remains. Extending `quoteInputForExactShares` to idle requires an explicit admission-policy change.

**Dissent/corrections:**

* Internal settlement is not the only rule capable of operating while already unlocked; my local oracle-referenced rule also needs no PoolManager interaction.
* “Entry internal, therefore exit must be internal” is an economic preference, not a theorem. Even matching internal exits allow external hedging and in-kind extraction of mispriced inventory. Conversely, combining internal entry with market realization may be an explicitly priced product, but needs evidence.
* The “still-one-sided wing only” funding restriction sacrifices existing idle liquidity unnecessarily; see §3.
* A swap-free consolidation does not guarantee absence of adverse selection. It changes subsequent exposure and active liquidity at a manipulable state. Direct cost can be only rounding while the subsequent reversal/hedge still matters.
* Wings stretching to global usable endpoints are valid, but “enter range” may occur far before full conversion; broad wings can stay mixed for long periods. Claims about productivity require later data.
* Post-mint placement is not the no-cost `B'=B+c` transition. Include loss and state whether holders, including the new depositor, pay it.

### Kimi K3

**Agree:** ownership-admission is the primary choice; CP source equations and exact-share inverse; explicit spread/divergence considerations; a funding cascade can be direct; correct warning about continued bisection after interpolation; no complete search-free claim while the sphere loop remains.

**Dissent/corrections:** orientation and +1 funding errors are above. Additionally:

* Its displayed equations do not include the proposed spread λ. It must specify the charging base, retained versus transferred destination, floor order, and the revised inverse. A fee label is not an economic formula.
* Consolidation alone is not inventory-ratio repair: swap-free removal/addition preserves aggregate token amounts apart from rounding. Thus “divergence until consolidation” can be permanent without external trades or explicit repair.
* A divergence rule falling back to **basket-only** violates the mandatory-scalar product as a final solution. A temporary risk rejection can be legitimate, but requires quantified supported scalar domains and an independent recovery path, not a renamed permanent loss of functionality.
* `B1/B0` and pool price need consistent raw-unit orientation/decimal handling. If comparing raw ratios to raw q²/Q², no second decimal normalization is applied; economic reporting can normalize both.
* Five slots can be bounded, but when both pending slots are occupied and active wings cross again, placement must defer to F rather than open another slot. State this explicitly.
* “Keeper failure safe, never lockup” is too strong. Blocked cover can exhaust; price moves can eliminate a requested currency; signed/work limits can reject. Accurate backing accounting proves neither liquidation availability nor absence of financial loss.

### MiniMax M3

**Agree:** a bounded position set and already-sized forward swap are not sizing searches; placement can be deferred; Pons should remain separate; scalar functionality cannot be replaced by baskets.

**Reject rank 1 as specified:** orientation and share-denominator errors invalidate it. Further corrections:

* `min(getLiquidityForAmounts(...,budget0,0), getLiquidityForAmounts(...,0,budget1))` is zero for an interior core. Use one call with both budgets, or the two distinct single-token constraint helpers.
* B=D+F+E does not reconcile to local ERC20 balance alone. Sync F/custody, not the economic book.
* PoolManager `modifyLiquidity` returns callerDelta containing principal **plus fees**, with feesAccrued informational; do not credit both independently as separate cash inflows. The internal Pool library's principal return is a different API.
* Never burn, “zero,” or send holder-owned residual dust away as optional cleanup. Retain and book it unless separately authorized.
* Fee-free pool liquidity addition does not change price. A before/after 50 bp impact check on that add does not defend against pre-positioned spot manipulation. Repricing happens on external pool trades, including before consolidation, not only when the keeper acts.
* Fully crossed wings are out of range and earn no new swap fees until price returns. Consolidating only currently in-range wings misses fully crossed orders.
* 256 user-salted positions are a finite bound, not evidence that nested ordinary quotes/redemptions meet the chain budget. Repeated dust can fill the cap. A raw “1e6 wei WAD” minimum is not a coherent mixed-decimal policy.
* Both outer inversion counts remain misstated as eight bisections despite the contrary caveat at the beginning. Source while-loops continue.
* The general analytic-conversion impossibility claim remains unproved. Lack of an adopted whole-book formula is not proof of nonexistence.

## 5. Corrections and qualifications to my own original

1. **Oracle admission was an architectural candidate, not an attack-resistant design.** I expressly listed the gap but should not let “controlled” imply closure. In particular, a fixed spread and a deviation threshold require an economic argument and production feed availability; no arbitrary chosen values establish safety.
2. **Clarify LP spot manipulation, not merely repeat a warning.** In continuous token1 units with independent token0 price P, an interior position has

   `V_L(q;P)=l*[P*(1/q−1/b)+(q−a)]`.

   Its derivative is `l*(1−P/q²)`; it has a **minimum** at q=√P within the range. Thus moving spot away from an initially fair price does not mechanically reduce this oracle-marked position NAV. My “cheap oracle admission followed by market exit” wording describes a risk to analyze, not a demonstrated generic exploit of every independent-price rule. Spot manipulation also changes real token holdings, and attacker losses/fees to the pool must be included. Conversely, holding P fixed does not make D(q) invariant or establish safe local cash redemption, stale-feed behavior or nested projected-rate composition. Do not substitute oracle q for actual position amounts and pretend that hypothetical holdings are owned.
3. **My inverse assumes a frozen charge.** The stated nested-ceil input inverse is valid for f_i fixed for that quoted operation, independent of c. A terminal imbalance fee depending on the unknown c can reintroduce sizing/inversion work. Use a genuinely fixed/pre-state schedule with proved piecewise domains, or derive its inverse explicitly. My proposed concentration rejection is distinct from such a fee.
4. **Three positions is an operation-count bound, not a gas guarantee.** Price queries, fee-growth reads, multi-position overlay traversal, oracle calls and nesting all count. Three also intentionally sacrifices continuous new wing placement when slots are occupied.
5. **Fixed outer thirds are speculative product semantics.** My proposed two predetermined sales do not establish exact outer LP parity or adequate acceptance rates. They preserve the possibility of autonomous scalar routing, but can incur wasted conversion/refunds and fail minimums. Keep that proposal separate from an adopted, proved formula.

## 6. Coherent accounting and fee choices

For local controlled-NAV entry, my equations remain directly derivable:

```
V = Σ p_i*B_i             // p_i priced per raw unit in a common scale
n = floor(c*(W-f_i)/W)
m = floor(S*p_i*n/V)
n_req = ceil(m_req*V/(S*p_i))
c_req = ceil(n_req*W/(W-f_i))
```

Credit all c; c−n is retained dilution compensation. No placement on the ordinary mint path. Before placement, `B'=B+c e_i`, `S'=S+m`, and marked value per share does not fall at fixed p. This remains a statement about the selected valuation, not a proof of market safety.

For internal CP with a proposed retained input spread λ, one concrete alternative is `n=floor(c*(W−λ)/W)` and mint using F1(B,n), while booking full c. The exact-share inverse first computes the F1 net requirement, then `ceil(n_req*W/(W−λ))`. With retained output spread γ, pay `floor(F2(B,r)*(W−γ)/W)`; the general two-leg exact-output inverse is still not supplied by this composition. These are proposals requiring approval, not source behavior. A scalar divergence guard does not calibrate either spread by itself.

Every realized placement/removal has `loss_i=(F_i+D_i)_before−(F_i+D_i)_after` after excluding transfers and fees. `HInventoryMath.sol:266–282` explicitly records it. Conservation includes loss, actual payouts, own fees, and external swap/repricing effects. Fee checkpointing is per owned position; collecting fees on all three positions must not mint caller credit from E.

Consolidation should reserve a sleeve using aggregate deployed principal: `target_i=floor((D_i+F_i)*p/(W+p))`, live p, existing deadband, final-state recomputation after rounded debts. Add to the fixed core only from positive free excess; retain unmatched currency. No four/five/256th slot appears implicitly. A public consolidation's rounding cost belongs to holders; repeated no-progress removal/addition must not churn their balances.

## 7. Manager state, interfaces and outer searches

Already-unlocked calls price against B but spend only actual local F; E and wings are not cover. No position operations/nested unlock under the retained product policy. Revert atomically on insufficient requested currency. A frozen oracle must fail closed for valuation-dependent routes when unavailable; this changes supported failure domains and must be explicit. Idle market-realization exits should not inherit an unnecessary admission-oracle dependency.

Retain scalar SE and SY selectors with actual minima/maxima, deadlines and authenticated funding. Transition state must project the complete position array, fee checkpoints, local balances, supply, exclusions and any selected oracle/charge state. Exact-input and exact-share execution are not interchangeable: exact-input can mint extra shares, so its resulting supply/held share rate must be projected.

Grok and Kimi correctly identify the direct inverse replacement: rated desired claim → decimal-aware ceil share requirement → direct input-for-shares equation → exact validation. It works only when the quote uses the same fixed rate convention and source snapshot as execution. A post-deposit rate-dependent target needs its own derivation; “plus rate projection” alone does not invert it.

`OExitQuoteLib.sol:357–371` and `OClaimLib.sol:255–274` remain searched until actually replaced. `OMath.sol:332–360` remains a 64-probe outer residual search. Grok/Kimi disclose that honestly. My deterministic outer split is a possible amendment; it is not established as economically equivalent. If the owner wants **end-to-end** search freedom, a proved outer policy change is a release gate. Cheap inner quotes do not satisfy that gate.

## 8. Final ranked scalar architecture and required decisions

1. **Controlled valuation, local-first admission; reserved three-position core/wing management; idle pro-rata removal plus one fixed-input swap; blocked covered settlement.** Retains synchronous scalar entry/exit with explicit oracle, risk and liquidity failures. Preferred for investigation where reliable independent valuation exists. No claim that an appropriate feed exists for every admissible pair.
2. **Explicitly charged internal CP, local-first; exact algebraic idle funding across the bounded position set; blocked F-only settlement.** More source arithmetic reusable, less external-oracle dependency, but book/external-price adverse selection remains a product cost. Choose this only with disclosed economics and no basket-only escape masquerading as scalar support.
3. **Immediate one-sided placement layered on either admission rule**, after solving loss attribution and preview/inverse parity. Deferred placement is simpler and does not depend on an open wing slot for scalar acceptance.
4. **Single-candidate external conversion** only as a certified optional domain. Basket-only and asynchronous-only replacements are excluded.

**Unresolved policy:** admission valuation or internal market; spreads and divergence treatment; supported scalar domains during oracle/keeper failures; three versus five slots and cap behavior; wing widths/core range; withdrawal realization costs; outer split/residual policy; same-state oracle/rate projection semantics. Preservation of scalar capability is mandatory, but universal success at arbitrary size/state is neither proposed nor possible under actual cover limits.

**Protection meanings:** D20's 50 bp is deposit-composition pool-price impact, not an oracle/deviation/wing-distance metric. A no-swap deposit makes that check inapplicable, not a defense. The 25 bp limit remains for management swaps, 10 bp for fee-inclusive fill shortfall. Scalar value/invariant rounding protection needs an explicitly approved replacement for basket alignment; do not silently transfer the 1 bp meaning. New parameters require owner approval under D25, not setters invented during implementation.

Update D1–8 admission/order/placement as selected; D3 for aggregate principal; D9–12/D21 for bounded lifecycle and genuine progress; D17–19 route/inverse/interleaving matrix; D20/D25 changed metrics; D27/D30 complete specifications and exact parity. Preserve source-agnostic D15/no-refund exact-in law, D16 booking, family/binding/removal boundaries D13–14/D22–24/D26/D28–29/D31. Explicitly amend DETF D57–58 range/accounting and corresponding SY/rate-provider law; do not claim only Hookless source changes suffice. B6/held-rate principles remain. Pons remains separate and unchanged without approval.

**Later gates:** independently verify the removal inverses/minimality/overflow, including low-price helper+1 counterexamples; model all realization losses; test orientation/negative ticks/exact boundaries/reversal; prove fee and donation attribution; quantify internal/external and oracle-marked cycles with actual pool costs; demonstrate useful scalar domains and clean cover failures; prove multi-range ordinary/transition/SY parity; eliminate or explicitly accept the outer search. Use production proxies and refreshed artifacts, then measure nested calls under unchanged 31M/32M limits. Finite caps and passing tests prove neither economic safety nor sufficient gas headroom.

## 9. Evidence status

Fresh access **2026-10-03**. Context7 `/uniswap/v4-core` preceded API verification. Primary source freshly fetched: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol, whose `modifyLiquidity` forms `callerDelta=principalDelta+feesAccrued` and whose `unlock` rejects AlreadyUnlocked. Context7 primary liquidity source: https://github.com/Uniswap/v4-core/blob/main/test/utils/LiquidityAmounts.sol. Local canonical math, CP helpers, placement loss accounting, current PRD D-table, and outer loops were directly re-read. Upstream main is not a deployed pin (PoolManager pragma 0.8.26); local liquidity helper pragma ^0.8.24, repository compiler baseline 0.8.35/optimizer 1/no via-IR from this round's original direct read.

No ordinary path failed this review; previously missing mistaken paths were not retried. No guard/SDK denial occurred. Confidence high in orientation, denominator and floor-helper corrections; medium in mathematical funding derivation pending wide-integer verification; unresolved in valuation economics, liveness and measured gas. Return to moderator/human and stop. No further round or implementation authorized.
