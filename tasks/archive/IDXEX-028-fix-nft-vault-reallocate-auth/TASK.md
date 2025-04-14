# Task IDXEX-028: Fix ProtocolNFTVaultTarget.reallocateProtocolRewards Authorization

**Repo:** IndexedEx
**Status:** Complete
**Created:** 2026-02-02
**Completed:** 2026-02-03
**Priority:** HIGH
**Dependencies:** None
**Worktree:** `feature/fix-nft-vault-reallocate-auth`

---

## Description

`ProtocolNFTVaultTarget.reallocateProtocolRewards(address recipient)` has an authorization check:
```solidity
if (msg.sender != address(feeOracle)) revert NotAuthorized(msg.sender);
```

However, the interface documentation in `IProtocolNFTVault.sol` states this "can only be called by feeTo address from VaultFeeOracle", implying `feeOracle.feeTo()` (the fee collector) should be the authorized caller, not the oracle contract itself.

**Source:** REVIEW_REPORT.md lines 451-465

## Design Decision Required

**Question from review:** Is the intended caller `address(feeOracle)` (oracle/manager diamond) or `feeOracle.feeTo()` (fee collector proxy)?

**Analysis:**
- If `feeOracle` (manager) is correct: fix the interface documentation
- If `feeTo` (collector) is correct: fix the code check

**Recommendation:** Determine the intended trust model. If the fee collector should be able to reallocate rewards (making it autonomous), check against `feeTo`. If only the manager should trigger this (centralized control), keep the current code but fix docs.

## User Stories

### US-IDXEX-028.1: Align Authorization with Intent

As a protocol administrator, I want the authorization check to match the intended caller so that rewards can be reallocated correctly.

**Acceptance Criteria:**
- [x] Determine intended caller (manager vs fee collector) → **feeTo (FeeCollector)**
- [x] Code check matches intended caller
- [x] Interface documentation matches code (docs were already correct)

### US-IDXEX-028.2: Add Authorization Tests

As a security auditor, I want tests proving only authorized callers can reallocate rewards.

**Acceptance Criteria:**
- [x] Test: intended caller can call `reallocateProtocolRewards`
- [x] Test: other addresses revert with `NotAuthorized`
- [x] Test: rewards are correctly transferred to recipient

## Technical Details

**File to modify:** `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol`

**Current check:**
```solidity
if (msg.sender != address(feeOracle)) revert NotAuthorized(msg.sender);
```

**If feeTo is intended caller:**
```solidity
if (msg.sender != address(feeOracle.feeTo())) revert NotAuthorized(msg.sender);
```

**Interface file to update:** `contracts/interfaces/IProtocolNFTVault.sol`
- Update NatSpec to match actual authorization behavior

## Files to Create/Modify

**Modified Files:**
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol` - Fix auth check (if code is wrong)
- `contracts/interfaces/IProtocolNFTVault.sol` - Fix NatSpec (if docs are wrong)

**Tests:**
- `test/foundry/spec/vaults/protocol/ProtocolNFTVault_ReallocateAuth.t.sol` - Authorization tests

## Inventory Check

Before starting, verify:
- [x] Locate `ProtocolNFTVaultTarget.reallocateProtocolRewards`
- [x] Read `IProtocolNFTVault` interface docs
- [x] Understand what `feeOracle` and `feeOracle.feeTo()` represent
- [x] Check if there are existing callers of this function

## Completion Criteria

- [x] Design decision documented
- [x] Code and docs aligned
- [x] Authorization tests pass
- [x] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
