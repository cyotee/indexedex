# Vault V2 notes

## Contents

- Factory
- Adapters
- Share price risk

## Factory

```solidity
function createVaultV2(address owner, address asset, bytes32 salt) external returns (address);
```

Asset must implement `decimals()`.

## Adapters

| Adapter | Role |
|---------|------|
| `MorphoMarketV1AdapterV2` | Allocate to Morpho Blue markets (AdaptiveCurve IRM) |
| `MorphoVaultV1Adapter` | Allocate into MetaMorpho-style vaults |

`realAssets()` on adapters drives `totalAssets` / interest accrual. Too many adapters or heavy `realAssets` gas can DOS vault interactions.

## Crane

Domain only + smoke factory create. Full adapter configuration tests can build on hermetic Blue + MetaMorpho TestBases.
