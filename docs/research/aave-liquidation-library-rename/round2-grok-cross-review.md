# Grok round-2 cross-review

- Reviewer: Grok (`xai/grok-4.7`). Date: 2026-10-12.
- Read: `round2-astra-original.md`, `round2-minimax-original.md`, `round2-kimi-original.md`, plus own `round2-grok-original.md` (unchanged). No other cross-reviews. No commands run.
- Verdict: **no blocking owner question.** PRD plus `BC_AAVE_V4_DEPLOY_STEPS.md:139–164` already decide the roots. Execution is still not authorized.

## Owner questions are not blockers

| Claim | Disposition |
|---|---|
| MiniMax Q1 / Kimi Q1: which root emits BC `FOUNDRY_LIBRARIES`? | **Resolved.** BC steps `cd` `lib/crane` and emit `contracts/protocols/.../LiquidationLogic.sol:LiquidationLogic`. After rename that prefix stays; only the basename becomes `LiquidationLogicAaveV4.sol`. IndexedEx `ArtifactCreationCode` stays on IndexedEx root (`lib/crane/...`). Do not ask the owner to pick again. A one-line PRD status/§5 clarification is administrative, as Astra said. |
| MiniMax Q2: IndexedEx 2-arg Spoke lookup root? | **Resolved.** The 2-arg call is `SpokeInstance.sol:SpokeInstance` from IndexedEx tests. It is not the library `FOUNDRY_LIBRARIES` string. |
| MiniMax Q3 / Kimi implicit overload approval | **Not an owner question.** PRD §6.4 already says remove the 4-arg overload only after zero callers, else stop. That stop is the approval gate. |
| MiniMax Q4 / Kimi Q2: fix `src/spoke/`? | **Already required.** PRD §5: that dialect is not valid for either root; correct emitters. `BC_AAVE_V4_DEPLOY_STEPS.md:145` already calls `SpokeDeployUtils.getLibraryString` wrong. Fix it to the Crane-root ID. Not a scope expansion. |
| MiniMax Q5 / math basenames | **Closed by PRD §9.** Follow-up only. Not this task. |
| Kimi Q3: live salt-0 / batch occupancy? | **Non-blocking evidence gap.** PRD §7 already forbids broadcast and says record old/new identities. If occupancy was not inspected, write "not inspected." Do not block code. |
| Astra cold-prep / stale "awaiting approval" header | **Administrative.** Interpret cold prep as a seeded worktree plus missing-artifact fixtures, not `rm` of shared `out/` or `cache_forge/`. Update PRD status when editing docs. Neither blocks the plan. |

MiniMax B.7 still allows `--force` for placeholder regeneration. Reject. PRD §3 forbids it. MiniMax B.6 cites `SpokeBytecodeLinker.sol:30` for `getLibraryString`; that function is `SpokeDeployUtils.sol:30`. MiniMax still claims the `.env` regex substring-matches `LiquidationLogicAaveV4:`. It does not: the pattern is `LiquidationLogic:`. Qualify it anyway so a later V3 line cannot win.

## Command corrections (including Grok's own plan)

`scripts/forge-artifacts.py` `build` and `test` call `graph.plan()` before `execute_plan` (`main` lines 411–428). `plan` reads existing `bytecode.linkReferences` and `resolve_artifact` fails on a removed ID (`library_artifacts` 198–212, queue 240–253). **Do not bootstrap with `forge-artifacts.py build`.** Grok round 2, Kimi phase 4, and MiniMax step 5 are wrong on that order. Astra is right: direct `forge build` of renamed libraries and concrete dependents first.

`SeMatrix_AaveLoopFixture.sol` is not a `.t.sol` test. `--test-root` on that file does not run the matrix. Consumers, re-checked this pass, all import the fixture:

- `dual/UniswapV4DualSEBCPHook_SeMatrix_AaveCrossVersionLoop.t.sol` plus `_F6` and `_F9`
- `single/UniswapV4SingleSEBufferHook_SeMatrix_AaveCrossVersionLoop.t.sol` plus `_F6` and `_F9`
- `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_AaveCrossVersionLoop.t.sol` plus `_F6` and `_F9`
- `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_AaveCrossVersionLoop.t.sol` plus `_F6` and `_F9`
- `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_AaveCrossVersionLoop.t.sol` plus `_F6` and `_F9`
- `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_AaveCrossVersionLoop.t.sol` plus `_F6` and `_F9`
- `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_AaveCrossVersionLoop.t.sol` plus `_F6` and `_F9`

Paths are under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`. Decimal files sit in each family's `decimals/` directory. Repeat `--test-root` on those `.t.sol` files or on those directories. Do not pass the fixture alone.

`forge script … run()` is execution (FFI, `.env`, possible broadcast). Grok round 2 was wrong to offer it. Validate scripts with `forge build` of the `.s.sol` paths only. Assert the Crane-root string in source. Do not run `LibraryPreCompile`.

`--all-artifacts` (Astra) still walks existing link refs. Use it only after the direct rebuild, and treat a stale-ID failure as "rebuild that consumer," not cache deletion.

## Recommended plan

1. Record `forge`/`solc` versions and Pool/Spoke method and storage baselines. Do not delete caches. Seed a new worktree from warm `out/` and `cache_forge/` if one is used.
2. Rename the two files to the approved suffixes. Retarget the 11 imports. Remove the TestBase import and 4-arg call. Keep the seed; fix its comment. Keep `library LiquidationLogic`, Echidna bindings, and V3 `type(...).creationCode` deployment.
3. Crane-root emitters: `contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic` in `SpokeBytecodeLinker` and `SpokeDeployUtils` (`vm.getCode` and `getLibraryString`). Qualify the `.env` regex to that filename. Leave the placeholder constant stale until step 5.
4. Re-grep 4-arg callers. If none, delete the overload and its recursion plumbing. If any remain, stop.
5. **Bootstrap, IndexedEx root, direct Forge, no `--force`:**

```bash
forge build \
  lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  lib/crane/contracts/protocols/lending/aave/v3.6/instances/PoolInstance.sol \
  lib/crane/contracts/protocols/lending/aave/v3.6/instances/L2PoolInstance.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol \
  contracts/utils/foundry/CraneFactoryArtifactSeed.sol
```

6. **Crane root** (`cd lib/crane`), same rule, so the placeholder matches `contracts/...` not `lib/crane/...`:

```bash
forge build \
  contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol \
  scripts/foundry/bc/Script_BC_Phase3_Aave.s.sol \
  scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol
```

Read `lib/crane/out/SpokeInstance.sol/SpokeInstance.json` link references. Set `LIQUIDATION_LOGIC_PLACEHOLDER` to that compile's token. Rebuild SpokeInstance once. Do not grep an IndexedEx `out/` artifact and paste it into the Crane constant.

7. Only then `python3 scripts/forge-artifacts.py plan` / `test` with explicit sources and `.t.sol` or directory `--test-root`s: `ArtifactCreationCode.t.sol`, `test/foundry/spec/protocol/lending/aave/cross-version` (includes `AaveCrossVersionLoop_Invariant.t.sol`), and the 21 matrix `.t.sol` files above. Crane pool/spoke suites from `lib/crane` via `forge test --match-path …` after that root's `forge build`. `python3 -m unittest scripts/test_forge_artifacts.py` is a planner unit check, not a substitute for the Solidity suites.

8. Docs: new Crane-root filename; delete the `--force` recompile instruction; provenance note on v4 `VENDOR_PROVENANCE.md`; v3.6 note only if a provenance file is found, else one sentence in `docs/protocols/lending.md`. No skill edits, no archive rewrites, no broadcast.

Acceptance unchanged from the PRD: both new artifacts, correct compilation targets, no old placeholder in source, distinct version-bound `getLiquidationLogic()` addresses, real liquidation and deficit paths, unchanged Pool/Spoke selectors and storage, library selectors unchanged, stale `out/LiquidationLogic.sol/` never selected. A missing run is not a pass.

## Corrections by author

- **Grok round 2:** no owner blocker stands. Replace helper-first build, fixture `--test-root`, and `forge script` with the sequence above.
- **Astra:** adopt direct `forge build`, script `forge build`, and concrete matrix tests. PoolInstance and L2PoolInstance paths exist. Do not treat `--all-artifacts` as the bootstrap.
- **Kimi:** Q1 is documentation hygiene, not a phase-2 blocker. Helper `build` is not safe first. Placeholder grep must use the Crane-root `out/`, after `cd lib/crane`.
- **MiniMax:** withdraw Q1–Q4 as blockers; withdraw `--force`; fix the linker file citation and the regex claim.

No researcher ran these commands. Agreement on this sequence is not proof the build will succeed.
