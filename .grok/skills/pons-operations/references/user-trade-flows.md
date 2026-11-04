# pons user trade and graduation flows

Sources: https://docs.ponsfamily.com/ · https://docs.ponsfamily.com/v2 · fetched 2026-07-29

## Wallet and network

1. Connect a wallet that supports Robinhood Chain.
2. Ensure **chain ID 4663**.
3. Fund with:
   - **ETH** for gas + (v1) WETH trades / wrap path as UI requires.
   - **v2 custom pairs:** the pairing ERC-20 (plus gas ETH).

Public RPC: `https://rpc.mainnet.chain.robinhood.com`  
Explorer: https://robinhoodchain.blockscout.com

## Pricing vocabulary (v1 UI)

| Term | Meaning |
|------|---------|
| Price | Live pool price for one token |
| Market cap | Price × circulating supply |
| FDV | Price × full supply (v1 fixed supply → often equals mcap unless burns) |
| Price impact | Pool movement from your trade size |
| Slippage | Max execution movement you accept |
| Liquidity | Assets available near current price |

Price comes from the live pool; received amount can differ from quote.

## v1 trade path

```text
Wallet → pons UI (or V3 router) → token/WETH Uniswap V3 pool (fee 1%)
```

1. Open token page; verify contract address.
2. Select buy (WETH → token) or sell (token → WETH).
3. Set amount and slippage.
4. Approve token if selling; confirm swap.
5. Check receipt on explorer.

**Launch window:** first two blocks restrict buys (creator-only on launch block; then 5% / 5.5% caps). Sells always allowed.

**Graduation:** progress toward default **4.2 ETH** paired principal. When graduated, **keep using the same pool** — nothing migrates.

## v2 trade path

### Pre-graduation (curve)

```text
Wallet → curve.buy(quoteIn, minTokensOut, recipient)  // or sell(...)
```

- Fees charged in the **quote asset**, never as a surprise fee in the launch token.
- Large buys move price more (same as thin liquidity).
- Curve always buys back — exit possible before graduation.
- If buy exceeds remaining sellable allocation: fill up to allocation, refund excess quote, possibly emit refund event.

### Post-graduation (Uniswap V4)

```text
Wallet → any V4-aware router/aggregator → pool (token + quote, fee 0, pons hook)
```

- Pool charges **no** core LP fee; hook applies pons fee policy.
- Holding does not change at graduation; only venue changes.
- If UI shows phase Swept (1): wait or trigger permissionless pool creation; do not expect curve trades (`CurveGraduated`).

### Custom pairs

- Quotes and graduation targets are in the **pair asset**, not ETH.
- Pair asset can fall in USD while launch “price in pair” rises — watch both.
- Approve pair token for the **curve** (pre-grad) or appropriate router (post-grad).

## Graduation progress (how to read UI)

| Gen | Progress heuristic |
|-----|-------------------|
| v1 | Paired principal / threshold from `graduationStatus` |
| v2 | `realQuoteReserve / graduationThreshold` **or** tokens sold vs tradable allocation (docs: both agree by construction) |

Neither is a recommendation to buy or hold.
