# Implementation plan — Aave liquidation-library filename disambiguation

- Date: 2026-10-12
- Status: implemented 2026-10-12. Filename rename, import retargets, loader restoration, and Crane-root placeholder regeneration are in the working tree. Not committed. Full invariant, decimal, adversarial, matrix, and Crane-native suites were not finished; the invariant file run was aborted.
- Controlling requirements: [PRD.md](PRD.md), including the human's filename-only decision.
- Readiness: no outstanding owner requirement questions. Actual compiler output, additional callers, and test results are implementation checks, not reasons to reopen the approved naming choice.
- All commands below are **proposed, not run**. Writing this plan does not authorize running them, editing source, renaming files, committing, or deploying.

## 1. Fixed scope

Rename in the existing version directories:

| Source | New basename |
|---|---|
| `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol` | `LiquidationLogicAaveV3.sol` |
| `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol` | `LiquidationLogicAaveV4.sol` |

Both continue to declare `library LiquidationLogic`. Preserve their file contents, including SPDX, pragma, function bodies, constants, structs and visibility. Do not rename test files, wrappers, `getLiquidationLogic()`, directories, or other Aave math libraries. No old-filename forwarding implementation.

Retarget imports and artifact/link identities; restore IndexedEx artifact-based linking; retain the seed. Do not remove genuine creation-code deployment in V3 `AaveV3LibrariesBatch2.sol`.

### Invocation roots

- **IndexedEx root:** current repository, its TestBases, generic artifact loader and `scripts/forge-artifacts.py`.
- **Crane root:** `lib/crane`, its BC linking helpers and native tests. Compiler source identities here start with `contracts/`, not `lib/crane/contracts/`.
- Validate the two libraries under both roots, with each root's existing configuration and its own output/cache.
- No operational emitter should output upstream `src/spoke/...` for these supported roots. Do not silently generalize Crane BC helpers to run from IndexedEx root.

Evidence: `BC_AAVE_V4_DEPLOY_STEPS.md:139–150` explicitly names the Crane path and working directory. This resolves the root question without further owner input.

## 2. Preconditions and baseline

1. Read current `CLAUDE.md`, coding/test rules, current family PRD and canonical skills before implementation. Preserve current product law and all unrelated working-tree changes.
2. Record IndexedEx/Crane revisions and local changes. Coordinate the eventual Crane change and IndexedEx submodule reference; do not reset either tree or mix unrelated changes into a commit.
3. Record the actual Forge version and compiler used by Forge, not merely whichever `solc` executable is on PATH. Record only nonsecret settings: compiler version, optimizer runs, EVM version, via-IR state and configured source/test/output/cache paths. Do not dump environment values or unreviewed configuration.
4. Preserve and warm-seed each root's configured output/cache in new workspaces. Serialize artifact writers; wait for compilation to exit. Use multi-hour timeouts, not output inactivity as a failure signal.
5. Save baseline source hashes, artifact compilation targets, full initcode hashes, link references, ABI, method identifiers and storage layouts for both libraries and concrete Pool/Spoke instances. Check source provenance before trusting any existing JSON artifact.
6. Re-run the PRD's direct-import/reference inventory. Current inventory is 12 imports: 11 retargets and one TestBase import removal. Inspect actual calls to `ArtifactCreationCode.creationCode`; a line-based regex is not proof of arity for multiline/nested calls.

**Gate:** another required four-argument loader caller triggers scope review before deleting its support. Additional import hits simply extend the rename inventory if within the approved scope. Missing upstream provenance is recorded, not fabricated.

## 3. Source edits, in dependency order

### 3.1 Rename the two library files

Move each source to its new basename without changing contents. Retain both `LiquidationLogic` declarations. Verify before/after content hashes of the renamed files agree. Import style changes belong to importing files, not the library bodies.

### 3.2 Retarget all live imports

Use the full paths in PRD §4 as the checklist:

- V3 production: `Pool.sol`, `LiquidationDataProvider.sol`, `AaveV3LibrariesBatch2.sol`.
- V3 tests: `LiquidationHelper.sol`, `Pool.Liquidations.CloseFactor.t.sol`, `Pool.Liquidations.t.sol`, `L2Pool.t.sol`.
- V4 production: `Spoke.sol`.
- V4 tests: `setup/Base.t.sol`, `LiquidationLogicWrapper.sol`.
- IndexedEx: `CraneFactoryArtifactSeed.sol`.

Keep the imported binding `LiquidationLogic`, existing qualified calls and `using` directives. Follow current canonical style on changed imports without sweeping unrelated imports. Do not modify Echidna's symbol binding; filename-only leaves it valid.

### 3.3 Restore the normal IndexedEx loader path

In `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol:15,81–88`:

- Remove the V4 library implementation import and direct-bytecode workaround comments.
- Replace the four-argument Spoke load with:

```solidity
ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")
```

- Leave Hub loading, protocol orchestration, deployment salts, reserve setup and economics unchanged.

In `contracts/utils/foundry/ArtifactCreationCode.sol`, after caller verification:

- Remove the four-argument overload and override ID/bytecode parameters and substitution logic threaded through `_creationCode` / `_linkSource`.
- Keep ordinary one-/two-argument entrypoints and recursive loading through actual artifact link references.
- Preserve source-target checks, depth limit, malformed/empty/missing/unlinked rejection, factory authorization, CREATE3 salt derivation, deployed-code checks, offset bounds, memory compaction and `releaseSalt` semantics.
- Avoid a general loader redesign or fallback that silently accepts another version.

In `CraneFactoryArtifactSeed.sol:28,35–38,59`:

- Keep the seed, updated V4 import and `type(LiquidationLogic).name`.
- Replace the recommendation to bypass JSON with the unique-filename artifact workflow.
- Do not import the seed from TestBases, FactoryServices or scripts.

### 3.4 Correct Crane linker identities

In `SpokeBytecodeLinker.sol:15,20–21,36–38`:

- Use `contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic` for Crane-root artifact identity and emitted library configuration.
- Keep the existing CREATE2 salt and helper API names.
- Mark the old placeholder as pending regeneration until §4 has produced a fresh Crane-root artifact. Do not run this linker with the stale constant.

In `T4/scripts/utils/SpokeDeployUtils.sol:22,30,79` (T4 = `lib/crane/test/foundry/spec/protocols/lending/aave/v4`):

- Retarget `vm.getCode` and emitted configuration to the same Crane-root identity.
- Remove the unsupported upstream `src/spoke/...` output for this workflow.
- Narrow library-address parsing to the specific V4 source identity, not just `LiquidationLogic:`.
- Test parsing/formatting using synthetic strings. Do not invoke scripts that read/write real environment files or use FFI as a validation shortcut.

Preserve `BytecodeHelper` Hub/Spoke artifact names and BC wrapper/report names. Update directly affected comments. Do not widen this to another deployment architecture.

## 4. Warm artifact migration — direct Forge first

**Why order matters:** `scripts/forge-artifacts.py:198–212,240–253` reads existing link references; its `build` action still calls planning before compilation (`417,427–428`). Old Spoke/Pool artifacts can refer to the removed filename and make the helper fail before a replacement is built.

Therefore do not bootstrap with `forge-artifacts.py build`. First invoke **direct `forge build` with explicit renamed sources and concrete dependents**.

Proposed from IndexedEx root, after source edits:

```bash
forge build \
  lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  lib/crane/contracts/protocols/lending/aave/v3.6/instances/PoolInstance.sol \
  lib/crane/contracts/protocols/lending/aave/v3.6/instances/L2PoolInstance.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol \
  contracts/utils/foundry/CraneFactoryArtifactSeed.sol
```

Refresh any additional concrete consumer found to retain old link references, including deployment batches as needed. Repeat the equivalent root-relative build from Crane root for its own artifacts. Verify both renamed artifacts and refreshed consumer identities before running the helper. A normal full build is permitted when necessary; a destructive rebuild is not.

**On stale-ID failure:** identify and directly rebuild the specific stale consumer. If current-source refresh cannot unblock planning, stop for a narrow planner review with regression tests. Do not ignore unresolved libraries, restore the bypass, or delete cache/output to conceal the problem.

### Placeholder regeneration

From the fresh **Crane-root** `SpokeInstance` artifact:

1. Locate the new V4 source-qualified `bytecode.linkReferences` entry and every offset/length.
2. Identify the placeholder bytes at those offsets. Do not assume a whole-file regex has found the only library token.
3. Replace `LIQUIDATION_LOGIC_PLACEHOLDER` with the compiler-verified token; confirm the old token is gone from live linker source.
4. Rebuild the linker and its consumers. Add a hermetic mismatch/unresolved-link regression so a future filename change cannot silently leave the hardcoded token stale.

A prelinked artifact may have no placeholder. Diagnose that state and report it; do not change compiler configuration or use `--force` to manufacture a desired token. Keep root identities separate; an IndexedEx token is not evidence for a Crane-root constant.

## 5. Regression work

Use real production/protocol fixtures, not new mocks of the library, Pool, Spoke, registry or factory.

1. **Version binding:** assert each real Pool/Spoke `getLiquidationLogic()` equals its expected version's library address, and the two addresses differ. Nonzero alone is insufficient. Include an executable liquidation and deficit-related path for each version.
2. **Artifact isolation:** load each new source-qualified artifact and validate provenance; wrong-source and missing-artifact cases must fail closed. Build both versions together and in each separate order and check that neither output acquires the other version's target or ABI.
3. **Invariant regression:** strengthen the namesake setup test in `AaveCrossVersionLoop_Invariant.t.sol` to verify artifact-based V4 binding rather than merely a nonzero address or an unproven overwrite story. Run the actual invariant suite with its existing run/depth configuration, not just setup smoke. Do not lower counts to make it pass.
4. **Loader preservation:** retain nested-link, occupied-identity, source-matching, error, and scratch-memory tests in `test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol` after removing override plumbing.
5. **Planner preservation:** add isolated stale-pre-rename-link/missing-artifact fixtures to `scripts/test_forge_artifacts.py` where needed to verify preparation ordering and fail-closed behavior. Do not modify shared real artifacts for negative tests.
6. **Operational strings:** use hermetic helper tests with synthetic linking configuration to prove root-correct output and exact V4 selection. Compilation alone does not verify the parser's behavior.

### Build-order evidence

For each root, build V3 then V4; V4 then V3; and both together. After each step inspect both renamed artifacts' compilation targets, bytecode and link references. Record whether compilation actually occurred. Cache-hit-only runs are coexistence observations, not proof of output-writing behavior. If further invalidation experiments are needed, request a bounded isolated test design rather than clearing caches or silently modifying the liquidation engines. Missing-artifact tests belong in isolated fixtures; new full workspaces must follow warm-seeding rules.

## 6. Validation commands and test selection — PROPOSED, NOT RUN

### IndexedEx cross-version family

After §4 succeeds, from IndexedEx root:

```bash
python3 scripts/forge-artifacts.py plan \
  lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  contracts/utils/foundry/ArtifactCreationCode.sol \
  contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol \
  --test-root test/foundry/spec/protocol/lending/aave/cross-version

python3 scripts/forge-artifacts.py test \
  lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  contracts/utils/foundry/ArtifactCreationCode.sol \
  contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol \
  --test-root test/foundry/spec/protocol/lending/aave/cross-version \
  -- -vv
```

Require actual discovery/execution of the invariant, decimal and adversarial suites. Inspect selected tests and counts; exit code zero with no tests is not a pass.

### Generic loader and planner

Do not feed the loader suite's intentionally nonexistent artifact IDs into automatic test-literal discovery. Prepare all real runtime artifacts (and any newly added real fixtures) separately, then run the suite:

```bash
python3 scripts/forge-artifacts.py build --all-artifacts
forge test --match-path 'test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol' -vv
python3 -m unittest scripts/test_forge_artifacts.py
```

If broad preparation exposes unrelated stale IDs, resolve their concrete preparation or report the blocker; do not relax resolution. A narrower explicit preparation with `--no-consumer-artifacts` is permissible only with a complete real fixture list. No planner `resolve` subcommand exists.

### Matrix consumers — 21 direct `.t.sol` files verified in this round

Base directory: `test/foundry/spec/hooks/uniswap/v4/standardExchange/`.

For **each row**, select exactly these three paths: `<directory>/<stem>.t.sol`, `<directory>/decimals/<stem>_F6.t.sol`, and `<directory>/decimals/<stem>_F9.t.sol`.

| Directory | Stem |
|---|---|
| `single` | `UniswapV4SingleSEBufferHook_SeMatrix_AaveCrossVersionLoop` |
| `dual` | `UniswapV4DualSEBCPHook_SeMatrix_AaveCrossVersionLoop` |
| `weighted` | `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_AaveCrossVersionLoop` |
| `orbital` | `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_AaveCrossVersionLoop` |
| `constantProduct/single` | `UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_AaveCrossVersionLoop` |
| `stable/quad/balancer` | `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_AaveCrossVersionLoop` |
| `stable/quad/curve` | `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_AaveCrossVersionLoop` |

Recheck for additional direct/transitive consumers immediately before implementation. Use repeated exact `--test-root` arguments with the artifact helper, selected in bounded batches if necessary. Example of one batch:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/utils/foundry/ArtifactCreationCode.sol \
  contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_AaveCrossVersionLoop.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/decimals/UniswapV4DualSEBCPHook_SeMatrix_AaveCrossVersionLoop_F6.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/decimals/UniswapV4DualSEBCPHook_SeMatrix_AaveCrossVersionLoop_F9.t.sol \
  -- -vv
```

Repeat for the other six rows. `SeMatrix_AaveLoopFixture.sol` is a helper, **not** a valid runnable test root (`forge-artifacts.py:297–309`).

### Crane suites and script compilation

Run from **Crane root**, using its existing configured test profile/root. A test-path filter from IndexedEx root does not automatically discover Crane-native tests.

```bash
forge build
forge test --match-path 'test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/*.t.sol' -vv
forge test --match-path 'test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/**/*.t.sol' -vv

forge build scripts/foundry/bc/Script_BC_Phase3_Aave.s.sol \
  scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol
```

Confirm the V3 liquidation/close-factor/helper/getter coverage and V4 library/liquidation/deficit/getter/configuration suites actually ran. Include additional helper consumers where current discovery shows these selections are insufficient. Compile the affected vendored precompile/example scripts too; report unresolved unrelated dependencies rather than widening this rename.

**Do not substitute `forge script --sig run()` for compilation.** It executes even without broadcasting and can invoke FFI or mutate local files. Script formatting/parser behavior belongs in hermetic tests, not deployment `run()`.

### Compatibility inspection

Use source-qualified contract IDs, with each root's correct path prefix. Proposed examples from IndexedEx root:

```bash
forge inspect lib/crane/contracts/protocols/lending/aave/v3.6/instances/PoolInstance.sol:PoolInstance methodIdentifiers
forge inspect lib/crane/contracts/protocols/lending/aave/v3.6/instances/PoolInstance.sol:PoolInstance storageLayout
forge inspect lib/crane/contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol:SpokeInstance methodIdentifiers
forge inspect lib/crane/contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol:SpokeInstance storageLayout
forge inspect lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol:LiquidationLogic methodIdentifiers
forge inspect lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic methodIdentifiers
```

Also compare ABI and L2PoolInstance layout/identifiers against the baseline. Normalize source-path/AST-ID differences when comparing layouts, not slot/offset/type changes. Do not require runtime hash to equal initcode hash or the first bytes of initcode to change. Compare full hashes and explain metadata, link-address and library-runtime address patches.

## 7. Documentation and provenance

Update maintained path/configuration examples in Crane V4 `deployments/README.md`, `BC_AAVE_V4_DEPLOY_STEPS.md`, and live greenfield documents inventoried in PRD §5. Correct the touched BC step's destructive `forge build --force` recommendation to the non-destructive preparation workflow; do not rewrite unrelated deployment instructions or run them.

Record the filename-only deviation in `lib/crane/docs/protocols/lending/aave/v4/VENDOR_PROVENANCE.md`; discover the V3 equivalent and record the V3 deviation in appropriate maintained documentation without inventing a pin or placing V3 provenance under V4. Preserve historical audit JSON, archived reports, licenses and recorded deployment addresses. Instruction/skill updates remain a separate maintainer follow-up, not part of implementation scope.

## 8. Completion evidence and stop conditions

Deliver an implementation report next to this plan with:

- Exact modified paths and both source renames; no liquidation-body diffs.
- Actual toolchain, roots/settings and commands, including failed attempts, cached runs, skipped tests and total counts.
- Correct nonempty artifacts and fresh version-specific links under both roots and build orders.
- Expected-version library getter equality, real liquidation/deficit execution and wrong-source rejection.
- Full cross-version invariant and matrix/loader/planner outcomes. A setup-only pass does not close this change.
- Consumer ABI/storage and external-library selector comparison, runtime-size measurements and unexplained differences treated as blockers.
- Old/new source identities, CREATE3 identity salts, CREATE2 salt inputs, full initcode hashes and predicted-address impacts. Filename-only is not byte/address stability. Existing deployed consumers remain untouched and occupied identities are not upgrades.
- Seed retained, TestBase direct-bytecode dependency removed, unused bypass removed, generic safeguards preserved, operational strings/docs corrected.

Stop for review if another required override caller is found, roots require undocumented portability, source-correct refresh cannot resolve stale planner IDs, ABI/storage or economic behavior changes, linking selects the wrong version, or safety checks must be weakened to pass. Do not restore the bypass as an unreported workaround. Do not revert unrelated work or automatically reset the tree. No deployment follows completion.

## 9. Readiness review and evidence

Four retained researchers supplied new originals and each reviewed the other three originals once. All originals/cross-reviews are preserved under `docs/research/aave-liquidation-library-rename/round2-*.md`.

- Astra and Grok initially reported no blocking requirement questions.
- MiniMax and Kimi initially requested clarification of roots/emitter scope; cross-review resolved those from the existing PRD and BC docs. Both withdrew the blockers.
- Cross-review rejected planner-first bootstrap, fixture-as-test-root, script execution labelled compilation, destructive `--force`, unsupported inspection/subcommands, and bytecode-hash equality claims. This consolidated plan—not individual draft commands—controls the handoff.
- All four final positions: ready to plan, no outstanding owner requirement questions. These are retained-session continuations, not fresh independence from earlier discussion; Kimi's previously disclosed first-round exposure remains part of the record.

Sessions preserved: Astra `ses_ecf91a653ffe47eAXAzZldDbAN`; Grok `ses_ecf88e093ffeR9iQX7Zmio9H50`; MiniMax `ses_ecf7e4741ffeuHNTjMRSkuDlb7`; Kimi `ses_ecf74f427ffegvAnSL3wWcDKEe`.

Primary/local evidence accessed 2026-10-12: current PRD; `CLAUDE.md:47–61`; family PRD `prds/AaveV3V4CrossVersionCarryLoopVault.md`; canonical Crane testing/porting guidance; `BC_AAVE_V4_DEPLOY_STEPS.md:139–165`; planner `297–309,387–428`; moderator search confirming 21 concrete matrix consumers. Context7-first Foundry references: https://github.com/foundry-rs/book/blob/master/src/pages/reference/forge/build.mdx and https://github.com/foundry-rs/book/blob/master/src/pages/reference/forge/inspect.mdx (researchers verified inspection fields). Current documentation is not proof of an installed binary version.

Confidence is high in requirements/readiness and the corrected sequencing. Compiler/test outcomes, exact emitted placeholder, addresses and live deployment occupancy remain unverified. Consensus and passing tests would not by themselves prove security or economic soundness.

**Human checkpoint:** detailed plan delivered. Execute only after a separate explicit implementation request in an implementation-capable session.
