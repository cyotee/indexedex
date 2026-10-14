# PRD — Version-qualified Aave liquidation-library filenames

- Date: 2026-10-12
- Status: filename-only scope approved by the human on 2026-10-12; ready for implementation planning. Not implemented; execution requires a separate request.
- Detailed plan: [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).
- Scope: Crane Aave v3.6 and v4 source identity, imports, linking, and IndexedEx artifact-workaround removal.
- Owner request: suffix both filenames with AaveV3/AaveV4, inventory consumers, restore artifact-based loading. No implementation in this session.
- Research record: [originals and cross-reviews](../../research/aave-liquidation-library-rename/).

## 1. Approved naming decision

Rename only the files, in their existing directories:

| Version | Current path, relative to IndexedEx | Proposed basename |
|---|---|---|
| Aave v3.6 | `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol` | `LiquidationLogicAaveV3.sol` |
| Aave v4 | `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol` | `LiquidationLogicAaveV4.sol` |

Keep `library LiquidationLogic` in both sources. These are different protocol implementations, not duplicate copies to merge. Keep every liquidation function body, constant, struct, visibility, license and pragma unchanged. Keep `getLiquidationLogic()`, test filenames, wrapper names, and version directories unchanged. No compatibility copy at the old filenames.

This removes the shared artifact basename without the much larger symbol migration. Expected default artifacts are `out/LiquidationLogicAaveV3.sol/LiquidationLogic.json` and `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json`; verify actual outputs and compilation targets, not merely existence.

Renaming declarations is deliberately excluded. V4's external `liquidateUser` takes library-local `LiquidateUserParams` (`v4/spoke/libraries/LiquidationLogic.sol:197–210`). Solidity library selectors use qualified names for non-storage structs, so renaming the library declaration can change that selector. This is not necessary to separate filenames.

## 2. Problem and evidence boundary

Both libraries currently have the same basename and declared symbol. The repository documents a failure loading the V4 source-qualified artifact during cross-version setup. Existing comments describe an overwrite; earlier conversation claimed a reproduction. This research round did not run or reproduce it.

Foundry compiler package v0.19.6 has duplicate-output disambiguation, including cached paths and parent-directory suffixes. Therefore do not describe every same-name compilation as an unconditional overwrite. Researchers reported different mutable `out/` contents at different times: Grok initially saw V4 in the short IndexedEx slot; Kimi and Grok's later reads reported V3 there. These are not an immutable trace proving which process wrote it. Build-order regression evidence remains required.

Distinct basenames remove this pair's shared default output path regardless of that unresolved chronology. They do not eliminate the need to build artifacts before tests, and do not fix unrelated duplicate names.

### Correct workaround location

- `contracts/utils/foundry/CraneFactoryArtifactSeed.sol:28,35–38,59` imports V4 and uses `type(LiquidationLogic).name`. It **does not supply creation code**.
- `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol:15,81–88` imports V4 and supplies `type(LiquidationLogic).creationCode` through a four-argument loader call.
- `contracts/utils/foundry/ArtifactCreationCode.sol:42–53,73–94,114–129` implements that explicit-library-bytecode bypass.

The requested removal means restoring ordinary artifact loading in the TestBase, removing unused bypass plumbing, and correcting the seed comment. The seed itself and its compilation role remain.

## 3. Controlling constraints

`CLAUDE.md:47–61` requires existing profiles, no via-IR, build-before-test, preserved `out/` and `cache_forge/`, and retention of the Crane seed. The older cache-deletion suggestion in Crane `crane-porting/SKILL.md:133` does not override those current consumer rules. No `forge clean`, `forge build --force`, blanket output deletion, or profile/config changes as a migration shortcut.

Preserve the product decisions in `prds/AaveV3V4CrossVersionCarryLoopVault.md:13–23,31–36,50–80`: separate version services, registry deployment, live accounting, per-version risk checks, and existing entry/exit economics. Crane porting law (`lib/crane/.claude/skills/crane-porting/SKILL.md:13–21`) requires faithful domain logic. Record the local filename deviation in maintained provenance documentation; do not claim upstream byte identity.

Configured compiler reported by source review: solc 0.8.35, optimizer runs 1, no via-IR. Artifact workflow documentation cites Forge 1.5.1 and compiler package 0.19.6. A later implementation must record actual executable versions rather than assuming these documented versions are installed.

## 4. Complete direct-import inventory found in this pass

The moderator re-ran a repository Solidity search and confirmed these 12 direct import sites. Line numbers describe the inspected pre-rename tree. Update the basename to the correct version; remove the TestBase implementation import instead of retargeting it. Follow current canonical import style for edited imports without sweeping unrelated dependencies.

| Version | Importer relative to IndexedEx | Line | Required action |
|---|---|---:|---|
| V3.6 | `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol` | 13 | Retarget V3 file |
| V3.6 | `lib/crane/contracts/protocols/lending/aave/v3.6/helpers/LiquidationDataProvider.sol` | 12 | Retarget V3 file |
| V3.6 | `lib/crane/contracts/protocols/lending/aave/v3.6/deployments/projects/aave-v3-libraries/AaveV3LibrariesBatch2.sol` | 11–13 | Retarget V3 file |
| V3.6 | `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/helpers/LiquidationHelper.sol` | 6–8 | Retarget V3 file |
| V3.6 | `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.Liquidations.CloseFactor.t.sol` | 31–32 | Retarget V3 file |
| V3.6 | `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.Liquidations.t.sol` | 35–36 | Retarget V3 file |
| V3.6 | `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/L2Pool.t.sol` | 14–16 | Retarget V3 file |
| V4 | `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol` | 21 | Retarget V4 file |
| V4 | `lib/crane/test/foundry/spec/protocols/lending/aave/v4/setup/Base.t.sol` | 85 | Retarget V4 file |
| V4 | `lib/crane/test/foundry/spec/protocols/lending/aave/v4/helpers/mocks/LiquidationLogicWrapper.sol` | 10 | Retarget V4 file |
| V4 | `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` | 28 | Retarget V4 file; retain seed |
| V4 | `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol` | 15 | Remove with bypass |

This is a source-search inventory, not a compiler-derived proof of the entire dependency graph. Re-run the search immediately before implementation and after changes; classify additional hits instead of silently ignoring them.

## 5. Non-import references and affected consumers

The following inventory is consolidated from attributed researcher source reviews. Directory abbreviations here: C3 = `lib/crane/contracts/protocols/lending/aave/v3.6`; C4 = corresponding `v4`; T3 = `lib/crane/test/foundry/spec/protocols/lending/aave/3.6`; T4 = corresponding `v4`.

| Location | Reference / requirement |
|---|---|
| `C4/deployments/utils/libraries/SpokeBytecodeLinker.sol:15,20–21,36–38` | Update artifact ID and generated linking configuration. Old placeholder `__$329ad157ba4e68d2f4f45d82720084bf07$__` becomes stale. Establish replacement from compiler-emitted link references for the supported root; do not paste an unverified hash. |
| `T4/scripts/utils/SpokeDeployUtils.sol:22,30,79` | Update `vm.getCode` ID and generated `FOUNDRY_LIBRARIES` string; review broad `LiquidationLogic:` address-extraction pattern so it selects V4, not either version. |
| `T4/scripts/LibraryPreCompile.s.sol:9–12,26–28`; `T4/scripts/deploy/examples/AaveV4DeployAnvil.s.sol:13` | Dependent script comments and linking/precompile workflow. No broadcasts or environment mutation authorized here. |
| `lib/crane/scripts/foundry/bc/BcAavePhase3Deploy.sol:111–117,149–152`; `Script_BC_Phase3_Aave.s.sol:19,87`; `Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol:12,23,27` | Linker consumers; retain API/report names unless a direct path reference needs updating. |
| `C4/deployments/utils/libraries/BytecodeHelper.sol:15,21` | Hub/SpokeInstance artifact names unchanged; refresh linked dependents. |
| `scripts/forge-artifacts.py:157–171,198–212,240–253` | Unique new basename resolution; stale existing link references can enqueue removed source IDs before a build. Validate warm migration. |
| `scripts/shell/lib/rh_4663_stages.sh:128` | Keep existing seed inclusion. |
| `C3/deployments/projects/aave-v3-libraries/AaveV3LibrariesBatch2.sol:27–30` | Keep legitimate CREATE2 deployment via `type(LiquidationLogic).creationCode`; it is not the IndexedEx workaround. |
| `C3/protocol/pool/Pool.sol:312,768,867–868`; `C3/helpers/LiquidationDataProvider.sol:202–212,302–307` | Same V3 symbol calls/constants and getter after import correction. |
| `C4/spoke/Spoke.sol:87,91,354–376,621,640–641` | Same V4 symbol constants/struct/calls/getter after import correction. |
| `C3/interfaces/IPool.sol:802–804`; `C4/spoke/interfaces/ISpoke.sol:730–731` | Preserve public getter name and ABI. |
| `T3/invariants/_config/echidna_config.yaml:52,62` | Existing symbol binding remains under filename-only decision; no config edit required. |

### Artifact identities and invocation roots

Retain source-qualified identity. Expected IndexedEx identities:

- `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol:LiquidationLogic`
- `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic`

Crane-root identities omit `lib/crane/`. Validate each against compiler output and current remappings. The existing upstream-style `src/spoke/...` generated string is not a valid default for either repository root. Correct maintained operational emitters/docs to their declared supported root; retain upstream examples only when explicitly labelled upstream. Do not read, modify or print actual secret environment files as part of research. Do not introduce bare-symbol lookup `LiquidationLogic`.

Supported invocation roots: IndexedEx tests and its generic artifact loader run from IndexedEx root; Crane BC operational helpers run from `lib/crane` (documented in `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md:139–150`). Validate renamed library artifacts in both roots. Cross-root portability of Crane's operational helpers is not a new requirement.

### Maintained docs and historical evidence

Update live path examples in C4 `deployments/README.md:21–50` and Crane `docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md:126–166`. Review `BC_GREENFIELD_DEPLOYMENT_PRD.md`, `BC_GREENFIELD_PHASE_DEPLOY_STEPS.md`, `BC_GREENFIELD_SCRIPT_GUIDE.md`, `BC_GREENFIELD_DEPLOY_RESEARCH.md`, and `BC_GREENFIELD_GAP_REPORT.md` for operational filename examples. Symbol-only prose remains valid. Record local filename adaptations in the V4 provenance record and corresponding V3 provenance location after discovery.

Do not rewrite archived deployment histories or generated audit snapshots in `docs/audits/`, `docs/security/`, or `implementation-artifacts/` to erase old identities. New evidence gets a new report. Canonical skills mentioning the old local filenames need a separately authorized maintainer follow-up; this PRD does not authorize editing instruction/skill files.

## 6. Functional requirements

1. Rename the two files only; preserve the declarations and version-specific logic.
2. Update all live import paths, artifact IDs, linker placeholders/configuration emitters, and maintained operational references to the correct version. Do not leave an old-path compatibility implementation.
3. Restore `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")` in the V4 TestBase. Remove its V4 library implementation import and overwrite/bypass comments.
4. Verify all callers of the four-argument loader overload. Remove that overload and explicit-library-bytecode recursion/substitution plumbing once zero required callers remain; if another caller is discovered, stop for scope review rather than deleting its support silently.
5. Preserve normal recursive artifact linking, source-target verification, missing/empty/malformed/unlinked rejection, factory authorization, depth limit, offset bounds, memory compaction and salt semantics in `ArtifactCreationCode`.
6. Retain the seed file, V4 compile-root import with the new filename, and `type(...).name` reference. Replace its instruction to use compiler creation code with the restored artifact workflow. Do not import the seed into TestBases or FactoryServices.
7. Keep legitimate creation-code use in actual deployment contracts, such as the V3 batch. No blanket removal of `type(...).creationCode`.

## 7. Deployment compatibility

Filename-only does **not** promise byte-identical artifacts or stable new deployment addresses. Source paths enter metadata and link placeholders. IndexedEx `ArtifactCreationCode.sol:126–131` derives library CREATE3 salt from the full `source:Library` identity, so the renamed source changes that salt. CREATE3 address changes here because the identity salt changes, not because CREATE3 hashes initcode.

Crane CREATE2 flows hash initcode; metadata/link changes can change predicted addresses even where explicit salts remain unchanged. Capture old/new identities, initcode hashes, salts and predicted addresses in implementation evidence. Do not alter unrelated component namespaces to compensate. Occupied CREATE3 component identities may reuse old code/bindings; unchanged component names are not an upgrade mechanism.

Existing deployed Pools/Spokes keep their embedded library addresses. A source rename does not orphan, upgrade or mutate those deployments. No live migration, transaction or broadcast is authorized. Consumer ABI and storage must remain stable; compare external-library method identifiers separately.

## 8. Implementation handoff and acceptance gates (not executed)

### Preparation and sequencing

Capture pre-change source/toolchain/configuration and method-identifier/layout baselines, including both roots' artifact provenance. Preserve the warm output/cache. After mechanical renames/import updates, explicitly rebuild renamed libraries and their concrete linking dependents before invoking a planner that might read stale pre-rename link references. If stale-ID resolution still blocks preparation, report it and review a narrow planner correction; do not suppress all unresolved dependencies.

### Required proof

- **Inventory closure:** no live source imports or operational artifact IDs still use either old library file; intentional historical references are listed separately. Both declarations remain `LiquidationLogic`; bodies/constants unchanged.
- **Artifact coexistence:** compile both versions together and separately in both orders under the supported roots, with warm caches. Verify both renamed artifacts retain correct compilation targets and nonempty bytecode after every sequence. Stale old output may remain but must never be selected by new consumers.
- **Warm migration and missing-artifact preparation:** test pre-rename warm artifacts containing old link references, and a newly prepared, warm-seeded workspace plus isolated missing-artifact regression fixtures. Do not interpret this as permission for unseeded monorepo compiles or deletion of shared output/cache. A plain test is not assumed to build runtime-only dependencies.
- **Link integrity:** compiler link references name the appropriate new source. All offsets resolve; no old placeholder is accepted. Assert Pool/Spoke `getLiquidationLogic()` equals the expected version-specific deployment, not just nonzero, and the two deployments differ. Include wrong-version/source rejection.
- **Behavior and compatibility:** compare public Pool/Spoke ABI, storage layouts and library method identifiers. Execute real liquidation and deficit-related paths for each version using existing production/protocol fixtures. Preserve arithmetic/rounding, economics, authorization and registry paths; no SUT mocks added.
- **Workaround removal:** V4 TestBase no longer supplies or imports the library's creation code. Seed remains. Generic loader regressions remain green, including occupied-identity reuse, source matching, nested links, failures and scratch-memory preservation.
- **Failure recurrence:** run `test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol`, including the actual invariant suite, not only setup smoke. Verify any retained namesake setup test now tests artifact-based linkage and is not merely a nonzero-address assertion.
- **Affected suites:** Crane V3 liquidation/helper/Pool getter suites; Crane V4 `contracts/spoke/libraries/liquidation-logic/LiquidationLogic.*.t.sol`, liquidation/getter/configuration suites; IndexedEx `ArtifactCreationCode.t.sol`, entire cross-version family (including decimals/adversarial/invariant), and affected `SeMatrix_AaveLoopFixture` consumers. Validate scripts' link output without broadcasts or secret mutation. Validate planner regressions and warm stale-ID behavior.
- **Report:** actual commands, executable versions, tests selected/skipped/failed, deployed runtime sizes, new artifact IDs and address effects. Missing runs are not passes. No via-IR, new profiles, `--force`, cache deletion or changed source/test roots.

## 9. Non-goals

No deduplication of the two engines; no library declaration rename; no change to financial behavior; no test-file/getter renaming; no widening to `MathUtils`, `PercentageMath`, or `WadRayMath` collisions; no instruction/configuration edits; no wholesale artifact deletion; no live deployment/migration. Discovery of another collision is a separate finding, not permission to widen this task.

## 10. Council record, corrections and confidence

Eight requested research turns completed: four originals and four continuations, each continuation receiving the other three original reports, not cross-reviews.

| Researcher | Original session | Initial position / cross-review result |
|---|---|---|
| Astra | `ses_ecf91a653ffe47eAXAzZldDbAN` | Filename-only suffixes; identified V4 selector risk, salt changes and stale planner references; retained recommendation and challenged unconditional overwrite claims. |
| Grok | `ses_ecf88e093ffeR9iQX7Zmio9H50` | Filename-only suffixes; later explicitly accepted V4 library-selector risk, stronger version-binding tests and correction of upstream path emitters. |
| MiniMax M3 | `ses_ecf7e4741ffeuHNTjMRSkuDlb7` | Favored filename-only but initially used prefix names and incorrectly promised stable bytecode/addresses; cross-review retracted those claims and adopted suffixes/seed retention. |
| Kimi K3 | `ses_ecf74f427ffegvAnSL3wWcDKEe` | Filename-only suffixes with metadata/selector cautions; disclosed incidental peer-text exposure in its original search, so its original is not fully independent. |

All final recommendations favor filename-only. This is qualified convergence, **not four clean independent confirmations**. Original reports are preserved, including errors; this consolidated PRD controls the proposed scope. MiniMax's cross-review also misattributes some peer positions and artifact observations; those claims are not adopted. Kimi's stronger attribution of the artifact writer is not established by read-only snapshots. No researcher finding changes permissions.

Confidence: high in the 12 direct imports, workaround location and filename-only scope; high in source-identity/linking impacts; lower in the original failure's exact build/cache chronology. Remaining gaps include executed post-rename results, exact placeholders/hashes/addresses, deployed identity occupancy, and supported BC script invocation root. Agreement and green tests alone would not prove security or economic soundness.

## 11. Primary references

Accessed 2026-10-12. Context7 was used first for Solidity/Foundry claims in researcher passes and Solidity claims in moderator consolidation.

- Solidity 0.8.35 libraries: https://raw.githubusercontent.com/argotorg/solidity/v0.8.35/docs/contracts/libraries.rst — fully qualified link identities and special library selector rules (Astra/Grok evidence).
- Solidity metadata: https://github.com/argotorg/solidity/blob/develop/docs/metadata.rst — source names in metadata; not a pinned runtime-version claim.
- Solidity linking: https://github.com/argotorg/solidity/blob/develop/docs/using-the-compiler.rst — placeholder hashes use `source:Library`.
- Foundry compiler package v0.19.6: https://raw.githubusercontent.com/foundry-rs/compilers/v0.19.6/crates/compilers/src/artifact_output/mod.rs — output naming and conflict handling; not proof of installed binary version or a reproduced overwrite.
- Local workflow: `docs/testing/ARTIFACT_BUILDS.md:26–55,66–68`; current router `CLAUDE.md:47–61`.

## 12. Human checkpoint

The human approved the filename-only suffix rename with retained symbols and requested the detailed plan. No blocking requirement questions remain after the follow-up council review. Implementation details and validation gates are in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). Execution still requires a separate request. No source files were renamed or changed and no builds/tests were run by either research round.
