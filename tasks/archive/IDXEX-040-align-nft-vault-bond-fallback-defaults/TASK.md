# Task IDXEX-040: Test Vault Fee Oracle Bond Terms Fallback Chain

**Repo:** IndexedEx
**Status:** Complete
**Created:** 2026-02-06
**Updated:** 2026-02-07
**Dependencies:** IDXEX-030
**Worktree:** `feature/align-nft-vault-bond-fallback-defaults`
**Origin:** Code review suggestion from IDXEX-030, repurposed after design analysis

---

## Description

The original task proposed aligning hardcoded fallback defaults in `ProtocolNFTVaultCommon._bondTerms()`. Design analysis revealed this fallback is **dead code**: `ProtocolNFTVaultTarget._bondTerms()` always delegates to the Vault Fee Oracle, which implements its own 3-level fallback chain:

1. **Vault-specific override** (`VaultFeeOracleRepo._bondTermsOfVault(vault)`)
2. **Vault-type default** (`defaultBondTermsOfVaultTypeId(typeId)`)
3. **Global default** (`defaultBondTerms()` — initialized with 5%/10% during deployment)

The oracle uses `minLockDuration == 0` as the sentinel for "not configured."

This task is repurposed to **add tests documenting the oracle fallback chain**, verifying each level works correctly and the sentinel logic is sound.

## Dependencies

- IDXEX-030: Fix Bond Bonus Defaults Scale (parent task) - Complete

## User Stories

### US-IDXEX-040.1: Test 3-level bond terms fallback chain

As a protocol developer, I want tests documenting the Vault Fee Oracle's bond terms fallback hierarchy so that the fallback architecture is verified and regression-protected.

**Acceptance Criteria:**
- [x] Test: When vault-specific bond terms are set, `bondTermsOfVault()` returns them
- [x] Test: When vault-specific terms are NOT set but vault-type defaults exist, `bondTermsOfVault()` returns vault-type defaults
- [x] Test: When neither vault-specific nor vault-type defaults are set, `bondTermsOfVault()` returns global defaults
- [x] Test: Global defaults match `DEFAULT_BOND_MIN_BONUS_PERCENTAGE` (5e16) and `DEFAULT_BOND_MAX_BONUS_PERCENTAGE` (1e17)
- [x] Test: Sentinel check — `minLockDuration == 0` correctly identifies "not configured"

### US-IDXEX-040.2: Test ProtocolNFTVaultTarget always delegates to oracle

As a security reviewer, I want a test proving that `ProtocolNFTVaultTarget._bondTerms()` always routes through the fee oracle, so that any base-class fallback is confirmed unreachable in production.

**Acceptance Criteria:**
- [x] Test: `ProtocolNFTVaultTarget._bondTerms()` returns values from the fee oracle, not from `ProtocolNFTVaultCommon` base class
- [x] Test: Changing oracle defaults changes the bond terms returned by the vault

## Technical Details

**Oracle fallback implementation** (`VaultFeeOracleQueryFacet.bondTermsOfVault()`, lines ~166-175):
```
bondTerms = _bondTermsOfVault(vault)           // Level 1: vault-specific
if (bondTerms.minLockDuration == 0)
  bondTerms = defaultBondTermsOfVaultTypeId()  // Level 2: type default
  if (bondTerms.minLockDuration == 0)
    bondTerms = defaultBondTerms()             // Level 3: global default
```

**Default values** (from `Indexedex_CONSTANTS.sol`):
- `DEFAULT_BOND_MIN_TERM` = 30 days
- `DEFAULT_BOND_MAX_TERM` = 180 days
- `DEFAULT_BOND_MIN_BONUS_PERCENTAGE` = 5e16 (5% WAD)
- `DEFAULT_BOND_MAX_BONUS_PERCENTAGE` = 1e17 (10% WAD)

**Base class dead code** (`ProtocolNFTVaultCommon._bondTerms()`, lines ~65-72):
- Has `maxBonusPercentage = ONE_WAD` (100%) — but never reached in production
- The test should document WHY this is dead code (ProtocolNFTVaultTarget always overrides)

## Files to Create

**New Files:**
- `test/foundry/spec/oracles/fee/VaultFeeOracle_BondTermsFallback.t.sol` — Fallback chain tests

**Key Contracts to Reference:**
- `contracts/oracles/fee/VaultFeeOracleQueryFacet.sol` — Oracle query with fallback
- `contracts/oracles/fee/VaultFeeOracleRepo.sol` — Storage and setters
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol` — Override that delegates to oracle
- `contracts/vaults/protocol/ProtocolNFTVaultCommon.sol` — Base class with dead fallback
- `contracts/constants/Indexedex_CONSTANTS.sol` — Default values

## Inventory Check

Before starting, verify:
- [x] IDXEX-030 is complete (bond bonus defaults fixed)
- [x] `VaultFeeOracleQueryFacet.bondTermsOfVault()` exists with 3-level fallback
- [x] Existing test patterns for fee oracle in `test/foundry/spec/oracles/`
- [x] Default constants match expected values

## Completion Criteria

- [x] All fallback levels tested individually
- [x] Sentinel logic tested
- [x] Oracle delegation from vault tested
- [x] Tests pass
- [x] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
