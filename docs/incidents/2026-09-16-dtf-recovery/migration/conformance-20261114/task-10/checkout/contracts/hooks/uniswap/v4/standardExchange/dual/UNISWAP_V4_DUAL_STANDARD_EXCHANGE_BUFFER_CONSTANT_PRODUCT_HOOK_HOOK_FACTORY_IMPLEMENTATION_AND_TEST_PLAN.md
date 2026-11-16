# Implementation & Test Plan: Dual SE Buffer CP Hook — Hook Factory Package

**Refactor PRD (deploy SoT):** [`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_HOOK_FACTORY_REFACTOR_PRD.md`](./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_HOOK_FACTORY_REFACTOR_PRD.md)  
**Product PRD (behavior SoT):** [`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`](./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md) (**v3.12** — deploy sections superseded by refactor PRD)  
**Gold shape:** Single SE Buffer CP under `…/constantProduct/single/` (pattern-copy, no subclass)  
**Skill:** `indexedex-uniswap-v4-hook-packages`  
**Date:** 2026-08-05  
**Status:** **Implemented** (hermetic package path green under `FOUNDRY_PROFILE=dual_se_buffer_cp_hook`)

---

## 1. Deploy path (only production path)

```text
1. setHookDiamondPackageFactory(hookFactory)
2. registry.deployPkg(Dual DFPkg initCode, PkgInit, salt)
3. premine mineNonce for PRODUCT_ID + sorted legs
4. pkg.deployVault(PkgArgs, mineNonce) → deployHookVault → CREATE2 bootstrap diamond
5. deployPair(tokenA, tokenB) then finalizeInitialization (staged init PRD; product key fee=0)
```

FactoryService exposes: `deployHooksFacet` / `deployDepositFacet` / `deployWithdrawFacet` / `deployPackage` / `findMineNonce` / `deployHook(pkg, args, mineNonce)` only. **No** CREATE3 monomorph `deployHook(create3Factory, …)`.

---

## 2. Package law

| Item | Value |
|------|--------|
| `PRODUCT_ID` | `keccak256("uv4-dual-se-buffer-constant-product-hook")` |
| `requiredHookFlags` | `BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA` |
| Salt | `PRODUCT_ID`, poolManager, feeOracle, **token-sorted** `(seLo,tLo,seHi,tHi)` — free ctor order → same address |
| `isExpectedInstance` | **Thin** code + flags only |
| Vault | `IBasicVault` + `IStandardVault` via shared MultiAsset facets; pair tokens = vaultTokens; reserves = claim supplies |
| LP | Shared ERC20 + ERC5267 + ERC2612; proxy is LP |
| SE In/Out | **Residual (D-SE):** not cut; swap previews remain on product surface. Vault/deploy DoD not blocked. |

---

## 3. Layout (shipped)

```text
contracts/hooks/uniswap/v4/standardExchange/dual/
  interfaces/
    IUniswapV4DualStandardExchangeBufferConstantProductHook.sol
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol
  facets/
    …HooksFacet.sol
    …DepositFacet.sol
    …WithdrawFacet.sol
  UniswapV4Dual…HookDFPkg.sol
  UniswapV4Dual…HookTarget.sol   # Repo bindings; no Common immutables
  UniswapV4Dual…HookRepo.sol
  UniswapV4Dual…HookMath / ClaimLib / PullLib
  UniswapV4Dual…Hook_FactoryService.sol
```

**Retired:** monomorph `…Hook.sol`, `…HookCommon.sol`, CREATE3 HookMiner deploy path.

**Non-authoritative (do not implement from):**  
`UNISWAP_V4_DUAL_BUFFER_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`  
Legacy monomorph plan sections in `UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` that prescribe CREATE3 instance deploy (superseded by this file + refactor PRD).

---

## 4. Testing

| Item | Value |
|------|--------|
| Profile | `FOUNDRY_PROFILE=dual_se_buffer_cp_hook` (dedicated product profile; peer of `single_se_buffer_cp_hook`) |
| TestBase | `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol` |
| Ladder | package → registry → hook factory; two real ERC-4626 SE legs; real PoolManager; no mock dual SUT |
| DoD suite | deploy/flags/salt/idempotent/swapped-legs/vault registry, deposit/withdraw/zap, fee growth, swap preview==exec |

**Compiler:** `via_ir = false` always. Stack depth via structs + helpers (crane-code-style), not IR.

---

## 5. Definition of Done (refactor)

1. Only package → registry → hook factory deploy path.  
2. `IUniswapV4HookDiamondPackage` + `IStandardVaultPkg`; structs on package interface.  
3. Instance registered vault; `vaultConfig` works.  
4. Flags + sorted salt + thin `isExpectedInstance`.  
5. Hermetic suite green under dual profile.  
6. Monomorph CREATE3 path removed from production/tests.  
7. Product PRD deploy supersession pointer present.  
8. This implementation plan exists.  
9. SE In/Out residual documented (this §2 + package interface NatSpec).

---

**End of hook-factory implementation plan**
