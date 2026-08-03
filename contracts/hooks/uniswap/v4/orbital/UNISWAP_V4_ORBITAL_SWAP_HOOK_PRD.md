# PRD: Uniswap V4 Orbital Swap Hook (3-Asset Spherical Curve)

**Name:** `UniswapV4OrbitalSwapHook`  
**Date:** 2026-08-03  
**Status:** **v1.11 plan-ready** — O1–O9 + Q1–Q48 + growth fee (2026-08-03). **v1.11:** partial-book min only over maxed positive legs (Q43); **sphere-NAV fair seed** (Q44 / D72 — replaces sum-NAV); residual `sumPos` invariant (Q45); `addLiquidity` returns used amounts (Q46); **orbital-normative Permit2 packing** §5.6 (Q47); Robinhood fork **chain ID 4663** (Q48).  
**Package path:** `contracts/hooks/uniswap/v4/orbital/`  
**Package kind:** IndexedEx **hook deploy package** — CREATE3-mined single contract via the **existing** ecosystem `create3Factory` + `HookMinerCreate3` + FactoryService helpers. **Not** a vault share diamond; **not** a second CREATE3 factory; **not** `DiamondPackageCallBackFactory` for the hook instance (v1). **Not** a Facet/DFPkg diamond product — use **Repo + Target + Math** style on a single mined contract that is also the fungible LP ERC-20 (EIP-2612).  
**Decision ID note:** `D*`, `O*`, and `Q*` IDs are **stable keys**, not document order.

**Authority (normative):**

| Layer | Role |
|-------|------|
| **This PRD (v1.11)** | Product law used to **write** the implementation plan. Canonical decisions live in §3 (D/O/Q). |
| **Implementation plan** (follow-on) | **Source of truth for implementors** once written against this PRD |
| Peer packages / reference repo | Pattern and math references only — **not** deploy law; do not copy CREATE2 / BaseHook / console.log |
| ETHGlobal `OrbitalHook.sol` | Behavioral/math reference only (D3) |

**Reference implementation (behavioral + math source, not deploy law):**

- Repo: [Dhruv-2003/ethglobal-buenos-aires-25](https://github.com/Dhruv-2003/ethglobal-buenos-aires-25) (`src/OrbitalHook.sol`, deploy/interaction scripts)
- Paper / product concept: [Paradigm — Orbital (2025-06)](https://www.paradigm.xyz/2025/06/orbital)
- Design notes in reference: multi-stable shared liquidity via spherical invariant; three Uni V4 pools as entry “doors”; hook holds inventory and does all pricing

**Sibling packages (do not conflate):**

| Package | Path | Role |
|---------|------|------|
| Single SE buffer | `contracts/hooks/uniswap/v4/standardExchange/single/` | Wrapper pool `underlying ↔ SE`; no multi-asset AMM |
| Dual SE buffer | `…/standardExchange/dual/` | CP AMM on **two** SE claim legs; buffer/unwrap into SEs |
| **This package** | `contracts/hooks/uniswap/v4/orbital/` | **3-asset spherical** curve on **raw ERC-20 reserves** held by the hook |

**Related Crane / IndexedEx standards (mandatory pattern sources):**

- Single buffer PRD (package shape, CREATE3 mine, settle pattern-copy, inheritance ban):  
  `contracts/hooks/uniswap/v4/standardExchange/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md`
- Dual buffer PRD (LP ERC-20 on hook, custom deposit surface, `beforeAddLiquidity` ban, Permit2 peer patterns):  
  `contracts/hooks/uniswap/v4/standardExchange/dual/UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`
- Crane HookMiner: `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol`
- Crane fee units: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol` (`DYNAMIC_FEE_FLAG`, `OVERRIDE_FEE_FLAG`)
- Crane math: `FixedPointMathLib` / `BetterMath` under `lib/crane/contracts/utils/`
- AGENTS.md — production-first tests; CREATE3; no mock SUT; no `new` facets

### 0. Terminology (normative)

| Term | Meaning in this PRD |
|------|---------------------|
| **Binding order** | Ctor order `(token0, token1, token2)` — LP views, events `amount0/1/2`, Permit2 batch index order |
| **Pool currency order** | V4 `currency0` / `currency1` = pair tokens **sorted by address** (may differ from binding indices) |
| **Hook LP / shares** | Fungible ERC-20 on **this** hook (18 decimals). API params named `shares` mean **hook LP**, never SE vault shares |
| **Full book** | All three Repo reserves \(r_0,r_1,r_2 > 0\) |
| **Partial book** | At least one Repo reserve is 0 (and `totalSupply > 0`) |
| **Seed** | Deposit into a **zero** reserve leg (pull full `a_jMax`); share mint via **sphere-NAV** (Q44 / D72), not sum-of-reserves |
| **Sphere spot weight \(p_i\)** | \(p_i = R - r_i^{18}\) (pre-op 1e18 reserves). Matches sphere marginal price ratios: \(\mathrm{d}y/\mathrm{d}x = -(R-x)/(R-y)\). Zero leg: \(p_j = R\) |
| **WAD domain** | All sphere, fee, LP, and NAV algebra in **1e18**; Repo stores **raw** native units |
| **\(L^2\)** | **Stored sphere parameter** (Q26) — recomputed after state changes; not a fee-conserved invariant |
| **DoD** | Definition of Done — package complete when §11 is satisfied |

### Canonical law index (planner shortcut)

Use this table as the **first hop**; full normative text lives at the linked section / decision. Do not invent alternate product law.

| Topic | Normative pointer |
|-------|-------------------|
| Product shape / non-goals | §1–§2.3 |
| Binding, \(R\), sphere, \(L^2\) | D14–D16, D15/O3, Q26, §4.3 |
| Decimal / WAD boundary + ceil/floor | D17, Q30, Q32/D64 |
| Trading fee + V4 override | D20–D21, D20a–c, §4.4.0 |
| Protocol growth fee (`kLast`) | D51–D59, Q11, §4.4.1 |
| First / later / seed / remove LP | D22–D25a, D24a, D72, Q38–Q39, Q43–Q46, §4.5 |
| Sphere-NAV partial mint | D72, Q44, §4.5.1 |
| No on-hook single-asset zap | Q40, §2.3 #19, §10 #6 |
| Preview fidelity | D27/Q37 — **bit-exact** |
| Swap settle / BeforeSwapDelta | §4.6 |
| Pool init scope | D31, D65, Q31, Q25 |
| Deploy / salt / CREATE3 | D32–D35, §5.2, §7 |
| Permit2 (inventory pulls) | D48–D49, Q22, Q36, Q47, **§5.6 (normative packing)** |
| LP ERC-20 + EIP-2612 + remove | D13, D46, Q41, §5.1 |
| Events / errors | D60/D61, §5.5 |
| Test DoD | §9; forks Q16/Q23/Q48 (Robinhood **4663**) |
| Locked decision tables | §3 (O1–O9, Q1–Q48, D*) |

---

## 1. Goal

Ship a **production-first Uniswap V4 hook package** that:

1. Binds **three** ERC-20 assets (typically stables, e.g. USDC / USDT / DAI) and one V4 `PoolManager` per hook instance.
2. Implements the **Orbital sphere invariant** for pricing (reference math; Paradigm geometry simplified to a **single orbit** in v1). Radius \(R\) is **set once from first liquidity** (O3), then fixed for the life of the instance:
   \[
   (R - x)^2 + (R - y)^2 + (R - z)^2 = L^2
   \]
   with \(x,y,z\) **1e18-normalized** virtual reserves of the three tokens.
3. Exposes **three Uni V4 pair pools** as swap entry points (A/B, B/C, A/C), **all pointing at the same hook address**, so every pair trade is priced against the **shared 3D reserve state** (witness / third token always participates in the math).
4. Holds **real token inventory on the hook** (not SE shares, not V4 CL positions).
5. Mints a **single fungible ERC-20** LP representing pro-rata claim on all three reserve legs.
6. Provides **custom** `addLiquidity` / `removeLiquidity` on the hook; **forbids** native V4 `modifyLiquidity` / CL.
7. Settles swaps via **`beforeSwap` + `beforeSwapReturnDelta`** (custom accounting / NoOp curve), pattern-copied to Crane settle order — **no** Solidity inheritance of OZ/`BaseHook` / `BaseTokenWrapperHook` / `DeltaResolver`.
8. Deploys via **existing** `create3Factory` + binding-aware `HookMinerCreate3` + FactoryService (same law as buffer hooks).
9. Uses **live Vault Fee Oracle** rates: trading fee (`dexSwapFeeOfVault`) residual in reserves + protocol growth (`usageFeeOfVault`) LP mint to `feeTo`; PoolKey uses **`DYNAMIC_FEE_FLAG`** so rates can change without re-init (Q7 / Q19).

### 1.1 Canonical user story (USDC / USDT / DAI)

```text
Hook binding (instance):
  token0 = USDC, token1 = USDT, token2 = DAI
  poolManager = V4 singleton
  feeOracle = Vault Fee Oracle (IVaultFeeOracleQuery) — ctor immutable
  swap fee = feeOracle.dexSwapFeeOfVault(address(hook))  // WAD; may change over time
  usage fee = feeOracle.usageFeeOfVault(address(hook))   // WAD; growth mint to feeTo
  R = unset until first liquidity (then set-once in Repo)

Inventory: hook holds USDC + USDT + DAI balances (accounting via Repo reserves)
LP: fungible auto-named ERC-20 (e.g. ORB-USDC-USDT-DAI) on same contract

--- First liquidity ---
User calls addLiquidity(a0Max, a1Max, a2Max, to, sharesMin, deadline, permit2Data)
  → returns (shares, a0, a1, a2) used amounts (Q46)
  → require deadline; ≥2 of three amountMax > 0 (O7)
  → pull via ERC-20 SafeTransfer and/or Permit2 (Q1 / Q22 / §5.6)
  → R := max(a0Wad, a1Wad, a2Wad) * 10  (set once; O3/Q4)
  → shares = sumWad − MINIMUM_LIQUIDITY (O2); require ≥ sharesMin
  → no protocol growth mint (kLast == 0); then set kLast/kLastMode if fee-on

--- Pools (integrator, external; any subset OK — O6) ---
initialize only the pairs you need
  → beforeInitialize: pair ⊂ bound tokens; **fee == DYNAMIC_FEE_FLAG** (Q7)
  → actual LP fee always from oracle at swap time (not frozen in PoolKey)

--- Swap USDC → DAI ---
  → feeWad = dexSwapFeeOfVault(this); apply residual on input in hook accounting (D20/D21)
  → beforeSwap returns dynamic fee override (V4 pips | OVERRIDE_FEE_FLAG) for routers (D20b/D20c)
  → BeforeSwapDelta custom curve; hook inventory is counterparty (§4.6)

--- Subsequent add (after swaps grew k) ---
  → if fee-on: mint protocol LP to feeTo from k growth vs kLast (D51–D57)
  → full book: three-leg Uni V2 proportional only (Q39); no on-hook zap (Q40)
  → partial book: prop min only over maxed positive legs (Q43); seed via sphere-NAV (Q44);
      seed-only OK (Q38); unified shares = supply' * V_in / V_before (D72)
  → then user mint on post-protocol totalSupply

--- Withdraw ---
removeLiquidity(shares, to, a0Min, a1Min, a2Min, deadline)
  → protocol growth mint first if fee-on; burn msg.sender LP only (Q41); pro-rata pay to `to`
```

### 1.2 Why this exists (product problem)

| Approach | Limitation |
|----------|------------|
| Uni V3/V4 CL pairs | Capital fragmented across three 2-token pools; multi-hop fees |
| Curve multi-stable | Multi-asset, but **uniform** liquidity (no nested concentration story) |
| Full Paradigm Orbital | Nested “orbits” (concentrated multi-asset ticks) — **v1 ships single orbit only** |
| **This package (v1)** | Shared 3-asset sphere on one hook; three V4 doors; production deploy/settle standards |

v1 is the **productionization of the ETHGlobal prototype curve + multi-pool shared inventory**, not a full multi-orbit tick system (see non-goals).

---

## 2. Product summary

### 2.1 What this package is

| Attribute | Value |
|-----------|--------|
| Primary artifact | CREATE3-mined single hook (Repo + Target + Math + Common) implementing V4 `IHooks` **plus** 3-asset LP ERC-20 |
| Binding | `(poolManager, feeOracle, token0, token1, token2)` — ctor immutables; **\(R\) set once on first liquidity** |
| Pool currencies | Any **ordered pair** of the three bound tokens (subset of three pools OK) |
| Inventory | Hook-held **raw ERC-20**; Repo reserves are SoT |
| Pricing | Orbital sphere on **1e18-normalized** reserves (**all** math in WAD — Q30); \(L^2\) **stored sphere parameter** (Q26); witness may be 0; **no full trade-leg drain** (Q27) |
| Swap (trading) fee | **Live** `dexSwapFeeOfVault(this)` — **WAD**; residual **stays in reserves** (LPs). Hook is economic SoT (D20c) |
| Protocol growth fee | **Live** `usageFeeOfVault(this)` — **WAD**; Uni V2–style **`kLast` + mint LP to `feeTo`** on add/remove (D51+) |
| V4 PoolKey.fee | **`DYNAMIC_FEE_FLAG`** — trading fee SoT is oracle (Q7 / Q19) |
| LP | Fungible ERC-20 + **EIP-2612**; **decimals always 18** (Q24); auto name/symbol; pro-rata (+ seed shares); protocol may hold LP via `feeTo` |
| Deposit / withdraw | Uni V2 **three-leg** proportional when full book; partial: **sphere-NAV** mint (Q44/D72), prop min only over maxed positive legs (Q43), **seed-only OK** (Q38); **no** on-hook zap (Q40); `addLiquidity` returns **(shares, a0, a1, a2)** (Q46); mins + deadline; SafeERC20 and/or Permit2 (§5.6); remove burns **`msg.sender`** (Q41); **protocol mint before user supply change** when fee-on |
| Deploy path | Existing `create3Factory` + `HookMinerCreate3` + FactoryService |
| Access | **Permissionless** instance; fee rates / `feeTo` via Vault Fee Oracle only |

### 2.2 What this package is not

- Not the single SE buffer hook or dual SE buffer hook (no Standard Exchange binding in v1).
- Not a full Paradigm multi-orbit tick / nested spherical-cap book (single \(R\), single \(L^2\) surface in v1).
- Not Uni V4 concentrated liquidity / Position Manager LP / tick bitmap.
- Not a Facet/DFPkg diamond for the hook instance.
- Not package-owned pool creation (integrator initializes the three pools).
- Not a DETF or vault registry product.
- Not a copy-paste of OZ `BaseHook` / Solady ERC20 from the hackathon tree without IndexedEx layering.
- Not dual-buffer fee naming: dual uses oracle `dexSwapFee` as **growth** share; **this** product uses `dexSwapFee` for **trading** residual and `usageFee` for **growth** (Appendix B).

### 2.3 Non-goals (v1)

1. Nested multi-orbit “ticks” / concentric spherical caps (Paradigm full product).  
2. \(n > 3\) assets (hypersphere).  
3. Yield buffering into SE / Morpho / ERC-4626 on the orbital book (future composition PRD).  
4. Native ETH as a pool currency (wrap to WETH off-hook).  
5. Fee-on-transfer / rebasing tokens as inventory (Q1 — **out of scope / unsupported**).  
6. Binary-search solvers — exact-in/out must be **closed form** on the sphere (no zap-split solver carve-out — Q40).  
7. Subclassing dual/single buffer hooks.  
8. Shared TestBases with DETF Uni V4 packages.  
9. Reusing reference CREATE2 `HookMiner.find` + `new {salt}` deploy (forbidden — CREATE3 factory law).  
10. Leaving `console.log` / debug logs in production sources.  
11. Trusting PoolManager `slot0` price for quoting (aggregators must use hook previews).  
12. Owner / pause / admin surface on the instance (**fully permissionless** — O9). Fee **rate** changes only via **Vault Fee Oracle** governance (not instance admin).  
13. Growing \(R\) after first mint (O3: set-once only; later ops that would make any 1e18 reserve ≥ \(R\) **revert**).  
14. Resetting \(R\) after full liquid exit (Q6 — dead shares + fixed \(R\) forever).  
15. Immutable deploy-time swap fee pips as product SoT (**superseded** by oracle WAD — Q3).  
16. Protocol cut taken as an extra **swap amountIn haircut** (protocol cut is **LP mint on growth only** — D51).  
17. Using `dexSwapFeeOfVault` as the protocol growth rate (that field is **trading fee only** on this product; growth uses **`usageFeeOfVault`** — D52).  
18. Splitting trading residual to `feeTo` on every swap, multi-recipient fee splits, or orbit-level fees (future — §10).  
19. **On-hook single-asset zap / `depositSingle`** (internal sphere rebalance then proportional mint) — **v1 out** (Q40). Full book = three-leg proportional `addLiquidity` only (Q39). Users rebalance off-hook, then multi-leg add. Fair zap = future PRD (§10).

---

## 3. Locked product decisions

| # | Decision | Value |
|---|----------|--------|
| D1 | Product name | **`UniswapV4OrbitalSwapHook`** (canonical; not `UniswapV4OrbitalHook`) |
| D2 | Package location | `contracts/hooks/uniswap/v4/orbital/` |
| D3 | Reference source | ETHGlobal `OrbitalHook.sol` + Paradigm Orbital writeup — **behavioral/math reference only** |
| D4 | Asset count (v1) | **Exactly three** ERC-20s per instance |
| D5 | Binding | Ctor immutables: `poolManager`, **`feeOracle` (`IVaultFeeOracleQuery`)**, `token0`, `token1`, `token2`; **no post-deploy rebind**; **\(R\) not a ctor arg** (D15). **No** immutable swap fee |
| D6 | Token validation | Non-zero; **pairwise distinct**; standard ERC-20 + **USDT-style** SafeERC20 (Q1). **Fee-on-transfer / rebasing unsupported** |
| D7 | Ctor token order | Caller-supplied order is **canonical binding order** for LP / views; pool keys still sort by address for V4 |
| D8 | Pool set | Integrator may create **any subset** of the three pair pools (O6); all `hooks = this` when created |
| D9 | Pool fee (V4 key) | **`LPFeeLibrary.DYNAMIC_FEE_FLAG`** only (Q7 / Q19). **Not** static 0 and **not** a frozen pips snapshot. SoT for rate = oracle |
| D10 | Native CL | **Forbidden** — `beforeAddLiquidity` and `beforeRemoveLiquidity` **revert** |
| D11 | Package shape | **Repo + Target + Common + Math + FactoryService + thin wire contract**; no Facet/DFPkg |
| D12 | Hook inheritance | **No** inheritance of Crane/OZ `BaseHook`, `BaseTokenWrapperHook`, `DeltaResolver`, or reference `BaseHook` — full **pattern-copy** |
| D13 | LP ERC-20 | **Same mined hook contract** (IHooks + ERC-20 + **EIP-2612**). **Decimals always `18`** independent of leg decimals (Q24). `MINIMUM_LIQUIDITY = 1000` is **LP wei**. Prefer Crane/Uni V2–style token helpers (not OZ `_mint` semantics that break dead shares — D46) |
| D14 | AMM model | **Orbital sphere** single orbit: \((R-x)^2+(R-y)^2+(R-z)^2=L^2\) |
| D15 | Radius \(R\) | **Set once on first successful `addLiquidity`**. \(R = \max(a_i^{18}) \times\) **`R_SAFETY_MULTIPLIER = 10`** (Q4). Repo set-once. Later ops with any 1e18 reserve **≥ \(R\)** **revert**. Pre-first-mint: \(R = 0\); swaps revert |
| D16 | Sphere parameter \(L^2\) | Repo **stored sphere parameter** (not a fee-conserved invariant). **Recompute** after every successful LP/swap state change from current 1e18 reserves: \(L^2=\sum_i(R-r_i^{18})^2\). With trading residual, post-swap reserves are **not** on the pre-swap sphere; the **next** trade uses the new \(L^2\) (Q26). Zero until first mint |
| D17 | Decimal law (uniform WAD math) | **Any `uint8` leg decimals** (Q2 / Q30 / Q32). Cache `decimals()` at ctor (missing/revert → **18**). **All product math** in **1e18**. **Repo stores raw.** **toWad** always **floor**. **fromWad denorm (Q32):** **floor** for amounts the user **receives** (exact-in `amountOut`, remove payouts, and LP `used_i` pulls sized by ratio); **ceil** for amounts the user **pays on exact-out** (`amountIn` after WAD gross-up). Decimals &gt; 18: truncating `toWad`; never invent tokens on invert. **preview == execution** is **bit-exact** on the shared ceil/floor path (Q37) |
| D18 | Reserves SoT | **Repo `reserves[token]`** — ignore stray `balanceOf` donations (D36) |
| D19 | Witness token | Third bound token always in formulas (may be **zero** — O7) |
| D20 | Trading (swap) fee | **Live per-address** WAD from **`feeOracle.dexSwapFeeOfVault(address(this))` on every swap and swap preview** (Q3 / Q10). Oracle cascade still applies when per-address unset (vault → type → default). **0 allowed**. Require **`feeWad < 1e18`**. Input residual; not PoolKey static fee |
| D20a | Exact-out trading gross-up | **WAD only:** `amountIn = amountInNet * 1e18 / (1e18 − feeWad) + 1` when `feeWad > 0`; if 0, `amountIn = amountInNet`. **No pips gross-up formula** (Q19) |
| D20b | Trading fee → V4 units | `uint24 v4Fee = uint24(feeWad * 1_000_000 / 1e18) \| LPFeeLibrary.OVERRIDE_FEE_FLAG` (floor pips, then set override bit). Return as **beforeSwap fee override**. Floor mapping may lose dust vs pure WAD residual — **preview == execution is defined on WAD residual**, not on the pips report |
| D20c | Fee override role (NoOp custom curve) | **Economic trading fee SoT = hook residual math (D20/D21).** V4 override is **informational + router/aggregator UX** so quotes and fee displays match. When `BeforeSwapDelta` consumes the full specified amount (custom curve / NoOp), PoolManager must **not** be relied on to collect residual. **Do not double-haircut** amountIn (Q19) |
| D21 | Trading fee destination | Residual **stays in input reserve** (grows inventory / \(L^2\) / LP NAV). **Not** transferred to `feeTo` |
| D51 | Protocol cut (growth) | **Yes — Uni V2–style liquidity growth fee.** On **addLiquidity** and **removeLiquidity** (not on every swap): if fee-on, **mint LP to `address(feeTo)`** from growth of a reserve measure since **`kLast`**, **before** adjusting the user’s LP supply. Peer: dual SE buffer CP **D57** / Crane `ConstProdUtils._calculateProtocolFee` |
| D52 | Protocol cut rate source | **Live per-address** **`feeOracle.usageFeeOfVault(address(this))` on every add/remove (and LP preview)** (Q10). Cascade → type default → **`defaultUsageFee`**. **Not** `dexSwapFeeOfVault`. **0 WAD** or **`feeTo == 0`** or **`ownerFeeShare == 0`** (Q18) ⇒ fee-off |
| D53 | Protocol cut recipient | **`address(feeOracle.feeTo())`**. Mint hook **ERC-20 LP** to that address. Failed mint ⇒ whole LP op reverts. **Exit:** any holder including `feeTo` uses normal **`removeLiquidity`** (Q12) — no special redeem |
| D54 | fee-on predicate | `feeOn = (feeTo != 0 && usageFeeWad != 0 && usageFeeWad < 1e18 && ownerFeeShare != 0)` where `ownerFeeShare = usageFeeWad * 100_000 / 1e18` (floor) (**Q18**) |
| D55 | `kLast` measure (3-asset) — **dual mode (Q11)** | **Full book** (all three reserves > 0): \(k = x^{18}\cdot y^{18}\cdot z^{18}\); fee root = **`cbrt(k)`**. **Partial book** (any reserve == 0): **sum-based interim** \(k = x^{18}+y^{18}+z^{18}\); fee root = **`k` itself** (linear growth measure). Repo stores **`kLast`** and **`kLastMode`** (`FullProduct` \| `SumInterim`). **Cross-mode:** if mode of this op ≠ stored mode, **do not mint** from incompatible `kLast`; treat as `kLast == 0` for mint, then set `kLast`/`kLastMode` post-op. **Re-seed** (partial → full): mint protocol fee on **sum-based** \(k_{\text{pre}}\) vs sum-mode `kLast` when same mode and growth; after successful seed to all-three, set post-op `kLast` to **product** and mode `FullProduct`. Overflow: accepted Uni V2-class risk on product mode |
| D56 | `ownerFeeShare` + protocol mint algebra | **`ownerFeeShare = usageFeeWad * 100_000 / 1e18`** (floor), `FEE_DENOMINATOR = 100_000`. **Same Uni V2 / ConstProdUtils generic branch** for both modes — only `rootK` measurement changes (Q20): FullProduct `rootK = cbrt(k)`; SumInterim `rootK = k`. Normative mint: `protocolLp = totalSupply * (rootK - rootKLast) / (rootK * FEE_DENOMINATOR / ownerFeeShare + rootK - rootKLast)` when `rootK > rootKLast` and fee-on; else 0. If floor `ownerFeeShare == 0`, fee-off (Q18). See §4.4.1 worked example |
| D57 | Growth fee timing (Uni V2 peer) | **Add:** measure \(k_{\text{pre}}\) from **current reserves before pull/seed**; if fee-on && `kLast != 0`, mint protocol LP from \((k_{\text{pre}}, kLast)\); then pull tokens / update reserves / mint **user** LP using **post-protocol-mint** `totalSupply`; set `kLast = k_{\text{post}}` if fee-on else `0`. User’s new capital is **not** taxed as growth in the same op. **Remove:** mint protocol LP from current \(k\) vs `kLast` **before** user burn; then burn/pay out; set `kLast` post-op. **First mint:** no protocol mint while `kLast == 0`; after first mint, set `kLast`/`kLastMode` from **post** reserves if fee-on (**dual-mode** — product only if all three > 0, else SumInterim). **Swaps** do **not** mint protocol LP or update `kLast` (growth accrues; next LP op realizes fee — dual D67 peer). Trading-fee residual and any reserve increase are fee-eligible on next LP op |
| D58 | Growth fee + previews | `previewAddLiquidity` / `previewRemoveLiquidity` **must** simulate protocol mint dilution (post-protocol `totalSupply`) so preview == execution **bit-exact** when fee-on **at the same oracle reads** (usageFee, feeTo, and trading fee for swaps) (Q37) |
| D59 | Growth fee public views | Required: `usageFee()` (WAD passthrough), `feeTo()`, `kLast()`, **`kLastMode()`** (Q21), and existing `dexSwapFee()` / `feeOracle()` |
| D22 | Deposit | **`addLiquidity(a0Max, a1Max, a2Max, to, sharesMin, deadline, permit2Data) returns (shares, a0, a1, a2)`** only multipath surface in v1 — **no** `depositSingle` / zap (Q40). **D57 protocol mint first** (if fee-on); pull via SafeERC20/Permit2 (§5.6); shares ≥ sharesMin; deadline. Returns **native used** amounts in **binding order** (Q46). Branch: first mint / full-book later (D24) / partial (D24a/D72/Q38) |
| D23 | First mint | **≥2** positive legs; **`require sum(a_iWad) > MINIMUM_LIQUIDITY`** so `shares = sumWad − MIN` does not underflow and user shares **&gt; 0** (Q33); set \(R\); dead MIN to **`address(0)`** (D46 Uni V2 peer); **no** protocol mint (`kLast == 0`); then set `kLast`/`kLastMode` if fee-on (D57 dual-mode) |
| D24 | Subsequent mint (all legs > 0) | **Full book only — three-leg Uni V2 min-ratio** (Q39). **No** one- or two-sided add; **no** zap. **Protocol mint** from pre-pull \(k\) vs `kLast` (D57); then min-ratio in **1e18** on **post-protocol** supply (Q19 / Q29 / Q30): `r_iWad = toWad(r_i)`; `a_iMaxWad = toWad(a_iMax)`; `shares = min_i(a_iMaxWad * supply' / r_iWad)`; `used_iWad = shares * r_iWad / supply'` (floor); `used_i = fromWadFloor(used_iWad)`; pull **only** `used_i`; **require `used_i > 0` for every leg** (all three participate) (Q35); require `shares >= sharesMin` and post 1e18 reserves **&lt; \(R\)**; set `kLast` post-op. Zero `a_iMax` on any leg ⇒ shares/used zero path **reverts** |
| D24a | Partial-book used amounts (Q5 / Q38 / Q43) | When **any** `r_j == 0` (partial book): (1) **Positive-leg prop set \(P\)** = `{i : r_i > 0 ∧ a_iMax > 0}` — Uni V2 min-ratio in **WAD over \(P\) only** (Q43). Legs with `r_i > 0` and `a_iMax == 0` are **not** in the min and **not** pulled. (2) **Zero-leg seed set \(Z\)** = `{j : r_j == 0 ∧ a_jMax > 0}` — pull **full** `a_jMax` native. (3) **Seed-only (Q38):** \(P = \emptyset\), \(Z \ne \emptyset\) OK. (4) Require \(P \cup Z \ne \emptyset\). Each \(i \in P\): `used_i > 0` after floor (Q35). **Share mint = sphere-NAV (D72 / Q44)** — **not** sum-of-reserves and **not** additive `sharesProp + sharesSeed`. While partial, protocol growth uses **SumInterim** \(k\) (Q11) |
| D72 | Sphere-NAV partial mint (Q44) | After protocol mint and after determining **used** amounts (D24a): pre-op spot weights **`p_i = R - toWad(r_i)`** (zero leg ⇒ `p_j = R`). Require every `p_i > 0` (equiv. all `r_i^{18} < R`). **`V_before = Σ_i p_i · toWad(r_i)`** (zero legs contribute 0). **`V_in = Σ_i p_i · toWad(used_i)`** using **pre-op** prices (no price-impact gift). **`shares = supply' · V_in / V_before`** (floor). Require `V_before > 0` (Q45), `shares > 0`, `shares >= sharesMin`. Full-book later mint **does not** use D72 (stays Uni V2 three-leg D24). First mint **does not** use D72 (O2 sumWad). Math lib must expose pure `sphereSpotWeight` / `sphereNavShares` helpers |
| D25 | Withdraw | **`removeLiquidity(shares, to, a0Min, a1Min, a2Min, deadline)`** — burn **`msg.sender`** LP only (Q41; no allowance/`burnFrom`); pay legs to `to`. **D57 protocol mint first**; then pro-rata in **WAD**: `amount_iWad = shares * toWad(r_i) / supply'`; `amount_i = fromWadFloor(amount_iWad)`; require ≥ mins; pay raw; deadline; set `kLast` post-op |
| D25a | Full liquid exit (Q6 / Q45) | After only **MINIMUM_LIQUIDITY** remains: residual pro-rata dust locked forever; **\(R\) stays set**; next add is **subsequent** path (never re-run first-mint / never reset \(R\)). **Invariant:** whenever `totalSupply > 0`, **`Σ toWad(r_i) > 0`** (residual dust on dead MIN never zeroes all legs). No `sumPosWad == 0` re-seed branch — if violated, treat as fatal invariant failure (tests assert; production should be unreachable) |
| D26 | Swap modes | Exact-in + exact-out; **pre- and post-swap** both leg **Repo** reserves **&gt; 0** (Q27 — **no full drain** of output leg); witness may be 0 |
| D27 | Preview fidelity | **Bit-exact** `preview* == execution` **at same oracle fee reads** (dexSwapFee on swaps; usageFee + feeTo on LP) and **same** toWad/fromWad ceil/floor path (Q37). **No** ±1 wei allowance in v1 DoD |
| D28 | Public previews / fee views | LP + swap previews (LP previews **include** protocol mint sim — D58); `reserveOf`, `lSquared`, `radius`, **`feeOracle`**, **`dexSwapFee()`**, **`usageFee()`**, **`feeTo()`**, **`kLast()`**, **`kLastMode()`**, tokens/pm |
| D29 | Zero amounts | Revert zero amountIn/out/shares; first mint &lt;2 positive legs reverts |
| D30 | Reentrancy | **One global non-reentrant lock** on **`addLiquidity` / `removeLiquidity` and `beforeSwap` body** (after `msg.sender == poolManager` check) (Q34). Blocks LP ↔ swap cross-reentrancy (malicious ERC-20 callbacks, nested unlock attempts). |
| D31 | Pool init | External; **only pools that set `hooks = this`** invoke the hook (Q31). Validate: currencies ⊂ bound set, distinct, **`fee == DYNAMIC_FEE_FLAG`**. **No** per-pair uniqueness: multiple PoolKeys for the same bound pair (e.g. different `tickSpacing`) **allowed** — all share the same reserves. **No** product concern for other pools of the same tokens that **do not** use this hook. **`sqrtPriceX96` + `tickSpacing` = plumbing only** (Q25); hermetic: spacing **60**, 1:1 mid. Subset of pairs OK (O6) |
| D62 | LP vs pool init independence | **`addLiquidity` / `removeLiquidity` / LP previews do not require** any V4 pool `initialize` (Q28). **Swaps** require: \(R > 0\), **initialized** pair pool for that directed pair, both trade-leg Repo reserves &gt; 0. **V4 `initialize` does not require** hook liquidity |
| D63 | Post-swap reserve floor | Successful swap **must leave** `reserves[tokenOut] > 0` and `reserves[tokenIn] > 0` in Repo after updates (Q27). Exact-in: require **`0 < y' < y`** (strict). Exact-out: `amountOut` must leave residual raw out reserve &gt; 0. Revert if trade would zero a leg (no dust-floor mint; hard fail) |
| D32 | Deploy | CREATE3 + flag mine; FactoryService; **not** vault registry `deployPkg` for instance (**no registry required** — Q10 / Q42). Fees always resolved **live** via **per-address** oracle query APIs; oracle cascade/defaults apply when per-address slot unset |
| D33 | Salt namespace default | **`"uv4-orbital-swap-hook-"`** |
| D34 | Salt material | `namespace, poolManager, feeOracle, token0, token1, token2, mineNonce` — **no \(R\)**, **no fee pips**. `mineNonce` is internal to the FactoryService mine loop (not a user deploy arg) |
| D35 | Idempotent deploy | Same binding + namespace ⇒ same address; `isExpectedHook` checks pm + feeOracle + tokens |
| D36 | Donations | Stray ERC-20 **ignore forever** for pricing/reserves (Q14). No skim/absorb in v1 |
| D60 | Events (Q17 / Q21) | **Normative ABIs in §5.5.** Required: `LiquidityAdded`, `LiquidityRemoved`, `Swap`. **`ProtocolFeeMinted` required whenever protocol growth mint &gt; 0** (omit only when mint is 0). No per-swap oracle spam events |
| D37 | Math library | Pure Math — sphere, WAD, shares, trading fee, \(R\), **sphere-NAV** \(p_i / V_{\mathrm{in}} / V_{\mathrm{before}}\) (D72), **cbrt product growth + sum interim growth** (Q11) + D56 algebra |
| D38 | Sqrt / cbrt | Crane `FixedPointMathLib` / `BetterMath` (or bit-identical pure helpers in Math) |
| D39 | Settle (swaps) | **§4.6** normative short law + pattern-copy dual/single buffer Target settle order (Q21) |
| D40 | Delta convention | §4.6 + tests: six directed pairs + router; custom curve / NoOp |
| D41 | Tests | Production-first; hermetic **required**; forks **required on Ethereum + Base + Robinhood Chain (4663)** (Q9 / Q16 / Q23 / Q48); no mock hook SUT |
| D42 | Fork DoD chains + tokens | **Ethereum, Base, and Robinhood Chain (chain ID 4663)** mainnet forks all required (Q16 / Q48). **Token choice is free:** production ERC-20s **or mintable/test tokens deployed on the fork** (Q23). Purpose = integration with **production protocol code** (PoolManager, Permit2, fee oracle, hook), **not** a specific stable triad. Prefer live stack; else deploy production-equivalent bytecode on the fork (dual D74 peer) |
| D43 | License / style | BUSL-1.1 (or peer); NatSpec + Crane style |
| D44 | LP name/symbol | Auto `ORB-{s0}-{s1}-{s2}`; address-fragment fallback |
| D45 | Access control | Permissionless instance; fee rate via **oracle only** |
| D46 | MINIMUM_LIQUIDITY | **1000 LP wei** (LP decimals = 18) → **`address(0)`** on first mint; **never burned**; permanently dilutes residual (Uni V2 / dual O5 peer). LP ERC-20 must support **balance on `address(0)`** (custom/Uni V2–style mint — **not** OZ `_update` that treats `to == 0` as burn) |
| D48 | Token pull (Q1 / Q22 / Q36 / Q47) | LP: **SafeERC20 `transferFrom`** (USDT-safe) **and** **Permit2** (signature **and** allowance transfer — both in DoD). **`permit2Data` empty ⇒ transferFrom only for every pulled leg.** **Non-empty ⇒ Permit2 for every `used_i > 0` leg** — **no mixed** transferFrom + Permit2 in the same call (Q36). **Normative packing = this PRD §5.6** (orbital self-contained; dual §7.3 is peer reference only). Swaps: PoolManager settlement only |
| D49 | Permit2 address | Uniswap **well-known Permit2** constant (chain-canonical); not a ctor arg (dual peer) |
| D50 | Fee oracle units | Both `dexSwapFeeOfVault` and `usageFeeOfVault` are **WAD percentages** (`_validateWadPercentage` peer in VaultFeeOracleRepo) |
| D61 | Custom errors (minimum set) | Plan may name precisely; **must cover:** `DeadlineExpired`, radius unset / swaps before first mint, `ReservesExceedRadius`, insufficient shares / amount mins, zero amounts, invalid pair / not bound token, wrong PoolKey fee (not dynamic), not pool manager, LP forbidden (native CL), invalid fee WAD ≥ 1e18, first mint &lt;2 legs, **first mint sumWad ≤ MIN** (Q33), **trade would zero leg** (Q27), **used_i == 0 after fromWad** (Q35 / full-book one-sided Q39), partial book empty \(P \cup Z\), invalid Permit2 packing/mode, reentrancy, insufficient LP balance on remove |
| D64 | Denorm ceil/floor (Q32) | **`fromWadFloor`:** exact-in `amountOut`, remove `amount_i`, later-mint `used_i`, seed positive-leg `used_i`. **`fromWadCeil`:** exact-out native `amountIn` after WAD fee gross-up. `toWad` always floor. Previews **bit-exact** match execution (Q37) |
| D65 | Pool-init product scope (Q31) | Hook only gates **pools that use this instance**. Validate bound pair + `DYNAMIC_FEE_FLAG`. **Do not** enforce single PoolKey per pair. **Do not** track or restrict same-token pools with `hooks != this` |
| D66 | Preview fidelity (Q37) | Same as D27 — **bit-exact**; supersedes any prior “±1 wei denorm” wording |
| D67 | Partial-book seed-only (Q38) | When any reserve is 0: `addLiquidity` may seed zero legs with **all** positive-leg maxes = 0 (\(P = \emptyset\)); shares from D72 only |
| D68 | Full-book add law (Q39) | When all three reserves &gt; 0: **only** three-leg proportional D24; one-/two-sided maxes **revert** |
| D69 | No on-hook zap (Q40) | No `depositSingle` / internal rebalance-then-mint in v1 |
| D70 | LP remove + permit (Q41) | Remove burns **`msg.sender`** only; LP has **EIP-2612 `permit`** for approvals/transfers (not a separate remove path) |
| D71 | Oracle call shape (Q42) | Always invoke **per-address** `dexSwapFeeOfVault(this)` / `usageFeeOfVault(this)` / `feeTo()`; oracle implements default fallback when override unset |
| D73 | Partial prop min set (Q43) | \(P = \{i : r_i > 0 \land a_iMax > 0\}\) only — zero-max positive legs ignored for min and pull |
| D74 | Residual sumPos invariant (Q45) | `totalSupply > 0` ⇒ `Σ toWad(r_i) > 0` always (D25a); no divide-by-zero re-seed path |
| D75 | addLiquidity return (Q46) | Returns `(uint256 shares, uint256 a0, uint256 a1, uint256 a2)` native used in binding order |
| D76 | Permit2 packing SoT (Q47) | **§5.6** of this PRD is normative; dual §7.3 is non-normative peer |
| D77 | Robinhood fork ID (Q48) | Robinhood Chain mainnet = **chain ID 4663** (same as dual D64/D74) |
| D47 | Impl plan follow-on | `UNISWAP_V4_ORBITAL_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` |

### 3.1 Implementor edges O1–O9 — **LOCKED** (2026-08-03; O1/O4 **revised by Q3**)

| ID | Topic | Locked value |
|----|--------|--------------|
| O1 | Fee encoding | **REVISED (Q3):** live **WAD** via **`dexSwapFeeOfVault(address(this))`**. **Not** immutable pips. |
| O2 | First-mint shares | **`require sumWad > MINIMUM_LIQUIDITY`**; **`shares = sumWad − MINIMUM_LIQUIDITY`** (Q33) |
| O3 | Radius \(R\) | First liquidity only; \(R = \max \times 10\); set-once |
| O4 | Exact-out gross-up | **REVISED:** WAD form `* 1e18 / (1e18 − feeWad) + 1` (D20a) |
| O5 | LP name/symbol | Auto `ORB-{s0}-{s1}-{s2}` + fallback |
| O6 | Pool subset | Any initialized pair enough |
| O7 | Live swaps | Both trade-leg reserves &gt; 0 **before and after** (Q27); witness may be 0; first mint ≥2 legs |
| O8 | LP slippage | sharesMin on add; amount mins on remove |
| O9 | Access control | Fully permissionless instance |

### 3.2 Clarification lock Q1–Q9 — **LOCKED** (2026-08-03)

| ID | Topic | Locked value |
|----|--------|--------------|
| Q1 | Token types + pulls | **Standard + USDT-style** SafeERC20. **Permit2** for LP token pulls (sig and/or allowance). FoT/rebasing **unsupported**. |
| Q2 | Decimals | **Any `uint8`** with toWad/fromWad (incl. >18 via truncating division). **`toWad` always floor**; **`fromWadFloor` / `fromWadCeil` per Q32** (not “both floor”). **All internal math in WAD** (Q30). |
| Q3 | Trading fee source | **`dexSwapFeeOfVault(this)`** WAD; 0 allowed; **&lt; 1e18**. **Protocol growth** separately uses **`usageFeeOfVault(this)`** → `feeTo` (D51–D59; v1.4). |
| Q4 | \(R\) multiplier | **Keep 10** |
| Q5 | Zero-leg seed | **REVISED (Q44):** seed used amounts per D24a; **share mint = sphere-NAV (D72)** — **not** sum-of-positive-reserves. **Seed-only allowed** when partial (Q38) |
| Q6 | Post full exit | Dead shares lock dust; **\(R\) permanent**; no re-first-mint |
| Q7 | Uni V4 fee field | **`DYNAMIC_FEE_FLAG`**. Oracle is SoT; fee may change without re-init. Hook returns V4 fee override from current WAD with **`OVERRIDE_FEE_FLAG`** (D20b). **Do not** freeze pips into PoolKey. |
| Q8 | LP deadline | **`deadline` required** on addLiquidity and removeLiquidity (`block.timestamp <= deadline`) |
| Q9 | Test DoD | Hermetic required; forks expanded by **Q16** / **Q23** |

### 3.3 Clarification lock Q10–Q18 — **LOCKED** (2026-08-03)

| ID | Topic | Locked value |
|----|--------|--------------|
| Q10 | Oracle resolution | **Always pull per-address** `dexSwapFeeOfVault(this)` on **each swap** and `usageFeeOfVault(this)` (+ `feeTo`) on **each liquidity deposit/withdraw** (and matching previews) (**Q42**). No VaultRegistry registration required for deploy. **Oracle-internal** cascade/defaults apply when per-address override is unset (type-level fees only if something external registered a type — **not** required for this package). |
| Q11 | Partial-book `kLast` | **Sum-based interim \(k\)** when any leg is 0; **mint protocol fee** on that measure when fee-on and same mode. Full book uses triple product + cbrt. Cross-mode: no mint from incompatible `kLast`; snapshot new mode post-op. Re-seed can mint on sum growth then switch to product `kLast`. |
| Q12 | feeTo exit | **Permissionless `removeLiquidity`** for any LP holder including `feeTo` (burns that holder’s **`msg.sender`** balance — Q41) |
| Q13 | First mint legs | **Keep ≥2** positive legs (O7 unchanged) |
| Q14 | Donations | **Ignore forever** (D36) |
| Q15 | tickSpacing | **No product validation** — any valid spacing |
| Q16 | Fork DoD | **Ethereum + Base + Robinhood Chain (4663)** mainnet forks **all required** (Q48) |
| Q17 | Events | **`LiquidityAdded`, `LiquidityRemoved`, `Swap`** required; **`ProtocolFeeMinted` when protocol mint &gt; 0** (field lists §5.5 / D60) |
| Q18 | Tiny usage fee floor | **`ownerFeeShare == 0` ⇒ fee-off** (no protocol mint) |

### 3.4 Clarity lock Q19–Q23 — **LOCKED** (2026-08-03; plan-ready)

| ID | Topic | Locked value |
|----|--------|--------------|
| Q19 | Exact-out + proportional + fee override + V4 oracle fees | **Exact-out gross-up = WAD only** (delete pips form). **Later mint = classic Uni V2 min-ratio in WAD** (D24 / Q29). **Fee override = informational / router UX + `OVERRIDE_FEE_FLAG`; residual SoT on hook; no double-haircut** (D20b/D20c). **Live oracle trading fees via `DYNAMIC_FEE_FLAG` are in-scope v1** — V4 supports per-swap override from `beforeSwap` |
| Q20 | Protocol mint algebra | **Same ConstProdUtils-generic Uni V2 formula for both modes**; only `rootK` changes (cbrt vs sum). Worked SumInterim example in §4.4.1 |
| Q21 | Surface: mode view, events, settle | **`kLastMode()` required public view.** **Normative event field lists** (§5.5). **Short §4.6 settle law + dual/single buffer Target peer pointer** |
| Q22 | Permit2 packing | **Empty `permit2Data` ⇒ SafeERC20 transferFrom only; non-empty ⇒ Permit2.** **Normative packing = this PRD §5.6** (Q47); dual §7.3 peer reference only |
| Q23 | Fork tokens | **Any ERC-20s OK on forks** — live production tokens **or deploy mintable/test tokens**. Goal = integrate with **production PM / Permit2 / fee oracle / hook bytecode**, not a specific stable set |

### 3.5 Clarity lock Q24–Q30 — **LOCKED** (2026-08-03; plan-ready)

| ID | Topic | Locked value |
|----|--------|--------------|
| Q24 | LP ERC-20 **metadata** decimals | **Always `18`** on the LP token (`decimals()`), independent of leg token decimals (dual O10 peer). `MINIMUM_LIQUIDITY = 1000` is LP wei. **Not** the same as leg balance scaling (see Q30) |
| Q25 | V4 `sqrtPriceX96` / `tickSpacing` | **PoolManager plumbing only** — ignored for product mid/depth. Product price = hook sphere + previews. Hermetic convention: **tickSpacing = 60**, **1:1 mid** (`getSqrtPriceAtTick(0)`). Integrators: any valid init. `beforeInitialize` does **not** enforce sqrtPrice/spacing (only pair ⊂ bound + `DYNAMIC_FEE_FLAG`) |
| Q26 | \(L^2\) semantics | **Stored sphere parameter**, recomputed after every successful state change. With trading residual, post-swap state is **not** on the pre-swap sphere; next trade uses new \(L^2\). Do **not** document \(L^2\) as a fee-conserved invariant |
| Q27 | Full leg drain on swap | **Forbidden.** Pre- and post-swap, both trade-leg Repo reserves **must be &gt; 0**. Exact-in requires **`0 < y' < y`** (1e18 domain). Revert trades that would set raw `reserves[tokenOut] == 0`. Witness may still be 0 (seed path elsewhere) |
| Q28 | LP vs pool init | **Independent.** Custom LP works with zero pools initialized. Swaps need \(R > 0\) + initialized pair pool + both leg reserves &gt; 0. Init does not require liquidity |
| Q29 | Mint / remove share math units | **Uniform 1e18.** First mint: sum of WAD deposits − MINIMUM (O2). Later mint: Uni V2 min-ratio **on WAD reserves / WAD maxes** (D24) — **not** raw token units. Seed (D24a) and remove (D25) also WAD-internal. **Revised from v1.7** “raw later mint” |
| Q30 | Decimal boundary law | **Internal SoT for math = 1e18.** Scale **in** with `toWad` before sphere / fee / LP formulas; scale **out** with `fromWadFloor` / `fromWadCeil` (Q32) only when transferring / settling. Repo stores **raw** reserves. Events `amount0/1/2` and swap `amountIn/Out` are **native** units. LP share amounts are already 18-decimal LP wei |

### 3.6 Clarity lock Q31–Q36 — **LOCKED** (2026-08-03; plan-ready)

| ID | Topic | Locked value |
|----|--------|--------------|
| Q31 | Pool init scope | **Only** restrict pools that configure **`hooks = this`**. `beforeInitialize`: bound pair + `DYNAMIC_FEE_FLAG` (+ PM plumbing free). **No** at-most-one-PoolKey-per-pair rule. **No** concern for other same-token pools that do **not** use this hook. Multiple tickSpacings for the same pair **on this hook** share reserves and are **allowed** |
| Q32 | Denorm ceil/floor | **Ceil** exact-out native `amountIn`; **floor** exact-in native `amountOut` (and LP pull/pay floors). Previews **bit-exact** with execution (Q37) |
| Q33 | First mint vs MIN | **`sum(a_iWad) > MINIMUM_LIQUIDITY`** required; else revert (no underflow / zero user shares) |
| Q34 | Reentrancy | **Single global lock** on LP add/remove **and** swap (`beforeSwap` path) |
| Q35 | Zero native used after fromWad | **Revert** if a required positive-leg `used_i == 0` after floor denorm (later mint / seed proportional legs). Full book: all three legs required (Q39) |
| Q36 | Permit2 vs transferFrom | Empty `permit2Data` ⇒ all pulls `transferFrom`. Non-empty ⇒ **all** pulled legs Permit2 only — **no mixed** path in one `addLiquidity` |

### 3.7 Clarity lock Q37–Q42 — **LOCKED** (2026-08-03; v1.10 plan-ready)

| ID | Topic | Locked value |
|----|--------|--------------|
| Q37 | Preview fidelity | **Bit-exact** `previewAddLiquidity` / `previewRemoveLiquidity` / `previewSwapExactIn` / `previewSwapExactOut` vs execution at the **same** oracle reads and **same** ceil/floor denorm path. **Supersedes** any “±1 wei denorm only” wording (D27 / D66). |
| Q38 | Partial-book seed-only | When **any** reserve is 0: user may set **all** positive-leg `a_iMax = 0` and only seed zero legs (\(P = \emptyset\)); **shares from D72 sphere-NAV**; require `shares > 0` and ≥ `sharesMin`. Combined seed + proportional still allowed when positive maxes are set (D24a). |
| Q39 | Full-book three-leg only | When **all three** reserves &gt; 0: **only** classic Uni V2 min-ratio over **all three** legs (D24). One- or two-sided `a_iMax` patterns **revert** (zero used / zero shares). **Not** a zap surface. |
| Q40 | No on-hook zap v1 | **No** `depositSingle`, **no** internal sphere rebalance-then-proportional-mint. Fair single-asset zap = **§10 future**. Closed-form swap solvers non-goal (#6) remains; no zap solver carve-out. |
| Q41 | Remove + LP permit | **`removeLiquidity` burns only `msg.sender`’s LP balance** (no allowance/`burnFrom`). Payout to `to`. LP token **must** implement **EIP-2612 `permit`** for approvals/transfers (router UX); permit is **not** a separate remove entrypoint. Inventory pulls still use Permit2/`transferFrom` (Q22/Q36) — unrelated to LP permit. |
| Q42 | Oracle query shape | Product code **always** calls per-address `dexSwapFeeOfVault(address(this))`, `usageFeeOfVault(address(this))`, and `feeTo()` (as applicable). Vault Fee Oracle **owns** fallback to defaults when per-address override is unset. No registry registration required for hook deploy. |

### 3.8 Clarity lock Q43–Q48 — **LOCKED** (2026-08-03; v1.11 plan-ready)

| ID | Topic | Locked value |
|----|--------|--------------|
| Q43 | Partial prop min set | Min-ratio only over **positive-reserve legs with `a_iMax > 0`** (\(P\)). Zero-max positive legs are skipped (not pulled, not in min). |
| Q44 | Sphere-NAV seed / partial shares | **Supersedes sum-NAV** `amount * supply / sumPos`. Partial-book **user shares** = **`supply' * V_in / V_before`** with pre-op \(p_i = R - r_i^{18}\), \(V = \sum p_i r_i^{18}\), \(V_{\mathrm{in}} = \sum p_i \cdot \mathrm{used}_i^{18}\) (D72). Worked example §4.5.1. |
| Q45 | Residual sumPos | Whenever `totalSupply > 0`, **`Σ toWad(r_i) > 0`** (dead MIN residual dust). **No** `sumPos == 0` re-seed branch; tests assert after full user exit. |
| Q46 | addLiquidity returns | **`(shares, a0, a1, a2)`** — native used amounts in binding order (symmetry with remove). |
| Q47 | Permit2 packing SoT | **§5.6 of this PRD is normative** (Signature batch + Allowance modes; binding-order pulled legs). Dual §7.3 is peer reference only. |
| Q48 | Robinhood chain ID | Fork DoD **Robinhood Chain mainnet = 4663** (dual D64/D74 peer). |

---

## 4. Architecture

### 4.1 Stack

```text
┌──────────────────────────────────────────────────────────────────┐
│ User / Router                                                    │
│   • addLiquidity / removeLiquidity on Hook                       │
│   • swapExact* via V4 on any pair pool                           │
└───────────────┬─────────────────────────────┬────────────────────┘
                │                             │
                ▼                             ▼
┌───────────────────────────┐   ┌──────────────────────────────────┐
│ UniswapV4OrbitalSwapHook  │   │ Uniswap V4 PoolManager           │
│  reserves x,y,z + L² + R  │◄──│  Pool AB / BC / AC               │
│  L² = stored sphere param │   │  fee = DYNAMIC_FEE_FLAG          │
│  feeOracle:               │   │  sqrtPrice/tickSpacing plumbing  │
│   dexSwapFee = trade WAD  │   │  hooks = same Orbital instance   │
│   usageFee → feeTo LP mint│   │  beforeSwap + ReturnDelta        │
│  kLast + kLastMode + LP18 │   │  fee override | OVERRIDE bit     │
│  Math: sphere + cbrt fee  │   │                                  │
└───────────────────────────┘   └──────────────────────────────────┘
```

### 4.2 Virtual multi-pool (“three doors, one room”)

Uniswap V4 pools are **strictly 2-currency**. Orbital multi-asset state lives **only** on the hook:

```text
Pool USDC/USDT  ──┐
Pool USDT/DAI   ──┼──► same UniswapV4OrbitalSwapHook (shared reserves + L²)
Pool USDC/DAI   ──┘
```

A USDC→DAI swap still uses **USDT reserve as witness** in \(L^2\), so idle third-asset capital supports every pair (capital efficiency thesis). When witness reserve is 0, \((R-z)^2 = R^2\) still participates in the formula (O7); capital-efficiency thesis is weaker until that leg is seeded.

### 4.3 Sphere pricing (normative math)

With \(x,y,z\) in **1e18 units** and **set-once** \(R\) (D15). \(L^2\) is the **stored sphere parameter** for the **current** reserves (Q26 / D16) — recomputed after each successful LP/swap; **not** a fee-conserved invariant:

\[
L^2 = (R-x)^2 + (R-y)^2 + (R-z)^2
\]

Witness \(z\) **may be 0** (O7); then \((R-z)^2 = R^2\).

**Decimal boundary (Q30 / Q32):** \(x,y,z,\Delta\) below are **1e18**. User / PoolManager amounts are **native** — `toWad` (floor) in; `fromWadFloor` / `fromWadCeil` out for settle/transfer.

**Exact-in** (native `amountIn` → WAD fee net → solve \(\Delta y\) → native `amountOut`):

\[
\begin{aligned}
\Delta x &= \mathrm{toWad}(\texttt{amountIn}) \\
\Delta x_{\text{net}} &= \Delta x - \left\lfloor \Delta x \cdot f_{\text{WAD}} / 10^{18} \right\rfloor \\
x' &= x + \Delta x_{\text{net}} \\
T &= L^2 - (R-x')^2 - (R-z)^2 \\
y' &= R - \sqrt{T} \\
\Delta y &= y - y' \\
\texttt{amountOut} &= \mathrm{fromWadFloor}(\Delta y)
\end{aligned}
\]

**Exact-out** (native `amountOut` → WAD solve \(\Delta x_{\text{net}}\) → **WAD** gross-up fee per D20a / O4 → native `amountIn`):

\[
\begin{aligned}
\Delta y &= \mathrm{toWad}(\texttt{amountOut}) \\
y' &= y - \Delta y \\
T &= L^2 - (R-y')^2 - (R-z)^2 \\
x' &= R - \sqrt{T} \\
\Delta x_{\text{net}} &= x' - x \\
\Delta x &=
\begin{cases}
\Delta x_{\text{net}} & \text{if } f_{\text{WAD}} = 0 \\
\left\lfloor \Delta x_{\text{net}} \cdot 10^{18} / (10^{18} - f_{\text{WAD}}) \right\rfloor + 1 & \text{if } f_{\text{WAD}} > 0
\end{cases} \\
\texttt{amountIn} &= \mathrm{fromWadCeil}(\Delta x)
\end{aligned}
\]

Repo updates use **native** gross in / out, then recompute \(L^2\) from `toWad(reserves[*])` (Q26).

**Domain / branch constraints (must revert if violated):**

- \(R > 0\) (first mint has run)  
- \(0 \le x,y,z < R\) (strict upper bound) before and after in 1e18 units  
- For swaps: raw `reserves[tokenIn] > 0` and `reserves[tokenOut] > 0` **before and after** (O7 / Q27 / D63)  
- \(T\) under the sqrt is non-negative  
- Interior branch only: exact-in requires **\(0 < y' < y\)** and \(\Delta y > 0\); exact-out requires \(x' > x\), \(\Delta x_{\text{net}} > 0\), post raw out &gt; 0  
- v1 does **not** support exterior sphere branches  
- Native `amountOut` ≤ available raw reserve **and** leaves residual out &gt; 0  

**Denorm (Q32 / D64):** exact-in out = **floor**; exact-out in = **ceil** (after WAD `+1` when fee &gt; 0). Preview == execution **bit-exact** (D27 / Q37).

### 4.3.1 Setting \(R\) (O3 — normative)

```text
// Only on first successful addLiquidity (totalSupply == 0 before mint):
a0Wad, a1Wad, a2Wad = toWad(used amounts)
m = max(a0Wad, a1Wad, a2Wad)
require m > 0
R = m * R_SAFETY_MULTIPLIER   // R_SAFETY_MULTIPLIER = 10 (package constant)
// imply R > m so first reserves sit at most at 10% of radius capacity on the max leg
store R in Repo (set-once; no setter)
then L² = (R-a0Wad)² + (R-a1Wad)² + (R-a2Wad)²
```

**Later adds / swaps:** if any post-state 1e18 reserve would be **≥ \(R\)**, revert (`ReservesExceedRadius`). \(R\) does **not** grow.

### 4.4 Fee law (v1) — two oracle channels

This product uses **two independent** Vault Fee Oracle fields (do not conflate):

| Channel | Oracle API | When | Destination |
|---------|------------|------|-------------|
| **Trading fee** | `dexSwapFeeOfVault(this)` WAD | Every **swap** | Residual **in reserves** (LPs) — **hook-applied** |
| **Protocol growth fee** | `usageFeeOfVault(this)` WAD | Every **add/remove liquidity** | **Mint LP → `feeTo`** |

#### 4.4.0 Trading fee (Q3 / D20 / Q19)

Uniswap V4 **supports** live oracle-driven trading fees:

1. Pool init with `PoolKey.fee = DYNAMIC_FEE_FLAG`.  
2. Each `beforeSwap` returns pips with **`OVERRIDE_FEE_FLAG`** so PoolManager / routers see the current rate.  
3. Hook **also** applies residual in WAD on inventory accounting (custom curve SoT).

```text
feeOracle   = IVaultFeeOracleQuery (immutable)
tradeFeeWad = feeOracle.dexSwapFeeOfVault(address(this))   // live each swap
require tradeFeeWad < 1e18

// Q30: all sphere + fee algebra in 1e18; native only for reserve update / settle
Exact-in (native amountIn from PM):
  dxWad = toWad(amountIn)
  feeWad = dxWad * tradeFeeWad / 1e18          // floor
  dxNetWad = dxWad - feeWad
  dyWad = sphereExactIn(..., dxNetWad)         // 1e18 domain
  amountOut = fromWadFloor(dyWad)              // Q32 — user receives floor
  require amountOut > 0 and reserves[out] - amountOut > 0  // Q27 / D63
  reserves[in]  += amountIn            // full native gross — residual stays in pool (D21)
  reserves[out] -= amountOut
  recompute L² from toWad(post reserves) (Q26 — not fee-conserved)
  // do NOT mint protocol LP or update kLast here (D57)
  return beforeSwap fee override =
      uint24(tradeFeeWad * 1e6 / 1e18) | OVERRIDE_FEE_FLAG   // D20b

Exact-out (D20a — WAD fee gross-up; native amountOut target):
  require amountOut < reserves[out]   // leave residual > 0 (Q27)
  dyWad = toWad(amountOut)
  dxNetWad = sphereExactOut(..., dyWad)
  dxWad = tradeFeeWad == 0 ? dxNetWad
        : dxNetWad * 1e18 / (1e18 - tradeFeeWad) + 1
  amountIn = fromWadCeil(dxWad)       // Q32 — user pays ceil
  reserves[in]  += amountIn; reserves[out] -= amountOut
  recompute L² from toWad(post reserves) (Q26)
  return same fee override as exact-in
```

**No double-haircut (D20c):** economic fee is the hook residual path. Override must not cause a second reduction of the user’s amountIn on top of D20.

**Why DYNAMIC_FEE_FLAG (Q7):** PoolKey.fee is fixed at initialize; trading rate is mutable via oracle. Dynamic flag + per-swap override keep routers honest without re-init.

#### 4.4.1 Protocol growth fee — Uni V2–style (D51–D59 / Q20)

Peer: dual SE buffer CP **D57** + Crane `ConstProdUtils._calculateProtocolFee` (generic `ownerFeeShare` branch), adapted to **three** assets and dual-mode `rootK`.

```text
// Live oracle pulls every LP op (Q10):
usageFeeWad   = feeOracle.usageFeeOfVault(address(this))
feeTo         = address(feeOracle.feeTo())
ownerFeeShare = usageFeeWad * 100_000 / 1e18          // floor
feeOn = feeTo != 0 && usageFeeWad != 0 && usageFeeWad < 1e18 && ownerFeeShare != 0  // D54 / Q18

// Dual-mode size measure (Q11 / D55):
if all three reserves > 0:
  mode = FullProduct;  k = xWad * yWad * zWad;  rootK = cbrt(k)
else:
  mode = SumInterim;   k = xWad + yWad + zWad;  rootK = k   // linear interim

// Protocol LP (D56) — same algebra both modes:
// if !feeOn or kLast == 0 or mode != kLastMode or rootK <= rootKLast: protocolLp = 0
// else:
//   protocolLp = totalSupply * (rootK - rootKLast)
//                / (rootK * 100_000 / ownerFeeShare + rootK - rootKLast)
// cross-mode: no mint; after op set kLast/kLastMode to post state when feeOn

addLiquidity (subsequent / re-seed):
  1. compute mode + k_pre / rootK_pre from current reserves
  2. if feeOn && same mode && kLast != 0: mint protocolLp to feeTo
  3. pull used amounts; update reserves; mint user shares (post-protocol supply)
  4. if feeOn: kLast = k_post, kLastMode = mode_post; else kLast = 0

removeLiquidity: same mint-then-burn pattern; update kLast/mode post-op

first mint (≥2 legs — Q13/O7):
  no protocol mint; set kLast/mode from post reserves if feeOn
  (partial first mint ⇒ SumInterim mode; all-three ⇒ FullProduct)

swaps:
  may change reserves/k but do not mint or update kLast;
  next LP op realizes protocol share of growth
```

**Worked SumInterim example (informative, Q20):**

```text
// Partial book: z = 0; xWad = 100e18; yWad = 100e18; zWad = 0
// mode = SumInterim; k = 200e18; rootK = 200e18
// kLast = 180e18 (same mode); totalSupply = 1000e18; ownerFeeShare = 5000 (5% WAD → 5e16)
// rootK - rootKLast = 20e18
// protocolLp = 1000e18 * 20e18 / (200e18 * 100_000 / 5000 + 20e18)
//            = 1000e18 * 20e18 / (4000e18 + 20e18)
//            ≈ 4.975e18 LP minted to feeTo before user mint/burn
```

**Why growth mint (not a second swap haircut):** Uni V2 / dual buffer peer — protocol earns LP via dilution on growth.

**Ops:** Prefer setting **per-address** `dexSwapFeeOfVault[hook]` and `usageFeeOfVault[hook]` (Q10). Cascade defaults still apply if unset. `feeTo` must hold ERC-20 LP; exit via normal `removeLiquidity` (Q12).

### 4.5 Liquidity (proportional 3-asset)

**Uniform WAD math (Q29 / Q30):** all share and ratio formulas use **1e18-normalized** leg amounts. **Native** units appear only when pulling/paying tokens (`fromWad` / user maxes / event amounts). LP ERC-20 **metadata decimals always 18** (Q24) — same numeric domain as WAD share wei, but that is LP metadata, not “scale each leg to match LP.”

**Branch selector (v1 — no zap):**

| State | Path |
|-------|------|
| `totalSupply == 0` | **First mint** (O2 / D23) — ≥2 positive legs; sumWad − MIN |
| All three `r_i > 0` | **Full-book later** (D24 / Q39) — three-leg Uni V2 min-ratio only |
| Some `r_j == 0` (and supply &gt; 0) | **Partial** (D24a / D72 / Q38 / Q43–Q44) — used amounts then **sphere-NAV shares**; seed-only OK |
| Single-asset when full book | **Revert** — not zap (Q40); rebalance off-hook then three-leg add |

```text
First mint (totalSupply == 0) — WAD sum (O2 / Q33):
  require deadline; count(amount_iMax > 0) >= 2
  used_i = amount_iMax                         // native pull (full max on first)
  a_iWad = toWad(used_i)
  require sum(a_iWad) > MINIMUM_LIQUIDITY      // else revert — no underflow
  shares = sum(a_iWad) - MINIMUM_LIQUIDITY     // MINIMUM = 1000 LP wei; shares > 0
  require shares >= sharesMin
  R = max(a_iWad) * 10
  pull native used_i via transferFrom XOR Permit2 (§5.6 / Q22 / Q36)
  mint dead 1000 to address(0)  // Uni V2 peer — balance on address(0); D46
  reserves[i] = used_i (raw)
  recompute L² from toWad(reserves); mint user shares to `to`
  if feeOn:
    if all three reserves > 0: kLast = xWad*yWad*zWad; kLastMode = FullProduct
    else: kLast = xWad+yWad+zWad; kLastMode = SumInterim
  else: kLast = 0
  // no protocol mint on first (D57)
  // does NOT require any V4 pool initialize (Q28)
  return (shares, used0, used1, used2)  // Q46

Later mint (all r_i > 0) — three-leg Uni V2 min-ratio in WAD (D24 / Q39 / Q19 / Q29 / Q30):
  require deadline
  // 1) protocol growth mint to feeTo from k_pre vs kLast (D57); emit ProtocolFeeMinted if > 0
  // 2) supply' = totalSupply after protocol mint
  r_iWad = toWad(r_i); a_iMaxWad = toWad(a_iMax)
  shares = min(a0MaxWad * supply' / r0Wad, a1MaxWad * supply' / r1Wad, a2MaxWad * supply' / r2Wad)
  require shares > 0 && shares >= sharesMin
  used_iWad = shares * r_iWad / supply'      // floor
  used_i = fromWadFloor(used_iWad)           // native pull; do NOT pull unused max
  require used_i > 0 for ALL three legs      // Q35 + Q39 — one/two-sided reverts
  require post toWad(reserves + used) < R
  pull used_i; reserves += used_i; recompute L²; mint user shares to `to`
  kLast = feeOn ? k_post : 0; kLastMode = mode_post if feeOn
  // NO depositSingle / internal zap (Q40)
  return (shares, used0, used1, used2)

Later mint (some r_j == 0) — partial book (D24a / D72 / Q43 / Q44 / Q38) + SumInterim growth (Q11):
  // Partial books: partial first mint (≥2 legs), and/or floor dust on remove (pro-rata can
  // zero a tiny leg). Swaps must NOT zero a trade leg (Q27). Seed re-seeds zero legs.
  // Invariant Q45: sumPosWad = Σ toWad(r_i) > 0 whenever totalSupply > 0.
  require deadline
  // 1) protocol mint on SumInterim k_pre vs kLast when fee-on and same mode; emit if > 0
  // 2) supply' = totalSupply after protocol mint
  // 3) Determine USED amounts (not shares yet):
  P = { i | r_i > 0 && a_iMax > 0 }     // Q43 — only maxed positive legs
  Z = { j | r_j == 0 && a_jMax > 0 }     // seed candidates
  require P ∪ Z ≠ ∅
  if P ≠ ∅:
    sTmp = min_{i in P}(a_iMaxWad * supply' / r_iWad)
    for i in P:
      used_iWad = sTmp * r_iWad / supply'   // floor
      used_i = fromWadFloor(used_iWad)
      require used_i > 0                    // Q35
    for i with r_i > 0 && a_iMax == 0:
      used_i = 0                            // skipped — not in min
  else:
    used_i = 0 for all positive-reserve legs  // seed-only Q38
  for j in Z:
    used_j = a_jMax                         // full native max seed pull
  for j with r_j == 0 && a_jMax == 0:
    used_j = 0
  // 4) Sphere-NAV shares (D72 / Q44) — pre-op prices; NOT sum-NAV; NOT sharesProp+sharesSeed
  //    p_i = R - toWad(r_i)   // zero leg ⇒ p = R; require r_iWad < R for all i
  //    V_before = Σ p_i * toWad(r_i)     // > 0 by Q45
  //    V_in     = Σ p_i * toWad(used_i)  // pre prices
  //    shares   = supply' * V_in / V_before   // floor
  require shares > 0 && shares >= sharesMin
  require post toWad(reserves + used) < R for every leg
  pull native (transferFrom XOR Permit2 §5.6); update raw reserves; recompute L²
  mint user shares to `to`
  kLast/mode = post-op measure (SumInterim or FullProduct if seed completed all three)
  return (shares, used0, used1, used2)

Remove (Q41):
  require deadline
  // burns msg.sender only — no burnFrom / LP Permit2 path
  // 1) protocol growth mint to feeTo (D57); emit ProtocolFeeMinted if > 0
  // 2) amount_iWad = userShares * toWad(r_i) / totalSupply' (post protocol mint)
  //    amount_i = fromWadFloor(amount_iWad)   // native pay to `to`
  require amount_i >= a_iMin
  burn msg.sender shares; transfer native to `to`; recompute L²
  kLast = feeOn ? k_post : 0
  // if only MINIMUM_LIQUIDITY left: dust locked; R unchanged (Q6);
  //    assert Σ toWad(r_i) > 0 (Q45)
```

#### 4.5.1 Sphere-NAV partial mint (normative — D72 / Q44)

Sphere marginal price ratios from §4.3: holding the third reserve fixed,
\[
\frac{\mathrm{d}y}{\mathrm{d}x} = -\frac{R-x}{R-y}
\quad\Rightarrow\quad
p_i \propto (R - r_i^{18}).
\]

**Pre-op weights (1e18 domain):** \(p_i = R - \mathrm{toWad}(r_i)\). For a zero leg, \(p_j = R\). Require \(p_i > 0\) for all \(i\) (already implied by \(r_i^{18} < R\)).

| Quantity | Formula |
|----------|---------|
| Pool value (relative) | \(V_{\mathrm{before}} = \sum_i p_i \cdot \mathrm{toWad}(r_i)\) |
| Deposit value (pre prices) | \(V_{\mathrm{in}} = \sum_i p_i \cdot \mathrm{toWad}(\texttt{used}_i)\) |
| User LP minted | \(\texttt{shares} = \left\lfloor \texttt{supply'} \cdot V_{\mathrm{in}} / V_{\mathrm{before}} \right\rfloor\) |

**Why not sum-NAV:** \(\sum r_i\) prices every WAD of inventory at 1 regardless of sphere imbalance. Seeding a scarce (zero) leg or topping an unbalanced book would systematically dilute or enrich existing LPs vs sphere spots. **D72 is the v1 fairness law** for all partial-book user mints (seed-only, prop-only on a subset of live legs, or combined).

**Consistency check (informative):** If \(P\) is **all** positive-reserve legs, used amounts are reserve-proportional with factor \(\alpha = s_{\mathrm{tmp}}/\texttt{supply'}\), and \(Z = \emptyset\), then \(V_{\mathrm{in}} = \alpha V_{\mathrm{before}}\) and \(\texttt{shares} = \alpha \cdot \texttt{supply'} = s_{\mathrm{tmp}}\) — recovers classic Uni V2 prop mint.

**Worked seed-only example (informative):**

```text
// Partial: r0Wad = 100e18, r1Wad = 100e18, r2Wad = 0; R = 1000e18; supply' = 1000e18
// p0 = p1 = 900e18; p2 = 1000e18
// V_before = 900e18*100e18 + 900e18*100e18 + 1000e18*0 = 180_000e36
// Seed-only: used0 = used1 = 0; used2Wad = 50e18
// V_in = 1000e18 * 50e18 = 50_000e36
// shares = 1000e18 * 50_000e36 / 180_000e36 = 1000e18 * 5/18 ≈ 277.777…e18 (floor)
// (Sum-NAV would have been 50e18 * 1000e18 / 200e18 = 250e18 — lower; sphere prices the
//  scarce leg higher, so seeder receives more LP for the same WAD of token2.)
```

**Multi-zero seed:** when two legs are zero, \(V_{\mathrm{in}} = R \cdot (\Delta_a^{18} + \Delta_b^{18})\) at pre prices; still one unified `shares` (not independent per-leg sum-NAV mints).

### 4.6 Swap settle / BeforeSwapDelta (normative short law — Q21)

**Model:** custom curve / **NoOp-style** accounting. Hook-held reserves are the counterparty. Pattern-copy settle order from **single buffer** and **dual buffer** Targets (take / sync / transfer / settle); **do not** inherit Crane `BaseHook` / `DeltaResolver`.

| Law | Value |
|-----|--------|
| Entry | Only `msg.sender == poolManager` on hook callbacks |
| Permissions | `beforeInitialize`, `beforeAddLiquidity` (revert), `beforeRemoveLiquidity` (revert), `beforeSwap`, `beforeSwapReturnDelta` |
| Curve | Price from §4.3 sphere on Repo reserves; **not** PoolManager CL / `slot0` / `sqrtPriceX96` (Q25) |
| Specified amount | Hook consumes full specified amount via `BeforeSwapDelta` for the trade (custom curve) so CL path is a no-op for inventory |
| Exact-in | User pays `amountIn` (gross); out = **fromWadFloor**; **post out reserve &gt; 0** (Q27); deltas match take/settle |
| Exact-out | User receives `amountOut` **&lt; pre out reserve**; in = **fromWadCeil** after WAD gross-up (D20a / Q32); deltas match |
| Reentrancy | Global lock held for duration of LP and swap accounting (Q34) |
| Fee report | Return V4 override per D20b; economic residual per D20/D21/D20c |
| Directions | All **six** directed pairs among bound tokens must pass golden tests (tokenIn≠tokenOut; both bound) |
| Pairs | Pool currencies must be a bound pair; third token is witness only |
| Router | Integrators use standard V4 routers against any **initialized** pair pool; true quote = hook `previewSwap*` |
| Events | Emit `Swap` on successful swap path (same call that updates reserves); LP events on add/remove |

**Peer pointer (non-normative detail source):** dual buffer PRD §6 (swaps) + Target settle patterns; single buffer settle pattern-copy. This package has **no** SE buffer/unwrap legs — inventory is raw ERC-20 only.

---

## 5. Package surface (normative file plan)

```text
contracts/hooks/uniswap/v4/orbital/
  UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md                         # this file
  UNISWAP_V4_ORBITAL_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on

  interfaces/
    IUniswapV4OrbitalSwapHook.sol                            # views + previews + LP surface

  UniswapV4OrbitalSwapHookMath.sol                           # pure sphere + WAD + shares + sphere-NAV (D72) + cbrt growth fee
  UniswapV4OrbitalSwapHookRepo.sol                           # diamond-style storage slot layout
  UniswapV4OrbitalSwapHookCommon.sol                         # reserve helpers, decimal cache, guards
  UniswapV4OrbitalSwapHookTarget.sol                         # IHooks + LP execute (pattern-copy settle)
  UniswapV4OrbitalSwapHook.sol                               # single CREATE3-mined wire + ERC-20

  UniswapV4OrbitalSwapHook_FactoryService.sol                # mine + create3Factory deploy

  # FORBIDDEN for hook product:
  #   *Facet.sol, *DFPkg.sol, I*DFPkg.sol
  #   Solidity inheritance of BaseHook / BaseTokenWrapperHook / DeltaResolver
```

### 5.1 Interface sketch (informative → required names)

```solidity
interface IUniswapV4OrbitalSwapHook {
    enum KLastMode { FullProduct, SumInterim }

    function poolManager() external view returns (IPoolManager);
    function feeOracle() external view returns (IVaultFeeOracleQuery);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function token2() external view returns (address);
    function radius() external view returns (uint256);       // 0 until first mint
    function dexSwapFee() external view returns (uint256);   // trading WAD — dexSwapFeeOfVault
    function usageFee() external view returns (uint256);     // growth WAD — usageFeeOfVault
    function feeTo() external view returns (address);        // protocol LP recipient
    function kLast() external view returns (uint256);        // product or sum per mode
    function kLastMode() external view returns (KLastMode);  // Q21 / D59
    function lSquared() external view returns (uint256);
    function reserveOf(address token) external view returns (uint256);

    function previewAddLiquidity(uint256 a0Max, uint256 a1Max, uint256 a2Max)
        external view returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2);
    function previewRemoveLiquidity(uint256 shares)
        external view returns (uint256 a0, uint256 a1, uint256 a2);

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external view returns (uint256 amountOut);
    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external view returns (uint256 amountIn);

    /// @param permit2Data empty => SafeERC20 transferFrom only; non-empty => Permit2 (§5.6 packing)
    /// @return shares LP minted to `to` (after protocol mint dilution when fee-on)
    /// @return a0 used amount of token0 (binding order, native)
    /// @return a1 used amount of token1
    /// @return a2 used amount of token2
    function addLiquidity(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2);

    /// @dev Burns `shares` from msg.sender only (no burnFrom). Pays native legs to `to`.
    function removeLiquidity(
        uint256 shares,
        address to,
        uint256 a0Min,
        uint256 a1Min,
        uint256 a2Min,
        uint256 deadline
    ) external returns (uint256 a0, uint256 a1, uint256 a2);

    // Also on the same contract (ERC-20 + EIP-2612 — Q41):
    // name(), symbol(), decimals()==18, totalSupply, balanceOf, allowance,
    // transfer, approve, transferFrom, DOMAIN_SEPARATOR, permit, nonces
}
```

LP ERC-20 surface on the same contract. **decimals always 18 (Q24)**; **name/symbol auto at ctor (O5)**; **EIP-2612 `permit` required (Q41)**. Prefer Crane / Uni V2–style token helpers (D46 — mint `MINIMUM_LIQUIDITY` to `address(0)`). Previews **must** include protocol-mint dilution when fee-on (D58) and are **bit-exact** vs execution (Q37). `previewAddLiquidity` returns the same used-amount triple as execution (Q46). **No** `depositSingle` / zap entrypoint (Q40).

### 5.2 Deploy API (FactoryService)

```solidity
// Default namespace: "uv4-orbital-swap-hook-"
// R and swap fee are NOT deploy arguments
function deployHook(
    ICreate3FactoryProxy create3Factory,
    IPoolManager poolManager,
    IVaultFeeOracleQuery feeOracle,
    address token0,
    address token1,
    address token2,
    string memory saltNamespace  // empty → default
) internal returns (address hook);
```

**Ctor validation:** non-zero `poolManager`, `feeOracle`, tokens; pairwise distinct tokens; `Hooks.validateHookPermissions`; cache any `uint8` decimals (missing → 18) + LP metadata.

**Mine loop:** buffer peer; salt includes **feeOracle**; no \(R\) / no pips; internal `mineNonce` only.

**`isExpectedHook`:** `poolManager()`, `feeOracle()`, `token0/1/2()` match (factory-side helper OK; not required on user ABI).

### 5.3 Storage (Repo)

| Field | Purpose |
|-------|---------|
| `poolManager` | V4 singleton (**immutable**) |
| `feeOracle` | Vault Fee Oracle (**immutable**) |
| `token0/1/2` | Bound assets (**immutable**) |
| `decimals0/1/2` | Cached decimals (**immutable**) |
| `name` / `symbol` | LP metadata (ctor-set) |
| `R` | Sphere radius — **Repo set-once on first mint** |
| `reserves[token]` | Authoritative balances in **raw native** units (math uses `toWad` — Q30) |
| `L_SQUARED` | Stored sphere parameter \(L^2\) (Q26) — recomputed from `toWad(reserves)` after state changes |
| `kLast` | Growth-fee measure (product or sum per mode); 0 when fee-off |
| `kLastMode` | `FullProduct` \| `SumInterim` (Q11) — **public via `kLastMode()`** |
| reentrancy lock | **Global** — LP + swap (Q34) |

### 5.4 Hook permissions

| Permission | Enabled | Role |
|------------|---------|------|
| beforeInitialize | **Yes** | Validate pair ⊂ {t0,t1,t2}, **`fee == DYNAMIC_FEE_FLAG`**; **do not** validate `sqrtPriceX96` / `tickSpacing` (Q25); **do not** enforce one PoolKey per pair (Q31) |
| beforeAddLiquidity | **Yes** | Revert — custom LP only |
| beforeRemoveLiquidity | **Yes** | Revert — custom LP only |
| beforeSwap | **Yes** | Orbital pricing + **dynamic fee override** (`pips \| OVERRIDE_FEE_FLAG`) |
| beforeSwapReturnDelta | **Yes** | Custom accounting / NoOp curve (§4.6) |
| after* / donate | **No** (v1) |

Required flags must be mined into the CREATE3 address (buffer §8 peer).

### 5.5 Events (normative field lists — D60 / Q21)

```solidity
event LiquidityAdded(
    address indexed provider,
    address indexed to,
    uint256 shares,
    uint256 amount0,
    uint256 amount1,
    uint256 amount2
);

event LiquidityRemoved(
    address indexed provider,
    address indexed to,
    uint256 shares,
    uint256 amount0,
    uint256 amount1,
    uint256 amount2
);

event Swap(
    address indexed sender,
    address indexed tokenIn,
    address indexed tokenOut,
    uint256 amountIn,
    uint256 amountOut,
    uint256 feeWad
);

/// @dev Required whenever protocol growth mint > 0 (D60); omit when mint is 0
event ProtocolFeeMinted(address indexed feeTo, uint256 shares);
```

`amount0/1/2` are in **binding token order** (`token0/1/2`), **native** token units (not WAD). Swap `amountIn`/`amountOut` are native. `feeWad` is the trading fee **rate** WAD applied on that swap (0 if fee-off) — not a native fee amount.

### 5.6 Permit2 packing (normative DoD — Q22 / Q36 / Q47)

Canonical Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3` (D49).  
Interfaces: Crane `ISignatureTransfer` / `IAllowanceTransfer`.  
**No witness** in v1 (plain transfer-to-hook; spender = hook).  
Owner of tokens = **`msg.sender`**. Recipient of pulls = **`address(this)`** (hook).  
**Pulled legs** = every binding index \(i\) with `used_i > 0` after mint math (1–3 legs).  
**Binding order** for batch indices: ascending `token0` → `token1` → `token2` among pulled legs only.

| Rule | Value |
|------|--------|
| Empty `permit2Data` | SafeERC20 `transferFrom(msg.sender, hook, used_i)` for **every** pulled leg |
| Non-empty `permit2Data` | **All** pulled legs via Permit2 only — **no mixed** transferFrom (Q36) |
| Modes in DoD | **Both** SignatureTransfer **and** AllowanceTransfer |
| Permit2 address | Well-known constant (D49); not ctor/salt |
| Swaps | No hook Permit2 — V4/PoolManager only |
| LP token | EIP-2612 `permit` on the hook ERC-20 (Q41) — **not** inventory Permit2; **not** used by `removeLiquidity` itself |

#### Mode discriminator (non-empty `permit2Data`)

```text
// First word selects mode (normative):
uint8 mode = abi.decode(permit2Data[:1] or via abi.encode prefix)

mode == 0  // SIGNATURE_BATCH
  permit2Data = abi.encode(
    uint8(0),
    ISignatureTransfer.PermitBatchTransferFrom permit,
    bytes signature
  )

mode == 1  // ALLOWANCE
  permit2Data = abi.encode(uint8(1))
  // Pre: user ERC-20 approved Permit2; user set Permit2 allowance for each
  // pulled token → hook via IAllowanceTransfer.approve
  // Pull: Permit2.transferFrom(msg.sender, hook, used_i, token_i) per pulled leg
```

#### SignatureTransfer batch (`mode == 0`)

```text
// permit.permitted.length == nPull where nPull = count(used_i > 0), 1..3
// permitted[k] ordered by ascending binding index among pulled legs only
// Requirements (else revert):
//   permitted[k].token == token of k-th pulled binding leg
//   signed/requested amount covers used_i for that leg
// Call: permitBatchTransferFrom
//   transferDetails[k].to = hook
//   transferDetails[k].requestedAmount = used for that leg
// Wrong token order, wrong length, insufficient amount, bad/expired sig → revert
```

**Examples:**

| Used legs | `permitted` length / order |
|-----------|----------------------------|
| only token1 | 1: `[token1]` |
| token0 + token2 | 2: `[token0, token2]` |
| all three | 3: `[token0, token1, token2]` |

#### AllowanceTransfer (`mode == 1`)

```text
// No signature payload.
// For each pulled leg in ascending binding order:
//   IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, hook, used_i, token_i)
// Insufficient Permit2 allowance / ERC-20 allowance to Permit2 → revert
```

**DoD tests:** empty transferFrom path; Signature batch for 1-, 2-, and 3-leg pulls in binding order; Allowance mode; wrong batch order / wrong length / expired sig / insufficient allowance revert; **no mixed** path in one call.

**Peer reference (non-normative):** dual buffer PRD §7.3 — same Permit2 address and no-witness spirit; **orbital packing above is SoT** for this package (Q47).

---

## 6. Mapping from reference implementation → IndexedEx law

| Reference (`OrbitalHook.sol`) | IndexedEx product law |
|-------------------------------|------------------------|
| `is BaseHook, ERC20` | **Pattern-copy** IHooks; ERC-20 on wire contract; **no BaseHook inherit** |
| CREATE2 `HookMiner.find` + `new {salt}` | **CREATE3** existing factory + FactoryService mine loop |
| Hardcoded `R = 1_000_000e18` | **\(R\) from first liquidity** ×10 max WAD leg (O3/Q4) |
| Hardcoded `LP_FEE = 1000` | Trading: live **`dexSwapFeeOfVault`**; growth: **`usageFeeOfVault` → feeTo** via `kLast`; PoolKey **DYNAMIC_FEE_FLAG** + **OVERRIDE_FEE_FLAG** |
| `mapping(Currency => uint256) reserves` | Repo storage under diamond slot discipline |
| Inline sphere math | **`UniswapV4OrbitalSwapHookMath` pure library** |
| `console.log` | **Forbidden** in production |
| Empty `unlockCallback` | Omit unused IUnlockCallback unless settle path needs it |
| Always init three pools in script | **Optional subset** (O6); integrator choice |
| Fee residual updates \(L^2\) | **Keep** (LP fee accrual model) |
| First LP `sum` raw amounts | **Sum of 1e18-normalized** amounts (O2); later mint also **WAD** Uni V2 (Q29) |
| No LP slippage params | **sharesMin / amountMins** (O8) |
| Exact-in + exact-out | Keep; prove **bit-exact** preview == execution (Q37); **WAD** gross-up O4/D20a |
| Solady FixedPointMathLib | Prefer **Crane** FixedPointMathLib / BetterMath |

### 6.1 Known reference risks (must fix in port)

1. **BeforeSwapDelta construction** — golden tests on all 6 directed pairs (§4.6).  
2. **First LP share sum** without decimal normalize — fixed by O2.  
3. **Reserve ≥ R** — hard fail; \(R\) now derived at first mint (O3); test growth past \(R\).  
4. **No preview views** — add public previews (D28).  
5. **Donation / balance desync** — Repo is SoT (D18/D36).  
6. **Gas / overflow** on `(R-x)**2` and fee gross-up — Math library bounds + fuzz.  
7. **Production security** — reentrancy, CEI, SafeERC20 (USDT quirks when that token is used).  
8. **Two-reserve live (O7)** — test swaps with witness = 0 and seed path for drained legs.  
9. **Fee override without OVERRIDE bit** — would leave dynamic pool at stored lpFee 0; use D20b.  
10. **Double fee** if PM residual and hook residual both applied — forbidden by D20c.

---

## 7. Deployment model

Matches buffer hook §8 spirit:

| Requirement | Law |
|-------------|-----|
| CREATE3 factory | **Existing** ecosystem `create3Factory` only |
| Address mining | `HookMinerCreate3.computeAddress` + binding salt; deployer = create3Factory |
| Flags | `BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_REMOVE_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA` |
| Vault registry | **Not** required for hook instance deploy; oracle may still key fees by vault address |
| Diamond package factory for instance | **Not** v1 |
| Pool initialize | **Not** part of `deployHook` |

After deploy, integrator (order flexible — **Q28**):

1. Configure oracle **dex** swap fee and **usage** fee for the hook address (and/or defaults) as needed.  
2. Approve tokens to hook and/or Permit2 for LP.  
3. `addLiquidity(..., sharesMin, deadline, permit2Data)` — **sets \(R\)**. **Does not require** pools initialized.  
4. Initialize **any subset** of pair pools with **`fee = DYNAMIC_FEE_FLAG`**, `hooks=hook` (O6/Q7). **`sqrtPriceX96` + `tickSpacing` are PM plumbing only** (Q25) — hermetic tests use tickSpacing **60** and 1:1 mid (`getSqrtPriceAtTick(0)`); integrators any valid values. Init **does not require** liquidity.  
5. Swaps only after: \(R > 0\), pair pool initialized, both trade-leg reserves &gt; 0.

---

## 8. Security and risk

| Risk | Mitigation |
|------|------------|
| Wrong hook flags | Mine + `validateHookPermissions` + tests |
| Invariant break / negative output | Require chains in Math; domain/branch constraints §4.3 |
| Reserve approaches / hits \(R\) | \(R = 10 \times \max\) first-mint WAD; later ops revert if reserve ≥ \(R\) |
| First-mint \(R\) too small for later TVL | Re-deploy new instance if capacity exhausted |
| Trade would zero a leg | Revert (Q27 / D63) — keeps swap legs live without dust-floor mint |
| USDT non-standard ERC-20 | SafeERC20 + Permit2 paths (Q1) |
| FoT / rebasing | Unsupported — out of scope |
| Stale / wrong trading fee | Always re-read `dexSwapFeeOfVault`; previews match; tests change mid-life |
| Stale / wrong growth fee | Re-read `usageFeeOfVault` + `feeTo` on LP; previews simulate `kLast` mint |
| Double trading fee (override + residual) | D20c — residual SoT on hook; override report-only for custom curve |
| Missing OVERRIDE bit | D20b — always OR `OVERRIDE_FEE_FLAG` |
| `feeTo` non-receivable | Whole add/remove reverts (D53) — document ops must use fee collector that can hold ERC-20 |
| PoolKey static fee mismatch | **DYNAMIC_FEE_FLAG** only (Q7) |
| Misread sqrtPrice as mid | Q25 — ignore; quote via `previewSwap*` |
| kLast overflow (triple product) | Accepted Uni V2-class scale limit; document |
| Reentrancy LP ↔ swap | **Global lock** on LP + `beforeSwap` (Q34) + V4 unlock discipline |
| First depositor inflation | MINIMUM_LIQUIDITY dead shares to address(0) |
| Partial-book LP dilution | **Sphere-NAV** mint (D72) at pre-op \(p_i = R-r_i\); **not** sum-NAV (Q44) |
| Residual empty book / `V_before == 0` | Impossible under Q45 when `totalSupply > 0`; tests assert after full exit |
| Fee / rounding leak | **Bit-exact** preview == execution at same feeWad (Q37); same toWad/fromWad ceil/floor path (Q30/Q32); exact-out WAD gross-up +1 |
| Mixed-decimal skew | Uniform WAD internal math (Q29/Q30) — never mix raw ratios with WAD sphere |
| Multi-pool desync | Single reserve mapping |
| Same-pair multi tickSpacing doors | Allowed (Q31); shared reserves — integrator MEV/routing surface, not a product bug |
| Stray ETH / non-bound ERC-20 | Ignore forever (same spirit as D36 donations); no skim in v1 |
| Stale PoolManager slot0 | True price is hook preview only |
| Overflow on squares / fee gross-up | Math bounds; fuzz under \(R\); feeWad &lt; 1e18 |
| Permissionless griefing | No instance admin (O9); fee via oracle governance |

---

## 9. Testing requirements (DoD)

### 9.1 Hermetic (**required** — Q9)

1. Deploy Crane V4 PoolManager + real **Vault Fee Oracle** surface (IndexedexTest peer — not a mock oracle SUT unless only for non-SUT isolation).  
2. Three mintable ERC-20s with **mixed decimals** including **>18 or 0** if practical (Q2); at least 6/6/18.  
3. `deployHook` with feeOracle; flags; `radius()==0`; immutables include feeOracle.  
4. Idempotent redeploy.  
5. First add with deadline + sharesMin (+ optional Permit2 path); \(R = max \times 10\); shares = sumWad − 1000; **sumWad ≤ MIN reverts** (Q33); **LP decimals == 18** (Q24); **no pool init required** for LP (Q28).  
6. Two-leg first mint OK; one-leg fails; first-mint `kLastMode` SumInterim if partial.  
7. Init **one** pool with **DYNAMIC_FEE_FLAG**; static fee=0 / wrong fee reverts (Q7); **sqrtPrice/tickSpacing not product-validated** (Q25); hermetic uses spacing 60 + tick-0 mid; optional second PoolKey same pair different spacing **allowed** (Q31).  
8. Set oracle **dex** fee non-zero WAD; six directed exact-in/out; **bit-exact** preview == execution (Q37); **ceil in / floor out** (Q32); override includes OVERRIDE bit.  
9. Change dex fee mid-life; quotes change; **bit-exact** preview == execution.  
10. Zero trading fee path.  
11. **No full drain:** exact-in/out that would set out reserve to 0 **reverts** (Q27); post-swap both trade legs &gt; 0.  
12. **Protocol growth fee:** non-zero per-address usage fee + feeTo; after swaps, next LP **mints to feeTo**; **`ProtocolFeeMinted`**; **bit-exact** preview == execution (D58 / Q37).  
13. Growth fee-off / **ownerFeeShare == 0** (Q18): no protocol mint.  
14. First mint ≥2 legs; `kLast`/`kLastMode` set if fee-on (SumInterim if partial); MIN to `address(0)` (D46).  
15. Witness=0 (partial first mint) + **sphere-NAV seed shares** (Q5 / Q44 / D72); **seed-only** with positive maxes all 0 (Q38); prop min **only over maxed positive legs** (Q43); **sum-interim protocol mint on re-seed** (Q11); then FullProduct mode. Bit-exact preview of seed vs sum-NAV golden (seed shares ≠ sum-NAV).  
16. Cross-mode: no bogus mint when mode flips without compatible kLast.  
17. Full-book later mint: unused max **not** pulled; **three-leg WAD** Uni V2 + floor pull; **one-/two-sided reverts** (Q39); **used_i == 0 reverts** (Q35); mixed-decimal legs. **No** depositSingle/zap path (Q40).  
18. sharesMin / amountMin / deadline fail paths.  
19. Reserve ≥ \(R\); full exit dust; \(R\) sticky (Q6); **assert `Σ toWad(r_i) > 0` after full user exit** (Q45).  
20. SafeERC20 **or** Permit2 §5.6 (empty; Signature 1/2/3-leg binding order; Allowance mode; **no mix** — Q36/Q47); donations ignored (Q14).  
21. Events LiquidityAdded / Removed / Swap with §5.5 fields; **ProtocolFeeMinted when mint &gt; 0** (Q17 / D60).  
22. Native modifyLiquidity reverts; zero amounts revert; **global reentrancy** LP↔swap (Q34).  
23. `kLastMode()` view; auto name/symbol; **EIP-2612 permit** on LP (Q41); remove burns **msg.sender** only; `addLiquidity` returns **(shares, a0, a1, a2)** match preview used (Q46); no mock hook/PM SUT.

### 9.2 Fork DoD — **Ethereum + Base + Robinhood Chain (4663) all required** (Q9 / Q16 / Q23 / Q48)

For **each** of Ethereum mainnet, Base mainnet, and **Robinhood Chain mainnet (chain ID 4663)** forks:

1. **Tokens:** use live production ERC-20s **or deploy mintable/test ERC-20s on the fork** (Q23). No requirement that the three legs be USDC/USDT/DAI specifically.  
2. **Stack:** live PoolManager / Permit2 / fee-oracle when present; else **deploy production-equivalent bytecode** on the fork (dual D74 peer). Not interface mocks of the SUT.  
3. Deploy hook + fee oracle wiring + add liquidity + init pool(s) (**DYNAMIC_FEE_FLAG**) + swap.  
4. If a USDT-style token is among the legs, cover SafeERC20 quirks; otherwise not required.  
5. At least one LP path exercising protocol growth mint when usage fee + feeTo configured.

### 9.3 Invariants / fuzz (recommended same PR stack)

1. After any successful op with \(R > 0\): stored \(L^2 = \sum_i (R - r_i^{18})^2\) (Q26 — equality is **definition of stored parameter**, not fee-less conservation across swaps).  
2. After swaps only: input raw reserve increases by full gross `amountIn`; output decreases by `amountOut`; trading residual remains in input reserve; **both trade-leg reserves remain &gt; 0**.  
3. LP remove after add (no swaps): pro-rata payouts **bit-exact** vs `previewRemoveLiquidity` (Q37); residual locked for dead MIN share (Q6); **`Σ toWad(r_i) > 0` while `totalSupply > 0`** (Q45).  
4. Protocol mint never exceeds D56 algebra for measured `rootK` growth.  
5. Partial-book mint: `shares == floor(supply' * V_in / V_before)` for pre-op \(p_i = R - r_i^{18}\) (D72); not sum-NAV.

---

## 10. Out of scope / future PRDs

1. **Multi-orbit ticks** (true Paradigm concentrated multi-asset).  
2. **Orbital + Standard Exchange buffer** (hold SE shares as legs; yield-bearing orbital).  
3. \(n\)-asset hypersphere.  
4. **Additional fee channels beyond v1’s two:** e.g. splitting **trading residual** to `feeTo` on every swap, multi-recipient fee splits, orbit-level fees. (**In scope v1:** live `dexSwapFeeOfVault` residual in reserves + live `usageFeeOfVault` growth mint; V4 `DYNAMIC_FEE_FLAG` + per-swap override — Q19.)  
5. Hook-as-DETF leg.  
6. **On-hook single-asset zap / `depositSingle`** — fair path = internal sphere rebalance to a proportional basket then D24 mint (solver/heuristic TBD). **Explicitly out of v1** (Q40); full book is three-leg `addLiquidity` only (Q39).  
7. **Allowance-based LP burn** (`burnFrom` / remove with spender) — v1 burns **`msg.sender` only** (Q41).

---

## 11. Definition of done (package)

- [x] PRD O1–O9 + Q1–Q48 + growth fee D51–D77 locked (**v1.11 plan-ready**).  
- [ ] Implementation + test plan document written.  
- [ ] Files under `contracts/hooks/uniswap/v4/orbital/` per §5.  
- [ ] FactoryService CREATE3 mine deploy green.  
- [ ] Hermetic DoD §9.1 green (incl. sphere-NAV seed, Permit2 §5.6, addLiquidity returns).  
- [ ] Fork DoD §9.2 green on **Ethereum + Base + Robinhood Chain (4663)** (Q16 / Q23 / Q48).  
- [ ] NatSpec + no console.log.  
- [ ] No BaseHook inheritance; no DFPkg/Facet; no owner/pause; no on-hook zap.  
- [ ] AGENTS.md testing / CREATE3 compliance.

---

## 12. Appendix A — Reference file map

| Path (upstream) | Role |
|-----------------|------|
| `src/OrbitalHook.sol` | Full prototype: sphere swap, 3-asset LP, fees |
| `script/OrbitalDeploy.s.sol` | CREATE2 mine + deploy (replace with FactoryService) |
| `script/OrbitalInteraction.s.sol` | Fork demo: LP + 3 pools + swap |
| `README.md` / `info.md` | Product narrative + math derivation notes |
| `HookMath.png` | Diagram asset (optional copy to docs) |

## 13. Appendix B — Comparison to dual buffer hook

| | Dual buffer | Orbital (this) |
|--|-------------|----------------|
| Assets | 2 pair tokens | 3 raw tokens |
| Inventory | SE shares | Raw ERC-20 |
| Curve | Constant product on claims | Sphere on reserves |
| Trading fee | Fixed ~0.3% residual (D29) | Live **`dexSwapFeeOfVault`** residual (WAD) |
| Yield / growth fee | `kLast` via oracle field named **`dexSwapFee`** (growth share — dual naming callout) | Growth via **`usageFeeOfVault` + `kLast`/`kLastMode`** mint to feeTo |
| V4 pools | One pair | Up to three pairs (subset OK), one hook |
| LP | Dual pro-rata; **decimals 18** | Triple pro-rata; partial **sphere-NAV** (Q44/D72); **seed-only OK** Q38; **decimals 18** (Q24); **EIP-2612** (Q41) |
| Single-asset deposit | `depositSingle` zap when eligible | **No** on-hook zap v1 (Q40); three-leg add when full book (Q39); partial seed ≠ zap |
| Radius / depth | N/A (CP) | \(R\) from first mint ×10 |
| V4 init price | Plumbing only (C6) | Plumbing only (Q25) |
| Package standards | Same CREATE3 / Repo-Target / no BaseHook | **Same** |
| Permit2 packing | Normative §7.3 | **Orbital-normative §5.6** (Q47); dual §7.3 peer only |
| addLiquidity returns | plan-defined | **`(shares, a0, a1, a2)`** (Q46) |
| Forks | Base + Robinhood 4663 | **Ethereum + Base + Robinhood 4663** (Q48) |
| Preview fidelity | fee-on preview == execution | **Bit-exact** (Q37) |

## 14. Appendix C — Revision log (clarity)

| Date | Version | Change |
|------|---------|--------|
| 2026-08-03 | v1.5 | O1–O9 + Q1–Q18 + growth fee D51–D60 |
| 2026-08-03 | v1.6 plan-ready | **Q19–Q23:** WAD-only exact-out; Uni V2 proportional used amounts; D20b `OVERRIDE_FEE_FLAG` + D20c no double-haircut; V4 dynamic oracle fees confirmed in-scope; D56 algebra + SumInterim example; first-mint dual-mode `kLast`; `kLastMode()` required; normative events §5.5; settle §4.6; Permit2 → dual §7.3; fork tokens free (test tokens OK); §10 fee future rephrased; D61 error minimum set; dual PRD path corrected |
| 2026-08-03 | v1.7 plan-ready | **Q24–Q29:** LP decimals always 18; V4 `sqrtPrice`/`tickSpacing` plumbing + hermetic convention; \(L^2\) stored sphere parameter; no full trade-leg drain; LP independent of pool init; (later revised) first mint WAD vs later raw Uni V2 |
| 2026-08-03 | v1.8 plan-ready | **Q29 revised + Q30:** uniform 1e18 internal math; native only at transfer/settle; Repo raw; Q24 = LP metadata only |
| 2026-08-03 | v1.9 plan-ready | **Q31–Q36:** pool-init scope = this hook only (no per-pair uniqueness; multi tickSpacing OK); **ceil amountIn / floor amountOut**; first mint `sumWad > MIN`; **global reentrancy lock**; **used_i == 0 revert**; Permit2 **all pulled legs** when non-empty. D17/D23–D24/D30–D31/D48/D64–D65/§4–§9 aligned |
| 2026-08-03 | **v1.10 plan-ready** | **Q37–Q42** + D66–D71: **bit-exact** previews (drop ±1 wei); partial **seed-only**; full-book **three-leg only** / **no on-hook zap**; LP **EIP-2612** + remove burns `msg.sender`; oracle always per-address query APIs; `ProtocolFeeMinted` when mint &gt; 0; MIN/`address(0)` Uni V2 mint note; canonical law index; §2.3/§4.5/§5/§9–§11/Appendix B aligned |
| 2026-08-03 | **v1.11 plan-ready** | **Q43–Q48** + D72–D77: partial prop min = maxed positive legs only; **sphere-NAV fair seed** (replaces sum-NAV; §4.5.1 + worked example); residual `sumPos > 0` invariant; `addLiquidity` returns `(shares,a0,a1,a2)`; **§5.6 orbital Permit2 packing** (sig batch + allowance); Robinhood **4663**; authority + terminology §0; security/DoD/Appendix B aligned |

---

**End of PRD — UniswapV4OrbitalSwapHook (v1.11 plan-ready — Q1–Q48 locked)**
