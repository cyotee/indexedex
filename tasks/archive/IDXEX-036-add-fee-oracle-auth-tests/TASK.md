# Task IDXEX-036: Add Fee Oracle Authorization and Bounds Tests

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-02
**Priority:** HIGH
**Dependencies:** IDXEX-026
**Worktree:** `feature/add-fee-oracle-auth-tests`

---

## Description

The code review identified no tests asserting fee-oracle setter authorization or parameter bounds. This task adds comprehensive test coverage for:
1. Authorization checks on all fee oracle setters
2. Parameter bounds validation (if implemented)
3. Fee share minting dilution under extreme values

**Source:** REVIEW_REPORT.md lines 904, 914

## User Stories

### US-IDXEX-036.1: Fee Oracle Setter Authorization Tests

As a security auditor, I want tests proving that unauthorized callers cannot modify fee parameters.

**Acceptance Criteria:**
- [ ] Test: `setDefaultUsageFee` reverts for non-owner/non-operator
- [ ] Test: `setDefaultUsageFeeOfTypeId` reverts for non-owner/non-operator
- [ ] Test: `setUsageFeeOfVault` reverts for non-owner/non-operator
- [ ] Test: `setDefaultBondTerms` reverts for non-owner/non-operator
- [ ] Test: `setDefaultBondTermsOfTypeId` reverts for non-owner/non-operator
- [ ] Test: `setVaultBondTerms` reverts for non-owner/non-operator
- [ ] Test: `setDefaultDexSwapFee` reverts for non-owner/non-operator
- [ ] Test: `setDefaultDexSwapFeeOfTypeId` reverts for non-owner/non-operator
- [ ] Test: `setVaultDexSwapFee` reverts for non-owner/non-operator
- [ ] Test: owner can call all setters
- [ ] Test: operator can call all setters

### US-IDXEX-036.2: Fee Parameter Bounds Tests

As a protocol administrator, I want tests validating fee bounds once constraints are defined.

**Acceptance Criteria:**
- [ ] Test: usage fee cannot exceed 100% (or defined max)
- [ ] Test: swap fee within Balancer-compatible range
- [ ] Test: bond terms within expected ranges

### US-IDXEX-036.3: Fee Dilution Impact Tests

As a security researcher, I want tests quantifying the impact of extreme fee values.

**Acceptance Criteria:**
- [ ] Test: 0% usage fee → no shares minted to feeTo
- [ ] Test: 100% usage fee → maximum dilution (document behavior)
- [ ] Test: out-of-range values (if possible) → revert or bounded

## Technical Details

**Test file:** `test/foundry/spec/oracles/fee/VaultFeeOracleManagerFacet_Auth.t.sol`

**Test structure:**
```solidity
contract VaultFeeOracleManagerFacet_AuthTest is TestBase {
    function setUp() public {
        // Deploy fee oracle with known owner/operator
    }

    // Authorization tests
    function test_setDefaultUsageFee_revertsForNonOwner() public { }
    function test_setDefaultUsageFee_succeedsForOwner() public { }
    function test_setDefaultUsageFee_succeedsForOperator() public { }
    // ... repeat for all 9 setters

    // Bounds tests (once constraints defined)
    function test_setDefaultUsageFee_revertsAboveMax() public { }
    function test_setDefaultDexSwapFee_withinBalancerRange() public { }

    // Dilution impact tests
    function test_usageFeeOfVault_zero_noFeeSharesMinted() public { }
    function test_usageFeeOfVault_max_maxDilution() public { }
}
```

## Files to Create

**New Files:**
- `test/foundry/spec/oracles/fee/VaultFeeOracleManagerFacet_Auth.t.sol` - Authorization tests
- `test/foundry/spec/oracles/fee/VaultFeeOracle_Bounds.t.sol` - Bounds validation tests
- `test/foundry/spec/oracles/fee/VaultFeeOracle_Dilution.t.sol` - Economic impact tests

## Dependencies

This task should be done after IDXEX-026 (which adds the access control) so that tests can verify the fix.

## Inventory Check

Before starting, verify:
- [ ] IDXEX-026 is complete (or use known-broken state for "before" tests)
- [ ] Understand fee oracle initialization pattern
- [ ] Identify test base that provides owner/operator setup

## Completion Criteria

- [ ] All authorization tests pass
- [ ] Bounds tests document expected ranges
- [ ] Dilution tests quantify economic impact
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
