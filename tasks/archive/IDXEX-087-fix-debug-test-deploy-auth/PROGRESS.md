# Progress Log: IDXEX-087

## Current Checkpoint

**Last checkpoint:** Complete
**Next step:** None — all acceptance criteria met
**Build status:** PASS
**Test status:** PASS (2 passed, 1 skipped as expected)

---

## Session Log

### 2026-02-08 - Fix Complete

**Root cause:** The actual failure was NOT at `deployVault` calls (lines 153-154) as originally described. The DFPkg is properly registered as a package, so `_onlyOwnerOrOperatorOrPkg()` recognizes it during `deployVault`.

The real bug was in `_seedAerodromePool()` at lines 391-394 — a **dangling conditional** where `vm.prank(owner)` was conditionally applied but `IERC20MintBurn(address(rich)).mint(...)` was called unconditionally:

```solidity
// BEFORE (broken):
if (tokenA == address(rich)) vm.prank(owner);
IERC20MintBurn(address(rich)).mint(address(this), amountA);  // always runs!
```

When `tokenA != rich` (e.g., CHIR/WETH pool), the `mint()` call executes without the owner prank, triggering `NotOperator`.

**Fix applied:**
1. `_seedAerodromePool()` — wrapped `vm.prank(owner)` + `mint()` inside braces so both are conditional
2. `IVaultRegistryDeployment.sol:14` — fixed broken import from `crane/` to `@crane/` (pre-existing build issue)

**Files modified:**
- `test/foundry/debug/ProtocolDETF_SyntheticPrice_Debug.t.sol` — fixed conditional mint logic
- `contracts/interfaces/IVaultRegistryDeployment.sol` — fixed import remapping prefix

**Verification:**
- `forge build` — PASS (no errors)
- `forge test --match-contract ProtocolDETFSyntheticPriceDebugTest` — PASS
  - `test_debug_synthetic_price` — PASS
  - `test_log_pool_state` — PASS
  - `test_mint_chir_with_weth` — SKIP (expected, uses `vm.skip(true)`)

### 2026-02-08 - Task Created

- Task designed via /pm:design
- TASK.md populated with requirements
- Ready for agent assignment via /pm:launch
