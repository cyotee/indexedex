# Round 2 — PRD completeness review + implementation plan (filename-only Option A, human-approved)

- **Author:** MiniMax M3 (`council-minimax` / `minimax/MiniMax-M3`), retained original session.
- **Reused first-pass evidence:** `docs/research/aave-liquidation-library-rename/minimax-original.md` and `minimax-cross-review.md` (preserved; not rewritten).
- **Do not read** other researchers' new round outputs or earlier cross-review artifacts.
- **Mode:** Research/document only. No shell, tests, execution, source/config edits, moves, deletes.

---

## A. PRD completeness assessment

`docs/plans/aave-liquidation-library-rename/PRD.md` (170 lines) is substantially complete. Strengths: filename-only Option A locked, 12 direct imports listed, workaround location precise (TestBase call site + `ArtifactCreationCode` 4-arg overload, lines cited), toolchain concerns recorded (no via-IR, no `out/`/`cache_forge/` deletion), acceptance gates §8, non-goals §9, Council record §10 with session IDs, primary references §11.

Remaining PRD gaps that need owner input before implementation:

1. **Canonical Foundry invocation root.** PRD §5 keeps both Crane-root and IndexedEx-root path dialects but does not specify which is canonical for the BC precompile (`Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol`) and which for the IndexedEx test base. Both dialects are still emitted after the rename and must point at consistent invocation roots or operators will get an unlinkable `FOUNDRY_LIBRARIES`.
2. **Conditional 4-arg overload removal.** PRD §6.4 says "remove … once zero required callers remain; if another caller is discovered, stop for scope review". The grep + regression suite run is an implementation step. Owner should pre-approve the conditional removal so the implementation does not need a second approval cycle.
3. **Upstream `src/spoke/...` dialect fix.** PRD §5 calls for "Correct maintained operational emitters/docs to their declared supported root". `SpokeDeployUtils.sol:30` still emits `src/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic:…`, which does not match either root's remappings. PRD §9 lists "no widening" as a non-goal, but fixing this one dial is in-scope as a dialect correction, not a feature. Owner should confirm.
4. **Other Aave basename collisions** (`WadRayMath.sol`, `PercentageMath.sol`, `MathUtils.sol` exist in both `v3.6/protocol/libraries/math/` and `v4/libraries/math/`). PRD §9 explicitly excludes. Note for owner follow-up.
5. **Echidna config** (`lib/crane/test/foundry/spec/protocols/lending/aave/3.6/invariants/_config/echidna_config.yaml:52,62`): symbol binding unchanged under filename-only (per PRD §5 row). No owner input needed; verify implementation does not modify it.

---

## B. Implementation plan (filename-only, symbols retained)

### B.1 Owner questions (blocking — need explicit decision before implementation)

| Q# | Question | Default if no answer |
|---|---|---|
| Q1 | Which Foundry root is canonical for `FOUNDRY_LIBRARIES` emission in the BC precompile script? | Crane-root (`contracts/...`) — current behavior; matches `SpokeBytecodeLinker.sol:37`. |
| Q2 | Which root for the IndexedEx TestBase 2-arg `ArtifactCreationCode.creationCode` lookup? | IndexedEx-root (`lib/crane/contracts/...`) — current TestBase line 86 dialect; the 2-arg loader will use it implicitly. |
| Q3 | Approve conditional removal of `ArtifactCreationCode.creationCode(factory, artifactId, libraryId, libraryCreationCode)` 4-arg overload after zero-caller verification? | Approved with the listed gate (`grep -RE "creationCode\([^)]*libraryId" contracts/ lib/crane/contracts/ lib/crane/test/` returns zero; loader regression suite passes). |
| Q4 | Approve fixing the upstream `src/spoke/...` dialect in `SpokeDeployUtils.sol:30` to match the canonical root? | Approved. Single-line `getLibraryString` change. |
| Q5 | Note (no decision): other Aave basename collisions are out of scope. | File a follow-up inventory after this PRD ships. |

### B.2 Pre-implementation baselines (capture before any change)

Capture these in an evidence file (e.g. `docs/research/aave-liquidation-library-rename/implementation-evidence/<date>/pre-baseline.md`):

- `forge --version` and `forge config` output (executable versions; PRD §3 notes these were not measured).
- `solc --version` output (sanity-check 0.8.35).
- `python3 scripts/forge-artifacts.py resolve "LiquidationLogic.sol:LiquidationLogic"` (must currently report 2 sources).
- `forge inspect lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol:Pool methods | sort` and the same for v4 `Spoke.sol`.
- `forge inspect ... StorageLayout` for `Pool.sol` and `Spoke.sol` (must be unchanged after rename).
- `forge inspect lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol:LiquidationLogic deployedBytecode | head -c 64` and same for v4 — initcode head before; compare after.
- Worktree cache seed: `rsync -a "${WARM}/cache_forge/" "${WT}/cache_forge/"` and `rsync -a "${WARM}/out/" "${WT}/out/"` if working in a fresh worktree (CLAUDE.md #9).

### B.3 File renames (ordered; do these first)

1. `git mv lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol`
2. `git mv lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol`
3. Verify with `find lib/crane/contracts/protocols/lending/aave -name "LiquidationLogic*.sol"` — exactly two files, neither named `LiquidationLogic.sol`.

### B.4 Import path updates (12 sites from PRD §4)

Order matters: do Crane v3.6 production first, then v3.6 tests, then v4 production, then v4 tests, then IndexedEx production. Per PRD §4:

| # | File | Line | New path |
|---|---|---:|---|
| 1 | `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol` | 13 | `../libraries/logic/LiquidationLogicAaveV3.sol` |
| 2 | `lib/crane/contracts/protocols/lending/aave/v3.6/helpers/LiquidationDataProvider.sol` | 12 | `../protocol/libraries/logic/LiquidationLogicAaveV3.sol` |
| 3 | `lib/crane/contracts/protocols/lending/aave/v3.6/deployments/projects/aave-v3-libraries/AaveV3LibrariesBatch2.sol` | 11–13 | `@crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol` |
| 4 | `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/helpers/LiquidationHelper.sol` | 6–8 | retarget |
| 5 | `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.Liquidations.CloseFactor.t.sol` | 31–32 | retarget |
| 6 | `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.Liquidations.t.sol` | 35–36 | retarget |
| 7 | `lib/crane/test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/L2Pool.t.sol` | 14–16 | retarget |
| 8 | `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol` | 21 | `@crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol` |
| 9 | `lib/crane/test/foundry/spec/protocols/lending/aave/v4/setup/Base.t.sol` | 85 | retarget |
| 10 | `lib/crane/test/foundry/spec/protocols/lending/aave/v4/helpers/mocks/LiquidationLogicWrapper.sol` | 10 | retarget |
| 11 | `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` | 28 | `@crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol` |
| 12 | `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol` | 15 | **Remove** (call site deleted, see B.5) |

### B.5 Workaround removal (coupled, per cross-review finding)

**a)** `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol`:
- Delete the `import {LiquidationLogic} …` line (line 15).
- Delete lines 81–88 (overwrite comment + 4-arg `creationCode` call).
- Replace the Spoke bytecode argument at lines 83–88 with `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")` (2-arg form).
- Remove the `type(LiquidationLogic).creationCode` reference. The 4-arg overload is no longer called here.

**b)** `contracts/utils/foundry/ArtifactCreationCode.sol` — conditional removal:
- After (a), verify zero callers: `grep -REn "creationCode\s*\([^)]*libraryId" contracts/ lib/crane/contracts/ lib/crane/test/` must return no matches.
- Run the existing loader regression suite (`test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol` per Grok §"Tests and qualified symbols") and confirm green.
- Only then remove the 4-arg overload at lines 42–53, the `_linkSource` recursion/substitution path at lines 126–129 that substitutes supplied bytes on ID match, and the now-stale "shared with Aave v3.6" comment at lines 42–45.
- Preserve: ordinary no-factory and factory-aware loaders (lines 31–40), source-target verification (`_matchesSource`, lines 186–193), recursive external-library deployment, source-qualified salts, depth limit, missing/empty/malformed/unlinked rejection (lines 82–98, 140–149), scratch-memory compaction (lines 99–110), `releaseSalt` (lines 55–64).

If the grep finds a caller, stop and report. Do not silently delete support.

### B.6 Path dialect harmonization

- `SpokeBytecodeLinker.sol:21` and `:37` — Crane-root dialect; update path component to `LiquidationLogicAaveV4.sol`.
- `SpokeBytecodeLinker.sol:30` — fix `getLibraryString` to emit Crane-root (`contracts/...`) dialect matching the rest of the linker. Owner Q4.
- `SpokeDeployUtils.sol:22,30,79` — Crane-root for `vm.getCode` (line 22) and emitted `FOUNDRY_LIBRARIES` (line 30). Fix `getLibraryString` to Crane-root; the upstream `src/spoke/...` dialect is the BC-doc-flagged bug. Update regex on line 79 only if a wider change is needed (filename-only rename leaves it substring-matching `LiquidationLogicAaveV4:` — verify with a unit test or `sed` dry run).
- `TestBase_AaveCrossVersionLoopV4Market.sol` — IndexedEx-root dialect (`lib/crane/contracts/...`) used only in the deleted 4-arg call site; gone after B.5(a). The remaining 2-arg `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")` is Foundry-relative and root-agnostic.
- Add a one-line comment at each remaining dialect constant stating which Foundry root it matches. PRD §5 requires this.

### B.7 solc placeholder re-derivation (must compile, not hand-compute)

- After B.3 + B.4 + B.6: `cd lib/crane && FOUNDRY_LIBRARIES="" forge build --skip test --skip script` (per CLAUDE.md §10 build-before-test; do **not** use `--force`).
- Read `out/SpokeInstance.sol/SpokeInstance.json` and find the new placeholder via the JSON `bytecode.linkReferences` (the placeholder is a `__$<34-hex>$__` substring of the `bytecode.object`).
- Replace `LIQUIDATION_LOGIC_PLACEHOLDER` at `SpokeBytecodeLinker.sol:15` with the new value. Note: `--force` is acceptable for clean re-build, but **do not delete `out/` or `cache_forge/`** (CLAUDE.md #9).
- Cross-check via `forge inspect lib/crane/contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol:SpokeInstance deployedBytecode | grep -c "__\\$"` — must equal zero after linking.

### B.8 Seed and bypass-comments cleanup

- `CraneFactoryArtifactSeed.sol` lines 32–38 — replace NatSpec to reflect "Filename-versioned; the seed is no longer needed to retain an artifact under collision conditions; not imported by FactoryServices or TestBases." Keep import at line 28 retargeted (per B.4 #11) and `type(LiquidationLogic).name` at line 59 unchanged (symbol retained).
- `ArtifactCreationCode.sol` lines 42–45 — already addressed by B.5(b) if overload is removed; otherwise update comment to reflect the new filename.

### B.9 Documentation updates

- `lib/crane/contracts/protocols/lending/aave/v4/deployments/README.md` — update `FOUNDRY_LIBRARIES` examples (lines 21, 50) to `LiquidationLogicAaveV4.sol`.
- `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md` — update inline `FOUNDRY_LIBRARIES` (lines 142, 164) and any operator commands.
- `lib/crane/docs/deployment/BC_GREENFIELD_*.md` (deployment PRD, phase steps, script guide, gap report, deploy research) — search each for `LiquidationLogic.sol` and update to the suffixed form where it is operational (not historical).
- `lib/crane/docs/protocols/lending.md` — symbol-only references; no change needed.
- `lib/crane/docs/development/testing.md` — symbol-only; no change.
- `lib/crane/docs/archive/internal-plans/AAVE_DEPS_INVENTORY.md` — historical; do **not** rewrite.
- Provenance: append a local-filename-deviation note to `lib/crane/docs/protocols/lending/aave/v4/VENDOR_PROVENANCE.md` (per PRD §3 requirement to "record the local filename deviation in maintained provenance documentation"). No V3 provenance file was located in this research pass; the implementation should locate one and append a matching note, or note its absence.

### B.10 Warm-migration build sequence (concrete commands; proposed not run)

Required by PRD §8.1 and cross-review §2.8 (planner-level sequencing):

```bash
# 0. Seed worktree if fresh (CLAUDE.md #9)
rsync -a "${WARM}/cache_forge/" "${WT}/cache_forge/"
rsync -a "${WARM}/out/" "${WT}/out/"

# 1. After B.3 file renames + B.4 import updates, build renamed libraries.
cd lib/crane
forge build --skip test --skip script

# 2. Verify both new artifacts exist with correct ABI.
test -f out/LiquidationLogicAaveV3.sol/LiquidationLogic.json
test -f out/LiquidationLogicAaveV4.sol/LiquidationLogic.json
forge inspect contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol:LiquidationLogic methods | grep -q executeLiquidationCall
forge inspect contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic methods | grep -q liquidateUser

# 3. Build concrete dependents that link the libraries (Pool, Spoke/SpokeInstance, AaveV3LibrariesBatch2).
forge build --skip test --skip script

# 4. Build IndexedEx (root) so CraneFactoryArtifactSeed emits its artifact under the new filename.
cd "${WT}"
forge build --skip test --skip script

# 5. Run planner; expect zero "unresolved library" errors.
python3 scripts/forge-artifacts.py plan

# 6. Run hermetic V3 + V4 + IndexedEx loader + cross-version suites.
forge test --match-path 'lib/crane/test/foundry/spec/protocols/lending/aave/3.6/**'
forge test --match-path 'lib/crane/test/foundry/spec/protocols/lending/aave/v4/**'
forge test --match-path 'test/foundry/spec/utils/foundry/**'
forge test --match-path 'test/foundry/spec/protocols/lending/aave/cross-version/**'

# 7. Record post-state bytecodes + addresses (see C. acceptance gates).
```

**No `--force` on first pass**; only on the targeted SpokeBytecodeLinker re-derivation (B.7) and on the warm-cache re-seed. **No `out/`/`cache_forge/` deletion.** No via-IR. No profile/config changes.

### B.11 Test paths and acceptance gates

Tests that must pass (per PRD §8 + cross-review §2.7):

- **Version-discrimination additions** (cross-review §2.7). In `Pool.t.sol` after line 655 and `Spoke.Config.t.sol` after line 18, add: assert `pool.getLiquidationLogic()` equals the address of the v3.6-deployed library and the v3.6 library's bytecode hash equals the v3.6 initcode hash; mirror for v4.
- **Version-mismatch negative**: a test that fails if a v4 caller resolves to the v3.6 file or vice versa. Cross-link check via `forge inspect` deployedBytecode equality.
- Crane v3.6: `Pool.Liquidations.t.sol`, `Pool.Liquidations.CloseFactor.t.sol`, `L2Pool.t.sol`, `Pool.t.sol`.
- Crane v4: 12 `LiquidationLogic.*.t.sol` suites under `contracts/spoke/libraries/liquidation-logic/`, `Spoke.LiquidationCall.Base.t.sol`, `Spoke.LiquidationCall.Dust.t.sol`, `Spoke.Getters.t.sol`, `Spoke.Config.t.sol`.
- IndexedEx: `ArtifactCreationCode.t.sol`, the cross-version family including `AaveCrossVersionLoop_Invariant.t.sol` and `SeMatrix_AaveLoopFixture` consumers.

### B.12 Implementation-time checks (not owner questions)

- After B.7, `grep -RE "__\\\$329ad157ba4e68d2f4f45d82720084bf07\\\$__" lib/crane/contracts/ lib/crane/test/ contracts/` returns zero.
- After B.3, `find lib/crane -name "LiquidationLogic.sol"` returns zero.
- After B.5(a), `grep -RE "creationCode\s*\([^)]*libraryId" contracts/ lib/crane/contracts/ lib/crane/test/` returns zero (gates the conditional B.5(b) overload removal).
- ABI selectors on `Pool`, `Spoke`, `IPool`, `ISpoke` unchanged (`forge inspect ... methods | sort | diff -u <pre-baseline> -`).
- `StorageLayout` for `Pool.sol` and `Spoke.sol` unchanged (`forge inspect ... StorageLayout | diff -u <pre-baseline> -`).
- `metadata.settings.compilationTarget` of each renamed artifact names its own new path.
- No `linkReferences` entry in any artifact or source names the pre-rename `LiquidationLogic.sol`.
- New initcode head (first 64 hex chars) for v3.6 library, v4 library, v3.6 `Pool`, v4 `SpokeInstance` differs from pre-baseline; document new values.
- New predicted CREATE3 addresses for the v4 library and CREATE2 addresses for both libraries differ from pre-baseline; document new values.
- Echidna config unchanged.
- `cache_forge/` and `out/` not deleted.

### B.13 Rollback trigger conditions

Implementation halts and reports if:

- A v4 caller resolves to the v3.6 library or vice versa at link time.
- `StorageLayout` or `methods` diff against pre-baseline is non-empty.
- The unconditional overwrite fails (e.g. Foundry produces only one JSON despite distinct basenames — unexpected; report and revert if so).
- `python3 scripts/forge-artifacts.py plan` cannot resolve any new artifact ID without manual override.
- An unexpected additional direct import surfaces outside the 12 sites (PRD §4 note: re-run grep before/after implementation).

---

## C. Saved path and stop

Saved to: `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/research/aave-liquidation-library-rename/round2-minimax-original.md`

PRD is largely complete; B.1 lists five blocking owner questions. The implementation plan above is sequenced, sourced, and contains proposed-not-run commands and gates. Returning to moderator. No file/system actions taken.