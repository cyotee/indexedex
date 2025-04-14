# Task IDXEX-090: Remove Dead PPM Bond Constants

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-11
**Dependencies:** IDXEX-056
**Worktree:** `feature/IDXEX-090-remove-dead-ppm-bond-constants`

---

## Description

Remove unused or dead PPM (parts-per-million) bond-related constants from the codebase. These constants are vestigial and may cause confusion or incorrect assumptions in tests and runtime code paths. This task ensures the constants are removed and any dependent code is updated or guarded appropriately.

## Dependencies

- IDXEX-056: (required)

## User Stories

### US-IDXEX-090.1: Remove dead constants

As a maintainer, I want the codebase to not include unused PPM bond constants so that the code is clearer and less error-prone.

**Acceptance Criteria:**
- [ ] Dead PPM bond constants are removed from contract/source files
- [ ] Tests referencing these constants are updated or removed
- [ ] No new compiler warnings introduced

## Technical Details

- Search for PPM-related constants (e.g., names containing `PPM`, `BOND`, `ppm`) and remove or replace them with the canonical WAD representations where appropriate.
- Update any tests or docs that reference the removed constants.
- Run `forge test` for impacted packages/paths.

## Files to Create/Modify

**Modified Files:**
- contracts/... (where constants are defined)
- test/... (where tests reference constants)

## Inventory Check

- [ ] Verify IDXEX-056 changes are available if required

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass locally and in CI
- [ ] TASK.md and PROGRESS.md are up to date

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`

(End of file)
