# Task IDXEX-061: Add Pretransferred Balance Validation (Defense-in-Depth)

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-035 (complete)
**Worktree:** `feature/add-pretransferred-balance-validation`
**Origin:** Code review suggestion from IDXEX-035 (Suggestion 1)

---

## Description

Add an explicit balance validation in the `pretransferred == true` early-return path of `_secureTokenTransfer` across all three `Common` implementations. Currently, the pretransferred path trusts the caller blindly, relying on downstream operations (DEX swaps, LP deposits, ERC4626 balance-delta checks) to fail if the claim is false.

A defense-in-depth check would catch the issue earlier with a clearer revert message. However, a naive `require(balanceOf >= amount)` check won't work if the vault already holds dust tokens. A proper implementation must use the same `balBefore` delta approach or verify that `balanceOf(this) >= amountTokenToDeposit` at the specific call time.

**Important consideration:** The review notes that since dust could make a naive balance check pass even without a transfer, the implementation needs careful thought. The check should verify that `balanceOf(this) >= amountTokenToDeposit` as a minimum precondition (the vault must hold at least the claimed amount), even though this doesn't prove the tokens were actually transferred.

(Created from code review of IDXEX-035)

## Dependencies

- IDXEX-035: Fix BasicVaultCommon._secureTokenTransfer Full-Balance Issue (parent task, complete)

## User Stories

### US-IDXEX-061.1: Add balance precondition check to pretransferred path

As a developer, I want `_secureTokenTransfer` to validate that the vault actually holds at least `amountTokenToDeposit` when `pretransferred == true` so that failures occur earlier with clear revert messages.

**Acceptance Criteria:**
- [ ] `BasicVaultCommon._secureTokenTransfer` adds a `require(tokenIn.balanceOf(address(this)) >= amountTokenToDeposit)` check in the pretransferred path
- [ ] `ProtocolDETFCommon._secureTokenTransfer` has the same check
- [ ] `SeigniorageDETFCommon._secureTokenTransfer` has the same check
- [ ] Test: pretransferred with insufficient balance reverts
- [ ] All existing tests pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/vaults/basic/BasicVaultCommon.sol`
- `contracts/vaults/protocol/ProtocolDETFCommon.sol`
- `contracts/vaults/seigniorage/SeigniorageDETFCommon.sol`

**Test Files:**
- `test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol` (add revert test)

## Inventory Check

Before starting, verify:
- [ ] IDXEX-035 is complete
- [ ] All three affected files exist and have the pretransferred early-return pattern

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
