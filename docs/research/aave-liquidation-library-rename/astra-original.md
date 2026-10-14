# Astra — original independent findings and proposed PRD

Research date: 2026-10-12. Independent first pass; no peer findings consulted. Research only: no shell, compilation, tests, deployments, source/config edits, moves, or deletions performed. This report is a proposal, not implementation authorization.

## 1. Recommendation and central findings

1. **Rename the two source files to `LiquidationLogicAaveV3.sol` and `LiquidationLogicAaveV4.sol`, in their existing directories. Default to retaining the declared `LiquidationLogic` symbols.** This satisfies the explicit filename request with the smallest compatibility change. If globally distinct Solidity symbols are also wanted, approve that as a separate explicit decision; it is not ABI-neutral in V4.
2. **The direct-creation-code workaround is not implemented in the artifact seed.** It is the V4 TestBase's four-argument loader call, backed by a special overload and recursive override plumbing in `ArtifactCreationCode`. Keep `CraneFactoryArtifactSeed.sol`; update its import and misleading comment.
3. **The statement that matching filenames necessarily overwrite artifacts is unproven and contradicted as a general rule by Foundry's collision-handling source.** The repository comments assert overwrite; they are evidence of the intended workaround, not a reproduction of its cause.
4. **Even filename-only renaming changes source-qualified link identity and the IndexedEx external-library CREATE3 salt.** Do not promise address or bytecode preservation. Preserve economics, storage layout, and consumer ABI; explicitly review deployment identity changes.
5. **Warm-artifact migration is a real additional risk:** the planner reads old artifact link references before building and can try to resolve the removed source. Supplying replacement source paths alone may not cure stale link-reference discovery.

Confidence: high for the identified code paths, selector risk, and salt derivation; medium for completeness outside the searched source/test/script and maintained documentation trees; unverified for runtime correctness, actual artifact overwrite, and deployment-address deltas.

## 2. Rules, versions, and scope

Read `CLAUDE.md`, `docs/agent/SKILL_CATALOG.md`, Crane `AGENTS.md`, canonical Crane deployment/architecture/testing guidance and V4 liquidation skill, and IndexedEx testing and V4 router skills directly. Current root rules require build-before-test, retaining the Crane seed, stable build paths, warm seeding, and no via-IR (`CLAUDE.md:47–61`). The local testing skill's `vm.getCode` description at line 21 is stale relative to the actual direct-JSON loader.

Relevant product documents inspected:

- `prds/AaveV3V4CrossVersionCarryLoopVault.md:13–23,31–36,50–80,86–91`: registry deployment, separate version services, live reconciliation, oracle-priced shares, never-borrow withdrawals, and per-version risk gates. None may change in this rename.
- `contracts/protocols/lending/aave/cross-version/AAVE_CROSS_VERSION_LOOP_VAULT_PLAN.md:45–87`: historical portability/direct-creation-code narrative. Current loader code and root law supersede its older deployment instructions and green-test claims.
- `lib/crane/docs/deployment/BC_GREENFIELD_DEPLOYMENT_PRD.md:209–251`: both Aave versions and V4 pre-link deployment remain documented consumers. This task does not authorize running those deployments.

Configured compiler: IndexedEx `foundry.toml:29,33–36` and Crane `foundry.toml:31,35` specify solc 0.8.35 and optimizer runs 1; IndexedEx explicitly disables via-IR. V3 source pragma is `^0.8.10`; V4 is `^0.8.20`. `docs/testing/ARTIFACT_BUILDS.md:26,81` records Forge 1.5.1 and compiler package 0.19.6, but the installed executable version was not measured. V4 provenance records upstream SHA `af1f0f2ba323ac6fbaaee3abf6be060c78e22d35`, tag description `v0.5.11-6-gaf1f0f2b` (`lib/crane/docs/protocols/lending/aave/v4/VENDOR_PROVENANCE.md:4–8`). Its old solc 0.8.34 statement is historical, not current configuration. V3 upstream commit and current checkout commit were not verified.

No existing rename-specific approved PRD was provided. This report supplies proposed requirements without changing existing product decisions.

## 3. Code inventory

Path abbreviations below are relative to IndexedEx:

- `C3` = `lib/crane/contracts/protocols/lending/aave/v3.6`
- `C4` = `lib/crane/contracts/protocols/lending/aave/v4`
- `T3` = `lib/crane/test/foundry/spec/protocols/lending/aave/3.6` (note: tests use `3.6`, not `v3.6`)
- `T4` = `lib/crane/test/foundry/spec/protocols/lending/aave/v4`

### Production definitions and imports

| Location | Existing reference and required treatment |
|---|---|
| `C3/protocol/libraries/logic/LiquidationLogic.sol:25–29` | Rename file; retain declaration under recommended filename-only option. |
| `C4/spoke/libraries/LiquidationLogic.sol:21–24` | Rename file; retain declaration under recommended option. |
| `C3/protocol/pool/Pool.sol:13,312,768,867–868` | Update import path; qualified liquidation/deficit calls and `address(LiquidationLogic)` change only if symbol rename approved. Keep `getLiquidationLogic()` ABI. |
| `C3/helpers/LiquidationDataProvider.sol:12,202–212,302–307` | Update relative import; preserve qualified constants and calculations. |
| `C3/deployments/projects/aave-v3-libraries/AaveV3LibrariesBatch2.sol:12–13,30` | Update import; its CREATE2 `type(...).creationCode` is genuine deployment code, not the IndexedEx workaround to remove. |
| `C4/spoke/Spoke.sol:21,87,91,354–376,621,640–641` | Update import; constants, `LiquidateUserParams`, liquidation/deficit/bonus calls, and address cast depend on symbol decision. Keep getter ABI. |
| `C3/interfaces/IPool.sol:802–804`, `C4/spoke/interfaces/ISpoke.sol:730–731` | Getter comments may clarify version; do not rename the public getter. |
| `contracts/utils/foundry/CraneFactoryArtifactSeed.sol:26–28,33–38,57–59` | Retain Hub/Spoke/library compile-root references; update library import and comment. `type(...).name` is not creation code. |

### Workaround removal boundary

`contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol:15,80–88` imports the V4 implementation and supplies:

`lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic`

plus `type(LiquidationLogic).creationCode` to the loader. Replace that call with the normal factory-aware artifact loader for `SpokeInstance.sol:SpokeInstance`, and remove the now-unneeded library import and overwrite comment.

`contracts/utils/foundry/ArtifactCreationCode.sol:42–53` supplies the public internal-library overload accepting one library ID and creation code. Lines 73–94 and 114–129 thread that override through recursion and substitute supplied code on ID match. After a complete caller check, remove this special overload/plumbing while retaining:

- ordinary no-factory and factory-aware creation-code loading;
- source-qualified artifact matching (`153–193`);
- recursive external-library deployment, source-qualified salts, code-existence checks (`123–136`);
- depth limit, missing/empty/malformed-bytecode rejection, link bounds checks (`82–98,140–149`);
- scratch-memory compaction (`99–110`) and `releaseSalt` behavior (`55–64`).

This is **not** a request to remove every `type(...).creationCode` across Crane, and **not** a request to remove the generic artifact infrastructure.

### Linker, scripts, and configuration-string references

- `C4/deployments/utils/libraries/SpokeBytecodeLinker.sol:14–21,29–38,43–52`: hardcoded placeholder `__$329ad157ba4e68d2f4f45d82720084bf07$__`, library artifact ID, and generated `FOUNDRY_LIBRARIES` entry all need review. The placeholder changes even for filename-only renaming. Derive it from actual compiler link references or validate a regenerated constant; do not guess the hash. Crane-root and IndexedEx-root source identities differ.
- `T4/scripts/utils/SpokeDeployUtils.sol:20–30,78–79`: `vm.getCode` ID, generated linking string, and name-based address-extraction regex. There is already a mismatch: lookup uses `contracts/protocols/...`, emitted configuration uses upstream `src/spoke/...`. Fix source identity for the supported invocation root, not just the basename. Filename-only retention leaves the broad `LiquidationLogic:` regex ambiguous between versions; qualify selection to V4. Do not inspect or modify actual environment files during research.
- `T4/scripts/LibraryPreCompile.s.sol:9–12,26–28`, `T4/scripts/deploy/examples/AaveV4DeployAnvil.s.sol:13`: deployment comments/logs and precompile consumer.
- `lib/crane/scripts/foundry/bc/BcAavePhase3Deploy.sol:111–116,152`; `Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol:12,23,27`; `Script_BC_Phase3_Aave.s.sol:19,87`: linker consumers and reporting labels. Renaming wrapper functions or report fields is unnecessary.
- `T3/invariants/_config/echidna_config.yaml:52,62` binds `LiquidationLogic` to `0xf06`; requires symbol update only if symbol rename approved, plus validation that it still identifies V3. This is an implementation inventory item, not permission to edit configuration in this session.
- `scripts/shell/lib/rh_4663_stages.sh:128` explicitly includes the Crane seed. Retain it.

### Tests and qualified symbols

Direct V3 test imports: `T3/helpers/LiquidationHelper.sol:7–8,61`, `T3/protocol/pool/Pool.Liquidations.CloseFactor.t.sol:31–32,90–166`, `Pool.Liquidations.t.sol:35–36`, and `L2Pool.t.sol:15–16`. `Pool.t.sol:654–655` checks the getter only for nonzero; insufficient to prove the correct version was linked.

Direct V4 imports: `T4/setup/Base.t.sol:85` and `T4/helpers/mocks/LiquidationLogicWrapper.sol:10`. The wrapper contains library-qualified parameters/results/calls at `136–165,200–244,253`. This is an implementation wrapper, not a replacement for the real liquidation engine.

Transitive V4 references requiring changes only under symbol renaming include all `LiquidationLogic.*.t.sol` suites under `T4/contracts/spoke/libraries/liquidation-logic/`: Base, EvaluateDeficit, LiquidateDebt, LiquidationAmounts, LiquidateUser, DebtToLiquidate, DebtToTargetHealthFactor, ValidateLiquidationCall, LiquidationBonus, LiquidateCollateral, CollateralToLiquidate, ExecuteLiquidation. Also `contracts/spoke/liquidation/Spoke.LiquidationCall.Base.t.sol:99–161,569–681`, `Spoke.LiquidationCall.Dust.t.sol:79,130,192,238`, and `contracts/spoke/misc/Spoke.Getters.t.sol:7,114,152`. Include `using LiquidationLogic for ...`, not just imports. Existing test filenames and wrapper contract names need not be renamed merely because they contain the phrase.

IndexedEx `test/` has no direct `LiquidationLogic` text matches, but the indirect deployment impact is substantial: `TestBase_AaveCrossVersionLoopV3Market.sol:24–35,46` inherits the V4 base. Run the entire `test/foundry/spec/protocol/lending/aave/cross-version/` family, including decimal/adversarial/invariant suites, and affected SE-matrix consumers of `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_AaveLoopFixture.sol:27–41,89–94`.

Generic loader regression suite: `test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol:17–65,76–91,99–193` covers salt encoding, occupied-identity reuse, memory preservation, nested linking, source matching and failures. It currently has no Aave-specific collision test.

## 4. Filename-only versus symbol rename

### Option A — filenames only (recommended default)

New artifact IDs end in `LiquidationLogicAaveV3.sol:LiquidationLogic` and `LiquidationLogicAaveV4.sol:LiquidationLogic`; normal artifact locations should be separate basename directories containing `LiquidationLogic.json`. Confirm emitted locations rather than treating that expectation as runtime evidence.

Keep library declarations and qualified type names unchanged. Versioned import aliases can be used selectively for clarity without changing declaration identity. Filename-only renaming resolves this pair's basename collision while minimizing upstream divergence and library-selector changes. Bare `LiquidationLogic` lookups remain ambiguous and must not be used as identity.

### Option B — filenames and declared symbols

Use `LiquidationLogicAaveV3` / `LiquidationLogicAaveV4` consistently for declarations, import bindings, qualified constants/types, `using`, address/type expressions, artifact contract names, linker keys, and config strings.

**Critical compatibility fact:** V4 declares `LiquidateUserParams` inside its library (`C4/.../LiquidationLogic.sol:35–45`) and accepts it in external `liquidateUser` (`197–210`). Solidity library selectors encode non-storage structs using qualified names such as `Library.Struct`, unlike regular contract tuple ABI. Thus renaming the V4 declaration changes the `liquidateUser` signature identity and is expected to change its selector. An import alias cannot preserve the renamed declaration's canonical type identity. All callers and library must be rebuilt together; never link an old Spoke against a renamed library as a drop-in replacement.

V3 external liquidation/deficit parameters use `DataTypes` structs (`77–81,162–168`), so this particular enclosing-library-name effect is not apparent there. Still compare all compiler-produced method identifiers; do not extrapolate V3 compatibility to V4.

Preserve public Pool/Spoke interface selectors, events/errors, storage field order/types, risk thresholds, rounding, reserve/accounting behavior and access checks under either option. JSON `internalType` and metadata differences must be separated from user-facing ABI differences. Reject claims of byte-for-byte identity.

## 5. Artifact hypothesis and build migration risks

The seed (`35–37`), TestBase (`81–82`) and loader (`43–45`) assert overwrite. However, Foundry compiler package v0.19.6 `artifact_output/mod.rs` implements `conflict_free_output_file`, `get_artifact_path`, and a taken-path set populated from cached artifacts; duplicate output paths are disambiguated with source parents. Therefore matching basename and symbol alone do **not** establish overwrite. Different build roots, incomplete/copied caches, stale artifacts, or a loader mismatch remain hypotheses. No reproduction was executed or artifact chronology collected.

The actual loader already tries source-path suffixes and verifies `.metadata.settings.compilationTarget` for full IDs (`ArtifactCreationCode.sol:169–192`). Keep these protections even after making this pair unique; other duplicate names remain possible.

Planner concern: `scripts/forge-artifacts.py:198–212` reads existing `.bytecode.linkReferences`; `240–253` queues those IDs and calls strict `resolve_artifact` (`157–170`). After a source rename, a stale Spoke artifact may still enqueue the removed V4 source ID and fail planning **before** the replacement can build. This is a code-derived risk, not a reproduced failure. Acceptance must cover the warm-before-rename state. Choose an explicit artifact-first refresh of affected concrete consumers, or a narrowly reviewed planner change to reconcile stale references against current imports; do not conceal errors by ignoring all unresolved libraries. Root rules prohibit wholesale cache/output deletion as the migration recipe.

## 6. Salt, address, and economics impact

- Loader library salt is `abi.encode(source + ":" + libraryName)._hash()` (`ArtifactCreationCode.sol:126–131`), not just the library symbol and not initcode. **Filename-only changes that salt.** New CREATE3 library identity/address is expected for the same factory. Crane-root and IndexedEx-root identities already differ.
- CREATE2 V3 library deployment uses passed salt plus creation code (`AaveV3LibrariesBatch2.sol:30`); V4 linker uses zero salt plus library bytecode (`SpokeBytecodeLinker.sol:17,29–30`). Source/metadata changes can change initcode and therefore addresses even if salts stay fixed. Linked Spoke and downstream constructor-bound deployments can change too.
- `ArtifactCreationCode.releaseSalt` stays unchanged. Occupied component salts reuse existing deployments and bindings; unchanged CREATE3 component identity does **not** mean new bytecode is installed. Existing tests explicitly demonstrate this (`ArtifactCreationCode.t.sol:31–65`). Do not silently add a migration or salt-compatibility shim.
- No economics changes are required or authorized. Preserve exact liquidation thresholds, fees, debt treatment, collateral transfers, rounding, and storage effects. Passing rename tests is not evidence that the carry strategy is economically sound or that an existing deployment is upgraded.

## 7. Documentation inventory and exclusions

Update maintained local-path/artifact examples in `C4/deployments/README.md:21–50`, `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md:126–164,180`, and relevant references in `BC_GREENFIELD_DEPLOYMENT_PRD.md:243`, `BC_GREENFIELD_PHASE_DEPLOY_STEPS.md:234`, `BC_GREENFIELD_SCRIPT_GUIDE.md:314`, and `lib/crane/docs/protocols/lending.md:32,119` as needed for the chosen symbol policy. Preserve historical logs/manifests as historical; do not rewrite old deployment addresses.

Canonical skill references include `lib/crane/.claude/skills/aave-v4-liquidation/SKILL.md:106,206,218,365,409` and V3 pool skill's source reference at line 431. These require owner-maintained follow-up only if describing local Crane paths rather than upstream names. Instruction/skill files are not permitted report targets in this session; no edits made or authorized here. Do not use mirror updates to broaden scope.

Other Aave versions, third-party trees, cached artifacts, archives and upstream citations must not be swept by an unqualified global replacement. A residual `LiquidationLogic` is valid under filename-only policy, in ABI getter names, and in historical/upstream material.

## 8. Proposed PRD acceptance gates

1. **Decision gate:** approve filename-only or filename-plus-symbol policy explicitly. Record expected artifact IDs for both invocation roots and anticipated address changes. Filename-only is the default proposal.
2. **Mechanical-change gate:** both requested suffixed filenames exist in their original version directories; every live import resolves to the proper version. No compatibility forwarding file recreates the ambiguous old artifact. No economic expression, storage member, public getter, event/error, visibility or authorization change.
3. **Artifact gate:** build both libraries together and separately in both version orders, with the supported compiler/settings. Inspect source compilation targets, bytecode, method identifiers, creation/runtime link references, and actual output paths. Demonstrate coexistence and correct version binding; do not infer it from file existence alone.
4. **Warm migration gate:** begin from pre-rename warm artifacts/cache, including stale Spoke link references. The documented preparation sequence must succeed without deleting shared output/cache or enabling via-IR. Missing new artifacts fail closed rather than falling back to old IDs.
5. **Workaround-removal gate:** no V4 direct `type(...).creationCode` remains in the IndexedEx market base; no special library-override overload/plumbing remains after caller verification. Seed remains a compile root. Generic loader and its safety/memory checks remain intact.
6. **Link correctness gate:** deploy real V3 Pool and V4 Spoke through their established test paths in one environment; assert each getter equals its expected library deployment and that the deployments are distinct. Exercise an actual liquidation and deficit-related path for each, not only supply or a nonzero getter. Demonstrate wrong-version artifact/source rejection.
7. **ABI/storage gate:** compare consumer ABI/selectors and storage layouts before/after. Compare external library method identifiers separately. Under Option B explicitly approve V4 `liquidateUser` selector change and prove matched rebuilds; do not claim binary compatibility. Account for library runtime address patching when comparing deployed code hashes.
8. **Regression gate:** build-before-test; run Crane V3 liquidation/helper/getter suites, V4 liquidation/getter/configuration suites, IndexedEx loader suite, cross-version suites and affected matrix fixtures. Run planner regression tests, including rename with stale artifacts. No new SUT mocks, profile changes, secrets, FFI environment mutation or broadcasts needed for hermetic acceptance.
9. **Release gate:** produce an old/new source-ID, salt, initcode-hash and predicted-address table for affected deployment flows. Inventory occupied identities and existing consumers before any later deployment authorization. Update maintained docs and provenance notes, retain historical evidence, and coordinate the Crane submodule revision with IndexedEx references.

## 9. Sources, counterarguments, and missing evidence

External sources accessed 2026-10-12, using Context7 first:

- Solidity library linking/selector rules (pinned 0.8.35 primary source): https://raw.githubusercontent.com/argotorg/solidity/v0.8.35/docs/contracts/libraries.rst — fully qualified placeholder identity, special library selectors, and runtime address patching.
- Solidity metadata documentation (Context7 primary-source result, develop rather than version-pinned): https://github.com/argotorg/solidity/blob/develop/docs/metadata.rst — paths/source hashes enter metadata and can change bytecode.
- Foundry compiler package v0.19.6 primary source: https://raw.githubusercontent.com/foundry-rs/compilers/v0.19.6/crates/compilers/src/artifact_output/mod.rs — duplicate-output disambiguation and cache-path reuse. Fetch output truncated only later in the file; the relevant functions were visible. An earlier guessed artifacts-source URL returned 404 and is not relied upon.
- Foundry `getCode` documentation via Context7: https://github.com/foundry-rs/book/blob/master/src/pages/reference/cheatcodes/get-code.mdx — artifact identifier syntax; it does not establish this checkout's overwrite behavior.

Counterarguments:

- Renaming symbols improves human clarity and bare-name uniqueness. Agreed, but filename-only is sufficient for basename separation and avoids the specific V4 library-selector break. Choose broader renaming consciously, not under an ABI-neutral label.
- Correctly source-qualified artifact lookup could make renaming unnecessary for correctness. Agreed in principle; the user nevertheless requested distinctive filenames, and those simplify operational identity. They do not prove the previous Foundry implementation was faulty.
- Existing overwrite comments may reflect a real incident. Agreed; absent a recorded build sequence and artifacts, this is historical testimony, not proof of a general overwrite rule.
- Keeping all generic loader checks might appear redundant after renaming. They protect other libraries and stale/wrong-source artifacts; removing them is unjustified scope expansion.

Missing evidence: installed Forge/solc executable versions and checkout SHAs, artifact/caching chronology, full all-file reference manifest including generated outputs, exact new placeholders/selectors/hashes/addresses, a complete verification of four-argument overload callers, affected deployment occupancy, and executed build/test results. Source/test/script searches support the listed inventory but do not constitute a compiler-derived dependency closure. No existing mainnet deployment, upstream release status, or historical green-test statement was independently validated. Conclusions are bounded accordingly.
