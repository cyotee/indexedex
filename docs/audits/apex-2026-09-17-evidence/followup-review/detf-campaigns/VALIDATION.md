# DETF validation overlay

Validation completed in `/tmp/apex-review-detf-validation`; this agent made no shared worktree edits. The parent integrated the five production and four regression files after their corrected regressions passed. The six invariant files remain available as `invariants.patch`.

1. Apply `regression.patch` to unchanged production originals. Run `red.py` in the independently seeded validation clone; it rebuilds all five edited-production-source descendants before the seven regression tests. Failures must be assertion/runtime reproduction failures, not compile/setup failures.
2. Apply `production.patch` and `invariants.patch`, rebuild the changed concrete runtime artifacts, run the same regressions and all five deterministic lifecycles.
3. Run five `invariant_accounting` campaigns with `FOUNDRY_INVARIANT_RUNS=256 FOUNDRY_INVARIANT_DEPTH=64 FOUNDRY_FUZZ_RUNS=10000`; source inline fail-on-revert is true. No failed action is caught or discarded. Eight-cycle deterministic lifecycle and depth-64 campaign each exercise the full rotating action set.

Production descendants include `MixedBufferMultiVaultStableDetfExchangeInFacet`, `MultiVaultWeightedDetfExchangeInFacet`, `ComposedStableCommonDetfExchangeOutQueryFacet`; abstract-source arguments to forge-artifacts.py also cover other concrete descendants automatically. Existing facet selector lists remain unchanged; rerun R12 size/selector checks after compiling.

All five campaigns use actual deployed DETFs, protocol reserve pools, and production router routes. UniV4, MixedBuffer, Composed and SingleSE use configured hostile non-SUT inputs to reach actual callback guards with identical funded calldata successful outside the lock. MultiWeighted package rejects hostile receipt-token configuration and uses actual registered SE shares; its callback-installation rejection is already covered in MultiVaultWeightedDetf_Reentrancy.t.sol. That campaign substitutes a second real market trade. SingleSE has no DETF exchangeOut or sweep selector and uses a second donation. UniV4 has no exchangeOut and uses its existing sweep selector. The three Balancer exact-output families exercise stake and unstake refunds. All five campaigns also exercise each deployed raw-SY child through funded deposit and partial redemption, with exact raw-token and SY-share balance deltas. Attack snapshots include staking liabilities and reserve LP custody.

No public fee-collection or rebalance entrypoint exists on these DETF surfaces. Market swaps accrue actual reserve fees; daily synchronizeRewards tests existing epoch maintenance, staking backing, and preservation of reserve LP custody. No new product API or economics are introduced.

Separate legacy decimals-only MultiWeighted/SingleSE campaigns are not replaced by these canonical-family changes. Their existing tests are not evidence of the new action accounting; native-unit regression evidence is a separate release requirement.

## Validation progress

- `red-003`: all seven regression tests fail at the expected runtime balance assertions on the exact original five production files. `red-002` is the preceding four-test reproduction; interrupted `red-001` is not evidence.
- `green-001`: corrected concrete runtime compilation succeeded. Test compilation exposed a stack-depth limit in the new stateful prepaid snapshot helper. Snapshot locals were grouped in a struct without changing its assertions or compiler settings.
- The overlay was formatted after RED; regression logic is unchanged. `package.py` reads immutable `originals/` so subsequent packaging cannot accidentally use corrected clone sources as its baseline.

- `green-002`: test compiler still required the atomic call expression to be split; `_atomicPrepaidMint` now isolates calldata construction without changing semantics.
- `green-003`: all seven refund regressions and four deterministic lifecycles pass. UniV4 reached a staged initialization getter removed by finalization; the market host now builds the actual deployed Single CP pool key.
- `green-004`: the actual UniV4 swap exposed the generic core test router’s settle-after-swap mismatch. The host now uses the repository’s existing `WrapperExactOutRouter`, as the live wrapper-hook matrix does, to settle before hook input is taken. Actor debit and output checks are retained.

## Final result

- `green-005`: all seven refund regressions and all five deterministic eight-cycle lifecycles pass: 12/12, no failures or skips.
- `campaign-001`: all five stateful campaigns pass at 256 runs × 64 calls, 16,384 calls per family, zero reverts, seed `0x20260917`; complete runtime 1,698.25 seconds.
- `forge fmt --check` passes for all 15 overlay files. Read-only `git apply --check invariants.patch` passes on the shared worktree after production/regression integration.
- Changed concrete runtime sizes are 17,873 bytes (MixedBuffer), 21,059 (MultiWeighted), and 20,937 (Composed). All three function-selector maps are unchanged.
- Exact commands, source/artifact/log hashes, clone inode isolation, and asserted action counts are in `validation-evidence.json`, also copied to `/tmp/apex-detf-invariant-manifest.json`. Combined patch: `/tmp/apex-detf-invariant.patch`.
