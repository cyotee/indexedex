# Task IDXEX-068: Add Permit2 Revert Error Selectors

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-10
**Dependencies:** IDXEX-037
**Worktree:** `feature/IDXEX-068-add-permit2-revert-error-selectors`

---

## Description

Add selector constants and helper utilities for Permit2 revert error signatures
used across tests. This task introduces a small library or test helper exposing
the bytes4 selectors for common Permit2 revert/error signatures so tests can
assert exact revert selectors without duplicating raw values.

## Dependencies

- IDXEX-037: Permit2 Integration (must be present and compiled)

## User Stories

### US-IDXEX-068.1: Provide selector constants for Permit2 errors

As a test author I want stable selector constants so revert-path tests can
depend on named selectors instead of hard-coded values.

**Acceptance Criteria:**
- [ ] `test/helpers/Permit2ErrorSelectors.sol` (or under `contracts/test/helpers/`) exists and compiles
- [ ] Selectors included: `Permit2_NotApproved`, `Permit2_TransferFailed`, etc. (match canonical signatures)
- [ ] At least one unit test imports the selectors and asserts equality with `cast sig "ErrorName(args)"`

## Technical Details

- Create a small Solidity library or constant contract exposing `bytes4` selector
  constants for Permit2 revert/errors.
- Place the file under `contracts/test/helpers/` or `contracts/test/utils/` so it's
  available to test code only (avoid changing production ABI surface).
- Update any tests that currently hardcode selectors to import the new helper.

## Files to Create/Modify

**New Files:**
- `contracts/test/helpers/Permit2ErrorSelectors.sol`
- `test/foundry/spec/permit2/Permit2ErrorSelectors.t.sol` (unit test)

**Modified Files:**
- Replace hardcoded selector usages in tests to import and reference the helpers

## Inventory Check

- [ ] IDXEX-037 available and compiled

## Completion Criteria

- [ ] Library file added and compiles
- [ ] Tests added and passing
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
