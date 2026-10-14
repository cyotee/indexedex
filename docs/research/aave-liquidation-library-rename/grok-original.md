# Grok original findings: Aave LiquidationLogic filename disambiguation

- Researcher: Grok (`xai/grok-4.7`), independent first pass
- Date: 2026-10-12
- Scope: inventory and implementation PRD only. No source edits, builds, tests, or moves were performed.
- Checkout: `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex`
- Decision recommended below: **filename-only rename**. Keep the Solidity library identifier `LiquidationLogic` in both versions.

## Question

Rename Crane Aave v3.6 and v4 `LiquidationLogic.sol` files with `AaveV3` / `AaveV4` suffixes, update imports and references across Crane and IndexedEx to the correct version, and remove the direct creation-code workaround the user calls Artifact Seed. Verify that name. Preserve economics, storage, and ABI where possible. Assess filename-only versus symbol rename, including artifact IDs, link placeholders, build scripts, docs, tests, and salt/address impact.

Prior chat claims that one artifact overwrites the other are untrusted hypotheses. This pass treats in-repo comments the same way until checked against compiler source and the current `out/` tree.

## Assumptions

1. "Suffix" means the version token follows `LiquidationLogic`, not a prefix: `LiquidationLogicAaveV3.sol` and `LiquidationLogicAaveV4.sol`.
2. `AaveV3` labels the existing **v3.6** tree. No separate non-3.6 `LiquidationLogic.sol` was found. The suffix must not be read as a port of an older Aave v3 tag.
3. Installed `forge` binary version was not queried. Artifact-path behavior is taken from `foundry-compilers` tag `v0.19.6`, which `docs/testing/ARTIFACT_BUILDS.md` line 26 cites together with Forge 1.5.1. Repo `solc` is `0.8.35` (`foundry.toml` lines 29 and 67; Crane `lib/crane/foundry.toml` line 31).
4. No broadcast logs or chain state were inspected. Address impact below is formula analysis, not a claim about a live deployment.

## Facts

### Two libraries, same filename and same symbol

| Version | Path | Declaration | Pragma | SPDX |
| --- | --- | --- | --- | --- |
| v3.6 | `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol` | `library LiquidationLogic` line 29 | `^0.8.10` line 2 | BSL-1.1 line 1 |
| v4 | `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol` | `library LiquidationLogic` line 24 | `^0.8.20` line 2 | LicenseRef-BUSL line 1 |

No other `library LiquidationLogic` or `contract LiquidationLogic` declaration was found. `LiquidationLogicWrapper` is a test contract, not a third copy.

Neither file declares `event` or `error`. Both take `storage` arguments and run by `DELEGATECALL` into the caller. They do not own Pool or Spoke storage.

Both are **external** libraries, not internal-only inlines:

- v3.6 `executeEliminateDeficit` is `external` (lines 77–81). `executeLiquidationCall` is `external` (lines 162–168). Public constants `CLOSE_FACTOR_HF_THRESHOLD` (line 50), `MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD` (line 57), and `MIN_LEFTOVER_BASE` (line 65) appear as getters in the compiled v3.6 artifact ABI. `DEFAULT_LIQUIDATION_CLOSE_FACTOR` is `internal` (line 44).
- v4 `liquidateUser` is `external` (lines 197–210). `notifyReportDeficit` is `external` (lines 265–276). `calculateLiquidationBonus` is `public` (lines 313–318). Public constants `HEALTH_FACTOR_LIQUIDATION_THRESHOLD` (line 185) and `DUST_LIQUIDATION_THRESHOLD` (line 188) appear as getters in the compiled v4 artifact ABI.
- Confirmed internal example: v3.6 `_burnCollateralATokens` (line 400); v4 `_validateLiquidationCall` (line 514). A full visibility census of every helper was not re-read. The external/public functions above are sufficient to force solc library linking.

Callers that embed the library address:

- v3.6 `Pool.getLiquidationLogic()` returns `address(LiquidationLogic)` (`Pool.sol` lines 867–868). Interface `IPool.getLiquidationLogic()` is `external view` (`IPool.sol` lines 801–804). The implementation is `external pure`. That view/pure mismatch is pre-existing and is not part of this rename. The selector is `getLiquidationLogic()` either way.
- v4 `Spoke.getLiquidationLogic()` returns `address(LiquidationLogic)` (`Spoke.sol` lines 640–641). `ISpoke.getLiquidationLogic()` is `external pure` (`ISpoke.sol` lines 730–731).

Qualified uses that must keep calling the v3.6 body: `Pool.sol` lines 312 and 768; `LiquidationDataProvider.sol` lines 202–212 and 302–307; `LiquidationHelper.sol` line 61; `Pool.Liquidations.CloseFactor.t.sol` constant reads.

Qualified uses that must keep calling the v4 body: `Spoke.sol` lines 87, 91, 354, 366, 376, 621, 641; `LiquidationLogicWrapper.sol` throughout; v4 unit tests that name `LiquidationLogic.*` structs.

These are different liquidation engines. `lib/crane/.claude/skills/aave-v4-liquidation/SKILL.md` documents v4 target health factor and variable bonus versus v3 close factor. Do not merge bodies, constants, or structs.

### Artifact collision is real; the current short path is v4, not a proven v3.6 overwrite

`foundry-compilers` `v0.19.6` `crates/compilers/src/artifact_output/mod.rs`, fetched 2026-10-12 from `https://raw.githubusercontent.com/foundry-rs/compilers/v0.19.6/crates/compilers/src/artifact_output/mod.rs`:

- `output_file` joins the source **file name** with `<contract>.json`. Both libraries therefore default to `out/LiquidationLogic.sol/LiquidationLogic.json`.
- `get_artifact_path` reuses a cached path for that source when one exists. Otherwise, if the default path is already in the in-memory taken set, `conflict_free_output_file` prefixes parent directory names until the path is unique.
- Files are sorted by path-component count, shortest first, so the shorter source wins the short artifact path in a single output pass.
- `ArtifactFile::write` writes that chosen path. A later compile that does not see the other artifact as taken can select the same default path and overwrite the file. That last step is an inference from the taken-set being cache/output-pass state, not a directory lock. It was **not** reproduced by running `forge`.

Path component counts under IndexedEx:

- v4: `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol` — 10 components
- v3.6: `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol` — 11 components

Observed `out/` on 2026-10-12, identified by ABI names because each JSON is one line and `compilationTarget` could not be extracted by the line reader:

| Artifact | ABI identity | Inference |
| --- | --- | --- |
| `out/LiquidationLogic.sol/LiquidationLogic.json` | `DUST_LIQUIDATION_THRESHOLD`, `HEALTH_FACTOR_LIQUIDATION_THRESHOLD`, `calculateLiquidationBonus` | v4 owns the short path |
| `out/logic/LiquidationLogic.sol/LiquidationLogic.json` | `CLOSE_FACTOR_HF_THRESHOLD`, `MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD`, `MIN_LEFTOVER_BASE` | v3.6 is at the parent-dir suffix `logic/` |
| `lib/crane/out/LiquidationLogic.sol/LiquidationLogic.json` | same v4 getter names | Crane-root short path is also v4 |
| `lib/crane/out/logic/LiquidationLogic.sol/LiquidationLogic.json` | same v3.6 getter names | Crane-root also disambiguated v3.6 under `logic/` |

In-repo comments that say v3.6 overwrites or "steals" `out/LiquidationLogic.sol/` are **not** what this checkout's `out/` shows:

- `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` lines 35–37
- `contracts/utils/foundry/ArtifactCreationCode.sol` lines 42–45
- `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol` lines 81–82

Those comments are evidence of an intended workaround and of a real shared short path. They are not validated evidence that v3.6 currently occupies that path. The collision remains: one short slot, one disambiguated slot, and a later compile can still move who owns the short slot. `vm.getCode("LiquidationLogic.sol:LiquidationLogic")` and any loader that stops at the first existing `out/LiquidationLogic.sol/LiquidationLogic.json` bind whichever version last won that slot.

`ArtifactCreationCode._artifactJson` (lines 169–181) walks source-path suffixes and, for a full source ID, checks `metadata.settings.compilationTarget` (lines 186–192). A short ID does not do that check. That is why a qualified ID can be safe when the disambiguated file exists, and why a short ID is not.

### What "Artifact Seed" actually is

`CraneFactoryArtifactSeed` is **not** the creation-code workaround.

- File: `contracts/utils/foundry/CraneFactoryArtifactSeed.sol`
- It is a `src` compile root. It imports v4 `LiquidationLogic` (line 28) and mentions `type(LiquidationLogic).name` (line 59) so a build of the seed can emit the library artifact.
- Its own NatSpec says that mention does not keep the artifact because of the shared filename.
- `CLAUDE.md` line 61 and `docs/testing/ARTIFACT_BUILDS.md` line 55 forbid deleting this file. `scripts/forge-artifacts.py` lines 39–44 treat any filename containing `ArtifactSeed` as a non-source helper, so a changed-source plan does not select it as an independent root unless a runtime artifact reference pulls it in. `--all-artifacts` does include `contracts/` (`forge-artifacts.py` lines 228–232).
- Nothing in `contracts/` except the seed and the test base names `SpokeInstance` / this library. IndexedEx production FactoryServices searched under `contracts/` do not deploy this library themselves.

The **direct creation-code workaround** is:

1. `TestBase_AaveCrossVersionLoopV4Market.sol` lines 15 and 81–88. It imports v4 `LiquidationLogic` only to pass `type(LiquidationLogic).creationCode` into the linker, with library ID `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic`.
2. `ArtifactCreationCode.creationCode(factory, artifactId, libraryId, libraryCreationCode)` lines 42–53 and the match at lines 126–129. If the supplied ID hashes equal to a link-reference ID and the bytes are non-empty, those bytes replace artifact lookup for that one library.

`test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol` exercises the 1-arg and 2-arg overloads (for example lines 34, 57, 61, 133, 144). No other Solidity caller of the 4-arg overload was found. The 4-arg overload exists for this bypass.

`type(LiquidationLogic).creationCode` is the compiler's creation code for the imported v4 library. It does not read `out/LiquidationLogic.sol/`. That is why the bypass survives a stolen short artifact. It also pulls the implementation import back into a test base, which `ARTIFACT_BUILDS.md` lines 3 and 64–65 say deployment helpers should avoid when artifact JSON is sufficient.

### Three path dialects already exist

Remappings, read 2026-10-12:

- IndexedEx `remappings.txt` line 3: `@crane/=lib/crane/`
- Crane `lib/crane/remappings.txt` lines 3–4: `@crane/contracts/=contracts/` and `@crane/test/=test/`

So the same `@crane/contracts/.../LiquidationLogic.sol` import is a different solc source-unit name in each Foundry project. Solidity 0.8.37 docs, accessed 2026-10-12, `https://docs.soliditylang.org/en/v0.8.37/using-the-compiler.html` section Library Linking: the placeholder is a 34-character prefix of the hex encoding of `keccak256` of the fully qualified library name `path:LibraryName`. Metadata `compilationTarget` includes that path, and the metadata hash is appended to bytecode (`https://docs.soliditylang.org/en/v0.8.37/metadata.html`). Repo compiler is 0.8.35; the placeholder format documented for 0.8.37 is the post-0.5.0 hash form, not the pre-0.5.0 raw-name form. This pass did not recompute any hash.

Live string dialects that must stay consistent with the compiler that consumes them:

| Dialect | Example today | Where |
| --- | --- | --- |
| IndexedEx source unit | `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic` | `TestBase_AaveCrossVersionLoopV4Market.sol` line 86 |
| Crane source unit | `contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic` | `SpokeBytecodeLinker.sol` lines 21 and 37; `BC_AAVE_V4_DEPLOY_STEPS.md` lines 142 and 164 |
| Upstream-style `src/` path | `src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic` | `SpokeDeployUtils.sol` line 30; v4 `deployments/README.md` line 50 |
| Crane `vm.getCode` path that does not match the IndexedEx remapping | `contracts/protocols/.../LiquidationLogic.sol:LiquidationLogic` | `SpokeDeployUtils.sol` line 22 |

`SpokeBytecodeLinker` also hardcodes placeholder `__$329ad157ba4e68d2f4f45d82720084bf07$__` (line 15). That constant is only valid for the fully qualified name of the compilation that produced it. A filename change changes the path component of that name, so the constant becomes wrong even if the library symbol stays `LiquidationLogic`. IndexedEx `ArtifactCreationCode` patches by JSON `linkReferences` offsets (lines 114–150), not by this constant. Do not copy the Crane placeholder into IndexedEx linking.

`FOUNDRY_LIBRARIES` must use the source-unit name of the `forge` invocation that recompiles `Spoke`. A string that is correct for Crane-root `contracts/...` is not automatically correct for an IndexedEx-root build of `lib/crane/...`. Which root actually runs `Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol` was not executed here.

### Salt and address formulas

These are different deployment systems. A filename change does not move storage inside an already deployed Pool or Spoke. It does change **new** library addresses.

1. IndexedEx artifact linker, `ArtifactCreationCode.sol` lines 126–131. Library salt is `abi.encode(source + ":" + name)._hash()` via `BetterEfficientHashLib`. Creation bytecode is the payload, not the salt (`ARTIFACT_BUILDS.md` lines 68–69; `releaseSalt` lines 55–64 returns the namespace unchanged). A filename change changes `source`, therefore the CREATE3 salt, therefore the CREATE3 address. An old identity that already has code is reused rather than upgraded (lines 36–37 and 131–132). New Spoke linking must use the new ID. Callers that keep the old ID will not find the renamed artifact.
2. v4 Crane linker, `SpokeBytecodeLinker.sol` lines 17–30. `LIQUIDATION_LOGIC_SALT` is `bytes32(0)`. Address is CREATE2 of salt 0 and `keccak256(initcode)`. Filename change changes metadata in initcode, so the CREATE2 address changes. `Create2Utils.create2DeployOrGet` (v4 `Create2Utils.sol` lines 113–118) returns an address only if **that computed address** already has code. It will not return the old library, because the old library's initcode hash differs. `create2Deploy` reverts if the new address is occupied (`ContractAlreadyDeployed`, lines 101–104).
3. v3.6 batch, `AaveV3LibrariesBatch2.sol` lines 27–30. One salt, `bytes("AAVE_V3_LIBRARIES_BATCH")._hash()`, is used for FlashLoanLogic, LiquidationLogic, PoolLogic, and SupplyLogic. CREATE2 addresses differ because initcode differs. v3.6 `Create2Utils._create2Deploy` (lines 68–82) likewise keys off `keccak256(bytecode)`. Renaming only the liquidation file changes only that library's initcode and address. The other three libraries stay put if their sources are untouched. New Pool bytecode must be relinked to the new library address. Already linked Pool instances keep the old embedded address and the old library code.

v4 test market salt in `TestBase_AaveCrossVersionLoopV4Market.sol` line 94 is `keccak256(abi.encode("indexedex.aave.cross-version.v4", address(this)))`. That string does not include the library name. Spoke CREATE2 address still changes if linked bytecode changes, because CREATE2 hashes the whole initcode. That is test-address movement, not a Pool/Spoke storage migration.

`via_ir` is not the reason linking exists. IndexedEx `foundry.toml` lines 35–36 and 72 set `via_ir = false`. Crane `foundry.toml` line 37 sets `viaIR = false`. `SpokeDeployUtils.sol` lines 9–10 say SpokeInstance is compiled with via-ir. That comment disagrees with both current profiles. Linking is required because the library has external functions (v4 deployments README lines 41–43). Do not enable `via_ir` to "fix" this rename.

### Import and reference inventory

Library source imports that break if the file is renamed and the import path is not:

| File | Line | Version |
| --- | --- | --- |
| `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol` | 13 | v3.6 relative `../libraries/logic/LiquidationLogic.sol` |
| `lib/crane/contracts/protocols/lending/aave/v3.6/helpers/LiquidationDataProvider.sol` | 12 | v3.6 relative |
| `lib/crane/contracts/protocols/lending/aave/v3.6/deployments/projects/aave-v3-libraries/AaveV3LibrariesBatch2.sol` | 11–13 | v3.6 |
| `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/helpers/LiquidationHelper.sol` | 7–8 | v3.6 |
| `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.Liquidations.CloseFactor.t.sol` | 31–32 | v3.6 |
| `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.Liquidations.t.sol` | 35–36 | v3.6 import; no other `LiquidationLogic` token found in that file |
| `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/L2Pool.t.sol` | 14–16 | v3.6 import; no other `LiquidationLogic` token found |
| `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol` | 21 | v4 |
| `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` | 28 | v4 |
| `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol` | 15 | v4; remove with the bypass, do not retarget it |
| `lib/crane/test/foundry/spec/protocols/lending/aave/v4/helpers/mocks/LiquidationLogicWrapper.sol` | 10 | v4 |
| `lib/crane/test/foundry/spec/protocols/lending/aave/v4/setup/Base.t.sol` | 85 | v4 import; no other token in that file. Child tests still name `LiquidationLogic.*` |

v4 unit tests import `LiquidationLogic.Base.t.sol`, not the library file. They still use the symbol (`LiquidationLogic.Base.t.sol` line 35; `LiquidationLogic.LiquidateDebt.t.sol` lines 110–111; `LiquidationLogic.LiquidationAmounts.t.sol` has `using LiquidationLogic for uint256`). Solidity does not re-export a parent's imports. This pass did not compile those tests, so it does not claim they fail today. Filename-only rename does not require editing those symbol uses if they already resolve. If a compile then reports an undeclared identifier, add an explicit import of the renamed **file** while keeping the symbol `LiquidationLogic`. Do not rename the test files.

Test filenames such as `LiquidationLogic.Base.t.sol` do not share the artifact directory `LiquidationLogic.sol`. Foundry's `output_file` uses the full file name. Renaming those tests is out of scope and would churn imports for no collision fix.

Artifact ID and linker strings:

- `SpokeBytecodeLinker.sol` lines 15, 21, 37
- `SpokeDeployUtils.sol` lines 22, 30, and the `.env` regex at line 79 (`LiquidationLogic:`). Filename-only keeps that regex working. A symbol rename to `LiquidationLogicAaveV4` would make `LiquidationLogic:` fail to match `LiquidationLogicAaveV4:`.
- `TestBase_AaveCrossVersionLoopV4Market.sol` line 86, deleted with the bypass rather than rewritten, if the 2-arg linker is used
- `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md` lines 142 and 164
- `lib/crane/contracts/protocols/lending/aave/v4/deployments/README.md` line 50

Scripts that call the linker but do not embed the path: `lib/crane/scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol` line 23; `BcAavePhase3Deploy.sol` lines 111–116 and 152. They need no path edit if `SpokeBytecodeLinker` is updated. Comments that name the file should be updated so operators do not export the old `FOUNDRY_LIBRARIES` value.

`scripts/forge-artifacts.py`:

- Literal artifact IDs match `File.sol:Contract` (line 22).
- `resolve_artifact` (lines 157–170) errors if a basename maps to more than one source that declares that contract name. Today `LiquidationLogic.sol:LiquidationLogic` is ambiguous. After a filename-only rename, `LiquidationLogicAaveV4.sol:LiquidationLogic` is unique even though the symbol is unchanged. `LiquidationLogic` **without** a file is still ambiguous, because both declarations keep that name. Current linker callers are path-qualified. Do not add new name-only `vm.getCode("LiquidationLogic")` calls.
- `library_artifacts` (lines 198–212) reads **existing** `bytecode.linkReferences` and queues those IDs. `plan` then calls strict `resolve_artifact` (lines 240–253). After the old file is gone, a stale `SpokeInstance.json` or `Pool` artifact can still name `.../LiquidationLogic.sol:LiquidationLogic` and fail planning before the replacement build. This is a code-derived migration hazard, not a reproduced failure. Do not delete `out/` or `cache_forge/` to clear it (`CLAUDE.md` lines 47–59). Rebuild the concrete dependents so their artifacts record the new link IDs.

Docs that mention the symbol but not the colliding filename can stay if the symbol stays: `lib/crane/docs/protocols/lending.md`, `lib/crane/docs/development/testing.md`, and the aave-v4-liquidation skill example `library LiquidationLogic`. Archive `lib/crane/docs/archive/internal-plans/AAVE_DEPS_INVENTORY.md` is historical; do not rewrite it as current law. Operational deploy docs listed above must change because they contain `FOUNDRY_LIBRARIES` paths.

JSON under `implementation-artifacts/` and `docs/audits/` contains old paths. Those are recorded build identities, not compile inputs. Do not rewrite audit evidence to pretend the rename already happened.

No other `LiquidationLogic.sol` basename collision was sought across the whole Aave trees. That scan is missing. This PRD does not authorize renaming other shared names (`MathUtils.sol`, `PercentageMath.sol`, and similar) even if a later scan finds the same class of bug.

## Inference

Filename-only rename is sufficient to remove the Foundry short-path collision. `output_file` keys off the file name, not the library identifier. After the rename the default artifacts are:

- `out/LiquidationLogicAaveV3.sol/LiquidationLogic.json`
- `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json`

Those paths do not conflict. Parent-dir suffixes and the short-slot race go away for this pair. The library symbol, function selectors, event signatures, struct layouts, and `type(LiquidationLogic).name` stay. `address(LiquidationLogic)` remains a link placeholder, not a literal address.

Symbol rename is not required for compilation. No file imports both libraries. It would change `type().name`, every qualified call, the artifact contract name, metadata, and the `.env` regex. It would diverge further from upstream Aave, which `crane-porting` says not to mutate for domain logic. It would still not be byte-identical to upstream, because a filename change already changes `compilationTarget` and therefore bytecode metadata.

Bytecode identity with upstream and with previously deployed libraries is **not** preserved by either option. Executed opcodes can still match if the only bytecode delta is the CBOR metadata suffix and, for dependents, the link placeholder. That opcode claim is not proven until a compiler diff strips metadata. Selectors and storage layouts can be preserved without that diff if function signatures and struct fields are not edited.

`getLiquidationLogic()` ABI on Pool and Spoke is preserved under filename-only. The address it returns on a **new** deployment changes. Existing deployments keep their embedded library address until those contracts are redeployed and relinked. There is no storage slot to migrate inside the libraries.

The creation-code bypass can be removed after the v4 file name is unique and `SpokeInstance` is rebuilt so its `linkReferences` name the new source unit. The 2-arg `ArtifactCreationCode.creationCode(factory, spokeArtifactId)` then deploys the library from `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json` instead of from `type().creationCode`. The seed file stays. Its import path must change so a seed build emits the unique artifact. Its NatSpec that says the import cannot keep the artifact becomes false after the filename split and should be corrected, not left as an instruction to keep the bypass.

## Speculation

- A later v3.6-only compile can still overwrite today's v4 short artifact if that compile does not see the v4 path as taken. The algorithm allows it. This checkout does not currently show that overwrite.
- No IndexedEx production FactoryService deploys these libraries. The search was `contracts/**/*.sol` for `SpokeInstance`, `SpokeBytecodeLinker`, and `AaveV3LibrariesBatch2`. A script outside that pattern could still deploy them.
- v4 unit tests may already fail to see `LiquidationLogic` through `Base.t.sol`, or the compiler may accept them for a reason not found here. Do not "fix" that by renaming the symbol.

## Counterarguments

1. Rename the symbol too, because `vm.getCode("LiquidationLogic")` stays ambiguous. Rejected as the default. Current callers are path-qualified. Name-only lookup is a new bug if someone adds it. Symbol rename has a larger miss risk (`LiquidationLogic.*` structs in the v4 tests) and breaks the `.env` regex. If a later requirement is name-only cheatcodes, do it as a separate change with aliases at the import (`import {LiquidationLogicAaveV4 as LiquidationLogic}`) only where call sites must stay stable — and note that `type().name` would still change.
2. Keep the creation-code bypass as defense in depth. Rejected. It reintroduces an implementation import into the test base and hardcodes one library's creation code beside a general linker. After unique filenames, a wrong artifact is a missing-file failure, which `ArtifactCreationCode` already reverts on (line 183), rather than a silent version mix.
3. Delete `CraneFactoryArtifactSeed.sol` because the user called the workaround Artifact Seed. Rejected. That file is the compile root `CLAUDE.md` line 61 says not to delete. The workaround is the 4-arg linker call.
4. Recompute and paste a new placeholder now. Rejected in this research pass. The hash depends on the source-unit path of a specific compiler invocation. Two dialects exist. A hand-computed hash would be an unverified constant, which is how the current linker got a constant that a filename change invalidates.

## Missing evidence

- Installed Forge version and an actual `forge build` after a simulated rename.
- `compilationTarget` strings inside the one-line artifact JSON.
- Whether BC scripts are invoked from IndexedEx root or Crane root, and therefore which `FOUNDRY_LIBRARIES` dialect is live.
- Broadcast or chain evidence of an already deployed salt-0 v4 library or `AAVE_V3_LIBRARIES_BATCH` liquidation library.
- A repo-wide basename collision scan for other v3.6/v4 pairs.
- Compiler proof that metadata-stripped runtime bytecode is unchanged.
- Compile status of v4 tests that use `LiquidationLogic.*` without a direct import.

## PRD

### Title

Disambiguate Crane Aave v3.6 and v4 LiquidationLogic artifacts by filename, then drop the creation-code bypass.

### Decision

Filename-only.

- Move `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol` to `LiquidationLogicAaveV3.sol` in the same directory.
- Move `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol` to `LiquidationLogicAaveV4.sol` in the same directory.
- Keep `library LiquidationLogic` in both files.
- Do not edit function bodies, constants, struct fields, storage layouts, or event/error signatures.
- Do not rename `LiquidationLogic.*.t.sol` test files, `LiquidationLogicWrapper`, or `getLiquidationLogic()`.
- Do not delete `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` or `ArtifactCreationCode.sol`.

### Non-goals

- Symbol rename, import aliases, or upstream byte-identity.
- Merging v3.6 and v4 math.
- Enabling `via_ir`.
- Deleting `out/` or `cache_forge/`.
- Rewriting audit JSON or archive plans.
- Renaming other duplicated Aave filenames.
- Migrating already deployed Pool/Spoke instances. New deploys get new library addresses. Old instances keep their linked library until an explicit redeploy.

### Implementation outline

1. Rename the two files. Update every import in the inventory to the matching version's new filename. Relative imports stay relative. `@crane/` imports stay `@crane/`.
2. Update path-qualified artifact IDs and `FOUNDRY_LIBRARIES` strings to the new filename, preserving each dialect's directory prefix (`lib/crane/...`, `contracts/...`, or `src/spoke/...`). Do not collapse dialects in this change. Add a one-line comment at each remaining dialect stating which Foundry root it matches.
3. Recompute `SpokeBytecodeLinker.LIQUIDATION_LOGIC_PLACEHOLDER` from the Crane-root fully qualified name `contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic` by compiling or by `keccak256` of that exact source-unit string, then take the 34-hex-character placeholder form documented by solc. Do not invent the hash in review. If a compile shows the source-unit name differs, the compile wins.
4. Remove the bypass:
   - Delete the `LiquidationLogic` import and the 4-arg `creationCode` call in `TestBase_AaveCrossVersionLoopV4Market.sol`. Pass Spoke bytecode through `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")` so link references come from the rebuilt artifact.
   - Remove the 4-arg overload and the "shared with Aave v3.6" comments in `ArtifactCreationCode.sol` if no caller remains.
   - Update `CraneFactoryArtifactSeed` import and NatSpec. State that the unique filename is what keeps the artifact, and that the seed must not be imported by FactoryServices, TestBases, or scripts (existing line 38).
5. Update operational docs: `BC_AAVE_V4_DEPLOY_STEPS.md` and v4 `deployments/README.md`. Leave archive inventories unchanged.
6. Refresh artifacts without deleting caches. Build the renamed libraries and concrete dependents that link them (`Pool`, `Spoke` / `SpokeInstance`, and the seed as an explicit source if the planner excludes it). Then run the artifact planner. If it fails on a stale `linkReferences` ID, rebuild those dependents; do not ignore unresolved libraries and do not delete `out/`.

### Acceptance criteria

1. Exactly one source file named `LiquidationLogicAaveV3.sol` and one named `LiquidationLogicAaveV4.sol`. No `LiquidationLogic.sol` remains under either Aave tree.
2. Both files still declare `library LiquidationLogic`. `git diff` of each file, ignoring the rename, shows no function, constant, or struct body change.
3. A build that includes both libraries writes both:
   - `out/LiquidationLogicAaveV3.sol/LiquidationLogic.json` with v3.6 ABI names `CLOSE_FACTOR_HF_THRESHOLD` and `executeLiquidationCall`
   - `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json` with v4 ABI names `DUST_LIQUIDATION_THRESHOLD` and `liquidateUser`
   Neither JSON's `compilationTarget` is the other file. `out/LiquidationLogic.sol/` is absent or, if a stale file remains because caches were not deleted, is not read by any updated caller.
4. `SpokeInstance` creation bytecode `linkReferences` name the new v4 source unit, not `LiquidationLogic.sol`. `Pool` creation bytecode link references name the new v3.6 source unit. Placeholders are either absent after linking or match the recomputed constant. No `__$329ad157ba4e68d2f4f45d82720084bf07$__` remains in source.
5. `TestBase_AaveCrossVersionLoopV4Market` does not import `LiquidationLogic` and does not pass `type(...).creationCode` for this library. `CraneFactoryArtifactSeed.sol` still exists and imports only the v4 filename.
6. `IPool.getLiquidationLogic` and `ISpoke.getLiquidationLogic` selectors are unchanged. No storage variable is added to either library, `Pool`, or `Spoke`.
7. v3.6 liquidation tests still read `LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD` and the v3.6 close-factor constants. v4 wrapper tests still call v4 `liquidateUser` / `calculateLiquidationBonus`. A test must fail if a v4 caller is pointed at the v3.6 file or the reverse.
8. New CREATE2 addresses differ from pre-rename initcode hashes. Document that; do not assert equality with old salt-0 or batch addresses. CREATE3 salts for the new source-qualified IDs differ from the old IDs. Occupied old IDs are not treated as upgrades.
9. `python3 scripts/forge-artifacts.py plan` on the renamed v4 file and on `TestBase_AaveCrossVersionLoopV4Market.sol` resolves a single source for the new artifact ID. It must not resolve `LiquidationLogic.sol:LiquidationLogic`.
10. `via_ir` remains false. No `out/` or `cache_forge/` deletion is part of the change.

### Validation not claimed here

This document does not claim the rename is safe on a live chain, that metadata-stripped bytecode matches, or that tests pass. Those are implementation gates. Consensus with other researchers would not supply that proof either.

## Confidence

| Claim | Confidence |
| --- | --- |
| Two source files, import inventory, and the real bypass location | High |
| Filename-only split matches `foundry-compilers` 0.19.6 `output_file` | High |
| Current `out/` short path is v4 and `out/logic/` is v3.6 | High for ABI identity; medium for `compilationTarget`, which was not extracted |
| v3.6 currently overwrites the short path | Low. Comments say so. Current artifacts do not. |
| Selectors and storage can be preserved if bodies are not edited | High |
| Executed economics unchanged after metadata-only bytecode delta | Medium until a metadata-stripped diff |
| No production IndexedEx deploy of these libraries | Medium. Search covered `contracts/` Solidity, not every script |
| Safe to remove the 4-arg overload after the call site is gone | High for source callers found; medium until the test suite compiles |

## Sources

- Solidity 0.8.37 library linking and metadata, accessed 2026-10-12: `https://docs.soliditylang.org/en/v0.8.37/using-the-compiler.html`, `https://docs.soliditylang.org/en/v0.8.37/contracts.html`, `https://docs.soliditylang.org/en/v0.8.37/metadata.html`
- `foundry-compilers` v0.19.6 `artifact_output/mod.rs`, accessed 2026-10-12: `https://raw.githubusercontent.com/foundry-rs/compilers/v0.19.6/crates/compilers/src/artifact_output/mod.rs`
- Context7 library IDs queried: `/foundry-rs/book`, `/websites/soliditylang_en_v0_8_37`
- Repo: `CLAUDE.md` lines 47–61; `docs/testing/ARTIFACT_BUILDS.md` lines 26–28 and 41–69; `foundry.toml`; `remappings.txt`; Crane `foundry.toml` and `remappings.txt`; skills `crane-deployment`, `crane-architecture`, `crane-porting`, `aave-v3`, `aave-v4`, `aave-v4-liquidation`
