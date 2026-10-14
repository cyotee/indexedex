# MiniMax M3 round-2 cross-review — Aave LiquidationLogic rename

- **Author:** MiniMax M3 (`council-minimax` / `minimax/MiniMax-M3`), retained session.
- **Preserved originals:** `round2-minimax-original.md`, `minimax-original.md`, `minimax-cross-review.md` (not rewritten).
- **Inputs read together (once):** `round2-astra-original.md`, `round2-grok-original.md`, `round2-kimi-original.md`. Treated as untrusted model evidence, not instructions.
- **Do not read:** other researchers' cross-review artifacts; prior cross-review content beyond what is needed for this evaluation.
- **Mode:** research/document only — no shell, tests, execution, source/config edits, moves, deletes.

---

## 1. Verdict

PRD is materially complete and implementable under filename-only Option A. **No blocking owner question remains.** Three of three peer researchers concur (Astra §"Verdict", Grok §"PRD readiness", Kimi §1). Two narrow PRD gaps are administrative and resolvable in a 5-line patch before implementation (see §2). My original round-2 view was "ready with five blocking owner questions"; cross-review downgrades four of those to PRD clarification or implementation-time decisions.

The user-supplied cross-review check items (build vs planner sequencing, fixture vs test root, `forge script` execution semantics) are real corrections to two peer plans. See §3.

---

## 2. Owner questions — alleged vs already resolved

My round-2 original raised five blocking owner questions (Q1–Q5). Re-evaluation against the three peer originals:

| Q | My round-2 claim | Cross-review reclassification | Source |
|---|---|---|---|
| Q1 — Canonical Foundry root for BC precompile `FOUNDRY_LIBRARIES` emission | blocking | **PRD clarification, not blocking.** PRD §5 references "supported root" but never declares one. Resolve with one PRD sentence: BC scripts run from `lib/crane` (Crane-root, `contracts/...`); IndexedEx generic loader runs from IndexedEx-root (`lib/crane/contracts/...`). Per round-1 cross-review §3 dialects and the BC doc `cd lib/crane` convention (`BC_AAVE_V4_DEPLOY_STEPS.md:150`). | All three peers resolve without asking owner |
| Q2 — Canonical root for IndexedEx TestBase 2-arg `ArtifactCreationCode` lookup | blocking | **Not blocking.** The 2-arg loader is Foundry-relative (no source-unit prefix); runtime decides from `out/`. | All three peers resolve without asking owner |
| Q3 — Pre-approve conditional removal of 4-arg `creationCode` overload | blocking | **Not blocking.** PRD §6.4 already encodes the stop-condition ("if another caller is discovered, stop for scope review rather than deleting its support silently"). The grep-and-regress gate is implementation-time, not owner-blocking. | All three peers treat as implementation-time |
| Q4 — Approve fixing `SpokeDeployUtils.sol:30` upstream dialect | blocking | **Implementation-time decision with strong consensus.** Grok §"SpokeBytecodeLinker" + Kimi §Q2 both recommend fix; Astra §"Crane operational linking" corrects to Crane-root; BC doc line 145 already flags it as a bug. The fix is a single-line `getLibraryString` change in vendored test tooling. PRD §9 lists "no widening" as a non-goal; dialect harmonization is correction, not widening. **Position:** proceed without explicit owner re-approval; record the decision in the evidence file. | All three peers agree |
| Q5 — Note other Aave basename collisions for follow-up | (note, not a decision) | **Note carried forward.** Kimi §8 H1 already flags `WadRayMath.sol`, `PercentageMath.sol`, `MathUtils.sol`. Out of scope. | Concur |

**PRD §5 administrative patch (≤ 5 lines):** insert one sentence naming the supported root convention and explicitly correct the upstream `src/spoke/...` dialect as bug, not feature. Not blocking implementation; blocking "ready" status if the moderator wants the PRD to be self-contained.

---

## 3. Corrections to peer plans

### 3.1 `forge-artifacts.py build` is itself a planner — bootstrap with direct `forge build` first

**User-supplied check item.** Confirmed correct.

- **Astra** (§"Warm stale-link migration — before planner invocation" + §"Proposed validation commands" lines 76–83) uses `forge build <explicit sources>` to directly build the renamed libraries and their concrete linkers, then runs `python3 scripts/forge-artifacts.py plan ...`. Correct.
- **Grok** (§"Warm stale-link migration" step 1–2 + §"Proposed commands" line 63) starts with `python3 scripts/forge-artifacts.py build ...`. This is the planner; a stale `SpokeInstance.json` link-reference queue would make it fail before the rename can take effect. **Order is wrong** for the warm-migration gate.
- **Kimi** (Phase 4 step 11, lines 53–56) likewise starts with `python3 scripts/forge-artifacts.py build ...`. Same issue.

**Position:** the warm-migration sequence must be:

```
1. (rename + import retarget + linker-string edits + seed/loader updates, no builds yet)
2. forge build <explicit sources>                       # direct compile, no planning
3. forge inspect / artifact checks                      # confirm ABI, compilationTarget
4. python3 scripts/forge-artifacts.py plan ...          # planner only after artifacts refreshed
5. python3 scripts/forge-artifacts.py test <sources> --test-root <test-only-runs>
```

This is what Astra prescribes (correct) and what Grok/Kimi should adopt. The `forge-artifacts.py build` form is a different beast from `forge build` — it queues link references and may resolve against stale artifacts. Direct `forge build` against explicit sources is the only safe bootstrap.

### 3.2 Non-`.t.sol` fixtures are not runnable test roots — identify actual consumers

**User-supplied check item.** Confirmed correct.

- **Grok** (§"Proposed commands" line 84) lists `--test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_AaveLoopFixture.sol` as a `--test-root` argument. `SeMatrix_AaveLoopFixture.sol` is a fixture helper contract, not a Foundry test root. Foundry's `--match-path` and `forge-artifacts.py --test-root` expect `*.t.sol` test files. Passing a fixture path to `--test-root` will either silently no-op or fail.
- **Kimi** (Phase 5 gate "Cross-version family") mentions "SeMatrix_AaveLoopFixture consumers" but does not name one. Incomplete.
- **Astra** (§"Regression edits and documentation" + §"Repeat IndexedEx helper `test` selections") explicitly says: "Repeat IndexedEx helper `test` selections for all discovered `SeMatrix_AaveLoopFixture` consumers: single/dual normal and decimal F6/F9 suites and weighted `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_AaveCrossVersionLoop.t.sol`. Select concrete tests, not the fixture alone; record selected counts."

**Position:** the implementation must enumerate the actual `*.t.sol` files that import or compose the fixture. Round-1 evidence points to fixtures under `test/foundry/spec/hooks/uniswap/v4/standardExchange/` (per `INDEXEDEX_AGENT_LAW.md` and round-1 cross-review). The `--test-root` arguments must be real test files (`*.t.sol`), not fixture helpers. The implementer must run a `grep -RE "SeMatrix_AaveLoopFixture" test/foundry/spec/` first and pass only `*.t.sol` paths to `--test-root`. Grok's command line is invalid as written.

### 3.3 `forge script` is execution, not compile-only — use `forge build` for script validation

**User-supplied check item.** Confirmed correct.

- **Grok** (§"Proposed commands" line 90): `forge script scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol --sig "run()" -vv`. **This executes `run()`** even with `--sig run()` — `forge script` always runs the script body. The script uses `vm.ffi(...)` (per `SpokeDeployUtils.sol:48`), which will execute shell commands (`bash -c ...`) when the script body runs. The BC script also calls `vm.startBroadcast()` and prints `console2.log(...)` — not a pure compile. Grok's caveat "if the script always writes `.env`, skip execution" is a contradiction: the script body itself is the action.
- **Astra** (§"Proposed validation commands — NOT RUN" line 108): "Validate script helper outputs through hermetic tests, not script `run()` or broadcast. Do not launch FFI precompile scripts." Correct.
- **Kimi**: does not propose script execution; recommends `forge-artifacts.py test` only.

**Position:** script validation must be `forge build <script-path>` (or `forge-artifacts.py build --consumer <script-path>`). For example:

```
forge build scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol
```

This compiles the script (validates imports, types, references) without running `run()`. If `run()` writes `.env` or calls FFI, the script body is not executed. The output emission (`FOUNDRY_LIBRARIES` strings) must be reviewed by reading source constants (`SpokeBytecodeLinker.sol:37`, `SpokeDeployUtils.sol:30`), not by running the script.

### 3.4 Other observations from peer plans

- **Source IDs in `forge inspect` calls**: Kimi Phase 0 baselines use `<Pool>` and `<Spoke>` placeholders without the artifact name. V3 `Pool` is the abstract contract at `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol`; the production artifact is `PoolInstance.sol:PoolInstance` (per round-1 inventory). The artifact ID must include the contract name (`PoolInstance:PoolInstance`, `SpokeInstance:SpokeInstance`), not the abstract. Grok uses `Spoke.sol:Spoke` (line 91) for the abstract — that compiles but is the test storage layout, not the production one. **Position:** production storage layout check requires the instance; abstract check is informative but not authoritative.
- **`forge build` for IndexedEx root**: Grok line 67 builds `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol` directly. The `Spoke.sol` is abstract; instances are `SpokeInstance.sol:SpokeInstance`. The `forge build` against the abstract compiles, but `linkReferences` for the production bytecode are in `SpokeInstance.json`. **Position:** explicit `forge build` should target the instance contracts, not the abstracts.
- **Crane-side `--all-artifacts` invocation**: Astra line 86 uses `python3 scripts/forge-artifacts.py build --all-artifacts` after direct builds. This is acceptable once direct builds have refreshed the rename pair's artifacts. The `--all-artifacts` flag then sweeps the rest. **Caveat:** confirm `--all-artifacts` does not invoke the planner that previously failed; if it does, prefer explicit-list rather than `--all-artifacts`.
- **Spoke deploy salt — round-1 cross-review §2.3 / §2.4**: even filename-only changes bytecode (metadata hash + link-reference hash). All three peers correctly note that new initcode hashes → new addresses. My round-1 retraction is upheld.
- **Solidity 0.8.35 metadata hash effect on bytecode**: Kimi cites the source; Grok implies it; Astra relies on it. Cross-review §2.3 from round 1 covered this. All three peers converge.
- **Bash FFI command syntax**: `SpokeDeployUtils.sol:48` uses `bash -c "$(sedCommand)"`. This requires bash on PATH. Foundry's `vm.ffi` runs host shell. Tests already do this; nothing new.

---

## 4. Recommended consolidated plan

The four peer plans (Astra/Grok/Kimi + my round-2) align closely. Differences are sequencing and command-shape, not scope. Consolidated plan:

### Phase 0 — Baselines (proposed, not run)

1. Capture `forge --version`, `solc --version` (PRD §3 honesty).
2. `forge inspect lib/crane/contracts/protocols/lending/aave/v3.6/instances/PoolInstance.sol:PoolInstance methods > pre.pool.methods` (production artifact; abstract is `Pool.sol:Pool`).
3. `forge inspect lib/crane/contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol:SpokeInstance methods > pre.spoke.methods`.
4. `forge inspect ... StorageLayout` for both instances.
5. Snapshot constant values from both library files: `0.95e18`, `2000e8`, `1e18`, `1000e26`.
6. Capture initcode head (first 64 hex chars) for both libraries and both instances.
7. Capture pre-rename `out/` warm-state: line counts of `out/LiquidationLogic.sol/LiquidationLogic.json`, `out/logic/LiquidationLogic.sol/LiquidationLogic.json`, `out/LiquidationLogicArtifactProbe.sol/LiquidationLogicArtifactProbe.json`.
8. Worktree seed per CLAUDE.md #9 (no cache deletion).

### Phase 1 — Renames + import retargets (Crane-side)

1. `git mv lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol` → `LiquidationLogicAaveV3.sol`.
2. `git mv lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol` → `LiquidationLogicAaveV4.sol`.
3. Retarget 10 Crane imports (V3 prod 3 + V3 tests 4 + V4 prod 1 + V4 tests 2). Keep `library LiquidationLogic` binding. Per round-2 PRD §4.

### Phase 2 — IndexedEx-side workaround removal

1. `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol`: remove lines 15 + 81–88; replace Spoke bytecode with `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")`.
2. `contracts/utils/foundry/CraneFactoryArtifactSeed.sol`: retarget import to V4 filename; replace NatSpec ll.35–37 (claim of permanent overwrite is no longer true); keep `type(LiquidationLogic).name`.
3. Conditional removal of `ArtifactCreationCode.creationCode` 4-arg overload: **after** `grep -RE "creationCode\s*\([^)]*libraryId" contracts/ lib/crane/contracts/ lib/crane/test/` returns zero AND `forge test --match-path test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol` passes. Per round-2 PRD §6.4 stop-condition.
4. Loader comment update at `ArtifactCreationCode.sol:42–45` (collision narrative no longer applies).

### Phase 3 — Crane operational linking

1. `SpokeBytecodeLinker.sol`: update `LIB_ARTIFACT_PATH` (l.21) and `FOUNDRY_LIBRARIES` emitter (l.37) to `contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic`. Leave `LIQUIDATION_LOGIC_PLACEHOLDER` (l.15) stale until Phase 5.
2. `SpokeDeployUtils.sol`: update `vm.getCode` (l.22) to Crane-root; fix `getLibraryString` (l.30) to Crane-root (Owner Q4 — resolves upstream `src/spoke/...` dialect bug per `BC_AAVE_V4_DEPLOY_STEPS.md:145`); tighten `.env` regex (l.79) to `LiquidationLogicAaveV4.sol:LiquidationLogic:` so it cannot match a V3 entry.
3. Comment-only updates: `LibraryPreCompile.s.sol`, `AaveV4DeployAnvil.s.sol`, `Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol`, `Script_BC_Phase3_Aave.s.sol`, `BcAavePhase3Deploy.sol`.
4. `AaveV3LibrariesBatch2.sol`: keep `type(LiquidationLogic).creationCode` (legitimate deployment; not the workaround).
5. `echidna_config.yaml`: unchanged (symbol binding preserved under filename-only).

### Phase 4 — Warm stale-link migration (no cache deletion, no `--force`)

Critical sequencing: **direct `forge build` first; `forge-artifacts.py plan` only after artifacts are refreshed**.

```bash
# 1. Direct build of renamed libraries and concrete linkers. No planner.
cd "${WT}"
forge build \
  lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  lib/crane/contracts/protocols/lending/aave/v3.6/instances/PoolInstance.sol \
  lib/crane/contracts/protocols/lending/aave/v3.6/instances/L2PoolInstance.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol \
  contracts/utils/foundry/CraneFactoryArtifactSeed.sol

# 2. Verify ABI identity.
test -f out/LiquidationLogicAaveV3.sol/LiquidationLogic.json
test -f out/LiquidationLogicAaveV4.sol/LiquidationLogic.json

# 3. Verify compilationTarget.
grep -q 'LiquidationLogicAaveV3.sol' out/LiquidationLogicAaveV3.sol/LiquidationLogic.json
grep -q 'LiquidationLogicAaveV4.sol' out/LiquidationLogicAaveV4.sol/LiquidationLogic.json

# 4. Verify old ID absent.
! grep -q 'LiquidationLogic.sol":' out/LiquidationLogicAaveV3.sol/LiquidationLogic.json
! grep -q 'LiquidationLogic.sol":' out/LiquidationLogicAaveV4.sol/LiquidationLogic.json

# 5. Same build sequence from Crane root.
cd lib/crane
forge build \
  contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol

# 6. Compile-only validation of BC scripts (no `run()`, no FFI).
cd "${WT}"
forge build scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol
forge build scripts/foundry/bc/Script_BC_Phase3_Aave.s.sol
cd lib/crane
forge build scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol

# 7. Planner only after artifacts are refreshed.
cd "${WT}"
python3 scripts/forge-artifacts.py plan \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  --consumer contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol

# 8. If planner reports unresolved library, rebuild the specific consumer (not delete cache).
# Per CLAUDE.md #9; do not delete out/ or cache_forge/.
```

### Phase 5 — Placeholder re-derivation (Crane-root compile only)

```bash
cd lib/crane
grep -o '__\$[0-9a-f]\{34\}\$__' out/SpokeInstance.sol/SpokeInstance.json | sort -u
# expect exactly one match
# update LIQUIDATION_LOGIC_PLACEHOLDER constant in SpokeBytecodeLinker.sol
```

Verify the new token equals the 34-hex prefix of `keccak256("contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic")`. The compile wins; do not hand-compute.

### Phase 6 — Test gates (build-before-test)

```bash
# IndexedEx root hermetic
cd "${WT}"
forge test --match-path 'test/foundry/spec/utils/foundry/**'
forge test --match-path 'test/foundry/spec/protocols/lending/aave/cross-version/**'
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/**'  # SeMatrix consumers only

# Crane root hermetic
cd lib/crane
forge test --match-path 'test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/**'
forge test --match-path 'test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/**'

# Specifically required: AaveCrossVersionLoop_Invariant.t.sol — real invariant run, not smoke
```

Identify actual `*.t.sol` consumers of `SeMatrix_AaveLoopFixture.sol` via `grep -RLE "SeMatrix_AaveLoopFixture" test/foundry/spec/ | grep '\.t\.sol$'`. Pass those to `--match-path`.

### Phase 7 — Acceptance gates

| Gate | Check |
|---|---|
| File system | `find lib/crane/contracts/protocols/lending/aave -name 'LiquidationLogic.sol'` returns zero |
| ABI | `forge inspect PoolInstance.sol:PoolInstance methods | sort | diff - pre.pool.methods` empty |
| ABI | Same for `SpokeInstance.sol:SpokeInstance` |
| ABI | Same for both libraries; library method identifiers byte-equal pre-rename (symbol unchanged) |
| Storage | `forge inspect ... StorageLayout | diff - pre.pool.layout` empty for both instances |
| Constant values | byte-identical to Phase 0 |
| Initcode heads | Documented delta; expected different from Phase 0 (metadata+link hash) |
| Predicted addresses | New CREATE2/CREATE3 addresses documented; old addresses recorded for migration evidence |
| Workaround removal | grep for `creationCode\([^)]*libraryId` returns zero; loader regression suite green |
| Seed retention | `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` exists; NatSpec no longer claims permanent overwrite |
| Echidna | Config unchanged |
| Compiler | `forge --version`, `solc --version` recorded |
| Forbidden | No `out/` or `cache_forge/` deletion; no `--force` on first pass; no via-IR; no profile/config changes |

### Phase 8 — Documentation and provenance

1. Update `lib/crane/contracts/protocols/lending/aave/v4/deployments/README.md` (l.21–50).
2. Update `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md` (l.142, l.164; remove `--force` references).
3. Review `BC_GREENFIELD_*.md` for live path examples; update where operational.
4. Add filename-deviation note to `lib/crane/docs/protocols/lending/aave/v4/VENDOR_PROVENANCE.md`.
5. Discover and update v3.6 provenance if it exists; otherwise note its absence in evidence.
6. Leave archive, audit JSON, implementation-artifacts/, skill files unchanged.

### Phase 9 — Rollback triggers

Halt and report if:

- Cross-version link swap: a v4 caller resolves to the v3.6 library or vice versa.
- `StorageLayout` or `methods` diff against pre-baseline non-empty.
- Single basename collision persists (Foundry produces only one JSON despite distinct names).
- Planner cannot resolve any new artifact ID without manual override.
- Unexpected additional direct import surfaces outside the 12 PRD §4 sites.

---

## 5. Cross-review confidence

| Claim | Confidence | Source |
|---|---|---|
| PRD is materially complete; no blocking owner questions | High | Three-of-three peer originals concur |
| `forge-artifacts.py build` runs planner before build | High | Per user's check item; matches planner source structure (`forge-artifacts.py` line 198–212 / 240–253) |
| `forge build <explicit sources>` is the safe bootstrap | High | Direct `forge build` does not invoke planner |
| `SeMatrix_AaveLoopFixture.sol` is a fixture, not a test root | High | Round-1 inventory; consensus in round-2 originals |
| `forge script --sig run()` is execution, not compile-only | High | Foundry `forge script` always runs the script body; FFI is a host shell |
| `forge build <script-path>` validates scripts without executing them | High | Foundry standard |
| Solidity 0.8.35 metadata hash includes filename | High | Round-1 cross-review §2.3; peer cites Solidity docs v0.8.37 |
| Filename-only changes bytecode/initcode/derived addresses | High | All three peers concur; round-1 retraction upheld |
| Conditional 4-arg overload removal gate works | High | PRD §6.4 encodes stop-condition; all peers apply it |
| Echidna config unchanged under filename-only | High | Symbol binding; PRD §5 row |

---

## 6. Saved path

Saved: `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/research/aave-liquidation-library-rename/round2-minimax-cross-review.md`

Returning to moderator. No further actions.