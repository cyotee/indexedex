# Morpho Blue liquidation

## Contents

- When liquidatable
- Call shape
- Incentives

## When

A position is liquidatable when collateral value (oracle × coll) is insufficient for borrow at LLTV (health factor < 1 after accrual). Exact condition is enforced in Blue liquidate path.

## Call

```solidity
// Seize collateral amount OR repay shares — follow Blue API (one path per call style)
morpho.liquidate(
    marketParams,
    borrower,
    seizedAssets,   // collateral to seize (or 0)
    repaidShares,   // debt shares to repay (or 0)
    data            // optional callback
);
```

Liquidator must have loan tokens for the repaid debt (unless callback funds it).

## Incentives

Blue applies liquidation incentive bounded by `MAX_LIQUIDATION_INCENTIVE_FACTOR` and `LIQUIDATION_CURSOR` (see `ConstantsLib`). Prefer reading upstream liquidate integration tests under:

`test/foundry/spec/protocols/lending/morpho/blue/upstream/integration/LiquidateIntegrationTest.sol`
