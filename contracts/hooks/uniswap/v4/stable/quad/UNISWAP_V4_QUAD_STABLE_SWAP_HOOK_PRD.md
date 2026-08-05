# PRD: Uniswap V4 Quad Stable Swap Hook (4-Asset StableSwap Curve)

**Name:** `UniswapV4QuadStableSwapHook`  
**Date:** 2026-08-03  
**Status:** **Draft v0.6.0** — StableSwap product law remains normative; **deploy / CREATE3 monomorph / product factory superseded**.  
**Package path:** `contracts/hooks/uniswap/v4/stable/quad/`  

> **DEPLOY SUPERSESSION (2026-08-04):** All CREATE3 monomorph instance deploy, `HookMinerCreate3` product mine, `UniswapV4QuadStableSwapHookFactory` as primary UX, and `saltNamespace` identity law are **superseded** by  
> [`UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_HOOK_FACTORY_REFACTOR_PRD.md`](./UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_HOOK_FACTORY_REFACTOR_PRD.md)  
> and the co-located hook-factory implementation plan.  
> **Current production path:** package DFPkg → vault registry `deployHookVault` → shared Uniswap V4 hook diamond package callback factory (CREATE2 flag-mined diamond).  
> Facets + package use CREATE3 only. Six pair doors via package `postDeploy` / permissionless `ensurePairPools`.  
> StableSwap math, rates, zap, fee-on-output, pair-door product policy in **this** PRD remain authoritative unless the refactor PRD explicitly revises them.

**Package kind:** IndexedEx **hook diamond package** (after refactor):

1. **Hook instance** — immutable diamond at CREATE2-mined address via shared hook factory; registered vault; LP ERC-20 on proxy via shared ERC20Permit facets.  
2. **Package + ensure** — `UniswapV4QuadStableSwapHookDFPkg` with `deployVault` / `ensurePairPools`; product CREATE3 monomorph factory **retired**.

**Behavioral / math reference (requirements harvest only — not deploy law, not package layout):**

- Multi-asset Uni V4 StableSwap hook designs that price 2–4 pegged assets with amplification \(A\), internal reserves, fungible LP, and pairwise V4 “doors” into shared inventory. This PRD restates the **required product behavior** in IndexedEx terms; implementors must **not** copy foreign factory/CREATE2/BaseHook/Ownable wiring.

**Sibling packages (do not conflate):**

| Package | Path | Role |
|---------|------|------|
| Single SE buffer | `contracts/hooks/uniswap/v4/standardExchange/` | Wrapper pool `underlying ↔ SE`; no multi-asset AMM |
| Dual SE buffer | `…/standardExchange/dual/` | CP AMM on **two** SE claim legs |
| Orbital sphere | `contracts/hooks/uniswap/v4/orbital/` | **3-asset** spherical invariant, single orbit |
| **This package** | `contracts/hooks/uniswap/v4/stable/quad/` | **4-asset** StableSwap (A-amplified) on **raw ERC-20 reserves** |

**Related Crane / IndexedEx standards (mandatory pattern sources):**

- Single buffer PRD (package shape, CREATE3 mine, settle pattern-copy, inheritance ban):  
  `contracts/hooks/uniswap/v4/standardExchange/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md`
- Dual buffer PRD (LP ERC-20 on hook, custom deposit surface, `beforeAddLiquidity` ban):  
  `contracts/hooks/uniswap/v4/standardExchange/dual/UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`
- Orbital PRD (multi-pool shared inventory + Repo/Target/Math peer for multi-asset hooks):  
  `contracts/hooks/uniswap/v4/orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md`
- Crane HookMiner: `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol`
- Crane math: `FixedPointMathLib` / `BetterMath` under `lib/crane/contracts/utils/`
- AGENTS.md — production-first tests; CREATE3; no mock SUT; no `new` facets

---

## 0. Terminology (normative)

| Term | Meaning in this PRD |
|------|---------------------|
| **Quad / n=4** | Exactly **four** bound ERC-20 assets per hook instance (v1). Not 2, not 3, not variable \(n\). |
| **Stable (product family)** | Package tree name under `hooks/uniswap/v4/stable/`. Hosts multi-asset StableSwap curve hooks (`quad`, and future `dual`/`triple` if added). |
| **Product name** | Canonical Solidity / package type: **`UniswapV4QuadStableSwapHook`**. Not Balancer WeightedMath; equal units after rate scaling only. |
| **StableSwap curve** | Curve-style invariant blending constant-sum and constant-product via amplification \(A\). Equal units after rate scaling. |
| **Rate-scaled reserve** | Token amount converted to **1e18 “stable units”** via decimal scale and optional rate oracle (see §4.3). |
| **Pair door** | A Uni V4 2-currency pool whose currencies are any ordered pair of the four bound tokens, all sharing **one** hook address and **one** shared reserve book. |
| **Witness legs** | For a swap on pair \((i,j)\), the other two tokens \(k,\ell\) still enter the invariant (may be zero). Solver must converge or the swap **reverts**. |
| **LP / shares** | Fungible ERC-20 minted by **this hook** — pro-rata claim on all four Repo reserves. Not V4 position NFTs. |
| **Repo reserves** | Authoritative inventory amounts in diamond-style storage. **Not** raw `balanceOf(hook)` alone. |
| **First-minted book** | `totalSupply > MINIMUM_LIQUIDITY` after a successful first `addLiquidity` (all four legs). Distinct from per-swap “live” gates. |
| **Swap-live (directed)** | For a directed pair swap: `reserves[in] > 0`, `reserves[out] > 0`, and the invariant solver converges on the post-trade state. **Witness legs may be zero** (D72). |
| **Zap-in** | Single- or multi-leg deposit that **rebalances via internal StableSwap exact-in swaps** toward the current reserve ratio, then performs a **proportional add** and mints LP. Depositor accepts curve price impact + fees on internal swaps. Public slippage guard: **`sharesMin` only** (D73). |
| **Zap-eligible** | First-minted book **and** all four `reserves[i] > 0`. Residual dust-only book (`totalSupply == MINIMUM_LIQUIDITY` only) is **not** zap-eligible. |
| **DoD** | Definition of Done — package complete when §8 is satisfied. |

---

## 1. Goal

Ship a **production-first Uniswap V4 hook package** that:

1. Binds **exactly four** ERC-20 assets and one V4 `PoolManager` per hook instance (e.g. USDC / USDT / DAI / USDS, or four like-kind LST wrappers with rate oracles).
2. Implements the **StableSwap invariant** for pricing on rate-scaled reserves with amplification coefficient \(A\):
   \[
   A \cdot n^{n} \cdot \sum x_i + D = A \cdot D \cdot n^{n} + \frac{D^{n+1}}{n^{n} \cdot \prod x_i}
   \]
   with \(n = 4\), \(x_i\) **1e18-normalized** (rate-scaled) reserves, \(D\) the invariant, \(A\) the **deploy-time immutable** amplification (no ramp in v1).
3. Exposes **up to six Uni V4 pair pools** (all \(\binom{4}{2}\) pairs) as swap entry points, **all pointing at the same hook address**, so every pair trade is priced against the **shared 4-asset reserve state**.
4. Holds **authoritative inventory in Repo** (hook-held raw ERC-20 settlement pattern-copied from peer hooks — see D18).
5. Mints a **single fungible ERC-20** LP representing pro-rata claim on all four reserve legs.
6. Provides **custom** `addLiquidity` / `removeLiquidity` on the hook; **forbids** native V4 `modifyLiquidity` / CL / donate.
7. Provides **zap-in** (v1 DoD): deposit one or more of the four tokens without a perfect ratio — internal StableSwap rebalance then proportional mint (see §4.8).
8. Settles swaps via **`beforeSwap` + `beforeSwapReturnDelta`** (custom accounting), pattern-copied to Crane settle order — **no** Solidity inheritance of OZ/`BaseHook` / `BaseTokenWrapperHook` / `DeltaResolver`.
9. Deploys hook instances via **existing** `create3Factory` + binding-aware `HookMinerCreate3` (same flag-mine law as buffer / orbital hooks).
10. Exposes an **on-chain permissionless factory** so any caller can deploy a new hook binding and **create all six** pair-pool combinations in one (or a tightly related) transaction flow — see **§5.5**.

### 1.1 Canonical user story (four stables)

```text
Hook binding (instance):
  token0..token3 = four ERC-20s, strict address ascending (D7)
  poolManager = factory immutable = canonical Uni V4 PoolManager on this chain (D67)
  lpFeePips = deploy-time LP fee (denominator 1e6; e.g. 500 = 0.05%)
  baseAmp = deploy-time amplification (unscaled user units; see D15)
  rateProviders[4] = optional IRateProvider per leg or address(0)

Inventory: Repo reserves[0..3] for the four tokens
LP: fungible auto-named ERC-20 (e.g. QS-USDC-USDT-DAI-USDS) on same contract

--- First liquidity ---
User calls addLiquidity(amounts[4], minAmounts[4], to, sharesMin)
  → all four amounts > 0 (D23 LOCKED)
  → first-mint shares from geometric mean of rate-scaled amounts − MINIMUM_LIQUIDITY
  → lock MINIMUM_LIQUIDITY permanently to address(0) (D47)
  → pull tokens; set reserves; post-state must be priceable (invariant converges)

--- Pools (factory, permissionless) ---
Anyone calls factory.deploy(tokens, lpFeePips, baseAmp, rateProviders, …)
  → mine+CREATE3 hook via ecosystem create3Factory
  → factory initializes ALL six address-sorted pair pools
       fee=lpFeePips, tickSpacing=1, hooks=hook, sqrtPriceX96=tick0
  → beforeInitialize validates each door
  → hook remains inert until first four-leg addLiquidity

--- Swap USDC → USDT (via USDC/USDT pool) ---
  → beforeSwap: identify in/out indices; load all four rate-scaled reserves + current A + D
  → exact-in: solve StableSwap for new out reserve; fee on **output** (D20)
  → exact-out: gross-up requested out by LP fee, then solve; reject zero input (D20a)
  → update Repo reserves; fee residual stays in book (D21 — no skim buckets)
  → settle deltas; return BeforeSwapDelta

--- Withdraw ---
removeLiquidity(shares, to, minAmounts[4])
  → burn LP → pro-rata four reserves → transfer; assert mins
```

### 1.2 Why this exists (product problem)

| Approach | Limitation |
|----------|------------|
| Uni V3/V4 CL multi-pairs | Capital fragmented across \(\binom{4}{2}\) 2-token books; multi-hop fees |
| Orbital (3-asset sphere) | Hard-capped at 3 assets; different geometry (not StableSwap \(A\)) |
| Curve / multi-stable off Uni | Not native to Uni V4 routing / UR / quoter surface |
| **This package (v1)** | Shared **4-asset** StableSwap book; six optional V4 doors; IndexedEx deploy/storage/settle standards |

v1 is the **productionization of multi-asset StableSwap on Uni V4 for exactly four tokens**, not a general \(n\)-coin factory and not Balancer weighted-pool math.

---

## 2. Product summary

### 2.1 What this package is

| Attribute | Value |
|-----------|--------|
| Primary artifact | CREATE3-mined single hook (Repo + Target + Math + Common) implementing V4 `IHooks` **plus** 4-asset LP ERC-20 |
| Binding | `(poolManager, token0..token3, lpFeePips, baseAmp, rateProviders[4] as IRateProvider|0)` — ctor immutables / set-once |
| Pool currencies | All **six** address-sorted pairs of the four bound tokens (factory creates all six; see §5.5) |
| Inventory | Authoritative **Repo `reserves[i]`**; settlement via pattern-copied take/sync/settle (D18) |
| Pricing | StableSwap invariant on **rate-scaled 1e18** reserves; \(n=4\); Newton-Raphson for \(D\) and target \(y\) |
| LP | Fungible ERC-20 on the hook; auto name/symbol; pro-rata four legs |
| Deposit | Proportional four-asset add + `sharesMin` + per-leg `minAmounts` |
| Zap-in | Single- or multi-leg imbalance deposit → internal swaps → proportional mint (**v1 DoD**); public slippage = **`sharesMin` only** |
| Withdraw | Pro-rata four-asset remove + per-leg mins |
| Swap | Via any **initialized** pair pool with **swap-live** gates (in/out reserves > 0 + convergent solve; witnesses may be zero) |
| PoolKey fee | **`fee = lpFeePips`** (same pips as hook LP fee); pricing still fully computed in hook StableSwap math |
| Deploy path | **On-chain permissionless factory** → existing `create3Factory` + `HookMinerCreate3` mine + **all-six pool `initialize`** |
| Access (hook) | **Fully permissionless** — no owner, no pause, no amp ramp, no fee skims |
| Access (factory) | **Permissionless `deploy*`** — any EOA/contract may deploy a new binding; no per-deploy allowlist |

### 2.2 What this package is not

- Not Balancer **WeightedMath** with free weight vectors \(w_i\) (v1 equal units after rate scale only).
- Not the Orbital sphere package (different invariant; 3 assets).
- Not single/dual SE buffer hooks (no Standard Exchange binding in v1).
- Not Uni V4 concentrated liquidity / Position Manager LP / tick bitmap.
- Not a Facet/DFPkg diamond for the **hook instance**.
- Not a second CREATE3 *infrastructure* factory (still uses ecosystem `create3Factory` for the hook bytecode).
- Not a DETF or vault registry product.
- Not a variable \(n \in \{2,3,4\}\) factory product — **quad only** in this package.
- Not a copy-paste of foreign `BaseHook` / Ownable-only pool factories without CREATE3 flag mining.
- Not first-liquidity mint inside the factory (factory deploys empty/inert hook + opens doors; LPs call `addLiquidity` after).

### 2.3 Non-goals (v1)

1. \(n \neq 4\) (dual/triple packages would be separate PRDs under `stable/`).  
2. Arbitrary Balancer-style weights / non-equal unit preferences.  
3. Yield buffering into SE / Morpho / ERC-4626 on the book (future composition PRD).  
4. Native ETH as a pool currency (**locked forbidden** — use WETH).  
5. Amp ramping / post-deploy \(A\) mutation.  
6. Hook/protocol fee skim buckets or withdrawers (all residual stays in reserves).  
7. Instance owner / pause / admin surface **on the hook**.  
8. Permit2 on hook deposit/swap/zap paths (v1).  
9. Binary-search solvers for routes — use Newton-Raphson closed solvers only.  
10. Subclassing orbital / dual / single buffer hooks.  
11. Shared TestBases with DETF Uni V4 packages.  
12. Deploying hooks with bare CREATE2 `new {salt}` that bypasses ecosystem `create3Factory` + flag mine (forbidden).  
13. Leaving `console.log` / debug logs in production sources.  
14. Trusting PoolManager `slot0` price for quoting (aggregators must use hook previews / V4 quoter through hook math).  
15. Rebasing tokens and fee-on-transfer tokens.  
16. Dynamic governance of **token set** after deploy (immutable binding).  
17. Factory-owned first bond / seeding of reserves (out of factory scope).  
18. Partial pair set as the **default** factory deploy path (default = **all six**; see D8 / §5.5 for ensure/repair).

---

## 3. Locked product decisions

> **Process:** Rows marked **LOCKED** are stakeholder-confirmed (2026-08-03 Q&A + quality pass) or peer-standard. §3.2 lists residual opens; as of **v0.5.2** none block the implementation plan.

| # | Decision | Value | Status |
|---|----------|--------|--------|
| D1 | Product name | **`UniswapV4QuadStableSwapHook`** (canonical) | **LOCKED** |
| D2 | Package location | `contracts/hooks/uniswap/v4/stable/quad/` | **LOCKED** |
| D3 | Math model | **StableSwap invariant** (\(n=4\)), not Orbital sphere, not Balancer WeightedMath | **LOCKED** |
| D4 | Asset count (v1) | **Exactly four** ERC-20s per instance | **LOCKED** |
| D5 | Binding | Ctor immutables: `poolManager`, **sorted** `token0..token3`, `lpFeePips`, `baseAmp`, per-token `IRateProvider` (or zero) | **LOCKED** |
| D6 | Token validation | Non-zero; **all pairwise distinct**; decimals in **[6, 18]** inclusive; **no native ETH** (`address(0)` forbidden) | **LOCKED** |
| D7 | Ctor / factory token order | Factory and hook require **`token0 < token1 < token2 < token3` by address** (strict ascending). That order **is** the canonical binding order for LP / views / array indices. Revert if unsorted or duplicates | **LOCKED** |
| D8 | Pool set | Factory **must create all six** pair pools on successful `deploy` (see §5.5). Permissionless `ensurePairPools(hook)` may complete/repair any missing doors. Manual external `initialize` of a valid pair remains allowed (hook `beforeInitialize` still gates). All doors: `hooks = hook instance` | **LOCKED** |
| D9 | Pool fee (V4 key) | **`fee = lpFeePips`** (same `uint24` as hook LP fee). Hook StableSwap math remains the pricing authority; V4 CL fee is not used for inventory pricing | **LOCKED** |
| D10 | Native CL | **Forbidden** — `beforeAddLiquidity` and `beforeRemoveLiquidity` **revert** | **LOCKED** |
| D11 | Donate | **Forbidden** — `beforeDonate` **reverts** | **LOCKED** |
| D12 | Package shape | **Hook:** Repo + Target + Common + Math + thin wire. **Deploy libs:** FactoryService (mine/salt). **On-chain factory:** `UniswapV4QuadStableSwapHookFactory` (+ interface). No Facet/DFPkg for hook or factory in v1 | **LOCKED** |
| D13 | Hook inheritance | **No** inheritance of Crane/OZ `BaseHook`, `BaseTokenWrapperHook`, `DeltaResolver` — full **pattern-copy** of permissions + settle | **LOCKED** |
| D14 | LP ERC-20 | **Same mined hook contract** (IHooks + ERC-20) | **LOCKED** |
| D15 | Amplification \(A\) | Deploy-time **immutable** `baseAmp` (unscaled). Internal math uses \(A \cdot\) `AMP_PRECISION` with **`AMP_PRECISION = 100`**. Bounds: `0 < baseAmp < MAX_AMP` with **`MAX_AMP = 1_000_000`**. Product guidance: **prefer \(A \ge 10\)** (see §6). | **LOCKED** |
| D16 | Amp ramp | **None in v1** — no `startAmpRamp` / `stopAmpRamp`; \(A\) never mutates after deploy | **LOCKED** |
| D17 | Decimal / rate law | Normalize math to **1e18 stable units**. Base scale per token: `10^(36 - decimals)`. Optional per-token rate: **Balancer `IRateProvider` address only** (or `address(0)`). When non-zero, always call **`getRate()`** → `uint256` @ 1e18. `effectiveRate = baseScale * getRate() / 1e18`; if provider is zero, `effectiveRate = baseScale` (implicit rate `1e18`). **Public APIs do not take a selector.** **No adapter contracts in package DoD** — non-`getRate` feeds must be wrapped **off-package**. Fail-closed on bad reads (D74). | **LOCKED** |
| D18 | Reserves source of truth | **Repo `reserves[i]`** — do **not** use raw `balanceOf(hook)` as sole pricing input (donations ignored — D36). Settlement: pattern-copy peer hooks (take input / pay output) | **LOCKED** |
| D19 | Witness tokens | For pair \((in,out)\), the **other two** indices always enter invariant / target-reserve solves | **LOCKED** |
| D20 | LP swap fee | **Deploy-time immutable** `uint24 lpFeePips`, denominator **`FEE_DENOMINATOR = 1_000_000`**. Require **`0 < lpFeePips < FEE_DENOMINATOR`**. Fees realized on the **output** side: exact-in deducts fee from raw curve out; exact-out grosses up requested out before solving. | **LOCKED** |
| D20a | Exact-out fee gross-up | `grossOut = ceil(amountOut * FEE_DENOMINATOR / (FEE_DENOMINATOR - lpFeePips))`; solve curve for `grossOut`; round input **up** in favor of pool; **`amountIn == 0` reverts** | **LOCKED** |
| D21 | Fee destination | **Reserves only** — fee residual stays in the book for LPs. **No** hook/protocol skim buckets, collectors, or withdraw functions in v1 | **LOCKED** |
| D22 | Deposit API | `addLiquidity(uint256[4] amounts, uint256[4] minAmounts, address to, uint256 sharesMin)` — pull only used amounts; require shares ≥ sharesMin and used ≥ mins | **LOCKED** |
| D22a | Zap-in API | **In v1 DoD.** Algorithm **A — target-ratio sequential** (§4.8). Accepts **any non-empty subset** of four legs (zeros allowed). Rebalance via internal StableSwap exact-in then proportional add. **Public slippage: `sharesMin` only** (D73) — no caller-supplied per-internal-swap min array. Internal swaps still apply the same LP fee math as public swaps; execution must match `previewZapIn` | **LOCKED** |
| D23 | First mint | **All four amounts > 0**; `shares = geometricMean(rateScaledAmounts) - MINIMUM_LIQUIDITY`; require shares > 0; lock MINIMUM_LIQUIDITY to dead; post-state invariant must converge. **Zap-in must not** be used for first mint (not zap-eligible until live) | **LOCKED** |
| D24 | Subsequent mint | Classic proportional: `shares = min_i(amounts[i] * supply / reserves[i])`; `actual[i] = ceil(shares * reserves[i] / supply)`; require actual ≤ amounts | **LOCKED** |
| D25 | Withdraw | `removeLiquidity(shares, to, minAmounts[4])` — pro-rata four tokens; burn; require each amount ≥ min | **LOCKED** |
| D26 | First-mint shares math | **4-value geometric mean:** \(\sqrt{\sqrt{a\cdot b}\cdot\sqrt{c\cdot d}}\) on rate-scaled amounts (pairwise to reduce overflow) | **LOCKED** |
| D27 | Preview fidelity | **preview == execution** on swap, LP, and zap paths (fee-inclusive); ±1 wei only where denorm / ceil forces it (document) | **LOCKED** |
| D28 | Public previews | `previewAddLiquidity`, `previewRemoveLiquidity`, `previewZapIn`, `previewSwapExactIn`, `previewSwapExactOut`, reserve/amp/fee/token views | **LOCKED** |
| D29 | Zero amounts | **Revert** on zero amountIn / amountOut / zero shares | **LOCKED** |
| D30 | Reentrancy | Non-reentrant on LP + zap surfaces; accounting updates **before** external transfers; swap path safe under V4 unlock | **LOCKED** |
| D31 | Pool init | **Factory primary path** creates all six pairs (§5.5). Hook `beforeInitialize` validates currencies ⊂ bound set, distinct, **`fee == lpFeePips`**, **`tickSpacing == TICK_SPACING` (1)**, `hooks == this`. External callers may still init a valid missing pair | **LOCKED** |
| D32 | Deploy | CREATE3 + flag mine via **existing** `create3Factory`; FactoryService owns salt/mine formula; **on-chain factory** is the permissionless public entrypoint (D51+). **Not** vault registry / manager `deployPkg` | **LOCKED** |
| D33 | Salt namespace default | **`"uv4-quad-stable-swap-hook-"`** | **LOCKED** |
| D34 | Salt material | `namespace, poolManager, token0..token3, lpFeePips, baseAmp, rateProvider fingerprint (hash of four addresses), mineNonce` via encodePacked hash (`BetterEfficientHashLib` peer) | **LOCKED** |
| D35 | Idempotent deploy | Same binding + namespace ⇒ same address; occupied expected hook returned; wrong code reverts | **LOCKED** |
| D36 | Donations | Stray ERC-20 transfers **do not** update Repo reserves; ignore for pricing in v1 | **LOCKED** |
| D37 | Math library | Pure `UniswapV4QuadStableSwapHookMath` — invariant, target reserve, scale/descale, geometric mean, fee + zap sizing helpers | **LOCKED** |
| D38 | Solver | Newton-Raphson; max **255** iterations; convergence when \(\lvert\Delta\rvert \le 1\); on failure **revert** | **LOCKED** |
| D39 | Post-state priceability | After **swap**, **addLiquidity**, and **zapIn**, re-run invariant; if non-convergent, **revert**. **removeLiquidity exempt** | **LOCKED** |
| D40 | Settle order | Pattern-copy peer hooks: take input; sync+transfer+settle output; **BeforeSwapDelta** matches taken/paid | **LOCKED** |
| D41 | Delta convention | Tests are law — all directed pairs exact-in/out green with real router / quoter | **LOCKED** |
| D42 | Tests | Production-first; real V4 PoolManager; mixed-decimal hermetic + forks; no mock hook SUT | **LOCKED** |
| D43 | Fork priority | **Base** and **Robinhood Chain** (equal DoD priority after hermetic). Any four ERC-20s; mintable test tokens OK (D71) | **LOCKED** |
| D44 | License / style | BUSL-1.1 (or package peer); NatSpec + Crane code-style | **LOCKED** |
| D45 | LP name/symbol | **Auto** from four token `symbol()`: e.g. `QS-{s0}-{s1}-{s2}-{s3}` (cap length if needed). Fallback: short address fragments. Cached in Repo at ctor | **LOCKED** |
| D46 | Access control | **Fully permissionless** — no owner, no pause, no fee setter, no amp admin | **LOCKED** |
| D47 | MINIMUM_LIQUIDITY | **1000**; mint permanently to **`address(0)`** | **LOCKED** |
| D48 | Tick spacing | Package constant **`TICK_SPACING = 1`**. Factory always uses it. `beforeInitialize` **must enforce** `tickSpacing == 1`. Product pricing ignores CL ticks | **LOCKED** |
| D49 | Unsupported tokens | Rebasing **forbidden**; fee-on-transfer **forbidden**; decimals outside [6,18] **forbidden**; native ETH **forbidden** | **LOCKED** |
| D50 | Impl plan follow-on | `UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` | **LOCKED** |
| D51 | On-chain factory product | **`UniswapV4QuadStableSwapHookFactory`** — dedicated on-chain contract under `stable/quad/` that exposes **permissionless** deploy + pool creation (normative API §5.5) | **LOCKED** |
| D52 | Factory permission model | **Anyone** may call `deploy` / `ensurePairPools`. No per-caller allowlist. Factory itself has **no pause** and **no owner-gated deploy** in v1. (Bootstrap: factory must be authorized to call `create3Factory.create3*` — typically **operator** on the ecosystem CREATE3 factory — configured at factory deploy time; that bootstrap is **ops**, not per-hook ACL) | **LOCKED** |
| D53 | Factory → CREATE3 path | Factory **must not** invent a second CREATE3 system. Hook bytecode is deployed with **`HookMinerCreate3.computeAddress(deployer = create3Factory)`** + `create3Factory.create3WithArgs(...)` using FactoryService salt material (D33–D35). Factory contract is the **caller**; miner `deployer` remains **`address(create3Factory)`** | **LOCKED** |
| D54 | Factory deploy atomicity | Single public `deploy(...)` **succeeds only if** (1) hook is deployed or idempotently returned **and** (2) **all six** pair pools are initialized (or already initialized). If any required `initialize` fails for a *new* pool, the whole tx reverts (no “hook without doors”) | **LOCKED** |
| D55 | Six pair combination set | Normative set is **all unordered pairs** of the four bound tokens, each as a V4 pool with **address-sorted** currencies. Binding-index pairs: \((0,1),(0,2),(0,3),(1,2),(1,3),(2,3)\). For each pair of addresses \((a,b)\): `currency0 = min(a,b)`, `currency1 = max(a,b)` | **LOCKED** |
| D56 | Normative PoolKey | For each pair: `PoolKey({ currency0, currency1, fee: lpFeePips, tickSpacing: TICK_SPACING (1), hooks: IHooks(hook) })` | **LOCKED** |
| D57 | Init sqrt price | Factory initializes every pair with **`sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0)`** (1:1 mid in V4 tick space). Product pricing ignores CL; this is only to satisfy `PoolManager.initialize` | **LOCKED** |
| D58 | Pool create entrypoint | Factory calls **`IPoolManager.initialize(poolKey, sqrtPriceX96)`** for each of the six keys. **Idempotent:** if pool already initialized, skip (do not revert the whole deploy solely because a door already exists) | **LOCKED** |
| D59 | `ensurePairPools` | Permissionless `ensurePairPools(hook)` **only if** `isDeployedByFactory[hook]` (or equivalent factory-attested set). Initializes any of the six doors not yet live. **Reject** hooks not deployed by this factory even if self-describing views match | **LOCKED** |
| D60 | Factory registry (minimal) | Factory **must** track factory-deployed hooks (`isDeployedByFactory`). **MAY** emit events and optional binding hash → hook. **Not** a full vault registry. Discovery: events + deterministic CREATE3 address from binding | **LOCKED** |
| D61 | Hook ctor vs pools | Hook **constructor does not** initialize pools (gas + reentrancy cleanliness). **Factory** owns pool creation after hook code is live | **LOCKED** |
| D62 | Salt mining paths (both DoD) | **(A)** `deploy(...)` — fully on-chain mine loop (bounded by `MAX_LOOP`, revert if exhausted). **(B)** `deployWithMineNonce(...)` (or equivalent) — caller supplies a pre-mined `mineNonce` that must yield flag-correct address for the binding salt; factory verifies flags + deploys (no search). **Both first-class in v1 DoD** | **LOCKED** |
| D63 | Factory deploy args | `token0..token3` (strict ascending), `lpFeePips`, `baseAmp`, rate providers, optional `saltNamespace`. **`poolManager` is NOT a per-deploy arg** — factory immutable (D67) | **LOCKED** |
| D64 | Multi-instance | Distinct bindings or distinct non-empty `saltNamespace` ⇒ distinct hook addresses (D35). Same binding + namespace ⇒ idempotent same hook + ensure six pools | **LOCKED** |
| D65 | Factory self-deploy | Factory contract itself is deployed once per chain via CREATE3 / script (ops). Spec of factory bootstrap is in §5.5.4; not user-facing per pool | **LOCKED** |
| D66 | No liquidity in factory | Factory **never** pulls user tokens or mints LP. First liquidity remains hook `addLiquidity` | **LOCKED** |
| D67 | PoolManager (canonical, immutable) | **Production:** factory ctor sets **`IPoolManager` immutable** to the **canonical Uniswap V4 PoolManager already deployed on that chain** (the official V4 singleton for the network). **One factory instance per chain** (same PM for every hook it deploys). Hook ctor binds **that same** PM as immutable. **Not** a per-`deploy` argument. **Forbidden:** inventing a second production PoolManager; reading PM from Vault Fee Oracle `feeTo()` (`IFeeCollectorProxy` — wrong type/role; §5.5.9). **Tests only:** hermetic/local may use a test-deployed PM that implements the same interface. Changing production PM is not a product path (new official V4 deployment would imply new factory ops, not a setter) | **LOCKED** |
| D68 | Factory events | **`HookDeployed` only when new hook bytecode is created.** Idempotent return of existing hook: do **not** re-emit `HookDeployed`. **`PairPoolsEnsured`** may emit on ensure / on deploy pool phase (including when some doors already live) | **LOCKED** |
| D69 | Rate provider type | **Balancer `IRateProvider` only** on public surfaces (`getRate() → uint256` @ 1e18). Package does **not** ship adapter contracts; callers pass existing providers (incl. IndexedEx SE rate-provider packages) or `address(0)` for pure decimal scale. Aligns with D17 | **LOCKED** |
| D70 | Inert book + open doors | After factory deploy, all six pools may exist while reserves are empty. **`addLiquidity` (first mint) does not require prior swaps.** Swaps require **swap-live** gates (D72) | **LOCKED** |
| D71 | Robinhood / Base fork tokens | Any four ERC-20s. Tests **may deploy mintable test tokens** on fork to satisfy the matrix. Fork purpose: integration with **production** PoolManager / CREATE3 / factory path — not a fixed named four-stable list | **LOCKED** |
| D72 | Directed swap gate | Swap is allowed iff **`reserves[in] > 0`**, **`reserves[out] > 0`**, and invariant solve + post-state priceability succeed. **Witness legs may be zero.** (Stronger “all four > 0” is **not** required for swaps; it **is** required for zap-eligible.) | **LOCKED** |
| D73 | Zap public slippage | **`sharesMin` only** on `zapIn`. No explicit per-internal-swap min-outs in the public ABI. Clients quote via `previewZapIn`; in-tx path is deterministic and must match preview within documented ± wei. | **LOCKED** |
| D74 | Rate oracle fail-closed | **Whenever** a path reads a leg rate (swaps, first-mint / rate-scaled math, zap target-ratio, `effectiveRate` / rate-using previews, etc.): if provider ≠ 0, **`staticcall getRate()`** must succeed with **exactly 32 bytes** and **`rate > 0`**. Otherwise **revert** (previews and execution match). No last-good cache; no silent fallback to `1e18` when a provider is configured. Pure raw pro-rata remove that does **not** call rates is unaffected until a path actually reads them. | **LOCKED** |

### 3.1 Implementor edges — **LOCKED** (v0.5)

| ID | Topic | Locked value |
|----|--------|--------------|
| Q1 | Fee encoding | **`uint24 lpFeePips` / `FEE_DENOMINATOR = 1_000_000`**. Deploy-time immutable. **Must be non-zero**. Also stored as **PoolKey.fee**. |
| Q2 | First-mint shares | **4-way geometric mean of rate-scaled amounts − MINIMUM_LIQUIDITY**. Forbidden: raw multi-decimal sum. |
| Q3 | \(n\) fixed | Compile-time / product constant **4**. |
| Q4 | Exact-out | Gross-up output by LP fee; round in favor of pool; **zero input reverts**. |
| Q5 | LP name/symbol | **Auto** `QS-{s0}-{s1}-{s2}-{s3}` with fallbacks. |
| Q6 | Pool set | Factory deploys **all six** doors; swaps work on any initialized pair. |
| Q7 | Live swap gate | **Pair legs only** (D72): `reserves[in] > 0` and `reserves[out] > 0`; invariant convergent. Witnesses may be zero. |
| Q8 | LP slippage | `sharesMin` + per-leg `minAmounts` on add; per-leg mins on remove; zap: **`sharesMin` only** (D73). |
| Q9 | Brick safety | Swap/add/zap require post-state priceable; remove always allowed. |
| Q10 | No BaseHook | Pattern-copy only. |
| Q11 | Amp | **Immutable** deploy-time only. |
| Q12 | Fee skim | **None** — residual in reserves. |
| Q13 | Admin | **Permissionless.** |
| Q14 | Zap-in | **v1 DoD.** |
| Q15 | Forks | **Base + Robinhood Chain** mainnets. |
| Q16 | Native ETH | **Forbidden.** |
| Q17 | Tick spacing | **`1`**. |
| Q18 | MINIMUM_LIQUIDITY sink | **`address(0)`**. |
| Q19 | Zap algorithm | **A — target-ratio sequential.** |
| Q20 | Zap inputs | **Any non-empty subset** of 4 legs. |
| Q21 | Factory | **On-chain permissionless** `UniswapV4QuadStableSwapHookFactory`. |
| Q22 | Pools on deploy | **All six** pairs, address-sorted, fee=`lpFeePips`, tickSpacing=1, sqrtPrice=tick0. |
| Q23 | CREATE3 | Factory calls ecosystem `create3Factory`; miner deployer = create3Factory. |
| Q24 | Token sort | **Strict ascending** `token0 < token1 < token2 < token3`. |
| Q25 | Mine APIs | **Both** on-chain mine + `deployWithMineNonce`. |
| Q26 | ensure scope | **Factory-deployed hooks only.** |
| Q27 | Events | **`HookDeployed` only on new code.** |
| Q28 | Rates | **`IRateProvider` addresses only**; always `getRate()`; no package adapters; no public selector (D17/D69). |
| Q29 | PoolManager | **Factory immutable = canonical Uni V4 PM for the chain**; not `feeTo()`; not per-deploy. |
| Q30 | First mint | **Allowed with open doors, no prior swaps.** |
| Q31 | Zap mins | **`sharesMin` only** — no public per-swap min array (D73). |
| Q32 | Rate failures | **Fail closed** on bad/zero/empty returndata (D74). |
| Q33 | Zero witness | **Allowed** for directed swaps; zap still needs all four reserves > 0. |

### 3.2 Residual open decisions

| # | Question | Notes |
|---|----------|-------|
| — | *(none blocking plan)* | Zap surplus→deficit ordering, ε, and multi-deficit split weights remain **implementation-plan detail** under §4.8 (must be deterministic and match `previewZapIn`). `MAX_LOOP` concrete value is plan/constants (see §10). |

---

## 4. Architecture

### 4.1 Stack

```text
┌──────────────────────────────────────────────────────────────────┐
│ Anyone (permissionless)                                          │
│   • factory.deploy(...)  →  hook + 6 pair pools                  │
│   • factory.ensurePairPools(hook)                                │
└───────────────────────────────┬──────────────────────────────────┘
                                │ CREATE3 (ecosystem) + initialize×6
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│ User / Router                                                    │
│   • addLiquidity / removeLiquidity / zapIn on Hook               │
│   • swapExact* via V4 on any of the 6 pair doors                 │
└───────────────┬─────────────────────────────┬────────────────────┘
                │                             │
                ▼                             ▼
┌───────────────────────────────┐   ┌──────────────────────────────────┐
│ UniswapV4QuadStableSwapHook │   │ Uniswap V4 PoolManager           │
│  reserves[4] + A + rates      │◄──│  6 pair pools (all combinations) │
│  ERC-20 LP                    │   │  fee=lpFeePips, tickSpacing=1    │
│  Math: StableSwap n=4         │   │  hooks = same Quad instance      │
└───────────────────────────────┘   └──────────────────────────────────┘
```

### 4.2 Virtual multi-pool (“six doors, one room”)

Uniswap V4 pools are **strictly 2-currency**. Quad multi-asset state lives **only** on the hook:

```text
Pool t0/t1  ──┐
Pool t0/t2  ──┤
Pool t0/t3  ──┼──► same UniswapV4QuadStableSwapHook (shared reserves + A + D)
Pool t1/t2  ──┤
Pool t1/t3  ──┤
Pool t2/t3  ──┘
```

A `t0→t1` swap still uses **t2 and t3 reserves as witnesses** in the StableSwap solve, so idle third/fourth-asset capital supports every pair.

**Factory obligation:** on successful permissionless deploy, **all six** doors above exist as initialized V4 pools (currency order address-sorted — §5.5.2).

### 4.3 Rate scaling (normative)

```text
RATE_PRECISION = 1e18
baseScale[i]   = 10^(36 - decimals(token_i))     // 6d → 1e30; 18d → 1e18
// provider[i] is IRateProvider or address(0) — no selector on public surface (D17)
oracleRate[i]  = provider == 0
                   ? 1e18
                   : staticcall IRateProvider(provider).getRate()  // must succeed
effectiveRate  = baseScale * oracleRate / RATE_PRECISION

scaleTo(amount, rate)   = floor(amount * rate / 1e18)
scaleToUp(amount, rate) = ceil(amount * rate / 1e18)
descale(scaled, rate)   = floor(scaled * 1e18 / rate)
descaleUp(scaled, rate) = ceil(scaled * 1e18 / rate)
```

**Oracle rules (fail-closed — D74):**

- If `provider != 0`: `staticcall getRate()` must succeed; return length must be **exactly 32 bytes**; decoded **`rate > 0`**. Any failure → **revert** on the user op **and** on matching previews.
- **No** last-good-rate cache; **no** silent fallback to `1e18` when a provider is configured.
- Scaling of `getRate()` must be **1e18**. Wrong scale silently misprices — deploy-time config hygiene + tests; not a runtime auto-correct.
- Near-zero (but non-zero) rates reintroduce dust round-trip risk at low \(A\); do not configure such oracles in production (ops guidance).

### 4.4 StableSwap math (normative sketch)

With \(n=4\), \(x_i\) rate-scaled reserves, amplification `amp` already including `AMP_PRECISION` (i.e. `getCurrentAmp()` returns scaled value):

**Invariant \(D\):** Newton-Raphson on

\[
A n^n \sum x_i + D = A D n^n + \frac{D^{n+1}}{n^n \prod x_i}
\]

using the iterative form peer multi-stable implementations use (255 iters, \(\Delta \le 1\)).

**Target reserve \(y\)** given new source reserve \(x'_s\), fixed other legs, preserved \(D\): Newton-Raphson solve for the missing leg.

**Exact-in:**

```text
x_in'  = x_in + scaleTo(amountIn, rateIn)
y_out' = getY(outIndex, x_in' at inIndex, fixed other legs, amp, D)  // Newton target reserve
rawOut = descale(x_out - y_out', rateOut)
grossLpFee = ceil(rawOut * lpFeePips / FEE_DENOMINATOR)   // D20/D21 — residual stays in book
amountOut = rawOut - grossLpFee
// update Repo: reserves[in] += amountIn; reserves[out] -= amountOut
// fee residual is the un-sent portion of rawOut still in reserves[out]
// post-state: getInvariant must converge (D39)
```

**Exact-out:**

```text
grossOut = ceil(amountOut * FEE_DENOMINATOR / (FEE_DENOMINATOR - lpFeePips))
// fee residual = grossOut - amountOut remains in reserves[out] (D21 — no skim buckets)
y_out' = x_out - scaleToUp(grossOut, rateOut)
x_in'  = getY(inIndex, y_out' at outIndex, fixed other legs, amp, D)
amountIn = descaleUp(x_in' - x_in, rateIn)
require amountIn > 0
```

### 4.5 Fee law (v1 — locked)

```text
FEE_DENOMINATOR = 1_000_000
lpFeePips       = immutable uint24   // e.g. 500 → 0.05%; MUST be > 0
PoolKey.fee     = lpFeePips          // D9 — encoded for router/UI; not a second fee stack

Exact-in:
  rawOut from curve on full amountIn
  grossLpFee = ceil(rawOut * lpFeePips / FEE_DENOMINATOR)
  amountOut = rawOut - grossLpFee
  // user receives amountOut; fee residual stays in reserves (D21)

Exact-out:
  grossOut = ceil(amountOut * FEE_DENOMINATOR / (FEE_DENOMINATOR - lpFeePips))
  // fee residual = grossOut - amountOut stays in reserves
  // curve depth uses grossOut so fee modes are symmetric with exact-in
```

**Mandatory safety:** `lpFeePips == 0` **reverts at deploy**. No hook/protocol skim path may zero the LP residual (none exist in v1).

### 4.6 Liquidity (proportional 4-asset)

```text
First mint (totalSupply == 0):
  require all amounts[i] > 0                 // D23 LOCKED
  scaled[i] = scaleTo(amounts[i], rate[i])
  sharesGross = geometricMean4(scaled)
  require sharesGross > MINIMUM_LIQUIDITY
  shares = sharesGross - MINIMUM_LIQUIDITY
  require shares >= sharesMin
  actual[i] = amounts[i]
  mint MINIMUM_LIQUIDITY to address(0) (D47)
  pull; set reserves; require invariant converges
  mint shares to `to`

Later mint:
  shares = min_i(amounts[i] * supply / reserves[i])
  require shares > 0 && shares >= sharesMin
  actual[i] = ceil(shares * reserves[i] / supply)
  require actual[i] <= amounts[i] && actual[i] >= minAmounts[i]
  pull actual; update reserves; require invariant converges
  mint shares

Remove:
  amount[i] = shares * reserves[i] / supply
  require amount[i] >= minAmounts[i]
  burn; decrease reserves; transfer
  // NO invariant converge require (exit always possible)
```

### 4.7 Amplification (v1 — immutable)

```text
scaledAmp = baseAmp * AMP_PRECISION   // stored once at deploy
getCurrentAmp() == scaledAmp always
// No ramp fields, no ramp events, no admin
```

### 4.8 Zap-in (v1 DoD — **LOCKED algorithm A**)

**Goal:** let a user deposit **without perfect 4-way ratio** and still receive LP, by rebalancing donated legs through the same StableSwap curve (paying the normal LP fee on each internal swap), then minting via the proportional add path.

**Eligibility (locked):**

- Book must be **zap-eligible**: `totalSupply > MINIMUM_LIQUIDITY` **and** all four `reserves[i] > 0`.
- First mint **must** use `addLiquidity` with all four legs — zap **reverts** if not zap-eligible.

**Inputs (locked — D73):**

```text
zapIn(
  uint256[4] amounts,     // max pull per leg; zeros allowed; require ≥1 positive
  address to,
  uint256 sharesMin       // sole public LP slippage guard
) → (shares, actualUsed[4])
```

Accepts **any non-empty subset** of the four legs (1–4 positive amounts). Pull only what the path consumes; refund unused input. **No** caller-supplied per-internal-swap min-outs array.

**Normative outcomes (locked):**

1. Internal swaps use **identical** exact-in StableSwap + fee math as public swaps (previewable).  
2. Final mint uses the **same** proportional `addLiquidity` math as D24.  
3. **`previewZapIn` == execution** within documented ± few wei.  
4. Post-zap invariant must converge (D39).  
5. User accepts price impact; no “no-IL” guarantee.  
6. Non-reentrant; accounting before external token movements.  
7. Residual free inventory on the hook after success: **zero** or documented ≤ few wei (prefer refund).  
8. Public slippage guard is **`sharesMin` only**; clients that need tighter control must size inputs via `previewZapIn` off-chain / same-tx quote.

**Algorithm A — target-ratio sequential (normative sketch):**

```text
1. Pull amounts[i] (or max caps) into working balances W[i] (rate-scale for math).
2. V = Σ rateScale(W[i])                         // total value in 1e18 stable units
3. Let R[i] = rateScale(reserves[i]); S = Σ R[i]
4. Target contribution T[i] = V * R[i] / S         // proportional to current book
5. For each i with rateScale(W[i]) > T[i] + ε:
     surplus = W[i] - descale(T[i])
     distribute surplus across underweight legs j (W[j] < T[j]) via
       sequential exact-in StableSwap(i → j) using same fee math as public swaps
     until W matches T within rounding, or no further progress
6. actual[i] = min(W[i], amounts available after swaps) sized for common share capacity
7. shares = proportional mint from actual (D24)
8. require shares >= sharesMin; require invariant converges
```

Exact ordering of surplus→deficit swaps, ε, and multi-deficit split weights are **implementation-plan detail** but must be deterministic and match `previewZapIn`.

**Balanced input:** if deposited legs are already at target ratio within rounding, skip internal swaps and mint proportionally (still subject to `sharesMin`).

**Public slippage:** **`sharesMin` only** (D73). Internal path is fully determined by `amounts` + book state; no separate min-out parameters.

**Forbidden:**

- Using PoolManager CL / external routers for rebalance (must stay in-hook StableSwap).  
- First-mint via zap.  
- Algorithms B/C as product law (superseded by A).  
- Public per-internal-swap min-out arrays (superseded by D73).

---

## 5. Package surface (normative file plan)

```text
contracts/hooks/uniswap/v4/stable/quad/
  UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md                        # this file
  UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on

  interfaces/
    IUniswapV4QuadStableSwapHook.sol                           # views + previews + LP surface
    IUniswapV4QuadStableSwapHookFactory.sol                    # permissionless deploy + ensure pools

  UniswapV4QuadStableSwapHookMath.sol                          # pure StableSwap n=4 + WAD rates + shares
  UniswapV4QuadStableSwapHookRepo.sol                          # diamond-style storage slot layout
  UniswapV4QuadStableSwapHookCommon.sol                        # reserve helpers, rate cache, guards
  UniswapV4QuadStableSwapHookTarget.sol                        # IHooks + LP execute (pattern-copy settle)
  UniswapV4QuadStableSwapHook.sol                              # single CREATE3-mined wire + ERC-20

  UniswapV4QuadStableSwapHook_FactoryService.sol               # pure/internal mine + salt + isExpectedHook
  UniswapV4QuadStableSwapHookFactory.sol                       # on-chain permissionless factory (D51)

  # FORBIDDEN:
  #   *Facet.sol, *DFPkg.sol for hook or factory (v1)
  #   Solidity inheritance of BaseHook / BaseTokenWrapperHook / DeltaResolver
  #   Second CREATE3 infrastructure (must use ecosystem create3Factory for hooks)
```

### 5.1 Diamond-style storage (Repo) — normative intent

Follow Crane **Repo** pattern: single namespaced storage slot (e.g. `keccak256("…UniswapV4QuadStableSwapHook.storage")` layout struct), **not** free-floating storage variables scattered on the wire contract without a Repo library.

**Repo layout sketch (informative):**

```solidity
struct Layout {
    // set-once / immutable peers may live as Solidity immutables on wire instead
    uint256[4] reserves;           // raw token units
    uint256[4] baseScales;         // 10^(36 - decimals)
    // rateProviders[4] as immutables preferred (IRateProvider or address(0); no selectors)
    // no fee accumulators (D21 reserves-only)
    // no amp ramp fields (D16 immutable)
    string name;
    string symbol;
    // ERC-20 balances/allowances may use Solady/Crane ERC20 storage — keep coherent
}
```

**Immutables on wire (preferred for gas/clarity):** `poolManager`, `token0..token3`, `lpFeePips`, `baseAmp`, `rateProviders[4]`, `decimals`/`baseScale` if fixed at ctor.

### 5.2 Interface sketch (informative)

```solidity
interface IUniswapV4QuadStableSwapHook {
    function poolManager() external view returns (IPoolManager);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function token2() external view returns (address);
    function token3() external view returns (address);
    function tokens() external view returns (address[4] memory);

    function lpFeePips() external view returns (uint24);
    function baseAmp() external view returns (uint256);
    function getCurrentAmp() external view returns (uint256); // == baseAmp*AMP_PRECISION if no ramp

    function reserveOf(address token) external view returns (uint256);
    function reserves() external view returns (uint256[4] memory);
    function effectiveRate(uint256 index) external view returns (uint256);

    function previewAddLiquidity(uint256[4] calldata amounts)
        external view returns (uint256 shares, uint256[4] memory actualAmounts);
    function previewRemoveLiquidity(uint256 shares)
        external view returns (uint256[4] memory amounts);
    /// @notice Preview zap. Fail-closed on rate reads (D74). Deterministic match to zapIn.
    function previewZapIn(uint256[4] calldata amounts)
        external view returns (uint256 shares, uint256[4] memory amountsUsed);

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external view returns (uint256 amountOut);
    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external view returns (uint256 amountIn);

    function addLiquidity(
        uint256[4] calldata amounts,
        uint256[4] calldata minAmounts,
        address to,
        uint256 sharesMin
    ) external returns (uint256 shares, uint256[4] memory actualAmounts);

    /// @notice Zap-in. Public slippage = sharesMin only (D73).
    function zapIn(
        uint256[4] calldata amounts,
        address to,
        uint256 sharesMin
    ) external returns (uint256 shares, uint256[4] memory amountsUsed);

    function removeLiquidity(
        uint256 shares,
        address to,
        uint256[4] calldata minAmounts
    ) external returns (uint256[4] memory amounts);
}
```

LP ERC-20 surface (`name`, `symbol`, `totalSupply`, `balanceOf`, `transfer`, …) lives on the same contract. Prefer Crane token helpers; do not re-vendor ad hoc ERC20 stacks.

### 5.3 Deploy API (FactoryService library)

Internal/pure helpers used by the **on-chain factory** (and tests). Not the permissionless UX by themselves if `create3Factory` is owner/operator-gated.

```solidity
// Default namespace: "uv4-quad-stable-swap-hook-"
// Rate oracles: Balancer IRateProvider only (getRate @ 1e18). address(0) = decimal scale only.
// No public selector field (D17/D69). Fingerprint = hash of four provider addresses.

function requiredFlags() internal pure returns (uint160);

function hookSalt(
    string memory namespace,
    address poolManager,
    address token0,
    address token1,
    address token2,
    address token3,
    uint24 lpFeePips,
    uint256 baseAmp,
    bytes32 rateProviderFingerprint, // hash of address[4] providers
    uint256 mineNonce
) internal pure returns (bytes32);

function isExpectedHook(address predicted, /* binding */) internal view returns (bool);

// Used by factory; create3Factory must authorize the caller (factory as operator).
function deployHook(
    ICreate3FactoryProxy create3Factory,
    IPoolManager poolManager,
    address token0,
    address token1,
    address token2,
    address token3,
    uint24 lpFeePips,
    uint256 baseAmp,
    address[4] memory rateProviders, // IRateProvider or address(0)
    string memory saltNamespace // empty → default
) internal returns (address hook);
```

**Ctor validation (hook):** non-zero token addresses; **`token0 < token1 < token2 < token3`**; no native ETH; decimals ∈ [6,18]; `0 < lpFeePips < 1_000_000`; `0 < baseAmp < MAX_AMP`; each rate provider is `address(0)` or a contract that will be called as `IRateProvider` (no on-chain bytecode probe required beyond non-EOA optional guidance — runtime fail-closed D74); `Hooks.validateHookPermissions(this, permissions)`; cache decimals + LP name/symbol.

**Mine loop:** same structure as `UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService` (binding-aware salt + `computeAddress` + empty deploy / expected return / collision revert / MAX_LOOP exhaust).

**`isExpectedHook`:** views match deploy args (pm, four tokens, fee, amp fingerprint, code present).

### 5.4 Hook permissions

| Flag | Enabled | Behavior |
|------|---------|----------|
| `beforeInitialize` | yes | Validate pair ⊂ bound four, distinct, **`fee == lpFeePips`**, **`tickSpacing == 1`**, hooks==this |
| `afterInitialize` | no | — |
| `beforeAddLiquidity` | yes | **Revert** (use hook LP surface) |
| `beforeRemoveLiquidity` | yes | **Revert** |
| `beforeSwap` | yes | StableSwap pricing |
| `beforeSwapReturnDelta` | yes | Custom amounts |
| `beforeDonate` | yes | **Revert** |
| all after* / after*ReturnDelta | no | — |

Address must encode these flags (CREATE3 mine). Include `BEFORE_DONATE` and both liquidity bans as required for §5.4.

### 5.5 On-chain permissionless factory (normative)

#### 5.5.1 Product purpose

Ship **`UniswapV4QuadStableSwapHookFactory`** so **any** account can:

1. Deploy a new quad hook instance for a chosen four-token binding + fee + amp + rate oracles.  
2. **Create all six** Uni V4 pair pools that serve as swap doors into that shared book.  
3. **Repair** missing doors via `ensurePairPools` without redeploying the hook.

The factory is the **default production entrypoint**. Scripts/tests may call FactoryService internals only when they already hold `create3Factory` operator rights.

#### 5.5.2 Pair combination set (complete)

Given binding tokens `T[0], T[1], T[2], T[3]` (ctor / factory arg order):

| # | Binding indices | Pool currencies (must address-sort) |
|---|-----------------|-------------------------------------|
| 1 | (0, 1) | `currency0 = min(T[0],T[1])`, `currency1 = max(T[0],T[1])` |
| 2 | (0, 2) | `min(T[0],T[2])`, `max(T[0],T[2])` |
| 3 | (0, 3) | `min(T[0],T[3])`, `max(T[0],T[3])` |
| 4 | (1, 2) | `min(T[1],T[2])`, `max(T[1],T[2])` |
| 5 | (1, 3) | `min(T[1],T[3])`, `max(T[1],T[3])` |
| 6 | (2, 3) | `min(T[2],T[3])`, `max(T[2],T[3])` |

**Count:** always \(\binom{4}{2} = 6\). No seventh pool. No pool that includes a token outside `T`.

**Normative `PoolKey` for each row:**

```solidity
PoolKey({
    currency0: Currency.wrap(c0),      // address-sorted
    currency1: Currency.wrap(c1),
    fee: lpFeePips,                    // D9 / D56 — same as hook immutable
    tickSpacing: int24(1),             // D48 / D56
    hooks: IHooks(hook)
})
```

**Init price (D57):**

```solidity
uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0); // 1:1 mid
poolManager.initialize(key, sqrtPriceX96);
```

#### 5.5.3 Public factory interface (informative → normative intent)

```solidity
interface IUniswapV4QuadStableSwapHookFactory {
    event HookDeployed(
        address indexed deployer,
        address indexed hook,
        address poolManager,
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp
    );
    event PairPoolsEnsured(address indexed hook, uint8 createdCount, uint8 alreadyLiveCount);

    function poolManager() external view returns (IPoolManager);
    function create3Factory() external view returns (ICreate3FactoryProxy);

    /// @notice Permissionless path A: on-chain mine + deploy + all six pools.
    function deploy(
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp,
        address[4] calldata rateProviders, // IRateProvider or address(0)
        string calldata saltNamespace // empty → default
    ) external returns (address hook, PoolKey[6] memory poolKeys);

    /// @notice Permissionless path B: caller-supplied mineNonce (must match flags); no on-chain search.
    function deployWithMineNonce(
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp,
        address[4] calldata rateProviders,
        string calldata saltNamespace,
        uint256 mineNonce
    ) external returns (address hook, PoolKey[6] memory poolKeys);

    /// @notice Permissionless: initialize missing doors — **factory-deployed hooks only** (D59).
    function ensurePairPools(address hook)
        external
        returns (PoolKey[6] memory poolKeys, uint8 createdCount);

    function pairPoolKeys(address hook) external view returns (PoolKey[6] memory);
    function isDeployedByFactory(address hook) external view returns (bool);
    function predictHookAddress(/* binding + namespace + mineNonce */) external view returns (address);
}
```

**Behavior notes:**

| Rule | Law |
|------|-----|
| Permissionless | No `onlyOwner` on `deploy` / `deployWithMineNonce` / `ensurePairPools` |
| Token order | Require `token0 < token1 < token2 < token3` (D7) |
| Idempotent deploy | Same binding + namespace → same hook; ensure six pools; return existing |
| Collision | Predicted address occupied by non-expected code → **revert** |
| Mine exhaust | Path A: no flag-matching salt within `MAX_LOOP` → **revert**. Path B: wrong nonce/flags → **revert** |
| ensure scope | **`isDeployedByFactory` only** (D59) |
| Pool already live | Skip; count as `alreadyLive` |
| No LP / no transfers | Factory never pulls ERC-20s |
| Events | **`HookDeployed` only when new bytecode created** (D68) |

#### 5.5.4 Factory bootstrap (ops, once per chain)

```text
1. Resolve CANONICAL_V4_POOL_MANAGER for the target chain
     (official Uniswap V4 PoolManager deployment address — not self-deployed in prod).
2. Deploy UniswapV4QuadStableSwapHookFactory via CREATE3 (script) with immutables:
     create3Factory  = ecosystem CREATE3 factory
     poolManager     = CANONICAL_V4_POOL_MANAGER   // D67 — fixed for factory life
3. Grant factory address operator (or owner) rights on create3Factory so
     factory.deploy → create3WithArgs succeeds for any end-user caller.
4. Publish factory address; end users never pass or choose PoolManager.
```

**Forbidden bootstrap patterns:** requiring each user to be `create3Factory` operator; deploying hooks with CREATE2 `new {salt}` that ignore ecosystem CREATE3 address formula; setting factory `poolManager` to fee collector / arbitrary non-V4 address; deploying a **production** second PoolManager for this product.

#### 5.5.5 Algorithm: `deploy` (normative sketch)

```text
1. Validate tokens, decimals, fee, amp, rate providers (same as hook ctor).
2. rateProviderFingerprint = hash of four IRateProvider addresses (incl. zeros).
3. hook = FactoryService.deployHook(create3Factory, pm, tokens…, fee, amp, rateProviders, namespace)
     // mine loop + create3WithArgs OR return existing expected hook
4. keys = compute six PoolKeys (D55–D56)
5. for each key in keys:
     if pool not initialized:
       poolManager.initialize(key, INIT_SQRT_PRICE_X96)   // D57–D58
6. mark isDeployedByFactory[hook] = true   // always on successful deploy path (new or idempotent)
7. emit HookDeployed only if new bytecode created (D68); emit PairPoolsEnsured as needed
8. return (hook, keys)
```

#### 5.5.6 Algorithm: `ensurePairPools` (normative sketch)

```text
1. require isDeployedByFactory[hook] == true   // D59 — factory-attested only
2. require hook has code and self-describing views match expected binding (isExpectedHook)
3. read token0..token3, lpFeePips from hook
4. for each of six keys: initialize if missing
5. return keys + createdCount
```

#### 5.5.7 Relationship to “external initialize”

- **Primary path:** factory `deploy` / `ensurePairPools`.  
- **Still valid:** a third party may call `poolManager.initialize` with a normative key; hook `beforeInitialize` accepts if gates pass.  
- **DoD for production UX:** factory path alone is sufficient to go from zero → hook + six doors without a custom script.

#### 5.5.8 Gas / UX expectations

- Path A (`deploy`) may be expensive (mine loop + 6 initializes). Acceptable for infrequent creation.  
- Path B (`deployWithMineNonce`) is the production gas optimization; clients mine off-chain then submit.  
- Frontends should call `predictHookAddress` + show six pairs before sending either path.

#### 5.5.9 PoolManager law (D67) — canonical chain PM, factory immutable

**Normative production law:**

```text
factory.poolManager  = immutable IPoolManager
                       ↳ must be the canonical Uniswap V4 PoolManager for that chain
hook.poolManager     = same address (set at hook deploy from factory)
deploy(...) args     = do NOT include poolManager
```

- All six `initialize` calls and all swaps use **that** singleton.  
- Users never supply or override PM.  
- **Hermetic tests** may deploy a local PM and pass it only into **factory construction** (still immutable after factory exists).

**Why not Vault Fee Oracle `feeTo()`:**

| | Vault Fee Oracle `feeTo()` | Uniswap V4 `PoolManager` |
|--|---------------------------|---------------------------|
| Type | `IFeeCollectorProxy` | `IPoolManager` (V4 singleton) |
| Role | Protocol fee **recipient** / collector | Settlement + pool registry for all V4 pools |
| Production source | IndexedEx fee oracle storage | **Official Uni V4 deployment on the chain** |

Wiring `poolManager = address(feeOracle.feeTo())` would point hooks at the **fee collector**, not V4 — invalid.

Fee oracle remains orthogonal to this package; v1 still has **no** hook/protocol fee skim to `feeTo` (D21).

#### 5.5.10 Balancer `IRateProvider` compatibility (D69 / D17 / D74)

**Normative for this package.** Crane/IndexedEx use Balancer V3:

```solidity
interface IRateProvider {
    function getRate() external view returns (uint256); // 1e18 scale
}
```

Hook rate path:

```text
if provider == 0:
  oracleRate = 1e18
else:
  staticcall IRateProvider(provider).getRate()
  require success && returndata.length == 32 && rate > 0   // D74 fail-closed
  oracleRate = rate
effectiveRate = baseScale * oracleRate / 1e18
```

Existing IndexedEx SE rate-provider packages implement `IRateProvider` and are valid inputs. **No new adapter DFPkg required** for v1 DoD. If a feed is not `getRate()`-shaped, the **caller** wraps it **off-package**. **Do not** reintroduce public `(oracle, selector)` config in v1.

---

## 6. Operational / safety requirements (product law)

These are **first-class requirements**, harvested from multi-stable StableSwap operational experience and restated as IndexedEx product rules:

1. **Token decimals ∈ [6, 18].** Outside range rejected at deploy.  
2. **Prefer \(A \ge 10\).** Lower \(A\) allows fee to round to zero on dust and opens round-trip leaks.  
3. **No rebasing tokens.** Reserves are internal; rebases desync books. Use wrapped non-rebasing forms + rate oracle.  
4. **No fee-on-transfer tokens.** Credits use transfer amounts, not balance deltas.  
5. **Rate oracles return `uint256` @ 1e18.** Wrong scale silently misprices. **Runtime fail-closed** on bad/zero reads when a provider is set (D74).  
6. **Non-zero LP fee at deploy.** Zero fee enables reserve drain / brick class.  
7. **Post swap/add/zap invariant check.** Prevent leaving non-priceable state.  
8. **Remove always available.** Even if book is “bricked” for swaps/adds.  
9. **Exact-out zero-input guard.** Required.  
10. **Accounting before external sends** on remove (and any native path if ever added).  
11. **Zap internal swaps:** same fee + math as public swaps; public guard = **`sharesMin` only**.  
12. **Amp immutable / no fee skim** — no admin ops surface in v1.  
13. **Directed swap gate:** pair legs only (D72); zap still requires all four reserves > 0.

---

## 7. Testing expectations (production-first)

Inherit IndexedEx / Crane testing law:

1. **No mock of SUT** (hook, Math, Repo, FactoryService under test).  
2. **Real V4 PoolManager** (Crane hermetic deploy or fork).  
3. **Gold TestBase** peer to dual/orbital/buffer: `TestBase_UniswapV4QuadStableSwapHook`.  
4. Allowed harnesses: mintable ERC20, optional hostile reentrancy ERC20 for adversarial suite.  
5. Cover at least:
   - **Factory path A + B:** on-chain mine and `deployWithMineNonce`; non-operator EOA; hook + **six** pools  
   - Sorted token inputs enforced; unsorted reverts  
   - Factory idempotent redeploy; `HookDeployed` only on new code  
   - `ensurePairPools` **factory-deployed only**; rejects foreign hooks  
   - `pairPoolKeys` matches D55–D56  
   - First mint with open doors / zero prior swaps  
   - Rate: `IRateProvider` or zero; no package adapters; **no selector API**  
   - Rate fail-closed: bad returndata / zero rate / reverting provider bricks ops + previews (D74)  
   - Deploy mine flags + hook idempotent return  
   - Inert book: no first mint → swaps revert (doors may exist)  
   - First mint geometric mean + MINIMUM_LIQUIDITY to `address(0)`  
   - Subsequent proportional add; slippage mins  
   - **Zap-in** single-leg and multi-leg; `sharesMin` only; not eligible pre-live; preview==exec  
   - Zap-eligible requires all four reserves > 0; directed swap allows zero witness (D72)  
   - Remove pro-rata; remove still works if intentionally imbalanced  
   - Exact-in / exact-out on **all six pairs**  
   - **preview == execution** (document ≤1 wei)  
   - Mixed decimals (6/6/18/18)  
   - Rate oracle leg  
   - Zero-fee deploy reverts  
   - Exact-out zero-input reverts  
   - Post-swap/add/zap non-convergent path reverts (constructed stress if feasible)  
   - CL add/remove/donate revert; `beforeInitialize` rejects wrong fee / tickSpacing / unbound token  
   - Donation does not change pricing reserves  
   - Reentrancy on remove/add/zap  
6. **Forks (DoD):** **Base** and **Robinhood Chain** — any four ERC-20s; **mintable test tokens allowed**; exercise production PM / CREATE3 / factory integration.  
7. Optional comparative: swap quotes vs a known StableSwap reference fixture for same reserves/A (off-package oracle), within documented tolerance.

---

## 8. Definition of Done

- [ ] Package files under `contracts/hooks/uniswap/v4/stable/quad/` match §5 (hook **and** factory).  
- [ ] CREATE3 FactoryService mine + deploy; on-chain **permissionless** factory; no BaseHook inherit; no Facet/DFPkg for hook/factory.  
- [ ] Factory `deploy` **and** `deployWithMineNonce`; each creates hook + **all six** pools (D54–D58, D62); `ensurePairPools` factory-only repair (D59).  
- [ ] Repo storage layout + Target settle pattern-copy.  
- [ ] StableSwap \(n=4\) math library pure; Newton-Raphson bounds documented.  
- [ ] LP ERC-20 on same contract; first/later mint + remove.  
- [ ] **Zap-in** + `previewZapIn` with algorithm **A** (any non-empty subset; **`sharesMin` only**) tested.  
- [ ] All six doors: **`fee == lpFeePips`**, **`tickSpacing = 1`**, address-sorted currencies; directed swaps with preview==exec; **swap-live = pair legs** (D72).  
- [ ] Safety gates: non-zero fee, zero-input exact-out, post-state priceability, token constraints, no native ETH, **rate fail-closed** (D74).  
- [ ] Hermetic TestBase green; **Base + Robinhood** forks green (factory bootstrap + at least one permissionless deploy path).  
- [ ] Factory + hooks bind **canonical chain V4 PoolManager** (immutable; D67); hermetic uses test PM only at factory construct.  
- [ ] Rates: public **`IRateProvider` addresses only** (D17/D69); no package adapters.  
- [x] Implementation plan written from **this PRD (v0.5.2+)** under `stable/quad` — see [`UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md) (**plan v1.0**).

---

## 9. Mapping: behavioral requirements ↔ IndexedEx standards

| Behavioral need | Foreign-style anti-pattern | IndexedEx law |
|-----------------|----------------------------|---------------|
| V4 PoolManager | Self-deploy production PM / pass PM per user deploy | **Canonical chain Uni V4 PM**; factory + hook **immutable** (D67) |
| Mine hook flags | CREATE2 `new {salt}` only | **CREATE3** ecosystem `create3Factory` + `HookMinerCreate3` (miner deployer = create3Factory) |
| Permissionless deploy | Users must hold CREATE3 operator keys | **On-chain factory** is operator; public `deploy` for anyone |
| Hook base | Inherit `BaseHook` | **Pattern-copy** permissions + callbacks |
| Storage | Scattered public vars / inheritance chain storage | **Repo** diamond-style slot + immutables |
| LP token | OZ ERC20 on inheritance tower | ERC-20 on mined wire; Crane helpers preferred |
| Multi-asset inventory | PM ERC-6909 claims as sole design | **Repo reserves** + peer settle |
| Admin on hook | Ownable mutates fees/A | **Immutables**; permissionless instance |
| Pool bootstrap | Hook ctor inits pairs / silent subset | **Factory** inits **all six** after hook code live (D61) |
| Pair set | Ad-hoc integrator keys | **Normative D55–D57** address-sorted + fee + tickSpacing + tick0 price |
| Tests | Mocks of hook/factory | **Production-first** real deploy |

---

## 10. Suggested constants (draft → implementor defaults)

| Constant | Value | Notes |
|----------|-------|-------|
| `N_TOKENS` | `4` | Fixed product constant |
| `FEE_DENOMINATOR` | `1_000_000` | Pips |
| `RATE_PRECISION` | `1e18` | |
| `AMP_PRECISION` | `100` | Internal A scale |
| `MAX_AMP` | `1_000_000` | Unscaled upper bound (exclusive per D15) |
| `MINIMUM_LIQUIDITY` | `1000` | Minted to `address(0)` |
| `TICK_SPACING` | `1` | Pool init convention |
| `INIT_SQRT_PRICE_X96` | `TickMath.getSqrtPriceAtTick(0)` | Factory pool init |
| `PAIR_COUNT` | `6` | \(\binom{4}{2}\) |
| `MAX_NR_ITERS` | `255` | Newton-Raphson (D38) |
| `MAX_LOOP` | Peer buffer/orbital mine-loop default (plan may pin exact uint) | On-chain mine exhaust (D62) |
| `MIN_DECIMALS` | `6` | |
| `MAX_DECIMALS` | `18` | |
| Default salt namespace | `"uv4-quad-stable-swap-hook-"` | D33 |
| Suggested demo `lpFeePips` | `500` (0.05%) | Non-zero |
| Suggested demo `baseAmp` | `100`–`1000` (stables) / higher for tight pegs | Ops guidance; prefer \(A \ge 10\) |

---

## 11. Out of scope follow-ons (explicit)

1. `stable/dual` and `stable/triple` packages (same math, different \(n\)).  
2. SE buffering of idle reserves.  
3. Amp ramp / mutable \(A\) after deploy.  
4. Hook/protocol fee skim collectors.  
5. Instance owner / pause / admin.  
6. DETF composition of quad LP or pair doors.  
7. Arbitrary weight vectors (true Balancer weighted pool on V4).  
8. Native ETH currency support.  

---

## 12. Revision log

| Version | Date | Notes |
|---------|------|-------|
| **v0.1** | 2026-08-03 | First draft PRD. Harvested multi-asset Uni V4 StableSwap behavior into IndexedEx requirements. |
| **v0.2** | 2026-08-03 | Stakeholder Q&A locks: PoolKey fee=`lpFeePips`; immutable A; reserves-only fees; all-four first mint; no native ETH; deploy-time rate oracles; permissionless; **zap-in in v1 DoD**; forks=**Base + Robinhood Chain**. |
| **v0.3** | 2026-08-03 | Residual locks: `TICK_SPACING=1`; MINIMUM_LIQUIDITY → `address(0)`; zap algorithm **A** target-ratio sequential; zap accepts **any non-empty subset** of 4 legs. Ready for implementation plan. |
| **v0.3.1** | 2026-08-03 | Package path moved `…/weighted/quad/` → **`…/stable/quad/`**. All PRD path references updated. Product name + CREATE3 salt namespace unchanged. |
| **v0.4** | 2026-08-03 | **On-chain permissionless factory** (D51–D66, §5.5): public deploy of hook via ecosystem CREATE3; **all six** pair pools initialized (address-sorted keys, fee=`lpFeePips`, tickSpacing=1, sqrtPrice=tick0); `ensurePairPools` repair; hook ctor does not create pools. |
| **v0.4.1** | 2026-08-03 | PRD file renamed to **`UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md`**. |
| **v0.4.2** | 2026-08-03 | All product identifiers renamed to **`UniswapV4QuadStableSwapHook`** family (interfaces, Math/Repo/Target/Factory/FactoryService, salt `uv4-quad-stable-swap-hook-`, LP prefix `QS-`). Removed residual “Weighted” product naming. |
| **v0.5** | 2026-08-03 | Q&A: strict ascending tokens; dual mine paths; factory-only ensure; `HookDeployed` only on new code; Balancer `IRateProvider` rates (no package adapters); first mint without prior swaps; Robinhood any ERC-20/test tokens. **D67:** PM is factory-immutable — **not** Vault Fee Oracle `feeTo()` (wrong type/role; §5.5.9). |
| **v0.5.1** | 2026-08-03 | **D67 clarified:** factory immutable PM = **canonical Uniswap V4 PoolManager for that chain**; users never pass PM; hermetic may use test PM only at factory construction. Bootstrap §5.5.4 updated. |
| **v0.5.2** | 2026-08-03 | **Quality/clarity pass.** Locked: **D72** pair-leg swap gate; **D73** zap `sharesMin` only; **D74** rate fail-closed; **D17/D69** public rates = `IRateProvider` addresses only (no selector). Fixed stale draft residue (user-story “proposed D23”, fee sketch skim language, R3 dangling refs, overloaded “live book”, ensurePairPools factory-only wording, DoD section cross-ref). Terminology + interfaces + tests aligned. |
| **v0.5.2+plan** | 2026-08-03 | Implementation plan **v1.0** landed beside this PRD. DoD “plan written” checked; §13 points implementors at the plan. |

---

## 13. Next iteration checklist (for other agents)

1. ~~Write **implementation + test plan** from **v0.5.2**~~ — **done:** [`UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md) (v1.0).  
2. Implement against **plan v1.0** + **this PRD** (production-first; both factory deploy paths; rate fail-closed; pair-leg swap gates).  
3. Re-verify canonical V4 PoolManager addresses on Base / Robinhood at script time (plan §7.1 table is guidance only).  
4. Confirm settle path bit-for-bit against buffer/dual Target peers during Phase E.

---

**End of PRD — UniswapV4QuadStableSwapHook (Draft v0.5.2)**
