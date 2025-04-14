# Task IDXEX-034: Fix StandardExchangeOut Pretransferred Refund Semantics

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-02
**Priority:** CRITICAL
**Dependencies:** None
**Worktree:** `feature/fix-standard-exchange-out-refund`

---

## Description

The `IStandardExchangeOut` interface documents: "Any pretransferred amount that exceeds `maxAmountIn` will be refunded to the caller." However, the Aerodrome, UniswapV2, and CamelotV2 StandardExchangeOut targets inherit `BasicVaultCommon._secureTokenTransfer`, which:
1. Returns full `tokenIn.balanceOf(this)` as transfer credit
2. Does NOT refund unused tokens in `pretransferred == true` mode

The Balancer V3 batch exact-out router assumes strategy vaults refund unused `tokenIn` to `msg.sender`. This cross-module mismatch can cause fund loss when `maxAmountIn > amountInUsed`.

**Source:** REVIEW_REPORT.md lines 386-448, 850-851, 909-917

## Impact Analysis

**Scenario:**
1. User calls batch router with `maxAmountIn = 1000` (pretransferred via Permit2)
2. Strategy vault only needs `amountIn = 800`
3. Expected: vault refunds 200 to router, router returns to user
4. Actual: vault keeps 200, user loses funds

**Affected contracts:**
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol`
- `contracts/vaults/basic/BasicVaultCommon.sol`

## User Stories

### US-IDXEX-034.1: Implement Pretransferred Refund Logic

As a vault user, I want unused tokens refunded when I pretransfer more than needed for an exact-out swap.

**Acceptance Criteria:**
- [ ] When `pretransferred == true`, vault tracks actual amount used
- [ ] Unused `tokenIn` is transferred back to `msg.sender` (router)
- [ ] Refund amount = pretransferred amount - actual amount used
- [ ] Works for all three affected targets (Aerodrome, UniswapV2, CamelotV2)

### US-IDXEX-034.2: Fix BasicVaultCommon._secureTokenTransfer

As a vault developer, I want `_secureTokenTransfer` to use balance-delta accounting so it returns the correct transfer amount.

**Acceptance Criteria:**
- [ ] `_secureTokenTransfer` uses balance-delta (balanceAfter - balanceBefore)
- [ ] Does NOT use full `balanceOf(this)` as return value

### US-IDXEX-034.3: Add Refund Tests

As a security auditor, I want tests proving refunds work correctly.

**Acceptance Criteria:**
- [ ] Test: `pretransferred == true` with `maxAmountIn > amountInUsed` → refund sent
- [ ] Test: refund bounded by actual received (no over-refund from dust)
- [ ] Test: `maxAmountIn` enforcement (revert if insufficient)
- [ ] Test: dust cannot cause over-refunds
- [ ] Test: integration with Balancer V3 batch router exact-out

## Technical Details

**Design Decision (bundled):** The intended `pretransferred` workflow should be that callers can transfer `maxAmountIn`, and vaults return unused amounts. This matches Balancer router assumptions and the interface documentation.

**Implementation approach:**

**Option A: Refund in each target**
Each `exchangeOut` implementation explicitly refunds:
```solidity
function exchangeOut(..., bool pretransferred) external returns (uint256 amountIn_) {
    uint256 balanceBefore;
    if (pretransferred) {
        balanceBefore = tokenIn.balanceOf(address(this));
    }

    // ... execute swap, compute amountIn_ ...

    if (pretransferred) {
        uint256 unused = balanceBefore - amountIn_;
        if (unused > 0) {
            tokenIn.safeTransfer(msg.sender, unused);
        }
    }
}
```

**Option B: Fix in BasicVaultCommon**
Create `_secureTokenTransferWithRefund` that handles both balance-delta and refund:
```solidity
function _secureTokenTransferWithRefund(
    IERC20 tokenIn_,
    uint256 maxAmountIn_,
    uint256 actualAmountUsed_,
    address sender_,
    bool pretransferred_
) internal returns (uint256) {
    if (pretransferred_) {
        uint256 unused = maxAmountIn_ - actualAmountUsed_;
        if (unused > 0) {
            tokenIn_.safeTransfer(sender_, unused);
        }
        return actualAmountUsed_;
    } else {
        return _secureTokenTransfer(tokenIn_, actualAmountUsed_, sender_);
    }
}
```

**Recommendation:** Option B provides a reusable pattern for all StandardExchangeOut targets.

## Files to Create/Modify

**Modified Files:**
- `contracts/vaults/basic/BasicVaultCommon.sol` - Fix `_secureTokenTransfer`, add refund helper
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol` - Use refund pattern
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol` - Use refund pattern
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol` - Use refund pattern

**Tests:**
- `test/foundry/spec/vaults/StandardExchangeOut_Refund.t.sol` - Refund behavior tests

## Inventory Check

Before starting, verify:
- [ ] Locate all `exchangeOut` implementations in affected targets
- [ ] Understand how `pretransferred` is used in each
- [ ] Check if `_refundExcess` already exists in SeigniorageDETFExchangeOutTarget (as a pattern)
- [ ] Confirm Balancer V3 router expects refund to `msg.sender`

## Completion Criteria

- [ ] All three targets implement refund logic
- [ ] BasicVaultCommon uses balance-delta accounting
- [ ] Refund tests pass
- [ ] Build succeeds
- [ ] All existing StandardExchangeOut tests pass
- [ ] Integration with Balancer V3 batch router works

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
