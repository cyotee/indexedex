# Morpho components (detail)

## Contents

- Blue contracts
- Types
- IRM / oracles
- Vaults & bundler

## Blue contracts (vendored)

| File | Role |
|------|------|
| `Morpho.sol` | Singleton markets + positions |
| `interfaces/IMorpho.sol` | `MarketParams`, `Market`, `Position`, `Id`, ops |
| `libraries/MarketParamsLib.sol` | `id()` |
| `libraries/SharesMathLib.sol` | Assets ↔ shares |
| `libraries/MathLib.sol` | WAD math, Taylor compound |
| `libraries/periphery/MorphoLib.sol` | Storage helpers |
| `libraries/periphery/MorphoBalancesLib.sol` | Expected balances with accrual |

## Core types

```solidity
struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;   // IOracle.price() → 1e36 scale
    address irm;      // IIrm.borrowRate / borrowRateView
    uint256 lltv;     // WAD, e.g. 0.86e18
}

struct Position {
    uint256 supplyShares;
    uint128 borrowShares;
    uint128 collateral;
}

struct Market {
    uint128 totalSupplyAssets;
    uint128 totalSupplyShares;
    uint128 totalBorrowAssets;
    uint128 totalBorrowShares;
    uint128 lastUpdate;
    uint128 fee; // WAD
}
```

## IRM & oracles

| Package | Main types |
|---------|------------|
| `blue-irm` | `AdaptiveCurveIrm`, `IAdaptiveCurveIrm` |
| `blue-oracles` | `MorphoChainlinkOracleV2`, factory |

Oracle interface is minimal: `function price() external view returns (uint256)`.

## Vaults & bundler

| Package | Entry points |
|---------|--------------|
| MetaMorpho V1.1 | `MetaMorphoV1_1`, `MetaMorphoV1_1Factory` |
| Public Allocator | `PublicAllocator.reallocateTo` |
| Vault V2 | `VaultV2`, `VaultV2Factory`, MarketV1/VaultV1 adapters |
| Bundler3 | `Bundler3.multicall(Call[])` + `GeneralAdapter1` |
