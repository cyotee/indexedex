# 46630 JSON keys and UI export

Contents:

- Pipeline
- Two JSON layers
- Stage JSON (skip keys)
- `platform.json` keys
- Tokenlists
- Aliases and traps
- After export
- Gold files

SoT writer: `scripts/foundry/anvil_robinhood_testnet/Phase_09_Stage_01_ExportFrontend.s.sol`.
SoT files on disk: `frontend/packages/protocol/src/addresses/chain/46630/`.
Do **not** overwrite `chain/4663/`. Do not treat `docs/DEPLOYMENT_SCRIPT_INVENTORY.md` or the old ten-DETF demo PRD as this map.

## Pipeline

```text
Phase 00–08  →  deployments/anvil_robinhood_testnet/phase<PP>_stage<SS>_<slug>.json
Phase 09     →  concatenates prior JSON (no txs)
             →  chain/46630/platform.json
             →  chain/46630/*.tokenlist.json
UI compile   →  ARTIFACT_REGISTRY['anvil_robinhood_testnet'][46630]
             →  getAddressArtifacts(46630, 'anvil_robinhood_testnet')
Aggregator   →  cd scripts/node && npm run build-tokenlists
             →  tokenlistRegistry.generated.ts  (LIST_REGISTRY, including featured-fee-detfs)
             →  chainPlatformOverrides.generated.ts  (platform overlay by chain id)
Apps         →  @indexedex/protocol tokenlists.ts + create/mint/staking/earn
```

Env for the 46630 lab:

```bash
NEXT_PUBLIC_DEFAULT_CHAIN_ID=46630
NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=anvil_robinhood_testnet
```

4663 and 46630 are first-class. `resolveArtifactsChainId` never remaps them to each other or to Sepolia.

## Two JSON layers

| Layer | Path | Role |
|-------|------|------|
| Stage artifacts | `deployments/anvil_robinhood_testnet/phase<PP>_stage<SS>_<slug>.json` | Skip/hydrate. Names in `LaunchIo.sol` `FILE_*`. |
| UI tree | `frontend/packages/protocol/src/addresses/chain/46630/` | What the protocol package and DTF/IndexedEx apps read. |

Phase 09 always rewrites both `FILE_09_01` (`phase09_stage01_export_frontend.json`) and the UI tree. Skip keys for 09 are empty.

`rpcUrl` in `platform.json` is written as `http://127.0.0.1:8545` even on a public 46630 run. The UI RPC comes from env / wagmi, not this field.

## Stage JSON (skip keys)

File names: `LaunchIo.sol`. Skip keys: implementation plan. Extra keys still hydrate later Stages.

| File | Skip keys | Also written |
|------|-----------|--------------|
| `phase00_stage01_anvil_env.json` | (none; always run) | chain sanity |
| `phase01_stage01_permit2.json` | `permit2` | |
| `phase01_stage02_weth.json` | `weth` | |
| `phase01_stage03_uniswap_v4.json` | `poolManager`, `positionManagerV4`, `universalRouter` | `quoter`, `stateView` if they have code |
| `phase01_stage04_uniswap_v3.json` | `v3Factory` | `v3Local` |
| `phase01_stage05_morpho_blue.json` | `morpho` | `morphoIrm`, `morphoOracle`, `morphoLocal`. **No** main CREATE2 vault-factory / bundler keys |
| `phase02_stage01_create3_factory.json` | `create3Factory` | |
| `phase02_stage02_diamond_package_factory.json` | `diamondPackageFactory` | |
| `phase02_stage03_hook_factory.json` | `hookFactory` | `hookFlagsFacet` |
| `phase03_stage01_common_facets.json` | `erc20Facet`, `multiAssetBasicVaultFacet`, `diamondCutFacet` | all common facets |
| `phase04_stage01_fee_collector_and_manager.json` | `feeCollector`, `indexedexManager` | |
| `phase04_stage02_erc20_minter_facade.json` | `erc20MinterFacade` | |
| `phase05_stage01_se_rate_provider_pkg.json` | `rateProviderPkg` | |
| `phase05_stage02_uniswap_v4_twap_oracle.json` | `twapOraclePkg`, `twapOracle`, `twapAdapterFactory` | `twapOracleFacet`, `poolManager` |
| `phase05_stage03_uniswap_v4_standard_exchange_pkg.json` | `uniV4SePkg` | |
| `phase05_stage04_uniswap_v3_standard_exchange_pkg.json` | `uniV3SePkg` | |
| `phase05_stage05_morpho_blue_standard_exchange_pkg.json` | `morphoBlueSePkg` | |
| `phase06_stage01_bond_nft_pkg.json` | `bondNftVaultPkg` | |
| `phase06_stage02_rebasing_claim_pkg.json` | `rebasingClaimTokenPkg` | |
| `phase06_stage03_cp_buffer_hook_pkg.json` | `cpHookPkg` | |
| `phase06_stage04_weighted_buffer_hook_pkg.json` | `weightedHookPkg` | |
| `phase06_stage05_orbital_buffer_hook_pkg.json` | `orbitalHookPkg` | |
| `phase06_stage06_curve_quad_buffer_hook_pkg.json` | `curveQuadHookPkg` | |
| `phase06_stage07_cp_detf_pkg.json` | `cpDetfPkg` | |
| `phase06_stage08_weighted_detf_pkg.json` | `weightedDetfPkg` | |
| `phase06_stage09_orbital_detf_pkg.json` | `orbitalDetfPkg` | |
| `phase06_stage10_curve_quad_detf_pkg.json` | `curveQuadDetfPkg` | |
| `phase07_stage01_core_test_tokens.json` | `DTF`, `TTUSDG`, `TTUSDE`, `TTWETH` | `tokenPkg` |
| `phase07_stage02_mag7_test_tokens.json` | `TTNVDA`, `TTMSFT`, `TTAAPL` | `TTGOOGL`, `TTAMZN`, `TTMETA`, `TTTSLA` |
| `phase07_stage03_uni_v4_se_dtf_weth.json` | `seRichWeth` | `rpRichWeth`, `v4Seeder` |
| `phase07_stage04_uni_v4_se_usd.json` | `seUsdeWeth`, `seUsdgWeth`, `seUsdgUsde` | matching `rp*` + `v4Seeder` |
| `phase08_stage01_fee_detf.json` | `DTF-DETF` | `DTF-CLAIM` |
| `phase08_stage02_ttdol_q.json` | `TTDOL-Q` | |
| `phase09_stage01_export_frontend.json` | (none) | copy of UI `platform.json` |

Phase 03 facet addresses stay in Stage JSON. They are **not** copied to `platform.json`.

`quoter` / `stateView` live in `phase01_stage03_uniswap_v4.json`. Phase 09 does **not** put them on `platform.json`. Create-path UI then falls back to `ROBINHOOD_UNISWAP_V4.stateView`.

## `platform.json` keys

Writer: `_writePlatform()`. Consumers: `getAddressArtifacts(…).platform` (IndexedEx create/mint/staking, DTF `sePlatform` / portfolio). Overlay: `CHAIN_PLATFORM_OVERRIDES[46630]` after `build-tokenlists`.

### Pins and core

| Key | What | UI |
|-----|------|-----|
| `chainId` | `46630` | `addressArtifacts.46630.test.ts`; normalizePlatform stamps it |
| `weth` | Canonical 46630 WETH | `normalizePlatform` also sets `weth9`; tokenlist has a separate `WETH` row |
| `permit2` | Canonical Permit2 | staking Permit2; fallback constant if missing |
| `poolManager` | Uni V4 PoolManager | create SE / DETF (`sePlatform`, `detfDeploy`) |
| `positionManagerV4` | Uni V4 PositionManager | periphery |
| `universalRouter` | Uni V4 Universal Router | swaps |
| `indexedexManager` | Manager diamond (also fee oracle) | create; `sePlatform.feeOracle` |
| `vaultRegistry` | **Same address** as `indexedexManager` | `getVaultRegistryAddress`; Earn registry |
| `feeCollector` | Fee collector diamond | protocol fees |
| `hookFactory` | Uni V4 hook diamond factory | `detfDeploy` / create |
| `create3Factory` | This tree’s CREATE3 | debug / create |
| `diamondPackageFactory` | Diamond package factory | `detfDeploy` |
| `erc20MinterFacade` | Mint facade | `/mint` `mintToken` |

### Packages (create wizard; not user-facing lists)

| Key | What |
|-----|------|
| `rateProviderPkg` | Shared SE rate-provider DFPkg |
| `twapOraclePkg` | Uni V4 multi-pool TWAP DFPkg |
| `twapOracle` | Canonical TWAP diamond instance for the pinned V4 PoolManager |
| `twapAdapterFactory` | CREATE3 Morpho / AggregatorV3 adapter factory |
| `uniV4SePkg` | Uni V4 SE DFPkg |
| `uniV3SePkg` | Uni V3 SE DFPkg (package only; no 07 instances) |
| `morphoBlueSePkg` | Morpho Blue SE DFPkg (package only; no 07 instances) |
| `cpHookPkg` / `cpDetfPkg` | CP buffer hook + CP DETF DFPkg |
| `weightedHookPkg` / `weightedDetfPkg` | Weighted |
| `orbitalHookPkg` / `orbitalDetfPkg` | Orbital |
| `curveQuadHookPkg` / `curveQuadDetfPkg` | Curve Quad |
| `bondNftVaultPkg` | Bond NFT DFPkg |
| `rebasingClaimTokenPkg` | Rebasing claim **package** (not an instance) |

### Rehearsal hosts (this chain, not Robinhood main CREATE2)

| Key | What |
|-----|------|
| `v3Factory` | Live V3 factory (pin or rehearsal) |
| `uniswapV3Factory` | Alias of `v3Factory` |
| `morpho` / `morphoBlue` | Live Morpho Blue (same address) |
| `morphoIrm` / `morphoOracle` | Rehearsal IRM + OracleMock |

**Must not appear:** `morphoVaultV2Factory`, `morphoVaultV2`, `morphoRegistry`, `bundler`, `bundler3`. Those are main-chain catalog rows with no 46630 code.

### Tokens, SEs, DETFs

| Key | What | Notes |
|-----|------|-------|
| `DTF`, `TTUSDG`, `TTUSDE`, `TTWETH` | Core mintable stand-ins | `/mint`; tags `token`+`testToken` |
| `TTNVDA`…`TTTSLA` | Mag7 stand-ins | same |
| `seRichWeth` | Uni V4 SE `DTF` / `TTWETH` | Plan skip key. **Not** a product brand in UI lists (tokenlist symbol `SE-DTF-TTWETH`) |
| `seUsdeWeth`, `seUsdgWeth`, `seUsdgUsde` | Uni V4 SEs for `TTDOL-Q` | |
| `DTF-DETF` | Fee Protocol DETF | `protocol-detfs` + `featured-fee-detfs` |
| `DTF-CLAIM` | Fee DETF `rebasingClaimToken` | base-tokens tag `claim` |
| `rebasingClaimToken` | **Alias of `DTF-CLAIM`**, not the quad claim | |
| `TTDOL-Q` / `$$DETF` | USD quad DETF (same address) | `protocol-detfs` symbol `$$DETF` |
| `I$$DETF` | Quad claim token | base-tokens tag `claim` |
| `deployer` / `uiWallet` | Anvil Dev 0 / Dev 1 (or public sender) | premint recipients |
| `networkProfile` | `anvil_robinhood_testnet` | |
| `rpcUrl` | hardcoded localhost | ignore for public |

No Morpho or Uni V3 **SE vault instances** on this platform.

## Tokenlists

Written by Phase 09. Dropdowns use `composeLists(getListRefs(46630))` (generated `LIST_REGISTRY`), **not** `ArtifactBundle.tokenlists` as the primary path. Featured fee DETFs load by **list id** `featured-fee-detfs`, not by tag.

`ARTIFACT_REGISTRY` still imports `base-tokens`, `strategy-vaults`, and `protocol-detfs` into the bundle (empty `erc4626` / Uni V2 / Aerodrome / Balancer). It does **not** put `featured-fee-detfs` on the bundle. Staking/Earn featured list needs the aggregator.

| File | Tags | Who reads it |
|------|------|----------------|
| `base-tokens.tokenlist.json` | `token`+`testToken` (11 stand-ins: `DTF` + 3 USD/WETH + 7 Mag7); `claim` (`DTF-CLAIM`, `I$$DETF`); `weth` (canonical WETH); `rh-faucet` (5 RH faucet stocks) | `/mint` = `getMintableTestTokensForChain` (testToken only; excludes WETH and faucet). Portfolio base tokens |
| `strategy-vaults.tokenlist.json` | `vault`+`se`+`strat` | Earn / DTF portfolio SEs. Four Uni V4 SEs only |
| `protocol-detfs.tokenlist.json` | `vault`+`detf` (`DTF-DETF`, `$$DETF`) | DTF list, portfolio, staking discovery. **No** `fee` tag here (test asserts that) |
| `featured-fee-detfs.tokenlist.json` | `vault`+`detf`+`fee` (`DTF-DETF` only) | IndexedEx home hero, `/staking`, Earn **exclude** (fee DETF is staking-only) |

Hermetic check: `frontend/packages/protocol/src/addressArtifacts.46630.test.ts` (2 protocol DETFs, 11 mintables, 5 faucets, WETH tag-only).

## Aliases and traps

| Do not confuse | With |
|----------------|------|
| `rebasingClaimToken` on platform | Quad claim. Platform key is the **fee** DETF claim. Quad claim is `I$$DETF` |
| `rebasingClaimTokenPkg` | A claim **instance** |
| `seRichWeth` | A token named RICH. It is the `DTF`/`TTWETH` SE |
| `$$DETF` | `DTF-DETF`. `$$DETF` is `TTDOL-Q` |
| `vaultRegistry` | A second diamond. Same as `indexedexManager` |
| `uniV3SePkg` / `morphoBlueSePkg` | Deployed SE vaults. Packages only; UI create-path, not 07 instances |
| `twapOracle` | Vault fee oracle. Fee oracle is `indexedexManager`. `twapOracle` is the Uni V4 poke TWAP instance |
| Stage `quoter` / `stateView` | `platform.json`. Create uses `ROBINHOOD_UNISWAP_V4` fallback |
| Old demo ten DETFs | This export. Only `DTF-DETF` and `TTDOL-Q` / `$$DETF` |
| `docs/DEPLOYMENT_SCRIPT_INVENTORY.md` 46630 table | Current Phase/Stage tree |

Create-path still accepts legacy platform aliases (`chirDetfPkg`, `bufferCpHookPkg`, `uniV3SePkg_rich`) in `sePlatform.ts`. 46630 export does **not** write those names.

## After export

1. Phase 09 has written `chain/46630/`.
2. Restart or rebuild the Next app so `@indexedex/protocol` re-imports JSON.
3. Run `cd scripts/node && npm run build-tokenlists` so `LIST_REGISTRY` and `CHAIN_PLATFORM_OVERRIDES` match the new files. Featured fee DETF and tag-composed dropdowns depend on this.
4. Point the app at 46630 (`anvil_robinhood_testnet`). DTF default is often `anvil_robinhood_main` / 4663; override env for this lab.

## Gold files

| Piece | Path |
|-------|------|
| Writer | `Phase_09_Stage_01_ExportFrontend.s.sol` |
| Stage names | `LaunchIo.sol` `FILE_*` |
| UI files | `frontend/packages/protocol/src/addresses/chain/46630/` |
| Registry | `frontend/packages/protocol/src/addresses/index.ts` (`anvil_robinhood_testnet`) |
| Resolve | `frontend/packages/protocol/src/addressArtifacts.ts` |
| Lists | `frontend/packages/protocol/src/tokenlists.ts` |
| Aggregator | `scripts/node` `npm run build-tokenlists` |
| Create platform | `frontend/apps/dtf/app/create/lib/sePlatform.ts` |
| Mint | DTF has no `/mint` route; `erc20MinterFacade` is still on `platform.json` |
| Spec | `frontend/packages/protocol/src/addressArtifacts.46630.test.ts` |
