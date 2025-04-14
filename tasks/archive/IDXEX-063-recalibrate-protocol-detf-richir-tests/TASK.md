# Task IDXEX-063: Recalibrate ProtocolDETF RICH-to-RICHIR Tests

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-035 (complete)
**Worktree:** `feature/recalibrate-protocol-detf-richir-tests`
**Origin:** Code review suggestion from IDXEX-035 (Suggestion 3)

---

## Description

Three ProtocolDETF spec tests fail after the IDXEX-035 fix because their slippage/preview expectations were calibrated against the buggy `_secureTokenTransfer` behavior (which returned `balanceOf(this)` instead of the transfer delta).

The failing tests:
1. `test_exchangeOut_rich_to_richir_exact` - SlippageExceeded (99.94e18 vs 100e18)
2. `test_exchangeIn_rich_to_richir_preview` - Preview vs actual delta 1.08%
3. `test_route_rich_to_richir_single_call` - Same preview discrepancy

These tests route through an Aerodrome StandardExchange vault that inherits `BasicVaultCommon`. The old code inflated `actualIn` if the vault held residual tokens. Preview math was implicitly calibrated against this inflation. The `actualIn` has been corrected.

The fix is correct; the tests need updating to either use looser slippage tolerances or recalibrated preview expectations that match the corrected delta-based accounting.

(Created from code review of IDXEX-035)

## Dependencies

- IDXEX-035: Fix BasicVaultCommon._secureTokenTransfer Full-Balance Issue (parent task, complete)

## User Stories

### US-IDXEX-063.1: Recalibrate preview/slippage expectations

As a developer, I want the ProtocolDETF RICH-to-RICHIR tests to pass with the corrected `_secureTokenTransfer` so that the test suite is green.

**Acceptance Criteria:**
- [ ] `test_exchangeOut_rich_to_richir_exact` passes
- [ ] `test_exchangeIn_rich_to_richir_preview` passes
- [ ] `test_route_rich_to_richir_single_call` passes
- [ ] Slippage tolerances are reasonable (not excessively loose)
- [ ] No other tests regress
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- ProtocolDETF spec test files containing the RICH-to-RICHIR routes (find exact files during implementation)

## Inventory Check

Before starting, verify:
- [ ] IDXEX-035 is complete
- [ ] The 3 failing tests can be identified and reproduced
- [ ] Understand the preview math pipeline for RICH-to-RICHIR routes

## Completion Criteria

- [ ] All 3 failing tests pass
- [ ] No regressions in other tests
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
