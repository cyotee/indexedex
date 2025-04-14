# Progress Log: IDXEX-064

## Current Checkpoint

**Last checkpoint:** Implementation complete
**Next step:** Code review / merge
**Build status:** Pass
**Test status:** Pass (1027 passed, 0 failed, 1 skipped)

---

## Session Log

### 2026-02-08 - Implementation Complete

**Problem:**
`SeigniorageDETFUnderwritingTarget.previewClaimLiquidity()` used `getCurrentLiveBalances()` which returns balances scaled by token rates (liveScaled18). The execution path in `_removeLiquidityFromPool()` uses `getPoolTokenInfo().balancesRaw` (raw token units). Since `calcProportionalAmountsOutGivenBptIn` returns amounts in the same unit as input balances, the preview was returning inflated (scaled) values while execution returns raw values.

**Root cause:**
Line 668 of `SeigniorageDETFUnderwritingTarget.sol` called `balV3Vault.getCurrentLiveBalances(address(reservePool_))` instead of destructuring `balV3Vault.getPoolTokenInfo(address(reservePool_))` to get `balancesRaw`.

**Fix:**
Changed `SeigniorageDETFUnderwritingTarget.sol:668` from:
```solidity
uint256[] memory currentBalances = balV3Vault.getCurrentLiveBalances(address(reservePool_));
```
to:
```solidity
(,, uint256[] memory currentBalances,) = balV3Vault.getPoolTokenInfo(address(reservePool_));
```

This matches the execution path at line 530 of the same file.

**Protocol DETF not affected:**
`ProtocolDETFBondingTarget.previewClaimLiquidity()` uses `calcSingleOutGivenBptIn` (weighted math) which correctly expects liveScaled18 balances and then converts the result to raw via `divDown(result, rate)`. Both preview and execution use the same `_loadReservePoolData()` -> `getCurrentLiveBalances()` path, so they are already consistent.

**Files changed:**
- `contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol` (line 668)

**References:**
- Execution path: `SeigniorageDETFUnderwritingTarget.sol:530` (`_removeLiquidityFromPool`)
- Reference pattern: `SeigniorageDETFUnderwritingTarget.sol:201` (uses `balancesRaw` from `getPoolTokenInfo`)

### 2026-02-08 - Task Created

- Task skeleton created from report summary
- Ready for agent launch
