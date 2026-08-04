# Implementation & Test Plan: Uniswap V4 Single Standard Exchange Buffer Hook

**PRD (product law SoT):** [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_PRD.md`](./UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_PRD.md) (**v1.1** — plan locks O1–O7 applied)  
**This plan (implementor SoT once accepted):** migrate monomorph `*BufferPricing*` scaffold → **hook diamond package** `UniswapV4SingleStandardExchangeBufferHook` under `standardExchange/single/`.  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/single/`  
**Date:** 2026-08-04  
**Status:** **Canonical plan — aligned to PRD v1.1.** Ready for implementor stamp, then code.

**Authority**

| Layer | Role |
|-------|------|
| PRD v1.1 | Product + deploy law (B1–B42, O1–O7, §0–§16) |
| **This plan** | Phases, file map, vault facet wiring, SE/test ladder, adversarial catalog, forks |
| Factory PRD | `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Skill | `indexedex-uniswap-v4-hook-packages`, `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing`, `crane-adversarial-testing` |
| Gold deploy shape | `…/standardExchange/constantProduct/single/` DFPkg (**deploy only** — different product) |
| Behavioral peer | Crane `BaseTokenWrapperHook` settle order — **pattern-copy only, no inheritance** |
| Legacy monomorph | Existing `*BufferPricing*` tree — **port logic, drop brand, delete CREATE3 instance path** |
| Superseded | `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_*.md` (non-authoritative after DoD) |

**Read order for implementors**

1. PRD §0–§2 (identity: buffer hop, not pricing/AMM/rate provider) + §4 locked decisions  
2. PRD §5–§8 (swap sketch, SE dependency, package surface) + §9.1–§9.3 (test locks)  
3. **This plan** §0–§6 (gap, files, phases, tests, adversarial)  
4. BCP TestBase / DFPkg only as **registry + hook-factory** pattern reference  

**Process rule:** If this plan and PRD disagree, **PRD wins** and this plan must be patched.

---

## 0. Locked implementor card (PRD copy)

| Topic | Lock |
|-------|------|
| Product | **`UniswapV4SingleStandardExchangeBufferHook`** — buffer-only wrap/unwrap hop |
| Not | Pricing, rate provider, CP AMM, Dual SE CP, Single SE BCP, LP, hook fees |
| Instance | Immutable **hook diamond** via package → `deployHookVault` → shared Hook Diamond Factory (CREATE2 flags) |
| `PRODUCT_ID` | `keccak256("uv4-single-se-buffer-hook")` |
| Salt | `PRODUCT_ID`, `poolManager`, `standardExchange`, `pairToken` — **no** package/facet addresses |
| Flags | `BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA` |
| Pool | fee **0**; currencies sort(`pairToken`, `address(SE)`); integrator `initialize` |
| CL | `beforeAddLiquidity` reverts |
| Amounts | SE `previewExchange*` / `exchange*` only; preview == execution |
| Role names | `standardExchange`, `pairToken` (not `underlying` in public API) |
| Inheritance | **No** `BaseTokenWrapperHook` / `BaseHook` / `DeltaResolver` |
| Vault surface | Cut **existing** `MultiAssetBasicVaultFacet` + `MultiAssetStandardVaultFacet`; tokens `[pairToken, SE]`; **reserves 0** |
| Hermetic SE | ERC-4626 **Wrapper SE** + Crane **`ERC4626PermitDFPkg`** on mintable test ERC-20 (**not** Morpho) |
| Forks | Hermetic **+ Base + Robinhood** in DoD |
| Adversarial | Full catalog (A/B/C/E/F/H) adapted to buffer |
| Dust | No hook `feeTo` product; under-delivery → revert |
| Rename | Full `*BufferPricing*` → `*Buffer*` in Phase A; no dual name |
| Profile | `FOUNDRY_PROFILE=hook_factory` for this tree |
| `vaultTokens` order | **Address-sorted** `[lower, higher]` of pairToken vs SE (O8) |
| Redeploy | Factory peer: existing if `isExpectedInstance`, else collision revert (O9) |
| Non-1:1 hermetic | Fee oracle usage fee on Wrapper SE (O10); yield optional P1 |
| Donation residual | Idle OK; never in swap accounting; flat asserts are success-path / delta-aware (O11) |
| `vaultFeeTypeIds` | `bytes32(HOOK_VAULT_TYPE)` left-aligned (O12) |
| `contentsId` | `keccak256(abi.encode(PRODUCT_ID, standardExchange, pairToken))` (O12) |
| Public helpers | `currency0/1`, `poolFee`, `tickSpacingHint`, `sqrtPriceX96Hint` required (O13) |
| Errors | Crane names + fixed package set §4.7 / PRD §8.1 (O14) — **no invent** |
| Naming | Full production type names; test basenames may use `UniswapV4SingleSEBufferHook_*` (O15) |
| Package deploy | `deployVault` **and** `deployVaultAutoMine` required (O16) |
| Hermetic 4626 | **Only** Crane `ERC4626PermitDFPkg` as protocolVault (O17) |
| Forks | Live PM pin + deploy fresh pair/4626/SE/buffer (O18); addresses in §7.4 |

**Implementor rule:** If unspecified in PRD + this plan, **stop and ask** — do not invent product law, error names, surfaces, or deploy paths.

---

## 1. Scope (v1 DoD)

### 1.1 In scope

1. Hook diamond package under `standardExchange/single/` with product name **Buffer** (B1).  
2. Bind one `poolManager` + one `standardExchange` + one `pairToken` (B35).  
3. Custom-accounting swaps: wrap/unwrap exact-in + exact-out (four modes) via SE only (B9–B13).  
4. Public surface **exactly** PRD §8: bindings, previews, `currency0/1`, `poolFee`, `tickSpacingHint`, `sqrtPriceX96Hint` (O2, O13).  
5. Zero CL; fee 0; no donate; no hook fees; end flat on success (B6–B8, B14, B16).  
6. Deploy: facets CREATE3; package via registry; `deployVault` **and** `deployVaultAutoMine` → `deployHookVault` (B23–B26, O16).  
7. Vault registration: multi-asset Basic + Standard facets; discovery via registry (B33, O1); feeTypeIds/contentsId per O12.  
8. Hermetic suite: Wrapper SE + **mandatory** Crane `ERC4626PermitDFPkg` + hermetic PM + hook factory (O5, O17).  
9. Fork smokes: Base + Robinhood with live PM pins (O6, O18).  
10. Adversarial P0/P1 suite (O7).  
11. Retire monomorph CREATE3 `deployHook` production path + pricing authority docs (B34).  
12. Full production type names only (O15); error names exactly §4.7 (O14).

### 1.2 Out of scope (v1)

- Multi-token buffer in one pool; auto-deploy N buffers for all `vaultTokens()`.  
- Native ETH currency; Permit2 on hook; package-owned pool `initialize`.  
- Hook-side usage/growth fee / `kLast` / LP ERC-20.  
- `IRateProvider`, rate storage, rate facet.  
- `IStandardExchangeIn`/`Out` **on the buffer** (users wrap via V4 swap only).  
- Subclassing Crane wrapper bases.  
- Shared TestBases with DETF or Single SE BCP beyond hook-factory ladder.  
- Morpho hermetic matrix; inventing SE first-deposit product law.  
- Keeping “Pricing” as a second product name after DoD.

### 1.3 Peer patterns (copy, do not inherit)

| Peer | Copy what |
|------|-----------|
| `…/constantProduct/single/` DFPkg + TestBase | `deployVault` → `deployHookVault`, premine, `PRODUCT_ID` salt, package-adjacent TestBase ladder |
| Existing monomorph `*BufferPricing*Target` | Four-mode wrap/unwrap + take/settle + `BeforeSwapDelta` signs |
| Crane `BaseTokenWrapperHook` | Permissions, pair/fee init checks, delta convention only |
| ERC-4626 SE DFPkg | Multi-asset Basic/Standard facet cuts + `initAccount` token list pattern |
| Factory stub package | Thin `isExpectedInstance`, flags facet postDeploy immutability |

---

## 2. Current-state gap audit (as of plan write)

Re-verify if tree moves before implementation.

| Area | Status | Work |
|------|--------|------|
| PRD v1.1 | Present | Authority |
| Pricing PRD / monomorph plan | Present | Mark superseded after DoD; do not implement further under those names |
| Monomorph hook (`*BufferPricing*`) | **Present** — CREATE3 + `underlying` naming | Port to diamond Repo init; rename `pairToken`; drop CREATE3 instance deploy |
| Monomorph tests | Deploy + Routes (Morpho hermetic) | Rewrite to hook-factory TestBase + Crane 4626 SE leg; drop Morpho hermetic DoD |
| Diamond package / DFPkg | **Missing** for this product | Greenfield package + product facet (BCP shape) |
| Multi-asset vault facets on buffer | **Missing** | Cut shared facets; init tokens; reserves 0 |
| FactoryService | CREATE3 monomorph mine | Replace with **facet + deployPkg** only (peer SEBCP FactoryService) |
| SE pair↔SE four modes (ERC-4626 wrapper) | **Largely present** | Phase 0 **verify** only — fix only if red |
| Hermetic Crane 4626 as protocol vault | BCP uses `SimpleYieldERC4626` stub | **Must** use Crane **`ERC4626PermitDFPkg`** only (O17); no stub protocol vault DoD |
| Adversarial suite | **None** | Full catalog Phase H |
| Base / RH forks for buffer | **None** | Phase I |

---

## 3. Target file map

### 3.1 Production (package-adjacent)

```text
contracts/hooks/uniswap/v4/standardExchange/single/
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_PRD.md
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # this file

  interfaces/
    IUniswapV4SingleStandardExchangeBufferHook.sol
    IUniswapV4SingleStandardExchangeBufferHookPackage.sol

  facets/
    UniswapV4SingleStandardExchangeBufferHookFacet.sol

  UniswapV4SingleStandardExchangeBufferHookRepo.sol
  UniswapV4SingleStandardExchangeBufferHookTarget.sol
  UniswapV4SingleStandardExchangeBufferHookCommon.sol   # required: SE preview/execute + take/settle
  UniswapV4SingleStandardExchangeBufferHookDFPkg.sol
  UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol

  TestBase_UniswapV4SingleStandardExchangeBufferHook.sol
```

**Naming (O15 — locked):** All production Solidity types/files use **full** `UniswapV4SingleStandardExchangeBufferHook*` (and `…BufferHookPackage` / `…BufferHookFacet` / `…BufferHookDFPkg` / `…BufferHook_FactoryService` / `…BufferHookRepo` / `…BufferHookTarget` / `…BufferHookCommon`).  
Test **file basenames** may use `UniswapV4SingleSEBufferHook_*.t.sol` for path length; contracts inside tests may alias the full interface.

### 3.2 Shared facets (not redefined)

| Facet | Source | Role on buffer diamond |
|-------|--------|------------------------|
| `MultiAssetBasicVaultFacet` | `contracts/vaults/basic/` | `vaultTokens` / `reserveOfToken` / `reserves` |
| `MultiAssetStandardVaultFacet` | `contracts/vaults/standard/` | `vaultFeeTypeIds` / `contentsId` / `vaultTypes` / `vaultConfig` |
| Hook flags facet | hook factory package | Installed by factory postDeploy |

### 3.3 Retire after green

```text
# Production monomorph entry + CREATE3 instance deploy path
UniswapV4SingleStandardExchangeBufferPricingHook.sol          # delete or empty redirect forbidden
UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService.sol  # replace
*BufferPricing* Repo/Target/Common/interfaces                 # renamed in place or deleted after move

# Docs
UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md  # banner: SUPERSEDED by Buffer PRD
…PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md                 # SUPERSEDED banner
…PRICING_HOOK_MOVE_AND_RENAME_PLAN.md                         # absorb into this plan; banner

# Tests
test/.../single/UniswapV4SingleStandardExchangeBufferPricingHook_*.t.sol  # replace with Buffer names
```

### 3.4 Tests

```text
contracts/hooks/uniswap/v4/standardExchange/single/
  TestBase_UniswapV4SingleStandardExchangeBufferHook.sol

test/foundry/spec/hooks/uniswap/v4/standardExchange/single/
  UniswapV4SingleSEBufferHook_Deploy.t.sol
  UniswapV4SingleSEBufferHook_Init.t.sol
  UniswapV4SingleSEBufferHook_Routes.t.sol          # four modes + preview==exec
  UniswapV4SingleSEBufferHook_LiquidityBan.t.sol
  UniswapV4SingleSEBufferHook_Fees.t.sol            # SE fee ≠ 1:1; no hook fee
  UniswapV4SingleSEBufferHook_VaultViews.t.sol      # multi-asset Basic/Standard
  UniswapV4SingleSEBufferHook_Flat.t.sol            # residual zero after success
  UniswapV4SingleSEBufferHook_RouteSmoke.t.sol      # sequential wrap then unwrap

  adversarial/
    TestBase_UniswapV4SingleSEBufferHook_Adversarial.sol
    Adversarial_Donation.t.sol
    Adversarial_Reentrancy.t.sol
    Adversarial_Access.t.sol
    Adversarial_Accounting.t.sol
    Adversarial_Griefing.t.sol
    Adversarial_Economic.t.sol                      # SE fee / non-1:1; no free lunch via donation

test/foundry/fork/base_main/hooks/uniswap/v4/standardExchange/single/
  UniswapV4SingleSEBufferHook_Base.t.sol

test/foundry/fork/robinhood_4663/hooks/uniswap/v4/standardExchange/single/
  UniswapV4SingleSEBufferHook_Robinhood.t.sol
```

---

## 4. Architecture detail

### 4.1 `PkgInit` / `PkgArgs` (interface-owned)

```solidity
// IUniswapV4SingleStandardExchangeBufferHookPackage
struct PkgInit {
    IVaultRegistryDeployment vaultRegistryDeployment;
    IFacet productFacet;
    IFacet multiAssetBasicVaultFacet;
    IFacet multiAssetStandardVaultFacet;
}

struct PkgArgs {
    address poolManager;
    address standardExchange;
    address pairToken;
}
```

**Validate:** non-zero addresses; `pairToken != standardExchange`; `pairToken ∈ IBasicVault(standardExchange).vaultTokens()` (or SE equivalent).

### 4.2 `calcSalt` / flags / expected instance

```text
PRODUCT_ID = keccak256("uv4-single-se-buffer-hook")
calcSalt(processed) = keccak256(abi.encode(PRODUCT_ID, poolManager, standardExchange, pairToken))
// factory: finalSalt = keccak256(abi.encode(packageSalt, mineNonce))  — no address(pkg)

requiredHookFlags() pure =
  BEFORE_INITIALIZE | BEFORE_ADD_LIQUIDITY | BEFORE_SWAP | BEFORE_SWAP_RETURNS_DELTA

isExpectedInstance(proxy): code.length > 0 && (uint160(proxy) & FLAG_MASK) == (flags & FLAG_MASK)
// thin — no loupe/facet-set equality
```

### 4.3 `diamondConfig` / `facetCuts`

```text
cuts:
  1. multiAssetBasicVaultFacet   (IBasicVault)
  2. multiAssetStandardVaultFacet (IStandardVault)
  3. productFacet                (IHooks + product previews + getters)

// NO diamondCut facet on live diamond after postDeploy (factory immutability)
// facetInterfaces: IHooks, product interfaceId, IBasicVault, IStandardVault, HOOK_VAULT_TYPE
```

```text
HOOK_VAULT_TYPE = bytes4(keccak256("UniswapV4SingleStandardExchangeBufferHook"))  // locked string
PRODUCT_ID      = keccak256("uv4-single-se-buffer-hook")
```

### 4.4 `initAccount`

```text
1. decode PkgArgs; re-validate
2. Repo._initialize(poolManager, standardExchange, pairToken)
   - store wrapZeroForOne = (pairToken < standardExchange)  // Repo-only; no public getter
   - currency0 = lower(pairToken, SE); currency1 = higher  // public via getters O13
3. MultiAssetBasicVaultRepo._initialize(address-sorted [currency0, currency1])  // O8
   - reserves default 0; never _updateReserve on wrap/unwrap
4. StandardVaultRepo (O12 — exact):
   vaultFeeTypeIds = bytes32(HOOK_VAULT_TYPE)   // bytes4 left-aligned in bytes32
   contentsId = keccak256(abi.encode(PRODUCT_ID, standardExchange, pairToken))
   vaultTypes = package facetInterfaces type id list (IHooks product id, IBasicVault, IStandardVault, HOOK_VAULT_TYPE as peer)
5. No LP metadata; no feeOracle binding on this product
```

### 4.4.1 Redeploy / idempotency (O9)

Match shared hook factory + BCP/stub package policy:

- Same `calcSalt` + same premined `mineNonce` → CREATE2 address fixed.
- If code already present and `isExpectedInstance` → **return existing** (idempotent path as factory exposes).
- If code present but **not** expected → **revert** (collision / wrong occupant).
- Different `pairToken` or SE → different salt → different instance (B37).
- **No** saltNamespace / multi-instance product identity (B38).

### 4.5 Product facet surface (O13 — complete; no subset)

| Selector group | Functions |
|----------------|-----------|
| IHooks | Full set; unused callbacks revert `HookNotImplemented` |
| Bindings | `poolManager`, `standardExchange`, `pairToken`, `wrapper` (== SE) |
| Currency / pool helpers | `currency0()`, `currency1()`, `poolFee()` → `0`, `tickSpacingHint()` → `60`, `sqrtPriceX96Hint()` → `79228162514264337593543950336` (1:1) |
| Previews | `previewWrap`, `previewWrapExactOut`, `previewUnwrap`, `previewUnwrapExactOut` |
| Permissions | `getHookPermissions` (pure) — required on product facet |

**Constants (locked):**

```text
uint24  POOL_FEE           = 0;
int24   TICK_SPACING_HINT  = 60;
uint160 SQRT_PRICE_1_1     = 79228162514264337593543950336;
```

**Forbidden on product facet:** `rate`/`getRate`, LP deposit/withdraw, SE In/Out execute for third parties, public `wrapZeroForOne()`.

### 4.5.1 Package interface deploy surface (O16)

```solidity
function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);
function deployVaultAutoMine(PkgArgs memory args) external returns (address vault);
```

Both required. Auto-mine documents gas risk in NatSpec; TestBase may call either; production scripts **must** premine.

### 4.6 Swap execution (port from monomorph Target)

Pattern-copy monomorph / `BaseTokenWrapperHook` delta signs:

| Mode | Flow |
|------|------|
| Wrap exact-in | `amountIn = -amountSpecified` → preview → take pair → approve SE → `exchangeIn` minOut=preview → settle SE → delta |
| Wrap exact-out | preview amountIn → take **exactly** amountIn → `exchangeOut` → settle SE |
| Unwrap exact-in | take SE → `exchangeIn` SE→pair → settle pair |
| Unwrap exact-out | preview SE in → take SE → `exchangeOut` → settle **actual** pair received (≥ out) |

Rules:

- `_onlyPoolManager()` on all live hooks.  
- Zero amounts → revert (`ZeroAmount`).  
- SE `deadline = block.timestamp`.  
- SE `minOut`/`maxIn` = tight preview; router owns user slippage.  
- Recipient for SE = hook; then settle to PoolManager.  
- SE calls: **`pretransferred = false`** + `forceApprove` + SE balance-delta pull (Rocket peer). Do not use free-mint pretransfer paths.  
- Under-delivery → SE/`Slippage` bubble — **no** dust absorb to feeTo on hook.  
- Success residual: **hard zero** pair+SE free balances from the swap path (delta-aware for O11 donations). Do not invent `MAX_DUST_WEI` on the hook.

### 4.7 Error surface (O14 — closed set)

**Crane `BaseTokenWrapperHook` / `BaseHook` names (define identically; do not rename):**

| Error | When |
|-------|------|
| `LiquidityNotAllowed` | `beforeAddLiquidity` |
| `InvalidPoolToken` | `beforeInitialize` pair mismatch |
| `InvalidPoolFee` | `beforeInitialize` fee ≠ 0 |
| `HookNotImplemented` | unused IHooks callbacks |
| `ExactInputNotSupported` | **Declare only — never throw in v1** |
| `ExactOutputNotSupported` | **Declare only — never throw in v1** |

**Package / product (fixed; no substitutes):**

| Error | When |
|-------|------|
| `ZeroAddress` | Zero address in PkgArgs / PkgInit / facet args |
| `SameToken` | `pairToken == standardExchange` |
| `InvalidPairToken` | `pairToken` not in SE `vaultTokens()` |
| `ZeroAmount` | Zero amount on preview or swap path |
| `NotPoolManager` | Hook entry not from PoolManager |

**SE:** bubble as-is (`UnsupportedRoute` / `InvalidRoute`, `Slippage`, `DeadlineExpired`, pause, etc.).  
**Deploy:** hook factory peer collision / mine exhaustion errors only — do not invent a parallel FactoryService error taxonomy beyond what the shared factory already emits.

---

## 5. Implementation phases

Ordered for incremental green slices. Do not claim DoD until Phase I + adversarial P0.

### Phase 0 — SE route gate (thin)

**Goal:** Confirm hermetic Wrapper SE supports closed-form `pairToken ↔ SE` four modes with preview == execution.

1. Deploy path **exactly (O17):** mintable ERC-20 → Crane **`ERC4626PermitDFPkg`** via create3Factory / diamondPackageFactory peer path → `ERC4626StandardExchangeDFPkg.deployVault(protocolVault)`.  
2. **Forbidden DoD protocol vaults:** `SimpleYieldERC4626`, Morpho MetaMorpho, ad-hoc `new` 4626.  
3. Assert wrap/unwrap exact-in + exact-out on SE alone (helpers on package TestBase).  
4. Set non-zero SE usage fee via fee oracle (O10); prove preview includes fee.  
5. **Do not** rework SE first-deposit / donation protection law.  
6. **If red:** fix ERC-4626 SE only enough for buffer paths; do not invent Morpho hermetic dependency.

**Exit:** TestBase helper `_assertSePreviewEqualsExec` green for all four modes.

---

### Phase A — Rename + package skeleton (compile)

1. Introduce Buffer-named interfaces / Repo / Target / Common / Facet / DFPkg / FactoryService.  
2. Port monomorph storage from immutables → Repo (`initAccount`). Public `underlying()` → **`pairToken()`**.  
3. FactoryService: `deployProductFacet`, `deployPackage` (registry), `findMineNonce`, `deployHook(pkg, args, nonce)` — **no** CREATE3 monomorph instance mine.  
4. DFPkg: `deployVault` → `deployHookVault`; salt; flags; multi-asset + product cuts; `initAccount`.  
5. PkgInit wires multi-asset facets from `TestBase_VaultComponents` (or create3 deploy once).  
6. `forge build` green under hook_factory profile if required.  
7. Banner superseded on old pricing docs (can wait until Phase G delete if preferred).

**Exit:** Package deploys inert diamond via registry+hook factory; views return bindings; vaultTokens length 2.

---

### Phase B — IHooks + init / liquidity ban

1. Port `beforeInitialize` / `beforeAddLiquidity` / disabled callbacks from monomorph Target.  
2. Test: wrong pair reverts; fee≠0 reverts; `modifyLiquidity` reverts; correct init succeeds.  
3. Hermetic pool: fee=0, `tickSpacing=60`, `sqrtPriceX96` 1:1 plumbing only (B22).

**Exit:** Init + liquidity ban specs green.

---

### Phase C — Four-mode wrap/unwrap + previews

1. Port Common SE preview/execute + take/settle (`Currency`/`PoolManager` pattern-copy).  
2. Port `beforeSwap` four branches + `BeforeSwapDelta` signs.  
3. Public preview functions = pure SE passthrough with zero guards.  
4. Tests: each mode preview == execution; sequential wrap→unwrap smoke; hook flat after success.  
5. SE fee-on case via **fee oracle non-zero usage fee** on Wrapper SE (O10): amounts non-1:1; still no hook fee.  
6. `_assertHookFlat` = success-path residual from **this** swap (delta or post-clean balance); do not fail solely because of pre-seeded donations (O11).

**Exit:** Routes + Flat + Fees hermetic green.

---

### Phase D — Vault views + registration

1. Assert `vaultTokens()` is **address-sorted** `[lower, higher]` of pairToken vs SE (O8).  
2. `reserveOfToken` / `reserves` all **0** before and after successful swaps (donations do not update reserves).  
3. `vaultConfig().tokens` matches; `vaultTypes` includes expected interface ids.  
4. Registry: instance listed as vault-class for package; `isExpectedInstance` true.

**Exit:** VaultViews + Deploy registration specs green.

---

### Phase E — Salt / immutability / second binding

1. Same `(pm, SE, pairToken)` → same salt; second deploy with same mineNonce: **return existing if expected, else revert** (O9 / factory peer).  
2. Different `pairToken` → different address (B37).  
3. Live diamond: no `diamondCut` (factory removed it).  
4. Premine-first path required in primary TestBase `setUp`; **at least one** Deploy test must exercise `deployVaultAutoMine` (O16).

**Exit:** Deploy salt/immutability specs green.

---

### Phase F — Hermetic suite polish + naming cleanup

1. Rename remaining tests/files off `*Pricing*`.  
2. Delete monomorph CREATE3 production path when diamond path is sole DoD path.  
3. Grep for `BufferPricing`, `underlying()` public API, `IRateProvider` on package — zero hits in production path.  
4. Document integrator notes already in PRD §12 in NatSpec on package interface.

**Exit:** Grep clean; only Buffer product names.

---

### Phase G — Adversarial (full catalog)

See **§6**. Implement P0 then P1; defer P2 with NatSpec.

**Exit:** `forge test --match-path '.../single/adversarial/**'` green for P0/P1.

---

### Phase H — Forks (Base + Robinhood) — O18

1. Fork TestBases: pin **live** PoolManager; deploy **fresh** pairToken + Crane `ERC4626PermitDFPkg` + Wrapper SE + buffer package.  
2. **Pins (locked):**

| Chain | Constant | Address |
|-------|----------|---------|
| Base | `BASE_MAIN.UNISWAP_V4_POOL_MANAGER` | `0x498581fF718922c3f8e6A244956aF099B2652b2b` |
| Robinhood | `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` | `0x8366a39CC670B4001A1121B8F6A443A643e40951` |

3. Smoke **required:** initialize fee-0 pool with hook + **all four** wrap/unwrap modes (exact-in and exact-out both directions).  
4. File header **must** cite constant path + address above.  
5. **Forbidden:** deployCode PoolManager on fork DoD path; pin live SE/pair as sole path (always fresh pair/4626/SE/buffer).

**Exit:** Both fork files green in CI (or documented env-gated profile with same pins).

---

### Phase I — DoD audit

1. Checklist vs PRD §14 + this plan §1.  
2. Cross-link dual/orbital docs that still say “pricing buffer” (PRD migration phase 5).  
3. Mark pricing PRD/plan **SUPERSEDED**.  
4. No new production code under `*Pricing*` names.

**Exit:** Plan status → **IMPLEMENTED**; PRD remains product SoT.

---

## 6. Adversarial catalog (buffer-adapted)

Methodology: `crane-adversarial-testing`. Production entry points only. No mock buffer package/factory/SE.

### 6.1 Threat model (short)

| Actor | Surface | Asset at risk |
|-------|---------|----------------|
| Attacker | V4 swap via router / PM unlock | User pair/SE mid-hop; stuck inventory |
| Attacker | Direct token transfer to hook | Donation inflation (should not reprice SE or steal) |
| Attacker | Hostile ERC-20 as `pairToken` or SE share | Reentrancy into swap / SE |
| Attacker | diamondCut / owner | Immutability break |
| Integrator bug | CL mid quote | Economic — document not exploit if previews correct |

### 6.2 Catalog IDs

| ID | Theme | Attack | Pass criteria |
|----|-------|--------|---------------|
| **A1** | Donation | Transfer `pairToken` to hook | Wrap/unwrap amounts still SE-previewed; victim swap does not mint free SE from donation |
| **A2** | Donation | Transfer SE shares to hook | Same; no free unwrap credit from idle SE |
| **A3** | Donation | Donate then force swap paths | Idle stuck OK (O11); **must not** credit into swap accounting; no feeTo absorb; flat asserts ignore donation baseline |
| **B1** | Economic | SE usage fee on/off (fee oracle) | Previews include fee; attacker cannot get better than SE by donating |
| **B2** | Economic | Non-1:1 after SE accrual (optional if 4626 yields) | Unwrap improves only per SE; still not rate-provider product; **not** Morpho hermetic |
| **C1** | Reentrancy | Hostile `pairToken` reenters hook/swap mid-wrap | Nested fails `IsLocked` / SE lock / PM rules; outer either reverts clean or completes with flat residual |
| **C2** | Reentrancy | Hostile SE share reenters on unwrap | Same |
| **C3** | Reentrancy | Reenter SE `exchangeIn` from token callback | SE or hook lock; no double settle |
| **E1** | Accounting | Successful four modes | Hook free pair+SE residual **0** (or ≤ documented SE dust) |
| **E2** | Accounting | Zero amount swap / preview | Revert `ZeroAmount` |
| **E3** | Accounting | Failed minOut / SE Slippage | Full revert; no stranded mid-swap inventory on hook |
| **F1** | Access | Non-PM calls `beforeSwap` / hooks | Revert `NotPoolManager` |
| **F2** | Immutability | Attempt `diamondCut` on live hook | Revert (no cut facet) |
| **F3** | Access | Random EOA cannot re-bind Repo | No setter; init once |
| **H1** | Grief | SE reverts mid-swap | Full tx revert; PM accounting consistent |
| **H2** | Grief | Exact-out with insufficient user input | Slippage/revert; no partial free inventory |
| **H3** | Grief | Add liquidity | Always `LiquidityNotAllowed` |
| **H4** | Grief | Init wrong fee/pair | Revert; pool not usable with bad key |

**P0 (ship gate):** A1, A2, C1, C2, E1, E2, E3, F1, F2, H1, H3.  
**P1:** A3, B1, B2, C3, F3, H2, H4.  
**P2 (defer OK):** Cross-pool MEV sandwich on multi-hop routes; fork-only MEV reconstructions.

### 6.3 Harness notes

- Extend feature TestBase → `TestBase_*_Adversarial`.  
- Hostile ERC-20: existing `ReentrantMockERC20` / crane pattern — wire as **pairToken** only if SE accepts it as vault token (deploy SE against hostile asset if needed). For SE-share reentrancy, hostile share as ERC-20 is harder (SE is diamond share); prefer reentrancy on `pairToken` + SE pull paths.  
- Allowed: mintable funding tokens; **not** mock SE as SUT.  
- Naming: `test_A1_...`, `test_C1_...`.

---

## 7. TestBase design (package-adjacent)

```text
CraneTest
  → IndexedexTest / VaultComponents (multi-asset facets, fee oracle, manager)
    → TestBase_ERC4626StandardExchange
      → TestBase_UniswapV4SingleStandardExchangeBufferHook
```

### 7.1 `setUp` sequence (hermetic)

```text
1. Super setUp (manager, multi-asset facets, ERC-4626 SE package)
2. pairToken = SimpleMintableERC20 (funding stub only)
3. protocolVault = deploy Crane ERC4626PermitDFPkg with asset=pairToken  // O17 mandatory
4. se = _deployERC4626SE(protocolVault)
5. pm = vm.deployCode PoolManager  // hermetic only
6. deploy hook flags facet + hook diamond factory; setHookDiamondPackageFactory
7. productFacet = FactoryService.deployProductFacet
8. hookPkg = FactoryService.deployPackage(PkgInit{ registry, productFacet,
       multiAssetBasicVaultFacet, multiAssetStandardVaultFacet })
9. Prefer: mineNonce = findMineNonce(...); hook = pkg.deployVault(args, mineNonce)
   Also cover: pkg.deployVaultAutoMine(args) in at least one Deploy test (O16)
10. initialize pool: fee=poolFee(), tickSpacing=tickSpacingHint(), sqrt=sqrtPriceX96Hint()
11. fund user; approve router / SE as needed
```

### 7.2 Helpers (required names)

| Helper | Purpose |
|--------|---------|
| `_defaultPkgArgs()` | pm, se, pairToken |
| `_deployCraneErc4626(pairToken)` | O17 only path for protocolVault |
| `_assertSePreviewEqualsExec` | Phase 0 |
| `_assertHookFlat()` | success-path residual; donation-aware (O11) |
| `_wrapExactIn` / `_unwrapExactIn` / exact-out variants | Via real swap router (`WrapperExactOutRouter`) |
| `_initPool` | uses public `poolFee` / `tickSpacingHint` / `sqrtPriceX96Hint` |

### 7.3 Production-first rules

- Never mock buffer DFPkg, product facet, hook factory, registry, manager, SE under test.  
- Crane `ERC4626PermitDFPkg` + Wrapper SE only for protocol vault + SE (mintable ERC-20 is the only allowed non-SUT funding stub).  
- Exact `assertEq` on preview vs execution (documented SE dust only if SE peer already allows).

### 7.4 Fork pins (O18 — copy into fork TestBase headers)

```text
Base:       lib/crane/.../BASE_MAIN.sol UNISWAP_V4_POOL_MANAGER
            0x498581fF718922c3f8e6A244956aF099B2652b2b
Robinhood:  lib/crane/.../ROBINHOOD_MAIN.sol UNISWAP_V4_POOL_MANAGER
            0x8366a39CC670B4001A1121B8F6A443A643e40951
```

---

## 8. Commands

```bash
# Hermetic package suite
FOUNDRY_PROFILE=hook_factory forge test \
  --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/single/**' -vv

# Adversarial only
FOUNDRY_PROFILE=hook_factory forge test \
  --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/single/adversarial/**' -vv

# Forks (env RPCs as project standard)
forge test --match-path 'test/foundry/fork/base_main/hooks/uniswap/v4/standardExchange/single/**' -vv
forge test --match-path 'test/foundry/fork/robinhood_4663/hooks/uniswap/v4/standardExchange/single/**' -vv

forge build
forge fmt
```

---

## 9. Definition of Done (checklist)

- [ ] Product named **Buffer**; no rate-provider / Pricing public surface  
- [ ] Hook factory package path only; vault registered  
- [ ] Multi-asset Basic + Standard facets cut; **address-sorted** tokens; reserves 0  
- [ ] `vaultFeeTypeIds` / `contentsId` match O12 exactly  
- [ ] Public surface complete: previews + `currency0/1` + `poolFee` + hints (O13)  
- [ ] Errors match §4.7 closed set (O14); `Exact*NotSupported` never thrown  
- [ ] Full production type names (O15); `deployVault` + `deployVaultAutoMine` (O16)  
- [ ] Zero CL; fee 0; four wrap/unwrap modes via SE only; preview == execution  
- [ ] No LP APIs; no hook fees; success-path hook flat (O11 donation-aware)  
- [ ] Hermetic: Crane `ERC4626PermitDFPkg` only as protocol vault (O17)  
- [ ] Adversarial P0/P1 green (P2 NatSpec deferred if any)  
- [ ] Base + Robinhood forks: live PM pins §7.4 + fresh stack (O18)  
- [ ] Monomorph CREATE3 instance path removed; pricing PRD/plan marked SUPERSEDED  
- [ ] Cross-links updated (dual/orbital “pricing buffer” language)  
- [ ] This plan status set to **IMPLEMENTED**

---

## 10. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| SE routes incomplete for exact-out | Phase 0 gate before claiming C |
| Multi-asset facets + product facet selector clash | Single cut ownership; product facet must not re-export Basic/Standard selectors |
| Donation stuck on hook (A3) | Document as non-product idle; no absorb market; optional future sweeper is out of v1 |
| Integrators use CL mid | Previews + NatSpec; test fee-on non-1:1 |
| Confusion with BCP package | Different PRODUCT_ID, path, no LP/rawToken/feeOracle |
| Morpho tests left as hermetic DoD | Explicitly remove; Morpho only optional fork |

---

## 11. Changelog

| Date | Note |
|------|------|
| 2026-08-04 | Initial plan for Buffer PRD v1.1: hook diamond package, multi-asset vault facets, Crane 4626 hermetic SE, full adversarial + Base/RH forks, full rename off Pricing |
| 2026-08-04 | O8–O11: address-sorted vaultTokens; factory redeploy policy; fee-oracle non-1:1; idle donation residual never credited |
| 2026-08-04 | O12–O18: feeTypeIds/contentsId formulas; currency+pool helpers; Crane error names; full type names; auto-mine required; mandatory Crane 4626; live PM fork pins |

---

**End of implementation plan**
