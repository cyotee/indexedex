# PRD: 4663 architecture launch as Phases / Stages

**Date:** 2026-08-24  
**2026-09-11 composition extension:** The owner requested a plan to add the fee-accrual DETF and migrate the existing staking deposits/reward reserves through the staking contract's existing functions. The [deployment and staking migration plan](./FEE_ACCRUAL_DETF_DEPLOYMENT_AND_STAKING_MIGRATION_PLAN.md) defines a separate proposed catalog (§6): preflight 01-04, reuse the enhanced wrapper package 06-10 for custody, instances/providers 07-01–03, DETF/bootstrap/migration 08-03–08, and composition export 09-02. This extends the instance workflow without changing architecture-only `all` or redeploying the existing core/staking contract. The owner confirmed pooled migration of deposits and reward reserves through the staking contract; remaining configuration gates apply. No deployment execution is claimed.
**Status:** Accepted for implementation  
**Tree:** `scripts/foundry/anvil_robinhood_main/`  
**Chain:** Robinhood mainnet **4663**

**Related:** 46630 lab rewrite (`docs/ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_PRD.md`) stays the token/instance lab. This tree is **packages only**.

## Goal

Stand up Crane factories and IndexedEx architecture on 4663 so a Protocol DETF instance can be deployed later, after a pons Family sale supplies the Uni V4 `PoolKey`. No test tokens. No SE vault instances. No Protocol DETF instances in this catalog.

## Catalog (locked)

| Phase | Stage | File | Skip keys |
|-------|-------|------|-----------|
| 00 | 01 | `Phase_00_Stage_01_AnvilEnv` | none (Anvil shell only) |
| 01 | 01 | Permit2 pin | `permit2` |
| 01 | 02 | WETH pin | `weth` |
| 01 | 03 | Uni V4 cores pin | `poolManager`, `positionManagerV4`, `universalRouter` |
| 02 | 01 | CREATE3 | `create3Factory` |
| 02 | 02 | Diamond Package Factory | `diamondPackageFactory` |
| 02 | 03 | Uni V4 Hook Factory | `hookFactory` |
| 03 | 01 | Common facets | `erc20Facet`, `multiAssetBasicVaultFacet`, `diamondCutFacet` |
| 04 | 01 | FeeCollector + Indexedex Manager | `feeCollector`, `indexedexManager` |
| 05 | 01 | SE rate-provider DFPkg | `rateProviderPkg` |
| 05 | 02 | Uni V4 TWAP oracle (facet + DFPkg + canonical instance + adapter factory) | `twapOraclePkg`, `twapOracle`, `twapAdapterFactory` |
| 05 | 03 | Uni V4 SE DFPkg | `uniV4SePkg` |
| 05 | 05 | Morpho Blue SE DFPkg | `morphoBlueSePkg` |
| 06 | 01 | Uni V4 Bond NFT DFPkg (R12a) | `bondNftVaultPkg` |
| 06 | 02 | Rebasing claim DFPkg | `rebasingClaimTokenPkg` |
| 06 | 03 | CP buffer hook DFPkg | `cpHookPkg` |
| 06 | 04 | Weighted buffer hook DFPkg | `weightedHookPkg` |
| 06 | 06 | Curve Quad buffer hook DFPkg | `curveQuadHookPkg` |
| 06 | 07 | Unified Uni V4 DETF DFPkg | `uniV4DetfPkg` |
| 06 | 10 | `Phase_06_Stage_10_RebasingAwareERC4626Pkg` | `rebasingAwareErc4626Pkg`, ERC4626/SE/SY/metadata/quote facets, `releaseIdentifier`, registry, fingerprints |
| 09 | 01 | Frontend `chain/4663/` export | none (always rewrite) |

Stage numbers match 46630. **05-04** (Uni V3 SE) and **06-05** (Orbital hook) stay unused so those packages can fill later without renaming. Family DETF packages (old CP / Weighted / Quad DETF DFPkgs) are **not** in this catalog. One `UniswapV4DetfDFPkg` binds any in-scope SE buffer hook at instance deploy.

Morpho SE is a **package** only. Morpho Blue host is `PkgArgs` at vault deploy, not this catalog. No Morpho rehearsal (`new Morpho`) on 4663.

## Out of this catalog

- Minter facade, test tokens, Mag7
- Uni V3 rehearsal or Uni V3 SE package
- Orbital hook package
- Old family DETF packages (`UniswapV4SingleStandardExchangeDETF`, Weighted DETF, Curve Quad DETF)
- SE vault instances and Protocol DETF instances

Phase 09 writes `platform.json` and empty instance tokenlists under `frontend/packages/protocol/src/addresses/chain/4663/`. It does not overwrite `pons-launch.json`.

A later Stage (Phase 08 Protocol DETF) will deploy a Protocol DETF **instance** from `uniV4DetfPkg` plus a hook package, after a pons `PoolKey` exists. Hook DFPkg first (predicted DETF as owner). Do not add that Stage until the key exists.

## Rebasing-aware ERC4626 catalog amendment (2026-09-11)

The rebasing-aware ERC4626 package is a default architecture dependency, independently of TokenStaking. Stage 06-10 deploys its facet and DFPkg through the existing CREATE3 factory, reusing the shared ERC20 facet and Diamond Package Factory. It creates no vault instance. TokenStaking stages remain opt-in.

Implementation and validation plan:

- Extract the rebasing-aware deployment from 06-08 into the 06-10 library; 06-08 reuses that library to preserve its standalone behavior and deterministic addresses.
- Include 06-10 in the shared public/local catalog, architecture quote, and local package rehearsal.
- Write `phase06_stage10_rebasing_aware_erc4626_pkg.json`, with both package and facet as live-code skip keys; export the package address for frontend discovery.
- Compile the affected scripts, check shell catalog routing without broadcasting, and run hermetic coverage of package deployment/reuse and the existing staking wrapper behavior.

The existing package exposes ERC20 and ERC4626; this amendment does not add Standard Yield or Standard Exchange interfaces.

## TokenStaking ($DTF) — opt-in (not architecture `all`)

Interim same-token staking until the Protocol DETF instance exists. Reuses the live CREATE3 factory (`0xD7786b10BC8Bc97dc7651CAb7B97086c8b227882`) and Diamond Package Factory (`0x976949aB55830fA4794bF40C88ea7D7567931003`). Facets and DFPkgs via CREATE3 / `TokenStaking_Component_FactoryService`. Instance via `tokenStakingPkg.deployStaking(diamondPackageFactory, PkgArgs)` — not `indexedexManager`.

| Phase | Stage | File | Skip keys |
|-------|-------|------|-----------|
| 06 | 08 | `Phase_06_Stage_08_TokenStakingPkg` | `tokenStakingPkg` |
| 08 | 01 | `Phase_08_Stage_01_TokenStakingDtf` | `tokenStaking` |
| 08 | 02 | `Phase_08_Stage_02_TokenStakingNotifyRewards` | live `periodFinish` (skip if a reward period is already running, unless `FORCE=1`) |

- Deposit / reward token: `$DTF` `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` (pin; fail if no code)
- `rewardsDuration`: 7 days (`604800`)
- Owner: `DEPLOYER_ADDRESS`
- `ownershipBufferPeriod`: 2 days (package default)
- Instance deploy does **not** call `notifyRewardAmount`.
- Phase 08 Stage 02 (`token-staking-fund`) pulls the sender's full `$DTF` balance via Permit2 and calls `notifyRewardAmount`.

Public path matches `forge script`: no `--broadcast` simulates; `--broadcast` sends.

```bash
bash scripts/shell/robinhood_main.sh token-staking
bash scripts/shell/robinhood_main.sh token-staking --broadcast
bash scripts/shell/robinhood_main.sh token-staking-fund
bash scripts/shell/robinhood_main.sh token-staking-fund --broadcast
```

Do not add these Stages to architecture `all`. JSON: `phase06_stage08_token_staking_pkg.json`, `phase08_stage01_token_staking_dtf.json`, `phase08_stage02_token_staking_notify.json`.

## Shells

1. **Anvil:** `scripts/shell/anvil_robinhood_main.sh` — fork 4663, Dev 0, `--unlocked`, Phase 00 then 01–06 packages and Phase 09 export. EIP-170 **on**.
2. **Public:** `scripts/shell/robinhood_main.sh` — `DEPLOYER_ADDRESS`, no Phase 00, then Phase 09 export.
3. **Simulate (quote):** `Script_SimulateArchitecture.s.sol` still wraps library `execute()` in one `startBroadcast` window. Not the deploy path.

Same skip/FORCE/JSON rules as 46630. Never `--skip-simulation`. Never `new` facets/DFPkgs. TWAP is not a vault.

The fee-accrual extension also includes **07-04 FeeAccrualLiquiditySeed** between provider deployment and DETF deployment. It initializes the empty Pons liquidity SE with both assets, using a small part of the reviewed total bootstrap budget. It is excluded from architecture-only `all`.
