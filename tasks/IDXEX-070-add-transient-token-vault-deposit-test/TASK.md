# Task IDXEX-070: Add Direct Transient Token During Vault Deposit Test

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-037 (complete)
**Worktree:** `feature/add-transient-token-vault-deposit-test`
**Origin:** Code review suggestion from IDXEX-037 (Suggestion 3)

---

## Description

The current transient state tests verify (a) the token can be set via harness and (b) it's zero after various operations. A test that reads the transient token *during* an actual vault deposit/withdrawal (using a callback hook) would strengthen the "set during swap" criterion.

The current harness-based test (`test_transientState_setDuringHarnessCall`) tests the set/read mechanics but not the actual router code path that sets the transient token. A more complex harness that hooks into the vault callback could read the transient token mid-flight and assert it equals the expected strategy vault address.

(Created from code review of IDXEX-037)

## Dependencies

- IDXEX-037: Add Balancer V3 Router Integration Tests (parent task, complete)

## User Stories

### US-IDXEX-070.1: Add in-flight transient token verification test

As a test maintainer, I want to verify that the router sets `currentStandardExchangeToken` to the correct strategy vault address during actual vault deposit/withdrawal operations, not just via the harness.

**Acceptance Criteria:**
- [ ] New test reads transient `currentStandardExchangeToken` during an actual vault deposit callback
- [ ] Assertion verifies the transient token equals the expected strategy vault address
- [ ] Test uses a callback hook (e.g., custom harness facet that reads transient state from within vault.unlock())
- [ ] Existing transient state tests still pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `test/foundry/spec/protocols/balancerV3/BalancerV3StandardExchangeRouter_TransientState.t.sol`

## Inventory Check

Before starting, verify:
- [ ] IDXEX-037 is complete
- [ ] Understand how the router sets transient storage during vault.unlock() callback
- [ ] Determine feasibility of reading transient state from within the callback context

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
