# Task IDXEX-088: Convert Fuzz Test vm.assume Range Constraints to bound()

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-086 (archived, complete)
**Worktree:** `feature/IDXEX-088-convert-fuzz-assume-to-bound`
**Origin:** Code review suggestion from IDXEX-086

---

## Description

Audit all fuzz tests in the codebase for `vm.assume` calls that constrain inputs to ranges, and convert them to `bound()` where appropriate. `bound()` remaps arbitrary inputs into the valid domain (no rejected runs), while `vm.assume` discards non-matching inputs (wastes fuzzer budget). Sentinel-value checks (e.g., `vm.assume(x != 0)`) should remain as `vm.assume` since they reject only a single value.

(Created from code review of IDXEX-086)

## Dependencies

- IDXEX-086: Fix BondTermsFallback Fuzz Test Input Constraints (parent task, complete)

## User Stories

### US-IDXEX-088.1: Audit and Convert vm.assume Range Constraints

As a developer, I want fuzz tests to use `bound()` for range constraints so that fuzzer runs are not wasted on rejected inputs, improving test efficiency.

**Acceptance Criteria:**
- [ ] All fuzz test files under `test/foundry/` are audited for `vm.assume` usage
- [ ] `vm.assume` calls that constrain to a range (e.g., `vm.assume(x <= MAX)`, `vm.assume(x >= MIN && x <= MAX)`) are converted to `bound(x, MIN, MAX)`
- [ ] `vm.assume` calls that check sentinel values (e.g., `vm.assume(x != 0)`, `vm.assume(x > 0)` where 0 is a sentinel) are left as-is with a comment explaining why
- [ ] All fuzz tests pass with 256+ runs after conversion
- [ ] No other tests are broken
- [ ] Build succeeds

## Technical Details

The pattern to look for:
```solidity
// BEFORE (wastes runs):
vm.assume(x <= 1e18);
vm.assume(y >= 100 && y <= 10000);

// AFTER (remaps into range):
x = bound(x, 0, 1e18);
y = bound(y, 100, 10000);
```

Keep as `vm.assume`:
```solidity
// Sentinel value — only 1 invalid value, negligible rejection rate
vm.assume(minLock > 0);
```

## Files to Create/Modify

**Modified Files:**
- All fuzz test files under `test/foundry/spec/` and `test/foundry/fork/` that use `vm.assume` for range constraints

## Inventory Check

Before starting, verify:
- [ ] Identify all fuzz test files with `vm.assume` calls
- [ ] Categorize each `vm.assume` as range-constraint vs sentinel-check
- [ ] IDXEX-086 changes are already on main (bound() pattern established)

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] `forge test` passes (full suite)
- [ ] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`
