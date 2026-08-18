# Implementation & Test Plan: Quad Stable Swap Hook → Hook Diamond Package

**Date:** 2026-08-04  
**Status:** Shipped with refactor  
**Authority:** [`UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_HOOK_FACTORY_REFACTOR_PRD.md`](./UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_HOOK_FACTORY_REFACTOR_PRD.md)  
**Product math law:** [`UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md`](./UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md) (deploy sections superseded)

## Goal

Migrate the 4-asset StableSwap hook from CREATE3 monomorph + product factory onto the shared Uniswap V4 hook diamond package callback factory, preserving product behavior.

## Delivered layout

```text
contracts/hooks/uniswap/v4/stable/quad/curve/
  interfaces/
    IUniswapV4CurveQuadStableSwapHook.sol
    IUniswapV4CurveQuadStableSwapHookPackage.sol
  facets/
    UniswapV4CurveQuadStableSwapHookHooksFacet.sol
    UniswapV4CurveQuadStableSwapHookLiquidityFacet.sol
  UniswapV4CurveQuadStableSwapHookDFPkg.sol
  UniswapV4CurveQuadStableSwapHookTarget.sol
  UniswapV4CurveQuadStableSwapHookRepo.sol
  UniswapV4CurveQuadStableSwapHookMath.sol
  UniswapV4CurveQuadStableSwapHookPairPoolLib.sol
  UniswapV4CurveQuadStableSwapHook_FactoryService.sol
  TestBase_UniswapV4CurveQuadStableSwapHook.sol
```

**Retired:** monomorph `UniswapV4CurveQuadStableSwapHook.sol`, `…Factory.sol`, `…Deployer.sol`, `…Common.sol`, `IUniswapV4CurveQuadStableSwapHookFactory.sol`.

## Deploy path (normative)

```text
1. setHookDiamondPackageFactory(hookFactory)
2. registry.deployPkg(quad DFPkg init)
3. premine mineNonce (PRODUCT_ID + binding flags)
4. pkg.deployVault(args, mineNonce) → deployHookVault → CREATE2 diamond
5. deployPair × 6 then finalizeInitialization → six pair doors + production ABI
6. addLiquidity / zapIn / swaps
```

| Field | Salt / binding |
|-------|----------------|
| `PRODUCT_ID` | `keccak256("uv4-curve-quad-stable-swap-hook")` |
| Includes | poolManager, token0..3 (sorted), lpFeePips, baseAmp, rateProviders[4] |
| Excludes | package/facet addresses, saltNamespace, caller, mineNonce |

| Flags (pure package constant) |
|-------------------------------|
| BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_REMOVE_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA \| **BEFORE_DONATE** |

## Storage

- Bindings + product reserves: `UniswapV4CurveQuadStableSwapHookRepo` via `initAccount`
- LP: shared `ERC20Repo` + ERC20Permit facets
- Vault views: `MultiAssetBasicVaultRepo` / `StandardVaultRepo` (synced on reserve updates)

## Test ladder

`CraneTest` → `IndexedexTest` → `TestBase_VaultComponents` → `TestBase_UniswapV4CurveQuadStableSwapHook`

**Profile:** `FOUNDRY_PROFILE=quad_stable`

```bash
FOUNDRY_PROFILE=quad_stable forge test -vv
```

### Coverage matrix

| Area | Tests |
|------|--------|
| Binding views / flags / registry | `*_Deploy.t.sol` |
| Six doors, salt, unsorted, rates-in-salt, ensure | `*_Factory.t.sol` |
| First mint / remove / mixed decimals | `*_Liquidity.t.sol` |
| Fee-on-output swaps all six pairs | `*_Swap.t.sol` |
| Zap sharesMin | `*_Zap.t.sol` |
| Rate fail-closed | `*_Rates.t.sol` |
| Donate / CL ban | `*_Safety.t.sol` |
| Reentrancy hostile tokens | `*_Reentrancy.t.sol` |
| Pure math fixtures | `*_Math.t.sol` |

Production-first: real PoolManager hermetic port; no mock package/factory/registry/SUT.

## DoD checklist

1. Production path is only package → registry → hook factory  
2. `IUniswapV4HookDiamondPackage` + vault surfaces complete  
3. Flags include beforeDonate; salt law product ID + binding  
4. Six doors ensureable without product CREATE3 factory  
5. Hermetic suite green under `quad_stable`  
6. Monomorph + product factory retired  
7. Product PRD deploy sections marked superseded  
8. This implementation/test plan file exists  
