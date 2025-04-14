# Task IDXEX-044: Fix Aerodrome DFPkg LP Deposit to Use pretransferred=true

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Type:** Bug Fix
**Dependencies:** IDXEX-006 ✓
**Worktree:** `feature/fix-aerodrome-pretransferred-flag`
**Origin:** Code review finding F-01 from IDXEX-006

---

## Description

The Aerodrome V1 DFPkg `deployVault` deposits LP tokens into the vault using `pretransferred=false` with a `safeApprove` + `exchangeIn` pattern. This works functionally but deviates from the spec (which calls for `pretransferred=true`) and costs ~20k extra gas per deploy due to the approve + transferFrom overhead.

The fix is to switch to `safeTransfer` + `pretransferred=true`, matching the spec and saving gas.

(Created from code review of IDXEX-006, finding F-01)

## Current Code (DFPkg lines ~198-207)

```solidity
lpToken.safeApprove(vault, lpTokensMinted);
IStandardExchangeIn(vault).exchangeIn(
    lpToken, lpTokensMinted, IERC20(vault), 0, recipient, false, block.timestamp + 1
);
```

## Target Code

```solidity
lpToken.safeTransfer(vault, lpTokensMinted);
IStandardExchangeIn(vault).exchangeIn(
    lpToken, lpTokensMinted, IERC20(vault), 0, recipient, true, block.timestamp + 1
);
```

## Files to Modify

- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol` (~line 198-207)

## Acceptance Criteria

- [ ] LP deposit uses `safeTransfer` + `pretransferred=true` instead of `safeApprove` + `pretransferred=false`
- [ ] No residual approval left after deposit
- [ ] All existing tests pass (AerodromeStandardExchange_DeployWithPool.t.sol)
- [ ] Build succeeds

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
