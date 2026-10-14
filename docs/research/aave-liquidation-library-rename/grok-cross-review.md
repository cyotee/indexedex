# Grok cross-review: Aave LiquidationLogic rename

- Reviewer: Grok (`xai/grok-4.7`)
- Date: 2026-10-12
- Inputs: own original `grok-original.md` (unchanged) plus untrusted originals `astra-original.md`, `minimax-original.md`, `kimi-original.md`. No cross-review files read. No builds, tests, or source edits.
- This is not consensus and not proof of security or economic soundness.

## Kept from Grok original

Filename-only remains the default: `LiquidationLogicAaveV3.sol` and `LiquidationLogicAaveV4.sol`, library symbol `LiquidationLogic` kept in both. `AaveV3` means the v3.6 tree. Do not delete `CraneFactoryArtifactSeed.sol`. Do not delete `out/` or `cache_forge/`. Do not enable `via_ir`. The creation-code bypass to remove is the 4-arg `ArtifactCreationCode` call in `TestBase_AaveCrossVersionLoopV4Market.sol`, not the seed file. CREATE3 library salt is `abi.encode(source:name)._hash()`, so a filename change changes that salt even if the symbol stays. Placeholder identity is `path:LibraryName`, not the filename alone.

## Corrections to Grok original

1. **Symbol rename is not selector-neutral for V4.** Original said library selectors stay if signatures stay. That is wrong for `liquidateUser`. Solidity 0.8.35 `docs/contracts/libraries.rst`, section "Function Signatures and Selectors in Libraries", fetched 2026-10-12 from `https://raw.githubusercontent.com/argotorg/solidity/v0.8.35/docs/contracts/libraries.rst`: non-storage structs are named by their fully qualified name (`C.S`). V4 `LiquidateUserParams` is declared inside `library LiquidationLogic` (lines 35–45) and is a memory argument of external `liquidateUser` (lines 197–210). Renaming the library symbol changes that selector. Import aliases do not preserve the declaration's canonical type name. V3 `executeLiquidationCall` / `executeEliminateDeficit` take `DataTypes` structs, so this particular effect is not apparent there. Astra §4 and Kimi §6 stated this; Grok now accepts it. Pool/Spoke `getLiquidationLogic()` selectors are still unchanged under either option.

2. **IndexedEx short-path occupant is unstable.** Original, from a first-pass read, recorded `out/LiquidationLogic.sol/LiquidationLogic.json` as V4 (`DUST_LIQUIDATION_THRESHOLD`, `calculateLiquidationBonus`) and `out/logic/...` as V3.6. A cross-review re-read of the same IndexedEx paths shows **both** now start with V3.6 getters (`CLOSE_FACTOR_HF_THRESHOLD`). Crane `lib/crane/out/LiquidationLogic.sol/LiquidationLogic.json` still starts with V4 `DUST_LIQUIDATION_THRESHOLD`. The writer of the IndexedEx change was not identified. This does not prove Foundry's general rule is last-write-wins, but it withdraws the original's "current checkout shows V4 owns the IndexedEx short path" as a stable fact. Kimi §3.4 matches the later IndexedEx state. Original crane-root observation still matches this re-read.

3. **Test gate was too thin.** Confirmed this pass: `TestBase_AaveCrossVersionLoopV3Market.sol` line 35 inherits `TestBase_AaveCrossVersionLoopV4Market`. A V3-only market test still runs the V4 setup and the bypass. Astra's demand for the cross-version family, an actual liquidation/deficit path, and rejection of a nonzero `getLiquidationLogic()` check (`Pool.t.sol` lines 654–655) is accepted. `echidna_config.yaml` lines 52 and 62 bind the symbol `LiquidationLogic` to `0xf06`. Filename-only leaves that binding valid; symbol rename must update it. Grok missed that file.

4. **`--force` should be forbidden in the recipe.** Original forbade cache deletion but did not name `--force`. MiniMax acceptance items 6–7 require `forge build --force`. That fights the warm shared cache in `CLAUDE.md` lines 47–59 and `ARTIFACT_BUILDS.md`. Do not use `--force` or delete `out/` / `cache_forge/` as the migration method.

5. **Do not preserve the upstream `src/spoke/` dialect as a live emitter.** Original said keep all three dialects and only change the filename. `src/spoke/libraries/LiquidationLogic.sol` is not a Crane or IndexedEx source unit (`SpokeDeployUtils.sol` line 30; v4 `deployments/README.md` line 50). Updating the basename inside that string still emits a linker key neither root will resolve. Crane-root output should be `contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic`. IndexedEx loader IDs should stay `lib/crane/...`. Those two are both valid and must not be collapsed into each other. Astra's "fix source identity for the supported root" is accepted for the `src/` dialect only.

## Agreements

- Astra, Kimi, and Grok: suffix spelling `LiquidationLogicAaveV3.sol` / `LiquidationLogicAaveV4.sol`; filename-only default; keep the symbol unless an owner explicitly accepts the V4 `liquidateUser` selector break.
- Astra, Kimi, and Grok: seed file stays; update its import and the false overwrite NatSpec. The bypass is the TestBase 4-arg call plus the matching overload. `AaveV3LibrariesBatch2` `type(...).creationCode` is real CREATE2 deployment code, not the workaround to delete.
- Astra, Kimi, and Grok: filename-only still changes metadata, link placeholders, CREATE3 source-qualified salts, and new CREATE2 addresses. Do not promise bytecode or address preservation. Economics, Pool/Spoke storage, and Pool/Spoke getter selectors can be preserved if bodies are not edited.
- Astra and Grok: planner `library_artifacts` can fail on stale `linkReferences` before the new file builds. Rebuild dependents. Do not ignore unresolved libraries and do not delete caches.
- Kimi H1, re-checked this pass: `WadRayMath.sol`, `PercentageMath.sol`, and `MathUtils.sol` exist in both v3.6 and v4 math trees. Same basename class. Out of scope for this rename. Linking impact of those three was not re-read.

## Objections

### MiniMax

- **Suffix spelling rejected.** MiniMax §4 uses prefixes `AaveV3LiquidationLogic.sol` / `AaveV4LiquidationLogic.sol`. The user asked for suffixes. MiniMax also writes a nonexistent v4 path `.../libraries/libraries/AaveV4LiquidationLogic.sol`.
- **Workaround location overstated.** MiniMax §2 says the user's Artifact Seed "is unambiguously" `CraneFactoryArtifactSeed.sol` and that the seed is the collision workaround. The seed is the compile root the user may have meant by that name. The direct creation-code workaround is the TestBase 4-arg call. Treating them as the same object leads MiniMax §12.2 to call the seed "removable" and "superfluous". The seed also compiles Hub, Spoke, facets, and factories. `CLAUDE.md` line 61 forbids deleting it. Commenting out only the LiquidationLogic import is a later optional cleanup, not an acceptance gate, and must not be done by deleting the file.
- **Bytecode-stability claim rejected.** MiniMax §7 and §10 say Option A leaves library bytecode, library address, and Spoke bytecode identical, and that existing deployments need no migration because the address stays. Solidity metadata docs, accepted by Astra, Kimi, and Grok, say a path change can change bytecode. CREATE3 salt includes the source path. CREATE2 salt `bytes32(0)` stays, but the address changes because initcode changes. MiniMax's placeholder formula (`keccak256(source_path)` only) omits `:LibraryName`.
- **Artifact filename inconsistency.** MiniMax acceptance item 1 looks for `out/AaveV3LiquidationLogic.sol/AaveV3LiquidationLogic.json` while Option A keeps the symbol `LiquidationLogic`. Foundry's contract file is `<symbol>.json`. Under filename-only the expected paths are `out/LiquidationLogicAaveV3.sol/LiquidationLogic.json` and `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json`.
- **`--force` rejected.** See correction 4.
- **Import-path denial.** MiniMax §4 says Option A `type(LiquidationLogic).creationCode` keeps working with no other source edit. The import path still must change. The TestBase call should be removed, not left compiling against the old path.

### Astra

No objection to the selector, salt, seed, or warm-cache points. Two limits: Astra did not inspect `out/`, so the occupant-change evidence is Grok/Kimi, not Astra. Astra's SeMatrix and product-PRD citations were not re-read in this pass; treat those suite names as peer inventory until an implementer confirms the match paths. Do not adopt Astra's "both version orders" build gate if it requires `--force` or cache deletion. A normal build of both libraries together, plus a dependent rebuild, is the allowed check.

### Kimi

Kimi's filename-only recommendation, seed retention, selector citation, and `src/` dialect note agree with the corrected Grok position. Kimi's IndexedEx `out/` description matches the cross-review re-read, not Grok's first-pass read. That is a timing difference, not a reason to discard either observation.

**Independence limitation:** Kimi §10 discloses that repo-wide grep printed lines from `astra-original.md`, `minimax-original.md`, and `grok-original.md`. Kimi says those files were not opened and that two leaked claims were not used: MiniMax's byte-stability claim, which Kimi correctly rejects, and the V4 selector rule, which Kimi says was confirmed from Solidity docs. The selector rule is now independently confirmed by Grok from the 0.8.35 rst. Kimi's pass is **not** a clean independent original. Overlap with Grok or Astra is not a fourth independent vote. Weight Kimi where a primary source or a file Grok re-read supports the sentence. Do not treat four-author agreement as uncontaminated consensus.

## Recommendations

1. Approve filename-only suffixes `LiquidationLogicAaveV3.sol` and `LiquidationLogicAaveV4.sol`. Reject MiniMax prefixes. Do not approve symbol rename unless the owner explicitly accepts a new V4 `liquidateUser` selector and a matched Spoke rebuild. V3 external selectors are not the same risk.
2. Remove the TestBase 4-arg bypass and, after a caller check, the 4-arg overload. Keep generic artifact loading, source matching, recursive linking, and `releaseSalt`. Keep `CraneFactoryArtifactSeed.sol`; update the v4 import and the overwrite comment. Do not make seed deletion an acceptance test.
3. Recompute `LIQUIDATION_LOGIC_PLACEHOLDER` from a real compile of the Crane-root source unit `contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic`. Do not hand-write the hash. IndexedEx linking uses JSON offsets and the `lib/crane/...` ID, not that constant.
4. Stop emitting `src/spoke/...` from Crane/IndexedEx scripts. Keep Crane `contracts/...` and IndexedEx `lib/crane/...` as separate valid dialects.
5. Migration: no `rm` of `out/` or `cache_forge/`, no `forge build --force`. Rebuild renamed libraries and concrete dependents (`Pool`, `Spoke`/`SpokeInstance`, seed if the planner excludes it). Stale link IDs must fail closed.
6. Tests must include: Crane V3 liquidation and deficit paths, V4 liquidation/getter suites, IndexedEx loader suite, and cross-version tests that inherit the V4 market base, including `TestBase_AaveCrossVersionLoopV3Market`. Assert each `getLiquidationLogic()` equals the deployment of the correct version and that the two library addresses differ. A nonzero getter is not enough. Echidna yaml changes only if the symbol is renamed.
7. Record old/new source IDs, salts, initcode hashes, and predicted addresses before any later deploy. Do not claim existing Pool/Spoke instances are upgraded.

## Unresolved dissent

- Whether the IndexedEx short-path flip was a Foundry incremental overwrite or some other writer. Mechanism still not reproduced by a controlled build.
- Whether to fix `SpokeDeployUtils.getLibraryString` in this change or only stop treating `src/spoke/` as canonical. Grok now says do not leave it as a live emitter. That is a small behavior fix, not a pure rename.
- Symbol rename remains an owner choice, not a researcher default. MiniMax still presents prefix filename-only as viable. Astra, Kimi, and corrected Grok reject that spelling and reject calling symbol rename ABI-neutral.
- Kimi cannot be counted as an independent confirmer of claims that appeared in grep leakage. Primary-source points Kimi also fetched (metadata, library selectors) can still be used.
- Duplicate math-library basenames are real and unscoped. No agreement to rename them here.
- No chain occupancy evidence. Address tables are predictions, not a migration plan.
