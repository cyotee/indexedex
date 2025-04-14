# Task IDXEX-035: Fix BasicVaultCommon._secureTokenTransfer Full-Balance Issue

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-02
**Priority:** HIGH
**Dependencies:** None
**Worktree:** `feature/fix-basic-vault-token-transfer`

---

## Description

`BasicVaultCommon._secureTokenTransfer` returns `tokenIn.balanceOf(this)` (full held balance), not the delta for the current call. This is problematic because:
1. If the vault holds dust or pre-existing balance, users get over-credited
2. Fee-on-transfer tokens would show incorrect amounts
3. The `pretransferred == true` mode treats full balance as transfer credit

This affects all Standard Exchange vaults that inherit from `BasicVaultCommon`: Aerodrome, UniswapV2, CamelotV2.

**Note:** This is related to but distinct from IDXEX-029 (SeigniorageDETFCommon) and IDXEX-034 (pretransferred refunds).

**Source:** REVIEW_REPORT.md lines 164-166, 850

## User Stories

### US-IDXEX-035.1: Fix Balance-Delta Accounting

As a vault user, I want my deposit credited correctly based on what I actually transferred.

**Acceptance Criteria:**
- [ ] `_secureTokenTransfer` records balance before transfer
- [ ] Returns `balanceAfter - balanceBefore` as `actualIn_`
- [ ] Works for both ERC20 and Permit2 paths
- [ ] Handles fee-on-transfer tokens correctly

### US-IDXEX-035.2: Handle Pretransferred Mode Correctly

As a router integrator, I want `pretransferred == true` mode to correctly identify the received amount.

**Acceptance Criteria:**
- [ ] When `pretransferred == true`, function identifies actual received amount
- [ ] Does NOT treat vault's entire balance as transfer credit
- [ ] Consider requiring caller to pass expected amount for verification

### US-IDXEX-035.3: Add Balance-Delta Tests

As a security auditor, I want tests proving balance-delta accounting works.

**Acceptance Criteria:**
- [ ] Test: vault with dust balance, deposit credited correctly (not dust + deposit)
- [ ] Test: fee-on-transfer token returns actual received amount
- [ ] Test: pretransferred mode with known amount

## Technical Details

**File to modify:** `contracts/vaults/basic/BasicVaultCommon.sol`

**Current (buggy):**
```solidity
function _secureTokenTransfer(
    IERC20 tokenIn_,
    uint256 amount_,
    address sender_,
    bool pretransferred_
)
    internal
    returns (uint256 actualIn_)
{
    if (!pretransferred_) {
        // ... transfer logic ...
    }
    actualIn_ = tokenIn_.balanceOf(address(this)); // BUG: full balance
}
```

**Fixed:**
```solidity
function _secureTokenTransfer(
    IERC20 tokenIn_,
    uint256 amount_,
    address sender_,
    bool pretransferred_
)
    internal
    returns (uint256 actualIn_)
{
    uint256 balanceBefore = tokenIn_.balanceOf(address(this));

    if (!pretransferred_) {
        // ... transfer logic ...
    }

    actualIn_ = tokenIn_.balanceOf(address(this)) - balanceBefore;
}
```

**Note on pretransferred mode:** When `pretransferred == true`, the caller has already sent tokens. The balance delta should still be computed from the point of function entry, but if the tokens were sent in the same transaction before this call, the delta would be 0. Consider:
1. Requiring `amount_` to be passed and verified against balance
2. Using a "pull" model where even pretransferred uses a known amount

## Files to Create/Modify

**Modified Files:**
- `contracts/vaults/basic/BasicVaultCommon.sol` - Fix `_secureTokenTransfer`

**Tests:**
- `test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol` - Balance-delta tests

## Inventory Check

Before starting, verify:
- [ ] Locate `BasicVaultCommon._secureTokenTransfer`
- [ ] Identify all callers and how they use the return value
- [ ] Check if `_secureSelfBurn` has the same issue
- [ ] Compare with `ProtocolDETFCommon._secureTokenTransfer` (reference implementation)

## Completion Criteria

- [ ] `_secureTokenTransfer` uses balance-delta accounting
- [ ] Balance-delta tests pass
- [ ] Build succeeds
- [ ] All existing vault tests pass

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
