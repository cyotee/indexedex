# Task IDXEX-032: Fix Fee Units Documentation (PPM vs WAD)

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-02
**Priority:** MEDIUM
**Dependencies:** None
**Worktree:** `feature/fix-fee-units-documentation`

---

## Description

There is a documentation inconsistency regarding fee unit conventions:

- `IVaultFeeOracleQuery.sol` NatSpec claims "fees denominated in PPM (parts per million)"
- `Indexedex_CONSTANTS.sol` uses WAD-looking values (`1e15`, `5e16`)
- `BALANCER_V3_FEE_DENOMINATOR = 1e18` (WAD scale)

This suggests fee values are actually WAD-scaled (1e18 = 100%), not PPM (1e6 = 100%). Any consumer using wrong unit assumptions may under/overcharge by ~1e12.

**Source:** REVIEW_REPORT.md lines 209-221, 853, 920, 942

## User Stories

### US-IDXEX-032.1: Determine Correct Fee Scale Convention

As a protocol developer, I want clear documentation on the fee scale so that I use correct values.

**Acceptance Criteria:**
- [ ] Determine whether fees are WAD (1e18=100%) or PPM (1e6=100%)
- [ ] Document the decision in code comments and/or README

### US-IDXEX-032.2: Fix Documentation

As a future integrator, I want accurate NatSpec so that I don't misinterpret fee values.

**Acceptance Criteria:**
- [ ] `IVaultFeeOracleQuery.sol` NatSpec matches actual convention
- [ ] `Indexedex_CONSTANTS.sol` comments match values
- [ ] All fee-related interfaces have consistent unit documentation

### US-IDXEX-032.3: Add Unit Consistency Tests

As a security auditor, I want tests proving fee units are consistent across the system.

**Acceptance Criteria:**
- [ ] Test: default values set in manager init produce expected fee percentages
- [ ] Test: fee calculations produce expected outcomes (e.g., 1% fee = 1e16 if WAD)

## Technical Details

**Analysis suggests WAD convention (1e18 = 100%):**
- `BALANCER_V3_FEE_DENOMINATOR = 1e18`
- `DEFAULT_VAULT_USAGE_FEE = 1e15` comment says "0.1%" → 0.001 * 1e18 = 1e15 ✓
- `DEFAULT_DEX_FEE = 5e16` comment says "5%" → 0.05 * 1e18 = 5e16 ✓

**Files to update:**

**`contracts/interfaces/IVaultFeeOracleQuery.sol`:**
```solidity
// Current (wrong):
/// @notice All fees are denominated in PPM (parts per million)

// Fixed:
/// @notice All fees are denominated in WAD (1e18 = 100%)
```

**Also verify/update:**
- `IVaultFeeOracleManager.sol` - Event and function NatSpec
- Any README or developer documentation

## Zero-Value Sentinel Semantics

**Related issue:** `usageFeeOfVault` and `dexSwapFeeOfVault` treat 0 as "unset" and fall back to defaults. This prevents intentionally setting an explicit 0% fee.

**Document this behavior:** Add NatSpec explaining that 0 means "use default" and explicit 0% fee is not supported via per-vault/per-type setters.

## Files to Create/Modify

**Modified Files:**
- `contracts/interfaces/IVaultFeeOracleQuery.sol` - Fix NatSpec
- `contracts/interfaces/IVaultFeeOracleManager.sol` - Fix NatSpec (if needed)
- `contracts/constants/Indexedex_CONSTANTS.sol` - Verify comments match values

**Tests:**
- `test/foundry/spec/oracles/fee/VaultFeeOracle_Units.t.sol` - Unit consistency tests

## Inventory Check

Before starting, verify:
- [ ] Read `IVaultFeeOracleQuery.sol` NatSpec
- [ ] Confirm default values in `Indexedex_CONSTANTS.sol`
- [ ] Check how fees are used in vault calculations

## Completion Criteria

- [ ] Fee unit convention documented consistently
- [ ] NatSpec updated to match actual convention
- [ ] Unit consistency tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
