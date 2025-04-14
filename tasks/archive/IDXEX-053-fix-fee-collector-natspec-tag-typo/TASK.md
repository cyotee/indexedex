# Task IDXEX-053: Fix FeeCollectorManager NatSpec Tag Typo

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Priority:** LOW
**Dependencies:** IDXEX-031 ✓
**Worktree:** `feature/fix-fee-collector-natspec-tag-typo`
**Origin:** Code review suggestion from IDXEX-031

---

## Description

The AsciiDoc tag `// tag::syncReservess(address[])[]` has a double 's' ("Reservess") in both `IFeeCollectorManager.sol` (line 26) and `FeeCollectorManagerTarget.sol` (line 33). The corresponding end tags use single 's' (`// end::syncReserves(address[])[]`), creating mismatched tag pairs. This should be fixed for documentation tooling consistency.

(Created from code review of IDXEX-031)

## User Stories

### US-IDXEX-053.1: Fix AsciiDoc Tag Typo

As a documentation toolchain consumer, I want AsciiDoc tag pairs to match so that code snippet extraction works correctly.

**Acceptance Criteria:**
- [ ] `IFeeCollectorManager.sol:26` tag reads `syncReserves` (single 's')
- [ ] `FeeCollectorManagerTarget.sol:33` tag reads `syncReserves` (single 's')
- [ ] Start and end tags match in both files
- [ ] Build succeeds
- [ ] No test regressions

## Files to Create/Modify

**Modified Files:**
- `contracts/fee/collector/IFeeCollectorManager.sol` - Fix tag typo on line 26
- `contracts/fee/collector/FeeCollectorManagerTarget.sol` - Fix tag typo on line 33

## Inventory Check

Before starting, verify:
- [ ] Locate the `// tag::syncReservess` lines in both files
- [ ] Confirm end tags use single 's'

## Completion Criteria

- [ ] Both tag typos fixed
- [ ] Build succeeds
- [ ] No test regressions

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
