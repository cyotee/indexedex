# Task IDXEX-056: Migrate Lending Terms from PPM to WAD

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Priority:** MEDIUM
**Dependencies:** IDXEX-032 ✓
**Worktree:** `feature/migrate-lending-terms-ppm-to-wad`
**Origin:** Code review suggestion from IDXEX-032

---

## Description

`DEFAULT_LENDING_BASE_RATE = 1000` and related lending constants in `Indexedex_CONSTANTS.sol` are documented as `(legacy PPM scale, not yet migrated to WAD)`. When lending functionality is activated, these constants and their consumers should be migrated to WAD scale (1e18 = 100%) for consistency with the rest of the fee system.

(Created from code review of IDXEX-032, Suggestion 4)

## User Stories

### US-IDXEX-056.1: Migrate Lending Constants to WAD

As a protocol developer, I want all fee-related constants to use the same WAD scale so that there is no unit confusion when implementing lending features.

**Acceptance Criteria:**
- [ ] `DEFAULT_LENDING_BASE_RATE` converted from PPM (1000 = 0.1%) to WAD (1e15 = 0.1%)
- [ ] All other lending-related PPM constants migrated
- [ ] Consumer code updated to use WAD-scale values
- [ ] NatSpec annotations updated to reflect WAD scale
- [ ] Legacy PPM annotations removed
- [ ] Build succeeds
- [ ] No test regressions

## Files to Create/Modify

**Modified Files:**
- `contracts/constants/Indexedex_CONSTANTS.sol` - Migrate constant values
- (lending-related contracts that consume these constants, currently commented out)

## Inventory Check

Before starting, verify:
- [ ] IDXEX-032 is complete
- [ ] Identify all PPM-scale lending constants
- [ ] Identify all consumers of these constants (may be commented out)
- [ ] Determine if lending is still disabled/commented out

## Completion Criteria

- [ ] All lending constants use WAD scale
- [ ] Consumer code updated or annotated
- [ ] Build succeeds
- [ ] No test regressions

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
