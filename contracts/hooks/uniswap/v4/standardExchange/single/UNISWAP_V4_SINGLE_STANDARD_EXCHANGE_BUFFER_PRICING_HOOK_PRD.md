> **SUPERSEDED** by `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_PRD.md` / `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` (Buffer hook diamond package). Do not implement further under Pricing names.

# PRD: Uniswap V4 Single Standard Exchange Buffer Pricing Hook

**Name:** `UniswapV4SingleStandardExchangeBufferPricingHook`  
**Date:** 2026-08-02  
**Status:** Product + implementor-edge decisions locked (implementation planning ready)  
**Clarifications locked:** 2026-08-02 (see **D48–D74** and §3.1)  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/single/`  
**Package kind:** IndexedEx **hook deploy package** — CREATE3-mined single contract via the **existing** ecosystem `create3Factory` + `HookMinerCreate3` + FactoryService helpers. **Not** a vault share diamond; **not** a second CREATE3 factory; **not** `DiamondPackageCallBackFactory` for the hook instance (v1). **Not** a Facet/DFPkg diamond product — use **Repo + Target** style on a single mined contract.

**In-scope dependency (mandatory for implementors):** fix and complete the **generic ERC-4626 Standard Exchange** package under `contracts/vaults/standard/erc4626/` so the hook can price and settle **only** through `IStandardExchangeIn` / `IStandardExchangeOut` for the full exact-in + exact-out matrix. See **§6.0**. Shipping the hook without those SE fixes is **out of compliance** with this PRD.

**Related docs:**

- Strategy research: `docs/research/morpho/2026-08-02-morpho-uniswap-lending-mm-strategies.md`
- Composition diagram: `docs/research/morpho/2026-08-02-morpho-v2-uniswap-v4-composition-diagram.md`
- Generic ERC-4626 SE (must fix as part of this work): `contracts/vaults/standard/erc4626/`
- Peer vault facet wiring (for `vaultTokens`): Camelot / other SE DFPkgs under `contracts/protocols/dexes/**`
- Balancer SE rate provider package (deploy-shape peer): `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`
- Crane Uni V4 wrapper base: `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/base/BaseTokenWrapperHook.sol`
- Crane rate template: `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/WstETHHook.sol`
- Crane HookMiner (canonical paths):  
  - `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol`  
  - `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMiner.sol`  
  - (also) `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/HookMiner.sol`

---

## 1. Goal

Ship a **production-first Uniswap V4 hook package** that:

1. Binds a **Standard Exchange (SE)** vault (typically generic ERC-4626 SE over Morpho Vault V2, sfrxETH, Stata, etc.) and its **underlying / loan token** (e.g. WETH).
2. Powers a **wrapper-style V4 pool** `underlying ↔ SE shares` with **fee = 0** and **no CL liquidity**.
3. Sets swap amounts / effective price via **`beforeSwap` + `BeforeSwapDelta`** so the rate **tracks the SE’s claim on underlying**, including **protocol yield** (e.g. Morpho interest) when previews use underlying exchange paths.
4. On **underlying → SE**: pull underlying, call SE **`exchangeIn`** / **`exchangeOut`** as appropriate (deposit into protocol vault as needed), deliver SE shares.
5. On **SE → underlying**: take SE shares, call SE **`exchangeIn`** / **`exchangeOut`** as appropriate (redeem protocol vault as needed), deliver underlying.
6. Deploys via **existing** `create3Factory` (mined salt) + FactoryService helpers, composable with existing SE DFPkgs and V4 PoolManager.
7. **As a required prerequisite / co-deliverable of this PRD:** complete the ERC-4626 SE wrapper routes and `vaultTokens()` facet/storage wiring so Morpho (and any other 4626) work through standard SE APIs only (§6.0).

### 1.1 Canonical user story (Morpho + WETH)

```text
Pool: WETH ↔ SE(Morpho Vault V2, asset = WETH)

User deposits 3 WETH via swap → SE holds Morpho shares claiming ~3 WETH
Morpho interest accrues → claim grows (illustrative ~4 WETH; DoD is strict increase only — D61)
Hook rate updates so SE ↔ WETH quotes reflect the higher claim (not flat 1:1)

Swap WETH → SE:  take WETH → SE.exchangeIn → mint/give SE shares
Swap SE → WETH:  take SE → SE.exchangeOut → Morpho redeem → pay WETH
```

---

## 2. Product summary

### 2.1 What this package is

| Attribute | Value |
|-----------|--------|
| Primary artifact | CREATE3-mined single hook contract (Repo + Target style) implementing V4 `IHooks` |
| Bound SE | Any SE exposing `IStandardExchangeIn` / `IStandardExchangeOut` with **closed-form underlying ↔ SE** routes for the full matrix in §7 |
| Bound underlying | Token the SE treats as the base/underlying leg (for ERC-4626 SE: `protocolVault.asset()`) |
| Pool type | Uni V4 **wrapper pool** (not AMM fee earner) |
| Pricing source | SE `previewExchangeIn` / `previewExchangeOut` on **underlying ↔ SE** legs only (not SE Morpho-share `asset()` alone) |
| Deploy path | Existing `create3Factory` + `HookMinerCreate3` + FactoryService (see §8) |
| Co-deliverable | **ERC-4626 SE route + `vaultTokens` fixes** (§6.0) — required before hook DoD |

### 2.2 What this package is not

- Not a Standard Exchange **vault** (does not mint its own SE share token).
- Not a Morpho/Aave port (reuses existing SE packages after §6.0 fixes).
- Not a Morpho-**specific** SE package (generic ERC-4626 SE must suffice).
- Not a CL market-making vault (no tick liquidity, no LP NFTs).
- Not Uniswap V3 (V3 has no equivalent hook delta model).
- Not a Facet/DFPkg diamond product for the **hook instance** (Repo/Target + FactoryService only).

### 2.3 Non-goals (v1)

1. Multi-hop routes outside the bound pair.  
2. Native ETH as pool currency (use WETH; optional later ETH wrap hop).  
3. Levered LP, Morpho borrow, or dual-sleeve strategies.  
4. Hook-owned idle inventory as a product (hook is thin; SE holds protocol exposure).  
5. Auto-creating Morpho vaults / SE instances inside the hook package (caller supplies existing SE + underlying; optional helper deploy scripts outside PRD).  
6. DETF composition of the hook itself (DETF may later consume SE shares as a leg if desired).  
7. Dynamic LP fee / MEV capture / limit orders beyond buffer pricing.  
8. Package-owned pool initialization (integrator/script initializes the V4 pool).  
9. Hook-side Morpho / protocol-vault math that bypasses SE previews (forbidden; fix SE instead).  
10. **Shared code / TestBases / deploy helpers with Uni V4 Single SE DETF** (D64) — packages stay independent.  
11. **Rework of existing ERC-4626 SE first-deposit / donation protection** (D48) — already shipped; do not reopen in §6.0.  
12. **Deadline-skew Repo/admin surface** (D59) — v1 hardcodes `block.timestamp`.

---

## 3. Locked product decisions

| # | Decision | Value |
|---|----------|--------|
| D1 | Product name | **`UniswapV4SingleStandardExchangeBufferPricingHook`** |
| D2 | Package location | `contracts/hooks/uniswap/v4/standardExchange/single/` |
| D3 | SE generality | **Any `IStandardExchange`** with closed-form underlying ↔ SE routes; **underlying explicit at deploy**; deploy **requires** `underlying ∈ SE.vaultTokens()` (no empty-SE preview smoke) |
| D4 | Morpho-specific SE | **Not required** — generic ERC-4626 SE after §6.0 fixes; interest via protocol 4626 inside SE previews |
| D5 | Pricing correctness rule | Quotes must use **SE ↔ underlying** previews (`previewExchangeIn` / `previewExchangeOut`); **forbidden** as sole NAV: SE `convertToAssets` when `asset()` is protocol-vault shares only; **forbidden**: hook reimplements pro-rata/Morpho math |
| D6 | Wrap exact-in quote | **`previewExchangeIn(underlying, amountIn, SE)`** |
| D7 | Wrap exact-out quote | **`previewExchangeOut(underlying, SE, amountOut)`** — SE interface exact-out with **`tokenOut = SE`**. ERC-4626 **must implement** this route (§6.0); not a hook-side inverse |
| D8 | Unwrap exact-out quote | **`previewExchangeOut(SE, underlying, amountOut)`** |
| D9 | Unwrap exact-in quote | **`previewExchangeIn(SE, seIn, underlying)`** — SE interface exact-in exit. ERC-4626 **must implement** if missing (§6.0) |
| D10 | Execution | **`exchangeIn` / `exchangeOut` only** for all four modes; `recipient` set to hook (then settle); **`deadline = block.timestamp` only (D59)** — no Repo deadline-skew flag in v1; reentrancy consistent with SE |
| D11 | Pool fee | **0** |
| D12 | CL liquidity | **Forbidden** (`beforeAddLiquidity` reverts) |
| D13 | Hook model | Crane **`BaseTokenWrapperHook`** **semantics only** (permissions, pair/fee init checks, `beforeSwap` + `beforeSwapReturnDelta`, delta settle order). **No Solidity inheritance** of `BaseTokenWrapperHook`, **`BaseHook`, or `DeltaResolver`** — full **Repo + Target pattern-copy** (D51 / D67). |
| D14 | Rate template | **`WstETHHook`** pattern (dynamic rate helpers), amounts **only** from SE previews — reference only; do not subclass |
| D15 | Package shape | **Repo + Target + Common + FactoryService**; **no Facet**, **no DFPkg**, **no diamondCut** for the **hook** instance; single CREATE3-mined contract. (ERC-4626 SE remains a diamond DFPkg and **does** cut vault facets — §6.0.B) |
| D16 | Instance binding | Per-hook instance binds **one** SE + **one** underlying (and V4 PoolManager) |
| D17 | Pool initialization | **External caller / script only**; package deploys hook only; **no normative product tickSpacing/sqrtPrice**. Hook `beforeInitialize` still validates pair + fee=0. **Test convention (D56 / D60):** hermetic/fork TestBases use **`tickSpacing = 60`** and **1:1 mid `sqrtPriceX96`** (`TickMath.getSqrtPriceAtTick(0)` or equivalent) |
| D18 | Hook address mining | **Required**. Mine with **`HookMinerCreate3`** helpers (`computeAddress` / CREATE3 address formula; `deployer = address(existing create3Factory)`). **FactoryService owns the binding-aware mine loop** (do not call bare `find` / `findWithPrefix` alone for product deploys — see D32 / §8.5). Prefer off-chain mine in FactoryService |
| D19 | Deploy form (v1 **locked**) | **CREATE3-mined single hook contract** via **existing** `create3Factory` + **`HookMinerCreate3`**. No second CREATE3 factory; no `DiamondPackageCallBackFactory.deploy` for hook instance |
| D20 | Registration / deploy surface | **Library on existing create3Factory only** — not vault registry, not `deployPkg`, **not** a new IndexedexManager surface. Typed `UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService` = **internal library helpers** on `ICreate3FactoryProxy` (peer facet FactoryService pattern). ACL = existing `create3` / `create3WithArgs` **`onlyOwnerOrOperator`** |
| D21 | CREATE3 salt namespace | **Default namespace:** `"uv4-single-se-buffer-pricing-hook-"`. **Override allowed** on `deployHook` (empty / omitted → default). Binding + mineNonce are always part of salt material (D32). **Multi-instance (D58):** same `(poolManager, SE, underlying)` with a **different** non-empty namespace is an **intentional** way to deploy **multiple** hook instances (e.g. test vs prod, A/B). Idempotency (D37) is **per** `(namespace, poolManager, SE, underlying)` |
| D22 | Miner/deployer consistency | Miner `deployer` **must** equal `create3Factory`. Mining with EOA/`address(this)` then deploying via factory is **forbidden** |
| D23 | Preview fidelity | **preview == execution** on closed-form wrap/unwrap (± **`MAX_DUST_WEI` (10)** only if SE documents multi-leg dust per D50/D55). SE interfaces treat preview as source of truth |
| D24 | Fees in previews | **Previews ALWAYS include any usage/mint fees** as they affect state / return values. Hook does not invent a second fee layer. Fee **shape** locked in D40 |
| D24a | Fee test law | Tests **must** configure a non-zero **usage fee on the Vault Fee Oracle** for the ERC-4626 SE fee type and assert preview == execution **with fees on**. Zero-fee paths may remain as additional coverage, not the sole proof |
| D40 | Usage fee shape (ERC-4626 SE) | **Dilution mint on share-minting routes only (locked):** fee = % of **user shares due**; **expand total supply** by minting that fee amount to `feeTo`; **do not deduct** from shares due to the user. User receives full calculated `userShares`. Existing holders are diluted. **v1 exit/unwrap: no usage fee** (no user skim, no exit dilution mint). See §6.0 fees + D42 |
| D40a | Fee math unit (ERC-4626 SE) | **WAD + `BetterMath._percentageOfWAD` only** (Rocket Pool SE peer). `feeShares = BetterMath._percentageOfWAD(userShares, usageFeeOfVault(SE))`. **Not** Aave Stata `FEE_DENOMINATOR` style for this package |
| D25 | Interest proof | Tests must show Morpho (or yield 4626) accrual **strictly increases** underlying out per SE share (**D61** — strict increase only; **no** fixed 3→4 ratio requirement; 3→4 in §1.1 is narrative only). **Real accrual only (D52):** advance time + protocol interest paths; **forbidden:** `vm.store` / balance-deal cheats solely to inflate `convertToAssets` / claim growth |
| D26 | Production-first tests | Real SE + real Morpho (or real protocol 4626) + real V4 PoolManager port; no mock SUT |
| D27 | Fee type (hook) | Hook package does not change SE fee policy; whatever SE charges **must** appear in SE previews (D24) |
| D28 | Quote matrix v1 | **Exact-in + exact-out both ways** (wrap and unwrap) — option A; all four via SE In/Out only |
| D29 | Binding | **Constructor immutables** for `poolManager`, `standardExchange`, `underlying`; Diamond **Repo** for any non-immutable layout fields / flags as needed; **no post-deploy `initialize` for binding** |
| D30 | Pool vault currency | **Always `address(SE)`** (SE diamond / share token). No separate share-token arg in v1 |
| D31 | Settlement | Prefer **pretransferred** when SE implements it. **Exact-out Out:** compute `amountIn`, burn/spend **only** that, **refund** refundable excess (pretransferred or pull); unrefundable multi-leg dust ≤ **`MAX_DUST_WEI = 10`** → oracle **`feeTo` only (D50 / D66)** when non-zero; **skip if `feeTo == 0` (D71)**; under-delivery of `amountOut` → **`Slippage` (D69)**; **zero amounts revert (D74)**. **No Permit2** on hook paths in v1. **Hook exact-out take (D43):** from PoolManager take **exactly** SE-previewed `amountIn` (no surplus pull) |
| D32 | Salt scheme | **Binding-aware CREATE3 salt** (locked). Material = `namespace, poolManager, standardExchange, underlying, mineNonce`. **Encode (option C):** Crane **`BetterEfficientHashLib`** — same style as `HookMinerCreate3.findWithPrefix`: `salt = abi.encodePacked(namespace, poolManager, standardExchange, underlying, mineNonce)._hash()`. **Canonical implementation lives only in `UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService`** (public pure helpers for salt + mine) so every deployer shares one formula. `mineNonce` until flags match. Same binding + namespace ⇒ same address. Use `HookMinerCreate3.computeAddress` (`deployer = create3Factory`). **Do not** bare `find` / `findWithPrefix` for product deploys (empty-only breaks D37) |
| D33 | Public previews on hook | **Yes** — all wrap/unwrap exact-in/out preview helpers are permissionless views |
| D34 | ERC-4626 SE co-work | **In scope of this PRD** — implementors **must** fix ERC-4626 SE per §6.0 |
| D35 | Fork priority | **Robinhood first**, then **Base**. Base Morpho addresses: **prefer Morpho official documentation** |
| D36 | Deploy validation | Non-zero addresses; **`underlying` ∈ `SE.vaultTokens()`**; no empty-SE preview smoke; `Hooks.validateHookPermissions` |
| D37 | `deployHook` idempotency + collision | **Idempotent when same binding:** recompute salt/address for `(namespace, poolManager, se, underlying)`; if predicted address has code and is the **expected hook** per **D53**, **return existing**. **If predicted address has code that is not the expected hook**, **revert** — do not keep mining past a flag-matching collision. Empty code ⇒ deploy |
| D38 | Exact-out spend law | For all exact-out routes: **calculate `amountIn`, consume only that, refund the rest** when the excess is a normal refundable surplus (pretransferred excess, pull overshoot). Hook does **not** retain inventory as a product. **Unrefundable multi-leg residual ≤ `MAX_DUST_WEI` (D50 / D66):** absorb to **oracle `feeTo` only** when `feeTo != 0` — not leave on hook/SE as idle inventory when a recipient exists, not require a second-transfer refund; **`feeTo == 0` → skip absorb (D71)**. **Under-delivery of `amountOut` is not dust** — revert `Slippage` (D69). **Zero amounts revert (D74)** |

| D39 | Hook swap implementation | Implement wrap/unwrap **exact-in and exact-out** via SE `exchangeIn` / `exchangeOut` + spend-only-`amountIn` + refund on the **Target** (pattern-copy settle path). **Do not** inherit Crane `BaseTokenWrapperHook`, `BaseHook`, or `DeltaResolver` (D51 / D67); do not rely on `_deposit`/`_withdraw` exact-in shape. Still match BaseTokenWrapperHook **permissions**, pair/fee init checks, and V4 delta settle order |
| D41 | MultiAsset Target/Facet law | **Mandatory for ERC-4626 SE path:** domain logic in **`MultiAssetBasicVaultTarget` / `MultiAssetStandardVaultTarget`**; **Facets implement `IFacet` only** (metadata + inherit Target). Same Crane pattern as `BasicVaultFacet is BasicVaultTarget, IFacet`. **Blast radius (locked):** **ERC-4626-focused only** — extract/split as needed so ERC-4626 SE cuts the standard `vaultTokens` surface. **Regression floor (D54):** **compile green + ERC-4626 SE suite only**. **Do not** require peer SE (Camelot/Aero/etc.) rewrites or full peer suites beyond compile for shared facet consumers |
| D42 | Exit / unwrap usage fee (v1) | **None.** Usage fee applies **only** on share-minting routes (wrap exact-in/out, protocolVault→SE mint). Unwrap / exit routes: full calculated underlying (or vault-token) out to user; **no** usage-fee skim; **no** exit dilution mint. Later PRD may revise |
| D43 | Hook exact-out take from PoolManager | **Exactly** the SE-previewed `amountIn`. Do **not** pull a larger `maxIn` from PM and rely on SE refund of surplus as the primary path. SE refund path remains for `pretransferred` / interface compliance / dust |
| D44 | protocolVault → SE exact-out scope | **SE completeness / peer-route parity only** (§6.0.A DoD). **Not** a hook swap path in v1 (hook pool is **underlying ↔ SE** only) |
| D45 | Hook v1 SE test matrix | **ERC-4626 / Morpho only** for hook DoD (hermetic Morpho + RH/Base fork). Other SE families (Camelot, etc.) are out of the v1 hook matrix (product still claims any SE meeting §6.1) |
| D46 | Hook → SE minOut / maxIn | **Tight = preview.** Pass `minOut` / `maxIn` equal to SE-previewed amounts (no hook-side slippage buffer). Outer router / caller owns user-facing slippage |
| D47 | Robinhood P0 fork readiness | Use **existing** foundry profile, RPC, and Morpho **infra** constants (`ROBINHOOD_MAIN` / peer patterns). Do not invent RH Blue/factory addresses from scratch when repo sources exist. **Vault instance (D68 / D72):** before P0 fork DoD, **pin an explicit Morpho-official / curated WETH Morpho Vault V2 address** into `ROBINHOOD_MAIN` (or IndexedEx constants) — factory alone is not enough; **not** TVL-discovered arbitrary instance |
| D48 | Empty SE / first deposit | Empty SE **allowed at hook deploy** (D36). First-deposit / donation-inflation protection is **already shipped SE law** — **do not rework** as part of §6.0; hook only relies on existing SE behavior. Not new hook product logic |
| D49 | Hook Repo fields (v1) | Binding is **ctor immutables** (D29). **`wrapZeroForOne` is Repo storage only (D70 / D73)** — set once in ctor from address sort (D62); **not** an immutable field; **not** a public product getter; not deferred to `beforeInitialize`. **No** deadline-skew Repo field (D59). Repo also holds any layout/helpers Common/Target need for settle; **no required post-deploy mutable product flags** |
| D50 | Unrefundable exact-out dust (v1) | When multi-leg SE math leaves a residual **≤ `MAX_DUST_WEI = 10`** that **cannot** be returned on the same settle path without a **second transfer**, **absorb** that residual to **oracle `feeTo` only (D66)** when `feeTo != address(0)` — do **not** leave it as idle product inventory on the hook or SE when a fee recipient exists; do **not** absorb to “protocol inventory” as an alternate destination; do **not** require a dedicated second-transfer user refund for that dust. **If `feeTo == address(0)`: skip absorb (D71)** — mirror Rocket Pool fee-mint skip; residual may remain only in that edge; NatSpec must document. Residual **> 10 wei** that cannot be refunded on-path is **not** silent absorb — fix math or revert (do not expand the bound without PRD revision). **Refundable surplus** (pretransferred excess, pull overshoot of calculated `amountIn`) still **refunds to caller** per D38. **Dust is leftover input residual only** — under-delivery of `amountOut` reverts `Slippage` (D69). SE NatSpec **must document** `MAX_DUST_WEI = 10`, absorb destination = oracle `feeTo`, and **skip when `feeTo == 0` (D71)**. Tests: refundable excess refunded; unrefundable residual (if any) lands on **`feeTo`** with **amount ≤ 10 wei** when `feeTo` non-zero; preview == execution for user-facing amounts |
| D51 | Hook inheritance shape | **Repo + Target pattern-copy; no Solidity inheritance** of Crane `BaseTokenWrapperHook` / `WstETHHook` / **`BaseHook` / `DeltaResolver`** (D67). Reuse as **behavioral reference** only (permissions bits, pair/fee validation, delta settle order). Pattern-copy take/settle/pay paths fully. Single CREATE3-mined contract wires Target/Repo/Common |
| D52 | Interest test method | **Real accrual only:** force Morpho (or protocol 4626) interest via **time advance + real protocol interest paths** (Crane Morpho TestBase / port helpers that drive genuine accrual are OK). **Forbidden:** `vm.store`, raw balance deals, or other cheats whose sole purpose is to inflate claim / `convertToAssets` without protocol accrual |
| D53 | `isExpectedHook` identity | **Views only:** predicted address has code; readable views `poolManager()`, `standardExchange()`, `underlying()` **equal** deploy args. **No** required interface-id, package marker, or creation-code hash check for idempotent return. Wrong immutables / non-matching views / empty-wrong product ⇒ **revert** (D37) |
| D54 | MultiAsset regression floor | After Target extract: **`forge build` green + ERC-4626 SE suite** (routes, vaultTokens, fees, interest). Peer packages that cut the same MultiAsset facets must **compile**; full peer SE suites are **not** required merge gates for this PRD |
| D55 | Dust constant | Canonical name **`MAX_DUST_WEI = 10`** (uint256). Document in ERC-4626 Out Target NatSpec and any SE helper that absorbs D50 dust |
| D56 | Test pool tickSpacing | Hermetic and fork hook TestBases **initialize** the V4 pool with **`tickSpacing = 60`**. Product package still does **not** set or own tickSpacing (D17) |
| D57 | Fee unit peer | ERC-4626 SE dilution fee **must** follow Rocket Pool SE: `BetterMath._percentageOfWAD` + oracle `usageFeeOfVault` (alias of D40a) |
| D58 | Namespace multi-instance | **Yes — intentional.** Different `saltNamespace` values for the same `(poolManager, SE, underlying)` deploy **distinct** hooks. Product supports multi-instance; default-namespace idempotency still holds per D37 |
| D59 | SE deadline from hook | **`block.timestamp` only** on all hook→SE `exchangeIn` / `exchangeOut` calls. **No** ctor skew, **no** Repo deadline-skew flag in v1 |
| D60 | Test pool sqrtPrice | Hermetic/fork TestBases initialize with **1:1 mid price:** `sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0)` (or equivalent 1:1). Pricing still comes from hook deltas / SE previews, not CL; convention is for valid `initialize` only |
| D61 | Interest DoD bar | **Strict increase only:** after real accrual (D52), `previewUnwrap(seAmount)` (underlying terms) is **strictly greater** than pre-accrual. **No** minimum bps floor; **no** fixed 3→4 ratio. §1.1 3→4 is illustrative narrative only |
| D62 | Currency order at ctor | **`wrapZeroForOne` (or equivalent) set in constructor** from address sort: compare `underlying` and `address(SE)` (same spirit as BaseTokenWrapperHook currency order). **Stored in Repo (D70 / D73)** — fixed for life of instance (no post-deploy mutation; **no public getter**). **Not** an immutable field; **not** deferred to `beforeInitialize`; later init must still match bound pair + fee=0 |
| D63 | Delivery sequencing | **SE-first stack, then hook.** Land §6.0 ERC-4626 SE routes / `vaultTokens` / fees fully and green **before** (or as a merged prerequisite of) the hook package PR. Hook DoD must not claim pass on incomplete SE routes |
| D64 | Uni V4 Single SE DETF coupling | **Fully independent.** This hook package does **not** share product code, TestBases, or deploy helpers with `contracts/vaults/detf/protocols/dexes/uniswap/v4/**`. DETF may later consume SE shares as a leg; **not** a v1 consumer of this hook |
| D65 | Mine loop exhaustion | If no flag-matching salt is found within `HookMinerCreate3.MAX_LOOP` (or same bound spirit), **`deployHook` reverts**. Do not silently return a non-mined address |
| D66 | Dust absorb destination | **Oracle `feeTo` only** (when non-zero). Unrefundable multi-leg residual ≤ `MAX_DUST_WEI` (D50) **must** transfer to Vault Fee Oracle **`feeTo`** (same recipient family as dilution fee mint) when `feeTo != address(0)`. **Forbidden:** SE protocol inventory as absorb destination; hook-held dust as product inventory; alternate destinations without PRD revision. **Zero `feeTo`:** **D71** |
| D67 | Hook base inheritance ban (full) | **No Crane Uni V4 hook base inheritance.** Forbidden: `BaseTokenWrapperHook`, `WstETHHook`, **`BaseHook`**, **`DeltaResolver`**, and any other Crane hook base that would pull settle utilities by inheritance. **Pattern-copy** permissions, init checks, and take/settle/pay paths into Target/Common. Behavioral reference only |
| D68 | RH P0 Morpho Vault V2 pin | **Pin explicit WETH Morpho Vault V2 address before P0 fork DoD.** `ROBINHOOD_MAIN` currently has Morpho Blue + Vault V2 **factory** only — **not** a vault instance. Add a verified live WETH Vault V2 address to `ROBINHOOD_MAIN` (preferred) or IndexedEx constants; P0 fork uses that pin only. Do not discover-at-runtime as the sole DoD path. **Selection criterion: D72** |
| D69 | Exact-out under-delivery | **Revert `Slippage` if delivered out &lt; `amountOut`.** Morpho/4626 rounding shortfall on redeem is **not** absorbable dust. D50 / D66 dust is **leftover input residual only** (excess SE or underlying that cannot be refunded without a second transfer). Never treat under-delivery of user `amountOut` as ≤10 wei dust |
| D70 | `wrapZeroForOne` storage | **Repo storage only.** Set once in ctor from address sort (D62). **Not** a Solidity `immutable` field (unlike Crane `BaseTokenWrapperHook`). No post-deploy setter. **No public product getter (D73)** |
| D71 | Dust absorb when `feeTo == 0` | **Skip absorb.** Mirror Rocket Pool dilution fee mint: if `address(feeOracle.feeTo()) == address(0)`, **do not** transfer residual dust; residual may remain on SE/hook **only** in that edge. **Do not** revert solely because `feeTo` is zero; **do not** burn residual as a substitute; **do not** invent an alternate sink. NatSpec must document skip-when-zero. Dilution fee mint already skips when `feeTo == 0` / `feePct == 0` (Rocket peer) |
| D72 | RH / Base vault pin selection | **Morpho-official / curated WETH Vault V2 only.** Pin addresses from Morpho documentation or Morpho-curated vault lists. **Forbidden** as sole pin criterion: highest-TVL scan, first arbitrary live instance, or runtime discovery. Same spirit for **Base P1** when pinning a vault instance. Factory + infra constants (D47) still required; pin is the **instance** address |
| D73 | `wrapZeroForOne` public surface | **No public getter on product interface.** `IUniswapV4SingleStandardExchangeBufferPricingHook` does **not** expose `wrapZeroForOne()`. Currency order is **Repo-only** (D70); tests assert behavior via pool init + swaps, not a dedicated view. Internal Target/Common may still read Repo |
| D74 | Zero amountIn / amountOut | **Revert on zero.** Hook wrap/unwrap and ERC-4626 SE `previewExchange*` / `exchangeIn` / `exchangeOut` routes **must revert** when `amountIn == 0` or exact-out `amountOut == 0` (prefer a clear amount error; `Slippage` / existing SE errors OK if peer already uses them). **No** no-op success path that returns zero and succeeds |

### 3.1 Clarification lock notes (2026-08-02)

| Topic | Locked answer |
|-------|----------------|
| Empty SE / donation (D48) | **Already exists** on ERC-4626 SE — **do not rework** in §6.0 |
| Currency order (D62 / D70 / D73) | **Ctor address sort → Repo storage only** — fixed for life of hook; not immutable; **no public getter** |
| Deadline (D59) | **`block.timestamp` only** — no skew surface in v1 |
| Namespace (D21 / D58) | **Multi-instance intentional** via different namespaces |
| PR sequencing (D63) | **SE-first**, then hook depends on SE green |
| Interest bar (D25 / D61) | **Strict increase only** — no fixed ratio |
| Test `sqrtPriceX96` (D60) | **1:1 TickMath mid** + `tickSpacing = 60` (D56) |
| Uni V4 DETF (D64) | **Fully independent** product/test surface |
| Dust destination (D50 / D66 / D71) | **Oracle `feeTo` only** when non-zero; **skip absorb if `feeTo == 0`** (Rocket peer) |
| Hook inheritance (D51 / D67) | **No** `BaseTokenWrapperHook` / `BaseHook` / `DeltaResolver` — full pattern-copy |
| RH vault instance (D47 / D68 / D72) | **Pin Morpho-official / curated WETH Vault V2** before P0 fork DoD — not TVL/arbitrary |
| Exact-out shortfall (D69) | **`Slippage` if out &lt; `amountOut`** — dust ≠ under-delivery |
| Zero amounts (D74) | **Revert** on `amountIn == 0` or exact-out `amountOut == 0` — no no-op success |

---

## 4. Architecture

### 4.1 Stack

```text
┌──────────────────────────────────────────────────────────────────┐
│ User / Router                                                    │
│   swap exact-in WETH ↔ SE                                        │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│ Uniswap V4 PoolManager                                           │
│   PoolKey: currency0/1 = {underlying, SE}, fee=0,                │
│            hooks = UniswapV4SingleStandardExchangeBufferPricingHook instance        │
└────────────────────────────┬─────────────────────────────────────┘
                             │ beforeSwap + BeforeSwapDelta
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│ UniswapV4SingleStandardExchangeBufferPricingHook (this package)                     │
│   underlyingCurrency = WETH (example)                            │
│   wrapperCurrency    = SE shares                                 │
│   se                 = IStandardExchangeIn/Out                   │
│                                                                  │
│   wrap:   SE.exchangeIn(underlying → SE)                         │
│   unwrap: SE.exchangeOut(SE → underlying)                        │
│   rate:   SE preview* on underlying legs                         │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│ Standard Exchange (existing DFPkg instance)                      │
│   e.g. ERC4626StandardExchangeDFPkg.deployVault(morphoVault)     │
│   asset() = Morpho V2 shares (for ERC4626 SE)                    │
│   exchangeIn/Out ↔ Morpho deposit/redeem                         │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│ Protocol yield vault (e.g. Morpho Vault V2)                      │
│   asset = WETH; interest → convertToAssets ↑                     │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 Interest / pricing law (normative)

```text
Protocol yield increases claim of protocol vault shares on underlying.
SE holds protocol vault shares; SE share claim on those shares is proportional.

Correct WETH NAV of SE shares:
  WETH = f( SE → protocolVaultShares → protocolVault.previewRedeem / convertToAssets )

Hook MUST obtain that f via SE underlying exchange previews/execution.

Incorrect sole price source:
  SE.convertToAssets(seShares) when SE.asset() == protocol vault shares
  (units are protocol shares; does not revalue Morpho interest into WETH)
```

### 4.3 Swap flows

**Four-route matrix (v1 locked — option A):**

```text
Wrap exact-in:
  amountIn underlying
  → seOut = previewExchangeIn(underlying, amountIn, SE)   // mint fee is dilution (D40); seOut = full user shares
  → take underlying from PoolManager → (prefer) transfer to SE
  → SE.exchangeIn(underlying, amountIn, SE, minSeOut=seOut, recipient=hook, pretransferred=true, deadline)  // tight (D46)
  → settle SE to PoolManager / user per V4 delta rules

Wrap exact-out:
  amountOut SE
  → amountIn = previewExchangeOut(underlying, SE, amountOut)   // tokenOut = SE; mint fees are dilution (not more amountIn)
  → take **exactly amountIn** underlying from PoolManager (D43)
  → SE.exchangeOut(underlying, maxIn=amountIn, SE, amountOut, recipient=hook, pretransferred, deadline)
  → SE spends only amountIn; refund path for pretransferred/interface dust → settle SE

Unwrap exact-out:
  amountOut underlying
  → seIn = previewExchangeOut(SE, underlying, amountOut)   // true exact-out; no exit usage fee (D42)
  → take **exactly seIn** SE from PoolManager (D43)
  → SE.exchangeOut(SE, maxSeIn=seIn, underlying, amountOut, recipient=hook, …)
  → SE burns only seIn; refund path for pretransferred/interface dust → settle underlying

Unwrap exact-in:
  seIn
  → underlyingOut = previewExchangeIn(SE, seIn, underlying)   // no exit usage fee (D42)
  → take SE onto hook
  → SE.exchangeIn(SE, seIn, underlying, minOut=underlyingOut, recipient=hook, …)  // tight bounds (D46); after §6.0 route exists
  → settle underlying
```

**Do not** implement wrap exact-out or unwrap exact-in by re-deriving Morpho/`convertToAssets` math in the hook. If a route is missing on ERC-4626 SE, **fix the SE** (§6.0).

---

## 5. Package surface (normative file plan)

Target layout under `contracts/hooks/uniswap/v4/standardExchange/single/`:

```text
contracts/hooks/uniswap/v4/standardExchange/single/
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md          # this file
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_MOVE_AND_RENAME_PLAN.md

  interfaces/
    IUniswapV4SingleStandardExchangeBufferPricingHook.sol               # marker + public previews + views

  UniswapV4SingleStandardExchangeBufferPricingHookRepo.sol              # Diamond-pattern storage layout (Repo library)
  UniswapV4SingleStandardExchangeBufferPricingHookCommon.sol            # preview helpers (SE calls only), currency order, settlement
  UniswapV4SingleStandardExchangeBufferPricingHookTarget.sol            # IHooks logic (pattern-copy BaseTokenWrapperHook; no inheritance — D51)
  UniswapV4SingleStandardExchangeBufferPricingHook.sol                  # single CREATE3-mined contract (wires Target/Repo)

  UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService.sol   # mine off-chain via HookMinerCreate3 + create3Factory
  # Optional: thin Deployer helper script/contract wrapping FactoryService

  # FORBIDDEN for hook product:
  #   *Facet.sol, *DFPkg.sol, I*DFPkg.sol
```

**Naming lock:** product and primary types use **`UniswapV4SingleStandardExchangeBufferPricingHook`** (not “SEBufferHook” in code).

**Shape lock (D15):** Diamond **storage + Repo library + Target** patterns; **no Facet**, **no DFPkg**, **no** diamond package factory for the hook instance.

### 5.1 Interface sketch (informative)

```solidity
interface IUniswapV4SingleStandardExchangeBufferPricingHook {
    function poolManager() external view returns (IPoolManager);
    function standardExchange() external view returns (address); // SE diamond
    function underlying() external view returns (address);
    function wrapper() external view returns (address); // SE share token = SE address
    // No wrapZeroForOne() — Repo-only (D70 / D73)

    /// @notice Exact-in wrap: underlying in → SE out
    function previewWrap(uint256 underlyingIn) external view returns (uint256 seOut);

    /// @notice Exact-out wrap: SE out → underlying in required
    function previewWrapExactOut(uint256 seOut) external view returns (uint256 underlyingIn);

    /// @notice Exact-in unwrap: SE in → underlying out
    function previewUnwrap(uint256 seIn) external view returns (uint256 underlyingOut);

    /// @notice Exact-out unwrap: underlying out → SE in required
    function previewUnwrapExactOut(uint256 underlyingOut) external view returns (uint256 seIn);
}
```

All preview functions are **public / permissionless** (D32). Implementations **must** delegate to SE `previewExchangeIn` / `previewExchangeOut` only. **Zero inputs revert (D74)** on previews and execute paths (hook + SE).

### 5.2 Deploy API (FactoryService — no DFPkg)

```solidity
// UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService (library on create3Factory — D20)
// internal helpers; call path: scripts/tests with create3Factory owner/operator
// Default namespace when saltNamespace is empty: "uv4-single-se-buffer-pricing-hook-" (D21)
// NOT on IndexedexManager; NOT vault registry / deployPkg
function deployHook(
    ICreate3FactoryProxy create3Factory,
    IPoolManager poolManager,
    address standardExchange,
    address underlying
) internal returns (address hook);

function deployHook(
    ICreate3FactoryProxy create3Factory,
    IPoolManager poolManager,
    address standardExchange,
    address underlying,
    string memory saltNamespace // empty → default D21
) internal returns (address hook);
// CREATE3 ctor / immutable + Repo init: (poolManager, standardExchange, underlying)
// Ctor also sets wrapZeroForOne in Repo from address sort (D62 / D70); no deadline skew stored (D59)
// Idempotent + collision (D37): per (namespace, binding) — multi-namespace multi-instance (D58)
```

**Ctor / deploy validation (D36):**

1. Non-zero `poolManager`, `standardExchange`, `underlying`.  
2. **`underlying` is a member of `IBasicVault(standardExchange).vaultTokens()`** (requires working `vaultTokens` — §6.0.B).  
3. **Do not** require `previewExchangeIn` / `previewExchangeOut` to succeed at deploy (empty SE / zero reserves allowed — D48).  
4. `Hooks.validateHookPermissions(this, …)` for BaseTokenWrapperHook flags.  
5. Set **`wrapZeroForOne` in Repo** from address sort of `underlying` vs `address(SE)` (D62 / D70) — not an immutable.

**Salt (D32) — binding-aware mine + EfficientHash (locked):**

Canonical encode lives in **`UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService`** only (everyone deploys through it):

```solidity
// using BetterEfficientHashLib for bytes;
// DEFAULT_SALT_NAMESPACE = "uv4-single-se-buffer-pricing-hook-"

function hookSalt(
    string memory namespace, // empty → DEFAULT_SALT_NAMESPACE
    address poolManager,
    address standardExchange,
    address underlying,
    uint256 mineNonce
) internal pure returns (bytes32) {
    if (bytes(namespace).length == 0) namespace = DEFAULT_SALT_NAMESPACE;
    return abi.encodePacked(namespace, poolManager, standardExchange, underlying, mineNonce)._hash();
}
```

Mine / deploy loop:

```text
namespace = saltNamespace if non-empty else "uv4-single-se-buffer-pricing-hook-"
// Different namespace ⇒ different salt stream ⇒ multi-instance for same (pm, se, underlying) is intentional (D58)

for mineNonce = 0 .. MAX_LOOP:   // same bound spirit as HookMinerCreate3.MAX_LOOP
  salt = FactoryService.hookSalt(namespace, poolManager, se, underlying, mineNonce)
  predicted = HookMinerCreate3.computeAddress(create3Factory, uint256(salt))
             // deployer MUST be address(create3Factory)
  if (uint160(predicted) & FLAG_MASK) != requiredFlags: continue

  if predicted.code.length == 0:
      create3Factory.create3WithArgs(hookCreationCode, abi.encode(pm, se, underlying), salt)
      // ctor sets immutables + wrapZeroForOne in Repo from address sort (D62 / D70); deadline not stored (D59)
      return predicted

  // occupied at first flag-matching salt for this (namespace, binding)
  if isExpectedHook(predicted, poolManager, standardExchange, underlying):
      return predicted   // idempotent same namespace + binding (D37)
  else:
      revert             // collision / wrong product — do not mine past this salt

// if loop ends with no valid salt: revert (D65)
```

**`isExpectedHook` (D37 + D53):** address has code; readable views `poolManager()`, `standardExchange()`, `underlying()` **equal** the deploy args. **Views only** — no interface-id, package marker, or creation-code hash requirement. Wrong / non-matching views or non-expected product ⇒ **revert**.

**Why not bare `HookMinerCreate3.find` / `findWithPrefix`:** those APIs hash only `(i)` or `(saltPrefix, i)` and require `code.length == 0`, so a second `deployHook` for the **same** binding would skip the live address and return a **new** salt — violating D37. Use `computeAddress` + FactoryService `hookSalt` loop. `findWithPrefix` is the **hash style peer** (`encodePacked(...)._hash()`), not the product entrypoint.
### 5.3 Storage (Repo)

| Field | Purpose |
|-------|---------|
| `poolManager` | V4 singleton (**ctor immutable** — D29) |
| `standardExchange` | Bound SE (**ctor immutable**) |
| `underlying` | Bound underlying ERC-20 (**ctor immutable**) |
| `wrapZeroForOne` | Currency order flag — **Repo storage only (D70 / D73)**; set once in ctor from address sort (D62); **not** Solidity `immutable`; **not** a public product getter; not post-deploy mutable |
| deadline skew | **Not in v1** (D59) — SE calls use `block.timestamp` only |

### 5.4 Hook permissions

Match `BaseTokenWrapperHook`:

| Permission | Enabled |
|------------|---------|
| beforeInitialize | Yes — validate pair + fee=0 |
| beforeAddLiquidity | Yes — revert |
| beforeSwap | Yes |
| beforeSwapReturnDelta | Yes |
| after* / donate | No (v1) |

Hook address **must** be mined so LSB flags match.

---

## 6. SE integration contract (normative)

### 6.0 MANDATORY: ERC-4626 Standard Exchange fixes (in scope of this PRD)

> **Implementor directive:** Completing this hook package **requires** fixing the generic ERC-4626 SE under `contracts/vaults/standard/erc4626/`. Do **not** ship a Morpho-specific SE. Do **not** paper over missing routes with hook-local protocol math. Treat the following as **hard DoD** for the hook program of work.

**Why:** The hook must use **only** `IStandardExchangeIn` / `IStandardExchangeOut`. Interface law already defines wrap exact-out as Out with **`tokenOut = SE`**. Today’s ERC-4626 Out Target implements **exit-only** routes (`tokenIn` forced to SE) and therefore **reverts** on wrap exact-out. Exact-in unwrap preview is also incomplete. `vaultTokens()` must be a normal basic-vault facet surface with storage initialized for the protocol vault and its `asset()`.

#### 6.0.A Route matrix the ERC-4626 SE must support

| User intent | SE API (normative) | Current ERC-4626 status (as of PRD audit) | Required fix |
|-------------|-------------------|-------------------------------------------|--------------|
| Wrap exact-in | `previewExchangeIn(underlying, amountIn, SE)` + `exchangeIn` | Implemented | Keep; **fees in preview if any**; tests |
| **Wrap exact-out** | **`previewExchangeOut(underlying, SE, amountOut)` + `exchangeOut`** where **`tokenOut = address(SE)`** | **Missing** — Out requires `tokenIn == SE` and only exits | **Must implement** |
| **protocolVault → SE exact-out** | **`previewExchangeOut(protocolVault, SE, amountOut)` + `exchangeOut`** | **Missing** | **Must implement** (same PR as wrap exact-out) |
| Unwrap exact-out | `previewExchangeOut(SE, underlying, amountOut)` + `exchangeOut` | Present but often burns **all** `maxAmountIn` | **Must** true exact-out (D38) |
| Unwrap exact-in | `previewExchangeIn(SE, seIn, underlying)` + `exchangeIn` | **Missing** public exact-in exit quote | **Must implement** |

**Wrap exact-out interface law (locked):**

```text
// Exact SE shares out; spend up to maxAmountIn underlying
previewExchangeOut(tokenIn=underlying, tokenOut=SE, amountOut=seDesired) → underlyingIn
exchangeOut(underlying, maxUnderlyingIn, SE, seDesired, recipient, pretransferred, deadline) → underlyingSpent
// amountSpent <= maxUnderlyingIn; excess pretransferred/pulled is REFUNDED
```

This is **not** optional product inventiveness — it is what `IStandardExchangeOut` means when `tokenOut` is the SE share token. Peer SEs already implement “external token → `tokenOut == address(this)`”. ERC-4626 SE **must** match that contract.

**Exact-out spend / burn / refund law (D38 + D50 + D66 + D69 + D71 + D74 — all Out routes, locked):**

```text
0. require amountOut > 0 (and amountIn paths amountIn > 0) else revert (D74)
1. amountIn = preview path for exact amountOut   // (or shared internal calc)
2. require amountIn <= maxAmountIn else Slippage
3. consume ONLY amountIn (burn SE or take underlying/vault tokens)
4. execute so user/recipient receives amountOut in full; if delivered out < amountOut → revert Slippage (D69)
5. refund any refundable excess: pretransferred surplus, or do not pull more than amountIn
6. if multi-leg math leaves residual ≤ MAX_DUST_WEI (10) that cannot be refunded without a second transfer:
     if feeTo != address(0): absorb to oracle feeTo ONLY (D50 / D55 / D66)
     if feeTo == address(0): skip absorb (D71) — residual may remain only in this edge
     document MAX_DUST_WEI + feeTo + skip-when-zero in NatSpec
7. return amountIn
```

**Forbidden (current bug pattern):** set `amountIn = maxAmountIn` and burn/spend the entire max while treating `amountOut` as a floor only.

**Forbidden (D50 / D66 / D69 / D71 / D74):** leave unrefundable dust as silent idle product inventory when `feeTo` is non-zero; **or** absorb dust to SE “protocol inventory” instead of `feeTo`; **or** force a second user-facing transfer solely to refund ≤ 10 wei; **or** silently absorb residual **> `MAX_DUST_WEI`**; **or** treat under-delivery of `amountOut` as dust; **or** burn residual as a substitute when `feeTo == 0`; **or** accept zero `amountIn` / `amountOut` as a successful no-op.

**Implementation sketch for wrap exact-out on ERC-4626 SE (informative, not hook-side):**

1. Invert SE share mint math → protocol-vault share delta needed for **`amountOut` user SE** (full user amount — D40, no fee skim).  
2. `amountIn = protocolVault.previewMint(vaultDelta)` (interest-aware) for **that user claim only** — usage fee does **not** increase `amountIn`.  
3. Execute: pull/pretransfer underlying → deposit protocol vault into SE → **`_mint(recipient, amountOut)`** + **`_mint(feeTo, feeShares)`** (D40 dilution); spend only `amountIn`; **refund rest**.  
4. `previewExchangeOut` returns the same `amountIn` as execute; user receipt remains `amountOut`; fee mint is parallel supply expansion.

**protocolVault → SE exact-out:** same SE mint inverse without underlying deposit (vault tokens already or pretransferred); still exact-out + refund + D40 fee mint.

**Unwrap exact-in:** expose `previewExchangeIn(SE, seIn, underlying)` using existing internal pro-rata + `previewRedeem` (today `_previewRedeemShares` is internal-only). Execute via `exchangeIn`; **no exit usage fee** (D42).

**`pretransferred` on Out:** implement per interface NatSpec — use pretransferred balance, consume `amountIn`, **refund excess** to caller. Today ERC-4626 Out **ignores** `pretransferred` and burns from `msg.sender` only; fix as part of §6.0.

**Fees (D24 / D24a / D40 / D40a / D57) — dilution mint (locked):**

```text
// On routes that mint SE shares to the user (wrap exact-in, wrap exact-out user amount, protocolVault→SE mint):
userShares = full shares due from exchange math (deposit / mint inverse)   // NO fee deduction
feeWad     = VaultFeeOracle.usageFeeOfVault(SE)                            // WAD (D40a)
feeShares  = BetterMath._percentageOfWAD(userShares, feeWad)               // Rocket Pool peer only

// Execute:
_mint(user / recipient, userShares)     // full amount due — NEVER reduced by fee
_mint(feeTo, feeShares)                 // expand total supply by fee amount
// Existing holders are diluted; user is not skimmed.
```

| Rule | Law |
|------|-----|
| Shape | **Dilution** — fee expands supply; does **not** reduce user shares |
| Fee base | **Percentage of user shares due** (not of underlying, not of residual after skim) |
| Fee unit | **WAD + `BetterMath._percentageOfWAD` only** (D40a / D57). **Not** Aave Stata `FEE_DENOMINATOR` |
| Recipient | Oracle `feeTo` (same as peers); **skip fee mint if `feeTo == 0` / `feePct == 0` / `feeShares == 0`** (Rocket peer; aligned with D71) |
| Forbidden | Deduct fee from `userShares` then mint remainder to user |
| Preview | Must model the same mint + fee mint so state-affecting paths stay consistent; **returned amount to user remains full `userShares`** (preview return == user receipt) |
| Exact-out wrap | User still receives exact `amountOut` SE; fee is **extra** mint to `feeTo` (underlying in covers user’s vault claim only) |
| Exit / unwrap routes (D42) | **No usage fee in v1.** Full calculated out to user; **no** user skim; **do not** mint exit dilution fees. Applies to SE→underlying and SE→protocolVault exits |
| Mint-route scope | Dilution usage fee on: wrap exact-in, wrap exact-out, protocolVault→SE mint. Not on exits |
| Zero amounts (D74) | **Revert** if `amountIn == 0` or exact-out `amountOut == 0` on SE routes (and hook passthroughs) |
| Tests (D24a) | Non-zero oracle usage fee on **mint** paths; user out == full due; `feeTo` balance ↑ by `feeShares`; totalSupply ↑ by userShares + feeShares; preview == execution. Exit paths: assert **no** fee mint / no skim under same oracle fee config |

**Audit note:** DFPkg already wires fee oracle storage, but ERC-4626 In/Out **do not** apply `usageFeeOfVault` today — implement D40 as part of §6.0.

**Dust (D38 + D50 + D55 + D66 + D69 + D71):**

| Residual kind | Law |
|---------------|-----|
| Refundable surplus (pretransferred excess, overshoot of calculated `amountIn`) | **Refund to caller** (D38) |
| Unrefundable multi-leg residual ≤ **`MAX_DUST_WEI = 10`** (would need second transfer), `feeTo != 0` | **Absorb to oracle `feeTo` only (D50 / D66)**; NatSpec documents `MAX_DUST_WEI` + `feeTo` |
| Same residual, **`feeTo == address(0)`** | **Skip absorb (D71)** — residual may remain only in this edge; do not burn; do not revert solely for zero `feeTo` |
| Unrefundable residual **> 10 wei** | **Not** silent absorb — fix route math or revert |
| Delivered out &lt; `amountOut` (rounding shortfall) | **`Slippage` revert (D69)** — not dust absorb |
| SE protocol inventory as dust sink | **Forbidden (D66)** |
| Hook product inventory | **Forbidden** when `feeTo` non-zero — hook is thin; does not keep dust as product |

**NatSpec:** Out Target must no longer be titled “exit routes only.”

#### 6.0.B `vaultTokens()` + Target/Facet split (mandatory — D41, ERC-4626-focused)

**Problem:** ERC-4626 SE must expose `vaultTokens()` through the standard multi-asset basic vault surface and **initialize** storage so declared tokens are:

1. **`protocolVault`** — the wrapped ERC-4626 vault (Morpho Vault V2, sfrxETH, Stata, etc.)  
2. **`protocolVault.asset()`** — the underlying / loan token (e.g. WETH)

**Why Targets (locked, not optional polish):** Crane law — **domain-specific functions live on Targets; Facets only implement `IFacet`** (name / interfaces / funcs / metadata) and inherit the Target. Same as `BasicVaultFacet is BasicVaultTarget, IFacet`. Multi-asset facets currently embed domain logic inline; that is out of compliance for this workstream where ERC-4626 needs the surface.

As of this PRD, `MultiAssetBasicVaultFacet` and `MultiAssetStandardVaultFacet` implement domain logic **inline** — there is **no** standalone `MultiAssetBasicVaultTarget` / `MultiAssetStandardVaultTarget`.

| Item | Law |
|------|-----|
| Extract Targets | **Must** create `MultiAssetBasicVaultTarget` and `MultiAssetStandardVaultTarget` with domain functions (Repo-backed): `vaultTokens`, `reserveOfToken`, `reserves`, `vaultConfig`, fee/type getters, etc. — **as required** for ERC-4626 SE + shared facet consumers to compile and pass required regressions |
| Facets = IFacet only | `MultiAssetBasicVaultFacet is MultiAssetBasicVaultTarget, IFacet` (and same for Standard). Facet body: **only** `IFacet` surface — no duplicated domain implementations |
| Blast radius (D41 + D54) | **ERC-4626-focused only.** Extract/split shared MultiAsset facets so ERC-4626 gets the surface. **Regression floor:** compile green + **ERC-4626 SE suite only**. Peer packages that cut these facets must **compile**; full peer SE suites are **not** required. **Do not** drive-by rewrite Camelot/Aero/other SE domain logic |
| ERC-4626 SE (**is** a diamond DFPkg) | Package **`facetCuts()` must cut** `MultiAssetBasicVaultFacet` **and** `MultiAssetStandardVaultFacet` into the **proxy the package deploys** (peer Camelot pattern). Register `IBasicVault` / `IStandardVault` in `facetInterfaces()`. If `MULTI_ASSET_STANDARD_VAULT_FACET` is stored on the DFPkg but omitted from cuts, **fix that gap**. |
| Storage init | In `initAccount`, `MultiAssetBasicVaultRepo._initialize` with **`[protocolVault, protocolVault.asset()]`** (both required; order may follow peer convention). |
| Correctness | After deploy, `IBasicVault(se).vaultTokens()` returns wrapped ERC-4626 vault **and** `asset()`. Hook deploy validation (D36) depends on this. |
| Hook instance | **Not a diamond** — **no** facet cuts on the hook. Hook does **not** inherit MultiAsset vault Targets and does **not** expose `vaultTokens`; it **reads** `IBasicVault(standardExchange).vaultTokens()`. Hook remains Repo + Target + single CREATE3 contract (D15). |
| Tests | Hermetic + fork: membership asserts on ERC-4626 SE; hook TestBase relies on fixed SE. |

**Anti-patterns:**

- One-off `vaultTokens` on marker facet without standard Target/Repo.  
- Storage init without **cutting** the Facet that exposes the selectors on the **SE proxy**.  
- Putting MultiAsset vault Targets on the **hook** (wrong product / wrong storage).  
- Leaving domain logic on Facets “because it already works” when extracting Targets for this path — **forbidden** under D41.  
- Full peer SE product rewrites “while we’re here” — **out of scope** (D41 blast radius).
#### 6.0.C SE fix DoD (must pass before / with hook DoD)

1. Wrap exact-out: `previewExchangeOut(underlying, SE, seOut)` / `exchangeOut` — **spent amount == preview**; refundable excess refunded; D50/D66 absorb if unrefundable multi-leg dust and `feeTo != 0`; **D71** skip if `feeTo == 0`.  
2. protocolVault → SE exact-out: same fidelity.  
3. Unwrap exact-out: **amountIn calculated**, only that burned, refundable excess refunded; D50/D71 if needed; preview == execution.  
4. Unwrap exact-in: `previewExchangeIn(SE, seIn, underlying) == exchangeIn(...)` out.  
5. **Fees in all previews** that apply on execute (D24); fix any fee/preview skew.  
6. **Vault Fee Oracle usage fee set non-zero** in tests (D24a); preview == execution under that fee.  
7. Existing wrap exact-in still passes; interest increases WETH claim.  
8. `vaultTokens()` via **cut** standard facets on SE proxy returns **protocol vault + asset()**; Targets extracted + Facets inherit.  
9. Production-first SE tests (hermetic + retain/extend sfrxETH/Morpho coverage).  
10. No Morpho-only SE package for this PRD.  
11. **Do not** rework first-deposit / donation-inflation protection (D48) — already shipped SE law.  
12. **Zero amounts (D74):** `amountIn == 0` / exact-out `amountOut == 0` revert on SE routes.  

### 6.1 Required SE capabilities (any bound SE, v1)

Bound SE **must**:

1. Implement `IStandardExchangeIn` and `IStandardExchangeOut`.  
2. Support **underlying → SE** exact-in **and** exact-out (`tokenOut = SE`).  
3. Support **SE → underlying** exact-out **and** exact-in.  
4. For ERC-4626 family: **protocolVault → SE** exact-out as well (**SE completeness only** — D44; not a hook path).  
5. List **underlying** among `vaultTokens()` (and declare protocol vault where applicable).  
6. Preview == execution on those routes; **previews always include fees** where fees apply (D24); **exit routes have no usage fee** (D42).  
7. Exact-out: compute amountIn, consume only that, **refund refundable rest** (D38); **unrefundable dust ≤ `MAX_DUST_WEI` (10) → oracle `feeTo` only when non-zero** (D50 / D55 / D66); **skip if `feeTo == 0` (D71)**; **out &lt; amountOut → Slippage** (D69).  
8. For ERC-4626 SE consumers: `protocolVault.asset() == underlying` when applicable — not required of every SE family.  
9. **Zero amounts (D74):** revert on zero `amountIn` / exact-out zero `amountOut`.
### 6.2 First-class consumer: ERC-4626 SE + Morpho V2

| Step | Action |
|------|--------|
| 0 | **Apply §6.0 SE fixes** (routes + `vaultTokens` facets/storage) |
| 1 | Deploy/configure Morpho Vault V2 with `asset = WETH` |
| 2 | `ERC4626StandardExchangeDFPkg.deployVault(morphoVault)` |
| 3 | Assert `vaultTokens()` contains Morpho vault + WETH |
| 4 | FactoryService: `HookMinerCreate3` + `create3Factory.create3*` for `(se, WETH)` |
| 5 | **External** script/caller initializes V4 pool `{WETH, SE}` fee=0 `hooks=hook` |

### 6.3 Approvals / custody (locked D31 / D43 / D46)

- **No Permit2** on hook paths in v1.  
- Prefer **`pretransferred = true`** when the SE path supports it (especially wrap: underlying on SE before `exchangeIn` / wrap exact-out `exchangeOut`).  
- `recipient` = hook (or documented settle target); then settle to PoolManager per V4 delta rules.  
- **`deadline = block.timestamp` only (D59)** — no Repo skew.  
- **Exact-out take (D43):** hook takes **exactly** SE-previewed `amountIn` from PoolManager (not a larger max with refund-as-primary).  
- **SE call bounds (D46):** `minOut` / `maxIn` **= previewed amounts** (tight); no hook-side slippage buffer; outer router owns user slippage.  
- Exact-out: SE refund path is for **refundable** `pretransferred` / pull surplus; **unrefundable multi-leg dust ≤ `MAX_DUST_WEI` (10) → oracle `feeTo` only when non-zero (D50 / D55 / D66)**; **skip absorb if `feeTo == 0` (D71)**; **under-delivery of `amountOut` reverts Slippage (D69)**; hook settles only net amounts required by V4 deltas.  
- **Zero amounts (D74):** hook and SE routes revert on zero `amountIn` / exact-out zero `amountOut`.  
- Unwrap after §6.0 Out fix: prefer pretransfer SE when Out consumes pretransferred balance and refunds excess SE; until then follow burn-from-caller semantics.  
- Exact take/settle order must **match** Crane `BaseTokenWrapperHook` / `DeltaResolver` **patterns** (D51 / D67 — full pattern-copy; **no** inheritance of `BaseTokenWrapperHook`, `BaseHook`, or `DeltaResolver`).  
- Reentrancy: SE locks + V4 unlock rules; hook must not re-enter PoolManager unsafely.
---

## 7. Pricing API mapping

| User intent | SE API | Notes |
|-------------|--------|--------|
| Quote wrap exact-in WETH → SE | `previewExchangeIn(WETH, amountIn, SE)` | Morpho interest in `previewDeposit` inside SE |
| Execute wrap exact-in | `exchangeIn(...)` | |
| Quote wrap exact-out SE amount | **`previewExchangeOut(WETH, SE, seOut)`** | **`tokenOut = SE`**; `amountIn` for full user `seOut` (D40 — fee is extra mint, not more underlying) |
| Execute wrap exact-out | **`exchangeOut(WETH, maxIn, SE, seOut, …)`** | spend only previewed in; refund excess; mint fee to `feeTo` |
| Quote unwrap exact-out | `previewExchangeOut(SE, WETH, amountOut)` | true exact-out; **no exit usage fee (D42)** |
| Execute unwrap exact-out | `exchangeOut(SE, maxSeIn=preview, WETH, amountOut, …)` | burn only amountIn; tight max (D46); refundable surplus refunded; unrefundable dust → oracle feeTo when non-zero (D50/D66); skip if feeTo=0 (D71); out shortfall → Slippage (D69); zero amountOut reverts (D74) |
| Quote unwrap exact-in | **`previewExchangeIn(SE, seIn, WETH)`** | §6.0.A — no hook-side pro-rata; no exit usage fee |
| Execute unwrap exact-in | **`exchangeIn(SE, seIn, WETH, minOut=preview, …)`** | tight minOut (D46) |

Hook public helpers map 1:1:

| Hook view | SE call |
|-----------|---------|
| `previewWrap` | `previewExchangeIn(underlying, …, SE)` |
| `previewWrapExactOut` | `previewExchangeOut(underlying, SE, …)` |
| `previewUnwrap` | `previewExchangeIn(SE, …, underlying)` |
| `previewUnwrapExactOut` | `previewExchangeOut(SE, underlying, …)` |

All hook previews are pure SE preview passthroughs. Usage fee on mint is **dilution (D40)** — user-facing returned amounts are full due; fee expands supply separately.

**Invariant (tests):**

```text
After pure Morpho interest (no new SE mints) — real accrual only (D52):
  previewUnwrap(seAmount) **strictly increases** in underlying terms (D61) — no fixed ratio.
  preview == execution on all four routes (fees included; D40a WAD math).
  exact-out routes refund refundable excess; never burn full maxAmountIn by default.
  unrefundable multi-leg residual (if any) ≤ MAX_DUST_WEI (10) absorbed to oracle feeTo only when feeTo != 0 (D50/D55/D66); skip if feeTo == 0 (D71).
  exact-out under-delivery of amountOut → Slippage (D69); not dust.
  zero amountIn / amountOut → revert (D74); no no-op success.
```

---

## 8. Deployment model

### 8.1 CREATE3 factory (locked — reuse existing)

| Requirement | Law |
|-------------|-----|
| Which factory? | **Existing** Crane/IndexedEx **`create3Factory`** (`ICreate3Factory` / `ICreate3FactoryProxy`) already used for facets |
| New CREATE3 factory for hooks? | **No** — do not deploy a second CREATE3 singleton |
| Hook instance path | **FactoryService binding-aware mine loop** (`hookSalt` + `HookMinerCreate3.computeAddress` + create3) — **not** bare `HookMinerCreate3.find` / `findWithPrefix` (D32 / D37). Then `create3Factory.create3` / `create3WithArgs` with the mined salt |
| Access control | Same as facets: **`onlyOwnerOrOperator`** on `create3` / `create3WithArgs` |
| Diamond package factory for hook instance? | **Out of scope for v1** (see §8.5; mineNonce diamond is fallback only, not default) |
| Vault registry | **Not** used for hooks |

```text
┌────────────────────────────────────────────────────────────┐
│ Existing create3Factory (ecosystem singleton / test base)  │
│   • deploy facets (today)                                  │
│   • deploy UniswapV4SingleStandardExchangeBufferPricingHook instances (this)  │
│   • HookMinerCreate3.deployer == address(create3Factory)    │
└────────────────────────────────────────────────────────────┘
```

### 8.2 FactoryService / package helper (not a new factory)

| Layer | Path | Deploys |
|-------|------|---------|
| Hook implementation bytecode | Via **existing** `create3Factory` + **mined** salt | One contract per (SE, underlying) [+ ctor immutables] |
| Typed helpers | `UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService` | **Internal library** on create3Factory (D20); mines salt, calls `create3Factory`, labels, returns hook |
| Optional deploy helper | script wrapping `deployHook` | Mines + create3 only; **does not** require `DiamondPackageCallBackFactory.deploy`; **not** a DFPkg; **not** IndexedexManager / vault registry |

Salt **namespace** (D19): never reuse plain `abi.encode(type(X).name)._hash()` style facet salts for hooks.

### 8.3 What “mined address” means (Uniswap V4)

Uniswap V4 does **not** read a permissions bitfield from storage. It decides which hook callbacks to invoke by inspecting the **least significant bits of the hook contract address** itself (`Hooks.sol`):

```text
Example: address ending such that bits encode:
  BEFORE_INITIALIZE | BEFORE_ADD_LIQUIDITY | BEFORE_SWAP | BEFORE_SWAP_RETURNS_DELTA
```

If those bits are wrong, PoolManager **never calls** your `beforeSwap` (or reverts at init with `HookAddressNotValid`). The logic can be perfect and still be a no-op.

**Mining** = search for a CREATE2/CREATE3 **salt** such that:

```text
deployedAddress = CREATE3(factory, salt, initCode)
(deployedAddress & ALL_HOOK_MASK) == requiredFlags
```

Crane provides miners under Uni V4 utils (`HookMiner` / related). Required flags for this product match `BaseTokenWrapperHook` permissions (see §5.4).

### 8.4 Relation to usual Diamond process

| Piece | v1 law |
|-------|--------|
| Facet CREATE3 on existing factory | Unchanged for other products; **hook instance is not a multi-facet diamond** |
| `DiamondPackageCallBackFactory.deploy` for hook instance | **Not used in v1** (awkward salt; package address in salt) |
| Hook instance | **Single contract** at CREATE3 address with mined flags on **existing** `create3Factory` |

Failure to mine the **instance** address = broken pool / silent missing callbacks.

### 8.5 How address mining works (implementation law)

#### Why V4 cares about the address

PoolManager inspects **only** the low **14 bits** of `PoolKey.hooks`:

```text
address hooks = 0x....XXXX
                  └── 14 flag bits (Hooks.ALL_HOOK_MASK)

BEFORE_INITIALIZE            = 1 << 13
BEFORE_ADD_LIQUIDITY         = 1 << 11
BEFORE_SWAP                  = 1 << 7
BEFORE_SWAP_RETURNS_DELTA    = 1 << 3
... (see lib/crane/.../v4/libraries/Hooks.sol)
```

This product needs the **BaseTokenWrapperHook** set (at minimum):

```text
flags =
    BEFORE_INITIALIZE_FLAG
  | BEFORE_ADD_LIQUIDITY_FLAG
  | BEFORE_SWAP_FLAG
  | BEFORE_SWAP_RETURNS_DELTA_FLAG
```

Constructors should call `Hooks.validateHookPermissions(this, permissions)` so a wrong address **reverts at deploy** instead of failing later.

#### What “mining” is

Search for a **salt** such that the **predicted** create address satisfies:

```text
uint160(predicted) & FLAG_MASK == flags
predicted.code.length == 0   // not already deployed
```

Crane already ships:

| Library | Path | Address formula |
|---------|------|-----------------|
| `HookMiner` | CREATE2 — `hooks/public/utils/HookMiner.sol` (also `v4/utils/HookMiner.sol`) | `addr = f(deployer, salt, keccak(initCode‖ctorArgs))` — **depends on bytecode + ctor** |
| `HookMinerCreate3` | CREATE3 — **`hooks/public/utils/HookMinerCreate3.sol`** (canonical for this product) | `addr = f(deployer, salt)` — **independent of bytecode** (Solmate CREATE3) |

**APIs on `HookMinerCreate3` (verified in Crane):**

| Function | Behavior | Use for this product? |
|----------|----------|------------------------|
| `find(deployer, flags, creationCode, constructorArgs)` | Loop `salt = 0..MAX_LOOP`; require flags + **empty** code; returns `bytes32(salt)` | **No** for product deploy — no binding in salt; empty-only breaks idempotency |
| `findWithPrefix(deployer, flags, …, saltPrefix)` | `salt = hash(saltPrefix ‖ i)`; flags + **empty** code | **No** as sole miner — same empty-only issue; prefix alone is not full binding law |
| `computeAddress(deployer, salt)` | `CREATE3.getDeployed(salt, deployer)` | **Yes** — FactoryService binding-aware loop (D32) |

Loop bound: `MAX_LOOP ≈ 160_444` (enough; 14 free bits ⇒ expected tries ~2^14).

#### CREATE2 vs CREATE3 mining

```text
CREATE2 (HookMiner / DiamondPackageCallBackFactory proxies):
  addr = keccak256(0xff ‖ deployer ‖ salt ‖ initCodeHash)
  Changing PkgArgs that affect only storage after deploy does NOT change addr
  if initCodeHash is fixed (MinimalDiamondCallBackProxy has fixed PROXY_INIT_HASH).

CREATE3 (HookMinerCreate3 / Crane create3Factory facets):
  addr = CREATE3.getDeployed(salt, deployer)
  Same salt ⇒ same addr regardless of init code — ideal for mining then deploying any payload.
```

#### How our **usual diamond** factory computes the proxy address today

`DiamondPackageCallBackFactory.deploy(pkg, pkgArgs)` (verbatim law from Crane):

```text
innerSalt = pkg.calcSalt(pkgArgs)              // package-controlled (delegatecall adaptor)
// Factory ALWAYS re-hashes with package address:
salt      = keccak256(abi.encode(pkg, innerSalt))
// CREATE2 of fixed MinimalDiamondCallBackProxy (no ctor args):
proxy     = CREATE2(
              deployer     = address(DiamondPackageCallBackFactory),
              initCodeHash = PROXY_INIT_HASH,   // keccak(type(MinimalDiamondCallBackProxy).creationCode)
              salt         = salt
            )
```

Comments in factory: *“We deliberately DO NOT use the pkgArgs in the salt”* (only via whatever `calcSalt` encodes). Package address **is** always in the outer salt.

#### Is package-in-salt “insurmountable” for mining?

**No — not if `calcSalt` can carry free entropy (a mine nonce).**

Proof sketch:

```text
fixed: factory, PROXY_INIT_HASH, pkg address
variable: innerSalt = f(mineNonce)   // package chooses this

for mineNonce = 0 .. ~2^18:
  salt  = keccak256(abi.encode(pkg, innerSalt(mineNonce)))
  proxy = CREATE2_addr(factory, PROXY_INIT_HASH, salt)
  if (uint160(proxy) & FLAG_MASK == requiredFlags) && proxy empty:
      use this mineNonce
```

Including `pkg` in the hash does **not** freeze the low 14 bits; it only changes the hash chain. Varying `innerSalt` still explores ~uniform addresses. Expected tries ≈ \(2^{14}\).

What **is** broken without a free nonce:

```text
calcSalt = keccak256(abi.encode(se, underlying))   // only
// ⇒ at most one candidate address per (pkg, se, underlying)
// ⇒ P(valid flags) ≈ 1/16384  → practically never works
```

So the real constraint is: **content-only calcSalt (no mine entropy) cannot produce valid V4 hook diamonds.** You must either:

1. Add **`mineNonce` (or equivalent salt entropy) to `PkgArgs` / `calcSalt`**, mine it, then call normal `factory.deploy`, **or**
2. **Do not use DiamondPackageCallBackFactory for the hook instance** — use **CREATE3** with a mined salt instead.

Diamond mining is **possible** but **awkward** (nonce plumbing, factory double-hash, diamond overkill for a thin hook). Prefer CREATE3 unless a multi-facet diamond hook is a hard requirement.

#### Diamond path (if we insist)

```text
PkgArgs { se, underlying, mineNonce }
calcSalt(args) = keccak256(abi.encode(se, underlying, mineNonce))  // MUST include mineNonce

// off-chain or in deployHook helper:
mineNonce = findNonce(factory, pkg, flags)
factory.deploy(pkg, abi.encode(PkgArgs({se, underlying, mineNonce})))

// post: require(Hooks.validateHookPermissions(proxy, ...))
```

Facets still CREATE3 as usual. Only the **proxy** is flag-mined CREATE2.

#### Recommended / locked path: existing CREATE3 factory + binding-aware HookMinerCreate3

**Normative (v1):** reuse the **same** `create3Factory` as facets. **No new CREATE3 factory.**

```text
// CREATE3 address = f(deployer = create3Factory, salt) only
// (Solmate CREATE3: intermediate proxy CREATE2, then CREATE child — init code does NOT affect address)

flags = BEFORE_INITIALIZE | BEFORE_ADD_LIQUIDITY | BEFORE_SWAP | BEFORE_SWAP_RETURNS_DELTA
namespace = override or default "uv4-single-se-buffer-pricing-hook-"   // D21

// CRITICAL: deployer must be create3Factory, not the script EOA / test contract
// FactoryService mine loop (D32 / D37) — NOT bare find / findWithPrefix:
// salt encode (option C): BetterEfficientHashLib — only via FactoryService.hookSalt
for mineNonce = 0 .. MAX_LOOP:
  salt = hookSalt(namespace, poolManager, se, underlying, mineNonce)
      // = abi.encodePacked(namespace, pm, se, underlying, mineNonce)._hash()
  predicted = HookMinerCreate3.computeAddress(address(create3Factory), uint256(salt))
  if flags mismatch: continue
  if empty: create3WithArgs(hookCode, abi.encode(pm, se, underlying), salt); return predicted
  if isExpectedHook(predicted, pm, se, underlying): return predicted   // idempotent
  else: revert  // occupied by non-matching code

// Constructor MUST set immutables / Repo + Hooks.validateHookPermissions(this, permissions)
// Pool currencies: underlying + address(se) only (D30)
// Tests MUST: assert address(hook) == predicted && flags match
// Tests MUST: second deployHook same binding returns same address
// Tests MUST: collision with wrong code at predicted address reverts
```

| Concern | DiamondPackageCallBackFactory (not v1 default) | **Existing create3Factory + HookMinerCreate3 (v1 law)** |
|---------|-----------------------------------------------|--------------------------------------------------------|
| Which factory | Package callback factory | **Same create3Factory as facets** |
| New CREATE3 factory? | N/A | **No** |
| Address formula | CREATE2(factory, fixed proxy hash, hash(pkg, calcSalt)) | CREATE3(create3Factory, salt) |
| Free salt control | Only via calcSalt entropy | Direct salt argument |
| Init code affects address? | No (fixed MinimalDiamond proxy) | No (CREATE3 property) |
| Mining library | Custom loop over calcSalt/nonce | **`HookMinerCreate3`** |
| Access control | Package deploy path | **`onlyOwnerOrOperator`** on create3 (same as facets) |
| Salt collisions | Per-pkg content salts | **Namespace required** (D19) |

**“Package” for this product** means FactoryService / deploy helper that:

1. Mines CREATE3 salt for flags with `deployer = create3Factory`  
2. Deploys hook bytecode via **existing** `create3Factory`  
3. Initializes binding (SE, underlying, poolManager) if not all in ctor  
4. Returns hook address  

It does **not** mean a second CREATE3 deployment system, and does **not** route the hook instance through `DiamondPackageCallBackFactory.deploy`.

That is the intentional **exception** to “every product instance is a diamond package proxy,” justified by Uni V4 address-bit law — while **reusing** IndexedEx CREATE3 infrastructure.

#### What is *not* production mining

WstETH hook tests often **etch** bytecode to a hand-built address with flags set (`deployCodeTo` / `vm.etch`). That proves behavior only; **do not** ship etch-based addresses.

#### Exception vs typical deploy (summary)

| Step | Typical SE vault / rate provider | This hook package (**v1 locked**) |
|------|----------------------------------|-------------------------------------|
| CREATE3 factory | Existing `create3Factory` for facets/packages | **Same existing `create3Factory`** — no new factory |
| Instance deploy | `DiamondPackageCallBackFactory.deploy` | **`create3Factory.create3*` + `HookMinerCreate3`** |
| Instance low bits | Don’t care | **Must match V4 flags** |
| Salt source | `hash(pkg, calcSalt(args))` | **Mined CREATE3 salt** (namespaced) |
| Miner deployer | N/A | **`address(create3Factory)` only** |
| Post-deploy check | Optional | **Required:** `validateHookPermissions` |

**Diamond package factory** remains possible with mineNonce (not blocked) but is **not v1 default**.

### 8.6 Integrator pool init (locked)

Package **does not** initialize the Uni V4 pool. After `deployHook`:

1. Integrator builds `PoolKey` with `hooks = hook`, currencies = sort(underlying, SE), `fee = 0`.  
2. Integrator calls PoolManager `initialize`.  
3. Hook `beforeInitialize` reverts if pair/fee invalid.

---

## 9. Security and risk

| Risk | Mitigation |
|------|------------|
| Stale / wrong rate (share-only NAV) | Normative D5; tests for **real** interest accrual (D52) |
| SE usage fee dilutes holders | D40 / D40a dilution mint (WAD); tests: user full shares + feeTo mint; no user skim; skip mint if feeTo=0 (Rocket peer) |
| Unrefundable multi-leg dust | D50 / D55 / D66 absorb to **oracle `feeTo` only** if ≤ `MAX_DUST_WEI` (10) and `feeTo != 0`; **D71** skip if `feeTo == 0`; NatSpec bound; not hook/SE product inventory when recipient exists |
| Exact-out under-delivery | D69 — revert `Slippage`; do not absorb shortfall as dust |
| Zero amounts | D74 — revert; no silent no-op |
| Morpho liquidity / withdraw queue | Execution may revert; slippage params; out must still meet `amountOut` or `Slippage` |
| Reentrancy SE ↔ PM | Locks; checks-effects; follow BaseTokenWrapperHook **settle-order pattern** (D51 / D67, no Crane hook base inheritance) |
| Wrong pool pair | `beforeInitialize` validation |
| Donation / inflation on empty SE | SE first-deposit rules; avoid empty SE in production demos |
| Hook permissions mismatch | Mining + init tests |
| Approval griefing | Exact approve / forceApprove patterns from SE |

---

## 10. Testing requirements (DoD)

### 10.0 ERC-4626 SE fixes (must ship / pass first or in same PR stack)

1. Wrap exact-out + protocolVault→SE exact-out; preview == execution; refund refundable excess; D50/D66 for unrefundable multi-leg dust (≤ `MAX_DUST_WEI` = 10 → oracle `feeTo` when non-zero); **D71** skip when `feeTo == 0`.  
2. Unwrap exact-out: burn **only** calculated amountIn; refund refundable excess; D50/D66/D71 if needed; **out &lt; amountOut → Slippage (D69)**; preview == execution.  
3. Unwrap exact-in: `previewExchangeIn(SE → underlying)` + execute; preview == execution.  
4. **Dilution fee (D24a / D40 / D40a):** non-zero Vault Fee Oracle usage fee on **mint** paths; **`BetterMath._percentageOfWAD`**; user receives **full** shares due; `feeTo` minted `feeShares`; totalSupply ↑ by user + fee; preview == execution; optional zero-fee control.  
5. **Exit fee law (D42):** under same non-zero oracle fee, unwrap paths deliver full calculated out; **no** fee mint / skim on exit.  
6. MultiAsset **Targets** hold domain logic; Facets **IFacet-only** + inherit (D41); ERC-4626 DFPkg **cuts both** Basic+Standard multi-asset facets into SE proxy; `vaultTokens()` = **protocolVault + asset()**. **Regression floor (D54):** compile + ERC-4626 suite only.  
7. Regression: wrap exact-in + **real** interest paths (sfrxETH/Morpho) — D52.  
8. **protocolVault → SE exact-out** covered on SE tests (D44 completeness); not required as hook swap test.  
9. **Zero amounts (D74):** SE routes revert on zero `amountIn` / exact-out zero `amountOut`.
### 10.1 Hermetic (hook)

1. Deploy V4 PoolManager (Crane port).  
2. Deploy Morpho Blue + Vault V2 (prefer real Morpho port).  
3. Deploy ERC4626 SE on that vault (**after** §6.0 fixes).  
4. Assert `vaultTokens()` contains protocol vault + WETH; hook deploy rejects wrong underlying.  
5. Deploy hook via **existing** `create3Factory` + FactoryService library (assert flag bits; D20).  
6. **Idempotent deployHook:** second call returns same address (**D53 views-only** `isExpectedHook`).  
7. Initialize pool **externally** with **`tickSpacing = 60`** (D56) and **1:1 mid `sqrtPriceX96`** (D60); **all four** wrap/unwrap exact-in and exact-out paths (**ERC-4626/Morpho only** — D45).  
8. **Interest test (D52 / D61):** real Morpho supply interest (time + protocol paths only) → `previewUnwrap` **strictly increases**; **no** fixed ratio; **no** claim-growth cheats.  
9. Hook previews == execution on all four routes (± dust ≤ 10 wei); **with Vault Fee Oracle usage fee non-zero** on mint (D24a / D40a); unwrap still full out (D42).  
10. Exact-out: hook took **exactly** previewed `amountIn` (D43); SE bounds tight (D46); SE `deadline = block.timestamp` (D59).  
11. `beforeAddLiquidity` reverts; wrong currency / non-zero fee init reverts.  
12. Same `create3Factory` as facets (no second CREATE3 factory).  
13. Empty SE deploy allowed: hook deploys with zero SE reserves (no preview smoke at deploy; D48 — **do not** rework SE first-deposit protection).  
14. Hook is **full pattern-copy** of BaseTokenWrapperHook behavior — **not** a subclass of `BaseTokenWrapperHook`, `BaseHook`, or `DeltaResolver` (D51 / D67); **`wrapZeroForOne` in Repo only** from ctor address sort (D62 / D70 / D73) — **no public getter**.  
15. **Idempotency + multi-instance:** second `deployHook` same namespace+binding returns same address; different namespace same binding deploys a **second** hook (D58).  
16. **Independence (D64):** no import/coupling to Uni V4 Single SE DETF package paths.  
17. **Dust vs Slippage:** unrefundable input residual ≤ 10 wei → `feeTo` when non-zero (D66); **skip if `feeTo == 0` (D71)**; any exact-out under-delivery → `Slippage` (D69).  
18. **Zero amounts (D74):** hook previews/swaps and SE routes revert on zero amounts.
### 10.2 Fork (v1)

| Priority | Network | Scope |
|----------|---------|--------|
| **P0** | **Robinhood** | Live Morpho Vault V2 + SE + hook smoke; use **existing** RH profile / Morpho **infra** constants (D47); **pinned Morpho-official / curated WETH Morpho Vault V2 address required first (D68 / D72)** — RH uses Vault V2 / no MetaMorpho V1 per `ROBINHOOD_MAIN` |
| **P1** | **Base** | Live Morpho + SE + hook; Base Morpho addresses from **Morpho documentation** (D35 / D72); pin **official/curated** vault instance similarly if not already constant |
### 10.3 Test locations (suggested)

```text
# SE fixes
test/foundry/spec/vaults/standard/erc4626/
  ERC4626StandardExchange_*_Routes.t.sol
  ERC4626StandardExchange_*_VaultTokens.t.sol

# Hook
contracts/test/bases/
  TestBase_UniswapV4SingleStandardExchangeBufferPricingHook.sol  # optional; not required for v1 Deploy/Routes
test/foundry/spec/hooks/uniswap/v4/standardExchange/single/
  UniswapV4SingleStandardExchangeBufferPricingHook_*.t.sol
test/foundry/fork/robinhood_main/.../UniswapV4SingleStandardExchangeBufferPricingHook_*_Fork.t.sol
test/foundry/fork/base_main/.../UniswapV4SingleStandardExchangeBufferPricingHook_*_Fork.t.sol
```

---

## 11. Reuse inventory

| Asset | Reuse how |
|-------|-----------|
| `BaseTokenWrapperHook` | **Behavioral reference only (D51 / D67):** permissions, init pair/fee checks, delta settle order. **Do not inherit** (nor `BaseHook` / `DeltaResolver`). Implement SE exact-in/out + full settle path on Target (D39) |
| `WstETHHook` | Dynamic rate helper shape — reference only; do not subclass |
| `BaseHook` / `DeltaResolver` | **Pattern-copy only (D67)** — take/settle/pay helpers reimplemented in Common/Target; no inheritance |
| `WETHHook` | 1:1 settle mechanics reference |
| `HookMinerCreate3` | **Canonical:** `hooks/public/utils/HookMinerCreate3.sol` — use `computeAddress`; product mine loop in FactoryService (D32) |
| `ERC4626StandardExchange*` | Bound SE for Morpho/sfrxETH/etc. — **fix per §6.0**, do not replace |
| Rocket Pool SE fee path | **Canonical fee unit peer (D40a / D57):** `BetterMath._percentageOfWAD` + `usageFeeOfVault` |
| Peer SE DFPkgs (Camelot, etc.) | Template for **Basic + Standard vault facet cuts** + `IBasicVault` / `vaultTokens` wiring |
| MultiAsset vault Facets (today) | **Extract** Targets with domain logic; Facets **only** `IFacet` + inherit (D41); regression floor **D54** |
| `BetterEfficientHashLib` | Salt encode in FactoryService (`encodePacked(...)._hash()`) — D32 |
| **Existing `create3Factory`** | **Only** CREATE3 deployer for hook instances (same as facets) |
| `HookMinerCreate3` | Mine salts off-chain in FactoryService; `deployer = address(create3Factory)` |
| `TestBase_ERC4626StandardExchange` / Crane Test | SE + create3Factory in tests |
| Crane Morpho TestBases | Hermetic Morpho + **real** interest accrual (D52) |

**New code:** hook Repo/Target/Common + FactoryService + tests; **plus** ERC-4626 SE route/`vaultTokens` fixes. **Not** a new CREATE3 factory, **not** a Morpho-specific SE, **not** hook Facet/DFPkg, **not** Uni V4 DETF shared scaffolding (D64), **not** SE first-deposit rework (D48).

---

## 12. Implementation phases

| Phase | Deliverable |
|-------|-------------|
| **P0** | This PRD + implementation & test plan (hook + SE dependency) |
| **P0.SE** | **ERC-4626 SE fixes (§6.0) — land first (D63):** wrap exact-out + protocolVault→SE exact-out (SE completeness D44); true exact-out burn/refund; unwrap exact-in; **dilution usage fee on mint only (D40/D40a/D42/D57 WAD)**; **D50/D55/D66 dust absorb to oracle `feeTo` only** if residual ≤ `MAX_DUST_WEI` (10) and `feeTo != 0`; **D71 skip if `feeTo == 0`**; **D69 out &lt; amountOut → Slippage**; **D74 zero amounts revert**; extract MultiAsset Targets + Facets **IFacet-only** (D41); **regression floor D54** (compile + ERC-4626 suite); **cut Basic+Standard facets into SE proxy**; init `[protocolVault, asset()]`; **Vault Fee Oracle non-zero usage fee tests** (mint: user full shares + feeTo; exit: no fee); SE tests. **Do not** rework first-deposit / donation protection (D48) |
| **P1** | Hook Repo + Target + Common (**pattern-copy, no BaseTokenWrapperHook inheritance — D51**); ctor immutables + **currency order from address sort into Repo only (D62 / D70 / D73 — no public getter)**; SE calls **`deadline = block.timestamp` (D59)**; FactoryService **library** mine off-chain + **idempotent** `deployHook` (D20 / D53 views-only) + **namespace multi-instance (D58)** + mine exhaustion revert (D65); all four routes via SE only; exact preview take (D43); tight SE bounds (D46); **D74** zero amounts revert. **No** Uni V4 DETF coupling (D64) |
| **P2** | Hermetic hook tests (Morpho/ERC-4626 only — D45): flags; **real** interest **strict increase** (D52 / D61); preview==execution **with oracle usage fee on mint** (WAD); deploy validation; idempotency + multi-namespace instance; pool init **`tickSpacing = 60`** + **1:1 mid sqrtPrice** (D56 / D60); zero-amount reverts (D74) |
| **P3** | Public preview polish / deploy helper DX |
| **P4** | Fork: **Robinhood first** (existing profile + Morpho infra — D47; **pin Morpho-official/curated WETH Vault V2 first — D68 / D72**), then **Base** (Morpho docs / curated vault — D72) |
| **P5** | Optional scripts; still no second CREATE3 factory |

**Stack law (D63):** merge/gate **P0.SE green before** claiming hook P1–P2 DoD complete. SE-first PR stack preferred over a single mixed PR that ships incomplete SE routes.

**Ordering law:** P0.SE is **blocking** for P1 DoD. Hook code may be drafted in parallel but must not claim complete without §6.0 green.

---

## 13. Remaining open questions

**None.** Product law **and** implementor-edge law for this PRD are fully locked.

**Resolved (product lock — 2026-08-02 clarification passes):**

- Exact-in **and** exact-out both ways (option A); external pool init only; any SE + explicit underlying.  
- **Existing create3Factory only**; `HookMinerCreate3`; hook **not** a diamond; **Repo + Target, no Facet/DFPkg**.  
- Wrap exact-out = Out with **`tokenOut = SE`**; protocolVault→SE exact-out **in scope on SE only** (D44 — not a hook path).  
- Exact-out: **calc amountIn, burn/spend only that**; **refund refundable surplus** (D38); **unrefundable multi-leg dust ≤ `MAX_DUST_WEI` (10) → oracle `feeTo` only when non-zero** (D50 / D55 / D66); **skip if `feeTo == 0` (D71)**; **out &lt; amountOut → Slippage** (D69); NatSpec documents constant + destination + skip-when-zero.  
- **Hook exact-out take = exactly previewed amountIn** (D43); SE refund not the primary surplus path.  
- **Hook → SE bounds tight = preview** (D46); outer router owns user slippage.  
- `vaultTokens`: extract MultiAsset Targets; **Facets IFacet-only** (D41); ERC-4626 package **cuts both facets into the SE proxy**; init **protocolVault + asset()** (not on the hook); **regression floor = compile + ERC-4626 suite only** (D54); no drive-by peer SE rewrites.  
- Previews include fee effects on routes that charge; tests **set Vault Fee Oracle usage fee non-zero** (D24a).  
- **Usage fee = dilution mint on mint routes only (D40/D42):** fee % of user shares due; mint fee to `feeTo`; **never deduct from user shares**; **v1 exits: no usage fee**.  
- **Fee unit = WAD + `BetterMath._percentageOfWAD` only** (D40a / D57 — Rocket Pool peer; not Aave Stata `FEE_DENOMINATOR`).  
- **`deployHook` = FactoryService library on create3Factory only** (D20) — not manager/registry.  
- Idempotent `deployHook`; **`isExpectedHook` = views only** (D53); mine off-chain; public previews; fork **RH then Base** (existing RH Morpho **infra** D47; **pin Morpho-official/curated WETH Vault V2 — D68 / D72**; Morpho docs for Base).  
- Hook v1 test matrix: **ERC-4626 / Morpho only** (D45).  
- Deploy: `underlying ∈ vaultTokens()`; no empty-SE preview smoke; empty-SE first-deposit is **already shipped SE law — do not rework** (D48).  
- Prefer pretransferred; **`deadline = block.timestamp` only** (D59); recipient on SE APIs.  
- **Salt (D21/D32/D37/D58):** fields `namespace, pm, se, underlying, mineNonce`; **encode = `abi.encodePacked(...)._hash()` via FactoryService only**; default namespace `"uv4-single-se-buffer-pricing-hook-"` (overridable); **different namespace ⇒ intentional multi-instance** for same binding; same namespace+binding → existing expected hook; wrong occupant **reverts**; mine exhaustion **reverts** (D65).  
- **Hook swap on Target via SE In/Out** (D39); **no Solidity inheritance** of `BaseTokenWrapperHook` / `BaseHook` / `DeltaResolver` — **full pattern-copy only** (D51 / D67).  
- **Canonical miner path:** `hooks/public/utils/HookMinerCreate3.sol` via FactoryService loop (**not** bare `find`).  
- **`wrapZeroForOne` at ctor from address sort → Repo storage only** (D62 / D70); **no public getter (D73)**; Repo has **no** deadline-skew field (D49 / D59).  
- **Interest tests: real accrual only** (D52); DoD bar = **strict increase only** (D61) — no fixed 3→4 ratio.  
- **Test pool:** `tickSpacing = 60` (D56) + **1:1 mid sqrtPrice** (D60); product still does not own tickSpacing/sqrtPrice (D17).  
- **Dust residual (D50 / D55 / D66 / D71):** unrefundable multi-leg dust **≤ 10 wei** absorbed to **oracle `feeTo` only when non-zero**; **skip absorb if `feeTo == 0`**; not second-transfer user refund, not SE inventory as product sink; **> 10 wei** not silent absorb; **under-delivery ≠ dust (D69)**.  
- **Zero amounts (D74):** revert on zero `amountIn` / exact-out zero `amountOut` (hook + SE).  
- **Delivery:** SE-first stack then hook (D63).  
- **Independence:** no Uni V4 Single SE DETF product/test/deploy coupling (D64).

**Resolved (implementor-edge ask pass — 2026-08-02):**

| # | Topic | Lock |
|---|--------|------|
| D40a / D57 | Dilution fee unit | WAD + `BetterMath._percentageOfWAD` (Rocket Pool) |
| D50 / D55 | Dust bound | `MAX_DUST_WEI = 10` hard ceiling |
| D53 | `isExpectedHook` | Views only (pm / se / underlying) |
| D54 | MultiAsset regressions | Compile + ERC-4626 suite only |
| D52 | Interest proof | Real accrual only; no claim-growth cheats |
| D56 | Test tickSpacing | `60` |
| D51 | Hook inheritance | Repo/Target pattern-copy; **no** `BaseTokenWrapperHook` inheritance |

**Resolved (clarification ask pass 2 — 2026-08-02):**

| # | Topic | Lock |
|---|--------|------|
| D48 | First-deposit / donation | Already shipped SE law; **do not rework** in §6.0 |
| D58 | Salt namespace multi-instance | **Intentional** — different namespace ⇒ distinct hooks for same binding |
| D59 | SE deadline | **`block.timestamp` only** — no skew surface |
| D60 | Test sqrtPrice | **1:1 mid** (`TickMath.getSqrtPriceAtTick(0)`) |
| D61 | Interest DoD bar | **Strict increase only** — no fixed ratio |
| D62 | Currency order | **Ctor address sort** — fixed for life (Repo; see D70) |
| D63 | PR sequencing | **SE-first stack**, then hook |
| D64 | Uni V4 DETF | **Fully independent** packages |
| D65 | Mine loop exhaustion | **`deployHook` reverts** if no salt within MAX_LOOP |

**Resolved (clarification ask pass 3 — 2026-08-02):**

| # | Topic | Lock |
|---|--------|------|
| D66 | Dust absorb destination | **Oracle `feeTo` only** — not SE protocol inventory |
| D67 | Hook base inheritance ban | **No** `BaseTokenWrapperHook` / `BaseHook` / `DeltaResolver` — full pattern-copy |
| D68 | RH P0 Morpho vault pin | **Pin explicit WETH Morpho Vault V2** constant before P0 fork DoD |
| D69 | Exact-out under-delivery | **`Slippage` if out &lt; `amountOut`** — dust is input residual only |
| D70 | `wrapZeroForOne` storage | **Repo storage only** — not Solidity immutable |

**Resolved (clarification ask pass 4 — 2026-08-02):**

| # | Topic | Lock |
|---|--------|------|
| D71 | Dust when `feeTo == 0` | **Skip absorb** (Rocket peer fee-mint pattern); residual may remain only in that edge; NatSpec documents |
| D72 | Vault pin selection | **Morpho-official / curated WETH Vault V2 only** — not TVL scan / arbitrary instance; same for Base P1 |
| D73 | `wrapZeroForOne` public surface | **No public getter** on product interface — Repo-only; tests via init/swaps |
| D74 | Zero amounts | **Revert** on zero `amountIn` / exact-out zero `amountOut` (hook + SE); no no-op success |

---

## 14. Success criteria

1. User can swap WETH ↔ SE on a Uni V4 pool (exact-in and exact-out both directions) and end with correct balances.  
2. After **real** Morpho interest (D52), same SE amount quotes and delivers **strictly more** underlying (D61 — no fixed ratio).  
3. Hook deploys via **existing** `create3Factory` + **FactoryService** mined salt (`hookSalt` + `HookMinerCreate3.computeAddress`); **idempotent** redeploy via **views-only** `isExpectedHook` (D53); multi-namespace multi-instance (D58); mine exhaustion reverts (D65); collision reverts if not expected hook; **no** `new` hook in production tests; **no** second CREATE3 factory.  
4. Deployed hook address permission bits match BaseTokenWrapperHook flags (`validateHookPermissions`); hook is **full pattern-copy**, not a subclass of `BaseTokenWrapperHook` / `BaseHook` / `DeltaResolver` (D51 / D67); **`wrapZeroForOne` in Repo only** from ctor address sort (D62 / D70 / D73 — **no public getter**); SE **`deadline = block.timestamp` only** (D59).  
5. Works with **fixed** generic ERC-4626 SE (or any SE meeting §6.1) without Morpho-specific SE package; **no** Uni V4 DETF coupling (D64).  
6. Preview == execution on **all four** routes with **Vault Fee Oracle usage fee non-zero** on mint; hook previews only call SE; **D40 / D40a:** user full shares due + fee mint via **`_percentageOfWAD`** to `feeTo`; **D42:** unwrap full out, no exit fee.  
7. Exact-out never consumes full `maxAmountIn` when less is required; hook takes **exactly** previewed `amountIn` (D43); **refundable** excess refunded; **unrefundable dust ≤ `MAX_DUST_WEI` (10) → oracle `feeTo` only when non-zero** (D50 / D55 / D66); **skip if `feeTo == 0` (D71)**; **out &lt; amountOut → Slippage** (D69).  
8. No CL liquidity; fee=0 pool; init validates pair; tests use **`tickSpacing = 60`** (D56) + **1:1 mid sqrtPrice** (D60).  
9. **ERC-4626 SE (landed first — D63):** wrap exact-out + protocolVault→SE exact-out (SE completeness) + unwrap exact-in; true exact-out burn; MultiAsset Targets + **IFacet-only Facets** (D41); **both vault facets cut into SE proxy**; `vaultTokens()` = protocol vault + `asset()`; regressions **D54**; **no** first-deposit rework (D48); **D74** zero amounts revert.  
10. `deployHook` is create3Factory library only (D20); hermetic/fork matrix Morpho ERC-4626 (D45); RH uses existing Morpho infra constants (D47) **plus pinned Morpho-official/curated WETH Vault V2 (D68 / D72)**.  
11. No open product or implementor-edge questions remain (§13 / §3.1).

---

## Changelog

| Date | Change |
|------|--------|
| 2026-08-03 | **Move + rename under `single/`:** package path `contracts/hooks/uniswap/v4/standardExchange/single/`; product `UniswapV4SingleStandardExchangeBufferPricingHook`; CREATE3 default salt `"uv4-single-se-buffer-pricing-hook-"`; Repo storage id `"indexedex.hooks.uv4.single.se.buffer.pricing.storage"`; Deploy-test override `"uv4-single-se-buffer-pricing-hook-test-"`; dual package untouched (stale dual→single links accepted until dual follow-up). See `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_MOVE_AND_RENAME_PLAN.md`. |
| 2026-08-02 | **Clarification lock (ask pass 4):** D71 dust absorb **skip when `feeTo == 0`** (Rocket peer); D72 vault pin = **Morpho-official / curated only** (not TVL/arbitrary); D73 **no public `wrapZeroForOne()`**; D74 **zero amounts revert** (hook + SE); §3.1 / §5–§7 / §9–§14 aligned |
| 2026-08-02 | **Clarification lock (ask pass 3):** D66 dust → **oracle `feeTo` only**; D67 **no** `BaseHook`/`DeltaResolver` inheritance (full pattern-copy); D68 **pin WETH Morpho Vault V2** before RH P0; D69 exact-out under-delivery → **`Slippage`** (dust ≠ shortfall); D70 **`wrapZeroForOne` Repo-only** (not immutable); §3.1 / §5.3 / §6 / §9–§14 aligned |
| 2026-08-02 | **Implementor-edge ask lock:** D40a/D57 WAD fee unit; D50/D55 `MAX_DUST_WEI=10`; D53 views-only `isExpectedHook`; D54 ERC-4626-only regression floor; D52 real interest accrual only; D56 test `tickSpacing=60`; D51 pattern-copy hook (no `BaseTokenWrapperHook` inheritance); D13/D25/D37/D39/D41/§6–§14 aligned |
| 2026-08-02 | **Lock D50:** unrefundable multi-leg exact-out dust **absorbed** (not second-transfer user refund; not hook inventory); later tightened to `MAX_DUST_WEI=10` and destination **oracle `feeTo` only** (D66) |
| 2026-08-02 | **Clarification lock (ask pass):** D42 exit usage fee none; D41 ERC-4626-focused blast radius; D20 FactoryService library only; D43 exact preview take; D44 protocolVault→SE SE-only; D45 Morpho/4626 test matrix; D46 tight SE bounds; D47 existing RH constants; D48 empty-SE is SE law; D49 optional Repo |
| 2026-08-02 | Initial PRD: UniswapV4SingleStandardExchangeBufferPricingHook package, SE buffer + Morpho-aware pricing, DFPkg layout, reuse inventory |
| 2026-08-02 | Clarifications: mined-address / diamond OK with proxy salt mining; exact-in+out both ways; factory-only registry; any SE + explicit underlying; external pool init |
| 2026-08-02 | §8.5: full address-mining law — CREATE2/CREATE3 miners, diamond factory salt formula, mine-nonce PkgArgs path, etch-not-production |
| 2026-08-02 | Diamond salt includes pkg but mining still possible with mineNonce; **prefer CREATE3 + HookMinerCreate3** over DiamondPackageCallBackFactory for hook instance |
| 2026-08-02 | **Lock:** reuse **existing** create3Factory only; no second CREATE3 factory; namespaced salts; miner deployer = create3Factory |
| 2026-08-02 | **Lock:** ctor/immutables binding; SE address as pool vault token; pretransferred preference, no Permit2 on hook; HookMinerCreate3 salt mine |
| 2026-08-02 | **Lock:** Repo+Target, **no Facet/DFPkg**; full 4-route matrix via SE only; public previews; RH then Base forks; deploy `vaultTokens` check |
| 2026-08-02 | **§6.0 mandatory:** implementors **must** fix ERC-4626 SE — wrap exact-out (`tokenOut=SE`), unwrap exact-in, `pretransferred`/preview fidelity, **`vaultTokens()` via typical facets + init `[protocolVault, asset()]`** |
| 2026-08-02 | **Lock:** exact-out calc amountIn + refund excess (D38); protocolVault→SE exact-out; previews always include fees (D24); idempotent deployHook (D37); MultiAsset Targets extracted + Facets inherit; Base Morpho from Morpho docs; RH then Base |
| 2026-08-02 | **Clarify:** MultiAsset Facets cut into **ERC-4626 SE proxy** (not hook); **D24a** tests must set non-zero **Vault Fee Oracle** usage fee |
| 2026-08-02 | **Lock clarifications:** binding-aware salt + default namespace `"uv4-single-se-buffer-pricing-hook-"` (override OK); D37 collision revert if not expected hook; D39 SE exact-out on Target (later: pattern-copy, no BaseTokenWrapperHook inheritance — D51); correct `HookMinerCreate3` path + use `computeAddress` not bare find/findWithPrefix |
| 2026-08-02 | **Lock:** salt encode option C — `BetterEfficientHashLib` `encodePacked(...)._hash()` **only in FactoryService**; **D40 dilution usage fee** (mint fee extra, never skim user); **D41** MultiAsset domain on Targets, Facets IFacet-only; refund dust |
| 2026-08-02 | **Consistency pass:** wrap exact-out sketch + §7 pricing notes + §10/§14 DoD aligned to D40 dilution (fee does not increase amountIn / does not skim user) |
| 2026-08-02 | **Clarification lock (ask pass 2):** D48 first-deposit already shipped (no §6.0 rework); D58 namespace multi-instance intentional; D59 `deadline = block.timestamp` only; D60 test 1:1 mid sqrtPrice; D61 interest strict increase only; D62 ctor address-sort currency order; D63 SE-first stack; D64 no Uni V4 DETF coupling; D65 mine-loop exhaustion reverts; §8.1 bare-`find` wording fixed to FactoryService mine loop; §3.1 notes table |
