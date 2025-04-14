# Progress Log: IDXEX-071

## Current Checkpoint

**Last checkpoint:** Implementation complete
**Next step:** Code review
**Build status:** PASS (clean compile with Solc 0.8.30)
**Test status:** 650 pass, 3 pre-existing failures (unrelated slippage tests)

---

## Session Log

### 2026-02-07 - Implementation Complete

**Changes made across 3 files:**

#### `contracts/vaults/protocol/ProtocolNFTVaultCommon.sol`
- Replaced dead-code `_bondTerms()` default implementation (hardcoded 7d-365d) with `StandardVaultRepo._feeOracle().bondTermsOfVault(address(this))`
- Made `_bondTerms()` non-virtual (no longer needs override, base class is authoritative)
- Added `StandardVaultRepo` import
- Removed unused `IVaultFeeOracleQuery` import
- Kept `ONE_WAD` import (still used by `_calcBonusMultiplier()`)

#### `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol`
- Removed `IVaultFeeOracleQuery public feeOracle` state variable (was at slot 0 via raw sstore)
- Removed `_bondTerms()` override that used raw `feeOracle` + passed DETF address
- Updated `reallocateProtocolRewards()` auth check from `feeOracle.feeTo()` to `StandardVaultRepo._feeOracle().feeTo()`
- Added `StandardVaultRepo` import
- Removed unused `BondTerms` and `IVaultFeeOracleQuery` imports

#### `contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol`
- Removed `_setFeeOracle(VAULT_FEE_ORACLE_QUERY)` call from `initAccount()` (was redundant with `StandardVaultRepo._initialize()` on line 251)
- Removed `_setFeeOracle()` function definition (raw `assembly { sstore(0, feeOracle_) }`)

**Key design decision:** Changed `bondTermsOfVault()` address argument from `address(ProtocolNFTVaultRepo._protocolDETF())` to `address(this)`. This matches the Seigniorage vault pattern and is consistent with the fee oracle's fallback chain (`VaultRegistryVaultRepo._bondFeeIdOfVault(vault)` which is indexed by vault proxy address, not DETF address).

**Verification:**
- `forge build` compiles cleanly
- 650/654 tests pass (3 pre-existing slippage failures in ProtocolDETFExchangeOut/Routes, 1 skipped)
- No new test failures introduced

### 2026-02-07 - Task Created

- Task designed via /design
- Identified architectural inconsistency: ProtocolNFTVaultTarget uses raw sstore for fee oracle while SeigniorageNFTVaultCommon uses StandardVaultRepo pattern
- Full refactor scope: move _bondTerms() to base class, remove raw slot 0 storage, verify init path
- TASK.md populated with requirements
- Ready for agent assignment via /backlog:launch
