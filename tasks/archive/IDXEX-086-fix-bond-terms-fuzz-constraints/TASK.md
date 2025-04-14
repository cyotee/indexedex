# Task IDXEX-086: Fix BondTermsFallback Fuzz Test Input Constraints

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-041 (archived, complete)
**Worktree:** `feature/fix-bond-terms-fuzz-constraints`

---

## Description

IDXEX-041 added bounds validation to bond terms setters (`_validateBondTerms` in `VaultFeeOracleRepo`), which enforces `maxBonusPercentage <= 1e18` and `minBonusPercentage <= maxBonusPercentage`. However, the fuzz tests in `VaultFeeOracle_BondTermsFallback.t.sol` (written in IDXEX-040, before the validation existed) pass arbitrary `uint256` values that now trigger validation reverts.

## Dependencies

- IDXEX-041 (complete) — Added the validation that causes these tests to fail

## User Stories

### US-IDXEX-086.1: Constrain Fuzz Inputs to Valid Bond Terms Ranges

As a developer, I want the fuzz tests to only generate inputs within the valid domain so that they test round-trip storage correctness without hitting the validation boundary.

**Acceptance Criteria:**
- [ ] `testFuzz_setVaultBondTerms_roundTrip` adds `vm.assume(maxBonus <= 1e18)` and `vm.assume(minBonus <= maxBonus)`
- [ ] `testFuzz_setVaultBondTerms_zeroMinLock_alwaysFallsBack` adds `vm.assume(maxBonus <= 1e18)` and `vm.assume(minBonus <= maxBonus)`
- [ ] Both fuzz tests pass with 256+ runs
- [ ] No other tests are broken

## Technical Details

The validation in `VaultFeeOracleRepo._validateBondTerms()` (lines 51-58) checks:
```solidity
if (terms_.maxBonusPercentage > ONE_WAD) {
    revert BondTerms_MaxBonusExceedsWAD(terms_.maxBonusPercentage, ONE_WAD);
}
if (terms_.minBonusPercentage > terms_.maxBonusPercentage) {
    revert BondTerms_MinBonusExceedsMax(terms_.minBonusPercentage, terms_.maxBonusPercentage);
}
```

The fix is to add `vm.assume` constraints before calling the setter:
- `vm.assume(maxBonus <= 1e18);`
- `vm.assume(minBonus <= maxBonus);`

Alternatively, use `bound()` for more efficient fuzzing:
- `maxBonus = bound(maxBonus, 0, 1e18);`
- `minBonus = bound(minBonus, 0, maxBonus);`

Using `bound()` is preferred over `vm.assume()` for range constraints because `vm.assume` rejects inputs (wasting runs), while `bound` remaps them into the valid domain.

## Files to Create/Modify

**Modified Files:**
- `test/foundry/spec/oracles/fee/VaultFeeOracle_BondTermsFallback.t.sol` — Add `bound()` constraints to `testFuzz_setVaultBondTerms_roundTrip` and `testFuzz_setVaultBondTerms_zeroMinLock_alwaysFallsBack`

## Inventory Check

Before starting, verify:
- [ ] `VaultFeeOracleRepo._validateBondTerms()` exists and enforces the two checks
- [ ] `ONE_WAD` is `1e18`
- [ ] Existing non-fuzz tests in the same file still pass

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] `forge test --match-contract VaultFeeOracle_BondTermsFallback_Test` passes (all tests)
- [ ] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`
