# probe-se-rate-provider: CONFIRMED (latent; not reachable on live 4663)

Hypothesis: se-rate-provider-full-book-manipulable

## Mechanism (narrowed by execution)
`StandardExchangeRateProviderFacet._getRate` quotes `previewExchangeIn(totalSupply)`. For a BPT-as-SE subject (Balancer V3 buffer pool), the full-book liquidation is `valuationOnly`, so `LiquidationLib:151` returns `live[idx]`. That makes `RP = bal[face] / supply`.
- RateMeasure.t.sol (CommonBufferMultiVaultStablePool, 1000 face + 1000 DAI): at rest RP = 0.500 while the marginal 1-BPT exit preview is 0.975, so RP understates value by about 2x.
- Pushing 100 / 300 / 600 face into the pool moves RP to 0.526 / 0.578 / 0.656, i.e. linearly with pool composition. On a stable pool the swap round trip costs only fees.
- Side observation (not pursued): after any face->DAI swap, the pool's own `previewExchangeIn(BPT->face)` reverts with panic 0x11 or returns erratic values (0.58 to 142 face per BPT). This looks like the computeBalance-domain issue already reported separately.

## Consumers
- **Weighted buffer hook (the live 4663 family): immune.** Per-leg rate scaling cancels (skeptic reasoning). This was not re-executed.
- **Curve quad stable buffer hook: exploitable.** It is not scale-invariant per leg, and inflow is credited as `shares * RP'`.

## PoC: QuadStableBptRateManip.t.sol (PASS)
Fixture: the project's own matrix row `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_CommonBufferMultiVaultStablePool`:
- 4 buffered legs, each its own CBMVS Balancer V3 pool (BPT-as-SE) plus its own StandardExchangeRateProvider
- real V4 PoolManager and real Balancer VaultMock

Setup (owner or governance, before the attack):
- Balancer static swap fee 0.1% (`manualSetStaticSwapFeePercentage`; the fixture default is 5%)
- quad dex fee 0.1%
- honest LP joins 200 face per leg

Attacker: unprivileged EOA (harness bob). Capital is X face0 of its own plus P face0 of simulated flash principal; a 0.1% flash fee is charged and the principal plus fee must come back.
1. Swap P face0 -> DAI in leg0's Balancer pool. RP0 rises from 0.5455 to 0.6138 (P=300) or 0.6826 (P=600).
2. `quad.exchangeIn(face0 X -> face1)`. The input is credited at the inflated RP0.
3. Swap DAI -> face0 to restore the pool.
4. `quad.exchangeIn(face1 -> face0)` at rest.

Profit is measured in face0 only, the same token in and out.

| run | face1 received | face0 back | attacker net face0 (after flash fee) | hook net BPT (leg0+leg1) |
|---|---|---|---|---|
| control X=100, P=0 | 99.14 | 94.48 | **-5.52** | +7.50 |
| X=60, P=300 | 66.95 | 64.41 | +3.60 | -4.08 |
| X=100, P=300 | 111.07 | 105.27 | **+4.52** | -3.30 |
| X=150, P=600 | 177.48 | 168.57 | **+17.45** | -13.03 |

Legs 0 and 1 are identical pools with equal RP at rest, so their BPT is valued 1:1. The hook's LP book loses about 1.6% of TVL per transaction in the P=600 run. The attack leaves no persistent state change, so it can be repeated.

Run:
```
FOUNDRY_PROFILE=audit forge test --match-path .../probe-se-rate-provider/QuadStableBptRateManip.t.sol -vv --match-test lp200
FOUNDRY_PROFILE=audit forge test --match-path .../probe-se-rate-provider/RateMeasure.t.sol -vv
```

## Limits
- **Not live.** No Balancer V3 pool family and no Curve or Balancer quad hook is deployed on Robinhood 4663. The live RPs are over a UniV4 FullSpread SE and a RebasingAware 4626, and the live consumer is the scale-invariant weighted hook.
- **Large manipulation relative to the pool.** The push is 30-60% of the Balancer pool's face reserve, and the hook holds about 20% of each pool. Profit grows with X * dRP/RP minus about 2 * fee * P, so it needs a cheap-fee stable BPT pool that is shallow relative to the quad hook.
- **Static mispricing with mixed legs.** A quad that mixes a BPT-as-SE leg with legs whose RP is correct is already mispriced at rest by about 1/N (RP 0.5 vs value 0.975). That was not tested.
- **Severity: medium as a latent issue.** It is high if a stable or quad consumer over a BPT-as-SE leg is deployed.

## Fix
Do not value a BPT-as-SE leg with a full-book single-token liquidation. Use the proportional or invariant-based BPT value (e.g. invariant * rate / supply), or the marginal unit exit. Bound or TWAP the provider. Alternatively, reject BPT-as-SE subjects in quad and orbital packages.

## Reviewer pass (adversarial review, 2026-10-21)
I re-ran the test on t4: all 4 attack and control tests pass, and the numbers match the table above. The anti-cheat checks are clean:
- The attacker is the unprivileged harness bob.
- The only setup-time configuration is the Balancer fee (0.1%, inside the package bounds of 0.01% to 10%) and the quad fee.
- There is no prank, store, etch or mock on protocol contracts during the attack.
- The flash principal is included in sStart, so it is implicitly repaid, and the 0.1% fee is deducted.

Caveat found in ReviewDecompose.t.sol (numeraire 1:1):
- In both the attack and the control, pool1 mints extra BPT to the hook on the hook's single-sided exit-then-rejoin. Pool balances end identical while supply rises, so pool1's outside LPs are diluted (-6.49 at P=600, -2.39 at P=300, -1.88 in the control). This is a separate pool join/exit anomaly, likely the computeBalance issue noted above.
- Part of that extra BPT reaches the attacker through the leg1 credit.
- Conservative bound: subtract the entire pool1 dilution from the attacker's profit. The result is +10.96 face0 (P=600, asserted) and +2.13 face0 (P=300).
- The hook's gross leg0 loss is about -20.1, partly offset by the +6.5 BPT it gains on leg1 from pool1's LPs.

Verdict: valid. The profit driven by the rate manipulation is still clearly positive, but the headline +17.45 overstates the share from this bug alone (lower bound about +11).
