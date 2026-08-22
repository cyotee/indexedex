# PRD: Uniswap V4 Single Standard Exchange Buffer Constant Product Hook

**Name:** `UniswapV4SingleStandardExchangeBufferConstantProductHook`  
**Date:** 2026-08-04  
**Status:** **Draft v1.4 — product law + vault/SE compatibility + DETF owner-during-lock (D88/D89)** (conversation locks applied)  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`  
**Package kind:** IndexedEx **hook product** that is **also** a Standard Exchange / vault-compatible surface. Deploy shape is **architecture-flexible** (see D10 / §2.4): either CREATE3-mined monomorph **or** mined Diamond proxy via a Uniswap V4–aware hook factory. **Not** a Uniswap V4 concentrated-liquidity (CL) reimplementation.

**Sibling packages (do not conflate):**

| Package | Path | Role |
|---------|------|------|
| **Single SE Buffer Pricing Hook** | `…/standardExchange/single/` | Wrapper portal `underlying ↔ SE` — **no LP**, **no AMM book** |
| **Dual SE Buffer CP Hook** | `…/standardExchange/dual/` | **Two** SEs + two pair tokens; CP on **both** SE claims; fungible LP; **no** zap-out |
| **This package** | `…/standardExchange/constantProduct/single/` | **One** SE + **one raw ERC-20 leg**; CP on **raw balance × SE claim**; fungible LP; **zap-in + zap-out** |

**Primary peer (behavioral template):**  
[`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`](../../dual/UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md) (v3.12).  
This v1.2 PRD **restates** dual-equivalent product law adapted to asymmetric legs so implementors need **not** open dual for locked decisions. Dual remains a pattern reference for code structure only — **do not subclass**. Dual DoD is **good enough to pattern-copy**.

**Product fee intent (LOCKED):** This hook must **behave like a Uniswap V2 pool**: charge a **swap fee** (D19) retained in reserves, and a **protocol growth / usage fee on liquidity growth** (D57 / `kLast`). Whether the bound SE charges usage fees is **orthogonal** to product design — SE fees matter only for integration correctness (fee-inclusive previews, claim composition D78) and test coverage, **not** as product law requiring SE exit fees.

**Related:**

- CP math peer: `lib/crane/contracts/utils/math/ConstProdUtils.sol`
- Single wrapper settle pattern-copy: `…/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHookTarget.sol`
- Dual CP implementor surface: `…/standardExchange/dual/` (pattern-copy; no dual Phase 0 gate)
- ERC-4626 **wrapper** SE (hermetic/fork test SE only — D60/D63T): `contracts/vaults/standard/erc4626/`
- Fee oracle: `contracts/interfaces/IVaultFeeOracleQuery.sol`
- Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3`
- Crane HookMiner: `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol`
- Future consumer (out of scope for this PRD): UniV4 SE DETF under `contracts/vaults/detf/protocols/dexes/uniswap/v4/`

**Test SE (LOCKED — D63T):** Hermetic and fork DoD use **only** the production **ERC-4626 Wrapper SE Vault** wrapping a mintable `pairToken`. **Do not** implement an ERC-4626 vault in this package. **Do not** matrix multiple SE implementations (no Uni V2 SE DoD row). Bound SE in production may be any `IStandardExchange` with closed-form pair↔SE routes (D4); tests prove SE integration via the wrapper SE only.

**Prerequisite (thin — D60 / D66):** Bound SE must expose closed-form **pairToken ↔ SE** buffer and unwrap routes with **preview == execution** (D73). Plan Phase 0 is a **verify-and-deploy-in-TestBase** gate on the existing ERC-4626 wrapper SE — **not** “build ERC-4626 product law,” **not** “add exit fees to SE,” **not** dual Phase 0 ownership.

**Authority:**

| Layer | Role |
|-------|------|
| **This PRD (v1.4)** | Product law for the hook — **canonical** D/O tables + §4–§7 + vault/SE compatibility + D88/D89 |
| **Implementation plan** | Source of truth for coding phases + deploy architecture choice once locked |
| Dual / single wrapper peers | Pattern and formula references — **do not subclass** |

---

## 0. Terminology (normative)

| Term | Meaning |
|------|---------|
| **`rawToken` / raw leg** | ERC-20 held **directly** by the hook as reserve inventory. **Not** buffered into the SE. Example consumer: DETF self-leg. |
| **`pairToken` / SE leg** | ERC-20 that **buffers into** the bound SE. Must be ∈ `SE.vaultTokens()`. Free `pairToken` on the hook is **not** product reserve (refund dust only). |
| **`standardExchange` / SE** | Bound `IStandardExchange` vault; hook holds **SE shares** as the SE-leg inventory. |
| **Virtual pair reserve / SE claim / claim supply** | **Normative pair-side reserve for CP and mid.** Pair-token value of hook-held SE shares via SE fee-inclusive preview unwrap: \(s = \mathrm{previewExchangeIn}(SE,\ \mathrm{seBalance},\ pairToken)\). **Not** free `pairToken.balanceOf(hook)`. Product book = **raw face reserve × virtual pair reserve**. |
| **Raw reserve** | Hook `balanceOf(rawToken)` counted as inventory (face amount). |
| **Effective reserves** | Pool-ordered \((x, y)\) where one leg is **raw reserve** and the other is **virtual pair reserve (SE claim)** (see §4.1). |
| **LP tokens / `lpAmount`** | Fungible ERC-20 minted by **this hook** — pro-rata claim on **raw inventory + SE shares**. Not SE vault shares. |
| **Live** | Both effective reserves \(> 0\) after mapping to pool order. |
| **Zap-eligible** | Live **and** `totalSupply > MINIMUM_LIQUIDITY` (Uni V2-style locked dust residual). |
| **Zap-in** | Single-asset **deposit**: internal CP swap + proportional add → mint dual LP. |
| **Zap-out** | Single-asset **withdraw**: burn LP → pro-rata both legs → internal swap residual other-leg **fully** → pay **one** currency. |
| **Claim-in (SE side)** | SE fee-inclusive preview of how much **virtual pair reserve / SE claim** a raw `pairToken` buffer adds — not assumed 1:1 with raw amountIn. |
| **Claim-out (SE side)** | SE fee-inclusive preview of how much **pairToken** an SE-share unwrap delivers / costs — fee-inclusive SoT. |
| **Buffer-last** | When a path must buffer `pairToken` → SE, **all CP quotes, residual swaps, and LP mint amounts that depend on pre-buffer book are computed first**; **buffer is the final inventory step** that lands pair into virtual reserve; then **user LP mint (when applicable) and `kLast` update** run on post-buffer effective reserves so buffering does not pollute swap/mint math mid-flight (O13). |
| **DoD** | Definition of Done — §11. |

**Role naming:** use `rawToken`, `pairToken`, `standardExchange` — **no** brand tickers; **no** DETF-specific type names on the hook ABI (DETF is a consumer).

---

## 1. Goal

Ship a **production-first Uniswap V4 hook** that:

1. Binds **one** Standard Exchange and **one** pair token, plus **one** raw ERC-20 leg and PoolManager + fee oracle.
2. Powers a V4 pool whose currencies are **`rawToken` ↔ `pairToken`** (address-sorted) — **not** SE shares as a pool currency.
3. Behaves as a **normal constant-product AMM** on effective reserves: **raw face balance** × **virtual pair reserve (SE claim in pairToken)** — Uni V2-like mid/depth; free pair is not the book.
4. **Buffers** `pairToken` into the SE on liquidity add (pair side) and on swap token-in when token-in is pair — **buffer-last** (O13): quote first, buffer last, then LP mint / `kLast` where applicable.
5. **Holds rawToken** as free ERC-20 inventory (no SE path for the raw leg).
6. **Unwraps** SE → pairToken on liquidity remove (SE share pro-rata) and on swap token-out when token-out is pair.
7. Mints a **single fungible ERC-20 LP** representing pro-rata ownership of **both** legs.
8. Supports:
   - **Proportional deposit** (both assets) — first mint and ratio-clamped subsequent mints.
   - **Single-asset deposit (zap-in)** — either currency once zap-eligible.
   - **Proportional withdraw** — both assets out.
   - **Single-asset withdraw (zap-out)** — either currency once zap-eligible.
   - **Standard Exchange swap surface** (`IStandardExchangeIn` / `IStandardExchangeOut`) for exact-in/out **raw ↔ pair** book swaps (compatibility; does **not** replace proportional/zap LP APIs).
   - **Vault discovery surface** (`IBasicVault` + `IStandardVault`) for tokens/reserves/types.
9. Deploys via hook diamond package → Vault Registry `deployHookVault` → shared hook CREATE2 factory. `deployVault` leaves a bootstrap diamond (vault pair + package-as-init). The product door is later `deployPair(tokenA, tokenB)` for the bound pair (`fee = 0`); production ABI (SE / deposit / withdraw / ERC-20) is installed by `finalizeInitialization`. After finalize, `beforeInitialize` lives on `SE_FACET`. See staged init PRD.

### 1.1 Canonical user story (DETF-shaped example — informative only)

```text
Binding:
  rawToken  = DETF (or any ERC-20 in tests)
  pairToken = USDC
  SE        = ERC-4626 SE (or other production SE) with USDC ∈ vaultTokens()

Pool: sort(DETF, USDC), fee = 0, hooks = this instance
  Product mid/depth = raw DETF inventory vs SE claim in USDC
  (V4 sqrtPriceX96 is plumbing only)

--- Proportional deposit (bond / first LP) ---
User supplies DETF + USDC (pool order; excess refunded when live)
  → hold DETF on hook
  → buffer USDC → SE
  → mint fungible LP

--- Zap-in USDC only ---
User supplies USDC (zap-eligible)
  → internal swap slice USDC→DETF (buffer USDC claim-in; pay DETF from inventory)
  → proportional add remainder USDC + DETF proceeds
  → mint same LP

--- Zap-in DETF only ---
User supplies DETF
  → internal swap slice DETF→USDC (take DETF; unwrap USDC from SE)
  → buffer leftover path as needed; proportional add
  → mint same LP

--- Swap (public V4) ---
USDC → DETF: take USDC → buffer SE → CP on claim-in → pay DETF
DETF → USDC: take DETF → CP → unwrap USDC from SE → pay USDC

--- Zap-out to USDC only ---
Burn LP → pro-rata DETF + SE shares → unwrap SE to USDC
  → swap residual DETF → USDC → pay USDC only

--- Zap-out to DETF only ---
Burn LP → pro-rata both → unwrap SE to USDC
  → swap residual USDC → DETF → pay DETF only
```

### 1.2 Product shape (locked)

| Layer | Role |
|-------|------|
| Uniswap V4 | Pool identity, **swaps** + currency settlement via hook deltas |
| Hook | Binding, deposit/withdraw (+ zap + Permit2), LP ERC-20, CP math, SE buffer/unwrap (pair leg only), `beforeSwap` |
| SE vault | Yield-bearing inventory for **pair leg only** |
| Concentrated liquidity | **Not used** — native `modifyLiquidity` **forbidden** |
| Book shape | **Always dual-sided** after successful add; no one-sided book mode |
| LP shape | **One** fungible ERC-20 only |

**Asymmetry vs dual (LOCKED):**

| | Dual CP | This package |
|--|---------|--------------|
| Legs | SE₀+token₀, SE₁+token₁ | **rawToken** + **(SE, pairToken)** |
| Both legs buffered? | Yes | **Only pairToken** |
| Effective reserve A | SE₀ claim | **rawToken balance** (face) |
| Effective reserve B | SE₁ claim | **Virtual pair reserve** = SE claim → pairToken |
| Pool currencies | Two pair tokens | rawToken + pairToken (address sort; lowest = currency0) |
| Withdraw single-asset | Not required dual v1 | **Required** (`withdrawSingle`) |
| SE fee DoD | Buffer-route fees in dual D70 | **Orthogonal** — product fees are D19+D57; SE fees only via D73/D78; tests use ERC-4626 wrapper SE only |

---

## 2. Product summary

### 2.1 What this package is

| Attribute | Value |
|-----------|--------|
| Primary artifact | CREATE3-mined single hook (Repo + Target) implementing V4 `IHooks` **plus** deposit/withdraw surfaces + LP ERC-20 |
| Binding | `(poolManager, feeOracle, standardExchange, pairToken, rawToken)` ctor immutables |
| Pool currencies | `sort(rawToken, pairToken)` |
| Inventory | Hook-held **rawToken** + hook-held **SE shares** |
| Effective reserves | Raw balance + SE claim (pool order) |
| Pricing | Constant product with **0.3%** swap fee retained in reserves |
| LP | Fungible ERC-20; pro-rata both inventory components |
| Deposit | Proportional + zap-in either asset |
| Withdraw | Proportional both + **zap-out either asset** |
| Funding | ERC-20 approve/transferFrom **and** Permit2 (both styles) on deposit paths |
| Deploy | `create3Factory` + `HookMinerCreate3` + FactoryService |

### 2.2 What this package is not

- Not the single SE **wrapper** pricing hook (`underlying ↔ SE`, no LP).
- Not the **dual** SE CP hook (two SEs).
- Not CL / Position Manager LP / tick ranges.
- Not a DETF, bond NFT, or rebasing claim package.
- Not multi-pool shared inventory (one V4 pool per hook instance).
- Not a promise of zero price impact on zap-in/out.
- Not a collapse of **proportional LP** or **zap** into `exchangeIn`/`exchangeOut` only — those remain first-class product APIs; SE In/Out is a **compatibility swap** surface on the same book.

### 2.3 Non-goals (v1)

1. One-sided book / single-leg market mode.  
2. Distinct ERC-20 receipts per leg.  
3. CL ticks / Uni LP NFTs.  
4. Native ETH as pool currency (use WETH if needed).  
5. Auto-deploying SE or raw token inside the package.  
6. Binary-search exact-out solvers (closed form only).  
7. Fee-on-transfer or rebasing **pool currencies** (unsupported).  
8. Treating V4 `sqrtPriceX96` as product mid after init.  
9. Second V4 pool initialize on the same hook instance.  
10. Shared TestBases / product code with DETF packages (D-indep).  
11. Subclassing dual or single wrapper contracts.  
12. Buffering `rawToken` into any SE.  
13. Using SE share address as a pool currency.  
14. Optimal multi-step zap-out (always sell 100% residual other-leg).  
15. Max-impact / max-fraction guards beyond `minAmountOut` on zap-out.  
16. Product max cap on protocol fee WAD.  
17. Hook Permit2 for swaps or for LP burn on withdraw.  
18. Mapping `exchangeIn` → mint LP or `exchangeOut` → burn LP (wrong product surface).

### 2.4 Deploy architecture (LOCKED product requirements; shape flexible)

**Product requirements independent of deploy shape:**

- Hook address must satisfy Uniswap V4 permission flags (D54).  
- One instance per binding `(poolManager, feeOracle, se, pairToken, rawToken)` (+ salt namespace / mineNonce).  
- Implements IHooks callbacks + LP ERC-20 + liquidity APIs + **compatibility vault/SE interfaces** (§7.6).  
- Prefer shared facets/libraries for size when using Diamond.

| Option | Shape | When |
|--------|--------|------|
| **A — Monomorph (baseline)** | CREATE3-mined single contract (Repo+Target), peer dual FactoryService | Default if Diamond factory not ready; size via external libs |
| **B — Hook Diamond (REQUIRED deploy path once factory green)** | CREATE2-mined **proxy** via [`UniswapV4HookDiamondPackageCallBackFactory`](../../factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md); facets for SE In/Out, Basic/Standard vault, LP, hooks, etc. | **Hard block:** this package DoD waits on factory PRD DoD |

**Option B factory law (normative — see factory PRD):**

1. Factory: `contracts/hooks/uniswap/v4/factory/` — **CREATE2** + `MinimalDiamondCallBackProxy`; salt **without** package address; package `calcSalt` + `mineNonce`; public **`PROXY_INIT_HASH`** for off-chain premine.  
2. Package implements `IUniswapV4HookDiamondPackage` (`requiredHookFlags` = D54 flags).  
3. **Immutable** instance after deploy.  
4. **Cannot** reuse ERC-4626 SE facet **logic** for CP book swaps — only selectors/interfaces; product math is package-specific.  
5. Monomorph Option A is **emergency fallback only** if factory plan explicitly waives — default is Option B.

---

## 3. Locked product decisions

### 3.1 Identity & binding

| # | Decision | Value |
|---|----------|--------|
| D1 | Product name | **`UniswapV4SingleStandardExchangeBufferConstantProductHook`** |
| D2 | Package location | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` |
| D3 | Peers | Dual CP = CP/LP/fee/Permit2 template (restated here); single wrapper = settle pattern-copy only. **No** required inheritance from either |
| D4 | SE generality | Any `IStandardExchange` with closed-form **pairToken ↔ SE** buffer and unwrap routes (exact-in + exact-out) |
| D5 | Binding | `(poolManager, feeOracle, standardExchange, pairToken, rawToken)` **ctor immutables**; no post-deploy rebind. Permit2 = well-known constant (not ctor arg). **feeOracle** = `IVaultFeeOracleQuery` for protocol growth + `feeTo` (D57) |
| D6 | Validation | Non-zero addresses; `rawToken ≠ pairToken`; `pairToken ∈ SE.vaultTokens()`; `rawToken` **must not** equal `address(SE)`; raw **need not** be in `vaultTokens()` |
| D7 | Pool pair | Currencies = address-sorted `(rawToken, pairToken)`; **`currency0` = lower address**, `currency1` = higher. Public views `currency0()` / `currency1()` **required** (D68) |
| D8 | Pool fee | **0** |
| D9 | Native CL | **Forbidden** — `beforeAddLiquidity` reverts `LiquidityNotAllowed` |
| D10 | Package shape | **Flexible:** Option A monomorph (CREATE3-mined Repo+Target) **or** Option B Hook Diamond (mined proxy + facets). Product surface identical. See §2.4. Facets allowed **only** under Option B; vault registry DFPkg path still **not** used for the hook instance |
| D11 | Hook inheritance | No Uniswap `BaseTokenWrapperHook` / `BaseHook` / `DeltaResolver` — pattern-copy settle; Diamond option may use Crane facet bases |
| D12 | One pool per hook | `beforeInitialize` hard-reverts after first successful init (store flag / PoolId) |
| D84 | Vault/SE compatibility | **Required v1:** implement `IStandardExchangeIn`, `IStandardExchangeOut`, `IBasicVault`, `IStandardVault` with normative mappings in §7.6. Does **not** remove `deposit` / `depositSingle` / `withdraw` / `withdrawSingle` |
| D85 | SE In/Out semantics | Exact-in / exact-out **rawToken ↔ pairToken** against the **same** effective book as public V4 swaps (D19+D78+virtual pair reserve). **Internal settle** (no PoolManager unlock) — same class as zap internal swaps (O4). **Not** LP mint/burn |
| D86 | IBasicVault reserves | `vaultTokens()` = `[currency0, currency1]`; `reserveOfToken(raw)` = raw face; `reserveOfToken(pair)` = **virtual pair reserve** (SE claim), never free pair balance; `reserves()` = pool-order effective reserves |
| D87 | IStandardVault | Expose fee type ids / contentsId / vaultTypes / vaultConfig for discovery + fee-oracle typing; `vaultTypes` includes at least SE In, SE Out, BasicVault, StandardVault, and hook product interface ids as applicable |

### 3.2 AMM & reserves

| # | Decision | Value |
|---|----------|--------|
| D13 | AMM model | **Normal constant product** on effective reserves only |
| D14 | One-sided book | **Not supported**. Live ⇔ both effective reserves \(> 0\) |
| D15 | **Virtual pair reserve** (SE claim) | \(s = \mathrm{previewExchangeIn}(SE,\ \mathrm{seBalance(hook)},\ pairToken)\) (SE→pair exact-in unwrap semantic; fee-inclusive SoT — D73). This is the **only** pair-side CP reserve — **not** free `pairToken` balance |
| D16 | Raw reserve | \(r = \mathrm{IERC20(rawToken).balanceOf(hook)}\) counted as inventory (intentional inventory; not subject to free-balance refund) |
| D17 | Reserves for CP | Map into **pool currency order**: if `currency0 == rawToken` then \(x = r\), \(y = s\); else \(x = s\), \(y = r\). \(k = x\cdot y\) after 1e18 normalize for mint/fee math |
| D18 | Yield in price | Re-read virtual pair reserve (SE claim) each quote; SE profit moves mid without a swap. Raw face balance does not “yield” unless token rebases (**rebasing raw out of scope**) |
| D19 | Trading swap fee | **0.3%** Uni V2-style on **public swaps** and **internal zap swaps** (zap-in and zap-out). Retained in reserves. Encoding: `feePercent = 300`, `feeDenominator = 100_000`. **Not** on pure proportional deposit/withdraw with no internal swap. V4 pool fee stays 0 |
| D20 | SE usage fees | **Orthogonal to product design.** Inside SE previews/execution only (D73). Hook does not re-implement SE fee math. Hermetic DoD uses ERC-4626 wrapper SE (dilution on share-mint is fine). **No** requirement to invent SE exit fees or multi-SE fee matrix (D70S demoted) |
| D21 | Claim composition (pair side) | Same law as dual D78, restated as **D78** below: CP uses **claim-in** / **claim-out** vs **virtual pair reserve**, not raw pair amount as if 1:1. **Raw leg** uses face raw amounts (no SE composition on raw) |
| D22 | Quote matrix | Exact-in + exact-out both directions; closed form via ConstProdUtils peers (§4.2) |

### 3.3 LP & liquidity surfaces

| # | Decision | Value |
|---|----------|--------|
| D23 | LP token | Single fungible **ERC-20 on the hook** (proxy is LP); decimals **18**; free transfer. Cut **ERC20PermitDFPkg facets** (`ERC20Facet` + `ERC5267Facet` + `ERC2612Facet`) + init `ERC20Repo` + `EIP712Repo`. Underlyings still use **Permit2** on deposit paths (not a substitute for LP EIP-2612). |
| D24 | LP ownership | Pro-rata of **raw inventory + SE share balances** |
| D25 | MINIMUM_LIQUIDITY | **1000** minted to `address(0)` on first mint; **never burned** — Uni V2 locked dust; backstop so the book is never fully drained by last-LP burns |
| D26 | First mint | **Proportional only** — both currencies non-zero. Geometric: `lp = sqrt(xN*yN) - MINIMUM_LIQUIDITY` on 1e18-normalized effective reserves after intake. Revert if sqrt &lt; MINIMUM_LIQUIDITY |
| D27 | Subsequent mint | Any `totalSupply > 0` (incl. only MINIMUM_LIQUIDITY residual): ratio clamp `min(dxN/xN, dyN/yN) * totalSupply` — **never** re-bootstrap geometric (D76) |
| D28 | Proportional deposit | Both pool currencies non-zero; when live, clamp to current effective-reserve ratio; **refund excess to `msg.sender`**; hold raw; buffer pair → SE; mint LP |
| D29 | Zap-in (`depositSingle`) | **Required v1** when zap-eligible (D79) — **either** `rawToken` or `pairToken`. Internal swap + proportional add → **same** LP. Empty book / not zap-eligible → revert |
| D30 | Zap-in economics | Depositor accepts CP impact (incl. 0.3%) + SE costs on pair-side legs. `previewDepositSingle` → expected LP; `previewZapSplit` strict preview == execution (D65) |
| D31 | Zap-in accounting | (1) closed-form split once with fee (ConstProdUtils `_swapDepositSaleAmt` peer); (2) internal swap (no PoolManager round-trip); (3) proportional add; (4) mint LP — never leave one-sided inventory as LP state |
| D32 | Proportional withdraw | Burn LP → pro-rata **rawToken** + pro-rata **SE shares** → unwrap SE→pair → pay both in pool order |
| D33 | Zap-out (`withdrawSingle`) | **Required v1** when zap-eligible (D79) — burn LP → realize both legs → **internal swap 100% of residual other-leg** into `tokenOut` → pay single asset. Accepts CP + SE costs. Not available when not zap-eligible |
| D34 | Zap-out accounting | Normative §4.6. Summary: (1) protocol mint if fee-on; (2) pro-rata raw + SE shares for `lpAmount` (pre-burn supply after protocol mint); (3) burn LP; (4) unwrap SE→pair for user SE slice; (5) **quote residual internal swap once on pre-buffer remaining book**; (6) execute residual sell **100%** other-leg; **buffer pair→SE last** when residual path needs buffer (O13); (7) pay `tokenOut` only; (8) refund free pair dust to `msg.sender`; (9) update `kLast` post-op when fee-on |
| D34a | Zap-out thin-book / impact | **No** max-impact, max-burn-fraction, or partial residual sell. User protection = **`minAmountOut` + `deadline`**. **Uni V2 locked dust** (`MINIMUM_LIQUIDITY` to `address(0)`) prevents full book drain / last-LP insolvency of the residual book. Residual sell against dust book may still severe-impact or naturally revert — **accepted**; users use proportional withdraw when thin |
| D35 | Withdraw when only MINIMUM_LIQUIDITY left | User cannot burn protocol dust; after full user exit, only `address(0)` LP remains. Re-seed via **proportional `deposit` only** until `totalSupply > MINIMUM_LIQUIDITY` again for zaps (D79) |
| D36 | Liquidity slippage | Deposits: `minLpAmount` + `deadline`. Proportional withdraw: `minAmount0`/`minAmount1` + `deadline`. Zap-out: `minAmountOut` + `deadline` |
| D37 | Funding | Classic `transferFrom` **and** Permit2 SignatureTransfer **and** AllowanceTransfer on **deposit** paths only (§7.3). Refunds of unused deposit tokens always to **`msg.sender`** (even if LP `to` differs). Swaps not via hook Permit2. Withdraw burns LP via classic `transferFrom` / balance (no LP Permit2 v1) |
| D38 | Reentrancy | All external liquidity entrypoints `nonReentrant` (`deposit*`, `withdraw`, `withdrawSingle`, Permit2 variants) |
| D39 | Decimal normalize | Normalize both effective reserves to 1e18 before CP/mint/zap math. Missing `decimals()` → 18. LP ERC-20 always 18 |
| D40 | LP name/symbol | Auto from pool currency symbols, e.g. `SSEBCP-{s0}-{s1}` (Single SE Buffer Constant Product); address-fragment fallback |

### 3.4 Fees, protocol growth, ops

| # | Decision | Value |
|---|----------|--------|
| D41 | Protocol growth fee | **Yes** — Uni V2-style `kLast` on **wad effective-reserve product**; mint protocol LP to oracle `feeTo` on mint/burn liquidity paths when fee-on. Full law **D57** |
| D42 | `kLast` units | After normalize both pool-order effective reserves to 1e18: `kLast = xN * yN` (D63). Overflow = accepted Uni V2-class risk (D83) |
| D43 | Protocol mint timing | **D72:** deposits use **pre-intake** product vs `kLast`; withdraw / withdrawSingle mint growth **before** user burn; set `kLast` post-op when fee-on; `kLast = 0` when fee-off |
| D44 | k growth sources | Swap fee retention, SE yield on hook-held shares, raw/SE-share donations — all fee-eligible on next mint/burn (D67) |
| D45 | Previews include protocol mint | When fee-on, deposit/withdraw/single previews simulate protocol LP mint first so preview == execution (D61). Includes `previewWithdrawSingle` |
| D46 | SE I/O | `exchangeIn` / `exchangeOut` only; tight minOut/maxIn = preview; SE deadline `block.timestamp` if required (§4.5) |
| D47 | Dust | `MAX_DUST_WEI = 10` for documented SE multi-leg dust / preview tolerance |
| D48 | Residual free pair/raw after liquidity ops | Free balances above dust that are **not** intentional inventory: **refund to `msg.sender`**. Intentional inventory = raw reserve + SE shares. After zap-out, only dust may remain of free pair (raw intentional remains). Swaps leave no free residual of settled currencies |
| D49 | Donation | Donated SE shares or rawToken to hook count in reserves (dilute LPs) |
| D50 | Fee-on-transfer / rebasing pool tokens | **Out of scope** |

### 3.5 Deploy, permissions, tests

| # | Decision | Value |
|---|----------|--------|
| D51 | Deploy | CREATE3-mined single contract; FactoryService on existing create3Factory; **not** vault registry / manager deployPkg |
| D52 | Salt namespace default | `"uv4-single-se-buffer-constant-product-hook-"` |
| D53 | Salt material | `namespace + poolManager + feeOracle + standardExchange + pairToken + rawToken + mineNonce` via EfficientHash peer; empty namespace → default. **No Permit2 in salt** |
| D54 | Mine flags | `BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA` |
| D55 | Idempotency | Same binding + namespace: if predicted address is expected hook → return existing; wrong code → revert |
| D56 | `isExpectedHook` | Factory/internal only: match poolManager, feeOracle, SE, pairToken, rawToken. **Not** required on public hook ABI (D80) |
| D57P | Empty SE at deploy | Allowed |
| D58P | Pool init | External/script; validates currencies + fee=0 + one-pool. Hermetic convention: `tickSpacing = 60`, 1:1 mid sqrtPrice plumbing |
| D59 | Deposit vs pool init | Deposit/withdraw/previews **do not require** V4 initialize. **Swaps** require initialized pool + live reserves. Internal zap swaps do **not** use PoolManager |
| D60 | Hook permissions | Only `beforeInitialize`, `beforeAddLiquidity`, `beforeSwap`, `beforeSwapReturnDelta`. Other callbacks revert |
| D61P | Access | Liquidity + views permissionless; callbacks `msg.sender == poolManager` only |
| D62 | DETF coupling | **Fully independent** product/test surface from DETF packages. DETF may consume this hook later; **not** a v1 DoD consumer |
| D63T | Test matrix (hermetic) | **Only** production **ERC-4626 Wrapper SE** wrapping mintable **pairToken** + **two mintable ERC-20s** (raw + pair). No mock hook/SE SUT. **No** multi-SE matrix. Phase 0 = thin verify/deploy gate (D66) |
| D64 | Fork DoD | **Base** and **Robinhood (4663)** forks; deploy-if-missing production-equivalent PoolManager/Permit2 (D74); **may deploy mintable tokens + ERC-4626 wrapper SE on fork** for smoke |
| D65P | Impl plan follow-on | `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` |

### 3.6 Dual-equivalent locks restated (canonical for this package)

These IDs mirror dual v3.12 law **adapted** to raw + SE-claim reserves. Implementors use **this table**, not dual’s.

| # | Decision | Value |
|---|----------|--------|
| D57 | Protocol fee on liquidity growth | Track **`kLast`** as **wad product** of pool-order effective reserves \(x_N \cdot y_N\) (D63). On **mint and burn** liquidity paths (`deposit`, `depositSingle`, `withdraw`, `withdrawSingle`), **before** adjusting user LP supply: if fee-on, mint protocol LP to **`address(feeTo)`** from growth since `kLast`. **Sources:** `feeOracle.dexSwapFeeAndFeeToOfVault(address(this))` → `(feeTo, dexFeeWad)`. **Naming:** oracle **`dexSwapFee` is protocol growth share (WAD), not a second amountIn trading fee**. Trading fee = D19 only. **`ownerFeeShare = dexFeeWad * 100_000 / 1e18`** (floor); ConstProdUtils **generic** `_calculateProtocolFee`. **No product max cap** (D82). **Fee-on** when `address(feeTo) != 0` and resolved dex fee ≠ 0. When fee-off set `kLast = 0`. Full surface §7.4 |
| D58 | Liquidity reentrancy | All external liquidity entrypoints **`nonReentrant`** |
| D60 | ERC-4626 wrapper SE test dependency | Hermetic/fork DoD deploys existing production **ERC-4626 Wrapper SE** under `contracts/vaults/standard/erc4626/` wrapping test pairToken. **Not** “implement ERC-4626 vault” in this package. **Not** dual Phase 0 ownership |
| D61 | Previews include protocol mint | When fee-on, `previewDeposit`, `previewDepositSingle`, `previewWithdraw`, `previewWithdrawSingle` **simulate D57 first**, then user math. Deposit paths use **pre-intake** product for protocol step (D72). `previewZapSplit` = D65 |
| D62 | Protocol fee math path | `ownerFeeShare = dexSwapFeeWad * 100_000 / 1e18`. Do not force Uni V2 fixed 1/6 |
| D63 | `kLast` units | Wad product only after normalize both pool-order effective reserves to 1e18 |
| D65 | `previewZapSplit` fidelity | Strict preview == execution (within `MAX_DUST_WEI`) on `amountToSwap`, `amountOtherOut`, `amountKeptIn`, SE-aware (D73/D78). Not disclosure-only |
| D66 | Plan Phase 0 (thin) | Implementation plan **Phase 0:** verify existing ERC-4626 wrapper SE is deployable in TestBase with pair↔SE routes + preview==exec — **no** SE product rewrite; **no** dual Phase 0 gate |
| D67 | Yield (and other k growth) fee-eligible | Any effective-reserve product increase since `kLast` is D57-eligible — incl. D19 retention, SE yield, donations |
| D68 | Required public surface | §6 / §7.1 list required surface by name (incl. `currency0`/`currency1`). Plan must not omit required items |
| D69 | One pool per hook (hard) | `beforeInitialize` hard-reverts after first successful init |
| D70S | SE usage fee DoD scope (**demoted v1.2**) | **Product fees = D19 + D57 only.** SE usage fees are **orthogonal**. DoD does **not** require inventing SE exit fees or multi-SE fee matrix. Previews must match execution under the **actual** ERC-4626 wrapper SE fee model (dilution on buffer / share-mint is expected; trust SE preview==exec). D78 still mandatory so claim-in ≠ face pair under dilution |
| D71 | Residual free non-inventory refund | After successful **liquidity** ops, free **pairToken** above dust refunded to `msg.sender`. Free **rawToken** is intentional inventory (do not refund raw that is reserve). After zap-out, free pair above dust refunded; book remains dual via remaining LPs’ raw + SE shares |
| D72 | D57 k measurement timing | Deposit / depositSingle: protocol mint from **pre-intake** product vs `kLast`. Withdraw / withdrawSingle: protocol mint **before** user burn. Set `kLast` post-op when fee-on (else 0). User’s own deposit capital not taxed as growth in same op |
| D73 | SE previews are fee-inclusive SoT | Bound SE `previewExchangeIn` / `previewExchangeOut` include all SE fees; preview == execution. Hook does not re-derive SE fee math. Composition with CP is D78 |
| D74 | Fork stack deploy-if-missing | Base + Robinhood (4663): live PM/Permit2/fee-oracle when present; else deploy production-equivalent on fork. Permit2 at well-known address when possible |
| D75 | `feeTo` receivability | Out of PRD scope. Failed protocol mint reverts the whole liquidity op — no best-effort skip |
| D76 | Subsequent mint while supply > 0 | Geometric first mint **only** when `totalSupply == 0`. MINIMUM_LIQUIDITY-only residual → always subsequent mint |
| D77 | Zap internal swap event | Internal rebalance (zap-in and zap-out) **must emit `ZapSwap`** — no PoolManager `Swap` log for internal leg |
| D78 | SE × CP composition (claim-in / claim-out) | **Normative §4.2.** Pair-side: CP on claim inflow/outflow, never raw pair as if 1:1 under SE fees. Raw-side: CP on face raw amounts. Zap internal swaps use same composition as public swaps |
| D79 | Zap eligibility | **Zap-eligible** ⇔ live **and** `totalSupply > MINIMUM_LIQUIDITY`. Applies to **`depositSingle` and `withdrawSingle`** and their previews. After full user exit (only MINIMUM_LIQUIDITY), both zaps **revert** — re-seed via proportional `deposit` only |
| D80 | `isExpectedHook` surface | Factory / internal only — not required hook ABI |
| D81 | `DepositSingle` event `amountIn` | Log **full user-supplied / pulled input**. Residual refund after zap is separate (no required `Refund` event v1) |
| D82 | Protocol fee WAD bounds | **No product max cap** on `dexFeeWad` / `ownerFeeShare` |
| D83 | `kLast` overflow | **Accepted Uni V2-class risk** at extreme scales |

### 3.7 Implementation edges (locked)

| ID | Topic | Value |
|----|--------|-------|
| O1 | First vs subsequent mint | Geometric only if `totalSupply == 0`; else ratio clamp (incl. MINIMUM_LIQUIDITY residual) |
| O1a | Zap-in split | ConstProdUtils `_swapDepositSaleAmt` peer with fee 300/100_000; one solve on 1e18-normalized reserves; internal swap uses D78; SE drift → clamp/refund residual — no binary search |
| O2 | API naming | `deposit` / `depositSingle` / `withdraw` / `withdrawSingle` + previews + `previewZapSplit`. Permit2: §7.1 names. No required `depositZap` alias |
| O3 | Decimal normalize | `toWad(a,d) = a * 10**(18-d)` if `d ≤ 18`; if `d > 18`, floor divide. Missing decimals → 18 |
| O4 | Internal swap settle | Shared buffer/unwrap/raw transfer helpers — **no** PoolManager unlock for zap-in or zap-out |
| O5 | Withdraw SE math | `seOut = seBal * lp / totalSupply` **pre-burn** (after protocol mint dilution if fee-on) |
| O6 | Raw withdraw math | `rawOut = rawBal * lp / totalSupply` **pre-burn** same supply basis |
| O7 | Integer sqrt | Floor Babylonian / Uni V2 / ConstProdUtils peer |
| O8 | Amount index order | `amount0`/`amount1` = pool `currency0`/`currency1` only; `currency0` = **lower address** of raw vs pair |
| O9 | Ctor arg order | Free documentation order `(se, pairToken, rawToken)`; pool order always address sort |
| O10 | LP ERC-20 location | Same mined hook contract |
| O11 | Claim/raw re-read | Re-read raw balance + **virtual pair reserve** after buffer/unwrap/transfer that changes inventory when the next step needs post-inventory state (e.g. post-buffer LP mint / `kLast`). **Do not** re-quote an already-solved CP/swap mid-flight after buffer (see O13) |
| O12 | CP formulas | Exact-in / exact-out on wad reserves with D19 fee via ConstProdUtils `_saleQuote` / `_purchaseQuote`. Exact-in floor out; exact-out ceil (+1) in |
| O13 | **Buffer-last + quote-before-buffer** | For any path that buffers `pairToken`→SE: (1) compute all CP / residual-swap / split quotes against the **pre-buffer** book (raw reserve × virtual pair reserve); (2) execute non-buffer inventory moves (take raw, unwrap SE→pair, pays) as needed; (3) **buffer pair as the final SE inventory step**; (4) then mint user LP (when the path mints) and/or set `kLast` from **post-buffer** effective reserves. Buffering must **not** mid-step reprice swaps. Zap-out residual sell: **single** closed-form quote on remaining book **before** any residual buffer |
| O14 | Exact-out SE invert | CP invert via ConstProdUtils; SE invert via fee-inclusive previews / closed-form dilution algebra for ERC-4626 wrapper SE. **No** unbounded binary search as primary product law |
| O15 | Permit2 placement | Permit2 packing lives in **Target** unless contract size forces externalization |
| O16 | Adversarial DoD | Required: reentrancy, donation dilution, `feeTo` non-receivable (protocol mint reverts whole op — D75), SE revert mid-zap (full tx reverts; no partial inventory) |

### 3.8 DETF owner path (Alignment D9 / D30) — LOCKED 2026-08-22

When this hook is a true-DETF reserve, the DETF diamond is `owner` and `ownerOnlyLiquidity` is on. Public swaps stay public. Third-party LP add/remove still revert (D9).

Claim redeem (alignment D15) must **buy DETF (raw)** on the residual book after a proportional LP withdraw, in the **same transaction** as that withdraw. Donate (alignment D29) must `depositSingle` as owner. Uniswap SwapRouter and a nested `PoolManager.unlock` fail if the manager is already unlocked.

| # | Decision | Value |
|---|----------|--------|
| **D88** | `ownerOnlyLiquidity` | Deploy-time `PkgArgs` flag. **On** for every DETF-reserve instance. When on: `deposit` / `depositSingle` / `withdraw` / `withdrawSingle` (and Permit2 variants) are **`onlyOwner`**. Public `beforeSwap` stays permissionless. Flag **off** remains valid for non-DETF uses (D61P). |
| **D89** | Owner swap/LP while PM locked | Owner-only exact-in and exact-out swap **rawToken ↔ pairToken** against the **same effective book** as public swaps (D19+D78). **Same 0.3% trading fee as public swaps.** Must succeed when `PoolManager` is **already unlocked** in this transaction: settle on the **current** unlock **or** use **internal book settlement** (O4 / D85 class — no second `unlock`). Owner LP add/remove in that same lock state is required (D88). **Owner `depositSingle` when `totalSupply == MINIMUM_LIQUIDITY` is allowed** (public zaps still revert, D79). Same zap math as a live zap. **`lpOut` must be > 0** or revert — the DETF is joining to put LP on the Bond NFT. Non-owner cannot call this path. **Do not** send the DETF through Uniswap SwapRouter for D15/D29. |

Required surface (names may move; semantics are the law):

```text
ownerSwapExactIn(tokenIn, tokenOut, amountIn, minAmountOut, deadline) onlyOwner → amountOut
ownerSwapExactOut(tokenIn, tokenOut, amountOut, maxAmountIn, deadline) onlyOwner → amountIn
```

Previews: `previewSwapExactIn` / `previewSwapExactOut` already required (D68) and must match these owner paths. Combining withdraw+partial zap into one owner helper is allowed if D15 can still size exact-out = remaining shortfall and rejoin leftover pair.

D62 (hook ships without a DETF package in-tree) stays: DETF is a consumer. D88/D89 **are** hook DoD so a DETF can consume the ABI without a later hook revision.

---

## 4. Economics & flows

### 4.1 Effective reserves (normative) — raw face × **virtual pair reserve**

```text
// Inventory components (intentional)
seBal     = IERC20(SE).balanceOf(hook)                 // SE shares held
rawBal    = IERC20(rawToken).balanceOf(hook)           // raw face reserve

// VIRTUAL PAIR RESERVE (normative pair-side CP reserve — D15)
// Free pairToken.balanceOf(hook) is NOT the book (refund dust only — D71)
virtualPairReserve = seClaim
  = SE.previewExchangeIn(SE, seBal, pairToken)         // unwrap exact-in; fee-inclusive (D73)

// Pool order: currency0 = lower address(raw, pair); currency1 = higher
if currency0 == rawToken:
    x, y = rawBal, virtualPairReserve
else:
    x, y = virtualPairReserve, rawBal

xN = toWad(x, decimals(currency0))
yN = toWad(y, decimals(currency1))
// kProduct = xN * yN  (for kLast / protocol fee)
```

**Views:** `rawReserve()` = raw face; `seClaimSupply()` = virtual pair reserve; `reserveCurrency0/1()` = pool-ordered effective reserves; `currency0()`/`currency1()` = address-sorted pool currencies.

Re-read raw + virtual pair reserve when the next step needs post-inventory state (O11). **Do not** re-quote CP mid-flight after buffer (O13).

**Live:** \(x > 0\) and \(y > 0\).  
**Zap-eligible (D79):** live **and** `totalSupply > MINIMUM_LIQUIDITY` (Uni V2 locked dust residual).

### 4.2 Public swap (CP + D19 + D78)

**Permissions:** `beforeSwap` + `beforeSwapReturnDelta`.  
**Constants:** `feePercent = 300`, `feeDenominator = 100_000`.

Work in **wad** for CP; convert to raw for ERC-20/SE/PM.

#### 4.2.1 Exact-in — pairToken → rawToken

```text
// 1) Claim inflow from buffering raw pair amountIn (fee-inclusive SE preview)
claimIn = preview_buffer_pair_to_claim(SE, amountInRaw)
//    claimIn ≤ amountInRaw when buffer usage fee > 0

// 2) CP on claimIn vs current effective reserves (D19 fee)
//    reserveIn = seClaim (pair-side reserve), reserveOut = rawBal
rawOut = _saleQuote(claimIn, seClaim, rawBal, 300, 100_000)   // floor; wad-aware

// 3) Settle
take pairToken amountInRaw from PoolManager → hook
buffer SE: exchangeIn(pair→SE, amountInRaw) with minOut = SE preview (tight)
pay rawOut rawToken from hook inventory → settle to user/PM
// Forbidden: feed amountInRaw into CP as if claimIn == amountInRaw when fees make them differ
```

#### 4.2.2 Exact-in — rawToken → pairToken

```text
// 1) CP on face raw amountIn (no SE composition on raw in)
//    reserveIn = rawBal, reserveOut = seClaim
claimOut = _saleQuote(amountInRaw, rawBal, seClaim, 300, 100_000)  // claim/pair out target

// 2) Settle
take rawToken amountInRaw from PoolManager → hook inventory
unwrap SE → pair: exchangeOut (or exchangeIn SE→pair peer) for claimOut pair with fee-inclusive SE out preview
pay pair to user/PM
```

#### 4.2.3 Exact-out — pairToken → rawToken (user wants exact rawOut)

```text
// 1) CP invert: required claimIn such that sale yields ≥ rawOut (ceil)
claimInNeeded = _purchaseQuote(rawOut, seClaim, rawBal, 300, 100_000)  // ceil peer

// 2) Invert SE buffer: raw pair amountIn such that claimIn_preview ≥ claimInNeeded (ceil)
amountInRaw = invert_buffer_pair_to_claim_ceil(SE, claimInNeeded)

// 3) Settle: take amountInRaw pair → buffer; pay exact rawOut
```

#### 4.2.4 Exact-out — rawToken → pairToken (user wants exact pairOut)

```text
// 1) Invert unwrap if needed: claim/SE shares required to deliver ≥ pairOut (fee-inclusive SE)
//    Often: claimOutNeeded such that preview unwrap delivers pairOut (ceil)
claimOutNeeded = invert_unwrap_to_pair_ceil(SE, pairOut)  // or pairOut if 1:1 claim units

// 2) CP invert: raw amountIn such that sale yields ≥ claimOutNeeded (ceil)
amountInRaw = _purchaseQuote(claimOutNeeded, rawBal, seClaim, 300, 100_000)

// 3) Settle: take raw; unwrap exact pairOut; pay pair
```

**`previewSwapExactIn` / `previewSwapExactOut`:** same composition; match execution within dust under the actual SE fee model (D73 / D78) — hermetic ERC-4626 wrapper SE dilution on buffer is expected.

### 4.3 Proportional deposit

```text
Pull amount0, amount1 (pool order) from msg.sender (or Permit2)
If totalSupply == 0:
  require both > 0
  transfer raw portion to hook inventory
  // buffer-last (O13): buffer pair → SE as final SE inventory step
  buffer pair portion → SE
  re-read effective reserves (raw × virtual pair); geometric mint; MINIMUM_LIQUIDITY → address(0)
  // first mint: no protocol mint while kLast == 0
else:
  // D57 first if fee-on: protocol mint from PRE-INTAKE product vs kLast (D72)
  clamp to ratio; refund excess to msg.sender
  intake raw; buffer pair last (O13)
  re-read post-buffer; subsequent mint LP to `to` using post-dilution totalSupply
Update kLast when fee-on (else 0) — post-buffer product
```

### 4.4 Zap-in (`depositSingle`)

Require zap-eligible (D79).  
Protocol mint (if fee-on) from **pre-zap** product before user mint (D72).  
All internal swap quotes use pre-buffer book; **buffer pair last** when the path intakes pair (O13).

**tokenIn == pairToken:**

1. Closed-form sale amount (fee-aware O1a) against **virtual pair reserve**  
2. Internal swap pair→raw (claim-in CP on pre-buffer book; pay raw from inventory) — emit **`ZapSwap`**  
3. Proportional add: remaining pair + raw received  
4. **Buffer remaining pair last** → SE  
5. Mint LP on post-buffer effective reserves; update `kLast`  

**tokenIn == rawToken:**

1. Closed-form sale amount against **raw reserve**  
2. Internal swap raw→pair (CP; unwrap pair from SE) — emit **`ZapSwap`**  
3. Proportional add: remaining raw + pair received  
4. **Buffer pair proceeds last** → SE  
5. Mint LP on post-buffer effective reserves; update `kLast`  

Emit **`DepositSingle`** with `amountIn` = full pull (D81).

### 4.5 SE I/O matrix (normative)

| Path | Direction | Call shape |
|------|-----------|------------|
| Buffer pair → SE | deposit / swap-in / zap pair-in | `exchangeIn(pairToken → SE)` ; minOut = tight SE preview |
| Unwrap SE → pair (withdraw exact-in of shares) | proportional withdraw / zap-out realize | `exchangeIn(SE → pairToken)` of pro-rata seOut shares |
| Unwrap SE → pair (swap exact out / claim out) | swap-out / zap internal | `exchangeOut(SE → pairToken)` peer as dual C15 / single-wrapper settle |

Tight bounds = fee-inclusive SE previews (D73). Under-delivery → revert (no partial fill). SE deadline = `block.timestamp` when required.

### 4.6 Zap-out (`withdrawSingle`) — normative accounting

Require zap-eligible (D79) and `tokenOut ∈ {rawToken, pairToken}`.

#### 4.6.1 Inventory snapshot (before user burn)

```text
// After optional D57 protocol mint (dilutes totalSupply):
S     = totalSupply          // post-protocol-mint
seBal = IERC20(SE).balanceOf(hook)
rawBal = IERC20(rawToken).balanceOf(hook)
seClaim = preview unwrap of seBal

// User pro-rata (floor) — same basis as proportional withdraw (O5/O6):
rawUser = rawBal * lpAmount / S
seUser  = seBal  * lpAmount / S
```

#### 4.6.2 Shared realize

```text
burn lpAmount from msg.sender (or allowance path)
// User-owned inventory now conceptually rawUser + seUser (still on hook until paid)

// Unwrap user SE shares → pair (realize pair leg):
pairUser = unwrap seUser → pairToken   // exchangeIn SE→pair; lands on hook
// Remaining book (other LPs) after burn + seUser extract:
//   rawRemain  = rawBal - rawUser
//   seRemain   = seBal - seUser
//   seClaimRem = preview unwrap seRemain
// Free pair on hook from unwrap: pairUser (user’s, not yet in CP reserves as SE claim)
```

#### 4.6.3 tokenOut == pairToken (sell all residual raw)

```text
// User keeps pairUser; sells rawUser into remaining book for more pair.
// QUOTE FIRST on pre-buffer remaining book (O13) — single closed-form solve:
//   reserveIn  = rawRemain
//   reserveOut = seClaimRem   // virtual pair reserve of remaining LPs
//   amountIn   = rawUser  (100% residual — no partial sell, D34a)
//   claimOut / pairFromSwap = _saleQuote(rawUser, rawRemain, seClaimRem, 300, 100_000)
// Execute: keep rawUser on hook as swap in; unwrap claimOut from seRemain → pair
// Pay user: pairUser + pairFromSwap
// Post: intentional inventory = remaining LPs’ raw + SE only
// Refund free pair dust to msg.sender if any above MAX_DUST_WEI
// kLast post-op when fee-on (no mid-step re-quote)
```

#### 4.6.4 tokenOut == rawToken (sell all residual pair)

```text
// User keeps rawUser; sells pairUser into remaining book for more raw.
// QUOTE FIRST on pre-buffer remaining book (O13) — single closed-form solve:
//   claimIn = preview_buffer_pair_to_claim(SE, pairUser)   // vs virtual reserve, D78
//   reserveIn  = seClaimRem   // remaining virtual pair reserve BEFORE buffering sold pair
//   reserveOut = rawRemain
//   rawFromSwap = _saleQuote(claimIn, seClaimRem, rawRemain, 300, 100_000)
// Execute (buffer LAST):
//   pay rawFromSwap from rawRemain to user path
//   buffer pairUser → SE as final SE inventory step (lands into virtual pair reserve)
// Pay user: rawUser + rawFromSwap
// Post: intentional inventory only; refund free pair dust if any
// kLast post-op when fee-on — buffering must not reprice the residual swap
```

#### 4.6.5 Invariants (must hold after successful zap-out)

1. User receives **only** `tokenOut` (plus any dust refund of the other currency ≤ dust policy).  
2. Hook free **pairToken** balance ≤ `MAX_DUST_WEI` (else refund excess to `msg.sender`).  
3. Hook **rawToken** balance = remaining LPs’ raw inventory only (no stranded “user raw”).  
4. Hook **SE shares** = remaining LPs’ shares only.  
5. Book remains live if remaining LPs + MINIMUM_LIQUIDITY residual still imply both reserves > 0; if user was last economic LP, residual is MINIMUM_LIQUIDITY dust book (Uni V2 peer).  
6. **`ZapSwap` emitted** with raw amounts actually swapped on the internal leg.  
7. **`WithdrawSingle` emitted** with `amountOut` paid.  
8. If residual swap would require more out-reserve than available under CP → **revert** (user should lower `lpAmount` or use proportional withdraw).  
9. `amountOut >= minAmountOut` and `block.timestamp <= deadline` else revert.  
10. Previews (`previewWithdrawSingle`) simulate D57 + full residual swap composition so preview == execution under the actual SE fee model (D73); residual quote is pre-buffer (O13).

### 4.7 Proportional withdraw

```text
(optional D57 protocol mint before burn)
seOut = seBal * lpAmount / totalSupply   // pre-burn, floor
rawOut = rawBal * lpAmount / totalSupply
burn lpAmount
transfer rawOut to `to`
unwrap seOut → pairToken to `to`
returns (amount0, amount1) pool order
update kLast
```

### 4.8 Preview fidelity

| Preview | Must match execution |
|---------|----------------------|
| `previewDeposit` | LP + used0/used1 after clamp + protocol mint dilution |
| `previewDepositSingle` | LP amount |
| `previewZapSplit` | amountToSwap, amountOtherOut, amountKeptIn (SE-aware) |
| `previewWithdraw` | amount0, amount1 |
| `previewWithdrawSingle` | amountOut (incl. residual internal swap + SE composition; quote pre-buffer) |
| `previewSwapExactIn` / `Out` | claim composition on pair side; face raw on raw side |

Tolerance: ≤ `MAX_DUST_WEI` only when SE documents multi-leg dust.

---

## 5. Package layout (normative)

```text
contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md   # this file
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on

  interfaces/
    IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol

  UniswapV4SingleStandardExchangeBufferConstantProductHook.sol              # mined contract
  UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol
  UniswapV4SingleStandardExchangeBufferConstantProductHookCommon.sol
  UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol
  UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol          # optional split
  UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol      # optional split
  UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol

  # FORBIDDEN for hook product:
  #   *Facet.sol, *DFPkg.sol (hook instance)
```

---

## 6. Public surface (required — D68)

### 6.1 Bindings & views

```text
poolManager()
feeOracle()
standardExchange()
pairToken()
rawToken()
currency0()                  // lower address of raw vs pair (D7)
currency1()                  // higher address
permit2()                    // well-known address
tradingFeePercent()          // 300
tradingFeeDenominator()      // 100_000
kLast()
dexSwapFeeAndFeeTo()         // resolved oracle view for address(this)
// or equivalent: dexSwapFee() + feeTo()
rawReserve()                 // face raw inventory used in CP
seClaimSupply()              // VIRTUAL PAIR RESERVE (SE claim in pairToken) — not free pair
reserveCurrency0()           // effective x (pool order)
reserveCurrency1()           // effective y (pool order)
isLive()
isZapEligible()
```

### 6.2 Liquidity

```text
deposit(amount0, amount1, to, minLpAmount, deadline)
  → (lpAmount, used0, used1)

depositSingle(tokenIn, amountIn, to, minLpAmount, deadline)
  → lpAmount

withdraw(lpAmount, to, minAmount0, minAmount1, deadline)
  → (amount0, amount1)

withdrawSingle(lpAmount, tokenOut, to, minAmountOut, deadline)
  → amountOut
```

**Param order note:** match dual peer where present: amounts, `to`, mins, `deadline`. Plan freezes exact Solidity signatures bit-identically to §7.1.

### 6.3 Previews

```text
previewDeposit(amount0, amount1) → (lpAmount, used0, used1)
previewDepositSingle(tokenIn, amountIn) → lpAmount
previewZapSplit(tokenIn, amountIn) → (amountToSwap, amountOtherOut, amountKeptIn)
previewWithdraw(lpAmount) → (amount0, amount1)
previewWithdrawSingle(lpAmount, tokenOut) → amountOut
previewSwapExactIn(zeroForOne, amountIn) → amountOut
previewSwapExactOut(zeroForOne, amountOut) → amountIn
```

### 6.3b Owner-during-lock (D88 / D89)

```text
ownerSwapExactIn(tokenIn, tokenOut, amountIn, minAmountOut, deadline) → amountOut   // onlyOwner
ownerSwapExactOut(tokenIn, tokenOut, amountOut, maxAmountIn, deadline) → amountIn  // onlyOwner
```

When `ownerOnlyLiquidity` is on, liquidity functions in §6.2 are `onlyOwner`. Owner swaps/LP must run while PoolManager is already unlocked (D89).

### 6.4 ERC-20 (LP)

Minimal ERC-20 + metadata (`name`, `symbol`, `decimals=18`, `totalSupply`, `balanceOf`, `allowance`, `approve`, `transfer`, `transferFrom` + Transfer/Approval events).

### 6.5 Events (v1 required)

| Event | Notes |
|-------|--------|
| `Deposit` | sender, to, amount0, amount1, used0, used1, lpAmount — used amounts after clamp |
| `DepositSingle` | sender, to, tokenIn, amountIn (**full pull** D81), lpAmount |
| `Withdraw` | sender, to, lpAmount, amount0, amount1 |
| `WithdrawSingle` | sender, to, lpAmount, tokenOut, amountOut |
| `ZapSwap` | sender, tokenIn, tokenOut, amountIn, amountOut (internal rebalance; zap-in and zap-out) |

### 6.6 Errors (minimum set)

Zero/invalid binding; `LiquidityNotAllowed`; `NotPoolManager`; `NotLive`; `NotZapEligible`; `DeadlineExpired`; slippage mins; `AlreadyInitialized` / second pool; zero amounts; insufficient reserves for swap/zap. Custom names: plan invents; behaviors locked here.

---

## 7. FactoryService, Permit2, protocol fee surface

### 7.1 Required Solidity-shaped surface (normative)

```solidity
// --- Bindings ---
function poolManager() external view returns (address);
function feeOracle() external view returns (address);
function standardExchange() external view returns (address);
function pairToken() external view returns (address);
function rawToken() external view returns (address);
function currency0() external view returns (address);  // lower address
function currency1() external view returns (address);  // higher address
function permit2() external view returns (address);

// --- Reserves / live ---
function rawReserve() external view returns (uint256);           // face raw
function seClaimSupply() external view returns (uint256);       // virtual pair reserve
function reserveCurrency0() external view returns (uint256);
function reserveCurrency1() external view returns (uint256);
function isLive() external view returns (bool);
function isZapEligible() external view returns (bool);

// --- Fees / kLast ---
function tradingFeePercent() external view returns (uint256);      // 300
function tradingFeeDenominator() external view returns (uint256);  // 100_000
function kLast() external view returns (uint256);
function dexSwapFeeAndFeeTo() external view returns (address feeTo, uint256 dexFeeWad);
// equivalent split views OK if plan documents

// --- Liquidity ---
function deposit(
    uint256 amount0,
    uint256 amount1,
    address to,
    uint256 minLpAmount,
    uint256 deadline
) external returns (uint256 lpAmount, uint256 used0, uint256 used1);

function depositSingle(
    address tokenIn,
    uint256 amountIn,
    address to,
    uint256 minLpAmount,
    uint256 deadline
) external returns (uint256 lpAmount);

function depositWithPermit2Signature(
    uint256 amount0,
    uint256 amount1,
    address to,
    uint256 minLpAmount,
    uint256 deadline,
    bytes calldata permit2Data
) external returns (uint256 lpAmount, uint256 used0, uint256 used1);

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

function withdrawSingle(
    uint256 lpAmount,
    address tokenOut,
    address to,
    uint256 minAmountOut,
    uint256 deadline
) external returns (uint256 amountOut);

// --- Previews ---
function previewDeposit(uint256 amount0, uint256 amount1)
    external view returns (uint256 lpAmount, uint256 used0, uint256 used1);

function previewDepositSingle(address tokenIn, uint256 amountIn)
    external view returns (uint256 lpAmount);

function previewZapSplit(address tokenIn, uint256 amountIn)
    external view
    returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn);

function previewWithdraw(uint256 lpAmount)
    external view returns (uint256 amount0, uint256 amount1);

function previewWithdrawSingle(uint256 lpAmount, address tokenOut)
    external view returns (uint256 amountOut);

function previewSwapExactIn(bool zeroForOne, uint256 amountIn)
    external view returns (uint256 amountOut);

function previewSwapExactOut(bool zeroForOne, uint256 amountOut)
    external view returns (uint256 amountIn);

// Minimal ERC-20 + metadata on same contract (D23 / O10)
// Plus vault/SE compatibility (§7.6)
// NOT required: isExpectedHook (D80)
```

### 7.6 Vault / Standard Exchange compatibility (normative — D84–D87)

**Intent:** Integrators that already speak IndexedEx vault/SE can discover reserves and run **exact-in/out book swaps** without learning a new ABI. **Proportional and zap LP routes remain mandatory first-class APIs** — SE In/Out does **not** replace them.

#### 7.6.1 Surface layering

| Layer | API | Role |
|-------|-----|------|
| V4 public swap | `beforeSwap` + PoolManager settle | AMM for the V4 pool |
| SE compatibility swap | `IStandardExchangeIn` / `IStandardExchangeOut` | Same book pricing; **direct** hook settle (no PM); `pretransferred` supported |
| Proportional LP | `deposit` / `withdraw` | Dual-sided LP mint/burn |
| Zap LP | `depositSingle` / `withdrawSingle` | Single-asset LP mint/burn |
| Discovery | `IBasicVault` + `IStandardVault` | tokens, reserves, types, fee typing |

#### 7.6.2 `IStandardExchangeIn` / `IStandardExchangeOut`

Supported routes (**only**):

| tokenIn | tokenOut | Behavior |
|---------|----------|----------|
| `pairToken` | `rawToken` | Exact-in / exact-out CP (§4.2.1 / §4.2.3): claim-in composition (D78), buffer pair **last** (O13), pay raw |
| `rawToken` | `pairToken` | Exact-in / exact-out CP (§4.2.2 / §4.2.4): face raw in, unwrap pair out |

**Must match** `previewSwapExactIn` / `previewSwapExactOut` composition for the same direction (within dust) when amounts align with V4 zeroForOne mapping.

**Reject** (`UnsupportedRoute` / peer SE error):

- Either token not in `{rawToken, pairToken}`  
- `tokenIn == tokenOut`  
- SE share address as tokenIn or tokenOut (SE shares are **not** a pool currency)  
- Using SE In/Out to mint/burn LP  

**Execution rules:**

- Live book required (same as public swap).  
- D19 trading fee retained in reserves.  
- Buffer-last / quote-before-buffer (O13).  
- No PoolManager unlock (D85).  
- `nonReentrant` on mutative SE entrypoints.  
- Previews fee-inclusive SE SoT (D73).  

**Permit2:** not required on SE In/Out v1 (callers may pretransfer or approve). Optional later.

#### 7.6.3 `IBasicVault`

```text
vaultTokens() → [currency0, currency1]   // address sort; length 2
reserveOfToken(rawToken)  → rawReserve()           // face
reserveOfToken(pairToken) → seClaimSupply()        // VIRTUAL PAIR RESERVE
reserveOfToken(other)     → 0  (or revert — plan picks one; prefer 0 peer vault)
reserves() → [reserveCurrency0(), reserveCurrency1()]
```

#### 7.6.4 `IStandardVault`

```text
vaultFeeTypeIds()  // bytes32 used with fee oracle typing for address(this)
contentsId()       // hash of vaultTokens / contents
vaultTypes()       // ERC165 interface ids this instance supports
vaultConfig()      // VaultConfig aggregate
```

`vaultTypes` **must** include at least:

- `type(IStandardExchangeIn).interfaceId`
- `type(IStandardExchangeOut).interfaceId`
- `type(IBasicVault).interfaceId`
- `type(IStandardVault).interfaceId`
- product hook interface id (if distinct)

Wire so fee oracle can resolve growth fee for `address(this)` as for other vaults (D57 already uses `dexSwapFeeAndFeeToOfVault(address(this))`).

#### 7.6.5 ERC165

If Option A monomorph: implement `supportsInterface` for the above ids (and ERC-20 if desired).  
If Option B Diamond: factory base ERC165 + loupe as peers.

### 7.2 FactoryService

```text
DEFAULT_SALT_NAMESPACE = "uv4-single-se-buffer-constant-product-hook-"

deployHook(create3Factory, poolManager, feeOracle, se, pairToken, rawToken)
deployHook(..., saltNamespace)  // empty → default

// Salt = hash(namespace, poolManager, feeOracle, se, pairToken, rawToken, mineNonce)
// Mine until address flags match D54
// Idempotent per (namespace, binding)
// Ctor args encode immutables
```

ACL: existing create3 `onlyOwnerOrOperator`. **Not** on IndexedexManager vault registry.

### 7.3 Permit2 packing (normative DoD)

Canonical Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3`.  
Interfaces: Crane `ISignatureTransfer` / `IAllowanceTransfer`.  
**No witness** in v1 (plain transfer-to-hook; spender = hook).  
Owner of tokens = **`msg.sender`**. Recipient of pulls = **`address(this)`** (hook).  
**No** Permit2 on `withdraw` / `withdrawSingle` / swaps.

#### SignatureTransfer — proportional `depositWithPermit2Signature`

```text
// Dual-token batch (required for proportional dual pull)
// Index order normative: permitted[0] = currency0, permitted[1] = currency1
permit2Data = abi.encode(
  ISignatureTransfer.PermitBatchTransferFrom permit,  // permitted.length == 2
  bytes signature
)
// Requirements (else revert):
//   permit.permitted[0].token == currency0 && amount covers amount0
//   permit.permitted[1].token == currency1 && amount covers amount1
// Call: permitBatchTransferFrom → transferDetails[i].to = hook,
//       requestedAmount[0] = amount0, requestedAmount[1] = amount1
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
// Pre: user ERC-20 approved Permit2; user set Permit2 allowance for (token, hook)
// Proportional: transferFrom currency0 for amount0, then currency1 for amount1 (pool order)
// Single: transferFrom tokenIn for amountIn
// Then shared _deposit / _depositSingle
```

**DoD tests:** execute real Permit2 at well-known address with this packing; wrong signature / wrong spender / expired / insufficient allowance / wrong batch token order revert.

### 7.4 Protocol growth fee surface (D57 / D61–D63 / D67 / D72)

```text
(feeTo, dexFeeWad) = feeOracle.dexSwapFeeAndFeeToOfVault(address(this))
// dexFeeWad = protocol GROWTH share (despite oracle name "dexSwapFee") — not D19 trading fee
// No product max cap (D82)
ownerFeeShare = dexFeeWad * 100_000 / 1e18   // floor; D62
feeOn = (address(feeTo) != 0 && dexFeeWad != 0)

// Effective reserves for k: wad-normalized pool-order (D63)
// xN, yN from §4.1; kProduct = xN * yN

// --- Deposit / depositSingle (D72) ---
// 1. Read preIntakeK from reserves BEFORE this op’s intake/buffer/zap
// 2. if feeOn && kLast != 0:
//      protocolLp = ConstProdUtils._calculateProtocolFee(
//                     totalSupply, preIntakeK, kLast, ownerFeeShare)
//      if protocolLp > 0: mint protocolLp to address(feeTo)  // fail ⇒ whole op reverts (D75)
// 3. Clamp/refund; intake / internal zap; re-read reserves
// 4. Mint user LP from reserve deltas using post-dilution totalSupply
// 5. if feeOn: kLast = postOpK; if !feeOn: kLast = 0

// --- Withdraw / withdrawSingle (D72) ---
// 1. Read currentK from reserves before user burn
// 2. if feeOn && kLast != 0: mint protocol LP from (currentK, kLast)
// 3. Burn user LP; pro-rata seOut/rawOut from post-protocol-mint totalSupply; unwrap/swap
// 4. if feeOn: kLast = postOpK; if !feeOn: kLast = 0

// Previews (D61): same fee-on mint simulation before user LP/out math
// k growth sources (D67): D19 retention, SE yield, donations — all fee-eligible
```

First mint: no protocol mint while `kLast == 0`; after first mint, set `kLast = xN * yN` when fee-on.

### 7.5 Events (normative)

```solidity
event Deposit(
    address indexed sender,
    address indexed to,
    uint256 amount0,      // pool currency0 used (after clamp)
    uint256 amount1,
    uint256 used0,
    uint256 used1,
    uint256 lpAmount
);

/// @dev amountIn = full user-supplied / pulled input (D81)
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
    uint256 amount0,
    uint256 amount1
);

event WithdrawSingle(
    address indexed sender,
    address indexed to,
    uint256 lpAmount,
    address tokenOut,
    uint256 amountOut
);

/// @dev Internal rebalance (zap-in or zap-out); raw amounts actually swapped
event ZapSwap(
    address indexed sender,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOut
);
```

---

## 8. Security notes

1. **Inventory solvency:** never pay raw or unwrap more than pro-rata / CP allows; swaps must not strand unpaid deltas.  
2. **SE share / raw donations** dilute LPs — accepted.  
3. **`feeTo` receivability:** mint failure reverts liquidity op (D75).  
4. **Reentrancy:** liquidity paths locked; SE/PM locks on swaps.  
5. **No CL path** to drain via `modifyLiquidity`.  
6. **Zap-out** must not leave material free pair on hook (refund dust only); raw residual for other LPs only.  
7. **rawToken == pairToken** forbidden at deploy.  
8. **Do not** treat SE shares as swap currency with users — only pair and raw.  
9. **Claim-in footgun:** feeding face pair into CP while SE dilution makes claim-in &lt; face under-funds book — D78 mandatory against **virtual pair reserve**.  
10. **Zap-out last-LP impact:** selling residual against MINIMUM_LIQUIDITY dust book can severe-impact or naturally revert — accepted (D34a); locked dust prevents full insolvency; users use proportional withdraw when thin.  
11. **Buffer-last:** never re-quote CP after buffer mid-path (O13).  
12. **Adversarial:** reentrancy, donations, non-receivable `feeTo`, SE revert mid-zap (O16).

---

## 9. Relationship to future UniV4 SE DETF

Informative only — **not** hook DoD:

| DETF need | Hook surface |
|-----------|--------------|
| Reserve pool DETF ↔ USDC | `rawToken=DETF`, `pairToken=USDC`, SE = backing SE |
| Bond open proportional | `deposit(detf, usdc, …)` → LP to bond NFT package |
| Direct claim new money | `depositSingle(USDC, …)` → LP to rebasing/protocol |
| Free DETF → claim | `depositSingle(DETF, …)` → LP to protocol |
| Claim redeem USDC | `withdrawSingle(lp, USDC, …)` |
| Claim redeem DETF (alignment D15) | Prop `withdraw` of id 0 LP slice, then **owner exact-out swap** leftover pair → DETF on the residual book (D89). Not SwapRouter. |
| Donate (alignment D29) | Owner `depositSingle` (pair or DETF), LP `to` = Bond NFT |
| Synthetic / gates | DETF app layer — not this PRD |

Hook PRD **must not** wait on a DETF package to merge. DETF PRD **must** depend on this hook’s frozen ABI **including D88/D89**.

---

## 10. Test expectations (product-level)

Production-first: no mock hook/SE SUT.

| Area | Required |
|------|----------|
| Hermetic SE | **Only** production ERC-4626 **Wrapper** SE wrapping mintable pairToken (D60/D63T) — no multi-SE matrix |
| Tokens | Mintable raw + pair ERC-20s (forks may deploy same) |
| Virtual reserve | CP/mid use `seClaimSupply` not free pair balance |
| Vault/SE compat | SE In/Out both directions match book previews; BasicVault reserves; StandardVault types; ERC165 |
| LP APIs | deposit / depositSingle / withdraw / withdrawSingle still required (not collapsed into SE) |
| First mint | Geometric + MINIMUM_LIQUIDITY locked dust; reverts if sqrt &lt; MIN |
| Subsequent | Ratio clamp; after full exit residual, subsequent not geometric |
| Zap-in | Both directions when zap-eligible; reverts empty / MIN-only residual; buffer-last |
| Zap-out | Both directions when zap-eligible; quote residual pre-buffer; full residual sell; minAmountOut; ZapSwap |
| Swaps | Exact-in/out both ways; 0.3% retained; D78 vs virtual pair reserve |
| SE integration | ERC-4626 wrapper SE preview==exec (D73); dilution on buffer OK; SE fees orthogonal |
| Protocol fee | fee-on mint; D72 pre-intake; yield → growth fee-eligible; preview dilution; `kLast` post-buffer |
| Permit2 | Signature + allowance proportional + single packing §7.3 (Target unless size) |
| Adversarial | Reentrancy, donation, feeTo non-receivable, SE revert mid-zap (O16) |
| Forks | Base + Robinhood 4663; deploy-if-missing stack (D74); may deploy tokens + wrapper SE |
| One-pool | Second initialize reverts |
| DETF | Not required to merge |

---

## 11. Definition of Done

1. Package under D2 with CREATE3-mined hook + FactoryService.  
2. Binding validation D6; one pool per instance D12/D69; `currency0`/`currency1` views (lowest address = 0).  
3. `beforeAddLiquidity` reverts; swaps via beforeSwap deltas.  
4. Effective reserves = **raw face × virtual pair reserve** (D15); free pair not the book.  
5. Proportional deposit first mint + subsequent clamp/refund; **buffer-last** + post-buffer LP/`kLast` (O13).  
6. `depositSingle` both directions when zap-eligible; reverts when not (D79).  
7. `withdraw` both assets; `withdrawSingle` both directions when zap-eligible; reverts when not.  
8. Public swaps exact-in/out both ways; 0.3% fee retained; D78 on pair side vs virtual reserve.  
9. SE yield moves mid (virtual pair reserve ↑) without swap.  
10. Protocol growth mint + `kLast` when fee-on; preview == execution (incl. withdrawSingle).  
11. Permit2 signature + allowance deposit paths with §7.3 packing (Target unless size).  
12. All required previews strict with ERC-4626 wrapper SE preview==exec (D73); SE fees orthogonal (D70S demoted).  
13. Events: Deposit, DepositSingle, Withdraw, WithdrawSingle, ZapSwap.  
14. Hermetic **only** ERC-4626 wrapper SE + mintable raw/pair; no SUT mocks; thin Phase 0 green (D66).  
15. Base + Robinhood fork smokes (deploy-if-missing stack; may deploy tokens/SE).  
16. No DETF package required to merge hook.  
17. Zap-out: quote residual pre-buffer; buffer last when needed; invariants §4.6.5; Uni V2 locked dust + minAmountOut (D34a).  
18. Adversarial DoD: reentrancy, donation, feeTo non-receivable, SE revert mid-zap (O16).  
19. Size within real CREATE3/runtime limits (Option A libs or Option B Diamond — §2.4).  
20. **Vault/SE compatibility (D84–D87 / §7.6):** `IStandardExchangeIn`/`Out` exact-in/out raw↔pair match book previews; `IBasicVault` virtual pair reserve; `IStandardVault` types/config; proportional + zap APIs still present.  
21. **D88 / D89:** `ownerOnlyLiquidity` flag; owner exact-in/out swap + LP add/remove succeed when PoolManager is already unlocked; non-owner cannot use that path; public swaps still work.

---

## 12. Out of scope / deferred

- DETF diamond, bond NFT, rebasing claim, thresholds, natural expansion  
- Weighted AMM / multi-SE  
- CL hybrid  
- Native ETH  
- Rework of single wrapper pricing hook  
- Moving dual package under `constantProduct/dual` (optional later reorg)  
- LP Permit2 / permit on LP token  
- Max-impact guards on zap-out  

---

## 13. Open items for implementation plan only (not product blockers)

| Item | Guidance |
|------|----------|
| Exact file split Math vs ClaimLib | Plan discretion if Target grows large; Permit2 stays in Target unless size forces split (O15) |
| Custom error names | Implementor invents; behaviors locked here |
| Exact invert helper names for SE buffer/unwrap ceil | Plan maps to ERC-4626 wrapper SE preview APIs (O14) |
| Deposit event field list (used0/used1 vs dual) | Prefer this PRD’s Deposit with used0/used1; dual may differ — this package locks used fields |

**No remaining product Q&A required to implement** after v1.2 conversation locks.

---

## 14. Revision history

| Version | Date | Notes |
|---------|------|-------|
| v1.0 | 2026-08-04 | Initial PRD: single SE + raw leg CP buffer; dual peer fees/LP/Permit2; zap-in + zap-out; path `constantProduct/single`; independent of DETF |
| v1.1 | 2026-08-04 | Plan-readiness lock: Phase 0 ERC-4626 hard gate; D70S SE fees both directions; D34a zap-out thin-book; dual D57–D83 restated; §4.2/§4.6/§7.1–§7.5 |
| **v1.2** | **2026-08-04** | **Conversation locks:** product = Uni V2 swap fee + growth fee; SE fees orthogonal (D70S demoted); **virtual pair reserve** explicit (D15/§4.1); **buffer-last / quote-before-buffer** (O13); thin Phase 0 verify-only ERC-4626 **wrapper** SE; tests **only** ERC-4626 wrapper SE; dual pattern-copy OK (no dual Phase 0 gate); `currency0`/`currency1` required; Uni V2 locked dust; adversarial DoD (O16); Permit2 in Target unless size; forks may deploy tokens/SE; real size limits |
| **v1.3** | **2026-08-04** | **Vault/SE compatibility:** `IStandardExchangeIn`/`Out` + `IBasicVault` + `IStandardVault` required (D84–D87, §7.6); SE surface = direct book swap not LP; proportional/zap remain first-class; **D10 deploy flexible** monomorph vs Hook Diamond; factory salt **without** package address + premined V4 flags (§2.4) |
| **v1.4** | **2026-08-22** | Alignment D9/D30: **D88** `ownerOnlyLiquidity`; **D89** owner exact-in/out swap + LP while PoolManager is already unlocked (no SwapRouter / nested `unlock`). DETF D15 residual DETF buy + D29 donate consume this ABI. |

---

## 15. Approval

| Role | Sign-off |
|------|----------|
| Product | Pending (v1.3 vault/SE compatibility + deploy flexibility) |
| Protocol | Pending |

**Status: Draft v1.4 — product law + D88/D89 owner-during-lock; plan ready for implementor lock stamp, then code.**
