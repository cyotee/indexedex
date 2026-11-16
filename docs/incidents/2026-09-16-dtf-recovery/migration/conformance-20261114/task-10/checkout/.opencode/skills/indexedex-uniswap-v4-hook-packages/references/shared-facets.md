# Shared facets to cut — do not reimplement

Hook diamond packages are **composition**. Standard token/vault ABI lives in **shared facets** already
used by SE vault packages. Product facets only implement **hook-specific** logic (V4 callbacks, CP
book, SE buffer routes, deposit/withdraw, fees).

**Gold cut list:**  
`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol`  
(`facetCuts` / `PkgInit` / TestBase wiring).

**LP token gold:** Crane `ERC20PermitDFPkg` — same three facets whenever the **proxy is the LP share**.

## Contents

- Factory base cuts (not product-owned)
- Shared LP token cuts (hook is its own LP) — ERC20PermitDFPkg
- Shared vault cuts
- Shared storage repos product code must use
- Product-only facets (what you may write)
- What not to reimplement
- Deploy / TestBase wiring

---

## Factory base cuts (always on hook diamonds)

Cut by **`UniswapV4HookDiamondPackageCallBackFactory`** via `InitArgs` — **not** by the product DFPkg:

| Facet | Role | Source |
|-------|------|--------|
| ERC-165 | `supportsInterface` | Facet registry canonical |
| Diamond Loupe | introspection | Facet registry canonical |
| ERC-8109 Introspection | IndexedEx introspection | Facet registry canonical |
| PostDeployAccountHook | postDeploy hook | Facet registry canonical |
| **HookFlags** | V4 permission flags on proxy | `HookFactoryService.deployUniswapV4HookFlagsFacet` |

Do **not** re-cut these in `diamondConfig` / product `facetCuts`.

---

## Shared LP token cuts — ERC20PermitDFPkg parity (mandatory when hook is LP)

When the **hook diamond is the LP ERC-20** (Single SE Buffer CP and peers), cut the **same three facets**
as Crane [`ERC20PermitDFPkg`](../../../../lib/crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol):

| Facet | Path | Surfaces (do not reimplement) | Deploy helper |
|-------|------|-------------------------------|---------------|
| **`ERC20Facet`** | `@crane/contracts/tokens/ERC20/ERC20Facet.sol` | IERC20 + metadata (`transfer`, `approve`, `balanceOf`, `totalSupply`, …) | `create3Factory.deployERC20Facet()` |
| **`ERC5267Facet`** | `@crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` | `eip712Domain()` | `create3Factory.deployERC5267Facet()` |
| **`ERC2612Facet`** | `@crane/contracts/tokens/ERC2612/ERC2612Facet.sol` | `permit`, `nonces`, `DOMAIN_SEPARATOR` | `create3Factory.deployERC2612Facet()` |

**Interfaces to declare** (with vault/product ones): `IERC20`, `IERC20Metadata`, `IERC20Permit`, `IERC5267`.

**`initAccount` (proxy storage) must:**

```solidity
ERC20Repo._initialize(name_, symbol_, 18);
EIP712Repo._initialize(name_, "1");  // required for ERC2612 / domain
```

Peers: `ERC4626StandardExchangeDFPkg`, DETF packages, `RebasingClaimTokenDFPkg` all cut ERC20+5267+2612 the same way.

**Not a substitute:** Uniswap **Permit2** on deposit of *underlyings* is a separate path (product PullLib).  
LP **EIP-2612** is the share-token permit surface above.

Do **not** invent `HookERC20Facet` / product-local permit facets.

---

## Shared vault cuts (mandatory when multi-asset vault surfaces apply)

| Facet | Path | Surfaces | Deploy helper |
|-------|------|----------|---------------|
| **`MultiAssetBasicVaultFacet`** | `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` | `vaultTokens`, `reserveOfToken`, `reserves` | `deployMultiAssetBasicVaultFacet()` |
| **`MultiAssetStandardVaultFacet`** | `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol` | `vaultConfig`, `vaultTypes`, `contentsId`, `vaultFeeTypeIds` | `deployMultiAssetStandardVaultFacet()` |

**Canonical factory service:** `contracts/vaults/VaultComponentFactoryService.sol`  
**Test bootstrap:** `contracts/vaults/TestBase_VaultComponents.sol` exposes  
`erc20Facet`, `erc5267Facet`, `erc2612Facet`, `multiAssetBasicVaultFacet`, `multiAssetStandardVaultFacet`.

### Typical `facetCuts` order (gold)

```text
1. ERC20_FACET
2. ERC5267_FACET
3. ERC2612_FACET
4. MULTI_ASSET_BASIC_VAULT_FACET
5. MULTI_ASSET_STANDARD_VAULT_FACET
6. … product-only facets (SE/hooks, deposit, withdraw, …)
```

---

## Shared storage repos (write from product logic)

| Repo | Use from product Targets |
|------|---------------------------|
| `ERC20Repo` | LP mint/burn/balance/totalSupply during deposit/withdraw/protocol fee |
| `EIP712Repo` | Init only (with ERC20 init); permit facets read domain/nonces |
| `MultiAssetBasicVaultRepo` | `_updateReserve` / token list |
| `StandardVaultRepo` | Vault type / fee / config bindings |

**Rule:** product Targets may **call** these repos; they must **not** expose duplicate public
`transfer` / `permit` / `vaultTokens` / `vaultConfig` that collide with shared facet selectors.

---

## Product-only facets (write these)

| Concern | Examples |
|---------|----------|
| Uniswap V4 hooks | `beforeInitialize`, `beforeSwap`, `beforeAddLiquidity`, delta returns |
| Product book | CP reserves, virtual pair / SE claim, buffer-last |
| Liquidity UX | `deposit` / `depositSingle` / `withdraw` / `withdrawSingle` + previews |
| SE surface | `exchangeIn` / `exchangeOut` **product math** (not generic ERC-4626 SE facet logic for buffer-CP books) |
| Fees / kLast | Protocol growth mint via `ERC20Repo` + fee oracle reads |
| Permit2 pulls | Product PullLib for **underlyings** — do not reimplement LP ERC-20/permit |

Split product facets for **EIP-170 size** (gold: Se / Deposit / Withdraw) — full type names.

---

## What not to reimplement

| Wrong | Right |
|-------|--------|
| Product facet with `balanceOf` / `transfer` / `approve` for LP | Cut `ERC20Facet`; mint/burn via `ERC20Repo` |
| Product facet with `permit` / `nonces` / `DOMAIN_SEPARATOR` / `eip712Domain` | Cut `ERC2612Facet` + `ERC5267Facet`; init `EIP712Repo` |
| Product facet with `vaultTokens` / `reserveOfToken` / `reserves` | Cut `MultiAssetBasicVaultFacet` |
| Product facet with `vaultConfig` / `vaultTypes` / `contentsId` | Cut `MultiAssetStandardVaultFacet` |
| Only `ERC20Facet` when hook is LP (omit permit facets) | **Full ERC20PermitDFPkg set** (20 + 5267 + 2612) |
| New `HookERC20Facet` / `MyBasicVaultFacet` under the product tree | Pass shared facet addresses in `PkgInit` |
| Wire generic ERC-4626 SE In/Out **facet logic** as the book swap for SE-buffer-CP products | Keep **interface**; product facets own book math |
| Re-cut factory loupe/ERC165/HookFlags in product `diamondConfig` | Factory **base** cuts only |

---

## Deploy / TestBase wiring

```solidity
// PkgInit (on interface) — shared LP + vault + product facets:
//   erc20Facet, erc5267Facet, erc2612Facet,
//   multiAssetBasicVaultFacet, multiAssetStandardVaultFacet,
//   seFacet, depositFacet, withdrawFacet, …

hookPkg = PkgFactory.deployPackage(
    registry,
    owner,
    PkgInit({
        // ...
        erc20Facet: erc20Facet,           // TestBase_VaultComponents
        erc5267Facet: erc5267Facet,
        erc2612Facet: erc2612Facet,
        multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
        multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
        seFacet: seFacet,                 // product CREATE3
        depositFacet: depositFacet,
        withdrawFacet: withdrawFacet
    }),
    salt
);
```

Product FactoryService deploys **product** facets only. Shared LP/vault facets come from
`VaultComponentFactoryService` / TestBase handles.

---

## Decision checklist (before writing a public function)

1. Is this selector already on `ERC20Facet` / `ERC5267Facet` / `ERC2612Facet` /
   `MultiAssetBasicVaultFacet` / `MultiAssetStandardVaultFacet` / factory base? → **cut, don’t write**.
2. Does it only mutate shared storage? → call **shared repo** from product Target.
3. Is it V4 hook / product book / deposit-withdraw route? → **product facet**.
4. Unsure? Open gold DFPkg `facetCuts` and match `ERC20PermitDFPkg` + MultiAsset order.
