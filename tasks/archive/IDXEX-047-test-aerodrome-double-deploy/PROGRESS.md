# Progress Log: IDXEX-047

## Current Checkpoint

**Last checkpoint:** Implementation complete
**Next step:** Code review
**Build status:** Pass
**Test status:** Pass (all 10 DeployWithPool tests pass; 671/676 spec tests pass, 5 pre-existing failures unrelated)

---

## Session Log

### 2026-02-07 - Implementation Complete

- Added 2 new tests to `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchange_DeployWithPool.t.sol`:
  1. `test_DoubleDeployVaultWithDeposit_SamePool` - Calls deployVault with deposit twice on the same pool. Verifies both deposits succeed (safeApprove doesn't revert), vault addresses match, shares are allocated correctly to both recipients, and pool reserves reflect both deposits.
  2. `test_DoubleDeployVaultWithDeposit_AllowanceCleared` - Verifies that the LP token allowance from DFPkg to vault is zero after each deposit call, confirming the `forceApprove(vault, 0)` cleanup works correctly.
- Build: passes
- All 10 DeployWithPool tests pass (including 8 existing + 2 new)
- All spec tests: 671 pass, 5 pre-existing failures (bond terms fuzz, slippage, DETF routes - unrelated to this change)
- Note: `forge test` with verbose flags crashes due to known Foundry macOS bug (SCDynamicStore NULL object), used `--json` output to verify results

### Acceptance Criteria Status

- [x] Test calls deployVault with deposit twice on the same pool
- [x] Second call succeeds without safeApprove revert
- [x] Both deposits produce correct vault shares
- [x] All existing tests still pass
- [x] Build succeeds

### 2026-02-06 - Task Created

- Task created from code review suggestion
- Origin: IDXEX-006 REVIEW.md, deferred debt D-03
- Ready for agent assignment via /backlog:launch
