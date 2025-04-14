# Task IDXEX-094: Add WAD validation to _initVaultRegistryFeeOracle

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-066
**Worktree:** feature/IDXEX-094-add-wad-validation-init-vault-registry-fee-oracle

---

## Description

Add defensive WAD-range validation to the initialization path `_initVaultRegistryFeeOracle` so it calls `VaultFeeOracleRepo._validateWadPercentage()` for `defaultVaultUsageFee_`, `defaultDexSwapFee_`, and `defaultSeigniorageIncentivePercentage_` before writing storage. This keeps init consistent with setter validations and prevents malformed init parameters from bypassing bounds checks.

This change is small, low-risk, and mirrors the existing validation applied in setters. The init path currently writes constants from `Indexedex_CONSTANTS.sol`, but validation provides defense-in-depth.

## Acceptance Criteria

- [ ] `_initVaultRegistryFeeOracle` calls `_validateWadPercentage()` for the three parameters before writing storage
- [ ] Unit tests (existing) continue to pass
- [ ] Add or update a minimal unit test if needed to cover init validation (optional)

## Files to modify

- `contracts/oracles/fee/VaultFeeOracleRepo.sol` (init function lines ~71-88)
- `contracts/manager/IndexedexManagerDFPkg.sol` (if init invocation needs minor adjustment)

## Notes

- Priority: Low (defensive hardening)
- Origin: Code review suggestion from IDXEX-066

---

When complete, output: <promise>PHASE_DONE</promise>
