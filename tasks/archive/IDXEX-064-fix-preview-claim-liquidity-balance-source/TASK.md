# IDXEX-064: Fix previewClaimLiquidity Balance Source

**Status:** Ready
**Priority:** Medium
**Created:** 2026-02-08
**Dependency:** IDXEX-051 ✓

## Summary

Align `previewClaimLiquidity()` with execution by using raw balances (not scaled18). This reduces UX surprise and improves minAmountOut correctness for claimLiquidity previews.

## Problem

`previewClaimLiquidity()` currently reads scaled/rated balances (scaled18) when simulating the effect of vault share redemptions on the reserve pool. Execution uses raw balances, so previews can over/underestimate outputs, causing incorrect `minAmountOut` guidance and poor UX.

## Goal

- Use `getPoolTokenInfo().balancesRaw` (or equivalent) when simulating Balancer V3 pool state changes for `claimLiquidity` previews.
- Ensure preview arithmetic uses raw balances consistently so preview ≤ execution semantics hold.

## Acceptance Criteria

- [ ] `previewClaimLiquidity()` uses raw balances for pool math where appropriate
- [ ] Tests covering claimLiquidity preview vs execution pass (no regressions)
- [ ] No new magic numbers introduced; logic follows existing `getPoolTokenInfo()` patterns

## Files / Areas to Inspect

- `contracts/registries/vault/*` (preview helpers)
- `contracts/vaults/protocol/ProtocolDETF*.sol` (claimLiquidity flow)
- Any Balancer V3 helpers using `IVaultExplorer.getPoolTokenInfo`

## Notes

Follow the pattern used in `SeigniorageDETFUnderwritingTarget.sol:201` for retrieving `balancesRaw`.
