# Grok round 2 — PRD readiness and implementation plan

- Author: Grok (`xai/grok-4.7`). Date: 2026-10-12.
- Not a fresh independent pass. Prior council memory is historical. This round did not read other researchers' round-2 files or earlier cross-reviews.
- Research only. Commands below are **PROPOSED, NOT RUN**.
- Saved path: `docs/research/aave-liquidation-library-rename/round2-grok-original.md`.

## PRD readiness

`docs/plans/aave-liquidation-library-rename/PRD.md` is complete enough to implement the approved decision. The human has approved filename-only `LiquidationLogicAaveV3.sol` / `LiquidationLogicAaveV4.sol` with `library LiquidationLogic` retained. The PRD body already matches that decision: no symbol rename, no engine merge, seed retained, TestBase 4-arg bypass removed, no `via_ir`, no `forge build --force`, no `out/` or `cache_forge/` deletion.

The header still says "awaiting human approval." That line is stale relative to this approval. It is a status edit, not a missing requirement. Approval of the PRD is still not authorization to execute it.

**Blocking requirement questions: none.**

Supported roots are already declared and do not need an owner choice:

- IndexedEx tests and `ArtifactCreationCode`: repo root. Identity prefix `lib/crane/` (`remappings.txt`: `@crane/=lib/crane/`).
- Crane BC precompile: `cd lib/crane`, as `BC_AAVE_V4_DEPLOY_STEPS.md` lines 150–164. Identity prefix `contracts/` (`lib/crane/remappings.txt`: `@crane/contracts/=contracts/`).
- `src/spoke/...` is not a supported root. Emitters must stop producing it. Upstream examples stay only if labelled upstream.

These are implementation-time checks, not owner questions: re-grep before editing; stop if a second 4-arg `creationCode` caller exists (PRD §6.4); record installed `forge`/`solc` instead of assuming Forge 1.5.1; fill the link placeholder from a Crane-root compile, never a guessed hash; if no v3.6 provenance file exists, add the filename-deviation note next to v4 `VENDOR_PROVENANCE.md` and one sentence in `docs/protocols/lending.md`. Do not edit skills. Do not broadcast. Do not follow the BC doc's current `forge build --force` line; that command contradicts current `CLAUDE.md` lines 47–61 and PRD §3.

## Ordered edits

Paths relative to IndexedEx. Do not edit function bodies, constants, structs, visibility, licenses, or pragmas. No old-filename compatibility file.

1. Rename in place (implementation uses `git mv`; this session does not):
   - `lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogic.sol` → `LiquidationLogicAaveV3.sol`
   - `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogic.sol` → `LiquidationLogicAaveV4.sol`
2. Retarget the 11 live imports. Keep the binding name `LiquidationLogic`. Relative imports stay relative.
   - V3: `Pool.sol:13`, `LiquidationDataProvider.sol:12`, `AaveV3LibrariesBatch2.sol:11–13`, `LiquidationHelper.sol:6–8`, `Pool.Liquidations.CloseFactor.t.sol:31–32`, `Pool.Liquidations.t.sol:35–36`, `L2Pool.t.sol:14–16`.
   - V4: `Spoke.sol:21`, `Base.t.sol:85`, `LiquidationLogicWrapper.sol:10`, `CraneFactoryArtifactSeed.sol:28`.
3. `TestBase_AaveCrossVersionLoopV4Market.sol`: delete the V4 library import and the 4-arg call (lines 15, 81–88). Spoke bytecode becomes `ArtifactCreationCode.creationCode(create3Factory, "SpokeInstance.sol:SpokeInstance")`. Hub load stays as it is.
4. Seed: keep the file and `type(LiquidationLogic).name`. Replace the NatSpec that says naming cannot keep the artifact and that Spoke must use compiler creation code. State that the unique filename is what keeps `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json`, and that TestBases must not import the seed.
5. Re-grep `creationCode(` with four arguments and `libraryCreationCode_`. If only `ArtifactCreationCode.sol` defines the overload and the TestBase was the only caller, delete the 4-arg overload and the override threading (lines 42–53, 73–94, 114–129) and the "shared with Aave v3.6" comment. Keep 1-arg and 2-arg loaders, source matching, recursive linking, depth/empty/malformed checks, scratch compaction, and `releaseSalt`. If any other caller remains, stop.
6. `SpokeBytecodeLinker.sol`: change artifact ID and `FOUNDRY_LIBRARIES` prefix to `contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic`. Leave `LIQUIDATION_LOGIC_SALT = bytes32(0)`. Do not invent a replacement for `__$329ad157ba4e68d2f4f45d82720084bf07$__` until step 8.
7. `SpokeDeployUtils.sol`: same Crane-root ID in `vm.getCode` (line 22). Change `getLibraryString` (line 30) from `src/spoke/...` to the Crane-root ID. Tighten the `.env` regex (line 79) so it requires `LiquidationLogicAaveV4.sol:LiquidationLogic:` and does not accept a bare `LiquidationLogic:` from another version.
8. After the IndexedEx artifact build below, compile Spoke from the Crane root (proposed command). Read the unlinked Spoke artifact `linkReferences` key and the `__$…$__` token. Only then set `LIQUIDATION_LOGIC_PLACEHOLDER` to that token. If the compilation target is not the Crane-root path, the compile wins; do not force the IndexedEx `lib/crane/` string into Crane-root `FOUNDRY_LIBRARIES`.
9. Comments only, no API renames: `LibraryPreCompile.s.sol`, `AaveV4DeployAnvil.s.sol`, `Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol`, `Script_BC_Phase3_Aave.s.sol`, `BcAavePhase3Deploy.sol`. `BytecodeHelper` Hub/Spoke artifact names stay. `AaveV3LibrariesBatch2` keeps `type(LiquidationLogic).creationCode`. `echidna_config.yaml` stays. `scripts/shell/lib/rh_4663_stages.sh` keeps the seed path.
10. Docs: `C4/deployments/README.md` and `BC_AAVE_V4_DEPLOY_STEPS.md` get the new Crane-root filename and lose `forge build --force` as the recompile step. Review greenfield deployment docs for live path examples; leave archive and `docs/audits/`, `docs/security/`, `implementation-artifacts/` unchanged. Add a filename-deviation note to `lib/crane/docs/protocols/lending/aave/v4/VENDOR_PROVENANCE.md`. No v3.6 `VENDOR*.md` was found under `docs/protocols/lending`; do not invent upstream byte identity.

Do not rename `LiquidationLogic.*.t.sol`, `LiquidationLogicWrapper`, `getLiquidationLogic()`, or math libraries.

## Warm stale-link migration

`scripts/forge-artifacts.py` `library_artifacts` reads existing `bytecode.linkReferences` and `resolve_artifact` fails closed on a removed source. Run **build before plan**.

1. Do not delete or `--force` IndexedEx `out/` or `cache_forge/`, or Crane's copies.
2. Finish source edits 1–7 and 9–10 first, with the placeholder still old.
3. From IndexedEx root, build the renamed libraries and concrete linkers before any `plan` that might enqueue the old ID. Include the seed as an explicit source because `ArtifactSeed` is excluded as an independent root (`forge-artifacts.py` lines 39–44).
4. Then `plan` the V4 file and the TestBase. A stale-ID error is a failed gate, not a cue to ignore unresolved libraries or wipe cache. If it persists after the dependent rebuild, stop for a narrow planner review (PRD §8).
5. Order-independence does not need cache deletion. Unique basenames cannot share `out/LiquidationLogic.sol/`. After both new artifacts exist, rebuild only the V3 file and confirm the V4 JSON `compilationTarget` is unchanged; then the reverse. Stale `out/LiquidationLogic.sol/` may remain and must not be selected.

CREATE3 library salt becomes `abi.encode(<new source>:LiquidationLogic)._hash()`. CREATE2 salts stay (`bytes32(0)`, `AAVE_V3_LIBRARIES_BATCH`) but initcode metadata changes, so predicted addresses change. Record old/new IDs, salts, initcode hashes, and predicted addresses. Do not treat occupied old identities as upgrades. No broadcast.

## Proposed commands (not run)

IndexedEx root. Timeouts must be hours (`CLAUDE.md` line 48). No `--force`, no `FOUNDRY_TEST` change, no `via_ir`.

```bash
# after source edits, before plan
python3 scripts/forge-artifacts.py build \
  lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  lib/crane/contracts/protocols/lending/aave/v3.6/protocol/pool/Pool.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol \
  contracts/utils/foundry/CraneFactoryArtifactSeed.sol

python3 scripts/forge-artifacts.py plan \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  --consumer contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol

# Crane root, after IndexedEx sources are renamed; read placeholder from its out/
# cd lib/crane && forge build contracts/protocols/lending/aave/v4/spoke/Spoke.sol
# do not forge build --force

python3 scripts/forge-artifacts.py test \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol \
  --test-root test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol \
  --test-root test/foundry/spec/protocol/lending/aave/cross-version \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_AaveLoopFixture.sol \
  -- -vv
```

Crane-root suites, proposed separately from `lib/crane` with that tree's `out/` and `cache_forge/` left intact: `test/foundry/spec/protocols/lending/aave/3.6/protocol/pool/Pool.Liquidations.t.sol`, `Pool.Liquidations.CloseFactor.t.sol`, `L2Pool.t.sol`, `Pool.t.sol`; `test/foundry/spec/protocols/lending/aave/v4/contracts/spoke/libraries/liquidation-logic/`, `contracts/spoke/liquidation/`, `contracts/spoke/misc/Spoke.Getters.t.sol`, `contracts/spoke/configuration/Spoke.Config.t.sol`.

BC script compile-only, no broadcast and no `.env` write: `forge script scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol --sig "run()" -vv` from `lib/crane`, or the IndexedEx-root equivalent only to prove it does not emit `src/spoke/` or `lib/crane/` in the Crane-declared `FOUNDRY_LIBRARIES` line. If the script always writes `.env`, skip execution and review the string in source.

## Acceptance

- Both new files exist; no `LiquidationLogic.sol` under either Aave tree; `library LiquidationLogic` unchanged; no body diff.
- IndexedEx artifacts: `out/LiquidationLogicAaveV3.sol/LiquidationLogic.json` has `executeLiquidationCall` and compilation target ending in `LiquidationLogicAaveV3.sol`; V4 artifact has `liquidateUser` and `LiquidationLogicAaveV4.sol`. Neither target is the other file.
- Spoke/Pool `linkReferences` use the new source units. Source contains no `__$329ad157ba4e68d2f4f45d82720084bf07$__`. Placeholder equals the Crane-root compile token.
- TestBase does not import the library or pass `type(...).creationCode` for it. Seed file still exists and imports only the V4 filename.
- `getLiquidationLogic()` on a real V3 Pool and V4 Spoke equals that version's library deployment; the two addresses differ. Run a liquidation and a deficit path, not only a nonzero getter. `AaveCrossVersionLoop_Invariant.t.sol` is in the cross-version root.
- Pool/Spoke getter selectors and storage layouts unchanged. Library method identifiers unchanged because the symbol was not renamed. `liquidateUser` selector must match the pre-rename identifier; a change means a symbol edit leaked.
- Planner resolves `LiquidationLogicAaveV4.sol:LiquidationLogic` to one source. It must fail, not guess, on `LiquidationLogic.sol:LiquidationLogic`.
- Report versions, commands, skips, failures, initcode hashes, and predicted addresses. A missing run is not a pass.

## Stop

This plan does not authorize execution, submodule commit, broadcast, or skill edits. Green tests would not prove economic soundness or that an existing deployment was upgraded.
