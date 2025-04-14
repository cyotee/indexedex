# Task IDXEX-071: Refactor ProtocolNFTVault Fee Oracle Storage to StandardVaultRepo

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-030
**Worktree:** `feature/refactor-protocol-nft-vault-fee-oracle-storage`

---

## Description

`ProtocolNFTVaultTarget` stores the fee oracle address as a raw state variable at slot 0 via inline `sstore`, bypassing the `StandardVaultRepo` repository pattern used by the rest of the codebase. `SeigniorageNFTVaultCommon` already uses the correct pattern: `StandardVaultRepo._feeOracle()`.

This task refactors `ProtocolNFTVaultTarget` to use `StandardVaultRepo._feeOracle()` for fee oracle access, moves `_bondTerms()` to the base class `ProtocolNFTVaultCommon`, moves the `feeOracle.feeTo()` auth check from `reallocateProtocolRewards()` to the base class, removes the direct `feeOracle` state variable, removes the `_setFeeOracle()` raw sstore helper, and verifies the initialization path in `ProtocolNFTVaultDFPkg`.

## Dependencies

- IDXEX-030: Fix Bond Bonus Defaults Scale - Complete

## User Stories

### US-IDXEX-071.1: Replace raw sstore fee oracle with StandardVaultRepo pattern

As a protocol developer, I want the Protocol NFT Vault to use `StandardVaultRepo._feeOracle()` for fee oracle access so that storage patterns are consistent across all vault types.

**Acceptance Criteria:**
- [ ] Remove `IVaultFeeOracleQuery public feeOracle` state variable from `ProtocolNFTVaultTarget`
- [ ] Remove `_setFeeOracle()` function with raw `sstore` from `ProtocolNFTVaultDFPkg`
- [ ] All fee oracle access in ProtocolNFTVault uses `StandardVaultRepo._feeOracle()`
- [ ] No raw `sstore`/`sload` for fee oracle address

### US-IDXEX-071.2: Move _bondTerms() to ProtocolNFTVaultCommon

As a protocol developer, I want `_bondTerms()` implemented in the base class so that the hardcoded dead-code fallback is eliminated and all subclasses automatically get oracle-backed bond terms.

**Acceptance Criteria:**
- [ ] `ProtocolNFTVaultCommon._bondTerms()` calls `StandardVaultRepo._feeOracle().bondTermsOfVault()` directly
- [ ] `ProtocolNFTVaultTarget._bondTerms()` override is removed (base class handles it)
- [ ] `_validateLockDuration()` and `_calcBonusMultiplier()` callers work unchanged
- [ ] Bond terms still resolve through oracle's 3-level fallback chain (vault → type → global)

### US-IDXEX-071.3: Move fee oracle auth check to base class

As a security reviewer, I want the `feeOracle.feeTo()` authorization check in `reallocateProtocolRewards()` to use `StandardVaultRepo._feeOracle()` so that the auth pattern is consistent and doesn't depend on a raw slot 0 state variable.

**Acceptance Criteria:**
- [ ] `reallocateProtocolRewards()` auth check uses `StandardVaultRepo._feeOracle().feeTo()`
- [ ] Auth behavior is unchanged (only fee collector can call)
- [ ] If the auth check can be moved to the base class, do so; otherwise keep in Target but use repo pattern

### US-IDXEX-071.4: Verify initialization path

As a protocol developer, I want the initialization path verified so that `StandardVaultRepo._feeOracle()` is properly set for Protocol vaults during deployment.

**Acceptance Criteria:**
- [ ] Verify `ProtocolNFTVaultDFPkg.initAccount()` calls `StandardVaultRepo._initialize()` with the fee oracle address
- [ ] Verify the fee oracle is accessible via `StandardVaultRepo._feeOracle()` after init
- [ ] If init gap exists, fix it so `StandardVaultRepo` has the oracle address
- [ ] Remove redundant `_setFeeOracle(VAULT_FEE_ORACLE_QUERY)` call if StandardVaultRepo._initialize() already handles it

## Technical Details

**Current (broken) pattern in ProtocolNFTVaultTarget:**
```solidity
IVaultFeeOracleQuery public feeOracle;  // Direct state variable

function _setFeeOracle(IVaultFeeOracleQuery feeOracle_) internal {
    assembly { sstore(0, feeOracle_) }  // Raw slot 0
}

function _bondTerms() internal view override returns (BondTerms memory) {
    return feeOracle.bondTermsOfVault(address(ProtocolNFTVaultRepo._protocolDETF()));
}
```

**Correct pattern (from SeigniorageNFTVaultCommon):**
```solidity
function _bondTerms() internal view returns (BondTerms memory terms_) {
    terms_ = StandardVaultRepo._feeOracle().bondTermsOfVault(address(this));
}
```

**Note on vault address:** SeigniorageNFTVaultCommon passes `address(this)` while ProtocolNFTVaultTarget passes `address(ProtocolNFTVaultRepo._protocolDETF())`. Verify which address the fee oracle expects for Protocol vaults and preserve the correct behavior.

**Initialization in ProtocolNFTVaultDFPkg.initAccount():**
- Already calls `StandardVaultRepo._initialize(VAULT_FEE_ORACLE_QUERY, ...)` (line ~248)
- Also calls `_setFeeOracle(VAULT_FEE_ORACLE_QUERY)` (line ~255) — this is the redundant raw sstore
- After removing `_setFeeOracle()`, verify `StandardVaultRepo._initialize()` correctly stores the oracle

## Files to Modify

**Modified Files:**
- `contracts/vaults/protocol/ProtocolNFTVaultCommon.sol` — Add `_bondTerms()` using StandardVaultRepo pattern, remove dead-code fallback
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol` — Remove `feeOracle` state variable, `_bondTerms()` override, update `reallocateProtocolRewards()` auth
- `contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol` — Remove `_setFeeOracle()`, verify StandardVaultRepo init

**Tests to Verify:**
- Existing protocol vault tests must still pass
- Existing fork tests for Protocol DETF must still pass

## Inventory Check

Before starting, verify:
- [ ] IDXEX-030 is complete
- [ ] `SeigniorageNFTVaultCommon._bondTerms()` pattern exists as reference
- [ ] `StandardVaultRepo._feeOracle()` accessor exists
- [ ] `StandardVaultRepo._initialize()` accepts fee oracle parameter
- [ ] Existing tests pass before making changes

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] No raw sstore/sload for fee oracle in Protocol vault contracts
- [ ] Fee oracle access is consistent with Seigniorage vault pattern
- [ ] All existing tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
