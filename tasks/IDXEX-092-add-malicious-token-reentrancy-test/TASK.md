# Task IDXEX-092: Add malicious-token reentrancy test (follow-up)

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-060
**Worktree:** `feature/IDXEX-092-add-malicious-token-reentrancy-test`
**Origin:** Code review suggestion from IDXEX-060

---

## Description

Create a mock ERC20 token that implements a `transfer()` callback (malicious token) which attempts to re-enter the vault's `exchangeIn`/`exchangeOut` during the transfer. The test should assert that the re-entrant call reverts with `IReentrancyLock.IsLocked()` and that no reentrant execution succeeds.

(Created from code review of IDXEX-060)

## Dependencies

- IDXEX-060: Add Reentrancy Guards to CamelotV2/Aerodrome (parent task)

## User Stories

### US-IDXEX-092.1: Malicious token reentrancy rejection

As a developer, I want a test using a malicious ERC20 mock to verify that re-entrant calls are rejected by the reentrancy lock so that we have end-to-end regression coverage for this attack vector.

**Acceptance Criteria:**
- [ ] Implement a `MaliciousToken` mock with a `transfer()` hook that attempts to call back into `exchangeIn`/`exchangeOut`.
- [ ] Add tests asserting the re-entrant call reverts with `IReentrancyLock.IsLocked()` for Aerodrome and CamelotV2 targets.
- [ ] Tests pass locally (`forge test`) and in CI.

## Files to Create/Modify

**Modified/Added Files:**
- `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchange_ReentrancyGuard.t.sol` (add malicious token harness)
- `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_ReentrancyGuard.t.sol` (add malicious token harness)
- `test/mocks/MaliciousToken.sol` (new malicious token mock)

## Inventory Check

Before starting, verify:
- [ ] IDXEX-060 is complete and merged
- [ ] Test harness can deploy malicious token in test environment

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`
