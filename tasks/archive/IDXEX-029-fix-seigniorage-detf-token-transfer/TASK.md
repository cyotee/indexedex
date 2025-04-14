# Task IDXEX-029: Fix SeigniorageDETFCommon._secureTokenTransfer Balance Bug

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-02
**Priority:** CRITICAL
**Dependencies:** None
**Worktree:** `feature/fix-seigniorage-detf-token-transfer`

---

## Description

`SeigniorageDETFCommon._secureTokenTransfer` returns `actualIn_ = tokenIn_.balanceOf(address(this))` (full balance), not the delta for the current transfer. If the contract already holds `tokenIn_` (dust, prior refunds, or a pre-fund), `actualIn_` can be larger than what was transferred for the current call, causing downstream mint/burn math to over-credit users.

**Contrast:** `ProtocolDETFCommon._secureTokenTransfer` correctly uses balance-delta accounting.

**Source:** REVIEW_REPORT.md lines 479-491

## Impact Analysis

This is a potential fund loss vector:
1. If vault already holds dust of tokenIn (from fees, failed refunds, donations)
2. User deposits via `exchangeIn()`
3. `_secureTokenTransfer` returns dust + user's deposit as `actualIn_`
4. User receives vault shares based on inflated `actualIn_`
5. User can redeem more than they deposited

## User Stories

### US-IDXEX-029.1: Fix Balance-Delta Accounting

As a vault user, I want my deposit credited correctly so that I don't receive more or fewer shares than I'm entitled to.

**Acceptance Criteria:**
- [ ] `_secureTokenTransfer` records balance before transfer
- [ ] `_secureTokenTransfer` computes `actualIn_ = balanceAfter - balanceBefore`
- [ ] Works correctly for both ERC20 allowance and Permit2 paths
- [ ] Handles fee-on-transfer tokens (actual received < requested)

### US-IDXEX-029.2: Add Regression Tests

As a security auditor, I want tests proving that pre-existing balances don't inflate deposit credits.

**Acceptance Criteria:**
- [ ] Test: vault with dust balance, user deposits, receives correct shares (not dust + deposit)
- [ ] Test: Permit2 path uses balance-delta
- [ ] Test: ERC20 path uses balance-delta
- [ ] Test: fee-on-transfer token scenario

## Technical Details

**File to modify:** `contracts/vaults/seigniorage/SeigniorageDETFCommon.sol`

**Current (buggy):**
```solidity
function _secureTokenTransfer(IERC20 tokenIn_, uint256 amount_, address sender_)
    internal
    returns (uint256 actualIn_)
{
    if (tokenIn_.allowance(sender_, address(this)) < amount_) {
        Permit2AwareRepo._permit2().transferFrom(sender_, address(this), uint160(amount_), address(tokenIn_));
    } else {
        tokenIn_.safeTransferFrom(sender_, address(this), amount_);
    }
    actualIn_ = tokenIn_.balanceOf(address(this)); // BUG: full balance, not delta
}
```

**Fixed (match ProtocolDETFCommon pattern):**
```solidity
function _secureTokenTransfer(IERC20 tokenIn_, uint256 amount_, address sender_)
    internal
    returns (uint256 actualIn_)
{
    uint256 balanceBefore = tokenIn_.balanceOf(address(this));

    if (tokenIn_.allowance(sender_, address(this)) < amount_) {
        Permit2AwareRepo._permit2().transferFrom(sender_, address(this), uint160(amount_), address(tokenIn_));
    } else {
        tokenIn_.safeTransferFrom(sender_, address(this), amount_);
    }

    actualIn_ = tokenIn_.balanceOf(address(this)) - balanceBefore;
}
```

## Files to Create/Modify

**Modified Files:**
- `contracts/vaults/seigniorage/SeigniorageDETFCommon.sol` - Fix `_secureTokenTransfer`

**Tests:**
- `test/foundry/spec/protocol/vaults/seigniorage/SeigniorageDETF_TokenTransfer.t.sol` - Balance-delta regression tests

## Inventory Check

Before starting, verify:
- [ ] Locate `SeigniorageDETFCommon._secureTokenTransfer`
- [ ] Compare with `ProtocolDETFCommon._secureTokenTransfer` pattern
- [ ] Identify all callers of `_secureTokenTransfer` in Seigniorage DETF

## Completion Criteria

- [ ] `_secureTokenTransfer` uses balance-delta accounting
- [ ] Regression tests pass
- [ ] Build succeeds
- [ ] All existing Seigniorage DETF tests pass

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
