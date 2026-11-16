# PRD: SE Orbital Buffer Hook — Staged Pair-Door Initialization

**Name:** `UniswapV4StandardExchangeOrbitalBufferHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.1** — copy Orbital gold v0.4.2. No CODE until accepted.  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/orbital/`  
**Package kind:** **Amend** `UniswapV4StandardExchangeOrbitalBufferHookDFPkg`. Not a new product. Not a factory rewrite.

**Authority**

| Layer | Role |
|-------|------|
| **This PRD** | Door timing, bootstrap vs production cuts, finalize, `postDeploy`, this-package callers |
| [Gold Orbital staged PRD](../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2 | Diamond machinery (S2, S9, S12, S21–S26, S35, S47–S57). **Do not reopen.** |
| [Family index](../../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md) | Order vs other families |
| [Product PRD](./UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md) | Sphere / SE buffer / LP / fees. Same-tx three doors superseded here |
| Hook factory PRD | Unchanged. F33: no public `diamondCut` |

If this file conflicts with the product PRD on **when doors exist** or **when the production ABI appears**, **this file wins**.

---

## 0. Goal

Same three caller stages as gold Orbital: deploy a registered bootstrap diamond, `deployPair` each product unordered pair `(t0,t1)`, `(t1,t2)`, `(t0,t2)`, then `finalizeInitialization`. SE deposit / withdraw / SE-share selectors stay off the proxy until finalize.

## 1. Why

Today `facetCuts()` is 9 Adds (ERC20 trio + vault pair + hooks + deposit + withdraw + SE). `postDeploy` calls `PairPoolLib.ensureThreePairPools`. Closest copy of gold; extra production facets are the only shape delta.

## 2. Family facts (as-built)

| Fact | Value |
|------|--------|
| Product doors | Binding pairs `(token0,token1)`, `(token1,token2)`, `(token0,token2)`. Address-sorted currencies. `fee = DYNAMIC_FEE_FLAG`. `hooks = proxy`. Tick/sqrt from Repo (0 → 60 / tick-0 mid), same as gold |
| Door ABI | Shared `IUniswapV4HookStagedPairInit`: **`deployPair(address,address)`** only. Sort internally. No named `deployPairPool*`. No pairId |
| Bootstrap cuts | Vault pair + `address(SELF)` init-only |
| `productionFacetCuts()` exact Add order | `[0]` HOOKS_FACET; `[1]` DEPOSIT_FACET; `[2]` WITHDRAW_FACET; `[3]` SE_FACET; `[4]` ERC20_FACET; `[5]` ERC5267_FACET; `[6]` ERC2612_FACET |
| `facetInterfaces()` (keep) | IERC20, IERC20Metadata, IERC20Permit, IERC5267, IStandardExchangeIn, IStandardExchangeOut, IBasicVault, IStandardVault, HOOK_VAULT_TYPE (9 IDs, today’s order) |
| `facetAddresses()` after amend | vault pair, `address(SELF)`, then the seven production immutables in the Add order above |
| `beforeInitialize` today | Hooks target. Extract to `UniswapV4StandardExchangeOrbitalBufferHookBeforeInitializeLib`. Checks stay bit-identical |
| Bulk ensure to delete | `PairPoolLib.ensureThreePairPools` |
| Repo | Append `bool initializationFinalized` at **end** of `Layout` only |

## 3. Locked (family)

| # | Law |
|---|-----|
| SE1 | Scope is **this directory only**. Grep `UniswapV4StandardExchangeOrbitalBufferHookDFPkg` and this package’s `deployVault` / `deployVaultAutoMine` / `PkgFactory.deployHook`. Known hits: gold TestBase, `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/**`. **Do not** touch raw Orbital (`hooks/uniswap/v4/orbital/`), frontend, or Anvil scripts unless that grep hits them. |
| SE2 | Gold S2 / S3 / S9 / S11 / S12 / S19 / S21–S26 / S35 / S47–S57 apply with names prefixed `UniswapV4StandardExchangeOrbitalBufferHook*`. |
| SE3 | Do not reopen SE buffer claim/pull, min-SE, B6, sphere math, salt, flags, `PRODUCT_ID`, `PkgInit` field order. |
| SE4 | Init-only selectors: gold S58 (exactly 6). Never cut deposit / withdraw / SE / `token0` / ERC20 onto the package-as-init cut. |
| SE5 | TestBase `setUp` calls `_ensureProductDoorsAndFinalize(hook)` after `deployHook` (`deployPair` × 3 product pairs + finalize). Add `_deployBootstrapOnly` for S43-style tests. |

## 4. Lifecycle

Gold §4.2 with this package’s `productionFacetCuts()` (7 Adds). `pkg.postDeploy` returns true and inits zero pools.

## 5. Files

```text
standardExchange/orbital/
  interfaces/IUniswapV4StandardExchangeOrbitalBufferHookInit.sol   # NEW
  UniswapV4StandardExchangeOrbitalBufferHookBeforeInitializeLib.sol
  UniswapV4StandardExchangeOrbitalBufferHookInitTarget.sol
  facets/UniswapV4StandardExchangeOrbitalBufferHookInitFacet.sol
  UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol              # is InitFacet
  UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib.sol        # delete ensureThreePairPools
  UniswapV4StandardExchangeOrbitalBufferHookRepo.sol               # + flag at end
  UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol        # beforeInitialize → lib
  TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol          # S42 helper
  interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol       # UNCHANGED (no door views)
  interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol # + productionFacetCuts()
```

## 6. Tests (default hermetic profile)

Same names/intent as gold plan §7, under `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/`:

- Package decl: bootstrap `facetCuts` length 3; `productionFacetCuts` length 7 matching the immutables above; `facetFuncs` = SE4 list; `postDeploy` direct `true` with no PoolManager.
- S43: `deployVault` alone: no doors, `vaultConfig` works, `isVault`, init selectors on package, `addLiquidity` / deposit / `token0` / `transfer` / `beforeSwap` unmatched, ERC165 still claims IERC20.
- Doors + finalize: emit once, skip-if-live silent, order-independent, `ProductDoorsNotLive` on 0 and 2 doors, extra tick-spacing does not count, stranger may door+finalize, no `diamondCut` before or after.
- After finalize: init-only unmatched; `beforeInitialize` on HOOKS_FACET; deposit on DEPOSIT_FACET; vault pair remains.
- Existing product specs stay green via S42 `setUp`. J-surface: unmatched swap/LP/SE before finalize.

## 7. Docs this change set must patch

Product PRD / impl plan sentences that claim `postDeploy` or `deployVault` inits all three doors or ships the full ABI at CREATE2. Point them here.

## 8. DoD

Gold §11 with this family’s 7 production Adds and SE4 selector set. No `via_ir`. No `new` facets/DFPkg. No CREATE3 InitFacet. No edits under `hooks/uniswap/v4/orbital/`.
