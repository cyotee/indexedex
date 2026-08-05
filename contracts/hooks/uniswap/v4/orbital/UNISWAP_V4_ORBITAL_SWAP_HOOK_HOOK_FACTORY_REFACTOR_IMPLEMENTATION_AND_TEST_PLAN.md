# Implementation & Test Plan: Orbital Hook → Hook Diamond Package

**PRD:** [`UNISWAP_V4_ORBITAL_SWAP_HOOK_HOOK_FACTORY_REFACTOR_PRD.md`](./UNISWAP_V4_ORBITAL_SWAP_HOOK_HOOK_FACTORY_REFACTOR_PRD.md)  
**Product PRD:** [`UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md`](./UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md) (math/API; deploy sections superseded)  
**Status:** Implemented (2026-08-04)

## Delivered layout

```text
contracts/hooks/uniswap/v4/orbital/
  interfaces/
    IUniswapV4OrbitalSwapHook.sol           # product ABI (+ pair pool process views)
    IUniswapV4OrbitalSwapHookPackage.sol    # PkgInit / PkgArgs / deployVault
  facets/
    UniswapV4OrbitalSwapHookHooksFacet.sol
    UniswapV4OrbitalSwapHookLiquidityFacet.sol
  UniswapV4OrbitalSwapHookDFPkg.sol
  UniswapV4OrbitalSwapHookTarget.sol
  UniswapV4OrbitalSwapHookRepo.sol
  UniswapV4OrbitalSwapHookMath.sol
  UniswapV4OrbitalSwapHookPairPoolLib.sol
  UniswapV4OrbitalSwapHook_FactoryService.sol
  TestBase_UniswapV4OrbitalSwapHook.sol
```

**Retired monomorph:** `UniswapV4OrbitalSwapHook.sol`, `UniswapV4OrbitalSwapHookFactory.sol`,
`UniswapV4OrbitalSwapHookCommon.sol`, `IUniswapV4OrbitalSwapHookFactory.sol`.

## Deploy path (only production path)

1. `setHookDiamondPackageFactory(hookFactory)` once  
2. `registry.deployPkg(orbital DFPkg initCode, PkgInit, salt)`  
3. Premine `mineNonce` for `PRODUCT_ID` salt + pure flags  
4. `pkg.deployVault(args, mineNonce)` → `deployHookVault` → hook CREATE2 factory  
5. `initAccount` binds Repo + ERC20/EIP712/MultiAsset/StandardVault  
6. Package `postDeploy(proxy)` ensures three pair doors (idempotent)

## Salt & flags

- `PRODUCT_ID = keccak256("uv4-orbital-swap-hook")`  
- Salt: `PRODUCT_ID, poolManager, feeOracle, token0, token1, token2` (binding order)  
- Excludes: package address, facets, `msg.sender`, tickSpacing, sqrtPriceX96  
- Flags: BEFORE_INITIALIZE | BEFORE_ADD_LIQUIDITY | BEFORE_REMOVE_LIQUIDITY | BEFORE_SWAP | BEFORE_SWAP_RETURNS_DELTA  

## Tests

```bash
FOUNDRY_PROFILE=orbital forge test
```

Hermetic suite under `test/foundry/spec/hooks/uniswap/v4/orbital/` covers:

- Deploy / registry / flags / salt / idempotency / no diamondCut  
- Three pair doors  
- Sphere LP, swaps, fees, Permit2, adversarial, reentrancy  

Gold TestBase: `contracts/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol`  
Ladder: `CraneTest` → `IndexedexTest` → `TestBase_VaultComponents` → package TestBase.
