# Incremental Foundry artifact builds

Deployment helpers load creation bytecode from `out/` at runtime. Keeping implementation imports out of those helpers cuts the Solidity dependency graph, but makes an explicit artifact refresh necessary before tests or scripts deploy edited contracts.

For a warm checkout, pass every edited production source and an exact test file or suite directory to the helper:

```bash
python3 scripts/forge-artifacts.py plan contracts/path/EditedTarget.sol \
  --test-root test/foundry/spec/path/RelevantTest.t.sol
python3 scripts/forge-artifacts.py test contracts/path/EditedTarget.sol \
  --test-root test/foundry/spec/path/RelevantTest.t.sol -- -vv
```

`plan` shows the commands without compiling. `test` prepares the selected tests' runtime artifacts with one targeted `forge build`, then uses `--skip` to exclude unrelated compilation roots from `forge test`. A failed build stops execution before tests. The active profile, compiler settings, configured source/test paths, `out/`, and `cache_forge/` are retained. Pass multiple edited files as positional arguments. An abstract target edit selects concrete descendants, refreshing the deployed facet/package artifact as well as the target.

Repeat `--test-root` to run several files or directories together in one compilation/test command:

```bash
python3 scripts/forge-artifacts.py test contracts/path/EditedTarget.sol \
  --test-root test/foundry/spec/path/Deploy.t.sol \
  --test-root test/foundry/spec/path/regression -- -vv
```

For artifact refresh alone, use `build` instead of `test` and omit `--test-root`. No package profiles, compiler-setting changes, cache deletion, or concurrent writers to `out/` are needed.

Forge 1.5.1's `--match-path`/`--match-contract` selection first compiles ABIs for the configured project. An empty test filter bypasses that preliminary compilation. The helper normally leaves that filter empty and excludes unrelated roots with `--skip`, which Foundry applies before resolving imports. Required dependencies and external-library outputs remain available. Passing filters after `--`, or importing other `.t.sol` files outside the selection, adds a preliminary ABI compilation limited by the same skips. See [Forge 1.5.1 test selection](https://github.com/foundry-rs/foundry/blob/v1.5.1/crates/forge/src/cmd/test/mod.rs#L195) and [compiler 0.19.6 source selection](https://github.com/foundry-rs/compilers/blob/v0.19.6/crates/compilers/src/compile/project.rs#L175).

Keep `src`, `test`, and output paths stable between build/test commands. Changing `FOUNDRY_TEST` to a selected file/directory invalidates the entire shared compiler cache even when compiler settings are identical; the compiler requires cached project paths to match. The helper changes compilation-root filters instead of those configured paths. See [compiler 0.19.6 cache validation](https://github.com/foundry-rs/compilers/blob/v0.19.6/crates/compilers/src/cache.rs#L1060).

When preparing a test or script whose runtime artifacts may be missing, include its path or a quoted glob:

```bash
python3 scripts/forge-artifacts.py build contracts/path/EditedTarget.sol \
  --consumer 'test/foundry/spec/path/*.t.sol'

# A consumer can be prepared without specifying edited sources:
python3 scripts/forge-artifacts.py build \
  --consumer 'scripts/foundry/path/Deploy.s.sol'
```

The consumer itself is built by the subsequent `forge test` or `forge script`. The helper follows imports from that consumer to find literal `File.sol:ContractName` references and recursively prepares their source artifacts. Existing `.bytecode.linkReferences` add external libraries; cold library artifacts are compiled through their current Solidity imports. Warm worktree seeding of **both** `out/` and `cache_forge/` remains mandatory. `--all-artifacts` is available for a broader runtime artifact refresh.

The graph comes from current source files and the active `forge config --json`, including remappings. Foundry's cached imports may still contain removed dependencies, so the helper does not use them. It rejects ambiguous artifact IDs and unresolved selected imports before compiling. Use a full source path in an artifact ID when filenames and contract names collide.

The parser recognizes literal artifact IDs. A consumer that constructs IDs dynamically must also supply the concrete source paths. For loader tests intentionally requesting missing artifacts, disable automatic test-literal discovery and supply the real fixture/production sources explicitly:

```bash
python3 scripts/forge-artifacts.py test contracts/path/RealFixture.sol \
  --test-root test/foundry/spec/path/ArtifactLoader.t.sol \
  --no-consumer-artifacts -- -vv
```

`--no-consumer-artifacts` requires explicit source paths or an explicit `--consumer`; it does not bypass their build. Deleted or renamed sources likewise require their replacement and affected consumer sources to be supplied explicitly; the helper cannot infer dependencies that no longer appear in current source.

TestBases, test files, scripts, and artifact seed aggregators are excluded as independent roots in the changed-source plan, except implementations explicitly referenced as runtime artifacts. Solidity dependencies needed by a selected root are always included. A broad interface/library change can legitimately affect many implementations. The artifact-loading migration changes shared deployment helpers and needs a broad initial rebuild. No wall-clock improvement is implied by a source count; timing validation is separate, and cold builds/full release suites remain larger jobs.

Inspect remaining import coupling and creation-code use with:

```bash
python3 scripts/forge-artifacts.py audit contracts/path/EditedTarget.sol --json
python3 -m unittest scripts/test_forge_artifacts.py
```

The audit reports reverse-import counts, runtime artifacts whose implementations are also directly imported, and `type(...).creationCode` sites. A reported import can be needed for inheritance or implementation-specific tests, so the report is an inspection tool rather than an unconditional ban. Live onchain factories and proxy init hashes must retain actual creation code because they cannot access Foundry's local artifacts.

The Foundry-only loader reads artifact JSON directly. Unlinked bytecode uses the overload that accepts the CREATE3 factory, which deploys and links external libraries recursively. Missing/empty/malformed bytecode and unresolved links fail rather than deploy incomplete code. This workflow retains the registry/CREATE3 deployment paths; it does not replace onchain deployment logic with cheatcodes.

External libraries now deploy through CREATE3 with salts derived from their source identifier and fully linked creation code. These addresses replace Forge's automatic library addresses, so linked component bytecode and addresses derived through `releaseSalt` can change. Fixed instance salts still reuse occupied CREATE3 addresses; this migration does not replace already deployed instances at those salts.

## Migration measurements

Reverse-import counts below exclude the edited source itself and include transitive importers. They measure invalidation scope, not elapsed compilation time.

| Edited source | Before: all / hermetic test sources | After: all / hermetic test sources |
| --- | ---: | ---: |
| Single constant-product hook `SeTarget` | 1,774 / 1,637 | 6 / 1 |
| Orbital buffer hook `Common` | 977 / 882 | 25 / 4 |
| Weighted buffer hook `HooksTarget` | 274 / 248 | 3 / 0 |
| `FeeCollectorManagerTarget` | 3,401 / 3,047 | 3 / 2 |

On the development checkout with Forge 1.5.1 and solc 0.8.35, the initial production migration build compiled 959 changed files successfully in 366.16 seconds. That broad migration cost is separate from subsequent target edits. Compiler settings remained optimizer enabled, one optimizer run, and `via_ir = false`.

A subsequent reversible comment edit to the single constant-product `SeTarget` selected three build roots with a 136-source import closure. Forge recompiled **five files in 3.64 seconds**; the complete helper command took **18.94 seconds**, including source-graph discovery and linting. An unchanged invocation skipped compilation and took 16.26 seconds. Restoring the exact original source recompiled five files in 4.05 seconds (19.73 seconds for the complete command). This measures invalidation from a small edit, not the compilation cost of every possible implementation change.

The artifact-loader suite passed all nine tests using the stable-path test command, with both artifact and test compilation skipped from cache. Coverage includes production deployment without implementation imports, executable/reused library links, nested links, qualified source matching, and explicit errors for invalid, missing, empty, or factory-less linked artifacts.

Additional validation ran 235 tests across the converted deployment families (233 passed) and 140 rebasing-vault tests (139 passed). Seven representative deployment scripts compiled successfully; scripts were not broadcast. Three product assertions remain failing in the existing workspace state:

- Weighted hook facet runtime: 24,680 bytes versus the 24,576-byte limit.
- Curve quad hook facet runtime: 24,789 bytes versus the same limit.
- `RebasingAwareERC4626_Buffers_Detf.test_F16_cpDetfMintRedeemWrapperShareReserve`: `InvalidRoute(wrapper, wrapper)` during withdrawal preview. `_previewUnwrapSe` calls `previewExchangeIn` without the identity-conversion branch already present in actual unwrapping.

The migration changes no production dependency of either oversized facet, and linking only replaces fixed-width addresses. The DETF trace identifies a preview route issue in existing product code. These product/test edits were already present before this migration and were preserved. The complete hermetic runtime suite and network fork tests were not run.

The final buffer-pool smoke suite passed all 16 tests, and DETF facet packaging/release validation passed all 10 tests. Those checks cover the remaining direct artifact lookups and rejection of stale release dependencies. Across the selected runtime suites, 407 tests passed and the three product failures above remain. The build planner's 24 Python tests and the shared-skill symlink check also passed.

An ABI-only solc check of all 5,716 sources in the configured production/hermetic test graph completed with zero errors in 171.02 seconds, without writing shared artifacts or cache. Seven representative maintained scripts received separate bytecode compilation. An attempted wider check including archived scripts encountered four pre-existing missing `DeploymentBase.sol` imports; archival paths were not repaired.

The new CI preparation command, `python3 scripts/forge-artifacts.py build --all-artifacts`, also passed locally. It selected 319 runtime artifact roots and compiled 27 changed files in 4.14 seconds (24.54 seconds for the complete command).

This migration includes two interface extractions inside the `lib/crane` submodule (`IERC4626PermitDFPkg` and `IERC20MintBurnOwnableOperableDFPkg`), alongside their implementation re-exports. Include those submodule changes when committing or sharing the workspace changes.
