# rawleg-rp-swap: CONFIRMED (latent and depends on config; no live 4663 instance)

Hypotheses: rawleg-rp-swap-units, hunt-raw-leg-rp-unconverted-swap-io

## Bug
D60 (05efa10e) lets a raw leg (standardExchanges[i]==0) carry a rate provider. Two things on that leg use rated units:
- reserves (ratedPairUnits = raw * rate)
- swap inflow (mapPairInToRatedWad)

The exact-in payout does not. It is `amountOut = Math.descale(budget, ratedScales[j])`, a decimal shift with no division by the rate:
- Weighted ClaimLib:159
- Curve quad ClaimLib:223

Buying the raw leg therefore pays r times the fair amount. Selling it back is credited at the rated value, so a round trip inside the pool alone makes about (r-1) - 2*fee per loop.

## PoC (passing)
- RawLegRpSwap.t.sol: Weighted 3-leg hook (leg0 SE, leg1 raw with rate 1.2, leg2 raw), dex fee 0.3%. The honest LP puts in 1M of rated value per leg. The attacker starts with 50k of its own token2 and does 5 round trips t2->t1->t2 through the public exchangeIn.
  - Attacker ends with 121,012 token2: +71,012 profit (+142%).
  - LP fair value drops by 71,012 (it matches the profit to the wei, apart from rounding).
  - Control (rate 1.0): the attacker loses 1,411 and the LP gains 1,410.
- RawLegRpSwapCurveQuad.t.sol: Curve quad (leg0 SE, leg1 raw with rate 1.2, legs 2 and 3 raw), amp 100, fee 0.1%. Same attack: +73,182 token2 profit, and the LP loses 73,182. Control (rate 1.0): -497.

Run: forge test <file> -vv

## Limits
- Only a pool deployed with a raw-leg rate provider whose rate is above 1 is affected. Orbital (not tested) is mispriced for any rate other than 1.
- Deployment is permissionless, but a deployer who set the provider gains nothing new; the victims are third-party LPs who join such a pool.
- No live chain-4663 instance has this config: the only raw leg there (the fee-accrual hook's DETF leg) has rp=0.
- Severity: high as a latent bug, not live.
- Not tested: the Balancer quad, Orbital, the exact-out paths, and the pretransfer override.

## Fix
On a raw leg with a provider:
- divide the payout by the rate: amountOut = budget * 1e18 / rate, descaled
- multiply the exact-out debit by the rate
- Orbital: also convert the input

Alternatively, restore the RateProviderWithoutSE revert.
