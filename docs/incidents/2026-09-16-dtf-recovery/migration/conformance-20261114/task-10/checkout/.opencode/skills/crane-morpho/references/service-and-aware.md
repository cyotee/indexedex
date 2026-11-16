# MorphoBlueService & AwareRepo

## Contents

- AwareRepo storage
- Service functions
- Diamond vs EOA

## AwareRepo

Slot: `protocols.lending.morpho.blue.aware`

```solidity
MorphoBlueAwareRepo._initialize(morpho, adaptiveCurveIrm, chainlinkOracleV2Factory);
IMorpho m = MorphoBlueAwareRepo._morpho();
address irm = MorphoBlueAwareRepo._adaptiveCurveIrm();
```

## Service (selected)

| Function | Purpose |
|----------|---------|
| `_id(MarketParams)` | Market id |
| `_createMarket` | Permissionless create |
| `_supply` / `_withdraw` | Loan side |
| `_supplyCollateral` / `_withdrawCollateral` | Collateral |
| `_borrow` / `_repay` | Debt |
| `_liquidate` | Liquidation (approves loan token max then clears) |
| `_expectedSupplyAssets` / `_expectedBorrowAssets` | View accrual helpers |
| `_accrueInterest` | Accrue |

Structs (`SupplyParams`, `BorrowParams`, …) avoid stack-too-deep.

## Diamond vs EOA

| Caller | Pattern |
|--------|---------|
| Diamond holds inventory | `MorphoBlueService._*` after transfer/approve to self |
| EOA tests | `vm.prank` + direct `morpho.supply(...)` |
| Handler fuzz | Direct Morpho; track expected shares in handler |
