# Common token addresses

**Fail closed:** if the chain is not listed, do not invent addresses.

| Chain | Chain ID | Symbol | Address | Notes |
|-------|----------|--------|---------|-------|
| Ethereum | 1 | WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | Canonical WETH9 |
| Ethereum | 1 | USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6 decimals |
| Base | 8453 | WETH | `0x4200000000000000000000000000000000000006` | OP-stack WETH |
| Base | 8453 | USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | native USDC |
| Base Sepolia | 84532 | WETH | `0x4200000000000000000000000000000000000006` | verify on-chain |
| Sepolia / IndexedEx | *project* | *test tokens* | use IndexedEx deployment tokenlists | fail closed if missing |

Permit2 (canonical multi-chain): `0x000000000022D473030F116dDEE9F6B43aC78BA3`
