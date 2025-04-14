# Task IDXEX-078: Add Fuzz Harness Drift Detection

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-10
**Dependencies:** IDXEX-046
**Worktree:** `feature/IDXEX-078-add-fuzz-harness-drift-detection`

---

## Description

Add a drift-detection helper to the fuzz harness that detects when mutated
inputs or simulated state cause inconsistent invariants across runs. This
improves test reliability and surfaces flaky behavior early.

## Dependencies

- IDXEX-046: Fuzz harness improvements (must be available)

## User Stories

### US-IDXEX-078.1: Detect invariant drift

As a test maintainer I want a harness-level detector that fails tests when
invariant outcomes diverge across nearby seeds or small perturbations.

**Acceptance Criteria:**
- [ ] A small library or handler that records invariant outputs and compares
  them across multiple runs
- [ ] Integrate drift detection into at least one existing fuzz test
- [ ] Tests updated and passing; detector optionally disabled by default

## Technical Details

- Implement a handler that runs invariants multiple times with small perturbing
  mutations and records results in a compact summary. If results diverge above
  a configurable threshold, the harness should fail with a clear message.
- Place the helper under `contracts/test/handlers/` or `test/helpers/` as
  appropriate.

## Files to Create/Modify

**New Files:**
- `contracts/test/handlers/FuzzDriftDetector.sol`

**Modified Files:**
- Integrate into an example fuzz test under `test/foundry/spec/`

## Inventory Check

- [ ] IDXEX-046 available and compiled

## Completion Criteria

- [ ] Drift detector added and integrated into one fuzz test
- [ ] Tests updated and passing
- [ ] Build succeeds
 - [x] Detector contract added at `contracts/test/handlers/FuzzDriftDetector.sol`

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
