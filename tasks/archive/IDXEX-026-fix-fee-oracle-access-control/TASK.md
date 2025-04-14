# Task IDXEX-026: Fix VaultFeeOracleManagerFacet Access Control

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-02
**Priority:** CRITICAL
**Dependencies:** None
**Worktree:** `feature/fix-fee-oracle-access-control`

---

## Description

The `VaultFeeOracleManagerFacet` is missing `onlyOwner` (or `onlyOwnerOrOperator`) access control on 9 out of 10 setter functions. Only `setFeeTo(IFeeCollectorProxy)` is protected. This allows any user to change global fee parameters, per-type defaults, and per-vault overrides, enabling fee bypass, economic manipulation, or griefing across all vaults that consume the fee oracle.

**Source:** REVIEW_REPORT.md lines 176-199

## Impact Analysis

Multiple Standard Exchange vaults (Aerodrome, UniswapV2, CamelotV2) compute fee shares via:
- `feeOracle.usageFeeOfVault(address(this))`
- Fee collection mints vault shares to `feeOracle.feeTo()`
- Camelot also uses `feeTo` as swap `referrer`

If fee-oracle setters are public, attackers can:
1. Set usage fee to 0% → bypass all protocol fees
2. Set usage fee to 100% → drain vaults via share dilution
3. Manipulate bond terms → inflate/deflate NFT bonuses
4. Redirect referral rewards (Camelot)

## User Stories

### US-IDXEX-026.1: Add Access Control to Fee Oracle Setters

As a protocol administrator, I want fee oracle setters to be restricted so that only authorized parties can modify economic parameters.

**Acceptance Criteria:**
- [ ] `setDefaultUsageFee(uint256)` is `onlyOwnerOrOperator`
- [ ] `setDefaultUsageFeeOfTypeId(bytes4,uint256)` is `onlyOwnerOrOperator`
- [ ] `setUsageFeeOfVault(address,uint256)` is `onlyOwnerOrOperator`
- [ ] `setDefaultBondTerms(BondTerms)` is `onlyOwnerOrOperator`
- [ ] `setDefaultBondTermsOfTypeId(bytes4,BondTerms)` is `onlyOwnerOrOperator`
- [ ] `setVaultBondTerms(address,BondTerms)` is `onlyOwnerOrOperator`
- [ ] `setDefaultDexSwapFee(uint256)` is `onlyOwnerOrOperator`
- [ ] `setDefaultDexSwapFeeOfTypeId(bytes4,uint256)` is `onlyOwnerOrOperator`
- [ ] `setVaultDexSwapFee(address,uint256)` is `onlyOwnerOrOperator`

### US-IDXEX-026.2: Add Authorization Tests

As a security auditor, I want tests proving that unauthorized callers cannot modify fee parameters.

**Acceptance Criteria:**
- [ ] Test each setter reverts for non-owner/non-operator
- [ ] Test owner can call each setter
- [ ] Test operator can call each setter

## Technical Details

**File to modify:** `contracts/oracles/fee/VaultFeeOracleManagerFacet.sol`

The facet likely inherits from a mixin providing `onlyOwner`/`onlyOwnerOrOperator`. The pattern already exists on `setFeeTo`.

```solidity
// Current (missing access control)
function setDefaultUsageFee(uint256 fee_) external {
    VaultFeeOracleRepo._setDefaultUsageFee(fee_);
}

// Fixed
function setDefaultUsageFee(uint256 fee_) external onlyOwnerOrOperator {
    VaultFeeOracleRepo._setDefaultUsageFee(fee_);
}
```

## Design Decision (Bundled)

**Question from review:** Should these setters be `onlyOwner` or `onlyOwnerOrOperator`?

**Recommendation:** Use `onlyOwnerOrOperator` to allow protocol operators to adjust parameters without requiring the owner key for routine operations. This matches the pattern in `VaultRegistryDeploymentTarget.deployPkg`.

## Files to Create/Modify

**Modified Files:**
- `contracts/oracles/fee/VaultFeeOracleManagerFacet.sol` - Add access control modifiers

**Tests:**
- `test/foundry/spec/oracles/fee/VaultFeeOracleManagerFacet_Auth.t.sol` - Authorization tests

## Inventory Check

Before starting, verify:
- [ ] `VaultFeeOracleManagerFacet.sol` exists and has the unprotected setters
- [ ] Understand which access control mixin is available (likely `MultiStepOwnableModifiers`)
- [ ] Confirm `setFeeTo` uses `onlyOwner` pattern to follow

## Completion Criteria

- [ ] All 9 setters have `onlyOwnerOrOperator` modifier
- [ ] Authorization tests pass
- [ ] Build succeeds (`forge build`)
- [ ] Existing tests still pass

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
