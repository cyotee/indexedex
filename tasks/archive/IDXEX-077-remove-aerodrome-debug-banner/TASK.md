# Task IDXEX-077: Remove Debug Banner from AerodromeStandardExchangeCommon

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-043
**Worktree:** `feature/IDXEX-077-remove-aerodrome-debug-banner`
**Origin:** Code review suggestion from IDXEX-043

---

## Description

A "REFACTORED CODE IS ABOVE" debug banner comment was left in `AerodromeStandardExchangeCommon.sol` (lines 140-144) during the IDXEX-043 proportional math refactoring. This is development scaffolding that should be removed.

(Created from code review of IDXEX-043)

## Dependencies

- IDXEX-043: Refactor Aerodrome Proportional Math (parent task) - Complete

## User Stories

### US-IDXEX-077.1: Remove debug banner

As a developer, I want leftover development scaffolding removed so that the codebase stays clean and professional.

**Acceptance Criteria:**
- [ ] Remove the 5-line "REFACTORED CODE IS ABOVE" banner block from `AerodromeStandardExchangeCommon.sol`
- [ ] No behavioral changes introduced
- [ ] Tests pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol`

## Inventory Check

Before starting, verify:
- [ ] IDXEX-043 is complete (confirmed)
- [ ] `AerodromeStandardExchangeCommon.sol` exists and contains the banner

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
