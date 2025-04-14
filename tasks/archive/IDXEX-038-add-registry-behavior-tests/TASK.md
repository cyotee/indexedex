# Task IDXEX-038: Add Registry Register/Unregister Behavior Tests

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-02
**Priority:** MEDIUM
**Dependencies:** None
**Worktree:** `feature/add-registry-behavior-tests`

---

## Description

The code review identified no targeted tests validating vault/package registry unregister behavior. The registry has specific behaviors:
1. Some indexes are cleaned on unregister, others are append-only
2. Package unregistration doesn't remove from `pkgsOfType` or fee-type-id sets
3. Vault unregistration doesn't garbage-collect `contentsIds` or `vaultTokens`

These semantics should be documented via tests.

**Source:** REVIEW_REPORT.md lines 269-350, 906-907

## User Stories

### US-IDXEX-038.1: Vault Registration/Unregistration Tests

As a protocol administrator, I want tests documenting vault registry behavior.

**Acceptance Criteria:**
- [ ] Test: `registerVault` adds to all relevant indexes
- [ ] Test: `unregisterVault` removes from expected indexes
- [ ] Test: `unregisterVault` does NOT remove from append-only sets (document behavior)
- [ ] Test: repeated registration attempts (idempotence)
- [ ] Test: removal of non-existent vault

### US-IDXEX-038.2: Package Registration/Unregistration Tests

As a protocol administrator, I want tests documenting package registry behavior.

**Acceptance Criteria:**
- [ ] Test: `registerPkg` adds to all relevant indexes
- [ ] Test: `unregisterPkg` removes from `packages` set
- [ ] Test: `unregisterPkg` does NOT remove from `pkgsOfType` (document behavior)
- [ ] Test: `packagesOfTypeId` results after unregister (stale entry present)

### US-IDXEX-038.3: Query Behavior Tests

As an integrator, I want tests documenting query results.

**Acceptance Criteria:**
- [ ] Test: `vaults()` returns all registered vaults
- [ ] Test: `vaultsOfType` returns correct subset
- [ ] Test: `vaultsOfToken` returns correct subset
- [ ] Test: query results after unregister

### US-IDXEX-038.4: Anti-Spam Behavior Tests (if IDXEX-027 keeps permissionless)

As a security researcher, I want tests documenting spam deployment behavior.

**Acceptance Criteria:**
- [ ] Test: multiple vault deployments increase registry size
- [ ] Test: gas cost growth over many deployments
- [ ] Test: query performance with large registry

## Technical Details

**Test files:**
- `test/foundry/spec/registries/vault/VaultRegistry_Registration.t.sol`
- `test/foundry/spec/registries/vault/VaultRegistryPackage_Registration.t.sol`
- `test/foundry/spec/registries/vault/VaultRegistry_Queries.t.sol`

**Key findings to document via tests:**

**VaultRegistryVaultRepo._removeVault:**
- Removes from most indexes
- Does NOT remove from `contentsIds` (set of all ever seen)
- Does NOT remove from `vaultTokens` (set of all ever seen)
- Incorrectly assigns `feeTypeIdsOfVault[vault] = vaultConfig.vaultFeeTypeIds` instead of clearing

**VaultRegistryVaultPackageRepo._removePkg:**
- Removes from `packages` set
- Clears `pkgNames` and `pkgFeeTypeIds`
- Does NOT remove from `pkgsOfType[typeId]`
- Does NOT remove from `vaultTypeIds`
- Does NOT remove from fee-type-id sets

## Files to Create

**New Files:**
- `test/foundry/spec/registries/vault/VaultRegistry_Registration.t.sol`
- `test/foundry/spec/registries/vault/VaultRegistryPackage_Registration.t.sol`
- `test/foundry/spec/registries/vault/VaultRegistry_Queries.t.sol`

## Inventory Check

Before starting, verify:
- [ ] Locate `VaultRegistryVaultRepo._registerVault` and `_removeVault`
- [ ] Locate `VaultRegistryVaultPackageRepo._registerPkg` and `_removePkg`
- [ ] Understand existing test setup for registry

## Completion Criteria

- [ ] Registration/unregistration behavior documented via tests
- [ ] Query behavior documented via tests
- [ ] Append-only semantics clearly documented in test comments
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
