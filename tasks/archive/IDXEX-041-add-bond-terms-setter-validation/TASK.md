# Task IDXEX-041: Add Bond Terms Setter Validation

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Dependencies:** IDXEX-030
**Worktree:** `feature/add-bond-terms-setter-validation`
**Origin:** Code review suggestion from IDXEX-030

---

## Description

`VaultFeeOracleRepo._setDefaultBondTerms()` accepts any `BondTerms` struct without validation. Adding a bounds check like `require(terms.maxBonusPercentage <= ONE_WAD)` would prevent future misconfiguration at the storage level, catching scaling errors (like the 500% vs 5% bug in IDXEX-030) at write time rather than allowing them to propagate.

This is a defense-in-depth measure to ensure bond bonus percentages stay within sane ranges (0-100% max bonus = 0 to 1e18 WAD).

(Created from code review of IDXEX-030)

## Dependencies

- IDXEX-030: Fix Bond Bonus Defaults Scale (parent task) - Complete

## User Stories

### US-IDXEX-041.1: Add bounds validation to bond terms setter

As a protocol administrator, I want the fee oracle setter to reject out-of-range bond bonus percentages so that misconfigured values cannot be written to storage and propagate to all vaults.

**Acceptance Criteria:**
- [ ] `VaultFeeOracleRepo._setDefaultBondTerms()` validates `terms.maxBonusPercentage <= ONE_WAD`
- [ ] `VaultFeeOracleRepo._setDefaultBondTerms()` validates `terms.minBonusPercentage <= terms.maxBonusPercentage`
- [ ] Invalid values revert with a descriptive error
- [ ] Test validates that out-of-range values are rejected
- [ ] Test validates that valid values (e.g., 5e16, 1e17) are accepted
- [ ] Tests pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/oracles/fee/VaultFeeOracleRepo.sol`

**Test Files:**
- New or modified test for bond terms validation

## Inventory Check

Before starting, verify:
- [ ] IDXEX-030 is complete (bond bonus defaults fixed)
- [ ] `contracts/oracles/fee/VaultFeeOracleRepo.sol` exists
- [ ] All current tests pass before making changes

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
