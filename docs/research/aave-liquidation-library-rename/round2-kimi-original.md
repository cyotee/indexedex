# Kimi K3 — Round 2 original: PRD readiness review + implementation plan (Aave LiquidationLogic rename)

Date: 2026-10-12. Author: Kimi K3 (kimi-code-plan-global/k3), retained session. Human has **approved filename-only** rename to `LiquidationLogicAaveV3.sol` / `LiquidationLogicAaveV4.sol`, symbols retained (`library LiquidationLogic` in both). Research/document only: nothing executed, built, edited, moved, or deleted. All commands below are **PROPOSED, NOT RUN**. Prior-round memory is historical context; I did not read any peer round-2 output or any cross-review artifact for this pass. Path abbreviations match the PRD (`C3`, `C4`, `T3`, `T4`).

## 1. PRD readiness verdict

`docs/plans/aave-liquidation-library-rename/PRD.md` (170 lines, dated 2026-10-12) is **substantively complete and implementable**: correct suffix spelling and directory placement (§1), correct workaround decomposition — seed vs TestBase 4-arg call vs loader overload (§2), controlling constraints incl. no `--force`/cache deletion/via-IR (§3), the confirmed 12-import inventory (§4), string/dialect/docs inventory (§5), functional requirements incl. overload-removal stop-condition (§6 FR4), deployment-identity honesty (§7), acceptance gates incl. warm stale-link migration and wrong-version rejection (§8), non-goals (§9), and an honest council record (§10).

**One structural gap:** §5 ("Artifact identities and invocation roots") tells implementers to correct emitters "to their declared supported root," but **no supported root is ever declared**. This is the only place where the PRD defers to a document that does not exist. Everything else an implementer needs is present. Verdict: ready once the supported-root ruling (Q1 below) is recorded; without it, the placeholder/`FOUNDRY_LIBRARIES` emitter edits are ambiguous.

## 2. Owner questions (need a ruling; distinct from implementation-time checks)

- **Q1 (blocking for Phase 2 emitter edits):** Which Foundry root is canonical for the BC Aave V4 library precompile flow (`Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol` → `SpokeBytecodeLinker`)? The placeholder constant and `FOUNDRY_LIBRARIES` string are valid only for the compiling root's source-unit name (`contracts/...` in Crane vs `lib/crane/contracts/...` in IndexedEx; solc hashes the full source-unit path — Solidity docs, Library Linking). **Recommended default:** Crane root is canonical (scripts live in `lib/crane/scripts/foundry/bc/`; BC docs `cd` into `lib/crane`, e.g. `BC_AAVE_V4_DEPLOY_STEPS.md:150`); IndexedEx linking uses `ArtifactCreationCode` JSON `linkReferences`, not the placeholder. Owner confirmation requested; if accepted, no PRD text change is strictly needed but §5 should name it.
- **Q2 (scope ruling):** Fix `T4/scripts/utils/SpokeDeployUtils.sol:30` (`getLibraryString` emits upstream `src/spoke/...` dialect, already flagged as a bug by `BC_AAVE_V4_DEPLOY_STEPS.md:145`) in this change, or annotate-only? **Recommended:** fix it — it is vendored *test tooling*, not domain logic, so `crane-porting` fidelity does not protect it; leaving it produces a broken precompile output against the new filename.
- **Q3 (release-gate input, non-blocking for code):** Do any broadcast deployments exist of the salt-0 CREATE2 v4 library or the `AAVE_V3_LIBRARIES_BATCH` v3.6 library whose old addresses must appear in the old/new identity table? Affects PRD §7 evidence table only.

## 3. Implementation-time checks (not owner questions)

Re-grep the import inventory immediately before editing (PRD §4 closure rule); verify zero remaining 4-arg `creationCode` callers before removing the overload (FR4 stop-condition); record actual `forge`/`solc` executable versions (PRD §3); discover whether a v3.6 provenance record analogous to `lib/crane/docs/protocols/lending/aave/v4/VENDOR_PROVENANCE.md` exists; if v4 `LiquidationLogic.*.t.sol` suites fail with undeclared `LiquidationLogic` after the rename (transitive-visibility risk flagged in round 1), add explicit imports of the renamed **file** keeping the symbol — do not rename symbols or test files.

## 4. Ordered implementation plan

### Phase 0 — Baselines (PROPOSED, NOT RUN)
```bash
forge --version && solc --version
forge inspect lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol:Pool methods > /tmp/pool.methods.before
forge inspect lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:Spoke methods > /tmp/spoke.methods.before
forge inspect <Pool> storageLayout / <Spoke> storageLayout   # both, before snapshots
grep -c . out/LiquidationLogic.sol/LiquidationLogic.json out/logic/LiquidationLogic.sol/LiquidationLogic.json 2>/dev/null  # warm-state record
```

### Phase 1 — Crane file renames + import retargets (10 Crane files)
1. Rename `C3/protocol/libraries/logic/LiquidationLogic.sol` → `LiquidationLogicAaveV3.sol` (same dir; preserve history with a rename-preserving move).
2. Rename `C4/spoke/libraries/LiquidationLogic.sol` → `LiquidationLogicAaveV4.sol`.
3. Retarget imports, basename only, relative stays relative / `@crane/` stays `@crane/`, no other edits:
   - V3: `C3/protocol/pool/Pool.sol:13`; `C3/helpers/LiquidationDataProvider.sol:12`; `C3/deployments/projects/aave-v3-libraries/AaveV3LibrariesBatch2.sol:11–13`; `T3/helpers/LiquidationHelper.sol:6–8`; `T3/protocol/pool/Pool.Liquidations.CloseFactor.t.sol:31–32`; `T3/protocol/pool/Pool.Liquidations.t.sol:35–36`; `T3/protocol/pool/L2Pool.t.sol:14–16`.
   - V4: `C4/spoke/Spoke.sol:21`; `T4/setup/Base.t.sol:85`; `T4/helpers/mocks/LiquidationLogicWrapper.sol:10`.
4. No body/constant/struct/license/pragma edits; `git diff` of each renamed file must show rename-only.

### Phase 2 — Crane linker/script strings (dialect-preserving)
5. `C4/deployments/utils/libraries/SpokeBytecodeLinker.sol`: update `LIB_ARTIFACT_PATH` (l.20–21) and the `FOUNDRY_LIBRARIES` emitter (l.36–38) to `contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic` (Crane root per Q1); leave `LIQUIDATION_LOGIC_PLACEHOLDER` (l.15) stale **until Phase 5 regenerates it from compiler output** — never hand-compute.
6. `T4/scripts/utils/SpokeDeployUtils.sol`: `vm.getCode` ID (l.22) → new Crane-root path; `getLibraryString` (l.30) → same Crane-root form (Q2); qualify the `.env` extraction (l.79) to `LiquidationLogicAaveV4.sol:LiquidationLogic:` so it cannot match a V3 entry.
7. Comment-only updates: `T4/scripts/LibraryPreCompile.s.sol:9–12`, `T4/scripts/deploy/examples/AaveV4DeployAnvil.s.sol:13`, `Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol:12`, `Script_BC_Phase3_Aave.s.sol:19`, `BcAavePhase3Deploy.sol` header comments. No API/report-field renames (`V4 LiquidationLogic` manifest label may stay).

### Phase 3 — IndexedEx workaround removal
8. `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol`: delete import (l.15) and the overwrite comment (ll.81–82); replace the 4-arg call (ll.83–88) with `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")`.
9. `contracts/utils/foundry/ArtifactCreationCode.sol`: **after** a grep confirms zero remaining 4-arg callers (PROPOSED: `rg -n "creationCode\(" contracts lib/crane --glob '*.sol' | rg -v "creationCode\(([^,)]*,){0,1}[^,)]*\)"` plus manual review), delete the 4-arg overload (ll.42–53) and the `libraryId_`/`libraryCreationCode_` plumbing through `_creationCode`/`_linkSource` (ll.73–94, 114–129); keep both 1-/2-arg public forms, `_artifactJson` source-suffix walk + `_matchesSource` (ll.153–193), depth limit, bounds checks, memory compaction, `releaseSalt`. Correct the stale collision comment (ll.42–45). If any other caller appears: **stop for scope review** (FR4).
10. `contracts/utils/foundry/CraneFactoryArtifactSeed.sol`: retarget import (l.28) to `LiquidationLogicAaveV4.sol`; replace NatSpec ll.35–37 with a statement that the unique filename keeps the artifact and the seed remains src-only (do-not-import rule preserved). File retained per `CLAUDE.md:61`.

### Phase 4 — Warm stale-link migration (no cache deletion, no `--force`)
11. IndexedEx: explicit artifact-first rebuild supplying renamed sources and consumers (renamed sources cannot be inferred from stale graphs — `ARTIFACT_BUILDS.md:53`):
```bash
python3 scripts/forge-artifacts.py build \
  lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  --consumer contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol
```
12. If `plan`/`build` fails because a stale `SpokeInstance.json`/`Pool.json` still enqueues the removed `.../LiquidationLogic.sol:LiquidationLogic` ID (strict `resolve_artifact`, `scripts/forge-artifacts.py:157–171,240–253`): rebuild the concrete linking dependents (`Pool`, `Spoke`, `SpokeInstance`, `AaveV3LibrariesBatch2`) explicitly so their artifacts record new link IDs; report the failure; do **not** ignore unresolved libraries, delete `out/`/`cache_forge/`, or use `--force`.
13. Crane root: equivalent targeted build of the renamed libraries + `SpokeInstance`/`Pool` dependents from `lib/crane`.
14. Planner regression: `python3 -m unittest scripts/test_forge_artifacts.py`; `python3 scripts/forge-artifacts.py plan` on both renamed files must resolve each new ID to exactly one source and must reject the old ID.

### Phase 5 — Placeholder regeneration (compiler-derived only)
15. After Crane-root build, extract the new placeholder from the artifact, then update `LIQUIDATION_LOGIC_PLACEHOLDER`:
```bash
grep -o '__\$[0-9a-f]\{34\}\$__' lib/crane/out/SpokeInstance.sol/SpokeInstance.json | sort -u   # expect exactly one
```
Confirm it equals the 34-hex prefix of keccak256 of `contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic` as evidenced by the artifact's `linkReferences` key; the compile wins over any hand computation.

### Phase 6 — Docs/provenance
16. Update path examples in `C4/deployments/README.md:21–50` and `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md:126–166`; review the four `BC_GREENFIELD_*` docs for filename examples. Label any retained `src/spoke/...` string explicitly "upstream". Record the filename adaptation in `VENDOR_PROVENANCE.md` (v4) and the discovered v3.6 provenance location. Do not touch archives, audit/evidence JSON, or skill/instruction files (separate maintainer follow-up).

## 5. Test paths and acceptance gates (PROPOSED, NOT RUN)

Build-before-test per `CLAUDE.md:61`; use `forge-artifacts.py test <edited> --test-root <suite>`:

| Gate | Suites / checks |
|---|---|
| Crane V3 | `T3/protocol/pool/Pool.Liquidations.t.sol`, `Pool.Liquidations.CloseFactor.t.sol`, `L2Pool.t.sol`, `Pool.t.sol` (incl. `test_getLiquidationLogic`) |
| Crane V4 | `T4/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.*.t.sol` (12), `T4/contracts/spoke/liquidation/Spoke.LiquidationCall.*.t.sol`, `Spoke.Getters.t.sol`, `Spoke.Config.t.sol` |
| IndexedEx loader | `test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol` (salt encoding, occupied-identity reuse, nested links, source matching, failure cases) |
| Cross-version family | `test/foundry/spec/protocol/lending/aave/cross-version/**` incl. `invariant/AaveCrossVersionLoop_Invariant.t.sol` (real invariant run, not smoke) and `SeMatrix_AaveLoopFixture` consumers |
| Link integrity | New artifacts' `linkReferences` name the new source units; `pool.getLiquidationLogic()` and `spoke.getLiquidationLogic()` equal the expected, **distinct** version-specific deployments; wrong-version artifact rejection demonstrated |
| Compatibility | `forge inspect` methods/storage diffs vs Phase 0 baselines empty; external-library method identifiers compared separately and unchanged (filename-only); constant values byte-identical (`0.95e18`, `2000e8`, `1e18`, `1000e26`) |
| Artifact coexistence | `out/LiquidationLogicAaveV3.sol/LiquidationLogic.json` (ABI: `executeLiquidationCall`) and `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json` (ABI: `liquidateUser`) both present with correct `compilationTarget` after together/separate/both-order compiles; stale `out/LiquidationLogic.sol/` never selected |
| Workaround removal | No 4-arg overload or callers remain; seed retained with corrected comment; no `via_ir`, no profile/config changes, no cache deletion, no broadcasts |
| Report | Actual commands, executable versions, pass/fail/skip counts, runtime sizes, old/new source IDs → salts → initcode hashes → predicted addresses. Missing runs are not passes |

## 6. Bottom line

PRD is ready once **Q1** (supported root; recommend Crane) is answered; Q2/Q3 are minor rulings with recommended defaults. The plan above is ordered so that mechanical renames (Phase 1–3) precede warm artifact migration (Phase 4), placeholder regeneration is compiler-derived (Phase 5), and docs/provenance close the change (Phase 6). Approval of this plan is not authorization to execute it.

Saved: `docs/research/aave-liquidation-library-rename/round2-kimi-original.md`. Returning to the moderator; stopping for the human.
