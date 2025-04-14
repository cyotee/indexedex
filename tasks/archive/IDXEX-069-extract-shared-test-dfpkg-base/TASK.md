# Task IDXEX-069: Extract Shared Test DFPkg Base

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-10
**Dependencies:** IDXEX-037
**Worktree:** `feature/IDXEX-069-extract-shared-test-dfpkg-base`

---

## Description

Extract a shared test Diamond Factory Package (DFPkg) base used across multiple
test suites. Many tests duplicate package setup for standard ERC20/DFPkg fixtures;
this task centralizes common initialization and helper functions into a reusable
TestDFPkg base to reduce duplication and make tests easier to maintain.

## Dependencies

- IDXEX-037: Test infra improvements (must be available)

## User Stories

### US-IDXEX-069.1: Reuseable test DFPkg base

As a test author I want a shared test DFPkg base so new tests can quickly
instantiate packages with consistent initialization.

**Acceptance Criteria:**
- [ ] `contracts/test/dfpkg/TestDFPkgBase.sol` or similar exists
- [ ] Existing tests updated to import and use the shared base (at least one example)
- [ ] No behavioral changes in tests — just refactor

## Technical Details

- Create a `TestDFPkgBase` contract under `contracts/test/dfpkg/` which exposes
  helper functions to deploy facets/packages via the Create3Factory and
  configure common init args.
- Update one or two test specs to use the new base as a proof-of-concept.
- Ensure NatSpec or include-tags are present where necessary for docs.

## Files to Create/Modify

**New Files:**
- `contracts/test/dfpkg/TestDFPkgBase.sol`
- `contracts/test/dfpkg/README.md` (short usage)

**Modified Files:**
- Update example tests in `test/foundry/spec/...` to use the new base

**Tests:**
- Add/modify `test/foundry/spec/...` to demonstrate usage

## Inventory Check

- [ ] IDXEX-037 available and compiled

## Completion Criteria

- [ ] Test base added and compiles
- [ ] At least one test updated to use it
- [ ] All tests pass

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
