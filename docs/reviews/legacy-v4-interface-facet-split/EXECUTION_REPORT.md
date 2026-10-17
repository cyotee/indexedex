> **Superseded — legacy family deleted (2026-10-15).** Retained as historical evidence only. Do not execute this plan or restore its implementation. See the [removal report](../legacy-v4-removal/EXECUTION_REPORT.md).

# Legacy V4 interface facet split — 2026-10-15

Status: **WITHDRAWN, 2026-10-15.** The owner is deleting `contracts/protocols/dexes/uniswap/v4`. The size overrun below is not an open gap. Do not continue this split.

Historical status: split implemented and behavioral validation complete. Across the legacy suites and untouched V3 control, 184 tests passed; only the two retained size assertions failed. IN, ERC-5115, and OUT still exceed the deployment size limit.

The owner authorized separating the legacy V4 ERC-5115 interface from `exchangeIn`, consolidating all eight ERC-5115 methods into one facet, and updating deployment wiring and tests. The earlier instruction to continue validation despite size overruns remains in effect.

## Implementation

| Facet | Product methods after the split |
|---|---|
| `UniswapV4StandardExchangeInFacet` | `exchangeIn` |
| `UniswapV4StandardYieldFacet` (new) | `deposit`, `redeem`, `exchangeRate`, `getTokensIn`, `getTokensOut`, `yieldToken`, `previewDeposit`, `previewRedeem` |
| `UniswapV4StandardExchangeOutMultiQueryFacet` | `previewExchangeOutOneToMany` |

`UniswapV4StandardExchangeInExecution` is a new abstract internal execution base with no public entrypoint. Both money targets inherit it. Its `_exchangeIn` body is unchanged from the pre-split IN target. The SY execution target no longer inherits the external `exchangeIn` method. `UniswapV4StandardYieldTarget` combines the existing SY money methods with the six moved reads and implements the complete `IERC5115_StandardizedYield` interface.

Both deposit flags, the internal-balance redemption caller gate, holder checks, reentrancy guards, minimum checks, and TWAP pokes retain their original code. No external call, self-call, delegate trampoline, or storage change was introduced. [Body comparison](evidence/body-preservation.txt) verifies the moved execution and SY money/helper bodies. [Artifact ABI check](evidence/abi-check.txt) verifies that the three changed facets expose exactly their assigned product methods plus IFacet metadata.

The package now installs 17 cuts. Existing indexes 0–15 remain stable; the new yield facet is index 16. The ERC-5115 interface declaration moves from the OUT multi-query facet to the yield facet; the package's existing ERC-5115 declaration remains. FactoryService deploys the new facet through CREATE3, and the production TestBase passes it through the manager/registry package path.

Facet declaration tests use the existing Crane `TestBase_IFacet` behavior suite. Proxy tests verify all eight SY selectors resolve to the new facet, while `exchangeIn` and the multi-token exit preview remain on their own facets. Package metadata tests, including their decimals variants, now assert all 17 facets. Their previous expectations had also omitted the callback already introduced by the prior architecture change; those indexes now match the deployed package.

## Build and runtime sizes

The production build passed: ten files compiled in 15.43 seconds, exit 0. [Build log](evidence/build.log). Command:

```sh
python3 scripts/forge-artifacts.py build \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol
```

Settings: Forge 1.5.1, Solc 0.8.35, default profile, Prague EVM, optimizer enabled with one run, `via_ir = false`. [Toolchain](evidence/toolchain.json). Existing `out/` and `cache_forge/` were retained.

| Facet | Before split | After split | Change | Over 24,576 |
|---|---:|---:|---:|---:|
| IN | 27,885 | 26,687 | −1,198 | 2,111 |
| ERC-5115 (new) | — | 29,373 | New facet | 4,797 |
| OUT multi-query | 16,937 | 6,114 | −10,823 | 0 |
| OUT | 30,033 | 30,033 | 0 | 5,457 |

Sizes are decoded `deployedBytecode.object` lengths, including metadata, from the artifacts; they are not creation bytecode sizes. The before artifacts were recorded before source edits. Changed facets were rebuilt before the after measurement. [Before](evidence/sizes-before.json), [after](evidence/sizes-after.json).

The split separates interface ownership and reduces the existing IN and query facets, but it does **not** resolve deployment size limits. IN, the new ERC-5115 facet, and OUT remain oversized. Shared internal execution and preview code still compiles into each facet that needs it; separating entrypoints does not turn those internal calls into shared deployed code.

## Validation

The [exact test command](evidence/test-command.txt) selects 25 concrete suites: the three affected facet declarations, ERC-5115 proxy behavior, architecture, vault-held redemption, full-range behavior, TWAP, package deployment, and eight concrete variants each for full-range decimals and package deployment decimals. The helper refreshes runtime artifacts before running tests. Execution uses the previously required approved unsandboxed path because Forge crashes on macOS system proxy discovery inside the sandbox.

The test compiler completed successfully in 174.45 seconds. Result: **175 passed, 2 failed, 0 skipped across 25 suites**, exit 1. [Full output](evidence/tests.log). The only failures are the existing `test_runtimeFacetSizes_withinEip170` tests: the package-order check first encounters IN at 26,687 bytes, and the loupe-order check first encounters ERC-5115 at 29,373 bytes. Their 24,576-byte assertions have not been raised or removed.

All three affected facet declaration suites passed. The ERC-5115 suite passed all 15 tests, including the six interface/deposit/event tests and nine inherited redemption tests. The package metadata and registry-deployment checks passed for the standard fixture and all eight decimals variants. Architecture selector ownership, full-range behavior, and TWAP checks passed. [Final artifact check](evidence/sizes-final-check.txt) confirms that the measured sizes remained unchanged after the test build.

The untouched V3 Pendle control also passed: **9 passed, 0 failed, 0 skipped**, exit 0. [Output](evidence/v3-control.log). Command:

```sh
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/sy/V3FullRangeNativeSY.t.sol \
  -- -vv
```

The control ran through the same approved unsandboxed execution path. [Hash verification](evidence/pendle-unchanged.txt) confirms the V3 test and eight shared SY files remained unchanged. No other-family source changes were needed.

## Integration notes

`IUniswapV4StandardExchangeDFPkg.PkgInit` gains `uniswapV4StandardYieldFacet`; callers must use the new struct encoding and supply the deployed facet. `Univ4SePkgInitCore` and its builder propagate the field. Existing encoded constructor payloads are not compatible. Fresh package deployments install the new cut; this work does not upgrade existing CREATE3 deployments or vaults. Existing vault-facing method signatures and behavior stay the same.

The [split-only diff](evidence/split.diff) and [changed-file list](evidence/changed-files.json) distinguish this work from extensive pre-existing changes recorded in [initial status](evidence/status-before.txt). The [scoped whitespace check](evidence/diff-check.txt) passed. Other families and shared SY sources were not edited. No commit, push, deployment, or PR was made.
