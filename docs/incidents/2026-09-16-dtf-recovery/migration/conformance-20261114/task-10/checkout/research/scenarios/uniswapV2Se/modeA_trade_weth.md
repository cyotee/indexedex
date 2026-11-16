# modeA_trade_weth

**Tracked notes.** Generated charts/data: `research/out/uniswapV2Se/modeA_trade_weth/`.  
**Reproduce:** `./research/run_mode_a.sh` · **Summary:** [`MODE_A_FINDINGS.md`](./MODE_A_FINDINGS.md)

## One-line story

Market repeatedly buys **USDC** from our Uni V2 LP (flow: WETH → USDC). Mirror of `modeA_trade_usdc`. Best run for “fees can be green while USDC-marked total is red.”

## Setup

- Product: Uni V2 SE + rate × pair Balancer matrix
- Init: 1 WETH = 1000 USDC; half circulating LP in SE vault
- Drive: `Script_ModeA_TradeWeth` — 1 WETH exact-in × 24
- Book: alice full-exit mark in USDC

## Charts (read in this order)

| File | Role |
|------|------|
| `rates.png` | SE foundation — rate(WETH)/rate(USDC) vs Uni |
| `price_index.png` | Five markets |
| `pnl_normalized.png` | P&L / start book |
| `pnl.png` | Absolute USDC + fee panel |
| `inventory.png` | Full-exit claims (qty often flat) |

## End numbers (step 24)

| Metric | Value |
|--------|--------|
| Uni USDC/WETH index | **0.99522** |
| SE rate(WETH) index | **1.00240** |
| SE rate(USDC) index | **0.99761** |
| `rateWeth × uni` | **= rateUsdc** (exact) |
| WETH-rated mid index | **0.99761** |
| USDC-rated mid index | **1.00239** |
| Total P&L / start | **−0.477%** |
| Fee P&L | **+7.29 USDC** |

## What the price chart shows

1. Uni **USDC/WETH** falls (WETH cheaper).
2. WETH-rated mids fall with inverse-rate path; USDC-rated rise.
3. Same rating ⇒ same path.

## What the rate chart shows

- Pool sold USDC → each share claims **more WETH**, **less USDC** → `rateWeth↑`, `rateUsdc↓`.
- Again `rateWeth × uni = rateUsdc`.

## What the P&L charts show

- Normalized total ≈ **−0.48%**, dominated by **price** (WETH mark-down in USDC).
- Fees still **+7.3 USDC** (maker income).
- Teaching line: **strategy income (fees) ≠ total USDC mark under directional flow.**

## Why (mechanism)

Same as `modeA_trade_usdc`, opposite demand. Numeraire = USDC makes WETH-down look like a loss even though inventory composition is the natural LP outcome.

## Caveats

- Hermetic; not live APY.
- Prefer normalized P&L; absolute book scale is dominated by Balancer pair legs.
- Cross-run summary: [`MODE_A_FINDINGS.md`](./MODE_A_FINDINGS.md)

## Commands

```bash
./research/run_mode_a.sh
# or single-run:
forge script scripts/foundry/research/uniswapV2Se/Script_ModeA_TradeWeth.s.sol:Script_ModeA_TradeWeth -vv
python research/plots/plot_all_mode_a.py research/out/uniswapV2Se/modeA_trade_weth
```
