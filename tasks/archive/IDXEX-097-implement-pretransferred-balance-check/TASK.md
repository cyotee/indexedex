# IDXEX-097: Implement Pretransferred Balance Check in Commons

**Status:** Ready
**Priority:** Medium
**Created:** 2026-02-08
**Dependencies:** IDXEX-096
**Worktree:** feature/IDXEX-097-implement-pretransferred-balance-check

## Summary

Implement a defensive precondition in the `_secureTokenTransfer` early-return path when `pretransferred == true` so callers cannot rely on missing balance checks. This change should be minimal and applied across the common vault commons (`BasicVaultCommon`, `ProtocolDETFCommon`, `SeigniorageDETFCommon`) unless the audit recommends narrower scope.

## Description

Add a require/assert that verifies the token balance is sufficient when `pretransferred` is true, or document and justify why existing call sites already perform necessary checks. Provide tests to exercise insufficient-balance scenarios.

## Acceptance Criteria

- [ ] Defensive balance check implemented across commons or targeted places as decided
- [ ] Unit tests added that assert pretransferred with insufficient balance reverts
- [ ] No behavior regressions in existing tests

## Files to Modify

- `contracts/vaults/basic/BasicVaultCommon.sol`
- `contracts/vaults/protocol/ProtocolDETFCommon.sol`
- `contracts/vaults/seigniorage/SeigniorageDETFCommon.sol`

## Completion Criteria

- [ ] Tests pass
- [ ] PR-ready patch in repo

When complete, output: `<promise>PHASE_DONE</promise>`
