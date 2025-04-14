# Task IDXEX-047: Add Test for Aerodrome Double deployVault with Deposit

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Type:** Testing
**Dependencies:** IDXEX-006 ✓
**Worktree:** `feature/test-aerodrome-double-deploy`
**Origin:** Deferred debt D-03 from IDXEX-006 review

---

## Description

Current tests only call `deployVault` with deposit once per pool. Add a test that calls `deployVault` with deposit twice on the same pool to exercise the LP approval path on a repeated call. This verifies that `safeApprove` doesn't revert on the second call (which it would if the first call left residual allowance on tokens with USDT-style approval semantics).

(Created from IDXEX-006 review, deferred debt D-03)

## Files to Create/Modify

**Modified Files:**
- `test/foundry/spec/protocols/dexes/aerodrome/v1/AerodromeStandardExchange_DeployWithPool.t.sol`

## Test Scenario

1. Deploy vault with new pool + initial deposit (first call)
2. Add more reserves to the pool
3. Deploy vault again with deposit on the same existing pool (second call)
4. Verify both deposits succeeded and vault received correct LP amounts

## Acceptance Criteria

- [ ] Test calls deployVault with deposit twice on the same pool
- [ ] Second call succeeds without safeApprove revert
- [ ] Both deposits produce correct vault shares
- [ ] All existing tests still pass
- [ ] Build succeeds

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
