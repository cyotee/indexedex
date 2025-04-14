# Task IDXEX-057: Add Balancer V3 Exact-Out Fork Test

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Priority:** MEDIUM
**Dependencies:** IDXEX-034 ✓
**Worktree:** `feature/add-balancer-v3-exact-out-fork-test`
**Origin:** Code review suggestion from IDXEX-034

---

## Description

The IDXEX-034 review identified a coverage gap: the acceptance criterion "Test: integration with Balancer V3 batch router exact-out" was not covered because it requires a fork test (mainnet state). Add a fork test that verifies the full Balancer V3 batch router exact-out pipeline including pretransferred refund semantics.

(Created from code review of IDXEX-034, Suggestion 1)

## User Stories

### US-IDXEX-057.1: Balancer V3 Exact-Out Fork Test

As a security auditor, I want a fork test proving that the Balancer V3 batch router exact-out flow correctly refunds excess pretransferred tokens.

**Acceptance Criteria:**
- [ ] Fork test exercises `exchangeOut` via Balancer V3 batch router
- [ ] Verifies pretransferred refund is returned to caller
- [ ] Verifies exact output amount is received
- [ ] Test passes on Base mainnet fork
- [ ] Build succeeds

## Files to Create/Modify

**New Files:**
- `test/foundry/fork/vaults/BalancerV3_ExactOut_Fork.t.sol` - Fork test

## Inventory Check

Before starting, verify:
- [ ] IDXEX-034 is complete
- [ ] Balancer V3 vault deployment exists on Base mainnet (or can be deployed in fork)
- [ ] Fork test infrastructure exists in `test/foundry/fork/`

## Completion Criteria

- [ ] Fork test passes
- [ ] Build succeeds
- [ ] No test regressions

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
