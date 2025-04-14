# IDXEX-098: Add Tests for Permit2 / Pretransferred Paths

**Status:** Ready
**Priority:** Medium
**Created:** 2026-02-08
**Dependencies:** IDXEX-096
**Worktree:** feature/IDXEX-098-add-permit2-pretransferred-tests

## Summary

Add unit and integration tests that exercise the `pretransferred` code paths (including Permit2 transfers) to ensure behavior is explicit and covered. Tests should include insufficient-balance cases and typical success paths. These test MUST use a BetterPermit2 instance for local tests, and the Permit2 address for mainnet in chain state fork tests.

## Acceptance Criteria

- [ ] Tests added under `test/foundry/spec/vaults/` and `test/foundry/spec/oracles/fee/` as appropriate
- [ ] CI-local runs succeed (`forge test --match-path ...`)
- [ ] Tests document required setup (Permit2 approvals, pretransferred flag usage)

## Files to Add/Modify

- `test/foundry/spec/vaults/basic/BasicVaultCommon_Permit2.t.sol`
- Additional focused tests for Seigniorage/Protocol DETF claim paths

When complete, output: `<promise>PHASE_DONE</promise>`
