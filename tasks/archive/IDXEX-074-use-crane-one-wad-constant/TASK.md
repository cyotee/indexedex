# Task IDXEX-074: Use Crane ONE_WAD Constant

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-041 (complete)
**Worktree:** `feature/use-crane-one-wad-constant`
**Origin:** Code review suggestion from IDXEX-041

---

## Description

`VaultFeeOracleRepo.sol` defines its own `ONE_WAD = 1e18` constant (line 14), and the test file `VaultFeeOracle_Bounds.t.sol` duplicates it (line 28). Crane already provides a canonical ONE_WAD constant that should be used instead of local redefinitions.

Replace the local `ONE_WAD` declarations with the Crane-provided constant import, following the project convention of treating Crane as the canonical source for shared constants.

(Created from code review of IDXEX-041, Suggestion 2)

## Dependencies

- IDXEX-041: Add Bond Terms Setter Validation (complete)

## User Stories

### US-IDXEX-074.1: Import ONE_WAD from Crane constants

As a developer, I want all code to use Crane's canonical ONE_WAD constant so that WAD-scaled values are consistent and DRY across the codebase.

**Acceptance Criteria:**
- [ ] Identify Crane's ONE_WAD constant location
- [ ] `VaultFeeOracleRepo.sol` imports ONE_WAD from Crane instead of defining its own
- [ ] `VaultFeeOracle_Bounds.t.sol` imports ONE_WAD from Crane instead of defining its own
- [ ] Search for other local ONE_WAD definitions in the IndexedEx codebase and consolidate
- [ ] All existing tests pass (no regressions)
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/oracles/fee/VaultFeeOracleRepo.sol` — Remove local ONE_WAD, import from Crane
- `test/foundry/spec/oracles/fee/VaultFeeOracle_Bounds.t.sol` — Remove local ONE_WAD, import from Crane

**Potentially Modified:**
- Any other files with local ONE_WAD definitions (search codebase)

## Inventory Check

Before starting, verify:
- [ ] IDXEX-041 is complete
- [ ] Locate Crane's ONE_WAD constant (likely in `@crane/contracts/constants/` or similar)
- [ ] Verify import path via remappings

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] No local ONE_WAD definitions remain (except Crane's canonical one)
- [ ] All tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
