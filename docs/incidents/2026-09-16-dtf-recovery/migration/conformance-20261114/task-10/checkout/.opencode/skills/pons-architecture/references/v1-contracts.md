# pons v1 — contracts and parameters

Source: https://docs.ponsfamily.com/ · https://docs.ponsfamily.com/llms.txt · fetched 2026-07-29

## Network

| Item | Value |
|------|--------|
| Chain ID | 4663 |
| RPC | `https://rpc.mainnet.chain.robinhood.com` |
| Explorer | https://robinhoodchain.blockscout.com |
| Pool fee | 10000 (1%) |
| Launch fee | 0.0005 ETH |
| Supply | 1,000,000,000 (1e9 tokens; 18 decimals with WETH) |
| Default graduation threshold | 4.2 ETH paired principal |

## Deployed addresses (Robinhood Chain)

### Active (start block 8991118)

| Contract | Address |
|----------|---------|
| Active factory | `0xA5aAb3F0c6EeadF30Ef1D3Eb997108E976351feB` |
| Active locker | `0x736D76699C26D0d966744cAe304C000d471f7F35` |

### Legacy (start block 8600612)

| Contract | Address |
|----------|---------|
| Legacy factory | `0x0c37a24F5D23A486FA692d1500881d698B1F77a4` |
| Legacy locker | `0x31ca5E101941A93A7DD6d0497928700625CF54B5` |

### Uniswap V3 stack (shared)

| Contract | Address |
|----------|---------|
| V3 factory | `0x1f7d7550B1b028f7571E69A784071F0205FD2EfA` |
| Position manager | `0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3` |
| Swap router | `0xCaf681a66D020601342297493863E78C959E5cb2` |
| Quoter V2 | `0x33e885eD0Ec9bF04EcfB19341582aADCb4c8A9E7` |
| WETH (quote) | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` |

## Fee splits

| Factory era | Creator | Protocol | From block |
|-------------|---------|----------|------------|
| Current launches | 70% | 30% | 8991118 |
| Legacy launches | 90% | 10% | 8600612 |

Split is **snapshotted per token at launch** and never changes. Creator rewards accrue on the locked position; claim via interface or protocol automation to payout wallet.

## Launch protection

- Buys protected for first **two blocks** after launch.
- Launch block: only creator's initial buy.
- Rest of window: each wallet ≤ **5%** of supply held and ≤ **5.5%** of supply bought.
- Selling and wallet-to-wallet transfers never restricted.
- Limits end at `restrictionsEndBlock` on factory launch record.

## Reference token (PONS)

For indexer/integration validation against known state:

| Field | Value |
|-------|--------|
| Token | `0x39dBED3a2bd333467115dE45665cC57F813C4571` |
| Pool | `0x10CC6BD38112cAc182db90B6a71d8Bb5939526bA` |
| Launch tx | `0x1f54f25fec2d963dcb338ecb8b46a6eb123198a5c7a746d34cb2dbe78d074af8` |
| Notes | Graduated; same-pool trading; **legacy factory** |

## Convenience HTTP APIs (not trust root)

From llms.txt — optional UX only; onchain events remain authoritative:

- Launch feed: `https://ponsfamily.com/api/pons-launches`
- Token details: `https://ponsfamily.com/api/pons-token/{token}`
- Token market: `https://ponsfamily.com/api/pons-market/{token}`

## Versioning

Deployed contracts are immutable. New versions ship as new factory/locker addresses listed under Contracts in the docs.
