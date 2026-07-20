# modeA_trade_usdc

**Tracked notes.** Generated charts/data: `research/out/uniswapV2Se/modeA_trade_usdc/`.  
**Reproduce:** `./research/run_mode_a.sh` · **Summary:** [`MODE_A_FINDINGS.md`](./MODE_A_FINDINGS.md)

## One-line story

Market repeatedly buys **WETH** from our Uni V2 WETH/USDC LP (flow: USDC → WETH). SE rates and Balancer share-pool mids re-mark; Alice holds the full matrix book.

## Setup

- Product: Uni V2 SE + rate × pair Balancer matrix
- Init: 1 WETH = 1000 USDC; half circulating LP in SE vault
- Drive: `Script_ModeA_TradeUsdc` — 1000 USDC exact-in × 24
- Book: alice full-exit mark in USDC (Balancer → redeem SE → remove Uni LP)

## Charts (read in this order)

| File | Role |
|------|------|
| `rates.png` | SE foundation — rate(WETH)/rate(USDC) vs Uni |
| `price_index.png` | Five markets (Uni + 4 Balancer mids) |
| `pnl_normalized.png` | P&L as fraction of start book |
| `pnl.png` | Absolute USDC + isolated fee panel |
| `inventory.png` | Full-exit token claims (often ~flat qty; see caveats) |

## End numbers (step 24)

| Metric | Value |
|--------|--------|
| Uni USDC/WETH index | **1.00480** |
| SE rate(WETH) index | **0.99761** |
| SE rate(USDC) index | **1.00240** |
| `rateWeth × uni` | **= rateUsdc** (exact) |
| WETH-rated mid index | **1.00239** (≈ 1/rateWeth) |
| USDC-rated mid index | **0.99761** (≈ 1/rateUsdc) |
| Total P&L / start | **+0.479%** |
| Fee P&L | **+7.33 USDC** |

## What the price chart shows

1. Black Uni **USDC/WETH** rises (WETH dearer).
2. Blue/cyan (**WETH-rated**) move **with** Uni mid-index sense via inverse rate (mids up as rateWeth down).
3. Red/orange (**USDC-rated**) move **opposite**.
4. Same rate target ⇒ **identical** index paths.

## What the rate chart shows

- Pool sold WETH → each share claims less WETH, more USDC → `rateWeth↓`, `rateUsdc↑`.
- Consistency check holds: share has one claim, two numeraires.

## What the P&L charts show

- Normalized total ≈ **+0.48%**, almost entirely **price P&L** (WETH mark-up in USDC).
- Fees **+7.3 USDC**, positive but negligible vs book size.
- Absolute `pnl.png` y-axis is huge (~1e12 USDC start) — prefer normalized.

## Why (mechanism)

Uni reserves tilt → SE rate providers update → Balancer `liveShares` scale with rate → frozen inventory ⇒ `mid_t/mid_0 = rate_0/rate_t`.

## Caveats

- Hermetic shock, not APY.
- Full book includes large Balancer **pair** legs; token-qty inventory indices stay near 1.0.
- See sibling run `modeA_trade_weth` for the mirror / “fees green, total red” case.
- Cross-run summary: [`MODE_A_FINDINGS.md`](./MODE_A_FINDINGS.md)

## Commands

```bash
./research/run_mode_a.sh
# or single-run:
forge script scripts/foundry/research/uniswapV2Se/Script_ModeA_TradeUsdc.s.sol:Script_ModeA_TradeUsdc -vv
python research/plots/plot_all_mode_a.py research/out/uniswapV2Se/modeA_trade_usdc
```
