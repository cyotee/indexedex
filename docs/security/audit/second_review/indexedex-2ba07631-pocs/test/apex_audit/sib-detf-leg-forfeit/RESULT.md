# sib-detf-leg-forfeit: H3SP-1 sibling execution on MixedBuffer, MultiVaultWeighted and UniswapV4 multi-leg

Status: CONFIRMED by execution in all three families (honest-user loss, no attacker). Runs on t4, profile audit:
- MixedBufferLegForfeit.t.sol: Suite result ok, 2 passed; 0 failed
- MvwLegForfeit.t.sol: Suite result ok, 3 passed; 0 failed
- V4WeightedLegForfeit.t.sol: Suite result ok, 2 passed; 0 failed

These are siblings of r3-H3SP-1 (ComposedStable), with the same root cause. They should be reported as a single finding that lists every location, not as new separate findings.

## Shape (all three)
The primary burn, which runs when the burn gate is open (synthetic < burnThreshold), works like this:
1. It sizes `lpOut = detfIn * protocolLp / totalSupply`, a pro-rata share of ALL protocol LP.
2. It exits that LP proportionally.
3. It pays the user only the selected tokenOut leg.
4. It re-joins every other non-DETF leg, plus the DETF self-leg, into protocol LP.

The quote (previewExchangeIn) matches what is executed, so `minAmountOut` gives no protection. When the gate is open this is the only DETF-contract redemption route these families offer. There is no consolidating route like the ComposedStable exact-in WETH path.

- MixedBuffer `_burnHeldDetf`: MixedBufferMultiVaultStableDetfExchangeOutTarget.sol:20-28. It pays `buffer_` or one `shares_[i]`, then `_joinReserveLegs(detf_, buffer_, shares_)` re-joins the rest.
- MVW `_burnHeldDetf`: MultiVaultWeightedDetfExchangeOutTarget.sol:23-28. It pays `shares_[leg_]`, then `_joinReserveDetfAndShares` re-joins the rest.
- UniswapV4 DETF `_burnHeld` / `_payBurnOut`: UniswapV4DetfTarget.sol:437-450 and 500-519. It pays only the tokenOut pair leg. The other pair legs stay on the DETF and `_trySweepDust` (line 450) puts them back into protocol LP. The test confirms that 0 pair-other is left on the DETF afterwards.

Spec context: DETF_ALIGNMENT_PRD.md §15.3 says "remove along the DETF–tokenOut curve; rejoin all other legs". §5 says "Burn must be honest against the same book". BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md:286 says "consolidate other legs to tokenOut / buffer". The code does neither of these: it does not do a DETF/tokenOut-only removal, and it does not consolidate. It sizes the burn on the full LP but pays one leg of the proportional exit.

## Per-family results (honest victim burns half of the DETF it bought through exchangeIn)

| Family / fixture | Gate opened by | Paid leg = slice exactly | Victim loss of non-DETF backing | Value moved to protocol LP |
|---|---|---|---|---|
| ComposedStable (r3-H3SP-1, reference) | config 1e30/1e29 | yes | 45.45% | flows pro-rata to holders (holder2 +0.1976 WETH) |
| MixedBuffer N=1 (DETF/DAI buffer/SE share), burn -> buffer | config 1e30/1e29 | 45.19e18 == 45.19e18 | **54.50%** (54.14 live-units share leg forfeited) | +80.1 LP (59% of lpOut, includes DETF self-leg) |
| MixedBuffer N=1, burn -> share0 | same | 54.14e18 == 54.14e18 | 45.49% (45.19 buffer forfeited) | +26.9 LP; holder2 redeem +2.09e18 |
| MVW N=2 (50/25/25), burn -> leg0 | config 1e30/1e29 | 9.811e18 == 9.811e18 | **49.99%** (weighted-spot valuation) | +11.26 LP (74.9% of lpOut) |
| MVW N=2, burn -> leg1 | same | exact | 50.00% | +11.26 LP |
| MVW N=3, burn -> leg0 | same | exact | **66.66%** | +10.36 LP (83% of lpOut) |
| UniV4 DETF, weighted hook DETF40/P0 30/P1 30, burn -> pair0 | **production Policy 1.05/0.95**, opened by real public DETF->pair0 sells (synthetic 0.9475 < 0.95) | 1.4094e18 == 1.4094e18 | **48.36%** (1.496 pair1 forfeited, worth 1.320 pair0 at the hook's after-fee swap quote, so the figure is conservative) | +1.027 LP (67.6% of lpOut) |
| UniV4 weighted, burn -> pair1 | per-pair gate for pair1 opened by sells | exact | 48.36% | same |

The loss scales as 1 - w_out / Σ w_nonDETF, so it gets worse as the number of legs grows (MVW N=3 loses 2/3). The UniswapV4 Orbital, Quad and other multi-leg hooks use the same `UniswapV4DetfTarget._burnHeld`/`_payBurnOut`, so they share the bug (not separately executed; only the hook's curve differs). 2-leg families (V4 CP single, SingleSE) are not affected.

Value flow: the forfeit is re-joined into protocol LP, and LP per DETF rises (MixedBuffer 1.4286e27 -> 1.4685e27). Remaining holders capture it pro-rata, in LP terms. When holder2 also redeems one leg, holder2 forfeits part of that gain again, which is why holder2's tokenOut gain is small in some rows. Attacker profit is limited to the pro-rata accrual to existing holders. No extraction path was shown.

## Validity notes
- No cheatcodes ran during the measured operations. Victims acquire DETF through the normal exchangeIn route. Each branch starts from the same snapshot.
- Balancer families open the gate by config (mint 1e30 / burn 1e29), the same convention as the accepted r3-H3SP-1. In production the gate opens whenever synthetic < burnThreshold (DETF below backing), which is exactly when holders redeem. The V4 run uses the real 1.05/0.95 Policy and opens the gate through market trades.
- Fair-value conventions: MixedBuffer uses stable-pool live-scaled18 units (spot ~1). MVW uses weighted-pool spot (value_i is proportional to w_i). V4 uses the hook's own after-fee swap quote.
- Live: the burn gate on the live 4663 weighted V4 DETF (60/20/20) is closed according to prior notes, so nothing is exploitable live at this moment. It becomes active for any user who redeems once synthetic < burnThreshold.

## Fix
On the primary burn, pay the whole non-DETF slice converted into tokenOut. Alternatively, size `lpOut` against only the tokenOut leg's share of the value (or do a single-token exit of the pro-rata LP). Apply the fix in all four families.
