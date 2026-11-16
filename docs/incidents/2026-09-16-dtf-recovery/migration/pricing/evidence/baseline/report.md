# Unchanged weighted DETF baseline

Date: 2026-11-10. Result: **PASS for the three requested unchanged-code commands: build exit 0; 8 tests passed, 0 failed, 0 skipped.** This is the initial baseline node, not completion of implementation-plan task 2 or gate E3.

The existing public mint preview below is captured exactly. Both exercised post-first-bond exchange paths use the reserve-swap fallback, not the primary seigniorage mint branch. These observations must not be relabeled as frozen primary mint-branch differential vectors.

## Execution identity

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02`.
- Branch: `work/dtf-migration-phase-02`.
- HEAD: `90ff0307a7a8e084aa073e02eff125e9c7973933`.
- Selected Forge: `/Users/cyotee/.foundry/bin/forge`, `1.9.1-nightly`, commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`, built `2026-11-03T06:12:02.538056000Z`.
- Selected Solar: `/Users/cyotee/.foundry/bin/solar`, `0.3.0-dev+commit.e7a91fc7`, Solidity `0.8.38`. The build itself confirms `Solar 0.8.38`.
- Inherited PATH initially resolved `/opt/homebrew/bin/forge`, `1.9.0-Homebrew`. The recorder prepended `/Users/cyotee/.foundry/bin`; Homebrew Forge was queried for its version only and was never used to compile.
- `toolchain.txt` contains actual versions and `forge config --json`: normal `contracts` / `test/foundry/spec`, `out`, `cache_forge`, optimizer enabled with one run, `via_ir: false`, and no additional compiler profiles. The retained `solc: "0.8.35"` configuration was not changed; every compiling command explicitly selected Solar.

`run.sh` is the evidence-only recorder. Every invocation explicitly changes to the worktree and exports:

```sh
TMPDIR=/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-baseline.iud2vw
NODE_COMPILE_CACHE="$TMPDIR/node-compile-cache"
BUN_RUNTIME_TRANSPILER_CACHE_PATH="$TMPDIR/bun-transpiler-cache"
PATH="/Users/cyotee/.foundry/bin:$PATH"
```

The runtime root was created with `mktemp -d` using the requested `pricing-baseline.XXXXXX` template. It is now removed. All compilation/test commands ran sequentially under persistent monitor subscriptions and were allowed to exit naturally. A requested four-hour monitor deadline exceeded the monitor interface's one-hour maximum; that rejected request launched nothing. Persistent monitors were then used without a compile-killing deadline. A rejected first-suite monitor regex likewise launched no test.

## Commands and actual outcomes

All times are UTC on November 10, 2026. `*-command.txt` records the resolved binary, cwd, environment, recorder PID, start time, and shell-escaped argv. `*-exit.txt` separately records the Forge and trace-capture `tee` exits and end time.

| Command | Start / end | Result | Raw evidence |
| --- | --- | --- | --- |
| `forge build --use solar` | 13:50:17 / 13:52:48 | Forge 0; tee 0. Compiled 5,793 files; Solar compilation reported 65.25 seconds. | `build-command.txt`, `build-exit.txt`, `build.log` |
| `forge test --use solar --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted.t.sol' -vvvv` | 13:53:12 / 13:53:21 | Forge 0; tee 0. 4 passed, 0 failed, 0 skipped. | `weighted-command.txt`, `weighted-exit.txt`, `weighted.log` |
| `forge test --use solar --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol' -vvvv` | 13:53:31 / 13:53:42 | Forge 0; tee 0. 4 passed, 0 failed, 0 skipped. | `nested-command.txt`, `nested-exit.txt`, `nested.log` |

The artifact-aware helper was not needed or invoked. The full requested build completed; no full unrelated test suite ran.

The weighted suite passed creation-length, custom single-pair mint-route, first-bond/exchange, and allowed-pair/not-other-pair checks. The nested suite passed first bond, mint preview/execution equality, burn preview/execution equality, and mature funded claim/close, with existing residual and allowance assertions unchanged.

No baseline build/test failure occurred. Existing warnings remain in the raw build log, including unreachable code, mutability suggestions, the unknown `fmt.skip` configuration key, and an AST-source warning for `BasicVaultErrors.sol`. They were not suppressed or repaired.

## Fixture provenance

Both test files and the following gold TestBases were read before execution:

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol`.
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Univ3Se.sol`.
- Their shared deployment portions in `TestBase_UniswapV4Detf.sol`, `TestBase_UniswapV4Detf_Weighted_ProdSe.sol`, and `UniswapV4DetfProductionSeDeployLib.sol`.

These deploy real DETF/hook facets through CREATE3 FactoryServices, registered packages through the IndexedEx manager/registry, and real package-created proxies and children. The weighted fixture wraps `SimpleYieldERC4626` dependencies through real ERC4626 SE packages; these are not a production lending-protocol integration. The nested fixture deploys two real UniV3 FullSpread SE packages around seeded protocol-port UniV3 pools, with rate providers and actual funded two-token SE activation. Existing mintable-token/yield fixtures and Permit2 etching were retained; no DETF, hook, SE, manager, registry, or fee-oracle replacement was introduced.

The first weighted fixture assigns weights `[4e17, 3e17, 3e17]` in sorted token order. The production-SE fixture explicitly assigns `4e17` to the DETF self-leg and `3e17` to each pair. Both use the ordinary unified DETF package, native 9-decimal DETF output, 18-decimal pair inputs, and a 30-day first bond. These local test tokens are not historical ETH/DTF contribution records.

## Original preview and quote observations

All amounts below are exact integers. `observations.json` preserves the observations as integer strings with trace line locators. Local fixture addresses identify this run only.

| Existing fixture / operation | Input and setup | Observed preview | Observed execution |
| --- | --- | --- | --- |
| Weighted ERC4626, `test_T8_2_firstBond_thenMintPair0` | First bond `80000000000000000000`; subsequent pair0 input `8000000000000000000` | No public DETF preview is called by this test. The existing internal hook swap preview returns `5268940424, 0` at `weighted.log:1904`. | Public exchange returns `5268940424, 0` at `weighted.log:2038`. |
| Weighted production UniV3, `test_H_WE_GV3_mint` | First bond `100000000000000000000`; subsequent mintToken input `10000000000000000000` | Public DETF `previewExchangeIn` call at `nested.log:48902`, return `5617384097, 0` at `nested.log:49328`. | Public exchange call at `nested.log:49332`, return `5617384097, 0` at `nested.log:50050`; original exact-equality assertion passes. |

The branch characterization is trace-backed:

- Weighted ERC4626 execution calls `ownerSwapExactIn` at `weighted.log:1798`. Its weighted math returns WAD output `5268940424990216880` at `weighted.log:1903`, then native DETF output `5268940424`.
- Production UniV3 execution calls `ownerSwapExactIn` at `nested.log:49506`. Its public preview calls the hook with the original `10000000000000000000` at `nested.log:49062`, not a seigniorage-boosted amount. The hook reads fee WAD `50000000000000000` at `nested.log:49201-49203`, previews a UniV3 SE deposit with `9500000000000000000` at `nested.log:49213`, and feeds mapped input `7027072017498277717` to weighted math at `nested.log:49322`. That returns WAD output `5617384097261037700`, converted to native DETF output `5617384097`.
- The same nested preview also reads rate-provider redemption state through real SE previews (`nested.log:48921-49001` and subsequent calls). Its amount-dependent SE mapping is present in the retained trace, not replaced by a scalar price.

Source interpretation agrees: `UniswapV4DetfTarget.sol:175-193` has the gate-dependent preview fallback; `UniswapV4DetfCommon.sol:170-179` converts contributions to pair units and `:259-262` applies the primary mint uplift. `DETFMintSplitLib.sol:19-26` applies the primary user split. Those primary mint operations are not proven by the fallback returns above.

**Coverage limit:** the unchanged suites expose ordinary quote/execution behavior and nested conversions, but not a complete canonical primary-mint oracle for both original ETH and DTF on one immutable book. No new preview surface, test, or evaluator was added to force that coverage. Future task-2 differential tests must establish primary-branch parity, frozen dependency closure, subsequent-live-change independence, zero components, rounding/domain boundaries, and no fallback. These passing fallback observations cannot satisfy those obligations.

## Unchanged boundaries and cleanup

`before-code.sha256` and `after-code.sha256` contain the same 5,200 tracked-file fingerprints covering `contracts`, `test`, `scripts`, Foundry/remapping configuration, and tracked root package/lock files. Their byte comparison returned 0. Both matching code-diff files are empty. `before-state.txt` and `after-state.txt` preserve workspace status, HEAD/branch, warm artifact directories, and dependency-link targets.

The first status command with `--ignore-submodules=none` encountered the pre-existing linked-submodule limitation, `expected submodule path 'lib/crane' not to be a symbolic link`. Its complete receipt remains in `initial-status-symlink-warning.txt`. Status capture was repeated successfully with `--ignore-submodules=all`; this does not independently hash shared dependency contents. No command in this node edited either shared link or its target. Existing copied incident inputs and other workers' report paths were left untouched.

`boundary-cleanup.txt` records:

- Shell syntax check exit 0; fingerprint comparison exit 0; code-diff comparison exit 0.
- Build/test recorder PIDs `21714`, `23806`, `24033` absent after completion (`ps` exit 1 with no matching rows). Individual Forge child PIDs were not retained separately; each foreground child and trace pipeline had already returned its recorded exit.
- Owned runtime directory removal exit 0 and explicit absence read-back exit 0 at `2026-11-10T13:55:47Z`.
- `out` and `cache_forge` preserved, and unchanged `lib/crane` / `node_modules` link targets read back. No node daemon, listener, or port was created; no unrelated process, port, or runtime root was cleaned.

Authored files are confined to this baseline directory. Build-generated `out` / `cache_forge` changes are the expected output of the requested compilation, not source edits. No product/test/shared-dependency edits, commits, installations, deployments, public transactions, or operational allocations occurred. Bash and JSON LSP servers were unavailable; no installation was attempted. Bash syntax and JSON parsing were checked instead.

Fungible ancestry and TokenStaking owner questions remain open and untouched. This report neither closes them nor claims task 2 complete.
