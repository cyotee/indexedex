# Task IDXEX-046: Add Fuzz Tests for Aerodrome Proportional Deposit Math

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Type:** Testing
**Dependencies:** IDXEX-006 ✓
**Worktree:** `feature/fuzz-aerodrome-proportional-math`
**Origin:** Deferred debt D-02 from IDXEX-006 review

---

## Description

Current Aerodrome DFPkg tests use fixed token amounts. Add fuzz/property-based tests for the proportional deposit math to catch rounding edge cases before mainnet deployment.

The proportional calculation in `_depositLiquidity` and `previewDeployVault` computes:
```
optimalB = (amountA * reserveB) / reserveA
```
If `optimalB <= amountB`, use (amountA, optimalB). Otherwise flip and compute optimalA.

Edge cases to fuzz:
- Very small amounts (1 wei, 2 wei)
- Very large amounts (near uint256 max / 2)
- Highly asymmetric reserves (1 wei vs 1e18)
- Equal reserves with different input ratios
- Zero amounts (should handle gracefully or revert)

(Created from IDXEX-006 review, deferred debt D-02)

## Files to Create/Modify

**New Files:**
- `test/foundry/spec/protocols/dexes/aerodrome/v1/AerodromeStandardExchange_Fuzz.t.sol`

**Reference Files:**
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol` (lines 334-354, 256-270)
- `test/foundry/spec/protocols/dexes/aerodrome/v1/AerodromeStandardExchange_DeployWithPool.t.sol` (existing test base)

## Acceptance Criteria

- [ ] Fuzz test covers proportional deposit math with randomized token amounts and reserves
- [ ] Property: actual amounts used never exceed user-provided max amounts
- [ ] Property: preview output matches actual deposit amounts
- [ ] Property: no overflow/underflow for reasonable ranges
- [ ] Tests pass with default fuzz runs (256+)
- [ ] Build succeeds

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
