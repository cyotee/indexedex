# High-volume rateProviderCompare

## Locked choices

| Axis | Choice |
|------|--------|
| Balancer swap fee | **Unchanged** (const-prod package default `5e16` = 5%) |
| Volume levers | **tradeSizeMul** and **tradeSteps** (not fee) |
| Baseline | **Not overwritten** |

## Tiers

| Tier | mul | steps | Artifact tree | Mode C outcome |
|------|-----|-------|---------------|----------------|
| mul10 | 10 | 24 | `highVol/mul10/` | Residual ~±2.4%; **probes 0** (fee-drowned) |
| **mul25_steps48** | **25** | **48** | `highVol/mul25_steps48/` | Residual ~**±10%** Mode A R−; **probes + fills** from ~step 22 |

## Reproduce

```bash
./research/run_rate_provider_compare.sh --high-vol          # mul10
./research/run_rate_provider_compare.sh --high-vol-25s48    # mul25 steps48 (arb apparent)
```

## Success criteria (mul25_steps48)

- Full 8-run matrix completes.
- R− residual **≫** baseline and **> fee scale** on Mode A.
- Mode C: **positive maxBuy/maxSell probes and non-zero fills** (R− proven; R+ also fills under stress — document).
- Next product step: use **pool fee as arb presentation threshold**.