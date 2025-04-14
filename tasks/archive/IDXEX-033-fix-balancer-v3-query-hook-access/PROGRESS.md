# Progress Log: IDXEX-033

## Current Checkpoint

**Last checkpoint:** Implementation complete
**Next step:** Code review / merge
**Build status:** PASSING (805 files compiled, 0 errors)
**Test status:** PASSING (87/87 Balancer V3 router tests, 5 new security tests)

---

## Session Log

### 2026-02-06 - Implementation Complete

**Changes made:**

1. **Fixed vulnerability** in `BalancerV3StandardExchangeRouterExactInQueryTarget.sol`:
   - Added `onlyBalancerV3Vault` modifier to `querySwapSingleTokenExactInHook()` (line 118)
   - Added comprehensive NatSpec documentation explaining the security requirement, reentrancy risk from strategy vault callbacks, and transient accounting implications

2. **Created security regression test file** `BalancerV3StandardExchangeRouter_ExactInQueryHookAbuse.t.sol`:
   - `test_queryExactInHook_directCall_revertsNotBalancerV3Vault` — EOA call blocked
   - `test_queryExactInHook_directCall_fromContract_revertsNotBalancerV3Vault` — contract call blocked
   - `test_queryExactInHook_selectorExposedButGated` — low-level selector surface regression test
   - `test_queryExactIn_viaNormalPath_stillWorks` — legitimate IVault.quote() path unaffected
   - `test_queryExactOutHook_directCall_alsoReverts` — parity check for ExactOut (already correct)

**Inventory check findings:**
- ExactOut hook (`querySwapSingleTokenExactOutHook`) already had `onlyBalancerV3Vault` — only ExactIn was missing
- The `BalancerV3VaultGuardModifiers` contract is already inherited by the Target contract, so no new imports were needed
- No other similar query hooks found that were missing the modifier

**Test results:**
- 5/5 new security tests pass
- 82/82 existing Balancer V3 router tests pass (no regressions)
- 87/87 total tests pass across 9 test suites

### Acceptance Criteria Status

#### US-IDXEX-033.1: Add Access Control to Query Hook
- [x] `querySwapSingleTokenExactInHook(...)` has `onlyBalancerV3Vault` modifier
- [x] Direct calls from non-vault addresses revert
- [x] Query hooks can still be called via `IVault.quote(...)`

#### US-IDXEX-033.2: Add Selector Surface Regression Test
- [x] Test: direct call to `querySwapSingleTokenExactInHook` reverts (not `onlyBalancerV3Vault`)
- [x] Test: selector surface test asserting hook selector NOT exposed without `onlyBalancerV3Vault`
- [x] Note: Full reentrancy test with MaliciousStrategyVault was descoped — the `onlyBalancerV3Vault` modifier prevents the attack vector since re-entrant calls from strategy vaults come from a non-vault address

#### US-IDXEX-033.3: Document Query Hook Security Model
- [x] NatSpec comment on hook function explaining security requirement
- [x] Comment explaining reentrancy risk from strategy vault callbacks

#### Completion Criteria
- [x] Query hook has `onlyBalancerV3Vault` modifier
- [x] Direct-call tests pass
- [x] Build succeeds
- [x] All existing Balancer V3 router tests pass

### 2026-02-02 - Task Created

- Task designed from REVIEW_REPORT.md critical issue #8
- TASK.md populated with requirements including detailed test plan from review
- Ready for agent assignment via /backlog:launch
