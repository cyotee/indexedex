# Task IDXEX-027: Fix VaultRegistryDeploymentTarget.deployVault Authorization

**Repo:** IndexedEx
**Status:** Complete
**Created:** 2026-02-02
**Completed:** 2026-02-03
**Priority:** HIGH
**Dependencies:** None
**Worktree:** `feature/fix-vault-registry-deployment-auth`

---

## Description

`VaultRegistryDeploymentTarget.deployVault(...)` is `public` with no access modifier, allowing anyone to deploy vault instances for any registered package. While `deployPkg(...)` is correctly restricted to `onlyOwnerOrOperator`, vault deployment is permissionless.

This may be intentional for public vault creation, but creates spam/grief vectors and unbounded on-chain storage growth since every deployment adds state entries across multiple registry sets/mappings.

**Source:** REVIEW_REPORT.md lines 244-266

## Design Decision

**Chosen approach:** Restrict to owner/operator **OR** registered package

This hybrid approach:
1. Blocks arbitrary unauthorized users from directly calling `deployVault()`
2. Allows registered packages (deployed via `deployPkg()`) to deploy vaults via their helper methods
3. Maintains the existing `DFPkg.deployVault(pool)` pattern that routes through the registry
4. Security boundary is at package registration (`deployPkg()` requires `onlyOwnerOrOperator`)

## User Stories

### US-IDXEX-027.1: Add Access Control (if restricted)

As a protocol administrator, I want vault deployment to be controlled so that registry storage growth is managed.

**Acceptance Criteria:**
- [x] `deployVault(...)` has authorization guard (custom `_onlyOwnerOrOperatorOrPkg()`)
- [x] Test: non-owner/non-operator cannot deploy vault directly
- [x] Test: owner can deploy vault
- [x] Test: registered package can deploy vault (DFPkg.deployVault() pattern)

### US-IDXEX-027.2: Add Anti-Spam (if permissionless)

*Not implemented - chose restricted approach instead.*

## Technical Details

**File modified:** `contracts/registries/vault/VaultRegistryDeploymentTarget.sol`

**Implementation:**
```solidity
function deployVault(IStandardVaultPkg pkg, bytes calldata pkgArgs) public returns (address vault) {
    // Authorization: owner, operator, or registered package
    _onlyOwnerOrOperatorOrPkg();
    // ...
}

function _onlyOwnerOrOperatorOrPkg() internal view {
    if (MultiStepOwnableRepo._owner() == msg.sender) return;
    if (OperableRepo._isOperator(msg.sender)) return;
    if (OperableRepo._isFunctionOperator(msg.sig, msg.sender)) return;
    if (VaultRegistryVaultPackageRepo._isPkg(msg.sender)) return;
    revert IOperable.NotOperator(msg.sender);
}
```

## Files Created/Modified

**Modified Files:**
- [x] `contracts/registries/vault/VaultRegistryDeploymentTarget.sol` - Added authorization

**Tests:**
- [x] `test/foundry/spec/registries/vault/VaultRegistryDeployment_Auth.t.sol` - 6 authorization tests

## Inventory Check

Before starting, verify:
- [x] Confirm `deployVault` is currently unguarded ✅
- [x] Check if any scripts/tests rely on permissionless deployment ✅ (DFPkg pattern)
- [x] Understand storage growth impact per deployment ✅ (registry entries)

## Completion Criteria

- [x] Design decision documented ✅
- [x] Access control implemented ✅
- [x] Authorization tests pass ✅ (6/6)
- [x] Build succeeds ✅
- [x] Existing tests still pass ✅ (Aerodrome, UniswapV2, CamelotV2, ProtocolDETF, Seigniorage)

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
