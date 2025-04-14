# Task IDXEX-080: Add Asymmetric Double Deploy Deposit Test

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Type:** Testing / Coverage
**Dependencies:** IDXEX-047 ✓
**Worktree:** `feature/IDXEX-080-asymmetric-double-deploy-test`
**Origin:** Code review suggestion from IDXEX-047 (Suggestion 1)

---

## Description

Add a variation of `test_DoubleDeployVaultWithDeposit_SamePool` that uses asymmetric (non-equal) amounts for the two deposits. The current test uses equal amounts (100 ether each) for both deposits, which makes assertions token-order-agnostic but doesn't exercise the proportional calculation path on the second deposit.

A test with asymmetric amounts (e.g., first deposit 100:200, second deposit 50:100) would exercise `_depositLiquidity` -> `_proportionalDeposit` on the second call, providing additional coverage of the proportional math for repeated deposits on the same pool.

(Created from code review of IDXEX-047, Suggestion 1)

## Dependencies

- IDXEX-047: Add Test for Aerodrome Double deployVault (completed - parent task)

## Acceptance Criteria

- [ ] New test calls `deployVault` with deposit twice on the same pool using asymmetric amounts (different amountA/amountB ratios)
- [ ] Second deposit exercises the `_proportionalDeposit` code path
- [ ] Both deposits succeed without reverts
- [ ] Both deposits produce correct vault shares for their respective recipients
- [ ] Pool reserves reflect both deposits
- [ ] All existing tests still pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchange_DeployWithPool.t.sol`

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
