# Hook package structure

## Contents

- Interfaces and structs
- Contract responsibilities
- Layout under `contracts/hooks/uniswap/v4/`
- Naming (full product types)
- Shared facets vs product facets
- Vault surfaces
- initAccount / storage
- Relation to monomorph hooks

## Interfaces and structs

Crane rule: **`PkgInit` and `PkgArgs` on the interface**, not the implementation contract.

```solidity
interface IMyHookPackage is IUniswapV4HookDiamondPackage, IStandardVaultPkg {
    struct PkgInit {
        IVaultRegistryDeployment vaultRegistryDeployment;
        // facets, poolManager, etc.
    }
    struct PkgArgs {
        // binding fields only
    }

    function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);
}
```

Also implement / extend:

- `IUniswapV4HookDiamondPackage` — `requiredHookFlags`, `isExpectedInstance`, full DFPkg lifecycle
- Instance vault surface for `_registerVault` — at least `IStandardVault.vaultConfig()` on the **proxy**
- Package declaration: `IStandardVaultPkg.vaultDeclaration()` for `deployPkg` registration

## Contract responsibilities

| Piece | Role |
|-------|------|
| Package contract | DFPkg: salt, diamondConfig, initAccount (delegatecall storage), postDeploy, **deployVault helper** |
| **Shared facets** (cut, not rewritten) | `ERC20Facet`, `MultiAssetBasicVaultFacet`, `MultiAssetStandardVaultFacet` — see [shared-facets.md](shared-facets.md) |
| Product Facets / Targets / Repos | Hook callbacks, book, deposit/withdraw, product SE routes — CREATE3 deploy |
| Hook factory | CREATE2 proxy + **base** cuts (loupe, ERC165, HookFlags, …) — not product-specific |
| Vault Registry | Auth + `deployHookVault` + vault index |

## Naming (full product types)

Use the **full product name** in Solidity types and file basenames. Do not invent `SEBCP` / `SSE` /
path-short type aliases for production contracts.

```text
# Good
UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol
UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet.sol

# Bad
UniswapV4SingleSEBCPHookDFPkg.sol
SSEBCPHookFacet.sol
```

Prose may say “Single SE Buffer CP Hook”. LP **symbol** may use PRD prefix `SSEBCP-`.  
`import { … as IHook }` is fine for stack/readability; the **declared type** remains full-length.

## Shared facets vs product facets

**Default for LP vault hooks:** `PkgInit` includes shared facet addresses; `facetCuts()` adds them
**before** product facets. Product Targets **must not** publish colliding IERC20 / IBasicVault /
IStandardVault selectors.

| Shared (cut) | Product (write) |
|--------------|-----------------|
| ERC20 + ERC5267 + ERC2612 (LP = ERC20PermitDFPkg) | `deposit` / `withdraw` / zap / previews |
| Basic + Standard vault views | V4 `beforeSwap` / liquidity bans / flags-required callbacks |
| (factory) loupe / HookFlags | SE In/Out **product** book math; buffer-last; kLast fees |

Full enumeration, repos, and anti-reimplement table: **[shared-facets.md](shared-facets.md)**.  
Gold: `…/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol`.

## Suggested layout

```text
contracts/hooks/uniswap/v4/<product-path>/
  interfaces/IUniswapV4<FullProductName>Package.sol   # PkgInit includes shared facet addresses
  UniswapV4<FullProductName>DFPkg.sol                 # facetCuts: shared + product
  UniswapV4<FullProductName>*Target.sol               # product logic only
  facets/UniswapV4<FullProductName>*Facet.sol         # size-split product facets
  UniswapV4<FullProductName>_FactoryService.sol       # CREATE3 product facets + deployPkg
  TestBase_UniswapV4<FullProductName>.sol             # package-adjacent gold TestBase
  UNISWAP_V4_<FULL_PRODUCT>_PRD.md
```

Shared facets live **outside** the product tree (`lib/crane` ERC20, `contracts/vaults/basic|standard`).

Factory infrastructure (shared):

```text
contracts/hooks/uniswap/v4/factory/      # factory, flags facet, PRD/plan
```

## initAccount and storage

- Proxy constructor → factory `initAccount` (delegatecall) → base cuts + package cuts + `pkg._initAccount(processed)`.
- Package `initAccount` runs in **proxy storage context** (adaptor DELEGATECALL from factory-in-proxy).
- Bindings go in Diamond storage / AwareRepos — not constructor immutables on the proxy.
- Do not put package/facet addresses in salt-relevant binding if they should be swappable.

## Vault config on the proxy

`_registerVault` calls `IStandardVault(vault).vaultConfig()` on the **new proxy**. Ensure package `diamondConfig` cuts a facet (often the package itself as facet, or a thin vault facet) that implements `vaultConfig` / types / contentsId.

## Monomorph vs package hooks

| Legacy monomorph | Hook diamond package |
|------------------|----------------------|
| CREATE3 + HookMinerCreate3 | CREATE2 + hook factory mineNonce |
| Single contract address is hook | Diamond proxy address is hook |
| Per-product factory often | Shared ecosystem factory |
| Not vault-registered by default | Registered via deployHookVault |

Do not subclass monomorph contracts for new packages; implement `IUniswapV4HookDiamondPackage` + registry path.

## Product logic vs deploy

This skill covers **package shape and deploy**. Hook callback behavior (beforeSwap, deltas, PoolManager unlock) still follows Uniswap V4 / family PRD and `uniswap-v4-hooks` style skills.
