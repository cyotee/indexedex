# Task IDXEX-083: Add WAD Percentage Bounds Validation

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-054
**Worktree:** `feature/IDXEX-083-add-wad-percentage-bounds-validation`
**Origin:** Code review suggestion from IDXEX-054

---

## Description

The percentage-based fee setters in `VaultFeeOracleManagerFacet` accept any `uint256` value without validating it is <= `ONE_WAD` (1e18 = 100%). A value > WAD would mean > 100% for usage fee, DEX swap fee, or seigniorage incentive percentage.

Currently only `BondTerms` setters validate inputs (via `_validateBondTerms` in `VaultFeeOracleRepo`). While `onlyOwnerOrOperator` access control provides a trust boundary, a sanity check prevents accidental misconfiguration (e.g., passing raw percentage `50` instead of WAD-denominated `5e17`).

This should be evaluated carefully -- some use cases might intentionally allow values > WAD. Needs protocol economics review before implementation. Consider adding the validation at the `VaultFeeOracleRepo` internal setter level so all callers benefit.

(Created from code review of IDXEX-054)

## Dependencies

- IDXEX-054: Add Seigniorage Manager Setter Functions (parent task, complete)

## User Stories

### US-IDXEX-083.1: Add bounds validation to seigniorage setters

As a protocol operator, I want percentage setters to reject obviously invalid values so that accidental misconfiguration is prevented.

**Acceptance Criteria:**
- [ ] `_setDefaultSeigniorageIncentivePercentage` reverts if value > ONE_WAD
- [ ] `_setDefaultSeigniorageIncentivePercentageOfTypeId` reverts if value > ONE_WAD
- [ ] `_overrideSeigniorageIncentivePercentageOfVault` reverts if value > ONE_WAD

### US-IDXEX-083.2: Add bounds validation to usage fee setters

**Acceptance Criteria:**
- [ ] `_setDefaultUsageFee` reverts if value > ONE_WAD
- [ ] `_setDefaultUsageFeeOfTypeId` reverts if value > ONE_WAD
- [ ] `_overrideUsageFeeOfVault` reverts if value > ONE_WAD

### US-IDXEX-083.3: Add bounds validation to DEX swap fee setters

**Acceptance Criteria:**
- [ ] `_setDefaultDexSwapFee` reverts if value > ONE_WAD
- [ ] `_setDefaultDexSwapFeeOfTypeId` reverts if value > ONE_WAD
- [ ] `_overrideDexSwapFeeOfVault` reverts if value > ONE_WAD

### US-IDXEX-083.4: Test bounds validation

**Acceptance Criteria:**
- [ ] Tests verify revert on value > ONE_WAD for each setter
- [ ] Tests verify value == ONE_WAD succeeds (boundary)
- [ ] Tests verify value == 0 succeeds (clear/disable)
- [ ] Existing tests continue to pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/oracles/fee/VaultFeeOracleRepo.sol` - Add validation to internal setters

**Test Files:**
- New or existing test files for bounds validation

## Inventory Check

Before starting, verify:
- [ ] IDXEX-054 is complete
- [ ] `VaultFeeOracleRepo.sol` has all internal setters
- [ ] Review if any downstream code intentionally uses values > WAD
- [ ] Check Crane `ONE_WAD` constant availability

## Completion Criteria

- [ ] All percentage-based fee setters validate value <= ONE_WAD
- [ ] Appropriate custom error defined for revert
- [ ] Tests verify boundary conditions (0, ONE_WAD, ONE_WAD+1)
- [ ] All existing tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`
