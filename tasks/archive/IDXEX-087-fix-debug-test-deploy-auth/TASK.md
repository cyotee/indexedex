# Task IDXEX-087: Fix ProtocolDETF SyntheticPrice Debug Test Deploy Auth

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** None (IDXEX-027, which introduced the auth requirement, is archived)
**Worktree:** `feature/fix-debug-test-deploy-auth`

---

## Description

The `ProtocolDETF_SyntheticPrice_Debug.t.sol` test fails with `NotOperator(0x7FA9...)` during `setUp()`. The `_deployVaultsAndRateProviders()` function calls `aerodromeStandardExchangeDFPkg.deployVault()` without `vm.prank(owner)`, but the underlying `VaultRegistryDeploymentTarget.deployVault()` now requires the caller to be owner, operator, or a registered package (added by IDXEX-027). The test contract address (Foundry's default `msg.sender`) has none of these roles.

Multiple archived tasks (IDXEX-018, IDXEX-054, IDXEX-055) have noted this as a "pre-existing debug test failure" without fixing it.

## Dependencies

None — this is a standalone test fix.

## User Stories

### US-IDXEX-087.1: Add Proper Authorization to Debug Test setUp

As a developer, I want the ProtocolDETF SyntheticPrice debug test to pass so that the full test suite runs cleanly without known setUp failures.

**Acceptance Criteria:**
- [ ] `_deployVaultsAndRateProviders()` uses `vm.prank(owner)` (or `vm.startPrank`/`vm.stopPrank`) before each `deployVault` call
- [ ] Any other calls in setUp() that require auth are similarly pranked
- [ ] `setUp()` completes without reverting
- [ ] All tests in the file pass (note: `test_mint_chir_with_weth` uses `vm.skip(true)` — this is expected)

## Technical Details

The error occurs at line 153-154 of the debug test:
```solidity
chirWethVault = IStandardExchange(aerodromeStandardExchangeDFPkg.deployVault(chirWethPool));
richChirVault = IStandardExchange(aerodromeStandardExchangeDFPkg.deployVault(richChirPool));
```

The DFPkg's `deployVault` calls `VAULT_REGISTRY_DEPLOYMENT.deployVault(SELF, ...)`, which requires `_onlyOwnerOrOperatorOrPkg()` authorization. The fix is to add `vm.prank(owner)` before each call.

Also check `_deployNftAndRichir()` at line 249 (`protocolNFTVaultPkg.deployVault(...)`) — this one may also need auth, though the package is registered on line 246 first.

## Files to Create/Modify

**Modified Files:**
- `test/foundry/debug/ProtocolDETF_SyntheticPrice_Debug.t.sol` — Add `vm.prank(owner)` or `vm.startPrank(owner)` around `deployVault` calls in `_deployVaultsAndRateProviders()` and potentially `_deployNftAndRichir()`

## Inventory Check

Before starting, verify:
- [ ] `VaultRegistryDeploymentTarget.deployVault()` has `_onlyOwnerOrOperatorOrPkg()` guard
- [ ] `owner` is defined in the base test class (inherited from `IndexedexTest`)
- [ ] The `_deployNftAndRichir()` function's `registerPackage` + `deployVault` sequence is correctly ordered

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] `forge test --match-contract ProtocolDETFSyntheticPriceDebugTest` passes
- [ ] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`
