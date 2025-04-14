# Task IDXEX-067: Add Seigniorage Setter Interface

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-10
**Dependencies:** IDXEX-036
**Worktree:** `feature/IDXEX-067-add-seigniorage-setter-interface`

---

## Description

Add a new interface and minimal implementation glue to expose a seigniorage setter
ABI for existing fee/seigniorage contracts. This task provides the interface and
selector constants used by tests and other packages to call the seigniorage setter
without depending on a concrete implementation.

## Dependencies

- IDXEX-036: Seigniorage Core (must be complete and available as package)

## User Stories

### US-IDXEX-067.1: Expose seigniorage setter interface

As an integrator I want a stable interface so tests and DFPkgs can reference
the seigniorage setter selector and ABI without importing an implementation.

**Acceptance Criteria:**
- [ ] `ISeigniorageSetter.sol` exists under `contracts/interfaces/` and compiles
- [ ] Tests referencing the selector can import it from the interface

## Technical Details

- Create `contracts/interfaces/ISeigniorageSetter.sol` with the setter function
  signature and an `interfaceId` natspec tag if appropriate.
- Export a Solidity library `SeigniorageSetterSelectors.sol` with `bytes4`
  selector constants for use in tests. Alternatively place selector const in the
  interface file as `bytes4 constant` if style guide permits.

## Files to Create/Modify

**New Files:**
- `contracts/interfaces/ISeigniorageSetter.sol`
- `contracts/test/helpers/SeigniorageSetterSelectors.sol` (or similar path)

**Modified Files:**
- None expected — keep changes additive

**Tests:**
- Add a minimal unit test that imports the selector constant and asserts the
  selector equals `cast sig "setSeigniorage(uint256)"` (or the canonical
  signature used)

## Inventory Check

- [ ] IDXEX-036 package is available and compiled in the repo

## Completion Criteria

- [ ] Interface and selector library added and compiled
- [ ] Tests added and passing
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
