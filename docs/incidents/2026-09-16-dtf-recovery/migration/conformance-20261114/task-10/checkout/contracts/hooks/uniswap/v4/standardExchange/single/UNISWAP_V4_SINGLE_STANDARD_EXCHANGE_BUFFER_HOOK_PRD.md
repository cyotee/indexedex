# PRD: Uniswap V4 Single Standard Exchange Buffer Hook

**Name:** `UniswapV4SingleStandardExchangeBufferHook`  
**Date:** 2026-08-04  
**Status:** **Draft v1.1 — plan-ready** (corrects product identity + Hook Factory deploy; §15 O1–O18 locked 2026-08-04)  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/single/`  
**Package kind:** IndexedEx **hook diamond package** — pure **buffer pool** for one `(standardExchange, pairToken)` pair. **Not** an AMM. **Not** a rate-provider product. **Not** a liquidity/LP product. **Not** Dual SE CP. **Not** Single SE BCP (constant-product).

**Authority:**

| Layer | Role |
|-------|------|
| **This PRD** | **Canonical product + deploy law** for the single SE buffer hook |
| **Impl plan** | [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Supersedes** | [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md`](./UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md) (incorrect “pricing” product framing + CREATE3 monomorph deploy) |
| Factory PRD | `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Skill | `indexedex-uniswap-v4-hook-packages` |
| Gold deploy shape | `…/standardExchange/constantProduct/single/` DFPkg (deploy only — **different product**) |
| Behavioral peer (V4 only) | Crane `BaseTokenWrapperHook` **semantics** (permissions, zero CL, `beforeSwap` + `beforeSwapReturnDelta`) — **no inheritance** |

**Existing monomorph tree** under this path is **non-authoritative scaffold**. Plan may rewrite names/files from `*BufferPricing*` → `*Buffer*` and migrate to a diamond package.

---

## 0. Why the old PRD was wrong

The shipped PRD/name **`…BufferPricingHook`** and its narrative mixed three different ideas:

| Incorrect framing | Why wrong for this product |
|-------------------|----------------------------|
| **“Pricing hook”** | Sounds like an AMM mid, oracle, or rate feed. Product is a **route hop that wraps/unwraps**, not a market-making book. |
| **Rate provider / WstETH rate template as identity** | Balancer-style `IRateProvider` and WstETH “display rate” templates are **not** this product. No rate-provider facet, no rate-provider package, no external FX oracle. |
| **Interest / claim-growth as primary story** | SE yield may change wrap/unwrap amounts over time, but that is **SE accounting**. The buffer does not “price yield”; it **executes** SE `exchangeIn` / `exchangeOut`. |
| **CREATE3 monomorph + no vault registry** | Violates Hook Factory standard (this repo’s locked deploy path for V4 hooks). |
| **Heavy dual-purpose language** | “Buffer **and** pricing” invited implementors to invent mid markets, rate storage, or liquidity. |

**Correct identity (locked):**

> A **Uniswap V4 buffer pool**: a fee-0, **zero-CL-liquidity** pool whose only job is to let routers **market-swap** `pairToken ↔ SE shares` by **immediately** depositing into / redeeming from a bound Standard Exchange vault. No LP product. No rate provider. No inventory book on the hook.

---

## 1. Goal

Ship a **production-first Uniswap V4 hook package** that:

1. Binds **one** Standard Exchange vault and **one** pair token (`pairToken ∈ SE.vaultTokens()`).  
2. Powers a V4 pool with currencies **`pairToken` ↔ `address(SE)`** (SE diamond is the share ERC-20).  
3. On every swap, **immediately** wrap or unwrap through SE (`exchangeIn` / `exchangeOut`) and settle via hook deltas — **no** hook-held inventory as product.  
4. **Forbids** native V4 liquidity (`beforeAddLiquidity` reverts).  
5. Exposes **no** `IRateProvider`, **no** AMM CP book, **no** fungible LP on the hook.  
6. Exists so **trade routes** (Universal Router, SE Router, aggregators) can hop through buffer pools to enter/exit SE share denomination.  
7. Deploys as an **immutable hook diamond** via **package → Vault Registry `deployHookVault` → shared Hook Diamond Package Callback Factory** (CREATE2 flag mining).

### 1.1 Canonical user story (route hop)

```text
SE = ERC-4626 Standard Exchange (asset = USDC), share token = address(SE)
Buffer pool currencies: sort(USDC, SE), fee = 0, hooks = this instance
CL liquidity: none forever

--- Router hop: raw USDC → SE shares (wrap) ---
User/router swaps USDC → SE on the buffer pool
  → beforeSwap: take USDC from PoolManager
  → SE.exchangeIn(USDC → SE shares)  // deposit into protocol vault as SE defines
  → settle SE shares to PoolManager / swap recipient
  → hook ends flat (no intentional residual inventory)

--- Router hop: SE shares → raw USDC (unwrap) ---
Swap SE → USDC
  → take SE shares → SE.exchangeIn/Out to USDC → settle USDC

--- Multi-token SE (e.g. two vault tokens) ---
SE.vaultTokens() = [WETH, USDC]
  → needs TWO buffer instances/pools if both legs should be routable:
       pool_WETH: WETH ↔ SE
       pool_USDC: USDC ↔ SE
  → accepted V4 limitation (pair-only doors); not a multi-asset buffer in one pool
```

### 1.2 Product problem this solves

| Without buffer pools | With buffer pools |
|----------------------|-------------------|
| Routers only trade ERC-20 pairs that already have AMM liquidity | Router can **wrap** into SE shares (or unwrap) as a **swap hop** |
| SE deposit/redeem is a separate app action | Same swap surface as other V4 pools (exact-in / exact-out) |
| Multi-hop “trade then deposit” needs custom integrator logic | Path can include `… → pairToken → SE → …` when SE is a pool currency |

---

## 2. Technical feasibility (normative)

### 2.1 Verdict

**This product is technically possible on Uniswap V4.** It matches the established **token-wrapper / custom-accounting hook** pattern (Crane `BaseTokenWrapperHook` semantics):

| Requirement | V4 mechanism |
|-------------|--------------|
| Zero CL liquidity | Pool initialized; **no** `modifyLiquidity`; hook `beforeAddLiquidity` reverts |
| Full control of swap amounts | `beforeSwap` + **`beforeSwapReturnDelta`** (`BeforeSwapDelta`) so PoolManager does **not** need AMM depth |
| Immediate wrap/unwrap | In `beforeSwap`: take input currency → call SE → settle output currency; no second user tx |
| Market-swap UX | Any V4 swap router that can hit the pool key can wrap/unwrap |
| No rate provider contract | Exchange amounts come **only** from SE `previewExchange*` / `exchange*` |

**Not required for feasibility:**

- Concentrated liquidity or any LP mint  
- External `IRateProvider`  
- Hook-owned reserves / fungible LP  
- Non-zero pool fee  

### 2.2 What Uniswap forces (accepted limitations)

| Limitation | Consequence | Product response |
|------------|-------------|------------------|
| A V4 pool is **exactly two currencies** | Cannot buffer “all SE tokens” in one pool | **One buffer instance + one pool per `(SE, pairToken)`** |
| Multi-asset SE | N vault tokens ⇒ up to N buffer pools | Documented; factory deploys one binding at a time |
| Pool must be `initialize`d | Needs `fee`, `tickSpacing`, `sqrtPriceX96` | **Plumbing only** — fee **0**; tick/sqrt **test convention**; product mid is **not** CL |
| `sqrtPriceX96` exists on the pool | Quoters that only read CL mid will be **wrong** | Routes **must** use hook/SE previews or a quoter that understands custom accounting; document for integrators |
| Custom accounting gas | Every hop pays SE deposit/redeem gas | Accept; buffer is not a free 1-wei hop |
| SE must support closed-form pair ↔ SE | Missing routes break exact-in/out matrix | SE completeness is a **hard dependency** (see §6) |

### 2.3 What “no pricing” means (precise)

| Allowed | Forbidden |
|---------|-----------|
| SE `previewExchangeIn` / `previewExchangeOut` to size the swap | Hook-local AMM (`x*y=k`), weights, oracles, TWAP |
| Amounts that change when SE claim / fees change | Separate **rate provider** product, Balancer rate provider packaging, WstETH-style rate storage as product law |
| Public preview helpers that **pass through** SE | Hook reimplements pro-rata / Morpho / 4626 math |
| Fee = 0 on the V4 pool | Product LP fee, growth fee, `kLast` on this hook |

If SE usage fees dilute shares or reduce unwrap, the buffer **faithfully executes** SE — it does **not** invent a second fee layer and does **not** market itself as a peg keeper.

### 2.4 What “no liquidity” means (precise)

| Allowed | Forbidden |
|---------|-----------|
| Transient tokens on the hook **within one swap** (take → SE → settle) | User-facing deposit/withdraw LP APIs |
| SE holding protocol inventory after wrap | Hook product inventory / idle book |
| `beforeAddLiquidity` always reverts | Native V4 LP, CL positions, donate-as-liquidity |

**Hook ends flat** on success (same spirit as old D38): no intentional residual balances. Dust handling, if any, is SE residual policy only and must not create a hook inventory product (see §5).

### 2.5 Failure modes that are **not** “impossible” — they are SE/integration bugs

These do **not** make the buffer design impossible; they fail closed if SE is incomplete:

1. SE missing exact-out wrap/unwrap routes.  
2. SE missing `pairToken ∈ vaultTokens()`.  
3. Reentrancy / lock if SE and hook re-enter poorly (use SE lock + hook only-PoolManager).  
4. Router quoting off CL `sqrtPrice` only (integrator bug).

---

## 3. Product summary

### 3.1 What this package is

| Attribute | Value |
|-----------|--------|
| Primary artifact | Hook **diamond** at CREATE2 is bootstrap (vault pair + package-as-init). Production `IHooks` + thin views land on `finalizeInitialization` |
| Binding | One `poolManager` + one `standardExchange` + one `pairToken` |
| Pool currencies | Address-sorted `pairToken` and `address(standardExchange)` |
| Behavior | Immediate wrap / unwrap via SE In/Out on every swap |
| Liquidity | **None** (CL forbidden) |
| Rate provider | **None** |
| LP token | **None** |
| Pool fee | **0** |
| Pricing source | **SE previews only** (passthrough) |
| Deploy | Hook diamond package + registry `deployHookVault` |
| Route role | Optional hop: enter/exit SE share denomination |

### 3.2 What this package is not

- Not Dual SE Buffer CP (`…/dual/`) — two SEs, CP book, fungible LP.  
- Not Single SE BCP (`…/constantProduct/single/`) — raw×claim CP AMM + LP.  
- Not Orbital / Quad multi-asset AMM hooks.  
- Not a Balancer V3 rate provider DFPkg.  
- Not a Morpho-specific package (any SE with closed-form pair↔SE).  
- Not a vault that mints a **new** share token (SE already is the share).  
- Not an interest-rate or FX oracle.

### 3.3 Non-goals (v1)

1. Multi-token buffer in one pool.  
2. Auto-deploying N buffers for all `vaultTokens()` in one call (may be a later helper script; not v1 package law).  
3. Native ETH currency (use WETH).  
4. Permit2 on hook (router can pull; SE may have its own paths).  
5. Same-tx full production ABI at CREATE2. Doors + ABI are staged (`deployPair` then `finalizeInitialization`).  
6. Hook-side usage fee / growth fee / `kLast`.  
7. Subclassing Crane `BaseTokenWrapperHook` / `BaseHook` / `DeltaResolver`.  
8. Sharing TestBases with DETF or Single SE BCP beyond factory TestBase ladder.  
9. Keeping the name **Pricing** or rate-provider product narrative.

### 3.4 Sibling map (do not conflate)

| Package | Path | Role |
|---------|------|------|
| **This** | `…/standardExchange/single/` | **Buffer only** — wrap/unwrap hop |
| Dual SE CP | `…/standardExchange/dual/` | Two SE claims, CP AMM, LP |
| Single SE BCP | `…/constantProduct/single/` | One SE + raw leg CP AMM, LP |
| Legacy monomorph “Pricing” | same `single/` tree today | **Wrong product framing** — replace |

---

## 4. Locked decisions

### 4.1 Identity & naming

| # | Decision | Value |
|---|----------|--------|
| B1 | Product name | **`UniswapV4SingleStandardExchangeBufferHook`** |
| B2 | Drop “Pricing” | Rename types/files/interfaces; no public “rate” product surface |
| B3 | Path | Keep `contracts/hooks/uniswap/v4/standardExchange/single/` |
| B4 | Role names | `standardExchange`, `pairToken` (not `underlying` if that implies 4626-only; **pairToken** is the bound vault token). Alias: for ERC-4626 SE, `pairToken` is typically `asset()`. |
| B5 | Wrapper address | Always `address(standardExchange)` in v1 |

### 4.2 Pool & swap law

| # | Decision | Value |
|---|----------|--------|
| B6 | Pool fee | **0** |
| B7 | CL / modifyLiquidity | **Forbidden** — `beforeAddLiquidity` reverts |
| B8 | Donate | Not implemented / revert |
| B9 | Swap model | Custom accounting only: `beforeSwap` + `beforeSwapReturnDelta` |
| B10 | Wrap direction | `pairToken → SE` via SE deposit path |
| B11 | Unwrap direction | `SE → pairToken` via SE redeem path |
| B12 | Quote matrix | Exact-in + exact-out both directions (four modes) via SE In/Out |
| B13 | Amount source | **Only** SE `previewExchangeIn` / `previewExchangeOut` and matching execute |
| B14 | Hook fees | **None** |
| B15 | Rate provider | **None** — no `IRateProvider`, no rate storage, no rate facet |
| B16 | Inventory | No product inventory; settle in-swap; end flat on success |
| B17 | Zero amounts | Revert |
| B18 | Tight SE bounds | `minOut` / `maxIn` = SE preview (router owns user slippage) |
| B19 | Deadline to SE | `block.timestamp` only (v1) |
| B20 | Currency order | Fixed at init from address sort of `pairToken` vs `SE`; **public** `currency0()` / `currency1()` required (O13); `wrapZeroForOne` Repo-only (no public getter) |
| B21 | Pool init | Product door via `deployPair` (or matching raw `PoolManager.initialize`); `beforeInitialize` validates wrap-aware pair + fee=0 (view-only) |
| B22 | Test / hint convention | `tickSpacingHint = 60`, `sqrtPriceX96Hint` 1:1 mid, `poolFee = 0` — public pure/view helpers (O13); plumbing only |

### 4.3 Deploy / Hook Factory (standard)

| # | Decision | Value |
|---|----------|--------|
| B23 | Instance shape | **Immutable diamond** via shared hook factory CREATE2 |
| B24 | Package | `IUniswapV4SingleStandardExchangeBufferHookPackage` holds `PkgInit` / `PkgArgs` |
| B25 | Product path | `pkg.deployVault(args, mineNonce)` → `registry.deployHookVault` → hook factory; **also** `deployVaultAutoMine(args)` required (O16) |
| B26 | Premine-first | Required for production scripts; auto-mine is test/convenience only |
| B27 | `PRODUCT_ID` | `keccak256("uv4-single-se-buffer-hook")` |
| B28 | `calcSalt` | `PRODUCT_ID`, `poolManager`, `standardExchange`, `pairToken` — **no** package address, **no** facet addresses |
| B29 | `requiredHookFlags` | Pure package-constant: `BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA` |
| B30 | `isExpectedInstance` | Thin: code + flags |
| B31 | Facets | CREATE3 product facet(s); bindings in Repo via `initAccount` |
| B32 | No live `diamondCut` | Install-then-remove; abandon bad configs |
| B33 | Vault registration | **Yes** — liquidity-holding is false, but buffer is a **registered vault-class package** for discovery (`IStandardVaultPkg`). Instance cuts **existing** `MultiAssetBasicVaultFacet` + `MultiAssetStandardVaultFacet` (multi-asset facets OK with two tokens). `initAccount` inits `MultiAssetBasicVaultRepo` with **address-sorted** `vaultTokens = sort(pairToken, SE)` (O8) and **reserves stay 0** (no inventory product; no reserve updates on wrap/unwrap). `StandardVaultRepo` vaultTypes/feeTypeIds/contentsId set at init. **No** `IStandardExchangeIn`/`Out` on the buffer diamond. |
| B34 | Retire | CREATE3 monomorph FactoryService instance deploy; `*BufferPricing*` production names |

### 4.4 Multi-pool / multi-token SE

| # | Decision | Value |
|---|----------|--------|
| B35 | One binding = one pair | `(SE, pairToken)` only |
| B36 | Many tokens | Deploy **many** packages/instances (or many `PkgArgs`) — one pool per token |
| B37 | Same SE, different pairToken | Different salt / different instance |
| B38 | Same SE + pairToken | One immortal binding (first-deployer-wins); no multi-namespace product identity (unlike old D58 namespace multi-instance) — **one binding → one address**. If tests need a second instance, change `PRODUCT_ID` only via new package version, not saltNamespace noise |

### 4.5 Inheritance & code shape

| # | Decision | Value |
|---|----------|--------|
| B39 | Crane bases | **No** Solidity inheritance of `BaseTokenWrapperHook`, `BaseHook`, `DeltaResolver`, `WstETHHook` |
| B40 | Pattern-copy | Permissions, pair/fee checks, take/settle order only |
| B41 | Layout | Interface package + DFPkg + Facet + Target + Repo (+ small Common if needed) |
| B42 | SE math | Forbidden in hook — SE only |

---

## 5. Swap execution (normative sketch)

Permissions: `beforeInitialize`, `beforeAddLiquidity` (revert), `beforeSwap`, `beforeSwapReturnDelta`.

### 5.1 Wrap exact-in (`pairToken` in → SE out)

```text
amountIn = -amountSpecified
seOut = SE.previewExchangeIn(pairToken, amountIn, SE)
take pairToken from PM
approve SE; SE.exchangeIn(... minOut = seOut)
settle SE shares to PM
return BeforeSwapDelta(specified=amountIn, unspecified=seOut)  // pattern-copy BaseTokenWrapperHook signs
```

### 5.2 Wrap exact-out / unwrap exact-in / unwrap exact-out

Same structure: preview → take exact needed → SE execute → settle opposite. Exact-out takes **exactly** previewed `amountIn` from PM (no surplus-max pull as primary path).

### 5.3 Dust / residual

- Prefer SE routes that leave **no** residual.  
- **No** hook inventory product.  
- Do **not** invent a second absorb market. If SE documents ≤ few-wei unrefundable dust, follow SE/peer policy **without** creating a rate or fee product on this hook. Under-delivery of `amountOut` → revert (`Slippage` or SE error).

---

## 6. SE dependency

### 6.1 Hard requirement

Bound SE must expose **closed-form** `pairToken ↔ SE` for:

| Mode | SE API |
|------|--------|
| Wrap exact-in | `previewExchangeIn` + `exchangeIn` |
| Wrap exact-out | `previewExchangeOut` + `exchangeOut` (`tokenOut = SE`) |
| Unwrap exact-in | `previewExchangeIn` + `exchangeIn` (`tokenIn = SE`) |
| Unwrap exact-out | `previewExchangeOut` + `exchangeOut` (`tokenOut = pairToken`) |

**preview == execution** on user-facing amounts (≤ documented SE dust only).

### 6.2 Phase 0

Plan Phase 0: verify (or finish) these routes on the SE family used in tests (ERC-4626 SE is the default hermetic leg). **Do not** re-open unrelated SE first-deposit product law in this PRD unless routes are missing.

### 6.3 Fees

SE may charge usage fees; buffer **does not**. Previews must include SE fees. Tests should include **non-zero SE fee** cases so wrap is not assumed 1:1.

---

## 7. Target architecture

```text
contracts/hooks/uniswap/v4/standardExchange/single/
  interfaces/
    IUniswapV4SingleStandardExchangeBufferHook.sol          # instance ABI
    IUniswapV4SingleStandardExchangeBufferHookPackage.sol   # PkgInit, PkgArgs, deployVault
  facets/
    UniswapV4SingleStandardExchangeBufferHookFacet.sol      # IHooks + product previews
  UniswapV4SingleStandardExchangeBufferHookDFPkg.sol
  UniswapV4SingleStandardExchangeBufferHookTarget.sol
  UniswapV4SingleStandardExchangeBufferHookRepo.sol
  UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol  # product facet + deployPkg only
  TestBase_UniswapV4SingleStandardExchangeBufferHook.sol
  THIS PRD
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md

Also cut into diamond (shared, not package-local):
  MultiAssetBasicVaultFacet
  MultiAssetStandardVaultFacet

RETIRE / rename away from production:
  *BufferPricing* monomorph, CREATE3 HookMiner instance deploy, old pricing PRD as authority
```

### 7.1 PkgInit / PkgArgs

```solidity
struct PkgInit {
    IVaultRegistryDeployment vaultRegistryDeployment;
    IFacet productFacet;
    IFacet multiAssetBasicVaultFacet;     // existing shared facet
    IFacet multiAssetStandardVaultFacet;  // existing shared facet
}

struct PkgArgs {
    address poolManager;
    address standardExchange;
    address pairToken;
}
```

Validation: non-zero; `pairToken ∈ SE.vaultTokens()` (or SE surface equivalent); `pairToken != SE`.  
`initAccount`: bind Repo + `MultiAssetBasicVaultRepo._initialize` with **address-sorted** `[lower, higher]` of `pairToken` vs `SE` (O8) + `StandardVaultRepo` types/fee ids; **do not** update reserves on swap.

### 7.2 Canonical deploy story

```text
1. setHookDiamondPackageFactory(hookFactory)
2. registry.deployPkg(bufferPkg, PkgInit, salt)
3. premine mineNonce for PRODUCT_ID + binding
4. pkg.deployVault(args, mineNonce) → registered bootstrap diamond
5. deployPair(tokenA, tokenB) for the wrap-aware pair (either order; fee=0, hooks=proxy)
6. finalizeInitialization Adds PRODUCT_FACET only
7. routers swap for wrap/unwrap hops
```

---

## 8. Public surface (instance)

**Normative product ABI** (O13 — no implementor subsetting):

```text
// Bindings
poolManager()
standardExchange()
pairToken()
wrapper()                    // == standardExchange

// Pool / currency helpers (address-sorted; fee/hints are constants)
currency0()                  // lower(address(pairToken), address(SE))
currency1()                  // higher(...)
poolFee()                    // pure → uint24(0)
tickSpacingHint()            // pure → int24(60)   // B22 plumbing only
sqrtPriceX96Hint()           // pure → uint160 1:1 mid (SQRT_PRICE_1_1)

// Previews (SE passthrough)
previewWrap(amountIn)
previewWrapExactOut(seOut)
previewUnwrap(seIn)
previewUnwrapExactOut(pairOut)

// IHooks (+ getHookPermissions if cut)
// Multi-asset vault facets: vaultTokens, reserveOfToken, reserves,
//   vaultFeeTypeIds, contentsId, vaultTypes, vaultConfig
```

**`vaultFeeTypeIds` / `contentsId` (O12):**

```text
HOOK_VAULT_TYPE = bytes4(keccak256("UniswapV4SingleStandardExchangeBufferHook"))
vaultFeeTypeIds = bytes32(HOOK_VAULT_TYPE)   // bytes4 left-aligned in bytes32
contentsId = keccak256(abi.encode(PRODUCT_ID, standardExchange, pairToken))
  // PRODUCT_ID = keccak256("uv4-single-se-buffer-hook"); pairToken unsorted binding field
```

**Package deploy surface (O16):**

```text
deployVault(PkgArgs args, uint256 mineNonce) → address
deployVaultAutoMine(PkgArgs args) → address   // required; gas-risky; tests may use; prod premine-first
```

**No:** `rate()`, `getRate()`, `IRateProvider`, LP ERC-20, deposit/withdraw liquidity, `kLast`, dual-token CP views, public `wrapZeroForOne()`.

### 8.1 Error law (O14)

**Crane wrapper/hook names — use exactly** (pattern-copy identifiers; no inheritance):

| Error | When |
|-------|------|
| `LiquidityNotAllowed` | `beforeAddLiquidity` |
| `InvalidPoolToken` | `beforeInitialize` pair mismatch |
| `InvalidPoolFee` | `beforeInitialize` fee ≠ 0 |
| `HookNotImplemented` | Unused IHooks callbacks |
| `ExactInputNotSupported` | **Declared for Crane ABI parity only — must never revert in v1** (all exact-in modes supported) |
| `ExactOutputNotSupported` | **Declared for Crane ABI parity only — must never revert in v1** (all exact-out modes supported) |

**Package / product additions (fixed names — do not invent substitutes):**

| Error | When |
|-------|------|
| `ZeroAddress` | Zero pm / SE / pairToken / facet in args or init |
| `SameToken` | `pairToken == standardExchange` |
| `InvalidPairToken` | `pairToken ∉ SE.vaultTokens()` (or SE equivalent) |
| `ZeroAmount` | Zero amountIn / amountOut on preview or swap path |
| `NotPoolManager` | Hook entry called by non-PoolManager |

SE reverts bubble unchanged. Factory deploy collisions / mine exhaustion use **hook factory peer errors** only (do not invent a second mine API).

---

## 9. Testing expectations

Ladder: `CraneTest` → `IndexedexTest` → Hook factory TestBase → buffer TestBase.

| Area | Assert |
|------|--------|
| Deploy | Package → registry → hook factory; flags; vault registered |
| Salt | Binding-stable; no package address |
| Init | Wrong pair / non-zero fee reverts; addLiquidity reverts |
| Wrap/unwrap | All four modes; preview == execution |
| Flat hook | No material residual after success |
| SE fee on | Non-1:1 still works; still no hook fee |
| Yield SE (optional) | After real accrual, unwrap preview per share may rise — still SE-driven, not rate provider |
| Route smoke | Multi-hop or sequential: swap into buffer then out (hermetic) |
| Profile | `FOUNDRY_PROFILE=hook_factory` |
| Production-first | Real SE + real PM port; no mock buffer package/factory |

### 9.1 Hermetic SE leg (locked)

| Component | Source |
|-----------|--------|
| `pairToken` | Mintable test ERC-20 (e.g. `SimpleMintableERC20`) — funding stub only |
| Protocol 4626 | **Mandatory** Crane **`ERC4626PermitDFPkg`** via create3Factory / diamondPackageFactory peer path (O17). Asset = `pairToken`. **Not** Morpho. **Not** `SimpleYieldERC4626` for DoD. |
| SE | Production **ERC-4626 Wrapper Standard Exchange** via `TestBase_ERC4626StandardExchange` / registry `deployVault(protocolVault)` |
| PoolManager | Hermetic: real Crane V4 `PoolManager` **bytecode** deploy (`vm.deployCode`) |

Do **not** require Morpho MetaMorpho for hermetic green. Morpho is not a hermetic matrix row.

### 9.2 Fork DoD (locked) — O18

Hermetic **plus** both:

1. **Base mainnet** fork under `test/foundry/fork/base_main/hooks/uniswap/v4/standardExchange/single/`  
2. **Robinhood (chain 4663)** fork under `test/foundry/fork/robinhood_4663/hooks/uniswap/v4/standardExchange/single/`

**Pin strategy (mandatory):**

| Pin | Source |
|-----|--------|
| Base `PoolManager` | Crane `BASE_MAIN.UNISWAP_V4_POOL_MANAGER` = `0x498581fF718922c3f8e6A244956aF099B2652b2b` |
| Robinhood `PoolManager` | Crane `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` = `0x8366a39CC670B4001A1121B8F6A443A643e40951` |

On each fork: **deploy fresh** mintable `pairToken` + Crane `ERC4626PermitDFPkg` + Wrapper SE + buffer package; **use live** PoolManager. Header of each fork TestBase must quote the pin constant path + address.

### 9.3 Adversarial DoD (locked)

Full Crane catalog adapted to buffer (A donation, B SE-fee/spot where applicable, C reentrancy, E residual/zero, F immutability/access, H grief/SE mid-swap revert). Suite under `test/.../single/adversarial/`. P0/P1 green or explicitly deferred in suite NatSpec. See implementation plan.

---

## 10. Migration from incorrect monomorph

| Phase | Work |
|-------|------|
| **0** | SE route matrix green for test SE |
| **1** | Package skeleton on hook factory (rename product) |
| **2** | Port wrap/unwrap Target to diamond (drop pricing narrative / rate language) |
| **3** | Suite: four modes + liquidity ban + deploy path |
| **4** | Delete monomorph CREATE3 path; mark old pricing PRD superseded |
| **5** | Update cross-links (orbital/dual docs that still say “pricing buffer”) |

**Do not** keep “Pricing” as a second supported product name after DoD.

---

## 11. Explicit supersessions

| Old pricing PRD topic | This PRD |
|-----------------------|----------|
| Name `…BufferPricingHook` | B1 `…BufferHook` |
| Rate / WstETH template as product identity | B15 — none |
| Interest-as-product story | SE-only; buffer is route hop |
| CREATE3 monomorph FactoryService deploy | B23–B34 Hook Factory |
| Namespace multi-instance salt | B38 single binding identity |
| Any implication of AMM or LP | B7, B14, §2.4 |
| “Pricing correctness” as headline | “SE passthrough correctness” |

Reusable engineering (pattern-copy settle, four-mode matrix, SE dependency) may be **ported** without porting product branding.

---

## 12. Integrator notes (non-normative but important)

1. **Quoting:** Use hook/SE previews or a custom-accounting-aware quoter. Do not trust CL mid for size.  
2. **Routing:** Treat buffer pools as **wrap/unwrap edges**, not deep liquidity venues.  
3. **Coverage:** For multi-token SE, deploy one buffer per token you want on the graph.  
4. **Composition:** After wrap, next hop can trade **SE shares** if another pool lists `address(SE)`; after unwrap, trade raw `pairToken`.  
5. **Not a peg:** If SE is under-backed or paused, swaps revert or worsen — buffer does not socialize loss.

---

## 13. Risks

| Risk | Mitigation |
|------|------------|
| Integrators misread CL price | Docs + preview API; test that 1:1 sqrt init ≠ constant 1:1 wrap when fees/yield exist |
| SE incomplete routes | Phase 0 gate |
| Confusion with Dual / BCP | Sibling map B; different PRODUCT_ID and vault type |
| Residual tokens on hook from SE bugs | Revert / SE fix; no inventory product |

---

## 14. Definition of Done

1. Product named **Buffer** (not Pricing); no rate-provider surface.  
2. Hook factory package path only; vault registered.  
3. Zero CL; fee 0; four wrap/unwrap modes via SE only.  
4. No LP APIs; no hook fees; no intentional inventory.  
5. Hermetic suite green under `FOUNDRY_PROFILE=hook_factory`.  
6. Base + Robinhood fork smokes green.  
7. Adversarial P0/P1 green (or deferred IDs NatSpec’d).  
8. Old monomorph CREATE3 + pricing PRD marked superseded / non-authoritative.  
9. Implementation plan exists as a separate file.

---

## 15. Open items — **LOCKED** (2026-08-04 plan clarification)

| ID | Question | **Lock** |
|----|----------|----------|
| O1 | Vault surface for `_registerVault` | **Cut existing** `MultiAssetBasicVaultFacet` + `MultiAssetStandardVaultFacet` into the diamond (two tokens is fine). `vaultTokens = [pairToken, SE]`; **reserves remain 0**; no product SE In/Out on buffer. See **B33**. |
| O2 | Public previews on interface | **Yes** — §8 surface (`previewWrap*`, `previewUnwrap*`). |
| O3 | Dust absorb if SE leaves wei | Prefer SE fix / revert under-delivery; **no** hook `feeTo` dust product; **no** second absorb market. |
| O4 | File rename batch vs alias | **Full rename** `*BufferPricing*` → `*Buffer*` in one plan phase; no long-lived dual product name. |
| O5 | Hermetic SE matrix | **ERC-4626 Wrapper SE** + Crane **`ERC4626PermitDFPkg`** (test ERC-20 asset). **Not** Morpho for hermetic DoD. See §9.1. |
| O6 | Fork DoD | Hermetic **+ Base + Robinhood** forks required. See §9.2. |
| O7 | Adversarial DoD | **Full catalog** (donation, reentrancy, residual, mid-swap SE revert, immutability, grief). See §9.3. |
| O8 | `vaultTokens` order | **Address-sorted** `[lower, higher]` of `pairToken` vs `address(SE)` — same sort spirit as V4 pool currencies. Pool order still independent plumbing. |
| O9 | Redeploy same binding | **Factory peer policy** (BCP/stub): same salt + mineNonce → return existing if `isExpectedInstance`, else revert on wrong occupant. Premine-first. **No** multi-namespace second instance (B38). |
| O10 | Hermetic non-1:1 | Drive via **fee oracle non-zero usage fee on Wrapper SE only**. Yield/accrual optional P1 if protocol 4626 supports it; **not** Morpho hermetic. |
| O11 | Donation residual (A3) | **Allow idle stuck** pair/SE on hook; **never** credit into wrap/unwrap accounting. No feeTo sweep in v1. Success-path “flat” asserts ignore pre-seeded donations (or snapshot delta-only). |
| O12 | `vaultFeeTypeIds` / `contentsId` | `vaultFeeTypeIds = bytes32(HOOK_VAULT_TYPE)`; `contentsId = keccak256(abi.encode(PRODUCT_ID, standardExchange, pairToken))`. See §8. |
| O13 | Public currency / pool helpers | **Required:** `currency0()`, `currency1()`, `poolFee()`, `tickSpacingHint()`, `sqrtPriceX96Hint()`. See §8. No public `wrapZeroForOne()`. |
| O14 | Error names | Crane wrapper/BaseHook names exactly where overlapping; package errors fixed in §8.1. No substitute names. |
| O15 | File / type naming | **Full product names only** in production: `UniswapV4SingleStandardExchangeBufferHook*`. Tests may use basename prefix `UniswapV4SingleSEBufferHook_*` for path length only. |
| O16 | Auto-mine surface | Package **must** expose `deployVault(args, mineNonce)` **and** `deployVaultAutoMine(args)`. Premine-first for production docs; auto-mine for tests/convenience. |
| O17 | Hermetic protocol 4626 | **Mandatory** Crane `ERC4626PermitDFPkg` via CREATE3 / `diamondPackageFactory` peer path as `protocolVault`. **Forbidden** as DoD: `SimpleYieldERC4626` or other stubs as protocol vault. |
| O18 | Fork pin strategy | **Live** Uniswap V4 `PoolManager` pin per chain constants; **deploy fresh** mintable `pairToken` + Crane 4626 + Wrapper SE + buffer package on fork. Document pins in fork TestBase header. |

---

## 16. Feasibility summary (answer to “if I missed something”)

| Desire | Possible? | Notes |
|--------|-----------|--------|
| Buffer pool as V4 market-swap hop | **Yes** | Custom accounting wrapper pattern |
| Immediate wrap/unwrap, no LP | **Yes** | `beforeSwap` + SE execute + settle |
| No rate provider | **Yes** | SE previews only |
| No liquidity | **Yes** | Ban `modifyLiquidity` |
| One SE, all tokens in one pool | **No** | V4 pair limit → N pools |
| CL-only quoter correctness | **No** (without custom quoter) | Integrators must preview SE |
| 1:1 always | **Only if SE is 1:1** | Fees/yield change amounts; still not a “rate provider product” |

**Nothing in the desired product requires an impossible Uniswap feature.** The main design cost is **operational** (many pools for multi-token SE) and **integration** (quotes must use SE, not CL mid).

---

**End of PRD v1.1**
