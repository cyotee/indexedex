# Task IDXEX-065: Add Operator Fee Oracle Authorization Tests

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-036 (complete)
**Worktree:** `feature/add-operator-fee-oracle-auth-tests`
**Origin:** Code review suggestion from IDXEX-036 (Suggestion 1)

---

## Description

The IDXEX-036 auth tests skip operator testing because `OperableFacet` is not wired into `IndexedexManagerDFPkg`. When OperableFacet is added to the DFPkg, these tests should be enabled to verify:

1. Operator can call all 9 `onlyOwnerOrOperator` setters
2. Operator CANNOT call `setFeeTo` (which is `onlyOwner` only)

The test infrastructure is already in place — just need to add operator setup in `setUp()` and duplicate the `_succeedsForOwner` pattern as `_succeedsForOperator`.

**Blocked on:** OperableFacet being wired into IndexedexManagerDFPkg.

(Created from code review of IDXEX-036)

## Dependencies

- IDXEX-036: Add Fee Oracle Authorization and Bounds Tests (parent task, complete)

## User Stories

### US-IDXEX-065.1: Enable operator auth tests

As a developer, I want to verify that operator accounts can call fee oracle setters so that the access control model is fully tested.

**Acceptance Criteria:**
- [ ] OperableFacet is wired into test DFPkg setup
- [ ] 9 `_succeedsForOperator` tests pass for all `onlyOwnerOrOperator` setters
- [ ] `setFeeTo` reverts for operator (only owner can call it)
- [ ] All existing auth tests still pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `test/foundry/spec/oracles/fee/VaultFeeOracleManagerFacet_Auth.t.sol`

## Inventory Check

Before starting, verify:
- [ ] IDXEX-036 is complete
- [ ] OperableFacet is available and can be integrated into the test DFPkg
- [ ] Auth test file exists with the `_succeedsForOwner` pattern

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
