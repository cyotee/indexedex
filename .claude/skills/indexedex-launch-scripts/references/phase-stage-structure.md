# Phase / Stage structure

Contents:

- File naming
- Phase map
- Two shells
- Skip, pin, rehearsal
- JSON and skip keys
- Simulate vs staged `all`
- Gold 46630 catalog
- Anti-patterns

SoT for **layout**: `docs/ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_PRD.md` §4.
SoT for **file names, Stage numbers, skip keys**: the matching implementation plan.
Gold on disk: `scripts/foundry/anvil_robinhood_testnet/` + `scripts/shell/lib/rh_46630_stages.sh`.

Do not invent a Stage that is in neither PRD nor plan.

## File naming

```text
scripts/foundry/<tree>/Phase_<PP>_Stage_<SS>_<PascalName>.s.sol   # thin Script
scripts/foundry/<tree>/Phase_<PP>_Stage_<SS>_<PascalName>.sol     # library body
deployments/<tree>/phase<PP>_stage<SS>_<slug>.json
```

Examples: `Phase_02_Stage_01_Create3Factory.s.sol`, `Phase_08_Stage_02_TtDolQ.s.sol`.

Shells invoke by Phase and Stage numbers, not aliases (`03b`, `stage06t`).
Bash octal: Stage `08` / `09` via `printf '%02d' "$((10#$n))"`.

Shared modules (rewrite IO around Phase file names; keep `FixtureEconomics` numbers):

- `DeploymentBase.sol`: chain id, `_outDir` / `OUT_DIR_OVERRIDE`, `_force` snapshot, `_shouldSkipStage`
- `LaunchIo.sol` / `LaunchState.sol`
- `RobinhoodCanonicalLib.sol`: **this-chain** pins with code only
- `FixtureEconomics.sol`

## Phase map

| Phase | Belongs | Does not |
|-------|---------|----------|
| **00** | Anvil-only: chain-id sanity, `deal` Dev 0 / Dev 1 | Anything that must run on public |
| **01** | External deps: **pin** if this chain has code, else **rehearsal** | Crane / IndexedEx factories, facets, packages, vaults, DETFs |
| **02** | CREATE3, Diamond Package Factory, Uni V4 Hook Factory | Common facets, manager |
| **03** | Common facets used by more than one SE or DETF package | Facets used by only one package (those stay in 05/06) |
| **04** | FeeCollector + Manager (facets, packages, diamonds), then minter facade | SE/DETF packages, token **instances** |
| **05** | SE rate-provider DFPkg, Uni V4 TWAP oracle (facet + DFPkg + canonical instance + adapter factory), then **one Stage per SE package** | SE **vault instances** |
| **06** | Bond NFT, rebasing claim, **one Stage per hook DFPkg**, **one Stage per DETF package** | DETF **instances** |
| **07** | Test tokens (core vs Mag7: separate Stages) and required Uni V4 SE **instances** | DETF instances; Morpho / Uni V3 SE instances (UI) |
| **08** | Protocol DETF instances (`DTF-DETF`, `TTDOL-Q`): separate Stages | Packages, tokens, SEs |
| **09** | Frontend export from prior JSON. No txs. | Deploys |

Promote a facet to Phase 03 in a **later** rewrite when it becomes shared. Do not leave copies in 05/06 and 03.

## Two shells

Same Foundry Stages. No one Foundry script that runs every Phase as the deploy path.

| Shell | Signer | Phases |
|-------|--------|--------|
| Anvil (`scripts/shell/anvil_robinhood_testnet.sh`) | Dev 0, `--unlocked` | 00 then 01–09 |
| Public (`scripts/shell/robinhood_testnet.sh`) | `--sender $DEPLOYER_ADDRESS` | No 00. Currently 01–09; subset is **not locked** |

`fresh_deploy.sh` is the Anvil helper (`--restart-anvil` then the Anvil shell).

4663 architecture tree is Phase/Stage (`scripts/shell/lib/rh_4663_stages.sh`): Anvil Phase 00 then 01–06 packages; public `robinhood_main.sh` has no Phase 00. Optional `simulate` still wraps library `execute()` in `Script_SimulateArchitecture.s.sol` for the 4663 funding quote. Do not port 46630 token/instance Stages onto 4663.

## Skip, pin, rehearsal

Every Stage: **return without broadcasting** when **all** catalog skip keys in its JSON are non-zero addresses with `code.length > 0`, unless `FORCE=1` / `--force`.

Skipped Stage **still rewrites** JSON (hydrate from disk).

`FORCE` is snapshotted in `_loadConfig` onto the Script instance (`forceEnabled`). Do not re-read process env inside `_shouldSkipStage`: Foundry tests share `FORCE` across parallel cases.

| Kind | If pin/JSON has code | If not |
|------|----------------------|--------|
| **Pin** (Permit2, WETH, Uni V4 cores) | Bind. Skip when JSON live unless FORCE. | **Fail.** Never deploy those. |
| **Rehearsal** (Uni V3 factory, Morpho) | Pin this-chain code. | `new UniswapV3Factory` + `enableFeeAmount(100,1)`; rehearsal Morpho + AdaptiveCurveIRM + OracleMock, enable IRM and 80% LLTV. Write **live** addresses. |
| **CREATE3** (Phase 02 Stage 01) | Skip if JSON factory has code unless FORCE. | **Always deploy a new CREATE3 for this tree.** Not a network-constants pin. |

`new Morpho` / `new UniswapV3Factory` **only** in Phase 01 rehearsal. Never `new` facets/DFPkgs.

Do **not** write Robinhood **main** CREATE2 (Morpho vault factory, registry, bundler) into 46630 JSON when that address has no code.

No `createMarket` in launch scripts. Morpho markets and Morpho / Uni V3 SE **vaults** are UI.

Uni V4 / Permit2 / WETH: never redeploy when they already have code.

## JSON

46630: `deployments/anvil_robinhood_testnet/phase<PP>_stage<SS>_<slug>.json`.

Key-by-key map and UI consumers: [frontend-export.md](frontend-export.md).

Skip keys are in the implementation plan (e.g. 01-01 `permit2`, 01-04 `v3Factory`, 02-01 `create3Factory`, 08-01 `DTF-DETF`). Phase 00 and Phase 09: empty skip keys; they always run (09 always rewrites).

Canonical getters in `RobinhoodCanonicalLib` for **live 46630** V4 / Permit2 / WETH only. Morpho / Uni V3 live addresses come from Phase 01 JSON.

## Simulate vs staged `all`

| Command | What |
|---------|------|
| Staged `all` / `--from-phase` / `--from-stage` | Default deploy path. Per-Stage simulate then broadcast. |
| Optional `simulate` | One Foundry script calling Stage **libraries** `execute()` in a single `startBroadcast` window. EIP-1559. No broadcast by default. Then quote from dry-run JSON. |

`simulate` is not `all`. Do not run it after a completed staged deploy on the same Anvil.

46630 **deleted** `Script_SimulateLaunch.s.sol` and `deploy_all.sh` as a second **deploy** orchestrator. Do not bring them back.

4663 gold for the quote path: `Script_SimulateArchitecture.s.sol` wrapping groups 01–03. 46630 has no simulate-quote script yet. Adding one is a PRD/plan amendment, not a silent extra file.

## Gold 46630 catalog (do not invent)

34 Stages. List: `scripts/shell/lib/rh_46630_stages.sh` (`rh_catalog_rows`) and `scripts/foundry/anvil_robinhood_testnet/README.md`.

Phase 03 is **one** Stage (`CommonFacets`). Phase 04-01 deploys FeeCollector **and** Manager **facets** via CREATE3, then packages, then diamonds. 04-02 is minter facade only. 05-02 deploys the Uni V4 TWAP facet + DFPkg + canonical instance + adapter factory (oracle diamond, not a vault). 05–06 otherwise are packages only. 07–08 are tokens / Uni V4 SEs / `DTF-DETF` / `TTDOL-Q` (premine before broadcast, `deployVault`, `deployPair`, finalize, first-bond as deployer EOA, launch-rich opening WAD from `FixtureEconomics`).

## Anti-patterns

- `Script_0N_*.s.sol` / `Stage_0N_*.sol` / `03b` aliases on a Phase/Stage tree
- Two orchestrators (`deploy_all.sh` plus a Stage catalog) on 46630
- `diamondPackageFactory.deploy` for a **registered** vault/DETF package
- Product brands (`RICH`, `RICHIR`) instead of DETF role names
- Pinning empty CREATE2 from another chain
- `--skip-simulation`
- `via_ir`
