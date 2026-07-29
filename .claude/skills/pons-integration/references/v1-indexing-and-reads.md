# pons v1 — indexing, reads, and trading surface

Source: https://docs.ponsfamily.com/ · fetched 2026-07-29

## Addresses (recap)

| Role | Address |
|------|---------|
| Active factory | `0xA5aAb3F0c6EeadF30Ef1D3Eb997108E976351feB` (from block 8991118) |
| Active locker | `0x736D76699C26D0d966744cAe304C000d471f7F35` |
| Legacy factory | `0x0c37a24F5D23A486FA692d1500881d698B1F77a4` (from block 8600612) |
| Legacy locker | `0x31ca5E101941A93A7DD6d0497928700625CF54B5` |
| V3 factory | `0x1f7d7550B1b028f7571E69A784071F0205FD2EfA` |
| Position manager | `0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3` |
| Swap router | `0xCaf681a66D020601342297493863E78C959E5cb2` |
| Quoter V2 | `0x33e885eD0Ec9bF04EcfB19341582aADCb4c8A9E7` |
| WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` |

## Event topics

| Event | topic0 |
|-------|--------|
| `TokenLaunched` | `0xdb51ea9ad51ab453a65a4cb7e60c3cb378c9501bb002609f8f97778fb6c4235a` |
| `Swap` (Uniswap V3) | `0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67` |

## Index launches (viem)

```ts
import { createPublicClient, http, parseAbiItem } from "viem";

const client = createPublicClient({
  chain: {
    id: 4663,
    name: "Robinhood Chain",
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: { default: { http: ["https://rpc.mainnet.chain.robinhood.com"] } },
  },
  transport: http(),
});

const launches = await client.getLogs({
  address: "0xA5aAb3F0c6EeadF30Ef1D3Eb997108E976351feB",
  event: parseAbiItem(
    "event TokenLaunched(address indexed token, address indexed deployer, address indexed dexFactory, address pairToken, address pool, uint256 dexId, uint256 launchConfigId, uint256 positionId, uint256 restrictionsEndBlock, uint256 initialBuyAmount)",
  ),
  fromBlock: 8991118n, // chunk upward; do not pull entire range at once
  toBlock: 8991118n + 2000n,
});
```

Register each emitted `pool` and index its `Swap` events. Optionally index token `Transfer` for holders. **No migration event** — poll graduation.

## Buy vs sell side

```text
tokenIsToken0 = token < pairToken
pairSigned    = tokenIsToken0 ? amount1 : amount0
side          = pairSigned > 0 ? "buy" : "sell"
```

## Token self-description

```ts
const tokenAbi = parseAbi([
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function totalSupply() view returns (uint256)",
  "function logo() view returns (string)",
  "function description() view returns (string)",
  "function liquidityPool() view returns (address)",
  "function socials() view returns (string twitter, string telegram, string discord, string website, string farcaster)",
]);
```

## Factory launch record

```ts
// getLaunchedToken(token) returns struct including:
// token, deployer, pairedToken, positionManager, positionId, dexId,
// launchConfigId, restrictionsEndBlock, supply, isToken0, poolFee, exists, initialBuyAmount
```

`isToken0` is required for pricing and trade direction. `poolFee` is **10000** (1%). Supply is fixed `1e9 * 1e18`.

## Pricing from slot0

Both token and WETH use 18 decimals → no decimal scaling between them.

```ts
// slot0().sqrtPriceX96
// ratio = sqrtPriceX96 / 2^96
// token1PerToken0 = ratio^2
// priceInWeth = isToken0 ? token1PerToken0 : 1 / token1PerToken0
// priceUsd = priceInWeth * ethUsd  // e.g. DeFiLlama as used by pons UI
// marketCapUsd = priceUsd * (supply / 1e18)
// FDV ≈ market cap unless burns (burn-adjusted mcap uses burned supply)
```

**Note:** casting full uint160 to JS `Number` loses precision for production indexers — use bigint fixed-point math in real systems. Docs show the ratio approach for clarity.

## Graduation

```ts
// graduationStatus(token) → (pairedPrincipal, threshold, graduated)
// progress = pairedPrincipal / threshold  // 0..1 UI line
```

Default threshold **4.2 ETH**. Trading continues in the **same** pool after graduation.

## Fee split and payout wallet

Resolve locker from factory `locker()` rather than hardcoding when possible.

```ts
// locker.tokenProtocolFeeShares(token) → protocol share
// creatorSharePercent = 100 - protocolShare
// locker.feeRedirects(token) → redirect; if zero, payout = deployer
// locker.protocolFeeRecipient()
```

## Reference token

| Field | Value |
|-------|--------|
| Token | `0x39dBED3a2bd333467115dE45665cC57F813C4571` |
| Pool | `0x10CC6BD38112cAc182db90B6a71d8Bb5939526bA` |
| Notes | Legacy factory; graduated |

## Trading execution

Use standard Uniswap V3 exact-in/out against the launch pool via:

- Swap router `0xCaf681a66D020601342297493863E78C959E5cb2`
- Quoter V2 `0x33e885eD0Ec9bF04EcfB19341582aADCb4c8A9E7`

Respect launch-window restrictions when simulating early buys.
