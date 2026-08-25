# PRD: 4663 architecture launch as Phases / Stages

**Date:** 2026-08-24  
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
| 06 | 01 | Bond NFT DFPkg | `bondNftVaultPkg` |
| 06 | 02 | Rebasing claim DFPkg | `rebasingClaimTokenPkg` |
| 06 | 03 | CP buffer hook DFPkg | `cpHookPkg` |
| 06 | 04 | Weighted buffer hook DFPkg | `weightedHookPkg` |
| 06 | 06 | Curve Quad buffer hook DFPkg | `curveQuadHookPkg` |
| 06 | 07 | CP single SE DETF DFPkg | `cpDetfPkg` |
| 06 | 08 | Weighted DETF DFPkg | `weightedDetfPkg` |
| 06 | 10 | Curve Quad DETF DFPkg | `curveQuadDetfPkg` |
| 09 | 01 | Frontend `chain/4663/` export | none (always rewrite) |

Stage numbers match 46630. **05-04** (Uni V3 SE) and **06-05 / 06-09** (Orbital) stay unused so those families can fill later without renaming.

Morpho SE is a **package** only. Morpho Blue host is `PkgArgs` at vault deploy, not this catalog. No Morpho rehearsal (`new Morpho`) on 4663.

## Out of this catalog

- Minter facade, test tokens, Mag7
- Uni V3 rehearsal or Uni V3 SE package
- Orbital hook or DETF packages
- SE vault instances and Protocol DETF instances

Phase 09 writes `platform.json` and empty instance tokenlists under `frontend/packages/protocol/src/addresses/chain/4663/`. It does not overwrite `pons-launch.json`.

A later Stage (Phase 08) will `deployPair` / first-bond a Protocol DETF from a pons `PoolKey`. Do not add that Stage until the key exists.

## Shells

1. **Anvil:** `scripts/shell/anvil_robinhood_main.sh` — fork 4663, Dev 0, `--unlocked`, Phase 00 then 01–06 packages and Phase 09 export. EIP-170 **on**.
2. **Public:** `scripts/shell/robinhood_main.sh` — `DEPLOYER_ADDRESS`, no Phase 00, then Phase 09 export.
3. **Simulate (quote):** `Script_SimulateArchitecture.s.sol` still wraps library `execute()` in one `startBroadcast` window. Not the deploy path.

Same skip/FORCE/JSON rules as 46630. Never `--skip-simulation`. Never `new` facets/DFPkgs. TWAP is not a vault.
