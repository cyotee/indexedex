---
name: indexedex-uniswap-v4-hook-packages
description: >
  Guides implementation of IndexedEx Uniswap V4 Hook Diamond Packages (IUniswapV4HookDiamondPackage),
  package→Vault Registry→hook factory deploy, CREATE2 flag mining, salt without package address,
  HookFlags facet, immutable postDeploy diamonds, and production-first tests. Use when building or
  reviewing "V4 hook package", "UniswapV4HookDiamondPackage", "deployHookVault", "requiredHookFlags",
  "hook diamond factory", "mineNonce", Single SE Buffer CP Hook package, or any new hook DFPkg under
  contracts/hooks/uniswap/v4/. DO NOT use for monomorph CREATE3 hooks (legacy weighted/orbital/quad)
  unless migrating them; DO NOT use vault DiamondPackageCallBackFactory salt law for V4 flag addresses.
license: MIT
---

# IndexedEx Uniswap V4 Hook Packages

How to implement **true hook diamond packages** that deploy through the **Vault Registry** and the
**Uniswap V4 Hook Diamond Package Callback Factory** (not monomorph CREATE3 hooks, not vault factory salt).

**Read first:** `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing`, then this skill.
**Product law:** `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md`  
**Impl gold:** co-located plan + stub under `test/foundry/spec/hooks/uniswap/v4/factory/stubs/`.

## Canonical deploy path (mandatory)

```text
1. setHookDiamondPackageFactory(hookFactory)     # once per manager (owner/operator)
2. registry.deployPkg(hookPkg initCode, args, salt)
3. off-chain mine mineNonce (flags match)
4. HookPackage.deployVault(typedArgs, mineNonce)
     → registry.deployHookVault(pkg, abi.encode(args), mineNonce)
       → hookFactory.deployWithMineNonce(...)
       → _registerVault(...)   # hook is a vault
```

| Path | Factory | Registered vault? |
|------|---------|-------------------|
| `pkg.deployVault` → `deployHookVault` | Hook factory | **Yes** |
| Direct `hookFactory.deploy*` | Hook factory | **No** (tests/escape only) |
| `pkg.deployVault` → `deployVault` | **Vault** factory | **Wrong** for V4 flags |

## Quick package checklist

1. Interface holds `PkgInit` / `PkgArgs` (Crane DFPkg rule).
2. `is IUniswapV4HookDiamondPackage` + vault surfaces (`IStandardVaultPkg` / instance `vaultConfig`).
3. `requiredHookFlags() pure` — package-constant; factory masks to `Hooks.ALL_HOOK_MASK`.
4. `calcSalt(processed)` includes **stable PRODUCT_ID + binding fields** — **never** package/facet addresses.
5. `processArgs` documented; salt uses **processArgs → calcSalt** (factory P19).
6. `isExpectedInstance` **thin** (code + flags); no loupe/facet-set equality.
7. `diamondConfig` has **no** `diamondCut` facet.
8. Hold `IVaultRegistryDeployment`; implement typed `deployVault(args, mineNonce)` → `deployHookVault`.
9. Facets via CREATE3; package via registry `deployPkg` / FactoryService; never `new` for SUT.
10. Tests: hermetic + real factory/registry; `FOUNDRY_PROFILE=hook_factory` for this tree.
11. **Full product type/file names** — never compress to `SEBCP` / `SSE` / short hook type aliases (see Naming).
12. **Cut shared facets** for LP (ERC20+5267+2612 = ERC20PermitDFPkg) + Basic/Standard vault views — do **not** reimplement those selectors in product facets (see [shared-facets.md](references/shared-facets.md)).

## Naming (mandatory)

| Layer | Rule | Example |
|-------|------|---------|
| Solidity types, files, FactoryService, TestBase **contracts** | **Full product name** | `UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg` |
| Prose / PRD shorthand | Short labels OK | “Single SE Buffer CP Hook” |
| LP **symbol** prefix | PRD-locked short prefix OK | `SSEBCP-…` (D40) — **not** a type name |
| `import … as` aliases in tests | Short **local** alias OK | `as IHook` / `as TestBase` — file + type still full |

**Forbidden:** `UniswapV4SingleSEBCPHook*`, `SSEBCPHookFacet`, `DualSEBCP*` as production type/file names.

Gold tree:  
`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook*`

## Shared facets (mandatory reuse)

When the **hook is its own LP token**, cut **ERC20PermitDFPkg** facets + MultiAsset vault facets:

| Cut into proxy | Do not reimplement |
|----------------|--------------------|
| `ERC20Facet` | IERC20 LP (`balanceOf`, `transfer`, …) |
| `ERC5267Facet` | `eip712Domain` |
| `ERC2612Facet` | `permit` / `nonces` / `DOMAIN_SEPARATOR` |
| `MultiAssetBasicVaultFacet` | `vaultTokens` / `reserveOfToken` / `reserves` |
| `MultiAssetStandardVaultFacet` | `vaultConfig` / `vaultTypes` / `contentsId` / `vaultFeeTypeIds` |

`initAccount`: `ERC20Repo._initialize` **and** `EIP712Repo._initialize(name, "1")`.  
Factory base cuts (loupe, ERC165, HookFlags, …) stay on the **hook factory** — not product `facetCuts`.  
Product facets = V4 hooks + book + deposit/withdraw + product SE routes only.  
Full catalog + wiring: [references/shared-facets.md](references/shared-facets.md).

## Progressive disclosure

| Reference | Load when |
|-----------|-----------|
| [references/deploy-path.md](references/deploy-path.md) | Wiring registry, package helper, ACL |
| [references/salt-flags-immutability.md](references/salt-flags-immutability.md) | Salt law, mining, flags facet, postDeploy |
| [references/package-structure.md](references/package-structure.md) | File layout, interface/contract split, initAccount |
| [references/shared-facets.md](references/shared-facets.md) | Reuse ERC20 + MultiAsset vault facets; anti reimplement |
| [references/testing.md](references/testing.md) | TestBase, H matrix, forge profile |
| [references/anti-patterns.md](references/anti-patterns.md) | Forbidden patterns and fixes |

## Key paths

```text
contracts/hooks/uniswap/v4/factory/
  IUniswapV4HookDiamondPackage.sol
  IUniswapV4HookDiamondPackageCallBackFactory.sol
  UniswapV4HookDiamondPackageCallBackFactory.sol
  UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol
  UniswapV4HookFlagsFacet / Repo
  UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_*.md

contracts/interfaces/IVaultRegistryDeployment.sol   # deployHookVault*
contracts/registries/vault/VaultRegistryDeploymentTarget.sol

test/foundry/spec/hooks/uniswap/v4/factory/
  TestBase_*.sol
  stubs/UniswapV4HookDiamondFactoryStubPackage.sol   # gold deployVault
```

## Constraints (do not violate)

- **CREATE2** instances via hook factory (callback needs factory as `msg.sender`). Facets stay CREATE3.
- Salt: `finalSalt = keccak256(abi.encode(packageSalt, mineNonce))` — **no** `address(pkg)`.
- Instances **immutable** after postDeploy (no live `diamondCut`).
- Premine-first; auto-mine is gas-risky.
- Monomorph hooks under `weighted/` / `orbital/` / `stable/quad/` are **legacy** until migrated.
- **Full type names** for product contracts/files; short LP symbols only when PRD locks them.
- **Compose shared facets** via `PkgInit` + `facetCuts`: LP = `ERC20Facet` + `ERC5267Facet` + `ERC2612Facet` (ERC20PermitDFPkg); vault = `MultiAssetBasicVaultFacet` + `MultiAssetStandardVaultFacet`. Init `ERC20Repo` + `EIP712Repo`. Product code uses shared repos — no parallel LP/permit/vault view facets.

## See also

- `skill:indexedex-testing` — registry path, no mock SUT
- `skill:crane-deployment` — CREATE3 / DFPkg / FactoryService
- `skill:crane-architecture` — Facet / Target / Repo / DFPkg
- `skill:uniswap-v4-hooks` / Crane V4 skills — PoolManager hook semantics (product logic, not deploy)
- Family PRDs next to each hook product under `contracts/hooks/uniswap/v4/**`
