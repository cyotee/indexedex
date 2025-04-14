# Task IDXEX-050: Document Preview Function Limitations

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Dependencies:** IDXEX-007 (completed)
**Worktree:** `feature/document-preview-limitations`
**Origin:** Code review suggestion from IDXEX-007

---

## Description

Add NatSpec documentation to `previewDeployVault` noting that `expectedLP` is an upper-bound estimate that does not account for Camelot's protocol mint fee (`_mintFee()`). The mint fee increases `totalSupply` before the depositor's liquidity is calculated, causing a slight overestimate.

This is a documentation-only change. The preview function is used for UI display purposes only, not in on-chain calculations.

(Created from code review of IDXEX-007, Suggestion 3 / Finding #1)

## Dependencies

- IDXEX-007: Review Camelot V2 DFPkg deployVault (completed - parent task)

## User Stories

### US-IDXEX-050.1: Document preview estimate limitations

As a developer integrating with the vault, I want clear NatSpec on `previewDeployVault` explaining that the LP estimate is an upper bound, so that I set correct UI expectations.

**Acceptance Criteria:**
- [ ] NatSpec `@notice` or `@dev` on `previewDeployVault` explains upper-bound behavior
- [ ] Mentions Camelot's `_mintFee()` as the source of discrepancy
- [ ] Notes this is for display/UI only
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol`

## Inventory Check

Before starting, verify:
- [ ] Locate `previewDeployVault` function in the DFPkg
- [ ] Understand existing NatSpec conventions in the codebase

## Completion Criteria

- [ ] NatSpec added to `previewDeployVault`
- [ ] Build succeeds
- [ ] No functional changes

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
