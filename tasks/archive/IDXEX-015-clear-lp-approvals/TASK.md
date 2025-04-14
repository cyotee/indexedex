# Task IDXEX-015: Clear Temporary LP Token Approvals

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-13
**Type:** Hygiene
**Dependencies:** IDXEX-008
**Worktree:** `feature/clear-lp-approvals`
**Origin:** Deferred debt D2 from IDXEX-008 code review

---

## Description

Clear temporary LP token approvals after use in `_depositLPToVault()` for improved code hygiene.

Currently, after `exchangeIn()` is called, the LP token approval to the vault is left set rather than being cleared to zero. While not a security risk (the LP token is standard and allowance is bounded), clearing approvals after use is better hygiene practice.

(Created from code review deferred debt of IDXEX-008)

## User Stories

### US-IDXEX-015.1: Clear Approvals After Use

As a developer, I want LP token approvals cleared after vault deposit so that no stale allowances remain.

**Acceptance Criteria:**
- [ ] After `exchangeIn()` call, approval is reset to 0
- [ ] Use `safeApprove(vault, 0)` or equivalent
- [ ] No functional change to deposit flow
- [ ] Tests pass
- [ ] Build succeeds

## Files to Modify

**Primary:**
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol` (specifically `_depositLPToVault()`)

**Tests:**
- May need to verify approval state in existing tests

## Implementation Notes

- This is a low-priority hygiene improvement
- Consider applying the same pattern to other DFPkgs (Camelot, Aerodrome) if they have similar patterns
- Be careful with `safeApprove` - some implementations revert if current allowance != 0

## Completion Criteria

- [ ] LP approval cleared after vault deposit
- [ ] All tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
