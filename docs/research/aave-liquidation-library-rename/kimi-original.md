# Kimi K3 — Original first-pass findings: Aave `LiquidationLogic.sol` rename (Crane v3.6 + v4)

Date: 2026-10-12. Author: Kimi K3 (kimi-code-plan-global/k3, variant high). Independent first pass; no peer artifacts were intentionally read (see §10 Protocol note). Research only — no code, config, test, or filesystem mutations were performed.

Repo anchors (all paths relative to `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex` unless absolute):

- `C3` = `lib/crane/contracts/protocols/lending/aave/v3.6/`
- `C4` = `lib/crane/contracts/protocols/lending/aave/v4/`
- `T3` = `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/`
- `T4` = `lib/crane/test/foundry/spec/protocols/lending/aave/v4/`
- `IX` = IndexedEx repo root (`contracts/`, `scripts/`, `docs/`)

---

## 1. Task restatement and naming interpretation

User asks: rename Crane Aave v3.6 and v4 `LiquidationLogic.sol` files with **AaveV3/AaveV4 suffixes**, update all imports/references across Crane and IndexedEx to the correct version, and **remove the direct creation-code workaround** the user calls "Artifact Seed" (location to be verified). Preserve economics, storage, ABI where possible. Assess filename-only vs symbol rename explicitly.

My interpretation (flagged as assumption A1):

- "Suffix" = version token appended after `LiquidationLogic`: `LiquidationLogicAaveV3.sol` / `LiquidationLogicAaveV4.sol` (not a prefix, and not `AaveV3LiquidationLogic.sol`). Either spelling satisfies "suffix"; I recommend `LiquidationLogicAaveV{3,4}.sol` because it keeps the common stem grouped in sorted listings and matches how test files are already named (`LiquidationLogic.*.t.sol`).
- "AaveV3" labels the existing **v3.6** tree. No other Aave v3.x `LiquidationLogic.sol` exists in the repo. The suffix should not be read as introducing a new upstream version.
- "Remove the direct creation-code workaround" = remove the 4-argument `ArtifactCreationCode.creationCode(..., libraryId, type(LiquidationLogic).creationCode)` bypass in `TestBase_AaveCrossVersionLoopV4Market.sol`, not necessarily the seed file itself (CLAUDE.md non-negotiable #10 forbids deleting the seed; see §4).

## 2. The two target files (facts, verified by direct read)

| # | File | Declared symbol | Pragma / license | Size |
|---|------|-----------------|------------------|------|
| 1 | `C3/protocol/libraries/logic/LiquidationLogic.sol` | `library LiquidationLogic` (line 29) | `^0.8.10` (line 2), BSL-1.1 (line 1) | 602 lines |
| 2 | `C4/spoke/libraries/LiquidationLogic.sol` | `library LiquidationLogic` (line 24) | `^0.8.20` (line 2), LicenseRef-BUSL (line 1) | 782 lines |

Both declare the **same** Solidity symbol `LiquidationLogic`. No third `library LiquidationLogic` or `contract LiquidationLogic` exists (`LiquidationLogicWrapper` is a test contract, `T4/helpers/mocks/LiquidationLogicWrapper.sol:16`).

v3.6 surface (file 1): constants `DEFAULT_LIQUIDATION_CLOSE_FACTOR` (l.44), `CLOSE_FACTOR_HF_THRESHOLD` (l.50, `public`), `MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD` (l.57, `public`), `MIN_LEFTOVER_BASE` (l.65, `public`); external `executeEliminateDeficit` (l.77) and `executeLiquidationCall` (l.162); internal `_burnCollateralATokens` (l.396), `_burnDebtTokens` (l.433), `_calculateAvailableCollateralToLiquidate` (l.507), `_burnBadDebt` (l.563). Both external functions take mapping-storage params plus `DataTypes.*` memory structs — **no library-local struct types in external signatures**.

v4 surface (file 2): 12 library-local structs `LiquidateUserParams` … `LiquidationAmounts` (ll.35–182); constants `HEALTH_FACTOR_LIQUIDATION_THRESHOLD` (l.185, `public`), `DUST_LIQUIDATION_THRESHOLD` (l.188, `public`); external `liquidateUser` (l.197, takes `LiquidateUserParams memory` at l.209 — **library-local struct in an external signature**), external `notifyReportDeficit` (l.265, mappings + `uint256` + `address` only), public pure `calculateLiquidationBonus` (l.313, all `uint256`), plus internal helpers (ll.343–782).

## 3. Verified collision mechanics (first-party evidence, not chat hypotheses)

The user's "prior chat claims of artifact overwrite" are confirmed **and refined** by in-repo evidence:

1. **The seed file itself documents the overwrite.** `IX/contracts/utils/foundry/CraneFactoryArtifactSeed.sol` NatSpec lines 35–37: *"Naming `LiquidationLogic` here does not keep its artifact. Aave v3.6 has the same filename and overwrites `out/LiquidationLogic.sol/`. Spoke linking must use the compiler creation code, not that file."* The v4 import is at line 28; `type(LiquidationLogic).name` at line 59.
2. **The consumer documents the bypass.** `IX/contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol` lines 81–88: comment *"v3.6 LiquidationLogic.sol steals out/LiquidationLogic.sol/. Pass the compiler's v4 creation code so that overwrite cannot unlink Spoke."* plus the 4-arg call with libraryId `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic` and `type(LiquidationLogic).creationCode`.
3. **The loader documents the collision.** `IX/contracts/utils/foundry/ArtifactCreationCode.sol` lines 42–45: *"`out/LiquidationLogic.sol/LiquidationLogic.json` is shared with Aave v3.6. A later v3.6 compile overwrites that file…"* and lines 169–177: *"Foundry disambiguates duplicate filenames with source-directory suffixes"* with a `_matchesSource` compilationTarget cross-check (ll.186–193).
4. **Current `out/` state (verified directly, read-only):**
   - `lib/crane/out/` contains BOTH `LiquidationLogic.sol/LiquidationLogic.json` (ABI contains `liquidateUser` → **v4**) AND `logic/LiquidationLogic.sol/LiquidationLogic.json` (ABI contains `executeLiquidationCall`, no `liquidateUser` → **v3.6**, disambiguated under its parent dir `logic/`). So a full Crane build disambiguates the pair: v4 holds the short slot, v3.6 gets the parent-dir suffix.
   - `IX/out/` contains BOTH paths too, but **both** JSONs contain `executeLiquidationCall` and neither contains `liquidateUser` → **both slots currently hold the v3.6 artifact; the v4 library artifact is absent from IndexedEx `out/` right now.** This is the overwrite race made visible: an incremental/partial compile that only saw the v3.6 file reclaimed the short slot (`out/LiquidationLogic.sol/`) while the earlier full-compile disambiguated copy sits at `out/logic/LiquidationLogic.sol/`.
   - Stale `IX/out/LiquidationLogicArtifactProbe.sol/LiquidationLogicArtifactProbe.json` exists with **no matching source anywhere in the tree** — residue of a prior investigation; harmless but should not be treated as load-bearing.

   **Mechanism inference (I1, medium-high confidence):** Foundry's duplicate-basename disambiguation is decided per compilation batch. A full build sees both files and writes `out/LiquidationLogic.sol/` (v4) + `out/logic/LiquidationLogic.sol/` (v3.6). A later incremental build compiling only v3.6 dependents sees a single `LiquidationLogic.sol` and writes the short path, overwriting the v4 artifact. That is exactly the failure the seed NatSpec and the TestBase comment describe. I did not execute builds to prove this; it is inferred from the two `out/` states plus first-party comments. `docs/testing/ARTIFACT_BUILDS.md` (ll.26, 28) cites Foundry 1.5.1 / compilers 0.19.6 as the pinned toolchain for these behaviors.
5. **solc placeholder rule (primary source):** the `__$<hash>$__` placeholder is "a 34 character prefix of the hex encoding of the keccak256 hash of the fully qualified library name", where the fully qualified name is `<source-unit path>:<LibraryName>` (Solidity docs v0.8.37, "Using the Compiler > Library Linking" and "Contracts > Libraries", https://docs.soliditylang.org/en/v0.8.37/using-the-compiler.html and .../contracts.html, accessed 2026-10-12). **Any filename change changes the path component and therefore the placeholder, even if the symbol stays `LiquidationLogic`.** Note also that the source-unit name differs by project root: `contracts/...` when compiling inside Crane, `lib/crane/contracts/...` when compiling inside IndexedEx — so the same library has *different* placeholders (and different `FOUNDRY_LIBRARIES` identities) per repo root.
6. **Bytecode/address rule (primary source):** "any change to the metadata might result in a change of the bytecode. This includes changes to a filename or path" (Solidity docs v0.8.37, "Contract Metadata", https://docs.soliditylang.org/en/v0.8.37/metadata.html, accessed 2026-10-12). **Therefore even a filename-only rename changes the libraries' initcode (metadata hash + link-reference keys), and changes the initcode of every contract that links them (`Pool`, `Spoke`/`SpokeInstance`).** Any claim that filename-only rename leaves bytecode "byte-for-byte stable" is false. Economics/logic bytecode is identical modulo metadata; deployed addresses of *new* deployments change; existing on-chain deployments are untouched.

## 4. "Artifact Seed" identity and what removal may/may not mean (facts)

- The user's "Artifact Seed" = `IX/contracts/utils/foundry/CraneFactoryArtifactSeed.sol` (64 lines). Verified: it is the only seed importing v4 `LiquidationLogic` (l.28) and naming it in `artifactNames()` (l.59). A second, unrelated seed `IX/contracts/utils/foundry/UniswapV4DetfFactoryArtifactSeed.sol` exists and does **not** reference `LiquidationLogic` (grep-clean).
- Governing law: CLAUDE.md non-negotiable #10 (line 61): *"Do not delete `contracts/utils/foundry/CraneFactoryArtifactSeed.sol`."* Same in `docs/agent/INDEXEDEX_AGENT_LAW.md:327` and the program docs `docs/factory-service-artifact-creation-bytecode.md` (D14, ll.43, 50, 73, 104) / `.plan.md` (ll.98–99, 204, 235). The seed's purpose is broader than LiquidationLogic: it is the `src` compile root for ~19 Crane implementations (ERC20Facet, ERC2612Facet, ERC4626Facet, ERC5267Facet, ERC4626PermitDFPkg, 4 Balancer facets, ERC20MintBurnOwnableFacet, ERC20MintBurnOwnableOperableDFPkg, ERC721Facet, StablePoolFactory, PoolManager, HubInstance, SpokeInstance, LiquidationLogic, SenderGuardFacet, WeightedPoolFactory — ll.8–30, 43–61). (The older plan text says "nine imports" — stale; the file now lists 19.)
- **Conclusion for the PRD:** the file must not be deleted under current law. What the rename can and should remove is:
  1. the 4-arg creation-code bypass in `TestBase_AaveCrossVersionLoopV4Market.sol:15, 81–88` (replaced by the normal 2-arg `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")`, letting the recursive linker read `linkReferences` from a uniquely-named artifact); and
  2. the now-false NatSpec sentences in the seed (ll.35–37) and in `ArtifactCreationCode.sol` (ll.42–45) that claim permanent overwrite — after unique filenames the overwrite mechanism for this pair disappears. The seed's v4 import itself should be **kept with the new filename** unless the artifact-build helper (`scripts/forge-artifacts.py`, `build --consumer` linkReferences following, ARTIFACT_BUILDS.md l.41) is relied on for all flows; keeping it is the conservative default because plain `forge build` of IndexedEx `src` would otherwise not emit the v4 library artifact (inference I2).
- If the user truly intends the seed file's *deletion*, that contradicts CLAUDE.md #10 and requires an explicit owner ruling; the PRD should surface this as a decision point, not assume it.

## 5. Full reference inventory (all line numbers verified by grep/read today)

### 5.1 Solidity import statements of the two files

| File | Line(s) | Imports | Version |
|------|---------|---------|---------|
| `C3/protocol/pool/Pool.sol` | 13 | relative `../libraries/logic/LiquidationLogic.sol` | v3.6 |
| `C3/helpers/LiquidationDataProvider.sol` | 12 | relative `../protocol/libraries/logic/LiquidationLogic.sol` | v3.6 |
| `C3/deployments/projects/aave-v3-libraries/AaveV3LibrariesBatch2.sol` | 11–13 | `@crane/...v3.6/protocol/libraries/logic/LiquidationLogic.sol` | v3.6 |
| `C4/spoke/Spoke.sol` | 21 | `@crane/...v4/spoke/libraries/LiquidationLogic.sol` | v4 |
| `T3/helpers/LiquidationHelper.sol` | 6–8 | `@crane/...v3.6/.../LiquidationLogic.sol` | v3.6 |
| `T3/protocol/pool/Pool.Liquidations.CloseFactor.t.sol` | 31–32 | v3.6 path | v3.6 |
| `T3/protocol/pool/Pool.Liquidations.t.sol` | 35–36 | v3.6 path | v3.6 |
| `T3/protocol/pool/L2Pool.t.sol` | 14–16 | v3.6 path | v3.6 |
| `T4/setup/Base.t.sol` | 85 | v4 path | v4 |
| `T4/helpers/mocks/LiquidationLogicWrapper.sol` | 10 | v4 path | v4 |
| `IX/contracts/utils/foundry/CraneFactoryArtifactSeed.sol` | 28 | v4 path | v4 |
| `IX/contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol` | 15 | v4 path | v4 |

### 5.2 Qualified symbol references (`LiquidationLogic.X`, `address(LiquidationLogic)`, `type(LiquidationLogic).*`, `using LiquidationLogic for`)

v3.6:
- `C3/protocol/pool/Pool.sol`: `executeLiquidationCall` (l.312), `executeEliminateDeficit` (l.768), `return address(LiquidationLogic)` in `getLiquidationLogic()` (ll.867–868).
- `C3/helpers/LiquidationDataProvider.sol`: `MIN_LEFTOVER_BASE` (ll.202–212 ×6), `MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD` (ll.302–303), `CLOSE_FACTOR_HF_THRESHOLD` (l.304), `DEFAULT_LIQUIDATION_CLOSE_FACTOR` (l.307).
- `C3/deployments/.../AaveV3LibrariesBatch2.sol`: `type(LiquidationLogic).creationCode` (l.30), deployed with shared salt `bytes("AAVE_V3_LIBRARIES_BATCH")._hash()` (l.27).
- `T3/helpers/LiquidationHelper.sol`: `LiquidationLogic._calculateAvailableCollateralToLiquidate(...)` (l.61) — **internal** library function; inlined at compile time, no external link.
- `T3/protocol/pool/Pool.Liquidations.CloseFactor.t.sol`: `MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD` (ll.90, 108, 126, 150, 153, 160, 166).
- `T3/protocol/pool/Pool.t.sol`: `test_getLiquidationLogic` asserts getter ≠ 0 (ll.654–655).

v4:
- `C4/spoke/Spoke.sol`: constants (ll.87, 91), `LiquidateUserParams` (l.354), `liquidateUser({...})` (l.366), `notifyReportDeficit` (l.376), `calculateLiquidationBonus({...})` (l.621), `return address(LiquidationLogic)` in `getLiquidationLogic()` (ll.640–641).
- `T4/helpers/mocks/LiquidationLogicWrapper.sol`: wraps every external/internal function and most structs (ll.136–253).
- `T4/setup/Base.t.sol`: import only (l.85).
- 12 unit suites `T4/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.*.t.sol` (Base, EvaluateDeficit, LiquidateDebt, LiquidationAmounts, LiquidateUser, DebtToLiquidate, DebtToTargetHealthFactor, ValidateLiquidationCall, LiquidationBonus, LiquidateCollateral, CollateralToLiquidate, ExecuteLiquidation): heavy `LiquidationLogic.<Struct|constant>` usage, incl. `using LiquidationLogic for uint256` (`LiquidationLogic.LiquidationAmounts.t.sol:10`). They import `LiquidationLogic.Base.t.sol` (path-sensitive string, l.4 of each).
- `T4/contracts/spoke/liquidation/Spoke.LiquidationCall.Base.t.sol` (ll.99–161, 569, 623, 681), `Spoke.LiquidationCall.Dust.t.sol` (ll.79, 130, 192, 238), `Spoke.Getters.t.sol` (`using LiquidationLogic for ISpoke.LiquidationConfig` l.7; calls ll.114, 152), `Spoke.Config.t.sol` (getter assertion l.18).
- `IX/contracts/utils/foundry/CraneFactoryArtifactSeed.sol`: `type(LiquidationLogic).name` (l.59).
- `IX/contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol`: `type(LiquidationLogic).creationCode` (l.87).

### 5.3 String / artifact-ID / placeholder references (break under ANY filename change)

| File | Line | Content |
|------|------|---------|
| `C4/deployments/utils/libraries/SpokeBytecodeLinker.sol` | 15 | `LIQUIDATION_LOGIC_PLACEHOLDER = "__$329ad157ba4e68d2f4f45d82720084bf07$__"` — must be **re-derived by compiling** after rename (keccak256 of the new Crane-root source-unit name, 34-hex prefix; do not hand-compute in review). |
| same | 20–21 | `LIB_ARTIFACT_PATH = "contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic"` (Crane-root dialect, fed to `VM.getCode` l.29) |
| same | 36–38 | emits `FOUNDRY_LIBRARIES=contracts/protocols/.../LiquidationLogic.sol:LiquidationLogic:<addr>` |
| `T4/scripts/utils/SpokeDeployUtils.sol` | 22 | `vm.getCode("contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic")` |
| same | 30 | `getLibraryString` emits upstream dialect `src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:<addr>` — already mismatched with the Crane tree (BC doc flags this: `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md:145`). |
| same | 79 | `.env` parser regex `sed -nr 's/.*LiquidationLogic:([^,]*).*/\1/p' .env` — keeps matching under Option A (symbol unchanged); under Option B (`LiquidationLogicAaveV4:`) the regex would still substring-match `LiquidationLogicAaveV4:`? No — the pattern captures after `LiquidationLogic:` literally; `LiquidationLogicAaveV4:` does not contain `LiquidationLogic:` so it **breaks under Option B**. Under Option A it remains ambiguous-by-substring if both versions ever appear in one `.env`. |
| `T4/scripts/LibraryPreCompile.s.sol` | 9–12, 26–28 | comments + flow only; no path strings of its own. |
| `IX/contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol` | 86 | IndexedEx-root libraryId `"lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic"` |
| `IX/contracts/utils/foundry/ArtifactCreationCode.sol` | 42–45 | NatSpec naming `out/LiquidationLogic.sol/LiquidationLogic.json` (comment update; code itself is generic). |
| `IX/contracts/utils/foundry/CraneFactoryArtifactSeed.sol` | 35–37 | NatSpec overwrite claim (comment update). |
| `T3/invariants/_config/echidna_config.yaml` | 52, 62 | crytic `--compile-libraries=(…,(LiquidationLogic,0xf06),…)` and `deployContracts ["0xf06","LiquidationLogic"]` — **symbol binding**; unchanged under Option A, must be updated under Option B. (Config edit is out of my remit; inventory only.) |

### 5.4 Deployment scripts / orchestration (behavioral dependents)

- `lib/crane/scripts/foundry/bc/BcAavePhase3Deploy.sol`: `deployLiquidationLogicLinkedSpoke()` (ll.111–117) delegates to `SpokeBytecodeLinker.deployLiquidationLogicAndLinkSpoke()`; consumed by `deployV4Core` (ll.149–152). No direct path strings; breaks transitively via SpokeBytecodeLinker.
- `lib/crane/scripts/foundry/bc/Script_BC_Phase3_Aave.s.sol`: comment l.19; manifest row label `"V4 LiquidationLogic"` (l.87) — cosmetic.
- `lib/crane/scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol`: ll.12, 23, 27 — delegates to SpokeBytecodeLinker.
- `C4/deployments/utils/libraries/BytecodeHelper.sol`: `getHubBytecode`/`getSpokeBytecode` use `vm.getCode("contracts/protocols/lending/aave/v4/.../HubInstance.sol:HubInstance" | "SpokeInstance.sol:SpokeInstance")` (ll.15, 21) — unaffected by the library rename itself, but the returned Spoke bytecode must be re-linked against the renamed library.
- v3.6 `IPool.getLiquidationLogic()` declared `external view` (`C3/interfaces/IPool.sol:802–804`); `Pool.sol:867` implements `external pure` — pre-existing view/pure mismatch, out of scope. v4 `ISpoke.getLiquidationLogic()` `external pure` (`C4/spoke/interfaces/ISpoke.sol:730–731`), matches `Spoke.sol:640`. **Keep the getter name in all cases: it is public ABI on Pool/Spoke and tested (`Pool.t.sol:654`, `Spoke.Config.t.sol:18`).**

### 5.5 Docs (need updates only where they carry paths/FOUNDRY_LIBRARIES)

- `C4/deployments/README.md`: §2 (l.21), "LiquidationLogic Pre-deployment" (ll.41–50) incl. upstream-dialect `FOUNDRY_LIBRARIES=src/spoke/libraries/LiquidationLogic.sol:...` (l.50).
- `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md`: Step B (ll.126–166, Crane-path `FOUNDRY_LIBRARIES` at ll.142, 164), script table (l.274), troubleshooting (l.314), changelog (l.369).
- `lib/crane/docs/deployment/BC_GREENFIELD_DEPLOYMENT_PRD.md` (ll.243, 631, 645), `BC_GREENFIELD_PHASE_DEPLOY_STEPS.md` (l.234), `BC_GREENFIELD_DEPLOY_RESEARCH.md` (l.306), `BC_GREENFIELD_SCRIPT_GUIDE.md` (l.314), `BC_GREENFIELD_GAP_REPORT.md` (ll.267, 275, 291), `lib/crane/docs/superpowers/plans/2026-07-23-bc-greenfield-deploy-scripts.md` (l.697).
- Symbol-only mentions (no path): `lib/crane/docs/protocols/lending.md` (ll.32, 119), `lib/crane/docs/development/testing.md` (l.249), skill `.claude/skills/aave-v4-liquidation/SKILL.md` (example `library LiquidationLogic` ll.106–133, upstream `src/spoke/...` reference paths ll.408–409). Under Option A these can stay; under Option B the skill example and lending.md symbol references should be revisited.
- Archive: `lib/crane/docs/archive/internal-plans/AAVE_DEPS_INVENTORY.md` (ll.97, 128) — historical; do not rewrite as current law.
- IndexedEx plan doc `contracts/protocols/lending/aave/cross-version/AAVE_CROSS_VERSION_LOOP_VAULT_PLAN.md` (ll.47–86) describes the `vm.getCode`/creationCode harness history — informational.
- Generated evidence/manifests mentioning the filename (do **not** hand-edit; regenerate if needed): `docs/security/universal-detf-audit/evidence/source-manifest.json`, `docs/research/apex-stage2-review/recurrence-20261007/evidence/source-before-build.json`, `docs/audits/apex-2026-09-17-evidence/followup-review/*.json`, `implementation-artifacts/detf-funded-staking/**.json`.
- Frontend (`frontend/`): zero matches. IndexedEx `scripts/` (shell/py): zero path matches for the library; but see `scripts/forge-artifacts.py` behavior below.

### 5.6 Tooling

- `scripts/forge-artifacts.py`: `resolve_artifact` (ll.157–171) raises on ambiguous artifact IDs (`resolves to N sources`) — today `LiquidationLogic.sol:LiquidationLogic` is ambiguous repo-wide; after a filename-only rename, `LiquidationLogicAaveV4.sol:LiquidationLogic` resolves uniquely **even with the symbol unchanged**, because resolution keys on file basename + declared contract name. `library_artifacts` (ll.198–212) reads existing `bytecode.linkReferences` — stale pre-rename artifacts naming the old source unit will fail planning until dependents are rebuilt (ARTIFACT_BUILDS.md l.53: renamed sources must be supplied explicitly). Do **not** delete `out/`/`cache_forge/` to clear this (CLAUDE.md #9); rebuild concrete dependents instead.

## 6. Option analysis: filename-only (A) vs file+symbol rename (B)

### Option A — rename files only; keep `library LiquidationLogic` in both

Changes required: every row in §5.1 (import paths), §5.3 (string IDs, placeholder re-derivation, FOUNDRY_LIBRARIES text), §5.4 transitive rebuild, doc path updates (§5.5), and removal of the TestBase bypass + seed/loader comment corrections (§4).

Preserved:
- **Economics**: identical code bodies → identical liquidation math, thresholds, bonus curves. (fact)
- **Storage**: both are stateless libraries operating on caller storage via DELEGATECALL; no storage layout exists to change. Pool/Spoke storage untouched. (fact)
- **ABI of Pool/Spoke**: all function selectors unchanged, incl. `getLiquidationLogic()`; library external selectors unchanged (symbol unchanged). (fact)
- `type(LiquidationLogic).name`, `.creationCode` call sites keep compiling unmodified.
- `scripts/forge-artifacts.py` ambiguity disappears for path-qualified IDs.
- Echidna config (symbol-keyed) untouched.

Still true after Option A:
- **Bytecode changes anyway** (metadata hash + placeholder hash; §3 items 5–6) → new CREATE2/CREATE3 addresses for the libraries, `Pool`, `Spoke`/`SpokeInstance` on any redeploy; `FOUNDRY_LIBRARIES` addresses must be regenerated per environment; salts themselves (name-hash salts, `bytes32(0)` CREATE2 salt, `AAVE_V3_LIBRARIES_BATCH`) are unchanged inputs, but resulting addresses change because initcode changed. Existing deployments keep their embedded library addresses. (fact + inference I3)
- Bare-name lookups (`vm.getCode("LiquidationLogic")`) would remain ambiguous in spirit (two `library LiquidationLogic` declarations); all current callers are path-qualified — keep it that way (recommendation R1).
- Upstream-divergence: filenames no longer match Aave upstream repos (`src/protocol/libraries/logic/LiquidationLogic.sol`, `src/spoke/libraries/LiquidationLogic.sol`). `crane-porting` SKILL.md requires "byte-for-logic equivalent to a pinned upstream tag" for domain contracts (ll.13–22); a rename is a deliberate deviation that should be recorded in the relevant VENDOR.md/adaptation notes (R2). (The v4 tree has no visible VENDOR.md in the deployments dir listing; locating/recording pins is a PRD task.)

### Option B — rename files AND symbols (`library LiquidationLogicAaveV3` / `LiquidationLogicAaveV4`)

Everything in Option A, **plus**:
- All §5.2 qualified references rewritten (~200 sites incl. test structs/constants, `using` directives, `address(...)`, `type(...)`).
- **v4 library external selector change (verified from Solidity docs):** external library function selectors use an internal naming schema where "non-storage structs are referred to by their fully qualified name, i.e. `C.S`" (Solidity docs v0.8.37, "Contracts > Libraries > Function Signatures and Selectors in Libraries", accessed 2026-10-12). `liquidateUser(…, LiquidateUserParams memory)` (l.197–210) therefore has selector computed over `LiquidationLogic.LiquidateUserParams`; renaming the symbol **changes `liquidateUser`'s selector**. `notifyReportDeficit` (mappings + scalars, l.265) and `calculateLiquidationBonus` (uint256s, l.313) are unaffected. Spoke.sol is compiled against the library so internal consistency holds on rebuild, but: any off-chain integration, fork test, or deployed Spoke calling the old library address by old selector breaks silently (DELEGATECALL to a selector that no longer exists → fallback/revert). (fact about schema; consequence is inference I4, high confidence)
- v3.6 external selectors (`executeLiquidationCall`, `executeEliminateDeficit`) take `DataTypes.*` structs — **unaffected** by renaming `LiquidationLogic` itself (fact, from same doc + signatures at ll.77, 162).
- Echidna config (§5.3) must change.
- Getter **names** stay (`getLiquidationLogic`) but return values on redeploy point at newly-addressed libraries — same as Option A.
- Higher regression surface for zero disambiguation benefit beyond what Option A already delivers (the artifact collision is keyed on **filenames**, not symbols — Foundry writes `out/<file>/<contract>.json`).

**Recommendation R3: Option A (filename-only).** It fully removes the artifact collision and the bypass; Option B buys symbol-level clarity at the cost of a v4 library selector change, an echidna config change, ~200 extra edits, and larger upstream divergence — with no additional artifact-safety benefit. If symbol disambiguation is later desired for reader clarity, prefer import aliases (`import {LiquidationLogic as LiquidationLogicV4} …`) at call sites rather than declaration renames, which preserves selectors while improving readability (recommendation R4, optional).

## 7. Salt / address impact summary (both options)

| Item | Salt input | Initcode changes? | Address on redeploy |
|------|-----------|-------------------|---------------------|
| v4 `LiquidationLogic` via `SpokeBytecodeLinker`/`SpokeDeployUtils` CREATE2 | `bytes32(0)` (`SpokeBytecodeLinker.sol:17`) | **Yes** (metadata+path) | New address; `FOUNDRY_LIBRARIES` must be regenerated per chain/env |
| v3.6 `LiquidationLogic` via `AaveV3LibrariesBatch2` CREATE2 | `bytes("AAVE_V3_LIBRARIES_BATCH")._hash()` (shared with 3 sibling libs, l.27) | Yes (this library only) | New address; sibling libraries' addresses unchanged if untouched |
| `Pool` (v3.6) | existing deploy flow | Yes (placeholder hash + metadata) | New address on redeploy; existing Pools keep old embedded library address |
| `SpokeInstance` (v4) | derived via `_deriveSalt`/`_deriveChildSalt` (deployments README) | Yes | New address on redeploy |
| IndexedEx CREATE3 library linking via `ArtifactCreationCode._linkSource` | `abi.encode("lib/crane/.../<file>:<Name>")._hash()` (ll.126–131) | Yes | **New salt input → new CREATE3 identity** for the library (the identity string contains the filename). Occupied-identity reuse means hermetic tests redeploy cleanly; any recorded address books change. |

No storage migration exists anywhere in scope; the libraries hold no state.

## 8. Residual / out-of-scope hazards discovered

- **Same collision class nearby:** `WadRayMath.sol`, `PercentageMath.sol`, `MathUtils.sol` exist in BOTH `v3.6/protocol/libraries/math/` and `v4/libraries/math/` (verified by glob). These are internal/pure libraries (no external link placeholders), but their artifact JSONs share basenames exactly like `LiquidationLogic.sol`. This rename PRD should NOT sweep them in; file a follow-up inventory. (H1)
- `SpokeDeployUtils.getLibraryString` emits the upstream `src/spoke/...` dialect that matches neither Crane nor IndexedEx roots (pre-existing; BC doc already flags it). The rename is the right moment to fix the dialect, but that is a behavior fix beyond pure rename. (H2)
- Stale `out/LiquidationLogicArtifactProbe.sol/` artifact without source (see §3.4). Ignore; do not delete `out/` per CLAUDE.md #9. (H3)
- Peer-artifact-adjacent claim I could not verify without building: whether the v4 unit suites currently compile relying on transitive visibility of `LiquidationLogic` via `Base.t.sol` (Solidity does not re-export imports; if they compile today it is because each suite's own imports resolve — `LiquidationLogic.Base.t.sol` imports the wrapper, and `Base.t.sol:85` imports the library into the shared base's scope… actual resolution needs a compile). Flagged as missing evidence M1; it does not change the rename plan (imports that name the old path must be updated regardless).

## 9. Validation acceptance criteria (proposed for the PRD)

1. Exactly one `LiquidationLogicAaveV3.sol` under `C3/protocol/libraries/logic/` and one `LiquidationLogicAaveV4.sol` under `C4/spoke/libraries/`; no file named `LiquidationLogic.sol` remains under either Aave tree. `git diff --no-index` of old vs new files shows path/header-only changes (Option A).
2. `forge build` in both repos emits `out/LiquidationLogicAaveV3.sol/LiquidationLogic.json` (ABI contains `executeLiquidationCall`) and `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json` (ABI contains `liquidateUser`); each JSON's `metadata.settings.compilationTarget` names its own new path.
3. `Pool` and `SpokeInstance` artifacts' `bytecode.linkReferences` keys name the new source units; no artifact or source contains `__$329ad157ba4e68d2f4f45d82720084bf07$__`; `SpokeBytecodeLinker.LIQUIDATION_LOGIC_PLACEHOLDER` equals the empirically re-derived value from a real compile (not a hand guess).
4. `TestBase_AaveCrossVersionLoopV4Market.sol` no longer imports `LiquidationLogic` and uses the 2-arg `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")`; the Spoke links and `spoke.getLiquidationLogic() != address(0)` passes (`Spoke.Config.t.sol:18` analog on the IndexedEx side).
5. `CraneFactoryArtifactSeed.sol` still exists (CLAUDE.md #10), its v4 import path updated, and its NatSpec no longer claims the overwrite is unavoidable. `ArtifactCreationCode.sol` ll.42–45 comment corrected.
6. Selector stability: `forge inspect` method identifiers for `Pool` and `Spoke`/`ISpoke` unchanged vs pre-rename (esp. `getLiquidationLogic()`); under Option A additionally the library's own ABI selectors unchanged.
7. v3.6 suites (`T3/protocol/pool/Pool.Liquidations*.t.sol`, `L2Pool.t.sol`, `Pool.t.sol`) and v4 suites (`T4/contracts/spoke/**`, incl. `liquidation-logic/` 12 suites) pass; cross-version loop tests consuming `TestBase_AaveCrossVersionLoopV4Market` pass after `python3 scripts/forge-artifacts.py test <renamed sources> --test-root <suites>` (ARTIFACT_BUILDS.md flow; `forge build` before `forge test`, CLAUDE.md #10).
8. BC path: `Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol` prints a Crane-dialect `FOUNDRY_LIBRARIES` line naming the new file; dry-run of `Script_BC_Phase3_Aave.s.sol` links SpokeInstance successfully (no unresolved-placeholder revert).
9. `python3 scripts/forge-artifacts.py plan` on both renamed files resolves uniquely (no "resolves to 2 sources" error); audit shows the 4-arg `creationCode` overload has no remaining callers.
10. Economics spot-check: constants in both renamed files byte-identical values (`CLOSE_FACTOR_HF_THRESHOLD=0.95e18`, `MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD=2000e8`, `HEALTH_FACTOR_LIQUIDATION_THRESHOLD=1e18`, `DUST_LIQUIDATION_THRESHOLD=1000e26`) and no function body diffs.

## 10. Uncertainty, counterarguments, protocol note

- **Protocol note (required disclosure):** while grepping repo-wide for `LiquidationLogic`, my tool returned matching lines from the three peer artifacts already present in this directory (`minimax-original.md`, `astra-original.md`, `grok-original.md`). I did not open or read those files deliberately and derived every finding above from my own reads of sources, `out/` artifacts, and Solidity docs. Two peer claims that leaked through grep output are marked here as *unverified by me* and were NOT used: (a) a claim that Option A leaves bytecode "byte-for-byte stable" — my §3.6 primary-source evidence contradicts it (metadata hash includes filenames); (b) a claim that v4 `liquidateUser`'s selector depends on the struct's qualified name — I independently confirmed this from Solidity docs before relying on it (§6 Option B). Where my conclusions overlap with leaked fragments, the evidence trail above stands alone.
- **Missing evidence:** M1 (v4 suite transitive-import compile behavior, §8); M2: exact Foundry 1.5.1 disambiguation algorithm (which file wins the short slot) — inferred from observed `out/` states, not from compilers source read; M3: whether any live/mainnet deployment exists whose addresses must be preserved (the repo docs describe testnet BC deploys only) — if mainnet state exists, the address-change rows in §7 become migration items.
- **Counterargument to my recommendation:** Option B gives globally unique symbols, eliminating the residual "two `library LiquidationLogic` declarations" confusion for humans and any future name-only tooling. If the owner values that over selector stability and diff minimality, Option B is viable but must ship with the echidna config update, the `.env` regex update (§5.3), and a redeploy/migration note for the v4 library selector change.
- Confidence: inventory completeness high (grep-verified, 75 files scanned, all `.sol`/script/doc hits enumerated); collision mechanics high (first-party comments + direct `out/` ABI inspection); Foundry-internal mechanism (I1) medium-high; selector-change claim for Option B high (primary doc).

## 11. Source citations

- Repo files: all paths/line numbers as cited inline (verified 2026-10-12).
- Solidity docs v0.8.37 (Context7 `/websites/soliditylang_en_v0_8_37`, accessed 2026-10-12): Library Linking (`using-the-compiler.html`), Libraries / Function Signatures and Selectors in Libraries (`contracts.html`), Contract Metadata (`metadata.html`), ABI specification (`abi-spec.html`).
- Repo docs: `CLAUDE.md` (#9, #10), `docs/testing/ARTIFACT_BUILDS.md`, `docs/factory-service-artifact-creation-bytecode.md` (+`.plan.md`), `docs/agent/INDEXEDEX_AGENT_LAW.md:327`, `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md`, `C4/deployments/README.md`, `lib/crane/.claude/skills/crane-porting/SKILL.md`, `lib/crane/.claude/skills/aave-v4-liquidation/SKILL.md`.
