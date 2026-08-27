# Redeploy inventory: SE `widthMultiplier` removal

Date: 2026-08-26

Removed unused `widthMultiplier` from Uniswap V3 and Uniswap V4 Standard Exchange `PkgArgs`, `deployVault`, instance salt, and proxy strategy storage. Vault join/exit/tick math did not read the value. Identity is the bound pool only.

This file is the on-chain redeploy list. Tests, launch scripts, and the DTF create ABI already match the new `deployVault` arity.

## Deploy rules

- Facets: CREATE3 via `*FactoryService` (`deploy*Facet`). Never `new`.
- Vault packages: `vm.prank(owner); indexedexManager.deploy*DFPkg(...)`. Never `diamondPackageFactory.deploy` for registered vault packages.
- CREATE3 salt is type-name (V4 SE facets also mix `"wethWrap"`). Occupied salt keeps **old bytecode**. Lab: `FORCE=1` or a fresh Anvil. Live 4663: existing facet/package addresses stay until you change salt or abandon the instance.
- DETF diamonds are immutable after deploy. Do not `diamondCut` live vaults onto new repo layout. Old SE instances keep the old package and old `deployVault(pool, width)` / `deployVault(poolKey, width)` ABI. New instances come from the new packages.

## What changed in source

| File | Change |
|------|--------|
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol` | `PkgArgs { PoolKey poolKey }`. `deployVault(PoolKey)`. Init writes position salts only. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol` | Deleted `StrategyConfig` (`widthMultiplier`, `centerWidthMultiplier`, `activeLiquidityBps`). `_initialize(bytes32 salt_)`. |
| `contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol` | `PkgArgs { IUniswapV3Pool pool }`. `deployVault(IUniswapV3Pool)`. No vault-repo init write. |
| `contracts/protocols/dexes/uniswap/v3/UniswapV3VaultRepo.sol` | Deleted `StrategyConfig` and `_initialize(uint24)`. |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimDFPkg.sol` | `UniswapV4PositionRepo._initialize(centerSalt)` only. Claim **still** stores `widthMultiplier` in `UniV4DetfRebasingClaimRepo` for wing ticks. |

`UniswapV3StandardExchangeCommon.sol` and `UniswapV4StandardExchangeCommon.sol` only lost NatSpec that mentioned width. Compiler metadata of every inheriting facet still changes.

## Must redeploy (new ABI / init)

These packages bake `PkgArgs` and `initAccount`. Old package addresses keep the old `deployVault` selector.

| Package | Factory / manager call | Launch stage |
|---------|------------------------|--------------|
| `UniswapV4StandardExchangeDFPkg` | `indexedexManager.deployUniswapV4StandardExchangeDFPkg` (`UniswapV4_Component_FactoryService`) | `anvil_robinhood_testnet` and `anvil_robinhood_main` **Phase 05 Stage 03** (`uniV4SePkg`) |
| `UniswapV3StandardExchangeDFPkg` | `indexedexManager.deployUniswapV3StandardExchangeDFPkg` (`UniswapV3_Component_FactoryService`) | `anvil_robinhood_testnet` **Phase 05 Stage 04**; `anvil_robinhood_fee_detf` **Script 05** |

After the new package is registered, **new SE vaults** use:

- V4: `pkg.deployVault(poolKey)`
- V3: `pkg.deployVault(pool)`

Instance salt is `calcSalt(abi.encode(PkgArgs))`. Same pool as an old `{pool, width}` deploy lands at a **different** vault address. That is intended.

Shared cuts on those packages do **not** change and do **not** need redeploy:

- `ERC20Facet`, `ERC5267Facet`, `ERC2612Facet`
- `MultiAssetBasicVaultFacet`, `MultiAssetStandardVaultFacet`

## Product facets (CREATE3)

Product facets inherit Common and inline the position/vault repo. Source graph changed. On a **fresh** chain, Stage 05 deploys them as part of the package stage. On a chain that already has code at the name salt, CREATE3 will keep the old facet unless `FORCE=1` or the salt suffix changes.

Functionally, join/exit still use `centerPosition` (slots before the deleted strategy word). V3 **position import** writes `imported*` fields that sat **after** `StrategyConfig`, so that facet is the one that must match the new layout if you import NFTs on vaults from the **new** package.

### Uniswap V4 Standard Exchange

Deploy helpers: `UniswapV4_Component_FactoryService` (facet salts include `"wethWrap"`).

| Contract | Helper |
|----------|--------|
| `UniswapV4StandardExchangeInExecutionDelegate` | `deployUniswapV4StandardExchangeInExecutionDelegate` |
| `UniswapV4StandardExchangeInFacet` | `deployUniswapV4StandardExchangeInFacet` |
| `UniswapV4StandardExchangeInQueryFacet` | `deployUniswapV4StandardExchangeInQueryFacet` |
| `UniswapV4StandardExchangePositionImportFacet` | `deployUniswapV4StandardExchangePositionImportFacet` |
| `UniswapV4StandardExchangeOutExecutionDelegate` | `deployUniswapV4StandardExchangeOutExecutionDelegate` |
| `UniswapV4StandardExchangeOutFacet` | `deployUniswapV4StandardExchangeOutFacet` |
| `UniswapV4StandardExchangeOutQueryFacet` | `deployUniswapV4StandardExchangeOutQueryFacet` |
| `UniswapV4StandardExchangeLiquidReserveFacet` | `deployUniswapV4StandardExchangeLiquidReserveFacet` |
| `UniswapV4StandardExchangeInMultiFacet` | `deployUniswapV4StandardExchangeInMultiFacet` |
| `UniswapV4StandardExchangeInMultiQueryFacet` | `deployUniswapV4StandardExchangeInMultiQueryFacet` |
| `UniswapV4StandardExchangeOutMultiFacet` | `deployUniswapV4StandardExchangeOutMultiFacet` |
| `UniswapV4StandardExchangeOutMultiQueryFacet` | `deployUniswapV4StandardExchangeOutMultiQueryFacet` |

Wire the new facet addresses into the **new** `UniswapV4StandardExchangeDFPkg` `PkgInit`. Do not point a new package at old product facets if you also FORCE-replaced any of the above.

### Uniswap V3 Standard Exchange

Deploy helpers: `UniswapV3_Component_FactoryService` (name-hash salts).

| Contract | Helper |
|----------|--------|
| `UniswapV3StandardExchangeInExecutionDelegate` | `deployUniswapV3StandardExchangeInExecutionDelegate` |
| `UniswapV3StandardExchangeInFacet` | `deployUniswapV3StandardExchangeInFacet` |
| `UniswapV3StandardExchangeInQueryFacet` | `deployUniswapV3StandardExchangeInQueryFacet` |
| `UniswapV3StandardExchangeOutExecutionDelegate` | `deployUniswapV3StandardExchangeOutExecutionDelegate` |
| `UniswapV3StandardExchangeOutFacet` | `deployUniswapV3StandardExchangeOutFacet` |
| `UniswapV3StandardExchangeOutQueryFacet` | `deployUniswapV3StandardExchangeOutQueryFacet` |
| `UniswapV3StandardExchangePositionImportFacet` | `deployUniswapV3StandardExchangePositionImportFacet` |
| `UniswapV3StandardExchangeLiquidReserveFacet` | `deployUniswapV3StandardExchangeLiquidReserveFacet` |
| `UniswapV3StandardExchangeInMultiFacet` | `deployUniswapV3StandardExchangeInMultiFacet` |
| `UniswapV3StandardExchangeInMultiQueryFacet` | `deployUniswapV3StandardExchangeInMultiQueryFacet` |
| `UniswapV3StandardExchangeOutMultiFacet` | `deployUniswapV3StandardExchangeOutMultiFacet` |
| `UniswapV3StandardExchangeOutMultiQueryFacet` | `deployUniswapV3StandardExchangeOutMultiQueryFacet` |

Same `PkgInit` rule as V4.

## Leftover Uni V4 DETF rebasing claim (not production DETF claim)

Production Uni V4 SE DETFs wire **`RebasingClaimTokenDFPkg`** (Phase 06 Stage 02). That package was **not** changed. Do **not** redeploy DETF DFPkgs, hook packages, or `DETFNFTVault` for this work.

`UniV4DetfRebasingClaimDFPkg` / `UniV4DetfRebasingClaimFacet` is the old wing-claim package. Its `initAccount` now calls salt-only `UniswapV4PositionRepo._initialize`. Redeploy only if you still deploy that leftover package:

| Contract | Helper |
|----------|--------|
| `UniV4DetfRebasingClaimFacet` | `UniV4DetfRebasingClaim_FactoryService.deployUniV4DetfRebasingClaimFacet` |
| `UniV4DetfRebasingClaimDFPkg` | `UniV4DetfRebasingClaim_FactoryService.deployUniV4DetfRebasingClaimDFPkg` |

## Do not redeploy

| Surface | Why |
|---------|-----|
| `DETFNFTVault*` / `IDetfSelfNftInventoryDFPkg` | Unchanged. Holds ERC-20 reserve LP. |
| `RebasingClaimTokenDFPkg` / claim facet | Production DETF claim. Unchanged. |
| Uni V4 hook packages (CP, orbital, weighted, Curve quad) | Unchanged. |
| Uni V4 SE DETF packages (CP, orbital, weighted, Curve quad) | `PkgInit` still points at the same claim/NFT **types**. No constructor field changed. |
| Slipstream SE | Still sizes ticks with `widthMultiplier`. |
| Uni V2 / Camelot / Aerodrome / Morpho SE | Out of scope. |
| Manager, vault registry, fee oracle, Permit2, WETH, PoolManager | Out of scope. |
| TWAP oracle package | Out of scope. |

## Callers (off-chain, not CREATE3)

Update anything that still encodes the second `uint24`:

- DTF `frontend/apps/dtf/app/create/lib/seAbi.ts` (`V4_SE_PKG_ABI`, `V3_SE_PKG_ABI`) and `SeVaultSlot.tsx` (already done)
- `scripts/foundry/anvil_robinhood_testnet/UniV4SeInstanceLib.sol` and `Phase_07_Stage_04_UniV4SeUsd.sol` (already done)
- `scripts/foundry/anvil_robinhood_fee_detf/Script_05_DeployUniV3SeOnRichPool.s.sol` (already done)
- `scripts/foundry/local_testing/anvil_single/Script_12_DeployScenario3Overlay.s.sol` (already done)

Frontend `platform.json` package addresses change when Stage 05 writes a new `uniV4SePkg` / `uniV3SePkg`. Re-export Phase 09 after those stages.

## Suggested lab sequence

1. `FORCE=1` on Phase 05 Stage 03 (V4 SE facets + DFPkg) and Stage 04 (V3 SE facets + DFPkg), or wipe Anvil.
2. Redeploy any SE **vault instances** you still need (Phase 07 SE stages, fee-DETF Script 05, scenario overlay).
3. Leave Phase 06 DETF/hook/NFT/claim stages unless you also FORCE the leftover `UniV4DetfRebasingClaim*` pair.
4. Phase 09 frontend export if UI talks to the new packages.

Existing SE vaults created with `widthMultiplier` in the salt are a different instance set. Do not expect `deployVault(pool)` to hit those addresses.
