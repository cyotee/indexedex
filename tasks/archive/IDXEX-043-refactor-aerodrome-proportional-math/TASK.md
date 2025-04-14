# Task IDXEX-043: Refactor Aerodrome Proportional Math

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Dependencies:** IDXEX-014
**Worktree:** `feature/refactor-aerodrome-proportional-math`
**Origin:** Code review suggestion from IDXEX-014

---

## Description

`AerodromeStandardExchangeDFPkg.sol`, `AerodromeStandardExchangeCommon.sol`, and `AerodromeCompoundService.sol` have proportional amount calculations in multiple places. The same extraction pattern from IDXEX-014 should be applied.

**Important:** The Aerodrome case is more complex than Uniswap V2 due to the distinction between volatile and stable pools. Stable pools use a different invariant curve (`x^3*y + y^3*x = k`) which affects optimal deposit ratios. The proportional math extraction may need to account for this difference, or it may only apply to the volatile pool path. Evaluate carefully before extracting.

(Created from code review of IDXEX-014)

## Dependencies

- IDXEX-014: Refactor Shared Proportional Math (parent task) - Complete

## User Stories

### US-IDXEX-043.1: Extract shared proportional math in Aerodrome

As a developer, I want the Aerodrome DFPkg to use shared proportional calculation functions so that the math in preview and execution paths cannot drift out of sync.

**Acceptance Criteria:**
- [ ] Identify all duplicated proportional math across the three Aerodrome files
- [ ] Extract shared function(s) appropriate for volatile pools
- [ ] Evaluate whether stable pool math can share the same extraction (may differ)
- [ ] `previewDeployVault()` uses the shared function(s)
- [ ] `_calculateProportionalAmounts()` uses the shared function(s)
- [ ] Preview results still match execution results exactly
- [ ] Tests pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol`
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol`
- `contracts/protocols/dexes/aerodrome/v1/AerodromeCompoundService.sol`

## Inventory Check

Before starting, verify:
- [ ] IDXEX-014 is complete (reference implementation exists)
- [ ] All three Aerodrome files exist
- [ ] Reference: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol` for pattern
- [ ] Understand volatile vs stable pool differences before extracting

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
