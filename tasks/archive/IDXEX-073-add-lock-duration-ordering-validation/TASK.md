# Task IDXEX-073: Add Lock Duration Ordering Validation

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-041 (complete)
**Worktree:** `feature/add-lock-duration-ordering-validation`
**Origin:** Code review suggestion from IDXEX-041

---

## Description

The bond terms validation added in IDXEX-041 validates bonus percentage ordering (`minBonusPercentage <= maxBonusPercentage`) and bounds (`maxBonusPercentage <= ONE_WAD`), but does not validate lock duration ordering. Inverted lock durations (`minLockDuration > maxLockDuration`) are currently accepted and stored.

The lock duration ordering validation should be added to the **Vault Fee Oracle setter functions** (facet level), ensuring that all write paths reject inverted lock duration ranges.

(Created from code review of IDXEX-041, Finding 4 / Suggestion 1)

## Dependencies

- IDXEX-041: Add Bond Terms Setter Validation (complete)

## User Stories

### US-IDXEX-073.1: Validate lock duration ordering in VaultFeeOracle setters

As a protocol administrator, I want the oracle setters to reject bond terms where `minLockDuration > maxLockDuration` so that invalid configuration is caught at write time.

**Acceptance Criteria:**
- [ ] VaultFeeOracle setter functions validate `minLockDuration <= maxLockDuration`
- [ ] Invalid values revert with a descriptive error including the offending values
- [ ] The zero sentinel (all-zero BondTerms) still passes validation (`0 <= 0`)
- [ ] Validation covers all 3 levels: global default, type-level default, vault-level override
- [ ] Tests validate rejection of inverted lock durations
- [ ] Tests validate acceptance of valid lock durations (including edge cases: equal min/max, zero/zero)
- [ ] All existing bond terms tests still pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/oracles/fee/VaultFeeOracleRepo.sol` — Add lock duration check to `_validateBondTerms()`
- `test/foundry/spec/oracles/fee/VaultFeeOracle_Bounds.t.sol` — Add revert and acceptance tests for lock duration ordering

## Inventory Check

Before starting, verify:
- [ ] IDXEX-041 is complete
- [ ] `_validateBondTerms()` exists in VaultFeeOracleRepo.sol
- [ ] Existing bounds tests pass

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] All existing tests pass (no regressions)
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
