# Astra — round 2 original: readiness and implementation plan

2026-10-12. Retained-session analysis, not a claim of fresh independence from round 1. No other round-2 reports or earlier cross-review files read. Current PRD, router, family decisions, artifact workflow, canonical Crane porting/testing and local testing skills were read directly. No commands below were run; no source/config changes, delegation, tests or deployments occurred.

## Verdict / owner questions

**Ready for implementation planning; no blocking product-requirement question remains.** Human approval fixes filename-only `LiquidationLogicAaveV3.sol` / `LiquidationLogicAaveV4.sol`, with symbols retained. Execution still requires separate authorization.

The PRD is materially complete. Moderator should make two administrative clarifications, not reopen naming:

1. Update its stale “awaiting approval” status/checkpoint (`PRD.md:4,168–170`) to record the approved naming decision without implying execution permission.
2. Interpret “cold preparation” (`131`) consistently with mandatory warm-worktree seeding (`CLAUDE.md:49–59`): a newly prepared **seeded** workspace plus isolated missing-artifact regression fixtures, not an unseeded full compile or deletion of shared output. A genuinely unseeded benchmark would require a separate exception, not block this rename.

Supported-root decision can be concrete without asking the owner: validate library artifacts in both projects; run Crane operational helpers/BC scripts from **Crane root**, and IndexedEx's generic loader from **IndexedEx root**. Do not promise that Crane's root-relative deployment helpers are portable to IndexedEx. If actual maintained consumers require that portability, stop for scope review rather than silently expand the refactor.

## Ordered implementation plan (proposal only)

Abbreviations: C3/C4 = `lib/crane/contracts/protocols/lending/aave/v3.6` / `v4`; T3/T4 = `lib/crane/test/foundry/spec/protocols/lending/aave/3.6` / `v4`.

### 1. Baseline and ownership

Record checkout/submodule revisions, actual Forge and compiler versions, source hashes, existing artifact targets/link references and compiler settings separately for both roots. Capture Pool/Spoke ABI, method identifiers and normalized storage layouts, and both libraries' method identifiers. Do not trust stale artifact identities without checking metadata. Protect warm outputs/cache; serialize writers; allow multi-hour builds.

Recheck PRD's 12 import sites (`48–67`) and every four-argument loader caller. Another required override caller triggers the PRD's scope-review stop (`108`). Read implementation coding rules before editing. No economic changes or unrelated cleanup.

### 2. Mechanical source edits

Rename only:

- C3 `protocol/libraries/logic/LiquidationLogic.sol` → `LiquidationLogicAaveV3.sol`.
- C4 `spoke/libraries/LiquidationLogic.sol` → `LiquidationLogicAaveV4.sol`.

Preserve exact file contents. Retarget V3 imports in `protocol/pool/Pool.sol`, `helpers/LiquidationDataProvider.sol`, `deployments/projects/aave-v3-libraries/AaveV3LibrariesBatch2.sol`; T3 `helpers/LiquidationHelper.sol`, `protocol/pool/{Pool.Liquidations.CloseFactor,Pool.Liquidations,L2Pool}.t.sol`.

Retarget V4 imports in C4 `spoke/Spoke.sol`, T4 `setup/Base.t.sol`, `helpers/mocks/LiquidationLogicWrapper.sol`, and IndexedEx `contracts/utils/foundry/CraneFactoryArtifactSeed.sol`. Keep seed `type(...).name`; correct its bypass comment. Leave getter names, test filenames, qualified symbols, Echidna binding and real V3 CREATE2 creation-code deployment unchanged.

### 3. Restore ordinary IndexedEx loading

In `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol:15,81–88`, remove the implementation import/comment and use `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")`.

In `contracts/utils/foundry/ArtifactCreationCode.sol`, remove four-argument overload and override parameters/substitution throughout recursion, retaining ordinary overloads, recursive library loading, source-target matching, salt derivation, authorization, all rejection/bounds/depth checks and scratch-memory compaction (`42–53,73–150`). Do not rewrite the linker architecture.

### 4. Crane operational linking

Update C4 `deployments/utils/libraries/SpokeBytecodeLinker.sol` artifact ID/emitted configuration and compiler-validated placeholder. Default minimal implementation: retain the existing mechanism, replace the constant only after observing the renamed **Crane-root** link identity, and add a regression that detects mismatch/unresolved placeholders. Do not guess a hash or copy an IndexedEx-root placeholder.

Update T4 `scripts/utils/SpokeDeployUtils.sol:22,30,79`: Crane-root artifact ID, correct `contracts/protocols/.../LiquidationLogicAaveV4.sol:LiquidationLogic` output, and exact V4 identity selection instead of broad `LiquidationLogic:` matching. Unit-test parsing/formatting using synthetic strings without environment reads/writes or FFI. Preserve public helper/report API names. Correct stale via-IR/bypass comments in touched operational material.

### 5. Warm stale-link migration — before planner invocation

The planner queues IDs from existing artifact link references **before building** (`scripts/forge-artifacts.py:198–212,240–253`). Explicitly build renamed libraries and concrete consumers directly with Forge first; building only libraries leaves stale Spoke/Pool artifacts. Include `PoolInstance`, `L2PoolInstance`, `SpokeInstance` and the seed; refresh further concrete consumers found in the current import graph.

Then run planner preparation. If it still names a removed library, identify the specific stale consumer and explicitly rebuild it; a full ordinary build is permitted if necessary. Never `--force`, `forge clean`, delete outputs/cache, suppress unresolved dependencies or change roots/profiles. If source-correct refresh cannot unblock planning, stop and review a narrowly scoped planner change with tests.

### 6. Regression edits and documentation

Strengthen `test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol:114–115` namesake setup regression: remove unsupported “stolen” causation and assert expected V4 identity, while running the actual `invariant_APEX_accounting` (`193`). Add both-version address equality/distinctness and executable liquidation/deficit coverage using existing real fixtures.

Extend `test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol` for renamed source resolution and wrong-source/missing-artifact failures without modifying shared artifacts. Extend `scripts/test_forge_artifacts.py` with isolated pre-rename-link fixtures and verified refresh ordering. Retain generic loader memory/occupied-salt/nested-link tests.

Update operational path examples in C4 `deployments/README.md`, Crane `docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md` and live examples identified in PRD §5. Record deviations in `docs/protocols/lending/aave/v4/VENDOR_PROVENANCE.md` and discovered V3 provenance. Leave history/audit snapshots and instruction/skill files unchanged.

## Proposed validation commands — NOT RUN

These are a command skeleton for a separately authorized implementer. Variables below are public paths, not environment secrets. Run from IndexedEx root unless stated. Add additional edited production sources and discovered test consumers to the helper selection.

```bash
forge --version
V3=lib/crane/contracts/protocols/lending/aave/v3.6
V4=lib/crane/contracts/protocols/lending/aave/v4
L3="$V3/protocol/libraries/logic/LiquidationLogicAaveV3.sol"
L4="$V4/spoke/libraries/LiquidationLogicAaveV4.sol"
LOOP=test/foundry/spec/protocol/lending/aave/cross-version

# Direct bootstrap bypasses planner stale-link discovery, not validation.
forge build "$L3" "$L4" "$V3/instances/PoolInstance.sol" \
  "$V3/instances/L2PoolInstance.sol" "$V4/spoke/instances/SpokeInstance.sol" \
  contracts/utils/foundry/CraneFactoryArtifactSeed.sol

python3 scripts/forge-artifacts.py plan "$L3" "$L4" \
  contracts/utils/foundry/ArtifactCreationCode.sol --test-root "$LOOP"
python3 scripts/forge-artifacts.py test "$L3" "$L4" \
  contracts/utils/foundry/ArtifactCreationCode.sol --test-root "$LOOP" -- -vv

# Loader negative literals must not be treated as build inputs.
python3 scripts/forge-artifacts.py build --all-artifacts
forge test --match-path 'test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol' -vv
python3 -m unittest scripts/test_forge_artifacts.py

forge inspect "$V3/protocol/pool/Pool.sol:Pool" methodIdentifiers
forge inspect "$V4/spoke/Spoke.sol:Spoke" storageLayout
forge inspect "$L3:LiquidationLogic" methodIdentifiers
forge inspect "$L4:LiquidationLogic" methodIdentifiers
```

Repeat both `abi`, `methodIdentifiers`, and `storageLayout` inspection for Pool/Spoke before/after; normalize non-layout AST identifiers. If added loader fixtures require explicit artifacts, build those too before its test command.

**Crane working directory `lib/crane`:**

```bash
forge build
forge test --match-path 'test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/*.t.sol' -vv
forge test --match-path 'test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/**/*.t.sol' -vv
forge build scripts/foundry/bc/Script_BC_Phase3_Aave.s.sol \
  scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol
```

Validate script helper outputs through hermetic tests, not script `run()` or broadcast. Do not launch FFI precompile scripts.

For each root, separately build the renamed V3 then V4 files, reverse their order, then build them together; inspect both targets after each step. Report cache-hit-only runs honestly; require at least one real invalidation/recompilation per ordering, using separately authorized disposable source-comment probes in dependent fixtures if necessary, never clearing cache.

Repeat IndexedEx helper `test` selections for all discovered `SeMatrix_AaveLoopFixture` consumers: single/dual normal and decimal F6/F9 suites and weighted `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_AaveCrossVersionLoop.t.sol`. Select concrete tests, not the fixture alone; record selected counts.

## Acceptance / remaining implementation checks

Ship only with: no live old-path lookups; untouched liquidation bodies; correct nonempty compilation targets in both roots; no unresolved/stale links in refreshed consumers; exact version-bound addresses; unchanged consumer ABI/storage and library selectors; real liquidation/deficit execution; complete invariant/cross-version/matrix/loader results; warm migration evidence; old/new ID/salt/hash/address table and runtime sizes. Existing deployed consumers remain unchanged; occupied component salts are not upgrades.

Installed versions, emitted placeholders, actual root usage, V3 provenance location, extra callers and test failures are **implementation checks**, not unanswered owner requirements. No passing result is claimed. High confidence in scope/readiness; actual execution success unverified.

Documentation accessed 2026-10-12 via Context7 first: https://github.com/foundry-rs/book/blob/master/src/pages/reference/forge/build.mdx (`[PATHS]`, destructive `--force`); https://github.com/foundry-rs/book/blob/master/src/pages/reference/forge/inspect.mdx (qualified contracts and inspection fields). Local evidence: current PRD §§3–8; `CLAUDE.md:47–61`; `ARTIFACT_BUILDS.md:14–55`; planner lines cited above. Current docs are not proof of the installed binary version.
