# PRD: Uniswap V4 Dual Standard Exchange Buffer Constant Product Hook

**Name:** `UniswapV4DualStandardExchangeBufferConstantProductHook`  
**Date:** 2026-08-03  
**Status:** **Accepted / plan-ready — v3.12**  
**v3.12 clarity:** SE×CP claim-delta composition (D78); `depositSingle` gate after MINIMUM_LIQUIDITY residual (D79 / C36); `isExpectedHook` factory-only (D80); `DepositSingle.amountIn` = full pull (D81); no product cap on protocol fee WAD (D82); `kLast` overflow = Uni V2-class accepted risk (D83); `dexSwapFee` naming callout; collapsed layered lock tables into canonical D/O/C + revision log.  
**Process:** Not an implementation mandate. A later agent rewrites the implementation plan from this PRD; that plan becomes the implementor source of truth.  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/dual/`  
**Package kind:** IndexedEx **Uniswap V4 Hook Diamond Package** (Option B) — instances deploy via package → vault registry `deployHookVault` → shared **Uniswap V4 Hook Diamond Package Callback Factory** (CREATE2 + `mineNonce`). Registered vault. **Not** monomorph CREATE3 / HookMinerCreate3 for instances (superseded). **Not** a second product CREATE3 factory. **Not** a Uniswap V4 concentrated-liquidity (CL) reimplementation.

> **Deploy law supersession (2026-08):** Instance CREATE3 + HookMinerCreate3 + FactoryService monomorph `deployHook` as production UX, deep `isExpectedHook` as deploy gate, and “not DFPkg/not vault diamond” package-kind statements in this PRD are **superseded** by  
> [`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_HOOK_FACTORY_REFACTOR_PRD.md`](./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_HOOK_FACTORY_REFACTOR_PRD.md)  
> and the implementor plan  
> [`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_HOOK_FACTORY_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_HOOK_FACTORY_IMPLEMENTATION_AND_TEST_PLAN.md).  
> **Product math / D78–D83 / liquidity / fees / Permit2** in this PRD (v3.12) remain normative.

**Sibling package (do not conflate):**  
`contracts/hooks/uniswap/v4/standardExchange/` — **single** SE buffer/pricing hook (`UniswapV4BufferAndPricingHook`): wrapper pool `underlying ↔ SE shares`, **no** dual pair-token AMM, **no** user LP deposit surface.

**Related docs:**

- Implementation & test plan (canonical name after rewrite): [`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md) — **rewrite from this v3.12 PRD**. Until that rewrite, the tree may still hold the **stale** file `UNISWAP_V4_DUAL_BUFFER_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` (non-authoritative; do not implement from it). **Not** worked in this PRD-lock pass.
- CP / zap math peer (normative formula source): `lib/crane/contracts/utils/math/ConstProdUtils.sol` (`_saleQuote`, `_purchaseQuote`, `_swapDepositSaleAmt`, `_calculateProtocolFee` generic path)
- Single SE buffer PRD (peer patterns for mine/settle/FactoryService **and** §6.0 ERC-4626 SE co-deliverable law): `contracts/hooks/uniswap/v4/standardExchange/UNISWAP_V4_BUFFER_AND_PRICING_HOOK_PRD.md`
- Generic ERC-4626 SE package (hard dual-hook prerequisite — D60): `contracts/vaults/standard/erc4626/`
- Crane Uni V4 wrapper base (permissions / settle **semantics only**): `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/base/BaseTokenWrapperHook.sol`
- Peer settle implementation (pattern-copy only, no inheritance): `contracts/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHookTarget.sol` + `…Common.sol`
- Crane HookMiner: `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol`
- SE interfaces (Crane): `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`, `IStandardExchangeOut.sol`; vault tokens: `IBasicVault.vaultTokens()`
- Fee oracle: `contracts/interfaces/IVaultFeeOracleQuery.sol` (WAD fees; 0 = unset → three-tier default)
- Permit2: Uniswap canonical deployment `0x000000000022D473030F116dDEE9F6B43aC78BA3` (same address Crane network constants use on mainnets/L2s)
- IndexedEx AGENTS.md — production-first testing; CREATE3; no mock SUT

**Prerequisite (hard — D60 / D66):** Bound SEs must expose closed-form **pair token ↔ SE** routes for deposit (buffer) and redeem (unwrap). Dual-hook DoD **requires** completing the **generic ERC-4626 Standard Exchange** package under `contracts/vaults/standard/erc4626/` so hermetic/fork legs use production SE routes (same co-deliverable law as single-hook §6.0). **The dual-hook implementation plan owns Phase 0:** gate on or finish those SE routes before dual DoD (D66). Dual does **not** re-open ERC-4626 first-deposit product law.

**Authority (normative):**

| Layer | Role |
|-------|------|
| **This PRD (v3.12)** | Product law used to **write** the implementation plan. **Canonical** product decisions live in §3 (D/O/C tables). Version history is §14 only — do not re-derive law from old lock-layer sections. |
| **Rewritten implementation plan** | **Source of truth for implementors** once written against this PRD |
| Peer packages / ConstProdUtils | Formula and pattern references cited by PRD/plan |
| Existing `dual/*.sol` | Non-authoritative scaffold; plan may prescribe full rewrite |

This PRD-lock pass does **not** write code or rewrite the plan.

---

## 0. Terminology (normative)

| Term | Meaning in this PRD |
|------|---------------------|
| **SE shares** | ERC-20 balances of bound Standard Exchange vaults held by the hook |
| **Claim** / **claim supply** | Pair-token value of hook-held SE shares via SE preview unwrap |
| **LP tokens** / **LP amount** / **`lpAmount`** | Fungible ERC-20 minted by **this hook** (pro-rata claim on both SE legs). API params historically named `shares` mean **hook LP tokens**, **not** SE vault shares |
| **Ctor legs** | `(se0, token0)` and `(se1, token1)` as passed to deploy/ctor (free order) |
| **Pool currencies** | V4 `currency0` / `currency1` = bound pair tokens **sorted by address** |
| **`amount0` / `amount1`** | Always **pool currency order** (`currency0` / `currency1`), never ctor-leg index |
| **`zeroForOne`** | V4 pool order: `currency0 → currency1` when true |
| **Live pool** | Both claim supplies \(x > 0\) and \(y > 0\) (C14) |
| **Zap-eligible** | Live **and** `totalSupply > MINIMUM_LIQUIDITY` (D79) — residual dust-only book is **not** zap-eligible |
| **Claim-in (swap/zap)** | SE fee-inclusive preview of how much **claim** a raw pair-token buffer adds (D78) — not assumed 1:1 with raw amountIn |
| **DoD** | Definition of Done — package complete when §11 is satisfied |

---

## 1. Goal

Ship a **production-first Uniswap V4 hook package** that:

1. Binds **two** Standard Exchange (SE) vaults and **two** pair tokens on a **per-hook-instance** basis: `(SE₀, token₀)` and `(SE₁, token₁)`.
2. Powers a V4 pool whose currencies are the **pair tokens** (`currency0 ↔ currency1` after address sort), **not** SE shares (e.g. WETH ↔ USDC).
3. Behaves as a **normal constant-product AMM** on **SE claim supplies** (effective reserves), not on idle pair-token balances.
4. **Buffers** pair tokens into the bound SE on liquidity add and on swap token-in.
5. **Unwraps** from the bound SE on liquidity remove and on swap token-out.
6. Mints a **single fungible ERC-20** LP token representing pro-rata claim on **both** SE legs (classic CP LP).
7. Supports **two deposit entry paths** (both in v1 DoD):
   - **Proportional (dual-asset)** — both pair tokens; Uni V2-style ratio add (clamp + refund excess).
   - **Single-asset** — one pair token via **internal zap-in** (swap portion for the other leg, then proportional add). Depositor **accepts** CP price impact and SE costs of the zap; no separate single-sided LP position or value guarantee beyond fair rebalance + add.
8. Deploys via hook diamond package → Vault Registry `deployHookVault` → shared hook CREATE2 factory. `deployVault` leaves a bootstrap diamond (vault pair + package-as-init). The product door is later `deployPair(tokenA, tokenB)` for the bound pair (`fee = 0`); production ABI (hooks / deposit / withdraw / SE / ERC-20) is installed by `finalizeInitialization`. See staged init PRD.

### 1.1 Canonical user story (WETH SE + USDC SE)

```text
Hook binding (instance):
  SE_WETH  ↔ token WETH   (WETH ∈ SE_WETH.vaultTokens())
  SE_USDC  ↔ token USDC   (USDC ∈ SE_USDC.vaultTokens())
  Cross-acceptance irrelevant

Pool: currency0/currency1 = sort(WETH, USDC), fee = 0, hooks = this instance
  (V4 still needs sqrtPriceX96 + tickSpacing at initialize — PoolManager plumbing only;
   product mid/depth come from SE claims, not CL price.)
Trading mid = claim reserves once live (x, y from SE → pair token previews)

--- Proportional deposit (dual-asset) ---
User supplies amount0 + amount1 in **pool currency order** (excess refunded to match ratio)
  → map each currency → its SE leg → buffer
  → mint fungible LP (pro-rata both legs)
  → claims x,y; k = x*y

--- Single-asset deposit (zap-in) ---
User supplies only one pair token (zap-eligible: x>0, y>0, and totalSupply > MINIMUM_LIQUIDITY — D79)
  → internal swap of optimal slice for the other currency
       CP on **claim-in** after SE buffer preview (D78); buffer sold leg; unwrap other
  → proportional add of remaining + received
       buffer both into SEs; mint same fungible LP
  → depositor accepts swap price impact + SE fees on the zap path
  → book stays dual-sided; no one-sided LP receipt

--- First liquidity ---
Must be dual-asset proportional deposit (both currencies non-zero).
Single-asset zap reverts if not zap-eligible (empty book, or only MINIMUM_LIQUIDITY residual — D79).

--- Swap ---
quote CP on claims using **claim-in** (SE fee-inclusive buffer preview of raw amountIn — D78)
take tokenIn → buffer SE_in
unwrap tokenOut from SE_out → settle

--- Withdraw ---
burn LP → pro-rata SE shares both legs → unwrap both → pair tokens to user
(returns amount0/amount1 in pool currency order)

--- Yield ---
SE claim ↑ → mid/depth update on next quote
```

### 1.2 Product shape (locked)

| Layer | Role |
|-------|------|
| Uniswap V4 | Pool identity, **swaps** + currency settlement via hook deltas; init requires fee/sqrtPrice/tickSpacing plumbing |
| Hook | Binding, **deposit / depositSingle / withdraw** (+ Permit2 variants), LP ERC-20, CP math, SE buffer/unwrap, `beforeSwap` |
| SE vaults | Yield-bearing inventory; effective reserves = redeem claim to pair token |
| Concentrated liquidity | **Not used** — native `modifyLiquidity` **forbidden** |
| Book shape | **Always dual-sided** after any successful add; no one-sided book mode |
| LP shape | **One** fungible ERC-20 only (never per-leg or single-asset receipts) |

**Normal CP:** Uni V2-style economics (dual reserves, fungible LP, swaps on \(x\cdot y=k\)), with reserves = **SE claims** and transfers = **buffer / unwrap**.

**Deposit law (locked):**

| Path | User provides | Accounting | LP received |
|------|----------------|------------|-------------|
| Proportional | Both tokens (ratio-clamped) | Buffer both → mint | Fungible dual LP |
| Single-asset | One token | **Internal zap** (CP swap + proportional add) → mint | **Same** fungible dual LP |

Single-asset is **not** a distinct liquidity position type. It is UX + internal rebalance; economic cost is borne by the depositor (accepted).

---

## 2. Product summary

### 2.1 What this package is

| Attribute | Value |
|-----------|--------|
| Primary artifact | CREATE3-mined single hook (Repo + Target) implementing V4 `IHooks` **plus** deposit surfaces + LP ERC-20 |
| Binding | Two SE + two pair tokens + PoolManager (ctor immutables); Permit2 = Uniswap well-known constant |
| Pool currencies | Bound pair tokens only (address-sorted) |
| Inventory | Hook-held **SE shares** |
| Effective reserves | \(x,y =\) claim of each SE leg → pair token (see §4) |
| Pricing | **Constant product on claims** with **0.3% swap fee** (D29); \(k = x\cdot y\) (fee retained for LPs) |
| LP | Fungible ERC-20; pro-rata **both** legs only |
| Deposit (proportional) | Both pair tokens (pool order amounts); clamp to ratio; buffer both SEs; refund excess |
| Deposit (single-asset) | One pair token; **internal zap-in** then proportional add; **v1 required** |
| Funding | **ERC-20 approve + transferFrom** and **Permit2** (SignatureTransfer + AllowanceTransfer) for deposits |
| Slippage | **min LP / min outs + deadline** on liquidity paths (v1 required) |
| Withdraw | Pro-rata SE shares; **unwrap** both legs to pair tokens (pool order returns) |
| Swap | tokenIn buffered; tokenOut unwrapped; CP on claims **+ 0.3% fee** (D29) |
| Deploy path | Existing `create3Factory` + `HookMinerCreate3` + FactoryService |

### 2.2 What this package is not

- Not the single SE wrapper hook (`underlying ↔ SE`).
- Not a one-sided or “partial book” AMM mode.
- Not single-asset **positions** or per-leg ERC-20 receipts (zap is entry only).
- Not a value-preserving promise for single-asset depositors beyond fair zap + add.
- Not a full Uniswap V4 CL engine or Position Manager LP.
- Not a global registry of token↔SE pairs (binding is **instance-local**).
- Not package-owned pool creation.
- Not a DETF.
- Not a Facet/DFPkg diamond for the hook instance.
- Not multi-pool shared inventory — **hard-rejected** at `beforeInitialize` after first successful pool init (D69); DoD is one pool per hook.

### 2.3 Non-goals (v1)

1. One-sided liquidity **positions** or one-sided-only **book** state.  
2. Distinct ERC-20 receipts per leg or per single-asset deposit.  
3. Guaranteeing single-asset depositors face zero price impact vs HODL.  
4. InitPrice / mode machine for empty or single-leg markets.  
5. Tick/range CL; Uni LP NFTs.  
6. Reimplementing default V4 CL behavior inside the hook.  
7. Native ETH as pool currency (use WETH).  
8. Auto-deploying SE / protocol vaults inside the hook package.  
9. Omitting classic ERC-20 **or** Permit2 deposit funding — **both** required (D45–D46). Swaps remain V4/PoolManager (no hook Permit2 for swaps).  
10. Omitting the **0.3% CP swap fee** (D29) or applying a second amountIn haircut beyond D29 — V4 pool fee stays 0; SE usage fees and D57 protocol growth mint remain separate.  
11. Binary-search exact-out solvers for swaps (closed form). *Zap: closed form once + clamp/refund residual only (O1a / C5).*  
12. Pricing without SE claim.  
13. Subclassing the single buffer hook.  
14. Universal pair registry.  
15. Multi-hop outside the bound pair.  
16. Levered LP / borrow sleeves / keepers.  
17. Deadline-skew **admin** surface for SE calls (`block.timestamp` if SE needs deadline). User-facing liquidity `deadline` is separate (D47).  
18. Shared TestBases with Uni V4 DETF packages.  
19. Fee-on-transfer or rebasing **pair tokens** (unsupported; may brick).  
20. Treating V4 `sqrtPriceX96` as product mid after init (ignored for pricing).  
21. Second V4 pool initialize against the same hook instance (D69).

---

## 3. Locked product decisions

| # | Decision | Value |
|---|----------|--------|
| D1 | Product name | **`UniswapV4DualStandardExchangeBufferConstantProductHook`** |
| D2 | Package location | `contracts/hooks/uniswap/v4/standardExchange/dual/` |
| D3 | Sibling to single hook | Pattern-copy settle/FactoryService style only; **no** required inheritance |
| D4 | SE generality | Any `IStandardExchange` with closed-form **pairToken ↔ SE** buffer and unwrap |
| D5 | Binding | `(poolManager, feeOracle, se0, token0, se1, token1)` ctor immutables; no post-deploy rebind. **Permit2** is Uniswap well-known constant (not a binding arg; D51). **feeOracle** = `IVaultFeeOracleQuery` for protocol growth fee + `feeTo` (D57) |
| D6 | Pair validation | Non-zero; `token0 ≠ token1`; `tokenᵢ ∈ vaultTokens(seᵢ)`; cross-membership irrelevant |
| D7 | `se0 == se1` | **Forbidden** v1 |
| D8 | Pool pair | Currencies = bound pair tokens (map leg ↔ `currency0/1` by address sort) |
| D9 | Pool fee | **0** |
| D10 | Native CL | **Forbidden** — `beforeAddLiquidity` reverts |
| D11 | Package shape | Repo + Target + Common + FactoryService; no Facet/DFPkg for hook |
| D12 | Hook inheritance | No `BaseTokenWrapperHook` / `BaseHook` / `DeltaResolver` inherit — pattern-copy |
| D13 | AMM model | **Normal constant product** on claim reserves only |
| D14 | One-sided book | **Not supported** — no product mode for single-leg markets; **live** means \(x>0\) and \(y>0\); empty book only before first mint |
| D15 | Claim supply | \(s_i = \mathrm{previewExchangeIn}(SE_i,\ \mathrm{balanceOf(hook)},\ token_i)\) (SE→token unwrap exact-in semantic) |
| D16 | Reserves for CP | Claims mapped into **pool currency order** for quotes: \(x =\) claim of `currency0` leg, \(y =\) claim of `currency1` leg; \(k = x\cdot y\), mid \(P = y/x\) (after 1e18 normalize for math) |
| D17 | Yield in price | Re-read claims each quote; SE profit moves mid without a swap |
| D18 | LP token | Single fungible **ERC-20** on the hook; pro-rata both SE share balances. API name `shares` / return `lpAmount` = **hook LP tokens** |
| D19 | Proportional deposit | **Required v1 path** — both pool currencies **non-zero**; when live, **clamp to current claim ratio** and **refund excess** (Uni V2 style); first mint uses both full amounts (no prior ratio) |
| D20 | Single-asset deposit | **Required v1 path** when **zap-eligible** (D79) — one pair token; **internal zap-in** then proportional add; same LP token as D19. **Not** available on empty book or MINIMUM_LIQUIDITY-only residual |
| D21 | Zap economics | Depositor **accepts** CP price impact **including D29 0.3% fee** + SE buffer/unwrap costs on the swapped slice; `previewDepositSingle` returns expected **LP amount**; **`previewZapSplit`** returns swap slice / other-leg amounts with **strict preview == execution** (D65). Internal swap uses **claim-in CP composition** (D78) |
| D22 | Zap accounting | (1) closed-form split of `amountIn`; (2) internal swap via same buffer-in / unwrap-out + **claim-in CP** as public swaps (D78); (3) proportional add of remainder + proceeds; (4) mint fungible LP — **never** leave one-sided inventory as LP state |
| D23 | First mint / empty pool | **Proportional dual-asset only** (both currencies non-zero). Sets initial \(x,y,k\). **Single-asset deposit reverts** if not zap-eligible (D79) — including \(x=0\) or \(y=0\), and after full user exit with only MINIMUM_LIQUIDITY residual |
| D24 | Remove liquidity | Burn LP → pro-rata **SE shares** both legs → **unwrap** to pair tokens → pay user |
| D25 | Swap | `beforeSwap` + `beforeSwapReturnDelta`; buffer tokenIn; unwrap tokenOut; CP on claims via **claim-in composition** (D78) |
| D26 | SE I/O | `exchangeIn` / `exchangeOut` only; no protocol-vault math on hook |
| D27 | Preview fidelity | preview == execution on closed-form paths **including fee-on protocol growth mint dilution** (D61), **`previewZapSplit` fields** (D65), **and swap previews under SE fees** (D73 / D78); dust only if SE documents ≤ peer `MAX_DUST_WEI` (10) |
| D28 | Public previews | `previewDeposit`, `previewDepositSingle`, **`previewZapSplit`**, `previewWithdraw`, swap exact-in/out, claim supplies — deposit/withdraw/single LP previews **simulate D57 before user math when fee-on** (D61); **`previewZapSplit` is SE-aware and strict** (D65); **swap previews use claim-in CP composition** (D78) |
| D29 | Trading swap fee (CP) | **0.3%** Uni V2-style on **public swaps and zap internal swap**. **Retained entirely in claim reserves** (LPs earn volume). V4 **pool** fee remains **0** (D9). Encoding: **`feePercent = 300`**, **`feeDenominator = 100_000`**. **Not** applied to pure proportional deposit (no internal swap). Distinct from D57 protocol growth fee |
| D30 | SE usage fees | SE `usageFeeOfVault` / vault fee oracle on bound SE legs; **inside SE previews/execution only** (D73 — fee-inclusive SoT). **In addition to** D29 and D57. Hook does **not** re-implement SE fee formulas. DoD tests **must** run with **non-zero SE usage fees on buffer / share-minting routes** (D70) — not a requirement to invent exit/unwrap usage fees |
| D31 | Quote matrix (swaps) | Exact-in + exact-out both ways; closed form |
| D32 | SE minOut/maxIn | Tight = preview |
| D33 | SE call deadline | `block.timestamp` if required by SE (no admin skew) |
| D34 | Inventory multi-pool | **Unsupported.** **v1 enforces one V4 pool per hook instance** via hard-revert on a second `beforeInitialize` success path (D69). Do not build multi-pool tests as required coverage |
| D35 | Pool init | External; `beforeInitialize` validates pair tokens + fee=0 **and enforces one-pool** (D69). **`sqrtPriceX96` + `tickSpacing` are V4 PoolManager plumbing only** — not product pricing (C6) |
| D36 | Deploy | CREATE3 + flag mine; FactoryService; not vault registry |
| D37 | Salt namespace default | `"uv4-dual-se-buffer-constant-product-hook-"` |
| D38 | Salt material | namespace + poolManager + **feeOracle** + canonical sorted legs + mineNonce (**no** Permit2) |
| D39 | Empty SE at hook deploy | Allowed; first LP still dual-asset when users fund |
| D40 | Donation SE shares to hook | Counts in `balanceOf` / claims (dilutes LPs) |
| D41 | Stray pair tokens on hook | Not inventory until buffered; ignore for CP. After successful **liquidity** ops: free pair-token balance ≤ `MAX_DUST_WEI`, else **refund excess to `msg.sender`** (D71). Swap path must not leave residual free pair tokens (full settle or revert) |
| D42 | Role naming | Ctor: `token0`/`token1` + `standardExchange0`/`1` (legs). Liquidity amounts: **pool currency order**. No DETF brand names; no WETH-generic APIs |
| D43 | Tests | Production-first; **two real ERC-4626 SE vaults wrapping test tokens** (D60); no mock SUT; both deposit paths + Permit2 packing DoD; **hermetic + required forks on Base and Robinhood Chain (4663)** (D64 / D74 deploy-if-missing); non-zero SE **buffer-route** usage fees (D70) + non-zero protocol dex fee paths; fee-on preview == execution (D61); **strict `previewZapSplit` under SE fees** (D65); **swap preview under SE fees via claim-in composition** (D78); **yield → D57 protocol fee** (D67); second-pool initialize reverts (D69); **ZapSwap** (D77); subsequent mint after MINIMUM_LIQUIDITY residual (D76); **`depositSingle` reverts when only MINIMUM_LIQUIDITY residual** (D79) |
| D44 | Impl plan follow-on | `UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` |
| D45 | Deposit funding | **Both** required in v1: (1) classic ERC-20 `approve` + hook `transferFrom(msg.sender)`; (2) Permit2 paths. Refund of unused deposit tokens always to **`msg.sender`** (even if LP minted to `to`) |
| D46 | Permit2 styles | **Both** required in v1 DoD: **SignatureTransfer** and **AllowanceTransfer** for deposit token-in. Swaps **not** via hook Permit2 (V4/PoolManager only) |
| D47 | Liquidity slippage params | **Required v1:** `minLpAmount` (min hook LP tokens) + `deadline` on deposits; `minAmount0`/`minAmount1` (pool order) + `deadline` on withdraw. Revert if `block.timestamp > deadline` or mins not met |
| D48 | Amount index order | **`amount0`/`amount1`/`used0`/`used1`/`minAmount0`/`minAmount1` = pool `currency0`/`currency1`** (address sort). Map to SE legs internally |
| D49 | Fee-on-transfer / rebasing pair tokens | **Out of scope** — unsupported; no special handling |
| D50 | Missing `decimals()` | Default **18** for normalize math if `decimals()` missing/reverts |

### 3.1 Implementation edges — **LOCKED** (2026-08-02)

| ID | Topic | Locked value |
|----|--------|--------------|
| O1 | First / subsequent LP mint | **First** (`totalSupply == 0` only — D76): `lpAmount = sqrt(xN * yN) - MINIMUM_LIQUIDITY` on **1e18-normalized claims** after buffer (Uni V2 geometric). If `sqrt(xN*yN) < MINIMUM_LIQUIDITY`, **revert**. **Later** (any `totalSupply > 0`, including only MINIMUM_LIQUIDITY residual): `lpAmount = min(dxN/xN, dyN/yN) * totalSupply` on normalized claim deltas — ratio clamp, never geometric re-bootstrap |
| O1a | Zap optimal split | **Closed form on 1e18-normalized claim reserves**, **once**, **with D29 0.3% fee**. Normative: Crane **`ConstProdUtils._swapDepositSaleAmt(amountIn, saleReserve, feePercent=300, feeDenominator=100_000)`** (or bit-identical inlined form). Fee-less limit of that formula is \(\sqrt{r(r+A)}-r\); **do not** ship fee-less when D29 is 0.3%. Convert wad↔raw with floor as needed. **Internal swap of the sold slice uses D78 claim-in composition** (same as public swaps). SE fee drift after execute: **proportional clamp + refund residual** — **no** second solve of the split, **no** binary-search as primary law |
| O2 | API naming | **Canonical:** `deposit` / `depositSingle` / `withdraw` (+ previews + `previewZapSplit`). Permit2: `depositWithPermit2Signature` / `depositWithPermit2Allowance` / `depositSingleWithPermit2Signature` / `depositSingleWithPermit2Allowance` (see §7.1). No required `depositZap` alias |
| O3 | Decimal normalization | **Normalize both claim legs to 1e18** before CP / mint / zap math. Canonical: `toWad(a,d) = a * 10**(18-d)` if `d ≤ 18`; if `d > 18`, `a / 10**(d-18)` (floor). Missing decimals → **18** (D50). **LP ERC-20 decimals always 18** (O10) |
| O4 | LP name/symbol | **Auto** from pair token symbols in **pool currency order only** (e.g. `DSEBCP-{symbol(currency0)}-{symbol(currency1)}`); address-fragment fallback if `symbol()` missing/reverts **or** combined name/symbol is unreasonably long. Prefix = Dual Standard Exchange Buffer Constant Product |
| O5 | MINIMUM_LIQUIDITY | **Yes** — `1000` (Uni V2 peer); mint to **`address(0)`** on first mint; **never burned**; permanently dilutes residual claim (accepted Uni V2 dust lock) |
| O6 | Ctor leg order | Free `(se0,token0)/(se1,token1)`; map to pool `currency0/1` by address sort at runtime |
| O7 | LP ERC-20 location | **Same mined hook contract** (IHooks + ERC-20) |
| O8 | Proportional non-ratio | **Clamp + refund** excess to `msg.sender` (D19, D45) |
| O9 | Zap settle path | **Shared SE buffer/unwrap helpers only** — **no** PoolManager round-trip for internal zap swap |
| O10 | LP ERC-20 decimals | **Always `18`** (independent of pair-token decimals) |
| O11 | Claim deltas for mint | **Re-read claims** via §4.1 before and after buffer steps. `dx = claimAfter - claimBefore` per pool leg (raw), then normalize. **Do not** invent claim from SE-share mint amounts alone without re-preview |
| O12 | CP swap formulas | Exact-in / exact-out as §4.2.1 on **wad** reserves **including D29 fee** via ConstProdUtils `_saleQuote` / `_purchaseQuote` peers. Exact-in **floor** out; exact-out **ceil** (+1) in |

### 3.2 Clarifications — **LOCKED** (2026-08-03)

| ID | Topic | Locked value |
|----|--------|--------------|
| C1 | Liquidity amount order | Pool **currency0/currency1** only (D48). Ctor `token0`/`token1` remain free-order SE legs |
| C2 | Funding | Classic `transferFrom` **and** Permit2 SignatureTransfer **and** AllowanceTransfer for deposits (D45–D46) |
| C3 | Refund recipient | Always **`msg.sender`** for unused deposit tokens |
| C4 | Min params | `minLpAmount` + `deadline` on deposit paths; `minAmount0`/`minAmount1` + `deadline` on withdraw (D47) |
| C5 | Zap residual after SE fees | Closed-form split once → execute → clamp/refund residual (O1a) |
| C6 | V4 `sqrtPriceX96` / `tickSpacing` | **Required by PoolManager.initialize**, ignored for product mid/depth. Hermetic tests: **`tickSpacing = 60`**, **1:1 mid** (`TickMath.getSqrtPriceAtTick(0)` or equivalent). Integrators may use any valid init price |
| C7 | Multi-pool | **Hard-rejected** after first successful init (D69); **DoD = one pool per hook** (D34) |
| C8 | `previewDepositSingle` | Returns expected **hook LP token amount** only |
| C9 | Zap split preview | **`previewZapSplit(tokenIn, amountIn)`** required — returns swap slice / other-leg / kept-in amounts; **strict preview == execution** within dust and **SE-aware** (D65, supersedes “disclosure only”); does not replace C8 (LP amount still on `previewDepositSingle`) |
| C10 | “Shares” in API | Means **hook LP tokens** unless explicitly “SE shares” |

### 3.3 Planning locks — **LOCKED** (2026-08-03, v3.4)

These close gaps that blocked a clean implementation plan and caused premature coding.

| ID | Topic | Locked value |
|----|--------|--------------|
| C11 | Authority for implementors | After rewrite: **implementation plan is SoT for coding**. This PRD is product law used to write that plan |
| C12 | Plan rewrite | Another agent rewrites the plan after PRD acceptance. This session does not rewrite the plan |
| C13 | Deposit vs pool init | **Superseded by staged init.** Production `deposit` / `withdraw` exist only after `finalizeInitialization`, which requires the product PoolKey live. **Swaps** still require that initialized pool + live claims. **V4 `initialize` does not require liquidity** (only sets sqrtPrice plumbing; product LP is via hook `deposit`, not `modifyLiquidity`) |
| C14 | Live check basis | **Live** ⇔ `claimSupplyCurrency0() > 0 && claimSupplyCurrency1() > 0` (pool-order claims). **Zap-eligible** is stricter (D79): live **and** `totalSupply > MINIMUM_LIQUIDITY` |
| C15 | SE I/O matrix | **§4.5** — buffer `exchangeIn(pair→SE)`; withdraw unwrap `exchangeIn(SE→pair)`; swap-out unwrap `exchangeOut(SE→pair)` |
| C16 | SE minOut / maxIn | **Tight = preview**. Under-delivery → revert (no partial fill) |
| C17 | SE deadline | **`block.timestamp`** when SE requires deadline (D33). Distinct from user liquidity `deadline` (D47) |
| C18 | Permit2 address | **Uniswap well-known only:** `0x000000000022D473030F116dDEE9F6B43aC78BA3`. **Not** a ctor deploy arg; **not** in CREATE3 salt. Hermetic: deploy Permit2 bytecode at that address or use fork |
| C19 | Permit2 packing (signature) | **Normative DoD — §7.3.** Both SignatureTransfer + AllowanceTransfer required; packing fixed in PRD |
| C20 | Dust bound | **`MAX_DUST_WEI = 10`** for preview==execution tolerance only when SE multi-leg dust is documented |
| C21 | Residual pair tokens | After successful **liquidity** ops, free pair-token balance on hook ≤ dust, else **refund to `msg.sender`** (D71). SE shares on hook **are** inventory. Swaps leave no free pair-token residual |
| C22 | Events (v1 required) | **`Deposit`**, **`DepositSingle`**, **`Withdraw`**, **`ZapSwap`** (D77) — normative arg lists in §7.5 |
| C23 | Custom errors | Plan/implementor judgement; must cover zero/invalid binding, not live, **not zap-eligible** (D79), deadline, slippage mins, liquidity forbidden, not pool manager, disabled hooks, **already initialized / second pool** (D69) |
| C24 | Hook permissions | **Only:** `beforeInitialize`, `beforeAddLiquidity`, `beforeSwap`, `beforeSwapReturnDelta`. Other IHooks callbacks revert |
| C25 | Access control | Liquidity + views: **permissionless**. Hook callbacks: **`msg.sender == poolManager` only** |
| C26 | Reentrancy | Liquidity paths **`nonReentrant`** (D58). Swaps: PoolManager + SE locks; no user reentry into liquidity mid-callback |
| C27 | SE test matrix (DoD) | **Two ERC-4626 Standard Exchange vaults wrapping test tokens** (distinct pair tokens). No mock SE. `se0 == se1` forbidden |
| C28 | Factory salt material | `namespace + poolManager + feeOracle + seLo + tLo + seHi + tHi + mineNonce` (address-sorted tokens). **No Permit2.** Empty namespace → default D37 |
| C29 | Factory idempotency | Same salt binding: expected hook at predicted address → return existing; wrong code → revert |
| C30 | Mine flags | `BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA` |
| C31 | Integer sqrt | Floor Babylonian / Uni V2 / ConstProdUtils peer |
| C32 | Zero / dust outputs | Zero amountIn / zero mint / zero swap out when in>0 → revert; clamp to used0==0 or used1==0 on subsequent proportional → revert |
| C33 | Withdraw SE share math | `seOut_i = seBal_i * lpAmount / totalSupply` **pre-burn** (floor); unwrap exact-in SE→pair each leg |
| C34 | V4 swap settle order | Pattern-copy single buffer: take tokenIn → buffer → unwrap tokenOut → settle; `BeforeSwapDelta`. No Crane base inheritance |
| C35 | Exact-out public swap | Closed-form amountIn with D29 fee (ceil); take that amountIn; buffer; unwrap exact amountOut |
| C36 | Bootstrap residual | After full user withdraw, **MINIMUM_LIQUIDITY** remains on `address(0)` with residual claims (Uni V2 dust). **Further liquidity = dual-asset proportional `deposit` only** — **`depositSingle` / zap is forbidden** while `totalSupply <= MINIMUM_LIQUIDITY` (D79). **Mint formula:** while `totalSupply > 0` (including only MINIMUM_LIQUIDITY left), always use **subsequent** mint (ratio clamp from residual claims) — **never** geometric first-mint. Geometric first mint **only** when `totalSupply == 0` (D76) |
| C37 | Claim measurement for mint | **Re-preview claims** after SE buffer/unwrap has settled (before mint math) |

**Additional product decisions (D51–D64):**

| # | Decision | Value |
|---|----------|--------|
| D51 | Permit2 | Well-known Uniswap address (C18); deposit paths require both styles (D45–D46); **`permit2()` view**; packing **normative DoD** (§7.3) |
| D52 | LP token standard | Minimal ERC-20 + metadata; **decimals = 18**; free transfer; no permit-on-LP required in v1 |
| D53 | `isExpectedHook` | Match `poolManager` + `feeOracle` + both SE+token legs (order-insensitive). **Factory / deploy-idempotency helper only** — **not** required on the hook public ABI (D80). May live on FactoryService or as an internal/pure check; plan must **not** invent a mandatory §7.1 `isExpectedHook` getter |
| D54 | Public `permit2()` view | **Yes** |
| D55 | CP / protocol-fee library | Prefer **ConstProdUtils** (or bit-identical) for sale/purchase/zap-split **and** protocol growth LP mint helpers (**generic** `_calculateProtocolFee` path — D62) |
| D56 | Scaffold | Existing `dual/*.sol` (may still use legacy `UniswapV4DualBufferPricingHook*` names) is non-authoritative; plan **must** rename to D1 and may prescribe full rewrite |
| D57 | Protocol fee on liquidity growth (Uni V2–style) | **Yes.** Track **`kLast`** as **wad claim product** \(x_N \cdot y_N\) (D63). On **mint and burn** liquidity paths (deposit, depositSingle, withdraw), **before** adjusting user LP supply: if fee-on, mint protocol LP to **`address(feeTo)`** from growth since `kLast`. **Measurement timing (D72 / Uni V2 peer):** on **deposit / depositSingle**, compute protocol mint from **pre-buffer** pool-order claims (user’s new capital is **not** partly taxed as growth); then buffer/zap/add; mint user LP from claim deltas; set `kLast` to **post-op** wad product when fee-on. On **withdraw**, mint protocol LP from growth since `kLast` **before** user burn (post any fee-on dilution of `totalSupply`), then burn/unwrap; set `kLast` post-op. **Sources:** `feeOracle.dexSwapFeeAndFeeToOfVault(address(this))` returns `(IFeeCollectorProxy feeTo, uint256 dexFeeWad)`. **Naming callout:** oracle field **`dexSwapFee` / `dexSwapFeeOfVault` is the protocol growth share (WAD)** mapped to ConstProdUtils `ownerFeeShare` — **despite the name, it is not a second amountIn trading fee**. Trading fee is only D29 0.3%. **`ownerFeeShare = dexFeeWad * 100_000 / 1e18`** (floor); use ConstProdUtils **generic** `_calculateProtocolFee` (Camelot-like), **not** fixed Uni V2 1/6 unless share lands in 16666–16667 special-case (D62). **No product max cap** on `dexFeeWad` / `ownerFeeShare` (D82) — trust oracle config. **Fee-on** when `address(feeTo) != 0` and **resolved** dex fee ≠ 0 (`IVaultFeeOracleQuery`: mapping 0 = unset → vault-type → global default). **Not** a second haircut on swap amountIn (that remains D29 0.3% to reserves). When fee-off set `kLast = 0` (Uni V2 peer). **k growth sources (D67):** any increase in claim product since `kLast` is fee-eligible — including **D29 swap fee retention**, **SE yield** on hook-held shares, and **donations** of SE shares — no special-case exclusion for yield. Full surface §7.4 |
| D58 | Liquidity reentrancy | **All** external liquidity entrypoints (`deposit*`, `withdraw`, Permit2 variants) are **`nonReentrant`**. Hook callbacks rely on PoolManager + lock discipline |
| D59 | Public fee views | **Required** (not plan-discretionary): `feeOracle()`, `tradingFeePercent()` and/or immutable constants for `300` + `100_000`, views for resolved `dexSwapFee` / `feeTo` (or `dexSwapFeeAndFeeTo()` reading oracle with `address(this)`), and **`kLast()`**. See D68 / §7.1 required surface |
| D60 | ERC-4626 SE co-deliverable | **Hard prerequisite for dual-hook DoD.** Complete generic ERC-4626 Standard Exchange under `contracts/vaults/standard/erc4626/` (single-hook §6.0 route/completeness law). Hermetic + fork DoD legs are **two production ERC-4626 SE vaults** wrapping test/real pair tokens — not mock SE. **Ownership:** dual-hook plan **Phase 0** gates on or finishes this work (D66) |
| D61 | Previews include protocol mint | When fee-on, `previewDeposit`, `previewDepositSingle`, and `previewWithdraw` **simulate D57 protocol LP mint first** (dilution of `totalSupply`), then user LP / outs, so **preview == execution** (D27). Deposit/single previews use **pre-buffer** claim product for the protocol-mint step (D72). User LP from zap is via `previewDepositSingle`. **`previewZapSplit`:** see **D65** (strict SE-aware match — not disclosure-only) |
| D62 | Protocol fee math path | **Generic ConstProdUtils `ownerFeeShare`:** `ownerFeeShare = dexSwapFeeWad * FEE_DENOMINATOR / 1e18` with `FEE_DENOMINATOR = 100_000`. Example: 5% WAD (`5e16`) → `ownerFeeShare = 5000`. Do **not** force Uni V2 fixed 1/6; the library’s 16666–16667 branch applies only if resolved share lands there |
| D63 | `kLast` units | **Wad claim product only:** after normalize both pool-order claims to 1e18, `kLast = xN * yN`. Never raw \(x \cdot y\) when pair decimals differ |
| D64 | Fork DoD networks | **Both required:** **Base** mainnet fork **and** **Robinhood Chain (chain ID 4663)** fork. Each: dual ERC-4626 SE legs; deposit → swap → withdraw smoke with fees on. Plan names the repo’s fork profile/RPC convention — do not invent alternate chain IDs. **“Real” stack (D74):** prefer live deployed PoolManager + Permit2 + fee-oracle path when addresses exist; if missing on that fork, **deploy production-equivalent bytecode on the fork** (Permit2 at the Uniswap well-known address when possible). Not mock SUT — real contracts on the fork |
| D65 | `previewZapSplit` fidelity | **Strict preview == execution** (within `MAX_DUST_WEI`) on **`amountToSwap`**, **`amountOtherOut`**, and **`amountKeptIn`**, **including when SE usage fees are non-zero**. Preview must be **SE-aware** (simulate buffer/unwrap costs and post-SE clamp/refund residual — same path as execution / O1a C5). Not “UI disclosure only.” Still fee-aware for D29 (O1a). User LP amount remains on `previewDepositSingle` |
| D66 | Dual plan owns ERC-4626 Phase 0 | The **dual-hook implementation plan** includes **Phase 0:** verify completeness of generic ERC-4626 SE closed-form pair↔SE routes (single-hook §6.0 law) and **finish any gaps** required for dual DoD. Dual does not assume a separate workstream is already green without checking |
| D67 | Yield (and other k growth) fee-eligible | Mechanical Uni V2 `kLast`: **any** claim-product increase since last liquidity op is D57 protocol-fee eligible on next mint/burn. **Includes SE yield** on hook-held shares. Do **not** special-case yield (no “refresh kLast without minting” for pure yield). Same path as swap-fee retention growth |
| D68 | Required public surface | **§7.1 lists the required product surface by name** (bindings, claims, liquidity + Permit2, previews, fee/`kLast` views, trading-fee constants, full minimal ERC-20 + metadata). Plan may add deploy/view helpers only; **must not** omit required items. Supersedes “sketch only — plan invents fee/kLast/ERC-20 names” |
| D69 | One pool per hook (hard) | **`beforeInitialize` hard-reverts** after this hook has already successfully initialized a V4 pool. Store a one-shot flag and/or initialized `PoolId` in Repo. Validates bound pair currencies (address-sorted match) + fee=0 on first init. Multi-pool shared inventory is **rejected**, not only discouraged |
| D70 | SE usage fee DoD scope | Non-zero SE **usage** fees required on **buffer / share-minting** routes only (proportional deposit buffer, swap-in buffer, zap buffer legs). Aligns with ERC-4626 SE peer law: dilution mint on share-mint routes; **v1 exit/unwrap may be fee-less**. Do **not** invent an exit usage fee solely for dual-hook DoD. `previewZapSplit` / previews must still match execution under deposit-side SE fees (D65). **SE fee inclusion law:** D73 |
| D71 | Residual free pair-token refund | After successful **liquidity** ops, free pair-token balance on the hook above `MAX_DUST_WEI` is **refunded to `msg.sender`** (same recipient as clamp refund, C3). Swap path: no residual free pair tokens (full take → buffer → unwrap → settle, or revert) |
| D72 | D57 k measurement timing | **Uni V2 peer.** Deposit / depositSingle: protocol mint uses **pre-buffer** pool-order claim product vs `kLast`. Withdraw: protocol mint from growth since `kLast` **before** user burn. Always set `kLast` to **post-op** wad product when fee-on (or `0` when fee-off). User’s own deposit capital is **not** taxed as k growth in the same op |
| D73 | SE previews are fee-inclusive SoT | Bound SEs **must** implement `previewExchangeIn` / `previewExchangeOut` so **preview == execution** and **all SE usage fees are included in those previews**. The hook **does not** re-derive SE fee math. Claims, buffer `minOut`, unwrap `maxIn`, and SE-aware previews use those previews as sole SoT for SE costs. **How CP and SE previews compose on swaps/zap is D78** — not “raw amountIn into CP with SE only on settle bounds.” |
| D74 | Fork stack deploy-if-missing | On Base and Robinhood (4663) forks: use live PoolManager / Permit2 / fee-oracle wiring when present. If absent, **deploy production-equivalent** PoolManager (and related V4 stack as required) and **Permit2 at well-known address** on the fork. “Real” means real bytecode on the fork — not interface mocks |
| D75 | `feeTo` receivability | **Out of scope for this PRD.** Protocol LP mints to `address(feeTo)` per D57. If mint fails (non-receivable contract, etc.), the liquidity op **reverts** via normal ERC-20 mint failure — no best-effort skip, no dual-hook special policy. Integrators/oracle config must supply a receivable `feeTo` (e.g. FeeCollector) |
| D76 | Subsequent mint while supply > 0 | Geometric first mint (O1) **only** when `totalSupply == 0`. If only **MINIMUM_LIQUIDITY** remains on `address(0)` after full user withdraw, **always subsequent mint** (ratio clamp from current residual claims). No second geometric “re-bootstrap” path |
| D77 | Zap internal swap event | Internal zap rebalance (O9 — no PoolManager) **must emit** a normative **`ZapSwap`** event (§7.5) so indexers see zap volume without relying on V4 `Swap` logs. Fields: sender, tokenIn, tokenOut, amountIn, amountOut. **`amountIn` / `amountOut`** = raw pair-token amounts actually swapped on the internal leg (after any clamp of the sold slice), not LP amounts |

### 3.4 v3.12 clarity locks — **LOCKED** (canonical; supersedes prior layered C38–C63 pointer tables)

Prior v3.4–v3.11 “clarity lock” subsections only restated D/O decisions. **v3.12 collapses them:** implementors and plan authors use **§3 D/O/C tables + §4–§7** as the single product SoT. Version archaeology lives in **§14 only**.

| # | Decision | Value |
|---|----------|--------|
| D78 | **SE × CP composition (claim-in)** | **Normal CP on actual reserve inflow.** Reserves are claims, not free pair tokens. SE buffer usage fees mean raw `amountIn` is **not** 1:1 with claim increase. **Normative algorithm (§4.2.1):** (1) **Exact-in:** `claimIn =` SE fee-inclusive `previewExchangeIn(pair→SE, amountIn)` (claim delta the buffer will add); run CP (D29) on **`claimIn`** vs current claims → `amountOut` (pair/claim out); buffer raw `amountIn` with `minOut` = SE preview; unwrap `amountOut` with fee-inclusive SE out preview. (2) **Exact-out:** CP → required **`claimIn`**; invert SE buffer preview (**ceil**) to raw `amountIn` user must pay; take/buffer that raw in; unwrap exact out. (3) **Zap internal swap** uses the same claim-in composition as public swaps. (4) Hook **never** re-implements SE fee formulas — only composes CP with `previewExchange*`. (5) Using raw amountIn in CP while only \(\Delta\)claim lands is **forbidden** (under-funds book vs quote). `previewSwapExactIn` / `Out` must match execution under non-zero SE buffer-route fees via this composition |
| D79 | **`depositSingle` / zap eligibility** | **Zap-eligible** ⇔ live claims (\(x>0\) and \(y>0\)) **and** `totalSupply > MINIMUM_LIQUIDITY`. After full user withdraw leaves only MINIMUM_LIQUIDITY on `address(0)`, **`depositSingle` reverts** — re-seed only via dual-asset proportional `deposit` (C36). Empty book (\(x=0\) or \(y=0\)) also reverts zap. `previewDepositSingle` / `previewZapSplit` revert (or equivalent view-fail) when not zap-eligible |
| D80 | **`isExpectedHook` surface** | **Factory / internal only** (D53). **Not** part of §7.1 required hook ABI |
| D81 | **`DepositSingle` event `amountIn`** | Log **user-supplied / pulled full input** (requested `amountIn` transferred in). Residual clamp/refund after zap is separate (refund to `msg.sender`, D71); **no** required `Refund` event in v1. Net capital in the book is not substituted for `amountIn` on the event |
| D82 | **Protocol fee WAD / `ownerFeeShare` bounds** | **No product max cap.** Any resolved `dexFeeWad` / resulting `ownerFeeShare` is allowed; misconfig is integrator/oracle risk (peer to D75 `feeTo` receivability). Plan must **not** invent a 100% clamp or Uni V2 1/6 max unless ConstProdUtils math itself reverts |
| D83 | **`kLast` / claim-product overflow** | **Accepted Uni V2-class risk.** `kLast = xN * yN` (wad product) may overflow `uint256` at extreme claim scales. No required dual-hook overflow-safe mul in v1 unless a ConstProdUtils peer already provides one used by plan; document as known scale limit for integrators |

| ID | Topic | Locked value |
|----|--------|--------------|
| C57 | SE fee-inclusive previews | **D73** — `previewExchangeIn`/`Out` include all SE fees; preview == execution; hook trusts SE previews as SoT |
| C58 | Public swap × SE fees | **D78** — claim-in CP composition; `previewSwap` matches execution under buffer-route SE fees |
| C59 | Fork stack | **D74** — live addresses preferred; else deploy production-equivalent PM + Permit2 on fork |
| C60 | Required ABI surface | **D68** / §7.1 — fee views, `kLast()`, trading-fee constants, full ERC-20 + metadata required; **not** `isExpectedHook` (D80) |
| C61 | Subsequent mint residual | **D76** / C36 — `totalSupply > 0` (incl. only MINIMUM_LIQUIDITY) ⇒ subsequent mint + ratio clamp only |
| C62 | ZapSwap event | **D77** / §7.5 — normative internal zap swap event |
| C63 | `feeTo` receivability | **D75** — out of PRD scope; failed mint reverts the liquidity op |
| C64 | Zap eligibility gate | **D79** — supersedes any “zap iff live only” reading of §5.2 |
| C65 | Claim-in composition | **D78** — supersedes raw-amountIn-into-CP readings of §4.2.1 |
| C66 | Event amountIn | **D81** — full pull on `DepositSingle` |
| C67 | Fee share cap | **D82** — none |
| C68 | Canonical lock location | Product law = §3 D/O/C + body §§; old v3.4–v3.11 layered pointer tables **retired** (history in §14) |

**Retired lock layers (do not reintroduce):** former §3.4–§3.7 pointer tables (v3.7–v3.11) that only restated D57–D77. Their content remains in D/O/C rows above and in §14.

---

## 4. Reserves, pricing, and buffer/unwrap

### 4.1 Effective reserves (claims)

```text
// Per ctor leg (raw pair-token units):
seBal_i = IERC20(se_i).balanceOf(address(hook))
claim_i = IStandardExchangeIn(se_i).previewExchangeIn(
            IERC20(se_i), seBal_i, IERC20(token_i)
          )   // SE shares → pair token, exact-in semantic

// For CP (pool currency order):
x = claim of currency0's bound SE leg   // claimSupplyCurrency0()
y = claim of currency1's bound SE leg   // claimSupplyCurrency1()
xN = toWad(x, decimals(currency0))
yN = toWad(y, decimals(currency1))
```

If either SE balance is 0, that claim is 0. **Live** (C14): \(x > 0\) and \(y > 0\).

**Storage:** do **not** cache \(k\) or mid in Repo as product state. Re-read claims every quote / mint / swap.

### 4.2 Constant product (normative formulas)

Work in **wad** for all CP / mint / zap math; convert to **raw** only for ERC-20/SE/PM amounts.

\[
k_N = x_N \cdot y_N,\quad P_N = \frac{y_N}{x_N}
\]

#### 4.2.1 Public swap (CP on claims **with 0.3% fee**, D29 + claim-in SE composition D78)

Use Crane **`ConstProdUtils`** (or bit-identical). Constants:

```text
feePercent     = 300
feeDenominator = 100_000   // FEE_DENOMINATOR — 0.3%
```

**Why claim-in (D78):** Uni V2 CP assumes the amount that **enters reserves** is what the swap adds to the book. Here reserves are **SE claims**. SE buffer usage fees mean raw pair-token `amountIn` may increase claim by **less** than raw `amountIn`. CP must run on that **claim inflow**, not on raw amountIn. Hook still does **not** re-implement SE fee formulas — it reads fee-inclusive SE previews only (D73).

**SE fee-inclusive SoT (D73):**

- Reserves \(x,y\) = claims from SE `previewExchangeIn` (SE→pair unwrap of hook-held balances).
- Buffer `minOut` / unwrap `maxIn` = tight SE previews (C16). Bound SEs must keep `previewExchange* == execution` with all SE usage fees inside those previews.
- Forbidden: raw amountIn into CP while only \(\Delta\)claim lands; parallel SE-fee haircut invented on the hook.

**Exact-in algorithm (normative D78):**

```text
// 1) Claim inflow from buffering raw amountIn into SE_in (fee-inclusive SE preview)
claimIn = preview_buffer_pair_to_claim(SE_in, amountInRaw)
//    i.e. what claimSupply of the in-leg increases by after exchangeIn(pair→SE, amountInRaw)
//    Prefer: SE preview of shares minted for amountInRaw, then preview unwrap of those shares
//    (or peer closed-form equivalent). claimIn ≤ amountInRaw when buffer usage fee > 0.

// 2) CP on claims with D29 — peer _saleQuote; inputs in wad when decimals differ
//    reserveIn/Out = current claims of in/out legs (pool order / zeroForOne)
amountOut = _saleQuote(claimIn, reserveIn, reserveOut, feePercent=300, feeDenominator=100_000)
//    floor out; require amountOut > 0 and amountOut < reserveOut

// 3) Execute
take amountInRaw tokenIn → buffer SE_in (minOut = SE preview for this buffer)
unwrap amountOut from SE_out via exchangeOut (maxIn = SE preview)
settle amountOut; return BeforeSwapDelta
```

Classic fee-less identity when SE buffer is 1:1: `claimIn == amountInRaw` → same as pure CP on raw in.

**Exact-out algorithm (normative D78):**

```text
// 1) CP: required claim inflow for exact amountOut — peer _purchaseQuote (ceil in)
claimIn = _purchaseQuote(amountOut, reserveIn, reserveOut, 300, 100_000)
//    require amountOut > 0 and amountOut < reserveOut

// 2) Invert SE buffer: raw amountIn such that buffer claim delta ≥ claimIn (ceil)
amountInRaw = invert_buffer_preview_ceil(SE_in, claimIn)
//    pure binary search **forbidden** as primary law if SE offers closed-form invert;
//    if SE only exposes forward preview, plan may use a **bounded** invert that still
//    keeps previewSwapExactOut == execution within dust — prefer closed form when available.

// 3) Execute
take amountInRaw → buffer SE_in; unwrap exact amountOut; settle
```

**ConstProdUtils CP kernels** (on **claim** amounts, not raw when they differ):

```text
// Exact-in (floor out) — _saleQuote with amountIn := claimIn
amountInWithFee = claimIn * (feeDenominator - feePercent)
amountOut = (amountInWithFee * reserveOut) / (reserveIn * feeDenominator + amountInWithFee)

// Exact-out (ceil claimIn) — _purchaseQuote
claimIn = floor(reserveIn * amountOut * feeDenominator
                / ((reserveOut - amountOut) * (feeDenominator - feePercent))) + 1
```

Work in **wad** for reserves/claim amounts when pair decimals differ; convert raw with **floor** on out / **ceil** on inverted raw in.

**`previewSwapExactIn` / `previewSwapExactOut`:** must implement the **same** claim-in composition and match execution within dust under **non-zero SE buffer-route usage fees** (D70 / D78).

**Fee retention (trading, D29):** the 0.3% is the Uni V2-style haircut on the **claim-in** amount in the CP step — value stays in claim reserves (LPs earn volume). SE buffer fees are **separate** and may leave the swapper’s raw payment without fully entering claims (accepted; reflected in worse amountOut / higher amountIn via D78).

**Protocol fee on growth (D57 / D67 / D72):** separate Uni V2–style **`kLast` (wad product, D63) + mint LP to `address(feeTo)`** on liquidity mint/burn when oracle fee-on — **not** an extra amountIn haircut. Oracle **`dexSwapFee`** = protocol growth WAD (**not** trading fee — D57 naming callout) → generic `ownerFeeShare` (D62); **no product max cap** (D82). **Any** claim-product growth since `kLast` is fee-eligible — including **SE yield**, D29 retention, and SE-share donations (D67). **Timing:** deposit paths measure growth on **pre-buffer** claims (D72). **`feeTo` receivability** out of PRD scope (D75). **`kLast` overflow** = accepted Uni V2-class risk (D83).

**Yield:** claim per SE share ↑ moves \(x\) or \(y\) and mid without a swap; that same claim growth increases \(k\) and is **D57 fee-eligible** at the next mint/burn.

**Execution summary (public swap via V4):**

1. Quote via D78 claim-in composition (ignore sqrtPrice).  
2. `take` tokenIn from PoolManager → hook.  
3. **Buffer** full raw tokenIn into SE_in (`exchangeIn` pair→SE, pretransferred preferred; `minOut` = SE preview).  
4. **Unwrap** quoted tokenOut from SE_out via **`exchangeOut`** (exact pair out; `maxIn` = SE preview).  
5. `settle` tokenOut to PoolManager.  
6. Return `BeforeSwapDelta` (C34).  

Insufficient SE claim / SE revert → whole swap reverts.

#### 4.2.2 Single-asset zap split (O1a) — **fee-aware** ConstProdUtils + D78

Goal: user brings \(A\) of tokenIn; sell \(s\) (with D29 fee, **claim-in aware**) for other token \(o\); proportional-add \((A-s)\) and \(o\).

**Requires zap-eligible (D79):** live claims **and** `totalSupply > MINIMUM_LIQUIDITY`.

**Normative split** on 1e18-normalized claim reserves: `ConstProdUtils._swapDepositSaleAmt(A, r_in, feePercent=300, feeDenominator=100_000)`:

```text
oneMinusFee = feeDenominator - feePercent
twoMinusFee = 2 * feeDenominator - feePercent
saleAmt = (sqrt(twoMinusFee^2 * r^2 + 4 * oneMinusFee * feeDenominator * A * r)
           - twoMinusFee * r) / (2 * oneMinusFee)
// cap saleAmt ≤ A; peer may fall back to A/2 only if sqrt edge case
// saleAmt is in **raw tokenIn units** of the sold slice (same units as A)
```

**Internal swap of `saleAmt`:** same **D78 claim-in composition** as public exact-in:

```text
claimIn = preview_buffer_pair_to_claim(SE_in, saleAmt)
amountOtherOut = _saleQuote(claimIn, r_in, r_out, 300, 100_000)  // claim CP, not raw saleAmt into CP
// execute: buffer saleAmt; unwrap amountOtherOut; emit ZapSwap(sender, tokenIn, tokenOut, saleAmt, amountOtherOut)
```

Fee-less special case (\(feePercent=0\)) of the split formula reduces to \(s=\sqrt{r(r+A)}-r\); **v1 must use feePercent=300**, not the fee-less root alone. When SE buffer is 1:1, `claimIn == saleAmt` and zap matches classic ConstProdUtils chain.

**Forbidden:**

- Invented quadratics that ignore the 0.3% fee  
- Binary-search solvers as primary law for the split  
- Using a different CP fee on zap than on public swaps  
- Raw `saleAmt` into CP when SE buffer fees make `claimIn ≠ saleAmt` (D78)

SE buffer/unwrap fees may desync ratio after the internal swap → **one** proportional clamp + refund (C5), not a re-solve of the split.

**`previewZapSplit` (D65):** must return the **same** split amounts execution will use after SE-aware simulation (closed-form O1a → D78 claim-in swap sim → simulated SE buffer/unwrap → clamp/refund residual), so `amountToSwap` / `amountOtherOut` / `amountKeptIn` match execution within dust **even with non-zero SE usage fees**.

### 4.3 Buffer (pair token → SE shares)

Used on: proportional add; swap token in; zap sold slice; zap post-swap add legs.

See §4.5.1 for exact SE call.

### 4.4 Unwrap (SE shares → pair token)

Used on: withdraw both legs; swap token out; zap internal swap tokenOut.

See §4.5.2–4.5.3 for exact SE calls.

Hook must not retain free pair-token inventory as a product after successful ops (C20–C21 / D71): liquidity residuals above dust refund to `msg.sender`; swaps full-settle or revert.

### 4.5 SE call matrix (normative)

Use Crane `IStandardExchangeIn` / `IStandardExchangeOut` only. **No** protocol-vault math on the hook.

| Op | When | SE API | Notes |
|----|------|--------|-------|
| **Claim read** | views / quotes / mint measurement | `previewExchangeIn(SE, seBal, pairToken)` | D15; **fee-inclusive SoT** (D73); **re-preview after SE settle before mint** (C37); **D57 pre-buffer read** uses claims before buffer (D72) |
| **Buffer** | deposit, swap-in, zap | `exchangeIn(pairToken → SE)` exact-in | minOut = **fee-inclusive** SE preview (C16 / D73); **prefer pretransfer** pair token to SE then `pretransferred=true`; DoD non-zero SE usage fee on these routes (D70) |
| **Unwrap withdraw** | burn LP | `exchangeIn(SE → pairToken)` exact-in on **pro-rata SE share balances** (C33 — not claim-weighted) | recipient user `to` or hook-then-transfer; exit usage fee **not** required for DoD (D70); preview is fee-inclusive SoT (D73) |
| **Unwrap swap/zap out** | public swap out, zap swap leg | `exchangeOut(SE → pairToken)` exact-out | maxIn = **fee-inclusive** SE preview (D73) |

`deadline` on SE calls = `block.timestamp` when required (C17).

**Law (D73):** the hook never re-implements SE usage-fee formulas. Bound SEs must keep `previewExchange*` == execution with fees inside the preview.

---

## 5. Liquidity (normal CP)

### 5.0 Deposit law summary

| | Proportional (`deposit`) | Single-asset (`depositSingle`) |
|--|--------------------------|--------------------------------|
| Inputs | `amount0`, `amount1` both used (after clamp); **pool currency order** | One pair token + `amountIn` |
| Requires live pool? | No for first mint; yes ratio from existing claims if live | **Zap-eligible (D79):** \(x>0,y>0\) **and** `totalSupply > MINIMUM_LIQUIDITY` |
| Internal swap? | No | **Yes** (portion of input; claim-in CP — D78) |
| SE | Buffer both legs | Buffer/unwrap as in swap, then buffer both for add |
| LP | Fungible dual | **Same** fungible dual |
| Cost to user | SE buffer fees only (no pool swap) | **CP impact on zap slice** + SE fees — **accepted** |
| Slippage | `minLpAmount`, `deadline` | `minLpAmount`, `deadline` |
| Funding | transferFrom **or** Permit2 | transferFrom **or** Permit2 |
| After full exit (only MINIMUM_LIQUIDITY) | **Yes** — subsequent mint ratio clamp (D76) | **No** — reverts (C36 / D79) |

### 5.1 Proportional deposit (dual-asset)

```solidity
function deposit(
    uint256 amount0,      // currency0
    uint256 amount1,      // currency1
    address to,
    uint256 minLpAmount,
    uint256 deadline
) external returns (uint256 lpAmount, uint256 used0, uint256 used1);

// Permit2 variants (SignatureTransfer + AllowanceTransfer both in DoD):
// depositWithPermit2(...) — exact struct/signature per peer Permit2 patterns
```

**Rules:**

1. Require `block.timestamp <= deadline`.  
2. Require `amount0 > 0` and `amount1 > 0` (proportional path is dual-asset only; single-asset users call `depositSingle`).  
3. Pull tokens via `transferFrom(msg.sender, …)` **or** Permit2 (variant).  
4. **D57 first (if fee-on and not first mint):** mint protocol LP to `address(feeTo)` from k growth measured on **pre-buffer** pool-order claims vs `kLast` (D72); then use **post-dilution** `totalSupply` for user mint math. First mint: no protocol mint while `kLast == 0`. If protocol mint reverts (`feeTo` non-receivable, etc.), whole deposit reverts — **no** best-effort skip (D75).  
5. **First mint** (`totalSupply == 0` after any no-op fee step): buffer both full amounts; mint under O1/O5; establishes \(k\). Revert if `sqrt(xN*yN) < MINIMUM_LIQUIDITY`.  
6. **Subsequent mint** whenever `totalSupply > 0` (D76) — including after full user withdraw leaves only **MINIMUM_LIQUIDITY** on `address(0)` with residual claims (C36). Requires live claims \(x>0,y>0\); compute ideal ratio from **pre-buffer** claims \(x,y\); **clamp** so used amounts are proportional; **refund** surplus to **`msg.sender`**. **Never** re-run geometric first-mint while supply > 0.  
7. Buffer `used0` → SE for currency0, `used1` → SE for currency1 (SE previews fee-inclusive — D73).  
8. Re-preview claims (O11 / C37); mint **user** LP from claim deltas (O1).  
9. Require `lpAmount >= minLpAmount`.  
10. Update `kLast` per §7.4 (post-op wad product when fee-on).  
11. Free pair-token residual above dust → refund **`msg.sender`** (D71).  
12. `previewDeposit` must match execution (D61 protocol dilution + refund/used amounts included; SE fee-inclusive previews — D73).

### 5.2 Single-asset deposit (internal zap-in) — **v1 required**

```solidity
function depositSingle(
    address tokenIn,
    uint256 amountIn,
    address to,
    uint256 minLpAmount,
    uint256 deadline
) external returns (uint256 lpAmount);

// + Permit2 variants (both SignatureTransfer and AllowanceTransfer)
```

**Rules:**

1. Require `block.timestamp <= deadline`.  
2. `tokenIn` is one of the bound pair tokens; `amountIn > 0`.  
3. Require **zap-eligible (D79):** live dual claims \(x > 0\), \(y > 0\), **and** `totalSupply > MINIMUM_LIQUIDITY`; else **revert**. (Empty book **or** only MINIMUM_LIQUIDITY residual after full user exit → revert; re-seed with dual-asset `deposit` only — C36.)  
4. **D57 first (if fee-on):** mint protocol LP to `address(feeTo)` from k growth on **pre-buffer / pre-zap** pool-order claims vs `kLast` (D72); then user mint uses **post-dilution** `totalSupply`.  
5. Compute split via closed-form Uni V2 zap analogue on normalized claims (O1a) — claims for the split are the live book **before** this op’s buffer (same pre-op read as D57).  
6. **Internal swap** of sold portion: **D78 claim-in composition** + same buffer tokenIn → SE_in and unwrap tokenOut from SE_out as public swaps — **via SE helpers only** (O9), not PoolManager. **Emit `ZapSwap`** (D77 / §7.5) with raw amounts actually swapped.  
7. **Proportional add** of kept tokenIn + received tokenOut (clamp if needed; residual refund to `msg.sender`).  
8. Re-preview claims; mint **same** fungible **user** LP as §5.1.  
9. Require `lpAmount >= minLpAmount`.  
10. Update `kLast` per §7.4 (post-op; captures D29 retention from the internal zap swap when fee-on).  
11. Free pair-token residual above dust → refund **`msg.sender`** (D71).  
12. Book remains dual-sided; no single-asset receipt.  
13. **Product disclosure:** single-asset depositors accept rebalance cost; UI/docs should not imply HODL-equivalent value.  
14. `previewDepositSingle` returns expected **LP amount** (preview == execution within dust, including D61 fee-on dilution); **reverts / view-fails when not zap-eligible**.  
15. **`previewZapSplit` (D65):** returns `amountToSwap`, `amountOtherOut`, `amountKeptIn` with **strict preview == execution** within dust — **SE-aware** via D78 + fee-inclusive SE previews (D73) under non-zero **buffer-route** SE usage fees (D70); not disclosure-only; same zap-eligible gate.

**Empty book / dust-only residual:** single-asset path reverts; only proportional dual-asset can bootstrap or re-seed after full user exit.

### 5.3 Withdraw

```solidity
function withdraw(
    uint256 lpAmount,
    address to,
    uint256 minAmount0,   // currency0
    uint256 minAmount1,   // currency1
    uint256 deadline
) external returns (uint256 amount0, uint256 amount1);
```

- Require `block.timestamp <= deadline`.  
- **D57 first (if fee-on):** mint protocol LP to `address(feeTo)` from k growth since `kLast` (current claims vs `kLast` before user burn — D72), then use **post-dilution** `totalSupply` (same order as §7.4). Failed mint → whole withdraw reverts (D75).  
- Burn `lpAmount` of hook LP tokens from `msg.sender`.  
- `seOut_i = seBal_i * lpAmount / totalSupply` (**pre-user-burn**, post-protocol-mint — C33), both legs. **Pro-rata is on SE share balances**, not claim-weighted amounts — LPs own a fraction of each SE pile; yield accrues in claim (pricing) without changing share pro-rata.  
- **Unwrap** each leg SE → pair token via fee-inclusive SE previews (D73); exit usage fee not required for DoD (D70).  
- Transfer pair tokens to `to` in pool currency packing for return values.  
- Require `amount0 >= minAmount0` and `amount1 >= minAmount1`.  
- Update `kLast` per §7.4.  
- Free pair-token residual above dust → refund **`msg.sender`** (D71).

LP is always a claim on **both** buffered legs (pro-rata SE shares → unwrap to pair tokens).

### 5.4 What is explicitly forbidden

- Minting LP for increasing only one claim without the zap swap (true single-sided add).  
- Separate ERC-20 or NFT for “WETH-only LP” vs “USDC-only LP”.  
- InitPrice / one-sided pricing modes.  
- Using native V4 `modifyLiquidity` for user LP.  
- Relying on V4 sqrtPrice as the trading mid.

---

## 6. Swaps (V4)

### 6.1 Permissions

| Hook | Enabled |
|------|---------|
| beforeInitialize | yes — pair tokens + fee=0 + **one-pool hard guard** (D69) |
| beforeAddLiquidity | yes — **always revert** |
| beforeSwap | yes |
| beforeSwapReturnDelta | yes |
| afterSwap / CL liquidity deltas | no |

### 6.2 Path (exact-in)

```text
require x > 0 && y > 0
claimIn = SE fee-inclusive buffer preview of raw amountIn     // D78
quote amountOut = CP(_saleQuote) on claimIn vs claims         // §4.2.1 + D29
take tokenIn → buffer into SE_in                              // §4.5.1
unwrap amountOut from SE_out                                  // §4.5.3 exact-out preferred
settle tokenOut
return BeforeSwapDelta (pattern-copy settle order)            // C34
```

### 6.3 Path (exact-out)

```text
require x > 0 && y > 0
claimIn = CP(_purchaseQuote) for exact amountOut              // §4.2.1 + D29
amountInRaw = invert SE buffer preview (ceil) for claimIn     // D78
take exactly amountInRaw tokenIn → buffer SE_in
unwrap exact amountOut from SE_out
settle tokenOut
return BeforeSwapDelta
```

Insufficient out claim / SE shortfall → revert (no partial fill).

Zap internal swap **must** use the same **claim-in CP + SE buffer/unwrap** economics as public swaps (shared library functions; O9 — no PoolManager round-trip; D78).

---

## 7. Package surface

```text
contracts/hooks/uniswap/v4/standardExchange/dual/
  UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md
  UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on

  interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol
  UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol
  UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol
  UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol   # optional pure math split
  UniswapV4DualStandardExchangeBufferConstantProductHookTarget.sol
  UniswapV4DualStandardExchangeBufferConstantProductHook.sol
  UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol
```

**Legacy scaffold names** (`UniswapV4DualBufferPricingHook*`) are non-authoritative (D56) — rename to D1 on implement.

### 7.1 Required public surface (D68)

**§7.1 is the required product surface (D68 / C60) — not an open sketch.** Plan may add deploy/view helpers only. Names below are normative unless marked “or equivalent single getter.”

```solidity
interface IUniswapV4DualStandardExchangeBufferConstantProductHook {
    // --- Bindings ---
    function poolManager() external view returns (address);
    /// @notice Vault fee oracle for protocol growth fee + feeTo (D57).
    function feeOracle() external view returns (address);
    /// @notice Uniswap well-known Permit2 (constant; D51 / D54).
    function permit2() external view returns (address);
    function standardExchange0() external view returns (address);
    function standardExchange1() external view returns (address);
    /// @notice Pair token bound to SE0 (ctor leg; not necessarily pool currency0).
    function token0() external view returns (address);
    /// @notice Pair token bound to SE1.
    function token1() external view returns (address);
    /// @notice Pool currency0 = address-min of bound pair tokens.
    function currency0() external view returns (address);
    /// @notice Pool currency1 = address-max of bound pair tokens.
    function currency1() external view returns (address);

    // --- Claims (fee-inclusive SE previews — D73) ---
    /// @notice SE→pair-token claim for hook-held SE0 shares (ctor leg).
    function claimSupply0() external view returns (uint256);
    function claimSupply1() external view returns (uint256);
    /// @notice Claim of pool currency0 / currency1 legs (for CP x,y).
    function claimSupplyCurrency0() external view returns (uint256);
    function claimSupplyCurrency1() external view returns (uint256);

    // --- Fees / kLast (required — D59 / D68) ---
    /// @notice CP trading fee numerator (300) or document as constant.
    function tradingFeePercent() external view returns (uint256);
    /// @notice CP trading fee denominator (100_000) or document as constant.
    function tradingFeeDenominator() external view returns (uint256);
    /// @notice Resolved protocol **growth** fee WAD for this hook (oracle three-tier).
    /// @dev Oracle name `dexSwapFee` — **not** the D29 0.3% trading fee (D57 naming callout). No product max cap (D82).
    function dexSwapFee() external view returns (uint256);
    /// @notice Resolved feeTo for protocol LP mint (address(feeTo)).
    function feeTo() external view returns (address);
    /// @notice Or single: dexSwapFeeAndFeeTo() → (feeTo, dexFeeWad). **Exactly one style** (pair of getters **or** combined) satisfies DoD — not both required.
    // function dexSwapFeeAndFeeTo() external view returns (address feeTo, uint256 dexFeeWad);
    /// @notice Last wad claim product xN*yN when fee-on; 0 when fee-off (D63).
    function kLast() external view returns (uint256);

    // --- Liquidity ---
    /// @notice Proportional dual-asset deposit. amount0/amount1 = pool currency0/currency1.
    /// @return lpAmount Hook LP tokens minted to `to`.
    function deposit(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external returns (uint256 lpAmount, uint256 used0, uint256 used1);

    /// @notice Single-asset deposit via internal zap-in then proportional add.
    /// @dev Reverts unless zap-eligible (D79): live claims and totalSupply > MINIMUM_LIQUIDITY.
    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external returns (uint256 lpAmount);

    /// @notice Proportional deposit funded via Permit2 SignatureTransfer (both currencies).
    /// @dev Exact Permit2 batch/struct types follow IAllowanceTransfer / ISignatureTransfer peers.
    function depositWithPermit2Signature(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 lpAmount, uint256 used0, uint256 used1);

    /// @notice Proportional deposit funded via Permit2 AllowanceTransfer (both currencies).
    function depositWithPermit2Allowance(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external returns (uint256 lpAmount, uint256 used0, uint256 used1);

    function depositSingleWithPermit2Signature(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 lpAmount);

    function depositSingleWithPermit2Allowance(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external returns (uint256 lpAmount);

    function withdraw(
        uint256 lpAmount,
        address to,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1);

    // --- Previews ---
    function previewDeposit(uint256 amount0, uint256 amount1)
        external
        view
        returns (uint256 lpAmount, uint256 used0, uint256 used1);

    /// @notice Expected hook LP tokens from single-asset deposit. Reverts/view-fails if not zap-eligible (D79).
    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 lpAmount);

    /// @notice Zap split (raw token units). Strict preview == execution within dust (D65);
    /// SE-aware via D78 claim-in + fee-inclusive SE previews (D73), not disclosure-only. Same D79 gate.
    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (
            uint256 amountToSwap,
            uint256 amountOtherOut,
            uint256 amountKeptIn
        );

    function previewWithdraw(uint256 lpAmount)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    /// @notice Claim-in CP composition (D78) + SE fee-inclusive previews (D73); preview == execution under SE fees.
    function previewSwapExactIn(bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function previewSwapExactOut(bool zeroForOne, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    // --- Minimal ERC-20 + metadata (required on same hook contract — O7 / O10 / D52) ---
    // name(), symbol(), decimals()==18, totalSupply(), balanceOf, allowance,
    // transfer, approve, transferFrom, Transfer/Approval events
    //
    // NOT required: isExpectedHook (D80 — factory/internal only)
}
```

**Permit2 notes:** see **§7.3** (packing is DoD). Swaps: **no** hook Permit2.

### 7.2 FactoryService

```solidity
function deployHook(
    ICreate3FactoryProxy create3Factory,
    IPoolManager poolManager,
    IVaultFeeOracleQuery feeOracle,
    address se0,
    address token0,
    address se1,
    address token1,
    string memory saltNamespace
) internal returns (address hook);
```

Salt material and idempotency: **C28–C30**, D37–D38, D53 (**no** Permit2 in salt; **include feeOracle**).

Ctor immutables: `(poolManager, feeOracle, se0, token0, se1, token1)`.

### 7.3 Permit2 packing (normative DoD)

Canonical Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3`.  
Interfaces: Crane `ISignatureTransfer` / `IAllowanceTransfer`.  
**No witness** in v1 (plain transfer-to-hook; spender = hook).  
Owner of tokens = **`msg.sender`**. Recipient of pulls = **`address(this)`** (hook).

#### SignatureTransfer — proportional `depositWithPermit2Signature`

```text
// Dual-token batch (required for proportional dual pull)
// Index order is normative (C45): permitted[0] = currency0, permitted[1] = currency1
permit2Data = abi.encode(
  ISignatureTransfer.PermitBatchTransferFrom permit,  // permitted.length == 2
  bytes signature
)
// Requirements (else revert):
//   permit.permitted[0].token == currency0 && requested/signed amount covers amount0
//   permit.permitted[1].token == currency1 && requested/signed amount covers amount1
// Call: permitBatchTransferFrom → transferDetails[i].to = hook,
//       transferDetails[0].requestedAmount = amount0,
//       transferDetails[1].requestedAmount = amount1
// Shared core: _deposit after both tokens on hook
```

#### SignatureTransfer — single-asset `depositSingleWithPermit2Signature`

```text
permit2Data = abi.encode(
  ISignatureTransfer.PermitTransferFrom permit,  // single TokenPermissions for tokenIn
  bytes signature
)
// Call: permitTransferFrom → to = hook, requestedAmount = amountIn
// Shared core: _depositSingle after tokenIn on hook
```

#### AllowanceTransfer — `depositWithPermit2Allowance` / `depositSingleWithPermit2Allowance`

```text
// No permit2Data.
// Pre: user ERC-20 approved Permit2; user set Permit2 allowance for (token, hook) via IAllowanceTransfer.approve
// Proportional: transferFrom currency0 for amount0, then currency1 for amount1 (pool order)
// Single: transferFrom tokenIn for amountIn
// Then shared _deposit / _depositSingle
```

**DoD tests:** R2–R5 execute real Permit2 at well-known address with this packing; wrong signature / wrong spender / expired / insufficient allowance / wrong batch token order revert.

### 7.4 Protocol growth fee surface (D57 / D61–D63 / D67 / D72)

```text
// Resolve oracle (C44): use query getters (already apply three-tier defaults)
(feeTo, dexFeeWad) = feeOracle.dexSwapFeeAndFeeToOfVault(address(this))
// feeTo is IFeeCollectorProxy; mint recipient = address(feeTo)  (C43)
// dexFeeWad = protocol GROWTH share (despite oracle name "dexSwapFee") — not D29 trading fee
// No product max cap on dexFeeWad / ownerFeeShare (D82)
ownerFeeShare = dexFeeWad * 100_000 / 1e18   // floor; D62
feeOn = (address(feeTo) != 0 && dexFeeWad != 0)

// Claims for k: always wad-normalized pool-order claims (D63)
// xN = toWad(claimSupplyCurrency0(), decimals(currency0))
// yN = toWad(claimSupplyCurrency1(), decimals(currency1))
// kProduct = xN * yN

// --- Deposit / depositSingle (D72 Uni V2 peer) ---
// 1. Read preBufferK from claims BEFORE this op’s buffer/zap
// 2. if feeOn && kLast != 0:
//      protocolLp = ConstProdUtils._calculateProtocolFee(
//                     totalSupply, preBufferK, kLast, ownerFeeShare)
//      if protocolLp > 0: mint protocolLp to address(feeTo)
// 3. Clamp/refund as needed; buffer / internal zap; re-preview claims
// 4. Mint user LP from claim deltas using post-dilution totalSupply
// 5. if feeOn: kLast = postOpK (wad product after buffer/add)
//    if !feeOn: kLast = 0
// User’s newly buffered capital is NOT included in preBufferK (not taxed as growth).

// --- Withdraw (D72) ---
// 1. Read currentK from claims before user burn
// 2. if feeOn && kLast != 0: mint protocol LP from (currentK, kLast) as above
// 3. Burn user LP; seOut from post-protocol-mint totalSupply (C33); unwrap
// 4. if feeOn: kLast = postOpK; if !feeOn: kLast = 0

// Previews (D61): same fee-on mint simulation before user LP/out math
// so previewDeposit / previewDepositSingle / previewWithdraw == execution
//
// k growth sources (D67) — all fee-eligible when fee-on:
//   D29 swap fee retained in claims, SE yield on hook-held shares, SE-share donations
// Do NOT special-case yield (no refresh-kLast-without-mint for pure yield)
```

Repo stores `kLast` (uint256 wad product). First mint: no protocol mint while `kLast == 0`; after first mint establishes reserves, set `kLast = xN * yN` when fee-on.

### 7.5 Events (normative DoD — C22 / C46 / D77)

```solidity
event Deposit(
    address indexed sender,
    address indexed to,
    uint256 amount0,      // pool currency0 used (after clamp)
    uint256 amount1,      // pool currency1 used
    uint256 lpAmount
);

/// @dev `amountIn` = **full user-supplied / pulled input** (D81), not net after residual refund.
event DepositSingle(
    address indexed sender,
    address indexed to,
    address tokenIn,
    uint256 amountIn,
    uint256 lpAmount
);

event Withdraw(
    address indexed sender,
    address indexed to,
    uint256 lpAmount,
    uint256 amount0,      // pool currency0 paid out
    uint256 amount1       // pool currency1 paid out
);

/// @notice Internal zap rebalance (O9) — not a V4 PoolManager swap. Required so indexers
/// see zap volume without relying on pool Swap logs (D77).
/// @dev amountIn/amountOut = raw pair-token amounts on the internal swap leg (after sold-slice clamp).
event ZapSwap(
    address indexed sender,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,     // raw tokenIn sold in the internal swap leg
    uint256 amountOut     // raw tokenOut received from SE unwrap
);
```

---

## 8. Lifecycle

```text
0. Ensure generic ERC-4626 SE package routes are complete (D60 / single-hook §6.0)
1. Deploy two ERC-4626 SE vaults (test tokens in hermetic DoD) with pair tokens in vaultTokens
2. pkg.deployVault(args, mineNonce) → registered bootstrap diamond (vault pair + package-as-init)
3. Product door then production ABI (staged init PRD):
     - deployPair(tokenA, tokenB) for the bound pair (either order; currencies address-sorted, fee=0, hooks=hook)
     - or raw PoolManager.initialize of that product PoolKey
     - tests: tickSpacing=60, 1:1 mid
     - extra tick/fee keys are not the product door; second product-key initialize → AlreadyInitialized (D69)
     - finalizeInitialization Adds the production ABI
4. First LP: deposit(amount0, amount1, ...) both non-zero (production ABI after finalize)
     → D57 no-op (kLast==0) → buffer both → re-preview claims → mint LP → set kLast if fee-on
   (swaps need live claims)
5. Further LPs: deposit and/or depositSingle when zap-eligible (D79; zap with 0.3% claim-in internal swap — D78); ERC-20 or Permit2
   (fee-on: protocol LP from pre-buffer k growth → buffer/zap → user mint → kLast post-op)
   After full user exit (only MINIMUM_LIQUIDITY left): deposit only — depositSingle reverts
6. Swaps via V4 (claim-in CP + 0.3% fee retained for LPs — D78 / D29)
7. withdraw → protocol mint if fee-on → unwrap both SEs → pair tokens (pool order) → kLast post-op
```

---

## 9. Testing (production-first)

0. **Phase 0 / prerequisite green (D60, D66):** dual plan **owns** verifying/finishing generic ERC-4626 SE closed-form pair↔SE matrix before dual DoD.  
1. Real hook (FactoryService + mine), real PoolManager, **two ERC-4626 SE vaults with test tokens** (C27, D60), real Permit2 at well-known address, real **Vault Fee Oracle** — no mock SUT.  
2. **Hermetic suite** — cover at least:  
   - deploy validation (D5–D7; feeOracle non-zero)  
   - product door via `deployPair` then finalize; **second product-key initialize reverts** (D69); addLiquidity reverts; C6 init convention  
   - first proportional dual deposit; MINIMUM_LIQUIDITY to `address(0)`  
   - first mint reverts if geometric LP &lt; MINIMUM_LIQUIDITY  
   - subsequent proportional: clamp + refund to `msg.sender`; preview == execution  
   - **after full user withdraw (only MINIMUM_LIQUIDITY left):** next proportional deposit uses **subsequent** mint / ratio clamp — not geometric first mint (D76)  
   - minLpAmount / deadline / minAmount0/1  
   - depositSingle both directions; previewDepositSingle + **previewZapSplit strict == execution** (D65), including **non-zero SE usage fees on buffer/share-mint routes** (D70 / D73 / D78 claim-in)  
   - depositSingle reverts if not live **or** if only MINIMUM_LIQUIDITY residual after full user exit (D79); **ZapSwap event** emitted on zap internal swap (D77)  
   - **`DepositSingle.amountIn`** logs full pulled input (D81)  

   - ERC-20 + **Permit2 packing §7.3** (Signature batch dual in **pool order**, Signature single, Allowance dual, Allowance single); wrong batch order reverts  
   - **required surface** fee views + `kLast()` + ERC-20 metadata (D68 / §7.1)  
   - amount0/1 = pool currency order when ctor leg order ≠ sort  
   - swap exact-in/out both ways **with 0.3% fee**; product mid from claims not sqrtPrice; **previewSwap == execution under non-zero SE buffer fees via claim-in composition** (D78 / D73)  

   - **LPs benefit from swap volume** (reserve/claim growth vs fee-less counterfactual or k growth check)  
   - **protocol growth fee:** non-zero resolved `dexSwapFeeOfVault(hook)` + non-zero `feeTo`; mint/burn mints protocol LP to `address(feeTo)` and updates **wad** `kLast`; fee-off path does not  
   - **D72 timing:** fee-on deposit does **not** mint protocol LP solely from the user’s own buffered capital in that op (pre-buffer k); growth from prior swaps/yield does mint  
   - **fee-on preview == execution** for deposit / depositSingle / withdraw (D61) including protocol dilution  
   - mixed-decimal pair tokens: wad `kLast` and CP math remain correct (D63)  
   - withdraw unwrap both legs; pool-order returns; pro-rata **SE share balances** (C33)  
   - yield accrual moves claim/mid  
   - **yield → D57:** fee-on + yield growth (no intermediate swap) → next mint/burn mints protocol LP (D67)  
   - **non-zero SE usage fees on buffer routes** (both SE legs; proportional + zap + swaps) — preview == execution via fee-inclusive SE previews (D73); exit fee-less OK (D70)  
   - residual free pair tokens after liquidity op refunded to `msg.sender` when above dust (D71)  
   - nonReentrant: nested reenter deposit/withdraw from hostile token or callback **reverts**  
   - true single-sided / InitPrice **absent**  
   - events §7.5 including **ZapSwap**  
3. **Fork suite required (D64 / D74):** **Base mainnet fork** and **Robinhood Chain (chain ID 4663) fork**. Prefer live PoolManager + Permit2 + fee oracle; **if missing, deploy production-equivalent bytecode on the fork** (Permit2 at well-known address when possible). Dual ERC-4626 SE legs; deposit → swap → withdraw smoke with fees on. Not mock SUT.  
4. **Pure math unit tests optional** — not DoD. Prefer **integration** proof that the **V4 pool attached to the hook** quotes/swaps as expected (hook path, not bare ConstProdUtils grid).

---

## 10. Security notes

1. **Multi-pool reuse hard-rejected** (D69) — shared inventory would couple pools; second `beforeInitialize` reverts.  
2. SE donations dilute LPs.  
3. **Zap is sandwichable** like swap + add — same MEV class; **`minLpAmount` + `deadline`** are the v1 user protection (not a free lunch).  
4. Rounding: never under-collateralize unwrap; ceil exact-out inputs (O12).  
5. Reentrancy: liquidity paths **`nonReentrant`** (D58); SE + PoolManager locks on swap path.  
6. Do not market single-asset deposit as “no slippage.”  
7. Permit2 packing §7.3 must not be forgeable across deposit types.  
8. Fee-on-transfer pair tokens unsupported.  
9. MINIMUM_LIQUIDITY permanently locked to `address(0)` (O5).  
10. Protocol growth fee dilutes LPs to `feeTo` (D57) — document for integrators; **includes yield-driven k growth** (D67); deposit paths measure k **pre-buffer** (D72).  
11. Residual free pair tokens above dust refund to **`msg.sender`** (D71) — not `to`.  
12. **`feeTo` receivability** is integrator/oracle config (D75) — not a dual-hook special case; failed protocol mint reverts the liquidity op.  
13. Hook trusts SE **fee-inclusive** previews (D73); do not fork SE fee logic into the hook.  
14. **Claim-in composition (D78)** — raw amountIn into CP while SE buffer fees reduce claim is a solvency footgun; tests must cover non-zero buffer fees.  
15. **Zap after dust residual forbidden (D79)** — sandwich/MEV surface only exists when zap-eligible.

---

## 11. Definition of done

1. D1–D83 product decisions implemented or waived in PRD revision log.  
2. §3 (incl. §3.1–§3.4) locks + §4 (incl. D78 algorithms) + §7.3 Permit2 packing + §7.4 protocol growth fee + §7.5 events (incl. **ZapSwap**) implemented.  
3. **Dual fee model:** D29 0.3% in reserves + D57 protocol growth mint to `address(feeTo)` via generic `ownerFeeShare` (D62) + wad `kLast` (D63); **yield-eligible** (D67); **pre-buffer k on deposits** (D72); **no product fee-share cap** (D82).  
4. Liquidity paths **nonReentrant** (D58).  
5. FactoryService deploy green (salt includes feeOracle; not Permit2); **`isExpectedHook` factory-only** (D80).  
6. **D60 / D66:** generic ERC-4626 SE package routes complete (dual plan Phase 0 owned); SE previews fee-inclusive + preview==execution (D73).  
7. §9 **hermetic + Base fork + Robinhood Chain (4663) fork** green (D74 deploy-if-missing); non-zero SE **buffer-route** usage fees (D70) + non-zero dex protocol fee; fee-on preview == execution (D61); **strict `previewZapSplit` == execution under SE fees** (D65); **swap preview == execution under SE fees via claim-in composition** (D78); Permit2 packing tests; second-pool init reverts (D69); subsequent mint after MINIMUM_LIQUIDITY residual (D76); **`depositSingle` reverts on MINIMUM_LIQUIDITY-only residual** (D79).  
8. Events Deposit / DepositSingle (full pull amountIn — D81) / Withdraw / **ZapSwap** per §7.5.  
9. Pool-attached behavior proven (swaps/quotes via V4 + hook); pure math unit tests optional.  
10. **Required public surface** (§7.1 / D68): fee views, `kLast()`, trading-fee constants, full ERC-20 + metadata, liquidity/previews/bindings — **not** `isExpectedHook`.  
11. **Process:** rewritten implementation plan accepted; implementors use that plan as SoT.

---

## 12. Consistency checklist

| Requirement | PRD location | Status |
|-------------|--------------|--------|
| CP 0.3% retained in reserves | D29, §4.2.1 | Locked |
| Protocol growth fee: generic ownerFeeShare from WAD | D57, D62, §7.4 | Locked |
| `dexSwapFee` naming = protocol growth, not trading fee | D57 | Locked v3.12 |
| **No product max cap on dexFeeWad / ownerFeeShare** | D82 | Locked v3.12 |
| `kLast` = wad claim product \(x_N \cdot y_N\); overflow accepted | D63, D83, §7.4 | Locked v3.12 |
| **D57 deposit timing: pre-buffer k (Uni V2 peer)** | D72, §5.1–§5.2, §7.4 | Locked |
| Fee-on previews include protocol mint dilution | D27, D61 | Locked |
| Zap fee-aware ConstProdUtils + claim-in | O1a, D78, §4.2.2 | Locked v3.12 |
| **Strict SE-aware `previewZapSplit` == execution** | D65 | Locked |
| **Yield (and any k growth) D57 fee-eligible** | D67 | Locked |
| SE matrix + pretransfer + tight preview | §4.5 | Locked |
| Re-preview claims before mint | O11, C37 | Locked |
| nonReentrant liquidity | D58, C26 | Locked |
| ERC-4626 SE hard prereq + two SE test legs | D60, D43, C27 | Locked |
| **Dual plan Phase 0 owns ERC-4626 completeness** | D66 | Locked |
| **Required public surface (fee + kLast + ERC-20); no isExpectedHook on ABI** | D68, D59, D80, §7.1 | Locked v3.12 |
| Deposit without V4 init; init needs no liquidity | C13 | Locked |
| **One pool per hook hard-revert** | D69, D34, C7 | Locked |
| Permit2 well-known + packing **pool-order batch** | C18–C19, C45, §7.3 | Locked |
| Events Deposit / DepositSingle (full pull) / Withdraw / **ZapSwap** | C22, D77, D81, §7.5 | Locked v3.12 |
| LP decimals 18; symbol pool order | O4, O10 | Locked |
| Hermetic + **Base + Robinhood 4663 forks**; deploy-if-missing stack | §9, D64, D74 | Locked |
| **SE usage fee DoD: buffer/share-mint only** | D70 | Locked |
| **SE previews fee-inclusive SoT** | D73 | Locked |
| **Claim-in CP composition for swaps + zap** | D78, C65, §4.2.1 | Locked v3.12 |
| **Zap-eligible = live + totalSupply > MINIMUM_LIQUIDITY** | D79, C36, C64, §5.2 | Locked v3.12 |
| **Subsequent mint while totalSupply > 0** | D76, C36 | Locked |
| **feeTo receivability out of PRD scope** | D75 | Locked |
| **Residual free pair tokens → `msg.sender`** | D71, D41 | Locked |
| Pure math unit tests optional; pool behavior required | §9 | Locked |
| Plan = implementor SoT | C11 | Locked |
| Product name `UniswapV4DualStandardExchangeBufferConstantProductHook` | D1 | Locked |
| Salt `uv4-dual-se-buffer-constant-product-hook-`; LP `DSEBCP-` | D37, O4 | Locked |
| Canonical law location (no layered C pointer tables) | C68, §3.4 | Locked v3.12 |

---

## 13. Guidance for implementation-plan authors

*(For the agent that rewrites the plan from this **accepted v3.12** PRD.)*

1. Cite every **D/O/C** and §4 / §7.3 / §7.4 / §7.5 / §17; plan becomes **implementor SoT** (C11). **Do not** re-derive law from retired layered lock tables (C68).  
2. File map + phase order; **rename to D1** `UniswapV4DualStandardExchangeBufferConstantProductHook` (and matching interface/files/salt); scaffold rewrite scope (D56). Rename stale plan file away from `…DUAL_BUFFER_PRICING…` when rewriting.  
3. **Phase 0 (D66):** dual plan **owns** verifying/finishing generic ERC-4626 SE package completeness (D60 / single-hook §6.0) before dual DoD — do not assume green without checking. SE previews must be **fee-inclusive + preview==execution** (D73).  
4. ConstProdUtils: trading 300/100_000; zap `_swapDepositSaleAmt`; protocol fee via **generic** `_calculateProtocolFee` with `ownerFeeShare = dexFeeWad * 100_000 / 1e18` (**no product cap** — D82); store **wad** `kLast` (**overflow accepted** — D83); **pre-buffer k on deposit/depositSingle** (D72).  
5. **Swaps + zap:** implement **D78 claim-in composition** (§4.2.1) — CP on SE buffer claim delta, not raw amountIn when they differ. Previews: fee-on paths simulate protocol mint before user LP/out math (D61); **`previewZapSplit` and swap previews** must match under **buffer-route** SE usage fees (D65 / D70 / D78).  
6. SE matrix §4.5; feeOracle + D57 (**dexSwapFee = growth share, not trading fee**); **yield growth is D57 fee-eligible** (D67); nonReentrant liquidity; mint protocol LP to `address(feeTo)` (receivability out of scope — D75).  
7. Permit2 packing **§7.3** — dual Signature batch **strict pool currency index order** (C45).  
8. Salt: feeOracle yes, Permit2 no (C28); deployHook includes feeOracle (§7.2 / §8); **`isExpectedHook` factory-only** (D80).  
9. **One-pool Repo flag** (D69); residual refund to `msg.sender` (D71); **subsequent mint** when `totalSupply > 0` (D76); **`depositSingle` only when zap-eligible** (D79).  
10. TestBase: two ERC-4626 SE test-token vaults + Permit2 at well-known + fee oracle overrides; **Base fork + Robinhood Chain 4663 fork** with **deploy-if-missing** PM/Permit2 (D64 / D74); yield→protocol-fee test (D67); D72 pre-buffer fee timing test; ZapSwap emission (D77); D78 under SE buffer fees; D79 zap-after-full-exit reverts.  
11. Implement **full §7.1 required surface** (D68): D59 views, `kLast()`, ERC-20, trading-fee constants — not optional; **not** `isExpectedHook` on hook ABI.  
12. Do not invent InitPrice, one-sided book, fee-less CP, multi-pool DoD, post-buffer-only D57 on deposits, raw `kLast`, fixed-only Uni V2 1/6 protocol fee, yield exclusion from D57, exit usage fee for DoD, disclosure-only `previewZapSplit`, parallel SE-fee math on the hook, raw-amountIn-into-CP under SE buffer fees, zap while only MINIMUM_LIQUIDITY residual, geometric re-bootstrap after MINIMUM_LIQUIDITY, fee-share product caps, or best-effort skip of protocol mint.

---

## 14. Revision log

| Date | Change |
|------|--------|
| 2026-08-02 | First draft through v3.3.1 (see prior entries in git history / earlier table rows). |
| 2026-08-03 | **v3.4–v3.5:** stakeholder Q1–Q22 (0.3% CP, ConstProdUtils zap, well-known Permit2, ERC-4626 test SEs, etc.). |
| 2026-08-03 | **v3.6:** Uni V2 dual fee — D29 0.3% in reserves **+** D57 protocol growth mint via `dexSwapFeeOfVault` + `feeTo` / `kLast`; feeOracle ctor+salt. Liquidity **nonReentrant**. Pure math optional; **pool behavior** required. **Fork required**. Non-zero SE usage + non-zero dex protocol fee tests. **Permit2 packing §7.3 DoD** (no witness; batch dual / single encode). |
| 2026-08-03 | **v3.7 plan-readiness locks:** D60 ERC-4626 SE **hard** prereq; D61 fee-on previews include protocol mint; D62 generic `ownerFeeShare = wad * 100_000 / 1e18`; D63 **wad** `kLast`; D64 forks **Base + Robinhood**; C38–C46; §7.3 batch **pool-order by index**; §7.4 rewritten; §7.5 event ABIs; §8 deployHook includes `feeOracle`; status **accepted / plan-ready**. |
| 2026-08-03 | **v3.8 stakeholder locks:** D65 strict SE-aware `previewZapSplit` == execution; D66 dual plan Phase 0 owns ERC-4626 SE; D67 yield (any k growth) D57 fee-eligible; D68 plan completes interface beyond §7.1; C47–C50; §5.3 withdraw D57 order; status **accepted / plan-ready**. |
| 2026-08-03 | **v3.9 rename:** product name **`UniswapV4DualStandardExchangeBufferConstantProductHook`** (D1); salt namespace `uv4-dual-se-buffer-constant-product-hook-` (D37); LP symbol prefix `DSEBCP-` (O4); file map + interface + plan filenames; legacy `UniswapV4DualBufferPricingHook*` scaffold non-authoritative. |
| 2026-08-03 | **v3.10 clarity locks:** D69 one-pool hard-revert; D70 SE usage fee DoD = buffer/share-mint only; D71 residual free pair tokens → `msg.sender`; D72 D57 **pre-buffer** k on deposits (Uni V2 peer); D64 Robinhood Chain **4663**; C51–C56; §5.1/§5.2 D57 order mirrored; scrub stale OQ refs; non-goals final law only; related-doc stale plan filename called out. Status **accepted / plan-ready**. |
| 2026-08-03 | **v3.11 clarity locks (plan-readiness Qs):** D73 SE `previewExchange*` fee-inclusive SoT + swap previews compose CP+SE; D74 fork deploy-if-missing PM/Permit2; D75 `feeTo` receivability out of scope (mint fail reverts); D76 subsequent mint while `totalSupply > 0`; D77 normative **`ZapSwap`** event; D68 §7.1 **required** surface (fee/`kLast`/ERC-20 mandatory); C57–C63; §4.2.1 / §4.5 / §5 / §7.1 / §7.5 / §9 updated. Status **accepted / plan-ready**. |
| 2026-08-03 | **v3.12 plan-readiness clarity (review Qs locked):** **D78** SE×CP **claim-in** composition (exact-in/out + zap; normative §4.2.1 algorithm — CP on buffer claim delta, not raw amountIn when SE buffer fees apply); **D79** zap-eligible = live **and** `totalSupply > MINIMUM_LIQUIDITY` (C36 wins over “live only”); **D80** `isExpectedHook` factory-only; **D81** `DepositSingle.amountIn` = full pull; **D82** no product cap on protocol fee WAD; **D83** `kLast` overflow accepted Uni V2-class risk; `dexSwapFee` naming callout on D57; **collapsed** former §3.4–§3.7 layered pointer tables into §3.4 + C68; terminology zap-eligible / claim-in; §5–§7 / §9 / §11–§13 / §15–§17 updated. Status **accepted / plan-ready**. |

---

## 15. Process next (product questions closed)

**Product law open questions:** none remaining after **v3.12**.  

**Process / delivery next steps** (not product ambiguity):

1. ~~Stakeholder accepts PRD~~ — **v3.12 accepted / plan-ready.**  
2. Another agent **rewrites** the implementation plan from this PRD (canonical filename under D44; retire stale `…DUAL_BUFFER_PRICING…` plan).  
3. Plan Phase 0: verify/finish generic **ERC-4626 SE** routes (D60 / D66).  
4. Coding agent implements from the rewritten plan (rename scaffold to D1; full rewrite allowed — D56).  
5. DoD: hermetic + Base + Robinhood 4663 (D64 / D74).

**High-signal locked clarifications (index — full law in §3):**

- **Claim-in CP composition** for swaps and zap internal swap (D78 / §4.2.1).  
- **Zap-eligible** only when live **and** `totalSupply > MINIMUM_LIQUIDITY` (D79 / C36).  
- V4 init needs no liquidity (C13).  
- Zap split = ConstProdUtils fee-aware (O1a); execution uses D78.  
- `dexSwapFeeOfVault` = **protocol growth share** (WAD) → `ownerFeeShare` (D62); **not** D29 trading fee; **no product max** (D82).  
- `kLast` = wad claim product (D63); overflow accepted (D83).  
- Previews include fee-on protocol mint (D61); D57 deposit timing pre-buffer (D72).  
- **`previewZapSplit` strict SE-aware == execution** (D65).  
- Yield growth D57 fee-eligible (D67).  
- ERC-4626 SE hard prereq; dual plan Phase 0 owns it (D60 / D66).  
- §7.1 required surface; **`isExpectedHook` not on hook ABI** (D68 / D80).  
- Fork DoD Base + Robinhood 4663; deploy-if-missing (D64 / D74).  
- One pool per hook hard-enforced (D69).  
- SE usage fee DoD: buffer routes only (D70); SE previews fee-inclusive SoT (D73).  
- Residual free pair tokens → `msg.sender` (D71).  
- Subsequent mint while `totalSupply > 0` (D76).  
- ZapSwap event (D77); `DepositSingle.amountIn` = full pull (D81).  
- `feeTo` receivability out of PRD scope (D75).

---

## 16. Summary for plan authors / implementors

```text
Product law: this PRD (v3.12 — accepted / plan-ready)
Name:   UniswapV4DualStandardExchangeBufferConstantProductHook (D1)
Implementor SoT: rewritten implementation plan (later agent)

Model:  CP on SE claims
Swap:   claim-in composition (D78) — CP(amountIn := SE buffer claim delta), not raw when SE fees
Fees:   (1) 0.3% trading fee retained in reserves (swaps + zap swap) on claim-in
        (2) protocol LP mint on k growth → address(feeTo)
            ownerFeeShare = dexSwapFeeWad * 100_000 / 1e18 (generic ConstProdUtils)
            dexSwapFee NAME = growth share, NOT trading fee
            no product max on growth WAD (D82)
            kLast = xN * yN (wad product); overflow accepted (D83)
            deposit/depositSingle: measure growth on PRE-BUFFER claims (D72)
            k growth sources: swaps, SE yield, SE donations (all fee-eligible — D67)
            feeTo receivability: out of scope; mint fail reverts op (D75)
Math:   ConstProdUtils sale/purchase/zap + _calculateProtocolFee generic path
Oracle: feeOracle immutable; query dexSwapFeeAndFeeToOfVault(this); 0 = unset → defaults
SE:     buffer In(pair→SE); withdraw In(SE→pair); swap-out Out(SE→pair);
        prefer pretransfer; tight=fee-inclusive SE preview (D73); re-preview claims before mint
        DoD non-zero usage fee on buffer/share-mint only (D70)
        hook never re-derives SE fee math — trust previewExchange* (D73)
Phase0: dual plan owns ERC-4626 SE completeness (D66) before dual DoD
LP:     ERC-20 on hook; decimals 18; symbol pool order; nonReentrant liquidity
        withdraw pro-rata SE share balances (not claim-weighted)
Zap:    only if zap-eligible: live AND totalSupply > MINIMUM_LIQUIDITY (D79)
V4 fee: pool fee = 0; one pool per hook hard-revert (D69)
Permit2: well-known address; packing §7.3 DoD; dual batch pool-order by index; no witness
Previews: fee-on deposit/single/withdraw include protocol mint dilution;
          previewZapSplit + previewSwap use D78 + SE fee-inclusive previews (D65/D73/D78)
Surface: §7.1 REQUIRED (D68): fee views, kLast, trading-fee constants, full ERC-20
         isExpectedHook factory-only (D80) — not hook ABI
Tests:  hermetic + Base fork + Robinhood Chain 4663 fork (deploy PM/Permit2 if missing — D74);
        non-zero SE buffer-route usage + dex protocol fee;
        yield→protocol fee; D72 pre-buffer fee timing; pool-attached swaps;
        subsequent mint after MINIMUM_LIQUIDITY residual (D76);
        depositSingle reverts on dust residual (D79); claim-in under SE fees (D78);
        pure math unit optional
DoD SE: two ERC-4626 SE vaults wrapping test tokens
Init:   no liquidity required; deposit may precede init; second init reverts
Residual: free pair tokens > dust after liquidity ops → msg.sender (D71)
Events: Deposit, DepositSingle (full pull amountIn — D81), Withdraw, ZapSwap (§7.5)
No:     one-sided book, CL, InitPrice, FoT pairs, multi-pool, yield exclusion,
        post-buffer-only D57 on deposits, disclosure-only previewZapSplit,
        geometric re-bootstrap while totalSupply > 0, parallel SE-fee math on hook,
        raw-amountIn-into-CP under SE buffer fees, zap on MINIMUM_LIQUIDITY-only book,
        product cap on protocol growth WAD, isExpectedHook on hook ABI
```

---

## 17. Algorithm card (plan-author quick path)

End-to-end product algorithms. Normative detail remains in §4–§7; this card is the preferred first read.

### 17.1 Proportional deposit (`deposit`)

```text
deadline OK; amount0>0, amount1>0; pull tokens (ERC-20 or Permit2)
if feeOn && kLast != 0:
  protocolLp = _calculateProtocolFee(totalSupply, preBufferK, kLast, ownerFeeShare)
  mint protocolLp → address(feeTo)   // fail ⇒ whole op reverts (D75)
if totalSupply == 0:
  buffer both full amounts; lp = sqrt(xN*yN) - MINIMUM_LIQUIDITY; mint MIN to address(0)
else:  // including only MINIMUM_LIQUIDITY residual
  clamp used0/used1 to claim ratio; refund excess → msg.sender
  buffer used0/used1; lp = min(dxN/xN, dyN/yN) * totalSupply  // post-dilution supply
require lp >= minLpAmount
kLast = feeOn ? postOpK : 0
refund free pair-token dust excess → msg.sender
emit Deposit(sender, to, used0, used1, lp)
```

### 17.2 Single-asset deposit (`depositSingle`)

```text
deadline OK; amountIn>0; tokenIn is a bound pair token; pull full amountIn
require zap-eligible: claim0>0 && claim1>0 && totalSupply > MINIMUM_LIQUIDITY  // D79
D57 protocol mint from pre-buffer/pre-zap k (same as deposit)
saleAmt = _swapDepositSaleAmt(amountIn, r_in, 300, 100_000)   // O1a on claim reserves
// internal swap (O9, no PoolManager) — D78:
claimIn = preview_buffer_pair_to_claim(SE_in, saleAmt)
amountOtherOut = _saleQuote(claimIn, r_in, r_out, 300, 100_000)
buffer saleAmt; unwrap amountOtherOut; emit ZapSwap(sender, tokenIn, tokenOut, saleAmt, amountOtherOut)
proportional add (amountIn - saleAmt) + amountOtherOut; clamp/refund residual → msg.sender
mint user LP from claim deltas (subsequent formula); require minLpAmount
kLast post-op; residual pair-token refund → msg.sender
emit DepositSingle(sender, to, tokenIn, amountIn /* full pull — D81 */, lp)
```

### 17.3 Withdraw

```text
deadline OK
if feeOn && kLast != 0: mint protocol LP from currentK vs kLast before user burn
seOut_i = seBal_i * lpAmount / totalSupply   // pre-user-burn, post-protocol-mint; SE shares not claim-weighted
burn user LP; unwrap both legs SE→pair; pay to; require minAmount0/1
kLast post-op; residual pair-token refund → msg.sender
emit Withdraw(...)
```

### 17.4 Public swap (V4 `beforeSwap`)

```text
require live claims
// Exact-in (D78):
claimIn = preview_buffer_pair_to_claim(SE_in, amountInRaw)
amountOut = _saleQuote(claimIn, reserveIn, reserveOut, 300, 100_000)
take amountInRaw → buffer SE_in → unwrap amountOut from SE_out → settle
// Exact-out (D78):
claimIn = _purchaseQuote(amountOut, ...)
amountInRaw = invert_buffer_preview_ceil(SE_in, claimIn)
take amountInRaw → buffer → unwrap exact amountOut → settle
return BeforeSwapDelta
// Previews mirror the same composition under non-zero SE buffer fees
```

### 17.5 Fee resolution (liquidity ops)

```text
(feeTo, dexFeeWad) = feeOracle.dexSwapFeeAndFeeToOfVault(this)  // growth WAD, not D29
ownerFeeShare = dexFeeWad * 100_000 / 1e18   // no product max (D82)
feeOn = feeTo != 0 && dexFeeWad != 0
k product always wad: xN * yN   // D63; overflow accepted D83
```
