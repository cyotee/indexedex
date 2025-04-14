# Progress Log: IDXEX-040

## Current Checkpoint

**Last checkpoint:** Implementation complete
**Next step:** Ready for code review
**Build status:** PASS (829 files compiled, no errors)
**Test status:** PASS (17/17 new tests, 83/83 total oracle fee tests)

---

## Session Log

### 2026-02-07 - Implementation Complete

**Created:** `test/foundry/spec/oracles/fee/VaultFeeOracle_BondTermsFallback.t.sol`

**17 tests covering all acceptance criteria:**

US-IDXEX-040.1 — 3-Level Bond Terms Fallback Chain:
- `test_globalDefaults_matchConstants` — Global defaults match named constants
- `test_globalDefaults_haveExpectedValues` — 30d/180d/5%/10% verified
- `test_unregisteredVault_fallsBackToGlobalDefaults` — Level 3 fallback works
- `test_updateGlobalDefaults_affectsUnregisteredVault` — Global change propagates
- `test_vaultTypeDefault_returnedByDirectQuery` — Level 2 direct query works
- `test_registeredVault_fallsBackToVaultTypeDefault` — Level 2 fallback via registered vault
- `test_vaultTypeDefault_withZeroMinLock_fallsThroughToGlobal` — Level 2 sentinel falls to Level 3
- `test_vaultSpecificOverride_takesHighestPriority` — Level 1 override works
- `test_clearVaultOverride_fallsBackToVaultTypeDefault` — Clearing Level 1 falls to Level 2
- `test_fullFallbackChain_progressiveRemoval` — Full chain walk: L1 → L2 → L3

Sentinel Logic:
- `test_sentinel_onlyChecksMinLockDuration` — Only minLockDuration==0 triggers fallback
- `test_sentinel_minLockDurationOfOne_noFallback` — minLockDuration=1 does NOT trigger
- `test_sentinel_allZeroStruct_isClearOverride` — All-zero struct clears override

US-IDXEX-040.2 — Oracle Delegation:
- `test_oracleDefaultChange_affectsBondTermsOfVault` — Oracle change propagates to vault
- `test_bondTerms_areFromOracle_notBaseClass` — Values differ from ProtocolNFTVaultCommon dead code

Fuzz Tests:
- `testFuzz_setVaultBondTerms_roundTrip` — Any non-zero minLock stores correctly (256 runs)
- `testFuzz_setVaultBondTerms_zeroMinLock_alwaysFallsBack` — Zero minLock always triggers fallback (256 runs)

**Key implementation details:**
- Follows existing patterns from `VaultFeeOracle_Units.t.sol` and `VaultFeeOracle_Bounds.t.sol`
- Tests Level 2 (vault-type default) by registering a vault with `IVaultRegistryVaultManager.registerVault()` using encoded `VaultFeeTypeIds` with a test bond type ID
- Fuzz tests prove the sentinel boundary is exactly at zero

### 2026-02-07 - Task Repurposed

- Design analysis revealed `ProtocolNFTVaultCommon._bondTerms()` fallback is dead code
- `ProtocolNFTVaultTarget._bondTerms()` always delegates to Vault Fee Oracle
- Oracle already implements 3-level fallback: vault-specific → vault-type → global defaults
- **Task repurposed**: from "align fallback defaults" to "test oracle fallback chain"
- New scope: add spec tests verifying each fallback level and sentinel logic

### 2026-02-06 - Task Created

- Task created from code review suggestion
- Origin: IDXEX-030 REVIEW.md, Suggestion 1
- Ready for agent assignment via /backlog:launch
