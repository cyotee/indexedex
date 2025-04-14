# Task IDXEX-076: Use Crane ConstProdUtils for Proportional Deposit

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-10
**Dependencies:** IDXEX-042
**Worktree:** `feature/IDXEX-076-use-crane-constprodutils-for-proportional-deposit`

---

## Description

Replace custom proportional deposit math with Crane's `ConstProdUtils` utilities
to standardize AMM math and reduce duplication. The change should be limited to
using the library functions for proportional deposit calculations without
changing business behavior.

## Dependencies

- IDXEX-042: ConstProdUtils integration (must be available)

## User Stories

### US-IDXEX-076.1: Use canonical constant-product math

As a developer I want tests and implementations to use `ConstProdUtils` so the
project shares a single authoritative implementation of proportional deposit
math.

**Acceptance Criteria:**
- [ ] Existing proportional deposit implementations updated to call `ConstProdUtils`
- [ ] No behavior changes in tests (only refactor)
- [ ] Build succeeds and tests pass

## Technical Details

- Replace manual calculations in `vaults/` or `protocols/` services with
  `ConstProdUtils.purchaseQuote()` or the appropriate helper. Import from
  `@crane/utils/math/ConstProdUtils.sol` per remapping.
- Add small adapter functions where necessary to keep stack depth low.

## Files to Create/Modify

**Modified Files:**
- Files in `contracts/` that implement proportional deposit math (search for
  `purchaseQuote`, `proportional`, `deposit` calculations)

**Tests:**
- Ensure tests still pass; add tests if edge-cases were uncovered

## Inventory Check

- [ ] IDXEX-042 available and compiled

## Completion Criteria

- [ ] All proportional deposit usages updated
- [ ] Tests updated (if needed) and passing
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
