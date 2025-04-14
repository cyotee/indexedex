# Task IDXEX-093: Add CamelotV2 exchangeOut test when blocker is resolved

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-060
**Worktree:** `feature/IDXEX-093-add-camelotv2-exchangeout-test`
**Origin:** Code review suggestion from IDXEX-060

---

## Description

Once the pre-existing `ERC4626Repo._reserveAsset()` OutTarget issue is fixed, add `test_exchangeOut_isLockedDuringExecution` to the CamelotV2 reentrancy guard test file to assert the `lock` modifier prevents re-entrancy during `exchangeOut`.

(Created from code review of IDXEX-060)

## Dependencies

- IDXEX-060: Add Reentrancy Guards to CamelotV2/Aerodrome (parent task)

## User Stories

### US-IDXEX-093.1: Add CamelotV2 exchangeOut lock test

As a developer, I want a test that asserts `exchangeOut` in CamelotV2 is locked during execution so that we have coverage once the pre-existing OutTarget blocker is resolved.

**Acceptance Criteria:**
- [ ] Add `test_exchangeOut_isLockedDuringExecution` to `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_ReentrancyGuard.t.sol`
- [ ] Test is gated or conditioned on the OutTarget fix and documented
- [ ] Tests pass when the blocker is resolved

## Files to Modify

- `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_ReentrancyGuard.t.sol`

## Inventory Check

Before starting, verify:
- [ ] The OutTarget `ERC4626Repo._reserveAsset()` behavior is corrected
- [ ] Test harness can deploy necessary mocks

## Completion Criteria

- [ ] Acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`
