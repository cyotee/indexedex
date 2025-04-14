# Task IDXEX-031: Fix FeeCollectorManagerFacet Missing syncReserves Selector

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-02
**Priority:** MEDIUM
**Dependencies:** None
**Worktree:** `feature/fix-fee-collector-syncreserves-selector`

---

## Description

`FeeCollectorManagerFacet.facetFuncs()` only returns selectors for `syncReserve` and `pullFee`, but `IFeeCollectorManager` also declares `syncReserves(IERC20[])`. The target implements this function, and the interface declares it, but the facet doesn't expose it.

This means calls to `syncReserves` on the fee collector proxy will likely not be routed correctly.

Additionally, this is inconsistent with `FeeCollectorDFPkg.facetInterfaces()` which advertises `type(IFeeCollectorManager).interfaceId`.

**Source:** REVIEW_REPORT.md lines 96-105

## User Stories

### US-IDXEX-031.1: Expose syncReserves Selector

As a protocol operator, I want to call `syncReserves(IERC20[])` on the fee collector proxy.

**Acceptance Criteria:**
- [ ] `FeeCollectorManagerFacet.facetFuncs()` includes `syncReserves.selector`
- [ ] Calls to `syncReserves` on proxy route to target correctly
- [ ] ERC165 `supportsInterface` for `IFeeCollectorManager` is accurate

### US-IDXEX-031.2: Add Selector Surface Tests

As a security auditor, I want tests proving the fee collector proxy exposes all interface selectors.

**Acceptance Criteria:**
- [ ] Test: `syncReserve(IERC20)` callable via proxy
- [ ] Test: `syncReserves(IERC20[])` callable via proxy
- [ ] Test: `pullFee(IERC20,uint256,address)` callable via proxy
- [ ] Test: ERC165 compliance check for `IFeeCollectorManager`

## Technical Details

**File to modify:** `contracts/fee/collector/FeeCollectorManagerFacet.sol`

**Current:**
```solidity
function facetFuncs() public pure override returns (bytes4[] memory) {
    bytes4[] memory funcs_ = new bytes4[](2);
    funcs_[0] = IFeeCollectorManager.syncReserve.selector;
    funcs_[1] = IFeeCollectorManager.pullFee.selector;
    return funcs_;
}
```

**Fixed:**
```solidity
function facetFuncs() public pure override returns (bytes4[] memory) {
    bytes4[] memory funcs_ = new bytes4[](3);
    funcs_[0] = IFeeCollectorManager.syncReserve.selector;
    funcs_[1] = IFeeCollectorManager.syncReserves.selector;  // ADD THIS
    funcs_[2] = IFeeCollectorManager.pullFee.selector;
    return funcs_;
}
```

## Files to Create/Modify

**Modified Files:**
- `contracts/fee/collector/FeeCollectorManagerFacet.sol` - Add `syncReserves.selector`

**Tests:**
- `test/foundry/spec/fee/collector/FeeCollectorProxy_Selectors.t.sol` - Selector surface tests

## Inventory Check

Before starting, verify:
- [ ] Locate `FeeCollectorManagerFacet.facetFuncs()`
- [ ] Confirm `IFeeCollectorManager` declares `syncReserves(IERC20[])`
- [ ] Confirm `FeeCollectorManagerTarget` implements `syncReserves`

## Completion Criteria

- [ ] `facetFuncs()` includes all 3 selectors
- [ ] Selector surface tests pass
- [ ] Build succeeds
- [ ] Existing tests pass

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
