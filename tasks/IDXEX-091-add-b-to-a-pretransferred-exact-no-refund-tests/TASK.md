# Task IDXEX-091: Add B->A direction for pretransferred exact no-refund tests

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-059
**Worktree:** `feature/IDXEX-091-add-b-to-a-pretransferred-exact-no-refund-tests`
**Origin:** Code review suggestion from IDXEX-059

---

## Description

Add tests covering the B->A direction for `_test_pretransferredExactNoRefund` to complete the test matrix (balanced/unbalanced pools). The existing tests only exercise A->B; adding B->A improves coverage and guards against reserve-sorting related regressions.

(Created from code review of IDXEX-059)

## Dependencies

- IDXEX-059: Fix Aerodrome Exact-Out Swap Semantics (parent task)

## User Stories

### US-IDXEX-091.1: Add symmetric tests

As a developer, I want B->A direction tests for pretransferred exact no-refund so that the exchange-out behavior is validated for both token ordering permutations.

**Acceptance Criteria:**
- [ ] Add B->A tests for balanced and unbalanced pools to `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchangeOut_Swap.t.sol`
- [ ] Tests assert no refund occurs and no revert when pretransferred exact amount is provided
- [ ] Tests pass locally (`forge test`) and CI

## Files to Create/Modify

**Modified Files:**
- test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchangeOut_Swap.t.sol

## Inventory Check

Before starting, verify:
- [ ] IDXEX-059 is complete (parent changes merged)
- [ ] Affected test file exists and is importable

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`
