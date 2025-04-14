# Task IDXEX-048: Add Missing Camelot V2 DFPkg Test Cases

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Dependencies:** IDXEX-007 (completed)
**Worktree:** `feature/add-camelot-dfpkg-test-cases`
**Origin:** Code review suggestion from IDXEX-007

---

## Description

Add missing test coverage for the Camelot V2 DFPkg `deployVault` flow. The IDXEX-007 code review identified four untested paths that should be exercised before production readiness.

(Created from code review of IDXEX-007, Suggestion 1 / Findings #2, #3, #4, #7)

## Dependencies

- IDXEX-007: Review Camelot V2 DFPkg deployVault (completed - parent task)

## User Stories

### US-IDXEX-048.1: Test InsufficientLiquidity revert

As a developer, I want a test that verifies `deployVault` reverts with `InsufficientLiquidity` when dust amounts are provided against large-reserve pairs, so that the edge case is covered.

**Acceptance Criteria:**
- [ ] Test calls `deployVault` with near-zero deposit amounts on a pair with large reserves
- [ ] Asserts revert with `InsufficientLiquidity` error
- [ ] Exercises the revert at `CamelotV2StandardExchangeDFPkg.sol:215`

### US-IDXEX-048.2: Test PoolMustNotBeStable revert

As a developer, I want a test that verifies `processArgs()` rejects stable Camelot pairs, so that the stable pool guard is covered.

**Acceptance Criteria:**
- [ ] Test creates or mocks a Camelot stable pair (`stableSwap() == true`)
- [ ] Asserts revert with `PoolMustNotBeStable` error
- [ ] Exercises the check at `CamelotV2StandardExchangeDFPkg.sol:564`

### US-IDXEX-048.3: Test token ordering flip

As a developer, I want a test where `address(tokenB) < address(tokenA)` to exercise the reserve sorting logic, so that reversed token ordering is covered.

**Acceptance Criteria:**
- [ ] Test deploys vault with tokens where address(tokenB) < address(tokenA)
- [ ] Verifies proportional amounts calculated correctly despite reversed ordering
- [ ] Exercises sorting logic in `_calculateProportionalAmounts` and `_transferAndMintLP`

### US-IDXEX-048.4: Test residual balance assertion

As a developer, I want a test that asserts the DFPkg contract holds zero tokens after `deployVault`, so that no funds are stranded.

**Acceptance Criteria:**
- [ ] After successful `deployVault` with deposit, assert DFPkg balance of tokenA == 0
- [ ] Assert DFPkg balance of tokenB == 0
- [ ] Assert DFPkg balance of LP token == 0

## Files to Create/Modify

**Modified Files:**
- `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_DeployWithPool.t.sol`

## Inventory Check

Before starting, verify:
- [ ] IDXEX-007 is complete (confirmed)
- [ ] Test file exists: `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_DeployWithPool.t.sol`
- [ ] Understand existing mock setup and test patterns

## Completion Criteria

- [ ] All four test cases implemented
- [ ] Tests pass with `forge test --match-contract CamelotV2StandardExchange_DeployWithPool`
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
