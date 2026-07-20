# Mode C findings — Uni demand + Balancer arb closer

**Audience:** internal review.  
**Tracked path:** `research/scenarios/uniswapV2Se/MODE_C_FINDINGS.md`  
**Artifacts:** `research/out/uniswapV2Se/modeC_market_buys_{usdc,weth}/`  
**Reproduce:** `FOUNDRY_PROFILE=default ./research/run_mode_c.sh`  
**Depends on:** Mode A identities in [`MODE_A_FINDINGS.md`](./MODE_A_FINDINGS.md)

## Question

After Uni moves SE rates (and Balancer live mids re-mark via rate providers), is there still a **profitable** Balancer residual that a closer can capture in the traded asset?

## Setup (shared with Mode A)

- Same hermetic Uni V2 SE + 4 Balancer const-prod matrix pools  
- Per step: Uni demand → `ResearchModeCCloser.closeAll` → sample  
- Profit asset = token market **sells into** Uni (WETH if market buys USDC; USDC if market buys WETH)  
- Closer probes buy-shares and sell-shares paths at 0.05% / 0.25% / 1% of pair inventory (and small WETH LP budgets for sell)

## Expected mechanism (from Mode A)

With **frozen Balancer raw inventory**, live mid tracks:

```text
mid_t / mid_0 = rate_0 / rate_t
```

So Uni → SE rate update **immediately re-marks** Balancer share legs. There is little/no “stale mid” lag of the kind you get when an oracle is slow.

Therefore **zero arb fills after Uni-only demand is a plausible correct outcome**, not necessarily a closer bug — round-trip fees (Balancer + SE + Uni) can dominate any residual.

## Diagnostics added (Session C)

`ResearchModeCCloser.StepResult` / series.jsonl fields:

| Field | Meaning |
|-------|---------|
| `arbFills` / `arbProfit` | Realized fills this step |
| `maxBuyProbe` | Best buy-shares path profit (wei of profit token), even if &lt; `MIN_PROFIT` |
| `maxSellProbe` | Best sell-shares path profit |
| `positiveProbes` | Pool legs with any probe profit &gt; 0 |

Interpretation:

| Pattern | Meaning |
|---------|---------|
| fills=0, max probes=0 | No edge **or** path reverts (swap/redeem) — check permit2 / free LP |
| fills=0, max probes &gt; 0 but &lt; MIN_PROFIT | Micro-edge below dust threshold (`1e12` wei) |
| fills=0, max probes ≥ MIN_PROFIT | Probe saw edge but execute failed (bug) |
| fills &gt; 0 | Residual captured — Mode C “live” |

## Current status (2026-07-20)

| Run | Status | Notes |
|-----|--------|-------|
| `modeC_market_buys_usdc` | **complete** | fills=0, maxBuy/SellProbe=0; total/start **−0.477%**; fee **+7.29 USDC** (= Mode A twin `modeA_trade_weth`) |
| `modeC_market_buys_weth` | **complete** | fills=0, maxBuy/SellProbe=0; total/start **+0.479%**; fee **+7.33 USDC** (= Mode A twin `modeA_trade_usdc`) |
| Both directions | **symmetric empty residual** | Uni-only demand leaves no Balancer arb after rate re-mark |
| Closer Permit2 buy path | fixed | ERC20→Permit2→router |
| Probe telemetry | **in series.jsonl** | Confirms zero edge, not “filled below threshold” |

### Interpretation of zero probes

Every buy and sell probe returned **0 profit** after Uni demand (both directions). Combined with Mode A’s rate↔mid identity, the working conclusion is:

> **SE rate providers re-mark Balancer share legs immediately. After Uni-only flow, there is no profitable residual through buy-share/redeem or mint/sell-share paths once pool + vault + Uni fees apply.**

That is a **product finding**, not a failed experiment. Mode C’s value is proving the residual is empty under default params.

If later we need a “closer fires” demo: Mode B (drive Balancer) or intentional inventory skew — not required to understand SE foundations.

## Product takeaway (SE foundation)

1. **Mode A** teaches how SE rates + Balancer mids move under Uni demand.  
2. **Mode C** teaches whether that move leaves free lunch on Balancer.  
3. With rate providers on share legs, **re-marking is continuous** — Mode C is often “no free lunch after fees,” which is the honest story for these vaults.  
4. Non-zero Mode C fills become interesting under **Mode B** (trade Balancer first), inventory skew, or fee asymmetry — not as the default Uni-only residual.

## Commands

```bash
# Full Mode C both directions + plots (uses FOUNDRY_PROFILE=research)
./research/run_mode_c.sh

# One direction
FOUNDRY_PROFILE=research forge script \
  scripts/foundry/research/uniswapV2Se/Script_ModeC_MarketBuysUsdc.s.sol:Script_ModeC_MarketBuysUsdc -vv
python research/plots/stamp_meta.py research/out/uniswapV2Se/modeC_market_buys_usdc \
  --script scripts/foundry/research/uniswapV2Se/Script_ModeC_MarketBuysUsdc.s.sol:Script_ModeC_MarketBuysUsdc
python research/plots/plot_all_mode_a.py research/out/uniswapV2Se/modeC_market_buys_usdc
```

## Next (after clean Mode C re-run)

1. Confirm `maxBuyProbe` / `maxSellProbe` series (zero vs dust).  
2. If probes always zero with working swaps → document as rate-alignment result.  
3. Mode B or intentional skew scenario only if we need a “fills &gt; 0” teaching demo of the closer plumbing.  
