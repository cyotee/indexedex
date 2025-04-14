# Task IDXEX-054: Add Seigniorage Manager Setter Functions

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Priority:** LOW
**Dependencies:** IDXEX-032 ✓
**Worktree:** `feature/add-seigniorage-fee-setters`
**Origin:** Code review suggestion from IDXEX-032

---

## Description

Usage fees and DEX swap fees have public setter functions (`setDefaultUsageFee`, `setUsageFeeOfVault`, etc.) on `IVaultFeeOracleManager`, but seigniorage incentive percentages have no equivalent setters. The storage layer (`VaultFeeOracleRepo`) supports per-vault and per-type seigniorage overrides, but they can only be set during init. Adding setter functions would complete the interface symmetry and allow runtime reconfiguration of seigniorage parameters.

(Created from code review of IDXEX-032, Suggestion 1)

## User Stories

### US-IDXEX-054.1: Add Seigniorage Incentive Setters

As a protocol operator, I want to adjust seigniorage incentive percentages at runtime so that I can tune protocol economics without redeployment.

**Acceptance Criteria:**
- [ ] `setDefaultSeigniorageIncentivePercentage(uint256)` added to `IVaultFeeOracleManager`
- [ ] `setDefaultSeigniorageIncentivePercentageOfTypeId(bytes32, uint256)` added to `IVaultFeeOracleManager`
- [ ] `setSeigniorageIncentivePercentageOfVault(address, uint256)` added to `IVaultFeeOracleManager`
- [ ] All three implemented in `VaultFeeOracleManagerFacet` with `onlyOwnerOrOperator` access control
- [ ] Setters delegate to existing `VaultFeeOracleRepo` internal functions
- [ ] `facetFuncs()` updated to include new selectors
- [ ] Events emitted for each setter (matching existing fee setter event pattern)
- [ ] Tests pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/interfaces/IVaultFeeOracleManager.sol` - Add function signatures and events
- `contracts/oracles/fee/VaultFeeOracleManagerFacet.sol` - Implement setters
- `contracts/fee/collector/FeeCollectorManagerFacet.sol` - Update `facetFuncs()` if needed

**Tests:**
- `test/foundry/spec/oracles/fee/VaultFeeOracleManagerFacet_Seigniorage.t.sol` - Setter tests

## Inventory Check

Before starting, verify:
- [ ] IDXEX-032 is complete
- [ ] Examine existing setter pattern in `VaultFeeOracleManagerFacet` (usage fee / DEX swap fee setters)
- [ ] Confirm `VaultFeeOracleRepo` has internal setter functions for seigniorage
- [ ] Check `facetFuncs()` selector registration pattern

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
