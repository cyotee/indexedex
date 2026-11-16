# Morpho Blue full lifecycle

## Contents

- Hermetic sequence
- Exact asserts pattern
- Interest accrual

## Hermetic sequence (recommended)

1. Deploy Morpho(owner), AdaptiveCurveIRM(morpho), OracleMock, mintable ERC-20s  
2. Owner: `enableIrm(irm)`, `enableLltv(lltv)`  
3. `createMarket(MarketParams{loan, coll, oracle, irm, lltv})`  
4. Supplier: approve + `supply`  
5. Borrower: `supplyCollateral` + `borrow`  
6. Optional: `vm.warp` + `accrueInterest`  
7. Borrower: `repay` full shares  
8. Borrower: `withdrawCollateral`  
9. Supplier: `withdraw` full supply shares  

Crane reference: `test/foundry/spec/protocols/lending/morpho/blue/unit/MorphoBlueLifecycle.t.sol`  
and `TestBase_MorphoBlue`.

## Assets vs shares

For `supply` / `withdraw` / `borrow` / `repay`:

- Pass **either** `assets > 0` **or** `shares > 0`, not both.
- Zero-zero reverts; both non-zero reverts.

## Interest

```solidity
vm.warp(block.timestamp + 30 days);
morpho.accrueInterest(marketParams);
// totalBorrowAssets / totalSupplyAssets increase when utilization > 0
```

Use `MorphoBalancesLib.expectedBorrowAssets(morpho, params, user)` for debt including pending interest without mutating state.
