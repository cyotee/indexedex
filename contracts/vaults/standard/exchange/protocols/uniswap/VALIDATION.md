# V2 implementation validation

Date: 2026-09-15. Local hermetic fixtures; no live transactions.

## Result

**86 passed, 0 failed, 0 skipped**, across six suites:

| Suite | Tests |
|---|---:|
| Preserved V3 baseline | 2 |
| Preserved V4 baseline | 2 |
| New V3 delivery/accounting | 26 |
| New V4 ERC20 delivery/accounting | 26 |
| New V4 native currency/WETH delivery/accounting | 26 |
| Independent constant-product examples/inversion checks | 4 |

[REGRESSION_RESULTS.txt](REGRESSION_RESULTS.txt) contains the actual test runner results. Fuzz tests use the repository default 16 runs. The [README](README.md#validation) records the build-before-test command. The production build and test compile passed with Solidity 0.8.35, optimizer runs 1, without viaIR. Existing unrelated hash-efficiency lint notes were emitted. Forge required execution outside the macOS sandbox after its system-proxy discovery crashed; the successful command still used local hermetic fixtures.

All 26 new facet, delegate and package runtime artifacts are below EIP-170's 24,576-byte limit; the largest is 23,737 bytes. [VALIDATED_ARTIFACTS.json](VALIDATED_ARTIFACTS.json) records the measured sizes and hashes of the unlinked runtime object strings. All 96 preserved source/document hashes match the pre-implementation manifest.

## Coverage

- Old real packages demonstrate zero-input share minting and redemption after ordinary market trades in both directions. The market trader is separately funded; the false depositor has zero input.
- New real registry-deployed packages reject unfunded input in both price directions, with a deployed position and positive local balances. Controls cover no position/no movement.
- Pull and prepared input succeed after price movement. Reuse, donation claims, wrong caller/recipient, missing/short/excess input and unconsumed credits fail with specific errors and unchanged vault balances/supply.
- Direct exact-input and exact-output swaps, single/multi deposits, exact-input/exact-output share withdrawals, and two-token withdrawals exercise real public selectors. Refund assertions track exactly the verified unused input.
- Both new versions support prepared deposits and withdrawals inside real locked protocol callbacks. Single-token sleeve exits include both entitlements, and exact-output quotes match execution.
- Native V4 tests exercise WETH unwrap/ETH settlement and rewrapping with the real PoolManager and WETH9.
- An external test token implements actual fee deductions and transfer callbacks. Fee-on-transfer funding reverts and rolls back; reentrant preparation is blocked while honest input still completes.
- Shared accounting matches an independently worked zero-fee swap-plus-proportional-mint example and its reverse exit; mixed decimals, products exceeding 256 bits, and fuzzed inverse rounding are checked.

## Scope of this evidence

This is the focused remediation suite, not a claim that every broader PRD release gate is complete. The preserved full feature suites are not substitutes for tests against the new packages. Imported NFT-position lifecycles, a multi-operation invariant campaign, all external hook/router/SY consumers, and every existing governance/disable policy require their own broader release validation. Old push-only consumers are incompatible until updated as described in the README. No deployment or immutable-consumer migration has been performed.
