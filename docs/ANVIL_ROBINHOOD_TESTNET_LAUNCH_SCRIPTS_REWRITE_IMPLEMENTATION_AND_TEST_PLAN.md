# Implementation Plan: Rewrite 46630 launch scripts (Phases / Stages)

**PRD (product + layout SoT):** [`ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_PRD.md`](./ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_PRD.md) (**Accepted**)  
**This plan (implementor SoT):** file map, Stage numbers, skip keys, shells, cutover  
**Date:** 2026-08-23  
**Status:** **READY FOR EXECUTION**

---

## Goal-command bootstrap

```text
Implement docs/ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_IMPLEMENTATION_AND_TEST_PLAN.md
against docs/ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_PRD.md (Accepted).

Read both fully before editing. PRD wins on Phase law. This plan wins on
file names, Stage numbers, JSON keys, skip rules. If a Stage is in neither,
STOP — do not invent.

Replace scripts/foundry/anvil_robinhood_testnet/ group 00–09 scripts with
Phase_PP_Stage_SS_*.s.sol. Two shells: Anvil Dev 0 (00–09, fork 46630) and
public DEPLOYER_ADDRESS (no Phase 00; 01–09 until a later PRD shrinks it).

Never `new` facets/DFPkgs. `new Morpho` / `new UniswapV3Factory` only in
Phase 01 rehearsal Stages. Registry for vault/DETF packages.
Never via_ir. DETF role names only. Forge patience 20–40+ min.
Seed cache_forge/ + out/ before first forge in a new worktree.

Do not edit anvil_robinhood_main / anvil_robinhood_fee_detf / chain/4663.
Do not script Morpho createMarket or Morpho/Uni V3 SE instances.
```

---

## Authority

| Layer | Wins on |
|-------|---------|
| Rewrite PRD | Phases, pin vs rehearsal, UI vs script instances, shells |
| This plan | Paths, Stage order, JSON keys, skip keys, cutover |
| Family / SE package PRDs + gold TestBases | `PkgInit` / `deployVault` call shapes |
| Skills | `indexedex-launch-scripts` (Phase/Stage + Anvil), `crane-deployment`, `crane-architecture`, `indexedex-testing`, `indexedex-uniswap-v4-hook-packages` |

Copy **behavior** from the current group scripts (`Stage_03_*.sol`, `Stage_03c`, `Stage_03d`, `Stage_04*`, `Stage_05`, `Stage_06_*`, `Script_09`). Do not copy group numbers or `03b` aliases.

---

## Skip rule (every Stage)

A Stage **returns without broadcasting** when **all** of its **skip keys** in its JSON file are non-zero addresses with `code.length > 0`, unless `FORCE=1`.

Each Stage still **re-writes** its JSON when skipped (hydrate from disk) so export stays consistent.

Pin Stages (Phase 01 Uni V4 / Permit2 / WETH): skip keys are the pinned addresses; first run requires bytecode on the fork or the Stage **fails** (do not deploy rehearsal V4 / Permit2 / WETH).

Rehearsal Stages (Uni V3 factory, Morpho): if skip keys missing or no code, **deploy** rehearsal and write live addresses.

---

## Directory and shells

Keep `scripts/foundry/anvil_robinhood_testnet/` as the Foundry home.

| Path | Role |
|------|------|
| `scripts/foundry/anvil_robinhood_testnet/Phase_PP_Stage_SS_*.s.sol` | Thin Foundry script per Stage |
| `scripts/foundry/anvil_robinhood_testnet/Phase_PP_Stage_SS_*.sol` | Library body |
| `DeploymentBase.sol`, `LaunchIo.sol`, `LaunchState.sol`, `FixtureEconomics.sol`, `RobinhoodCanonicalLib.sol` | Shared; rewrite IO/state to Phase JSON names |
| `scripts/shell/anvil_robinhood_testnet.sh` | **Anvil:** fork 46630, Dev 0, Phase 00 then 01–09 |
| `scripts/shell/robinhood_testnet.sh` | **Public:** `DEPLOYER_ADDRESS`, **no** Phase 00, currently 01–09 (subset later) |
| `fresh_deploy.sh` | Anvil helper: `--restart-anvil` then Anvil shell |

Delete old `Script_0N_*.s.sol`, `Stage_0N_*.sol`, `Script_SimulateLaunch.s.sol`, and `deploy_all.sh` **after** the new Stages run. Do not keep two orchestrators.

JSON artifacts: `deployments/anvil_robinhood_testnet/phase<PP>_stage<SS>_<slug>.json`.

---

## Stage catalog

### Phase 00 — Anvil env (Anvil shell only)

| Stage | File | Skip keys | Does |
|-------|------|-----------|------|
| 01 | `Phase_00_Stage_01_AnvilEnv.s.sol` | none (or chain-id already 46630 + Dev 0 funded) | Sanity: chain 46630. `deal` Dev 0 / Dev 1 if balances are low. No public equivalent. |

### Phase 01 — External deps

| Stage | File | Skip keys | Does |
|-------|------|-----------|------|
| 01 | `Phase_01_Stage_01_Permit2.s.sol` | `permit2` | Pin canonical Permit2. Fail if no code. |
| 02 | `Phase_01_Stage_02_Weth.s.sol` | `weth` | Pin `ROBINHOOD_TESTNET.WETH`. Fail if no code. |
| 03 | `Phase_01_Stage_03_UniswapV4.s.sol` | `poolManager`, `positionManagerV4`, `universalRouter` | Pin live V4 cores (also serialize quoter / stateView if they have code). Fail if PoolManager missing. **Never** deploy V4. |
| 04 | `Phase_01_Stage_04_UniswapV3.s.sol` | `v3Factory` | If factory pin has code, pin it. Else `new UniswapV3Factory`, `enableFeeAmount(100,1)`. JSON is the **live** factory. |
| 05 | `Phase_01_Stage_05_MorphoBlue.s.sol` | `morpho` | If a **this-chain** Morpho has code at a future constants pin, bind. Else rehearsal `Morpho` + AdaptiveCurveIRM + OracleMock, enable IRM and 80% LLTV. JSON live `morpho`, `morphoIrm`, `morphoOracle`. **No** `createMarket`. Do not write Robinhood **main** CREATE2 into this JSON when it has no code. |

### Phase 02 — Crane factories

| Stage | File | Skip keys | Does |
|-------|------|-----------|------|
| 01 | `Phase_02_Stage_01_Create3Factory.s.sol` | `create3Factory` | **Always deploy** a new CREATE3 for this tree (R20). Split `InitDevService.initEnv` if it also deploys the diamond factory; Stage 01 must not be the only home of the diamond factory. |
| 02 | `Phase_02_Stage_02_DiamondPackageFactory.s.sol` | `diamondPackageFactory` | Deploy Diamond Package Factory via CREATE3. |
| 03 | `Phase_02_Stage_03_HookFactory.s.sol` | `hookFactory` | Deploy Uni V4 Hook Diamond Package Factory + hook flags facet. Do not wait for Crane promotion. |

### Phase 03 — Common facets

| Stage | File | Skip keys | Does |
|-------|------|-----------|------|
| 01 | `Phase_03_Stage_01_CommonFacets.s.sol` | `erc20Facet`, `multiAssetBasicVaultFacet`, `diamondCutFacet` | **One Stage.** Deploy: ERC20, ERC2612, ERC5267, ERC4626, ERC4626 basic/standard vault, multi-asset basic/standard vault, MultiStepOwnable, Operable, DiamondCut. Serialize all of them. |

### Phase 04 — IndexedEx core

| Stage | File | Skip keys | Does |
|-------|------|-----------|------|
| 01 | `Phase_04_Stage_01_FeeCollectorAndManager.s.sol` | `feeCollector`, `indexedexManager` | Deploy FeeCollector **and** Manager **facets** here, then packages, then diamonds. `setHookDiamondPackageFactory`. Fee/bond/liquid defaults (current `FixtureEconomics`). Create3 `setOperator(manager)`. |
| 02 | `Phase_04_Stage_02_Erc20MinterFacade.s.sol` | `erc20MinterFacade` | Deploy Minter Facade diamond/package. Do not deploy test tokens here. |

### Phase 05 — SE packages

Package-only facets stay in that Stage.

| Stage | File | Skip keys | Does |
|-------|------|-----------|------|
| 01 | `Phase_05_Stage_01_SeRateProviderPkg.s.sol` | `rateProviderPkg` | Shared SE rate-provider DFPkg. |
| 02 | `Phase_05_Stage_02_UniswapV4TwapOracle.s.sol` | `twapOraclePkg`, `twapOracle`, `twapAdapterFactory` | CREATE3 TWAP facet + DFPkg + adapter factory. `deployOracle({ poolManager: canonical V4 })` for the canonical instance. Not a vault. Also write `twapOracleFacet`. Bind Phase 01 V4 PoolManager pin. |
| 03 | `Phase_05_Stage_03_UniswapV4StandardExchangePkg.s.sol` | `uniV4SePkg` | Uni V4 SE DFPkg + its In/Out/Query/PositionImport/LiquidReserve facets. `PkgInit.twapOracle` is the 05-02 instance. Bind Phase 01 V4 pins. |
| 04 | `Phase_05_Stage_04_UniswapV3StandardExchangePkg.s.sol` | `uniV3SePkg` | Uni V3 SE DFPkg + its facets. Bind live `v3Factory` from 01-04. |
| 05 | `Phase_05_Stage_05_MorphoBlueStandardExchangePkg.s.sol` | `morphoBlueSePkg` | Morpho Blue SE DFPkg + Morpho ERC4626/In/Out/Marker facets. Bind live Morpho from 01-05. No vaults. |

### Phase 06 — DETF packages and hooks

Family-specific hook/DETF facets stay in that Stage. Shared ERC721 + DETF NFT vault facet: Bond NFT Stage. Claim facet: Claim Stage.

| Stage | File | Skip keys | Does |
|-------|------|-----------|------|
| 01 | `Phase_06_Stage_01_BondNftPkg.s.sol` | `bondNftVaultPkg` | Bond NFT DFPkg + ERC721 + DETF NFT vault facets used only here. |
| 02 | `Phase_06_Stage_02_RebasingClaimPkg.s.sol` | `rebasingClaimTokenPkg` | Rebasing claim DFPkg + claim facet. |
| 03 | `Phase_06_Stage_03_CpBufferHookPkg.s.sol` | `cpHookPkg` | CP single SE buffer hook DFPkg + its facets. |
| 04 | `Phase_06_Stage_04_WeightedBufferHookPkg.s.sol` | `weightedHookPkg` | Weighted buffer hook DFPkg + facets. |
| 05 | `Phase_06_Stage_05_OrbitalBufferHookPkg.s.sol` | `orbitalHookPkg` | Orbital buffer hook DFPkg + facets. |
| 06 | `Phase_06_Stage_06_CurveQuadBufferHookPkg.s.sol` | `curveQuadHookPkg` | Curve Quad buffer hook DFPkg + facets. |
| 07 | `Phase_06_Stage_07_CpDetfPkg.s.sol` | `cpDetfPkg` | CP Single DETF DFPkg + its DETF facets. |
| 08 | `Phase_06_Stage_08_WeightedDetfPkg.s.sol` | `weightedDetfPkg` | Weighted DETF DFPkg + facets. |
| 09 | `Phase_06_Stage_09_OrbitalDetfPkg.s.sol` | `orbitalDetfPkg` | Orbital DETF DFPkg + facets. |
| 10 | `Phase_06_Stage_10_CurveQuadDetfPkg.s.sol` | `curveQuadDetfPkg` | Curve Quad DETF DFPkg + facets. |

Gold: copy `PkgInit` field sets from current `Stage_03_UniV4Packages` / `Stage_03b_OrbitalWeightedPackages`. Registry `deployPkg` / family `FactoryService.deployPkg`.

### Phase 07 — Tokens and Uni V4 SE instances

| Stage | File | Skip keys | Does |
|-------|------|-----------|------|
| 01 | `Phase_07_Stage_01_CoreTestTokens.s.sol` | `DTF`, `TTUSDG`, `TTUSDE`, `TTWETH` | Deploy token DFPkg if needed. Mintable `DTF`, `TTUSDG`, `TTUSDE`, `TTWETH`. Authorize facade. Mint 1e12 to deployer and UI wallet (current `FixtureEconomics.PREMINT`). |
| 02 | `Phase_07_Stage_02_Mag7TestTokens.s.sol` | `TTNVDA`, `TTMSFT`, `TTAAPL` | Mag7 `TTNVDA`…`TTTSLA`. Same facade operator + mint policy as current 04b. |
| 03 | `Phase_07_Stage_03_UniV4SeDtfWeth.s.sol` | `seRichWeth` | Uni V4 SE + pool for `DTF` / `TTWETH` (fee DETF door). Width 1. RP on. |
| 04 | `Phase_07_Stage_04_UniV4SeUsd.s.sol` | `seUsdeWeth`, `seUsdgWeth`, `seUsdgUsde` | Three Uni V4 SEs for `TTDOL-Q`. No DETF deploy. |

No Morpho SE instances. No Uni V3 SE instances.

### Phase 08 — Protocol DETF instances

Copy current `Script_06_Ttchir` / `Script_06e_DolQ` behavior (premine **before** broadcast, `deployVault`, `deployPair`, finalize, first-bond as deployer EOA, launch-rich opening WAD from `FixtureEconomics`).

| Stage | File | Skip keys | Does |
|-------|------|-----------|------|
| 01 | `Phase_08_Stage_01_FeeDetf.s.sol` | `DTF-DETF` | Fee DETF `DTF-DETF` / claim `DTF-CLAIM`. Pair `TTWETH`. SE from 07-03. |
| 02 | `Phase_08_Stage_02_TtDolQ.s.sol` | `TTDOL-Q` | USD quad. SEs from 07-04. |

### Phase 09 — Export

| Stage | File | Skip keys | Does |
|-------|------|-----------|------|
| 01 | `Phase_09_Stage_01_ExportFrontend.s.sol` | none (always rewrite JSON) | Read prior Stage JSON. Write `chain/46630/` platform + tokenlists. Live `morpho`, `v3Factory`, pkgs, facade, tokens, Uni V4 SEs, `DTF-DETF`, `TTDOL-Q`. No mainnet Morpho catalog keys. No txs. |

---

## Shared modules

Rewrite `LaunchState` / `LaunchIo` around Phase file names. Keep `FixtureEconomics` numbers (fees, opening WAD, premint, pool fee 3000 / tick 60). `RobinhoodCanonicalLib` pin getters for **live 46630** V4 / Permit2 / WETH only. Morpho/Uni V3 live addresses come from Phase 01 JSON, not from main CREATE2 dumps.

Do **not** add `Script_SimulateLaunch`.

---

## Shells

**Anvil** `scripts/shell/anvil_robinhood_testnet.sh`:

- Fork 46630 (`robinhood_testnet_alchemy`, fallback public). `--chain-id 46630 --disable-code-size-limit --unlocked`.
- Signer Anvil Dev 0.
- Run Phase 00 Stage 01, then every Stage 01–09 in catalog order.
- Simulate each Foundry Stage, then broadcast (same as current `deploy_all.sh`: never `--skip-simulation`).
- `FORCE=1` / `--force` re-runs Stages.
- Optional: `--from-phase PP --from-stage SS` resume.

**Public** `scripts/shell/robinhood_testnet.sh`:

- No Phase 00. `--sender $DEPLOYER_ADDRESS`.
- Today: Phases 01–09. Comment in the script: public subset is **not** locked; change only after Anvil UI testing + PRD patch.

---

## Cutover

1. Add new Phase files beside old group scripts.
2. Point Anvil shell at the new Stage list.
3. Green Anvil run through Phase 09 (or through Phase 06 + 09 if 07–08 compile-blocked; do not ship a half cutover).
4. Delete old `Script_0*.s.sol`, `Stage_0*.sol`, `Script_SimulateLaunch.s.sol`, `deploy_all.sh`.
5. README in the Foundry dir: Phase table + two shells only.

---

## Definition of done

- [x] Every Stage file exists with the names in this plan.
- [x] Anvil shell forks 46630, Dev 0, runs 00 then 01–09.
- [x] Public shell exists, no Phase 00.
- [x] Skip-if-JSON-valid works; `FORCE` re-runs.
- [x] CREATE3 is deployed in 02-01, not read from network constants.
- [x] Phase 03 is a single common-facet Stage.
- [x] Phase 04-01 includes FeeCollector/Manager facets.
- [x] No Morpho/Uni V3 SE instances; no Morpho `createMarket`.
- [x] Phase 09 `platform.json` has live rehearsal Morpho + V3 factory + pkgs + facade + tokens + Uni V4 SEs + two protocol DETFs.
- [x] Old group scripts and `SimulateLaunch` removed after cutover.
- [x] `forge` not killed for “no progress”; seed `cache_forge/` + `out/` in new worktrees.

---

## Out of scope

- Hook Factory promotion into Crane.
- Canonical CREATE3 in `ROBINHOOD_TESTNET.sol`.
- Public Stage subset smaller than 01–09.
- Weighted/Stable create-wizard UI txs.
- `anvil_robinhood_main` / `anvil_robinhood_fee_detf`.
