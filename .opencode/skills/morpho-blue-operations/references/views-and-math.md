# Morpho Blue views and math

## Contents

- Position / market reads
- MorphoBalancesLib
- MorphoLib
- Constants

## Direct reads

```solidity
Position memory p = morpho.position(id, user);
Market memory m = morpho.market(id);
MarketParams memory mp = morpho.idToMarketParams(id);
```

## MorphoBalancesLib (with pending interest)

```solidity
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
using MorphoBalancesLib for IMorpho;

uint256 supplyAssets = morpho.expectedSupplyAssets(params, user);
uint256 borrowAssets = morpho.expectedBorrowAssets(params, user);
(uint256 totalSupply, uint256 totalSupplyShares, uint256 totalBorrow, uint256 totalBorrowShares) =
    morpho.expectedMarketBalances(params);
```

## Constants (`ConstantsLib`)

| Name | Value / meaning |
|------|-----------------|
| `ORACLE_PRICE_SCALE` | `1e36` |
| `MAX_FEE` | `0.25e18` |
| `LIQUIDATION_CURSOR` | `0.3e18` |
| `MAX_LIQUIDATION_INCENTIVE_FACTOR` | `1.15e18` |

## WAD

IRM and LLTV use WAD (`1e18`). Shares math uses virtual assets/shares offsets (see `SharesMathLib`).
