# Independent first-pass findings: Aave LiquidationLogic rename (Crane v3.6 + v4)

- **Author:** MiniMax M3 (`council-minimax` / `minimax/MiniMax-M3`)
- **Mode:** Independent first pass. Peer artifacts (`astra-original.md`, `grok-original.md`) in the same directory exist but are **not** read here.
- **Scope:** Inventory, filename-only vs symbol-rename assessment, Artifact Seed verification, validation acceptance criteria. **No shell, code execution, edits, deletes, or moves.**
- **Date / context:** Repository at `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex`. Working directory is the IndexedEx monorepo with `lib/crane` vendored as a submodule. Project agent router: root `CLAUDE.md` + `INDEXEDEX_AGENT_LAW.md`.

---

## 1. Target files (the rename subject)

| # | Absolute path | Library symbol | Pragma | Notes |
|---|---|---|---|---|
| 1 | `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol` | `library LiquidationLogic` | `^0.8.10` (line 2) | 602 lines; constants `DEFAULT_LIQUIDATION_CLOSE_FACTOR`, `CLOSE_FACTOR_HF_THRESHOLD`, `MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD`, `MIN_LEFTOVER_BASE` (lines 44–65). Functions: `executeEliminateDeficit` (line 77), `executeLiquidationCall` (line 162), plus `internal` helpers `_burnCollateralATokens`, `_burnDebtTokens`, `_calculateAvailableCollateralToLiquidate`, `_burnBadDebt`. |
| 2 | `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol` | `library LiquidationLogic` | `^0.8.20` (line 2) | 782 lines; constants `HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18` (line 185), `DUST_LIQUIDATION_THRESHOLD = 1000e26` (line 188). Function surface: `liquidateUser` (line 197), `notifyReportDeficit` (line 265), `calculateLiquidationBonus` (line 313), plus `internal` `_executeLiquidation`, `_liquidateCollateral`, `_liquidateDebt`, `_validateLiquidationCall`, `_calculateLiquidationAmounts`, `_calculateCollateralToLiquidate`, `_calculateDebtToLiquidate`, `_calculateDebtToTargetHealthFactor`, `_evaluateDeficit`. Many public structs (`LiquidateUserParams`, `ExecuteLiquidationParams`, …, `LiquidationAmounts`, lines 35–182). |

**Both files declare `library LiquidationLogic`** with no AaveV3/AaveV4 prefix in the symbol. This is the source of the user's request.

Both files live under the `src = 'contracts'` Foundry root of Crane (`lib/crane/contracts/...`). IndexedEx's `src` root is `contracts/`, so the remapping `@crane/contracts/` is what indexes them into IndexedEx's compilation graph.

---

## 2. The "Artifact Seed" workaround (user's term, verified)

The user's "Artifact Seed" is unambiguously **`contracts/utils/foundry/CraneFactoryArtifactSeed.sol`**. Evidence:

- **File:** `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` (64 lines).
- **Doc-comment lines 32–38:** "Src compile root for Crane implementations IndexedEx FactoryServices deploy. Naming `LiquidationLogic` here does not keep its artifact. Aave v3.6 has the same filename and overwrites `out/LiquidationLogic.sol/`. Spoke linking must use the compiler creation code, not that file."
- **Mechanism:** The library body (line 40) is `library CraneFactoryArtifactSeed` with a single function `artifactNames()` that returns `string.concat(type(...).name, type(...).name, ...)` for many types. The v4 `LiquidationLogic` import is at line 28 and its name is appended at line 59 via `type(LiquidationLogic).name`. There is **no runtime bytecode here**; the contract exists solely so that compiling this source keeps the v4 `LiquidationLogic` import in the IndexedEx `src` graph and emits a `LiquidationLogic.json` artifact into `out/LiquidationLogic.sol/`.
- **Why it fails to keep the artifact:** Foundry writes one `out/<File.sol>/<ContractName>.json` per source filename. Both Aave v3.6 and v4 have a file named `LiquidationLogic.sol`; whichever compiles last (in the current build order) overwrites the other at `out/LiquidationLogic.sol/LiquidationLogic.json`.
- **Self-acknowledgment of the workaround:** The Artifact Seed's NatSpec explicitly states that Foundry's collision requires consumers to bypass the on-disk artifact and pass the compiler's creation code directly.
- **Confirmation from the actual consumer:** `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol` lines 81–88 carries comments "v3.6 LiquidationLogic.sol steals out/LiquidationLogic.sol/. Pass the compiler's v4 creation code so that overwrite cannot unlink Spoke." and passes `type(LiquidationLogic).creationCode` into the linker manually with library ID `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic`. This is the bypass that exists only because of the filename collision.
- **Other seed files in the same shape:** `contracts/utils/foundry/UniswapV4DetfFactoryArtifactSeed.sol` exists for an unrelated purpose (Uni V4 DETF) and is not part of this rename.

The Artifact Seed is **not a Crane-native helper**. It is a project-local IndexedEx workaround authored in `contracts/utils/foundry/`.

**`CLAUDE.md` non-negotiable #10** explicitly forbids deleting this file: "Do not delete `contracts/utils/foundry/CraneFactoryArtifactSeed.sol`. Do not import it from TestBases or FactoryServices." The rename is therefore the lever for safely *unimporting* it from `TestBase_AaveCrossVersionLoopV4Market.sol` (and from any IndexedEx FactoryService that references v4 `LiquidationLogic` through it). The file itself is not deleted in this rename; the rename eliminates the reason it must exist.

---

## 3. Why the rename fixes the collision (root cause, in plain terms)

Foundry's artifact loader (`ArtifactCreationCode.sol`, lines 153–194) uses Foundry's `out/<file>/<name>.json` convention. With both files named `LiquidationLogic.sol`, two compile targets share one slot at `out/LiquidationLogic.sol/LiquidationLogic.json`. Either:

1. Renaming both files (the user's request, e.g. `AaveV3LiquidationLogic.sol` / `AaveV4LiquidationLogic.sol`) yields `out/AaveV3LiquidationLogic.sol/AaveV3LiquidationLogic.json` and `out/AaveV4LiquidationLogic.sol/AaveV4LiquidationLogic.json`. **No collision.** The Artifact Seed becomes unnecessary and its workaround in the TestBase can be replaced with the normal `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")` call.
2. Or, renaming only the file while keeping `library LiquidationLogic` as the Solidity symbol **preserves** the v3.6 `type(LiquidationLogic).creationCode` and `address(LiquidationLogic)` references used by `Pool.sol` line 868 and `Spoke.sol` line 641.

---

## 4. Filename-only vs symbol rename — explicit assessment

The user wrote "with AaveV3/AaveV4 suffixes" — that targets **filenames**, not library symbols. The PRD/impl plan must pick:

### Option A — Filename only (least invasive, preserves ABI and bytecode names)

| Property | Effect |
|---|---|
| v3.6 file path | `.../libraries/logic/LiquidationLogic.sol` → `.../libraries/logic/AaveV3LiquidationLogic.sol` |
| v4 file path | `.../libraries/logic/LiquidationLogic.sol` → `.../libraries/libraries/AaveV4LiquidationLogic.sol` |
| Library symbol | **stays `library LiquidationLogic`** in both files |
| `address(LiquidationLogic)` | unchanged (`Pool.sol:868`, `Spoke.sol:641`) |
| `type(LiquidationLogic).name` | unchanged ("LiquidationLogic"). `CraneFactoryArtifactSeed.sol:59` keeps emitting it. |
| `type(LiquidationLogic).creationCode` | unchanged. `AaveV3LibrariesBatch2.sol:30` and the TestBase linker at `TestBase_AaveCrossVersionLoopV4Market.sol:87` keep working with no other source edit. |
| `getLiquidationLogic()` ABI selector | unchanged. v3.6 `IPool.sol:804` and v4 `ISpoke.sol:731` selectors unchanged. |
| Struct / event / error selectors inside each library | **unchanged** — ABI per library is preserved. |
| `out/` artifact path | `out/AaveV3LiquidationLogic.sol/LiquidationLogic.json` and `out/AaveV4LiquidationLogic.sol/LiquidationLogic.json`. Collision gone. |
| Spoke solc link placeholder | **changes** because solc hashes source filenames into its `__$<hash>$__` placeholders. The current placeholder is `__$329ad157ba4e68d2f4f45d82720084bf07$__` (`SpokeBytecodeLinker.sol:15`). After rename it will be different. Must be re-derived empirically and replaced in `SpokeBytecodeLinker.LIQUIDATION_LOGIC_PLACEHOLDER`. |
| Spoke `FOUNDRY_LIBRARIES` env string | **must change** to `contracts/protocols/lending/aave/v4/spoke/libraries/AaveV4LiquidationLogic.sol:LiquidationLogic:0x<addr>` everywhere it's printed. |
| Foundry `forge build --force` | required after rename (compiler link references change). |

### Option B — File + library symbol rename to `library AaveV3LiquidationLogic` / `library AaveV4LiquidationLogic`

| Property | Effect |
|---|---|
| All file-path effects above | same as Option A |
| Library symbol | renamed in both files |
| `address(LiquidationLogic)` (Pool:868, Spoke:641) | must change to `address(AaveV3LiquidationLogic)` / `address(AaveV4LiquidationLogic)`. ABI selector `getLiquidationLogic()` unchanged; **the *value returned* changes** for new deployments. |
| All qualified type references | `LiquidationLogic.executeLiquidationCall(...)`, `LiquidationLogic.MIN_LEFTOVER_BASE`, `LiquidationLogic.DUST_LIQUIDATION_THRESHOLD`, struct refs, etc. — must be rewritten. **190+ qualified symbol references** identified (see §6 below). |
| `getLiquidationLogic()` | **Keep name** — keep ABI selector — but its body returns the new symbol. ABI on the proxy is unchanged. |
| Tests (v3.6 `Pool.Liquidations.t.sol`, v4 `LiquidationLogic.*.t.sol`) | many `LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD`-style refs need rewriting, plus struct names (`LiquidationLogic.LiquidationAmounts`, etc.). High touch count. |
| `CraneFactoryArtifactSeed.sol:59` | `type(LiquidationLogic).name` → `type(AaveV4LiquidationLogic).name` (or remove the import entirely once the collision is gone). |
| `AaveV3LibrariesBatch2.sol:30` | `type(LiquidationLogic).creationCode` → `type(AaveV3LiquidationLogic).creationCode`. |
| `TestBase_AaveCrossVersionLoopV4Market.sol:15,87` | import + `type(LiquidationLogic).creationCode` rewritten; libraryId string rewritten. |

### Recommendation carried into the PRD

The user phrasing — "with AaveV3/AaveV4 suffixes" — is ambiguous between filename and symbol, and the term "suffix" applies to both. **The PRD should explicitly choose Option A (filename-only) or Option B (filename + symbol)**, with reasoning. Both are workable; Option A is the smallest blast radius for ABI, library linker behavior, struct/event/error selectors and `type().creationCode`/`type().name` consumers. Option B is cleaner symbolically but touches every qualified call site.

**Recommendation:** default to **Option A (filename-only)** unless the user wants the symbol rename. ABI, linkage and struct selectors are load-bearing for downstream consumers and the v4 Spoke/solc link placeholder path is the only *forced* rewrite either way. Document Option B as the explicit follow-up if naming consistency is required.

---

## 5. Imports inventory (must-touch file paths)

### Crane production imports

| File | Line | Statement |
|---|---|---|
| `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol` | 13 | `import {LiquidationLogic} from "../libraries/logic/LiquidationLogic.sol";` |
| `lib/crane/contracts/protocols/lending/aave/v3.6/helpers/LiquidationDataProvider.sol` | 12 | `import {LiquidationLogic} from "../protocol/libraries/logic/LiquidationLogic.sol";` |
| `lib/crane/contracts/protocols/lending/aave/v3.6/deployments/projects/aave-v3-libraries/AaveV3LibrariesBatch2.sol` | 11–13 | `import {LiquidationLogic} from "@crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol";` |
| `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol` | 21 | `import {LiquidationLogic} from "@crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol";` |

### Crane test imports (Crane-side)

| File | Line | Statement |
|---|---|---|
| `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/helpers/LiquidationHelper.sol` | 8 | imports v3.6 `LiquidationLogic` |
| `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.Liquidations.CloseFactor.t.sol` | 32 | imports v3.6 `LiquidationLogic` |
| `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.Liquidations.t.sol` | 36 | imports v3.6 `LiquidationLogic` |
| `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/L2Pool.t.sol` | 16 | imports v3.6 `LiquidationLogic` |
| `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.t.sol` | — | uses `pool.getLiquidationLogic()` selector (line 654–656) |
| `lib/crane/test/foundry/spec/protocols/lending/aave/v4/setup/Base.t.sol` | 85 | imports v4 `LiquidationLogic` |
| `lib/crane/test/foundry/spec/protocols/lending/aave/v4/helpers/mocks/LiquidationLogicWrapper.sol` | 10 | imports v4 `LiquidationLogic` (wraps every library function) |
| All `lib/crane/test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.*.t.sol` (12 files) | 4 | `import "@crane/test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.Base.t.sol";` — path-sensitive. **Do not rename `liquidation-logic` directory** if filename-only rename chosen. |
| `lib/crane/test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/liquidation/Spoke.LiquidationCall.Base.t.sol` | 4 | imports v4 test Base |
| `lib/crane/test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/liquidation/Spoke.LiquidationCall.Dust.t.sol` | — | uses `LiquidationLogic.DUST_LIQUIDATION_THRESHOLD` |
| `lib/crane/test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/misc/Spoke.Getters.t.sol` | 114, 152 | calls `LiquidationLogic.calculateLiquidationBonus({...})` |
| `lib/crane/test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/configuration/Spoke.Config.t.sol` | 18 | asserts `instance.getLiquidationLogic() != address(0)` |

### IndexedEx production imports (project-local; affected by `out/` collision)

| File | Line | Statement |
|---|---|---|
| `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` | 28 | `import {LiquidationLogic} from "@crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol";` |
| `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol` | 15 | `import {LiquidationLogic} from "@crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol";` |

### IndexedEx-deploy-script references to the artifact string

- `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol:81–88` — the only currently-active IndexedEx-site consumer of `ArtifactCreationCode.creationCode(...)` that passes the v4 library ID and creation code explicitly. After the rename, this site can collapse to the normal factory-aware loader.

(Other search hits for `LiquidationLogic` in `implementation-artifacts/`, `docs/audits/`, `docs/security/`, `docs/plans/records/` are JSON evidence caches produced by prior research/audit tooling. They reference filenames in their string fields and would need a separate "regenerate manifest" pass after the rename; they are not source.)

---

## 6. Qualified-symbol inventory (changes only if Option B)

### v3.6 qualified references (`LiquidationLogic.X`)

- `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol:312` — `LiquidationLogic.executeLiquidationCall(...)`
- `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol:768` — `LiquidationLogic.executeEliminateDeficit(...)`
- `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol:868` — `return address(LiquidationLogic);`
- `lib/crane/contracts/protocols/lending/aave/v3.6/helpers/LiquidationDataProvider.sol` — `LiquidationLogic.MIN_LEFTOVER_BASE` (lines 202, 203, 206, 207, 211, 212), `LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD` (lines 302, 303), `LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD` (line 304), `LiquidationLogic.DEFAULT_LIQUIDATION_CLOSE_FACTOR` (line 307)
- `lib/crane/contracts/protocols/lending/aave/v3.6/deployments/projects/aave-v3-libraries/AaveV3LibrariesBatch2.sol:30` — `type(LiquidationLogic).creationCode`
- `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/helpers/LiquidationHelper.sol:61` — `LiquidationLogic._calculateAvailableCollateralToLiquidate(...)`
- `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.Liquidations.CloseFactor.t.sol:90,108,126,150,153,160,166` — `LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD`

### v4 qualified references (`LiquidationLogic.X`)

- `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:87` — `LiquidationLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD`
- `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:91` — `LiquidationLogic.DUST_LIQUIDATION_THRESHOLD`
- `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:354` — `LiquidationLogic.LiquidateUserParams`
- `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:366` — `LiquidationLogic.liquidateUser({...})`
- `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:376` — `LiquidationLogic.notifyReportDeficit(...)`
- `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:621` — `LiquidationLogic.calculateLiquidationBonus({...})`
- `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:641` — `return address(LiquidationLogic);`
- `lib/crane/test/foundry/spec/protocols/lending/aave/v4/helpers/mocks/LiquidationLogicWrapper.sol` — wraps every `LiquidationLogic.*` function and struct (lines 136–253)
- `lib/crane/test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.*.t.sol` — extensive struct use (`LiquidationLogic.LiquidationAmounts`, `LiquidationLogic.CalculateLiquidationAmountsParams`, `LiquidationLogic.DUST_LIQUIDATION_THRESHOLD`, …). Sample of file paths and line counts already enumerated in §5.
- `lib/crane/test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/liquidation/Spoke.LiquidationCall.Base.t.sol` — uses `LiquidationLogic.CalculateLiquidationAmountsParams`, `LiquidationLogic.LiquidationAmounts`, `LiquidationLogic.CalculateDebtToTargetHealthFactorParams` (lines 99, 102, 137, 139, 159, 161, 569, 623, 681)
- `lib/crane/test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/liquidation/Spoke.LiquidationCall.Dust.t.sol` — `LiquidationLogic.DUST_LIQUIDATION_THRESHOLD` (lines 79, 130, 192, 238)
- `lib/crane/test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/misc/Spoke.Getters.t.sol` — `LiquidationLogic.calculateLiquidationBonus({...})` (lines 114, 152)

Total qualified references across both libraries ≈ **190 occurrences** (per grep summary). Rename only matters if Option B is chosen.

---

## 7. Artifact IDs, link placeholders, deploy scripts

### Foundry `FOUNDRY_LIBRARIES` strings (must rewrite to the new path)

| File | Line | Current value | Required change |
|---|---|---|---|
| `lib/crane/contracts/protocols/lending/aave/v4/deployments/utils/libraries/SpokeBytecodeLinker.sol` | 21 | `"contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic"` (used by `VM.getCode(LIB_ARTIFACT_PATH)` on line 29) | path component to the new filename; `LiquidationLogic` contract-name part is unchanged under Option A, changes under Option B |
| `lib/crane/contracts/protocols/lending/aave/v4/deployments/utils/libraries/SpokeBytecodeLinker.sol` | 37 | `"FOUNDRY_LIBRARIES=contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:"` | same |
| `lib/crane/test/foundry/spec/protocols/lending/aave/v4/scripts/utils/SpokeDeployUtils.sol` | 22 | `"contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol:LiquidationLogic"` (passed to `vm.getCode`) | same |
| `lib/crane/test/foundry/spec/protocols/lending/aave/v4/scripts/utils/SpokeDeployUtils.sol` | 30 | `"src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:"` (this is the upstream-path dialect written by `getLibraryString`; it does **not** work for Crane-root or IndexedEx-root invocations) | comment in BC_AAVE_V4_DEPLOY_STEPS.md:145 already calls this out: "Vendored `SpokeDeployUtils.getLibraryString` still emits `src/spoke/...` — fix for Crane remapping in the BC script (hardcoded correct path)." Two dialects exist. |
| `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md` | 142, 164 | inline env-line strings | both must match the new path |
| `lib/crane/contracts/protocols/lending/aave/v4/deployments/README.md` | 50 | `FOUNDRY_LIBRARIES=src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:0x<address>` (upstream dialect) | operator-visible doc; must match the new path |

### solc link placeholder (changes for filename-only too)

- File: `lib/crane/contracts/protocols/lending/aave/v4/deployments/utils/libraries/SpokeBytecodeLinker.sol:15`
- Constant: `string internal constant LIQUIDATION_LOGIC_PLACEHOLDER = "__$329ad157ba4e68d2f4f45d82720084bf07$__";`
- Used at line 47: `string memory linked = _replaceAll(object, LIQUIDATION_LOGIC_PLACEHOLDER, addrHex);`
- **Derivation:** solc emits placeholders of the form `__$<keccak256(source_path)$__`. Renaming the file changes the source path → different keccak → different placeholder. Must re-derive empirically by compiling `SpokeInstance` with the new file path and reading the placeholder from `out/SpokeInstance.sol/SpokeInstance.json`. Do not guess the hash.

### Foundry artifact loader (`ArtifactCreationCode.sol`)

- Lines 42–45: explicit comment `/// @dev out/LiquidationLogic.sol/LiquidationLogic.json is shared with Aave v3.6. A later v3.6 compile overwrites that file. The supplied bytecode is the library the caller compiled, so the stolen artifact cannot break linking.`
- Lines 165–193: `_artifactJson()` discovers artifacts via `out/<file>/<name>.json` and tries the most specific suffix first when a full source ID is supplied. After the rename, the file suffix disambiguates and the source-qualified lookup is no longer required for `SpokeInstance`.
- Lines 186–193: `_matchesSource(json_, id_, separator_)` cross-checks the JSON's `metadata.settings.compilationTarget` to disambiguate when two filenames overlap. After the rename this fallback is no longer triggered for the LiquidationLogic pair.

### Salt / address impact

- **CREATE2 salt for the v4 library:** `bytes32(0)` (constant `LIQUIDATION_LOGIC_SALT` in `SpokeBytecodeLinker.sol:17`; also hardcoded in `Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol:23` and `LibraryPreCompile.s.sol:40`, and in `BcAavePhase3Deploy.sol:65` for V4_SALT = `keccak256("crane-bc-aave-v4-v1")` is the market-level salt — different scope, unrelated to the library).
- **Library address:** derived from `keccak256(0xff ++ factory ++ 0x00 ++ keccak256(0x00 ++ bytes32(0)) ++ keccak256(initcode))`. The initcode is the v4 `LiquidationLogic` bytecode, which is **byte-for-byte stable** under Option A (no Solidity source change → identical initcode → identical deployed library address). Under Option B, the library bytecode changes (`library AaveV4LiquidationLogic { … }` has the same source but different metadata-derived bytecode hash; Foundry's metadata hash and any leading run-time constants derived from the source name would shift). **Existing on-chain library addresses stay valid under Option A; they become orphaned under Option B and require redeployment.**
- **Spoke creation bytecode:** linked with `__$<hash>$__` and `FOUNDRY_LIBRARIES`. New deploys must be re-linked against the **new** library address on Option B; on Option A, redeploys link to the same address, so previously-deployed Spoke instances continue to call the same library at the same address — no migration needed.
- **CRANE-v3.6 pool/proxy creation code:** `AaveV3LibrariesBatch2.sol:30` does `Create2Utils._create2Deploy(salt, type(LiquidationLogic).creationCode)`. Same analysis: bytecode changes only under Option B, so the v3.6 pool library address stays stable under Option A.
- **`getLiquidationLogic()` return value:** under Option A, `Pool.getLiquidationLogic()` and `Spoke.getLiquidationLogic()` keep returning the existing library address; under Option B they return the new address on redeployed contracts only.

### Build / deploy scripts

- `lib/crane/scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol` — pre-deploys library + prints `FOUNDRY_LIBRARIES` Crane path. Path must update.
- `lib/crane/test/foundry/spec/protocols/lending/aave/v4/scripts/LibraryPreCompile.s.sol` — upstream-conventions precompile (the one referenced in `AaveV4DeployAnvil.s.sol`). The FFI sed commands grep on the **address**, not the path, so this script continues to work as long as the library is deployed and the `.env` value is updated by the path-emitting upstream code.
- `lib/crane/test/foundry/spec/protocols/lending/aave/v4/scripts/utils/SpokeDeployUtils.sol` — `vm.getCode(LIB_ARTIFACT_PATH)` and `getLibraryString` both contain the old path.
- `lib/crane/scripts/foundry/bc/BcAavePhase3Deploy.sol` — calls `deployLiquidationLogicLinkedSpoke()` (line 111) and `deployV4Core()` (line 149). Wrapper path; no direct filename references, but its comments and the linked-spoke flow depend on `SpokeBytecodeLinker`.
- `lib/crane/test/foundry/spec/protocols/lending/aave/v4/setup/Base.t.sol:85` — test base for v4 spoke tests; imports v4 `LiquidationLogic`.
- `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/utils/BatchTestProcedures.sol:285` and `TestnetProcedures.sol:196` — sed-based detection of the FOUNDRY_LIBRARIES env line; they grep on `FOUNDRY_LIBRARIES`, not the path, so they continue to function.

---

## 8. Docs to update (operational, must change)

These are operator-facing or reference docs that quote the filename in a way that will mislead if left unchanged:

- `lib/crane/contracts/protocols/lending/aave/v4/deployments/README.md` — multiple references to `LiquidationLogic` filename in §2, §3, and the placeholder note.
- `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md` — inline env-line strings at lines 142 and 164.
- `lib/crane/docs/superpowers/plans/2026-07-23-bc-greenfield-deploy-scripts.md` — mentions `LiquidationLogic` filename in the deploy script plan (line 693, 697, 706, 980). Plan-style content; not a legal PRD.
- `lib/crane/docs/protocols/lending.md` — mentions `LiquidationLogic` symbol (no filename collision). Symbol-level references do **not** need to change if symbol stays (Option A).
- `lib/crane/docs/development/testing.md` — same: symbol-level.
- `lib/crane/docs/archive/internal-plans/AAVE_DEPS_INVENTORY.md` — historical archive; do **not** rewrite. Mentions the file at line 128.

These are **non-laws** that should track the rename once approved:
- Skill files under `lib/crane/.claude/skills/aave-v4-liquidation/` (or equivalent) if they exist and reference the symbol. (Not directly verified here — only the doc-level mentions above. The `indexedex-testing`, `indexedex-launch-scripts`, and `indexedex-adversarial-testing` skill catalogues under `.claude/skills/` should be checked in cross-review.)
- The Foundry profile configurations: `lib/crane/foundry.toml` (line 8: `src = 'contracts'`; line 81–96: skip lists including `contracts/external/**` and `contracts/protocols/lending/aave/v3.6/dependencies/.../certora/**`). None of these are filename-specific and they do **not** need changes.
- The IndexedEx `foundry.toml` and `remappings.txt`: unchanged — they don't reference filenames.

---

## 9. Tests to update (if Option B)

If the symbol is renamed, every `LiquidationLogic.X` call site and every `library LiquidationLogic` consumer (including `LiquidationLogicWrapper.sol`) needs editing. The Blast radius under Option A is **zero** for symbol references, only for paths.

Test files that exercise the v4 library functions through `LiquidationLogicWrapper`:

- `LiquidationLogicWrapper.sol:136–253` — wraps every function and most structs. (Option B touches this; Option A leaves it untouched.)
- All `LiquidationLogic.*.t.sol` files (12 files in `liquidation-logic/` directory): heavily use `LiquidationLogic.<StructName>` and `LiquidationLogic.<constant>`. Option B touches all of them; Option A leaves them untouched.

The `liquidation-logic/` directory itself is a Foundry-test layout convention and does **not** need to be renamed — the directory name has no semantic dependence on the source file name (only on the test-class names).

---

## 10. Salt / address impact summary

| Scenario | Library bytecode | Library address | Spoke bytecode | Existing deployments |
|---|---|---|---|---|
| Option A (filename only) | identical | identical | identical (since library ID is unchanged under Option A — solc still keys the placeholder by file path; Spoke recompile produces the same `__$...$__` placeholder pattern with a new hash, **but the linker uses the caller-supplied bytecode**, not the on-disk artifact, so the linked bytecode is identical given the same library address) | **No migration required.** Existing v4 Spoke instances keep calling the existing library at the same address. The only post-rename step is `forge build --force` (to refresh the new placeholder hash) before the next Spoke recompile. |
| Option B (file + symbol) | different (Solidity metadata hash changes) | different on any redeploy | different (the v4 Spoke now calls a new library at a new address) | **Existing v4 Spoke instances are orphaned** — they call the old `LiquidationLogic` address but Foundry would re-link the new Spoke bytecode to the new address. v3.6 Pool proxies are similarly orphaned. A migration plan is required if any mainnet/fork state is in use. |

For IndexedEx tests, neither option requires forking.

---

## 11. What the rename does NOT touch (validation surface)

- Storage layouts inside `Pool.sol`, `Spoke.sol`, `Hub.sol`, etc. — **unchanged** (no storage variables move).
- Selectors of every external/public function in Pool/Spoke that the proxy exposes — **unchanged** (function name is unchanged). `getLiquidationLogic()` keeps its selector.
- Selectors of internal library functions (`_executeLiquidation`, `_burnDebtTokens`, etc.) — **unchanged** under Option A.
- ABI of the v4 library's structs (selector parameters need to be looked up but the struct field names/order stay).
- Pool/Spoke constructor args and bytecode hash behavior under CREATE3 — unchanged.

---

## 12. Validation acceptance criteria (the PRD must require these)

To prove the rename achieves its goals without breaking economics, ABI, or storage:

1. **Artifact collision gone** — `ls out/AaveV3LiquidationLogic.sol/AaveV3LiquidationLogic.json` and `ls out/AaveV4LiquidationLogic.sol/AaveV4LiquidationLogic.json` both exist after `forge build`; neither is missing or empty.
2. **`CraneFactoryArtifactSeed.sol` becomes removable** — after the rename, the IndexedEx `src` graph no longer needs the v4 `LiquidationLogic` import from the seed; **as a validation**, temporarily commenting out line 28 + line 59 of `CraneFactoryArtifactSeed.sol` and rebuilding must succeed for any production artifact loader to find v4 `LiquidationLogic`. The PRD should call out that the seed file is kept (per CLAUDE.md non-negotiable) but is now superfluous; deleting is a separate decision.
3. **`TestBase_AaveCrossVersionLoopV4Market.sol` works without the manual library ID/creation-code workaround** — change the linker call to `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")` (no `libraryId_`/`libraryCreationCode_` overload), build, run the test base, and confirm `setUp()` deploys `SpokeInstance` successfully with all selectors wired.
4. **All v3.6 Pool selectors reachable** — `forge inspect lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol:Pool methods` shows the same selectors as before the rename (especially `getLiquidationLogic()` returns `LiquidationLogic` symbol reference remains a placeholder).
5. **All v4 Spoke selectors reachable** — same for Spoke.
6. **Spoke deploys with v4 library link** — `forge script lib/crane/test/foundry/spec/protocols/lending/aave/v4/scripts/LibraryPreCompile.s.sol --fork-url … --ffi` succeeds and prints a non-empty `FOUNDRY_LIBRARIES` line whose path matches the new file. `forge build --force` produces a `SpokeInstance.json` whose `.bytecode.object` contains the **regenerated** solc placeholder; the linker `LIQUIDATION_LOGIC_PLACEHOLDER` constant is updated to match.
7. **Hermetic tests pass** — `forge build --force && forge test --match-path 'lib/crane/test/foundry/spec/protocols/lending/aave/v4/**' -vv`. The cross-version loop tests under `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol` pass without `FOUNDRY_LIBRARIES` set externally.
8. **No silent mock/SUT drift** — no `new LiquidationLogic()` or `MockLiquidationLogic` introduced; the production library remains the SUT (per CLAUDE.md non-negotiable #3, production-first).
9. **`getLiquidationLogic()` return value** — under Option A, `pool.getLiquidationLogic()` and `spoke.getLiquidationLogic()` return the same addresses as before on the same deployment set; under Option B, they return the new addresses (and a migration note is required for any in-state deployment).
10. **Docs refreshed** — BC deploy steps, Aave V4 deployments README, BC greenfield plan all reference the new path; archive files (`AAVE_DEPS_INVENTORY.md`) explicitly left untouched.
11. **No `forge build --sizes` regression** — v3.6 Pool/Spoke bytecode sizes do not change under Option A (same compiler input). Under Option B, expect a small metadata-derived size delta (typically ≤ a few bytes for the changed contract name in metadata).
12. **No `via_ir`** — both files compile under the existing profile; `viaIR = false` (CLAUDE.md non-negotiable #7).
13. **Symbol rename (Option B only)** — every qualified reference in §6 is updated; `forge test` greps for `LiquidationLogic\.` (qualified) in the rename targets return only the renamed symbol's name with the new prefix; no stray `LiquidationLogic.executeLiquidationCall` etc. survive in the codebase except where they belong (the library body itself, if the symbol was kept) or where intentional (the `getLiquidationLogic()` ABI name, which must remain).

---

## 13. Uncertainty / validation gaps

- **solc placeholder regeneration:** I cannot run `forge build` to derive the new `__$<hash>$__` placeholder for the renamed file. It must be re-derived empirically by anyone executing this rename. The placeholder currently in `SpokeBytecodeLinker.sol:15` (`__$329ad157ba4e68d2f4f45d82720084bf07$__`) is for the pre-rename file. The hash must be re-computed after the rename and replaced.
- **`SpokeDeployUtils.sol:30` upstream `src/spoke/...` dialect** — `BC_AAVE_V4_DEPLOY_STEPS.md:145` already flags this as a bug ("hardcoded correct path"). Whether to fix this dialect as part of this rename is a separate decision; the rename alone does not require it but leaving it produces a broken precompile output.
- **`remappings.txt` / Foundry profile drift between Crane-root and IndexedEx-root invocations** — `FOUNDRY_LIBRARIES` source-unit paths depend on which root runs `forge`. The two current dialects are Crane-root (`contracts/...`) and upstream-style (`src/spoke/...`). IndexedEx-root builds would use `lib/crane/contracts/...` (e.g. `TestBase_AaveCrossVersionLoopV4Market.sol:86` does this). The PRD should clarify which root is canonical for v4 library precompile.
- **Peer original research in `docs/research/aave-liquidation-library-rename/`** — `astra-original.md` and `grok-original.md` are present and were not read for this first pass. Cross-review will see them together.
- **Did not verify:** skill content under `lib/crane/.claude/skills/aave-v4-*/` and IndexedEx `.claude/skills/` (none of the names returned content in initial grep). Only docs and source. Cross-review should confirm no skill file embeds the filename in a way that operator-facing material would mislead.
- **Did not verify:** the exact set of every Crane-side qualified `LiquidationLogic.X` reference is reported via grep totals (≈190), not line-by-line re-checked. The §6 list is curated by sample.
- **The user's "Artifact Seed" term is verified** to point at `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` (evidence at lines 32–38 and the `type(LiquidationLogic).name` call at line 59). No other "Artifact Seed" file exists; `UniswapV4DetfFactoryArtifactSeed.sol` is a separate file with the same pattern for Uni V4 DETF and is not part of this rename.
- **The `LiquidationDataProvider.sol` helper** uses the v3.6 library's constants heavily (MIN_LEFTOVER_BASE, etc.) but does not re-export them. Renaming its qualified references is required under Option B; under Option A only the import path changes.
- **`UniswapV4DetfFactoryArtifactSeed.sol`** has the same shape and the same `LiquidationLogic` collides concern would not affect it (it imports other types, not `LiquidationLogic`). Not touched by this rename.

---

## 14. Original-finding evidence map (for cross-review quoting)

- `/lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol` (602 lines) — primary v3.6 source.
- `/lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol` (782 lines) — primary v4 source.
- `/contracts/utils/foundry/CraneFactoryArtifactSeed.sol` lines 28, 32–38, 59 — Artifact Seed workaround, self-documented.
- `/contracts/utils/foundry/ArtifactCreationCode.sol` lines 42–45, 153–194 — Foundry artifact loader collision commentary.
- `/contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol` lines 15, 81–88 — the IndexedEx-site workaround that the rename makes unnecessary.
- `/lib/crane/contracts/protocols/lending/aave/v4/deployments/utils/libraries/SpokeBytecodeLinker.sol` lines 14–21, 29–38, 43–52 — solc placeholder, artifact paths, env string.
- `/lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol` lines 21, 87, 91, 354, 366, 376, 621, 640–642 — qualified symbols + `address(LiquidationLogic)`.
- `/lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol` lines 13, 312, 768, 867–869 — qualified symbols + `address(LiquidationLogic)`.
- `/lib/crane/contracts/protocols/lending/aave/v3.6/deployments/projects/aave-v3-libraries/AaveV3LibrariesBatch2.sol` line 30 — `type(LiquidationLogic).creationCode`.
- `/lib/crane/contracts/protocols/lending/aave/v3.6/helpers/LiquidationDataProvider.sol` lines 12, 202–212, 302–307 — qualified constants.
- `/lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md` lines 142, 145, 163–164 — env-line strings + dialect note.
- `/lib/crane/contracts/protocols/lending/aave/v4/deployments/README.md` lines 27, 50, 51, 55 — operator-facing env-line + placeholder note.
- `/lib/crane/test/foundry/spec/protocols/lending/aave/v4/scripts/utils/SpokeDeployUtils.sol` lines 22, 30 — `vm.getCode(...)` and dialect string.
- `/lib/crane/test/foundry/spec/protocols/lending/aave/v4/scripts/LibraryPreCompile.s.sol` lines 6, 22–43 — upstream-conventions precompile script.
- `/lib/crane/test/foundry/spec/protocols/lending/aave/v4/helpers/mocks/LiquidationLogicWrapper.sol` lines 10, 136–253 — wrapper.
- `/lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.t.sol` lines 654–656 — `test_getLiquidationLogic`.
- `/lib/crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol` lines 801–804 — `getLiquidationLogic` interface declaration.
- `/lib/crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol` lines 730–731 — `getLiquidationLogic` interface declaration.

---

## 15. Saved path and stop

This document is the only artifact written by this first-pass session:
- `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/research/aave-liquidation-library-rename/minimax-original.md`

Returning to the moderator for cross-review. No further file/system actions taken.