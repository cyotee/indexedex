# Task IDXEX-030: Fix Bond Bonus Defaults Scale (500% vs 5%)

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-02
**Priority:** HIGH
**Dependencies:** None
**Worktree:** `feature/fix-bond-bonus-defaults-scale`

---

## Description

`contracts/constants/Indexedex_CONSTANTS.sol` defines bond bonus percentages that don't match their comments:
- `DEFAULT_BOND_MIN_BONUS_PERCENTAGE = 5e18` (comment says "5%")
- `DEFAULT_BOND_MAX_BONUS_PERCENTAGE = 10e18` (comment says "10%")

If values are WAD-scaled (1e18 = 100%), then `5e18` = 500% and `10e18` = 1000%, not 5%/10%.

These defaults are applied during `IndexedexManagerDFPkg.initAccount` and affect all NFT vault bonding calculations.

**Source:** REVIEW_REPORT.md lines 55-72, 851, 919, 941

## Impact Analysis

Multiple bonus calculations use `ONE_WAD + terms.maxBonusPercentage`, implying:
- `maxBonusPercentage` should be in `[0, ONE_WAD]` for up to +100% bonus
- `5e18` / `10e18` represent +500% / +1000% bonus, not +5% / +10%

This could result in:
1. Massively inflated bond rewards if used as-is
2. Potential overflow issues if bonus exceeds expected range

## User Stories

### US-IDXEX-030.1: Fix Bonus Percentage Defaults

As a protocol administrator, I want bond bonus defaults to match their intended economic parameters.

**Acceptance Criteria:**
- [ ] Determine intended scale (WAD: 1e18=100% or PPM: 1e6=100%)
- [ ] Fix `DEFAULT_BOND_MIN_BONUS_PERCENTAGE` to match "5%" intent
- [ ] Fix `DEFAULT_BOND_MAX_BONUS_PERCENTAGE` to match "10%" intent
- [ ] Update comments if scale is different than WAD

### US-IDXEX-030.2: Add Scale Validation Tests

As a security auditor, I want tests proving default values produce expected economic outcomes.

**Acceptance Criteria:**
- [ ] Test: manager init sets bond terms to intended scale
- [ ] Test: bonus calculation with defaults produces expected multiplier
- [ ] Test: edge case at max bonus doesn't overflow

## Technical Details

**File to modify:** `contracts/constants/Indexedex_CONSTANTS.sol`

**If WAD-scaled (1e18 = 100%):**
```solidity
// Current (wrong):
uint256 constant DEFAULT_BOND_MIN_BONUS_PERCENTAGE = 5e18;   // 500%
uint256 constant DEFAULT_BOND_MAX_BONUS_PERCENTAGE = 10e18;  // 1000%

// Fixed:
uint256 constant DEFAULT_BOND_MIN_BONUS_PERCENTAGE = 5e16;   // 5% = 0.05 * 1e18
uint256 constant DEFAULT_BOND_MAX_BONUS_PERCENTAGE = 1e17;   // 10% = 0.10 * 1e18
```

**If PPM-scaled (1e6 = 100%):**
```solidity
uint256 constant DEFAULT_BOND_MIN_BONUS_PERCENTAGE = 5e4;    // 5% = 50000 PPM
uint256 constant DEFAULT_BOND_MAX_BONUS_PERCENTAGE = 1e5;    // 10% = 100000 PPM
```

**Design Decision (bundled):** Based on `BALANCER_V3_FEE_DENOMINATOR = 1e18` in the same file and usage patterns like `ONE_WAD + terms.maxBonusPercentage`, WAD-scaling (1e18 = 100%) appears to be the convention. Values should be `5e16` and `1e17`.

## Files to Create/Modify

**Modified Files:**
- `contracts/constants/Indexedex_CONSTANTS.sol` - Fix bonus percentage constants

**Tests:**
- `test/foundry/spec/constants/BondTermsDefaults.t.sol` - Scale validation tests

## Related Files to Check

- `contracts/manager/IndexedexManagerDFPkg.sol` - Uses defaults in `initAccount`
- `contracts/vaults/seigniorage/SeigniorageNFTVaultTarget.sol` - Consumes bond terms
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol` - Consumes bond terms

## Inventory Check

Before starting, verify:
- [ ] Locate `Indexedex_CONSTANTS.sol` and find bond bonus constants
- [ ] Confirm how bonus terms are used in NFT vault calculations
- [ ] Verify `ONE_WAD` value (should be 1e18)
- [ ] Check if any existing tests fail with corrected values

## Completion Criteria

- [ ] Bonus percentage constants fixed to match comments
- [ ] Scale validation tests pass
- [ ] Build succeeds
- [ ] All existing tests pass (or update tests if they assumed wrong values)

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
