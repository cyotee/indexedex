# Task IDXEX-095: Add read-back assertion to seigniorage fuzz test

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-066
**Worktree:** feature/IDXEX-095-add-readback-assertion-seigniorage-fuzz-test

---

## Description

Add an `assertEq` to `testFuzz_setDefaultSeigniorageIncentivePercentage_wadBoundStored` in `test/foundry/spec/oracles/fee/VaultFeeOracle_Bounds.t.sol` so the test reads back the stored value after calling `setDefaultSeigniorageIncentivePercentage(pct)` and verifies it equals the input (or the bounded value). This aligns the seigniorage fuzz test with the usage-fee and dex-fee fuzz tests.

## Acceptance Criteria

- [ ] Test `testFuzz_setDefaultSeigniorageIncentivePercentage_wadBoundStored` includes an `assertEq` verifying the stored value equals the expected value
- [ ] All fuzz tests in `VaultFeeOracle_Bounds.t.sol` pass

## Files to modify

- `test/foundry/spec/oracles/fee/VaultFeeOracle_Bounds.t.sol` (around line ~386)

## Notes

- Two-line, low-effort test improvement. No production code changes required.

---

When complete, output: <promise>PHASE_DONE</promise>
