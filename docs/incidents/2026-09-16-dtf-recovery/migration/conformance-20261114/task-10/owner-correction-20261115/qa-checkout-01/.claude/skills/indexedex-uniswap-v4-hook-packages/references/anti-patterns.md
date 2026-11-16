# Anti-patterns (Uniswap V4 Hook Packages)

## Contents

- Deploy mistakes
- Salt / flags mistakes
- Package shape mistakes
- Naming mistakes
- Shared facet / reimplement mistakes
- Testing mistakes

## Deploy mistakes

| Wrong | Right |
|-------|--------|
| `registry.deployVault(hookPkg, args)` | `registry.deployHookVault(hookPkg, args, mineNonce)` or `pkg.deployVault(args, mineNonce)` |
| Product UX = direct `hookFactory.deploy*` | Product UX = package helper → registry (registers vault) |
| Forget `setHookDiamondPackageFactory` | Wire once after factory CREATE3 |
| `new MyHookPackage()` / `new MyFacet()` | CREATE3 + FactoryService / `deployPkg` |
| Subclass monomorph weighted/orbital hook | Fresh package implementing `IUniswapV4HookDiamondPackage` |

## Salt / flags mistakes

| Wrong | Right |
|-------|--------|
| Salt includes `address(pkg)` | processArgs → calcSalt(processed) → mineNonce only |
| Facet addresses in calcSalt for “versioning” | PRODUCT_ID + binding; redeploy package without changing salt |
| PkgArgs-dependent `requiredHookFlags` | Pure package-constant flags |
| Deep `isExpectedInstance` (loupe equality) | Thin: code present + flags match |
| Production auto-mine only | Premine + `deployWithMineNonce` / package `deployVault` |

## Package shape mistakes

| Wrong | Right |
|-------|--------|
| `PkgArgs` on the contract | `PkgArgs` / `PkgInit` on the **interface** |
| diamondCut in package `diamondConfig` | No cut; immutable after postDeploy |
| No vaultConfig on proxy | Facet cut so `_registerVault` can read config |
| WETH/product brand in generic role names | Role names per AGENTS.md (`rateAsset`, etc.) |

## Naming mistakes

| Wrong | Right |
|-------|--------|
| `UniswapV4SingleSEBCPHookDFPkg` / `SSEBCPHookFacet` types or files | Full product name: `UniswapV4SingleStandardExchangeBufferConstantProductHook*` |
| Short type names “for path length” without PRD exception | Full names; only **LP symbol** prefixes (`SSEBCP-`) may be short when PRD locks them |
| Renaming dual product to `DualSEBCP*` types because an old plan said “short OK” | Prefer full `UniswapV4DualStandardExchangeBufferConstantProductHook*` for new work |

## Shared facet / reimplement mistakes

| Wrong | Right |
|-------|--------|
| Product facet reimplements `balanceOf` / `transfer` / `totalSupply` for LP | Cut **`ERC20Facet`**; mint/burn via **`ERC20Repo`** |
| Product facet reimplements `permit` / `nonces` / `DOMAIN_SEPARATOR` / `eip712Domain` | Cut **`ERC2612Facet`** + **`ERC5267Facet`**; init **`EIP712Repo`** |
| Only cut `ERC20Facet` when hook **is** the LP | Full **ERC20PermitDFPkg** set: ERC20 + 5267 + 2612 |
| Product facet reimplements `vaultTokens` / `reserveOfToken` / `reserves` | Cut **`MultiAssetBasicVaultFacet`**; update via **`MultiAssetBasicVaultRepo`** |
| Product facet reimplements `vaultConfig` / `vaultTypes` / `contentsId` | Cut **`MultiAssetStandardVaultFacet`** |
| New `HookERC20Facet` / `MyBasicVaultFacet` under the product tree | Reuse `VaultComponentFactoryService` / TestBase handles; pass into `PkgInit` |
| Product `facetCuts` re-adds loupe / ERC165 / HookFlags | Factory **base** cuts only |
| Generic ERC-4626 SE In/Out **facet logic** as buffer-CP book swap | Keep SE **interfaces**; product facets own book math (see family plan) |
| Public product functions that **collide** with shared facet selectors | Product-only selectors; compose shared cuts first |

Full catalog: [shared-facets.md](shared-facets.md).

## Testing mistakes

| Wrong | Right |
|-------|--------|
| Mock factory / registry / package SUT | Real deploy path |
| Only factory-direct deploys for “product” tests | At least one path via `pkg.deployVault` → registry |
| Ignore `FOUNDRY_PROFILE=hook_factory` when default OOMs | Use narrow profile for this tree |
| Assert only “code.length > 0” | Flags, registry membership, idempotent address, immutability |

## Quick rejection phrases

If a PR or agent plan includes any of:

- “use DiamondPackageCallBackFactory for the hook address”
- “CREATE3 the diamond proxy so flags work”
- “include package address in salt for uniqueness”
- “keep diamondCut for upgrades on the hook instance”
- “shorten types to SEBCP / SSE for convenience”
- “implement ERC20 / vaultTokens / vaultConfig on the product facet”
- “copy MultiAssetBasicVaultTarget into the hook package”
- “ERC20 only for LP; skip 2612/5267 because Permit2 covers deposits”
- “implement permit() on the product Target instead of cutting ERC2612Facet”

…stop and re-read this skill + factory PRD + [shared-facets.md](shared-facets.md).
