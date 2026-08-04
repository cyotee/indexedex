# PRD: Uniswap V4 Weighted Swap Hook (Multi-Asset Weighted Curve)

**Name:** `UniswapV4WeightedSwapHook`  
**Date:** 2026-08-03  
**Status:** **Draft v0.2.0** — quality/clarity pass; residual product opens closed via stakeholder Q&A (CREATE3 + off-chain mine; factory-immutable feeOracle; `rootK = V`; no full-book leg zeroing; factory doors only; LP deadline + `msg.sender` burn). Ready for implementation plan.  
**Package path:** `contracts/hooks/uniswap/v4/weighted/`  
**Package kind:** IndexedEx **hook deploy package** with two primary artifacts:

1. **Hook instance** — CREATE3-deployed single contract via the **existing ecosystem `create3Factory`**, with **off-chain-mined** salt material so the predicted address has required V4 hook flag bits (`HookMinerCreate3` / family peer). Repo + Target + Math + Common; also the fungible LP ERC-20. **Not** a vault share diamond; **not** `DiamondPackageCallBackFactory` for the hook instance; **not** Facet/DFPkg for the hook.
2. **On-chain factory** — permissionless public surface that deploys hooks through the ecosystem `create3Factory` (as operator or equivalent authorized path) and **initializes all** \(\binom{n}{2}\) Uni V4 pair doors for the bound token set. Factory is **not** a second CREATE3 *system*; it is an **application factory** that *calls* the ecosystem CREATE3 factory.

**Decision ID note:** `D*`, `Q*`, and `O*` IDs are **stable keys**, not document order. Prefer referring to IDs over section renumbering.

**Authority (normative):**

| Layer | Role |
|-------|------|
| **This PRD (v0.2.0)** | Product law used to **write** the implementation plan. Canonical decisions live in §3. |
| **Implementation plan** (follow-on) | Bit-exact formulas, ABI names, file staging — **source of truth for implementors** once written against this PRD |
| Peer packages / Balancer reference | Pattern and math references only — **not** deploy law; do not copy CREATE2 / BaseHook / console.log |

**Behavioral / math references (requirements harvest — not deploy law, not package layout):**

- Balancer V3 **WeightedMath** + **WeightedPool** (global normalized weights; \(n \le 8\); min weight 1%; swap / invariant formulas) under Crane:  
  `lib/crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol`  
  `lib/crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool.sol`  
  Join/exit unbalanced helpers:  
  `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol`
- IndexedEx multi-door hook peers:  
  - Quad Stable: `contracts/hooks/uniswap/v4/stable/quad/UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md` (doors + factory shape + ecosystem CREATE3)  
  - Orbital: `contracts/hooks/uniswap/v4/orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md` (fee oracle dual channel, `kLast`, partial-book dual mode, Permit2, DYNAMIC_FEE_FLAG, LP deadline / burn rules)

**Sibling packages (do not conflate):**

| Package | Path | Role |
|---------|------|------|
| Single SE buffer | `…/standardExchange/single/` | Wrapper pool `underlying ↔ SE` |
| Dual SE buffer | `…/standardExchange/dual/` | CP AMM on two SE claim legs |
| Orbital sphere | `…/orbital/` | 3-asset spherical invariant |
| Quad StableSwap | `…/stable/quad/` | 4-asset StableSwap \(A\)-amplified |
| **This package** | `…/weighted/` | **2–8 asset** Balancer-style **weighted** curve on shared reserves |

**Related Crane / IndexedEx standards (mandatory pattern sources):**

- Crane HookMiner: `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol`
- Crane fee units: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol` (`DYNAMIC_FEE_FLAG`, `OVERRIDE_FEE_FLAG`)
- Crane math: Balancer `FixedPoint` / `WeightedMath`; Crane `FixedPointMathLib` / `BetterMath` as needed
- Vault Fee Oracle: `contracts/interfaces/IVaultFeeOracleQuery.sol`
- AGENTS.md — production-first tests; CREATE3; no mock SUT; no `new` facets

### Canonical law index (planner shortcut)

Use this table as the **first hop**; full normative text lives at the linked section / decision. Do not invent alternate product law.

| Topic | Normative pointer |
|-------|-------------------|
| Product shape / non-goals | §1–§2.4 |
| Binding, \(n\), weights, tokens | D4–D9, §4.1–§4.2 |
| Rate scaling / fail-closed | D17–D18, §4.3 |
| Swap math + trading fee | D20–D23, D37, §4.4–§4.5 |
| Protocol growth (`kLast`) | D24–D31, D28 (`rootK = V`), §4.5 |
| Full-book join/exit | D33–D34, D38, §4.6 |
| Partial book dual mode | D36, §4.7 |
| No leg zeroing on full-book exit | D67, §4.7.8 |
| Settle / BeforeSwapDelta | D65, §4.9 |
| Hook permissions / doors only | D10–D13, D42–D43, D68, §4.8 |
| Deploy / factory / CREATE3 | D44–D51, D69, §5.3–§5.4 |
| LP ERC-20, deadline, burn | D16, D40–D41, D70–D71, §5.2 |
| Permit2 packing | D40 (peer Orbital §5.6 packing law) |
| Events / errors | D72–D73, §5.5 |
| Preview fidelity | D52–D53 |
| Test DoD | §7–§8 |
| Locked decision tables | §3 |

---

## 0. Terminology (normative)

| Term | Meaning in this PRD |
|------|---------------------|
| **Weighted (product family)** | Package tree under `hooks/uniswap/v4/weighted/`. Hosts multi-asset Balancer-style weighted curve hooks. |
| **Product name** | Canonical Solidity / package type: **`UniswapV4WeightedSwapHook`**. |
| **Option A weights** | One **global** immutable normalized weight vector \(w[0..n-1]\) for the whole book. Not per-pair independent weights. |
| **\(n\)** | Token count for the instance: **2 ≤ n ≤ 8**, fixed at deploy. |
| **Normalized weight** | Fixed-point WAD weight; \(\sum_i w_i = 1\mathrm{e}18\); each \(w_i \ge\) `MIN_WEIGHT` (1e16 = 1%). |
| **Weighted invariant \(V\)** | \(V = \prod_i b_i^{w_i}\) on **rate-scaled 1e18** balances (Balancer `computeInvariant*`). |
| **Pair door** | A Uni V4 2-currency pool whose currencies are any **address-sorted** pair of the bound tokens, all sharing **one** hook address and **one** shared reserve book. |
| **Factory doors** | The exact set of \(\binom{n}{2}\) PoolKeys created at deploy: `fee = DYNAMIC_FEE_FLAG`, `tickSpacing = TICK_SPACING` (1), `hooks = hook`. **Only** these keys may initialize against the hook (D68). |
| **Full book** | All \(n\) Repo reserves \(> 0\). Full Balancer join/exit + product \(V\) protocol fee mode. |
| **Partial book** | At least one bound token has Repo reserve \(= 0\). **Allowed divergence** from pure Balancer (which requires all balances \(> 0\)). Restricted LP surface + dual-mode protocol fee (§4.7). |
| **LP / shares / BPT** | Fungible ERC-20 minted by **this hook** — pro-rata claim on all \(n\) Repo reserves (via invariant / proportional rules). Not V4 position NFTs. “BPT” in Balancer APIs maps to this LP. |
| **Repo reserves** | Authoritative inventory amounts in **hook storage** (Repo layout). **Not** raw `balanceOf(hook)` alone. Donations never update Repo. |
| **First-minted book** | `totalSupply > MINIMUM_LIQUIDITY` after a successful first liquidity op. |
| **Swap-live (directed)** | For pair \((in,out)\): `reserves[in] > 0`, `reserves[out] > 0`, and weighted swap solve succeeds under ratio caps. Other legs may be zero. |
| **Rate-scaled balance** | Token amount converted to 1e18 units via decimal scale and optional Balancer-style `IRateProvider.getRate()`. |
| **Taxable amount** | On unbalanced joins/exits: the portion of a leg above (or below) the proportional invariant path — charged the **swap fee** (Balancer peer). |
| **Off-chain mine** | Caller (or tooling) computes `mineNonce` / salt material so `CREATE3.getDeployed(...)` has required hook flags **before** calling factory deploy. Factory **does not** run a gas-heavy on-chain mine loop as the primary path (D48 / D69). |
| **DoD** | Definition of Done — package complete when §8 is satisfied. |

---

## 1. Goal

Ship a **production-first Uniswap V4 hook package** that:

1. Binds **\(n \in [2, 8]\)** ERC-20 assets, one V4 `PoolManager`, and one Vault Fee Oracle per hook instance.
2. Implements **Balancer Weighted Pool math** on rate-scaled reserves with a **global** immutable weight vector:
   \[
   V = \prod_{i=0}^{n-1} b_i^{w_i},\quad \sum w_i = 1\mathrm{e}18,\quad w_i \ge 1\%
   \]
3. Exposes **all** \(\binom{n}{2}\) Uni V4 pair pools as swap doors into the **same** shared \(n\)-asset reserve state (factory creates all doors on deploy).
4. Holds **authoritative inventory in Repo**; settles swaps via **`beforeSwap` + `beforeSwapReturnDelta`** (custom accounting); pattern-copy settle — **no** Solidity inheritance of OZ/`BaseHook` / `DeltaResolver`.
5. Mints a **single fungible ERC-20 LP** representing claim on the multi-asset book.
6. Mirrors Balancer Weighted **join/exit surface** as closely as feasible: proportional, single-asset, unbalanced multi-asset, exact-BPT-out joins; matching exits; invariant-ratio and max-in/out caps.
7. Takes **trading fees** live from **`dexSwapFeeOfVault`**, applied in the **Balancer Weighted** manner (fee on swap **input**; residual stays in book).
8. Takes **protocol growth fees** live from **`usageFeeOfVault`**, minting LP to live **`feeTo()`** on **add and remove** (Uni V2 / Orbital peer).
9. Supports optional Balancer **`IRateProvider`** per token (e.g. ERC-4626 vault rate).
10. **Allows partial book** (zero reserves on some legs) as an **IndexedEx divergence** with dual-mode rules (§4.7), while **forbidding** full-book exits that zero a leg (D67).
11. Deploys via **on-chain permissionless factory** + ecosystem CREATE3 + **off-chain-mined** flag-correct address.
12. Supports **Permit2** on LP pull paths and **deadline** on LP mutators (Orbital peer).

### 1.1 Canonical user story (example: 4 tokens, 40/30/20/10)

```text
Hook binding (instance):
  n = 4
  tokens[0..3] = four ERC-20s, strict address ascending
  weights = [0.40e18, 0.30e18, 0.20e18, 0.10e18]
  poolManager = factory immutable = canonical Uni V4 PoolManager
  feeOracle   = factory immutable IVaultFeeOracleQuery  // all hooks from this factory share it
  rateProviders[i] = IRateProvider or address(0)
  LP = fungible ERC-20 on same contract (e.g. WGT-A-B-C-D)

--- Off-chain (anyone) ---
// Mine mineNonce (or salt material) so predicted CREATE3 address has HOOK_FLAGS
// Salt preimage includes namespace, poolManager, feeOracle, n, tokens, weights, rateProviders (D47)

--- Deploy (permissionless factory) ---
Anyone calls factory.deployWithMineNonce(tokens, weights, rateProviders, namespace, mineNonce)
  → CREATE3 deploy hook via ecosystem create3Factory at flag-correct address
  → initialize ALL 6 pair pools (DYNAMIC_FEE_FLAG, tickSpacing=1, hooks=hook)
  → inert until first liquidity

--- First mint (full book preferred path) ---
joinProportional / multi-amount first mint with all legs > 0, deadline, permit2Data
  → shares from rate-scaled V − MINIMUM_LIQUIDITY
  → lock MIN to address(0); set kLast if fee-on

--- Single-asset join (full book) ---
joinSingleAssetExactIn(token, amountIn, sharesMin, to, deadline, permit2Data)
  → require deadline; protocol growth mint first
  → Balancer single-token add math + swap fee on taxable portion
  → mint user LP to `to` (or msg.sender policy peer — plan freezes recipient param)

--- Swap A → B via A/B pool ---
  → beforeSwap: load rate-scaled balA, balB, wA, wB
  → tradeFeeWad = dexSwapFeeOfVault(this)  // 0 allowed
  → exact-in: amountInNet after input fee; WeightedMath.computeOutGivenExactIn
  → residual fee stays in reserves[in]
  → DYNAMIC fee override for routers

--- Remove ---
exitProportional(shares, amountsMin, to, deadline)
  → require deadline; protocol mint first; burn msg.sender LP only; pay `to`
  → full book: post-state must keep all reserves > 0 (D67) unless full dust exit rules apply

--- Protocol growth ---
On every add/remove: usageFeeOfVault + feeTo → mint LP to feeTo from V growth vs kLast
  rootK = V (literal) on full book
```

### 1.2 Why this exists (product problem)

| Approach | Limitation |
|----------|------------|
| Uni V3/V4 CL multi-pairs | Capital fragmented across \(\binom{n}{2}\) books; multi-hop fees |
| Quad StableSwap | Equal-unit stables; not free weight vectors for uncorrelated assets |
| Balancer Weighted off Uni | Not native Uni V4 routing / UR / quoter surface |
| Per-pair independent weights (Option B) | Inconsistent shared book or fragmented reserves |
| **This package** | Shared **n-asset weighted** book; all pairwise V4 doors; IndexedEx oracle + CREATE3 standards |

---

## 2. Product summary

### 2.1 What this package is

| Attribute | Value |
|-----------|--------|
| Primary artifact | CREATE3-deployed single hook (Repo + Target + Math + Common) implementing V4 `IHooks` **plus** LP ERC-20 |
| Binding | `(poolManager, feeOracle, tokens[n], weights[n], rateProviders[n])` — ctor immutables / set-once. `poolManager` and `feeOracle` come from **factory immutables** (same for every hook from that factory) |
| Pool currencies | All \(\binom{n}{2}\) address-sorted pairs of bound tokens (**factory doors only**) |
| Inventory | Authoritative **Repo `reserves[i]`** |
| Pricing (swap) | `WeightedMath.computeOutGivenExactIn` / `computeInGivenExactOut` on the **two trade legs** only |
| Pricing (LP) | Full-book: Balancer invariant / `BasePoolMath`-equivalent join-exit. Partial: dual-mode rules §4.7 |
| LP | Fungible ERC-20 on the hook; auto name/symbol; 18 decimals; EIP-2612 |
| Trading fee | Live **`dexSwapFeeOfVault(this)`** WAD; Balancer input-side residual; **0 allowed** |
| Protocol fee | Live **`usageFeeOfVault(this)`** → mint LP to live **`feeTo()`** on add **and** remove; **`rootK = V`** (full book) |
| PoolKey fee | **`DYNAMIC_FEE_FLAG`** + per-swap override report |
| Deploy path | On-chain permissionless factory → ecosystem CREATE3 + **off-chain mine** + all pair `initialize` |
| Access (hook) | Fully permissionless — no owner, no pause, no weight mutation |
| Access (factory) | Permissionless `deploy*` / `ensurePairPools` |

### 2.2 What this package is not

- Not per-pair independent weight vectors (Option B).
- Not StableSwap / Orbital sphere / dual SE buffer.
- Not Uni V4 concentrated liquidity / Position Manager LP.
- Not a Facet/DFPkg diamond for the hook instance.
- Not a second CREATE3 infrastructure.
- Not a DETF or vault registry product.
- Not amp ramps / weight ramps (LBP is out of scope).
- Not a separate zap path (single-asset join is the one-token entry when full book).
- Not inheritance of `BaseHook` / `DeltaResolver`.
- Not an on-chain mine loop as the **primary** deploy path (off-chain mine is primary).
- Not free re-init of arbitrary extra PoolKeys against the hook.

### 2.3 Non-goals (v1)

1. \(n \notin [2,8]\) or post-deploy change of \(n\) / token set / weights.  
2. Gradual weight change (LBP).  
3. Yield buffering of legs into SE/Morpho inside this package.  
4. Native ETH as pool currency (use WETH).  
5. Hook/protocol **ERC-20 skim buckets** (growth is LP mint only; trade residual stays in reserves).  
6. Instance owner / pause / admin fee setters (oracle only).  
7. Binary-search solvers — closed Balancer formulas only.  
8. Subclassing orbital / quad / dual buffer hooks.  
9. Shared TestBases with DETF Uni V4 packages.  
10. Bare CREATE2 that bypasses ecosystem CREATE3 + flag-correct address.  
11. Trusting PoolManager `slot0` for product quotes.  
12. Fee-on-transfer / rebasing tokens.  
13. Factory-owned first liquidity seed.  
14. Partial pair set as the **default** factory path (default = **all** \(\binom{n}{2}\)).  
15. On-chain mine loop as DoD-required deploy path (optional later; primary is off-chain mine).  
16. Zeroing any leg via full-book exit while the book remains multi-leg live (D67).  
17. Leaving `console.log` / debug logs in production sources.

### 2.4 Allowed divergence from Balancer (explicit)

| Topic | Balancer Weighted | This package |
|-------|-------------------|--------------|
| Host | Balancer V3 Vault | Uniswap V4 PoolManager + multi pair doors |
| Zero balances | Forbidden (`ZeroInvariant`) | **Partial book allowed** (§4.7) for seed / incomplete capitalization |
| Full-book exit zeroing | N/A (Vault always full) | **Forbidden** — full-book remove must leave all \(n\) reserves \(> 0\) (D67) |
| Fee rates | Vault/pool config | **Vault Fee Oracle** live WAD |
| Protocol cut | Separate protocol fee pathways | Uni V2–style **LP mint to `feeTo`** from \(V\) growth; **`rootK = V`** |
| Settlement | Vault credit/debt | V4 unlock + hook deltas |
| LP token | BPT | Same-contract ERC-20 LP |

When full book is live, join/exit/swap **math** should match Balancer Weighted + BasePoolMath behavior (including taxable swap fee and ratio caps) as closely as fixed-point peers allow. Implementation plan freezes bit-exact rounding vs Crane `WeightedMath`.

---

## 3. Locked product decisions

> Rows marked **LOCKED** are stakeholder-confirmed (2026-08-03 design thread + v0.2.0 quality pass). Residual opens in §3.2 are plan-level only and **do not** block writing the implementation plan.

| # | Decision | Value | Status |
|---|----------|--------|--------|
| D1 | Product name | **`UniswapV4WeightedSwapHook`** | **LOCKED** |
| D2 | Package location | `contracts/hooks/uniswap/v4/weighted/` | **LOCKED** |
| D3 | Math model | Balancer **WeightedMath** (+ BasePoolMath-equivalent joins/exits); **not** StableSwap / Orbital | **LOCKED** |
| D4 | Weight model | **Option A** — one global immutable normalized weight vector | **LOCKED** |
| D5 | Asset count | **Variable \(n \in [2, 8]\)** fixed at deploy | **LOCKED** |
| D6 | Binding | Ctor immutables: `poolManager`, **`feeOracle`**, `tokens[n]`, `weights[n]`, `rateProviders[n]` | **LOCKED** |
| D7 | Token validation | Non-zero; all pairwise distinct; decimals in **[6, 18]**; **no native ETH** | **LOCKED** |
| D8 | Token order | Factory/hook require **strict address ascending** `tokens[0] < … < tokens[n-1]`. That order is binding index for weights, rates, reserves, views | **LOCKED** |
| D9 | Weights | Each \(w_i \ge\) **`MIN_WEIGHT = 1e16`**; \(\sum w_i =\) **`1e18`** exactly; immutable | **LOCKED** |
| D10 | Pool set | Factory **must create all** \(\binom{n}{2}\) pair pools on successful `deploy`. Permissionless `ensurePairPools(hook)` may repair. All doors: `hooks = hook` | **LOCKED** |
| D11 | Pool fee (V4 key) | **`LPFeeLibrary.DYNAMIC_FEE_FLAG`** only. Economic trading fee SoT = hook residual math | **LOCKED** |
| D12 | Native CL | **Forbidden** — `beforeAddLiquidity` / `beforeRemoveLiquidity` **revert** | **LOCKED** |
| D13 | Donate | **Forbidden** — `beforeDonate` **reverts** | **LOCKED** |
| D14 | Package shape | Hook: Repo + Target + Common + Math + thin wire. FactoryService + on-chain Factory. **No** Facet/DFPkg for hook/factory | **LOCKED** |
| D15 | Hook inheritance | **No** inheritance of `BaseHook`, `BaseTokenWrapperHook`, `DeltaResolver` — pattern-copy only | **LOCKED** |
| D16 | LP ERC-20 | **Same** mined hook contract (IHooks + ERC-20 + **EIP-2612**). Decimals **18**. Prefer Uni V2–style mint that allows balance on `address(0)` | **LOCKED** |
| D17 | Rate law | Normalize to **1e18**. `baseScale[i] = 10^(36 - decimals_i)`. Optional Balancer **`IRateProvider`** or `address(0)`. When non-zero: always `staticcall getRate()` → uint256 @ 1e18. `effectiveRate = baseScale * rate / 1e18`. **No public selector**; **no package adapters** | **LOCKED** |
| D18 | Rate fail-closed | Provider ≠ 0 ⇒ success, returndata length 32, **rate > 0**, else **revert** on op + matching preview. No last-good cache; no silent `1e18` fallback when configured | **LOCKED** |
| D19 | Reserves SoT | **Repo `reserves[i]`**; donations ignored for pricing | **LOCKED** |
| D20 | Trading fee source | Live **`feeOracle.dexSwapFeeOfVault(address(this))`** WAD on every swap + swap preview. Oracle cascade/default is SoT when no per-address override. **`0` allowed**. Require **`feeWad < 1e18`** | **LOCKED** |
| D21 | Trading fee method | **Balancer Weighted**: fee on **input**. Exact-in: `amountInNet = amountIn − floor(amountIn * feeWad / 1e18)`; curve on net; **full gross** added to `reserves[in]`. Exact-out: gross-up input with **ceil** division `ceil(netIn * 1e18 / (1e18 − feeWad))` (peer Orbital/dual; plan freezes `+1` vs pure ceil helper). Residual stays in book for LPs | **LOCKED** |
| D22 | Trading fee destination | Residual **in reserves** (input leg). **Not** transferred to `feeTo` | **LOCKED** |
| D23 | Fee override report | `uint24 v4Fee = uint24(feeWad * 1_000_000 / 1e18) \| OVERRIDE_FEE_FLAG`. Informational / router UX. **No double-haircut** with residual math | **LOCKED** |
| D24 | Protocol growth | **Yes** — Uni V2–style. On **add and remove** (not each swap): mint LP to **`address(feeOracle.feeTo())`** from growth of measure \(k\) since **`kLast`**, **before** user mint/burn | **LOCKED** |
| D25 | Growth rate source | Live **`feeOracle.usageFeeOfVault(address(this))`** WAD. **Not** `dexSwapFeeOfVault`. Cascade/default when unset | **LOCKED** |
| D26 | Growth recipient | Live **`feeTo()`** each LP op (may change). Failed mint ⇒ whole LP op reverts. Exit via normal remove | **LOCKED** |
| D27 | fee-on predicate | `feeOn = (feeTo != 0 && usageFeeWad != 0 && usageFeeWad < 1e18 && ownerFeeShare != 0)` with `ownerFeeShare = usageFeeWad * 100_000 / 1e18` (floor) | **LOCKED** |
| D28 | `k` / growth measure | **Full book:** \(k = V = \prod b_i^{w_i}\) (rate-scaled); **`rootK = V` (literal)** — no extra root transform. Overflow accepted as Uni V2–class / Balancer-scale risk; Math uses Balancer FixedPoint + checked intermediates. **Partial book:** interim measure §4.7 | **LOCKED** |
| D29 | Growth algebra | Peer Orbital/dual: `protocolLp = totalSupply * (rootK - rootKLast) / (rootK * FEE_DENOMINATOR / ownerFeeShare + rootK - rootKLast)` when `rootK > rootKLast` and fee-on and same mode. `FEE_DENOMINATOR = 100_000` | **LOCKED** |
| D30 | Growth timing | Add: measure pre-pull \(k\); mint protocol; then user join; set `kLast` post. Remove: mint protocol then burn; set `kLast` post. First mint: no protocol mint (`kLast==0`); set post if fee-on. Swaps do not mint or update `kLast` | **LOCKED** |
| D31 | Growth + previews | LP previews **must** simulate protocol mint dilution so **preview == execution** at same oracle reads | **LOCKED** |
| D32 | feeOracle binding | **Immutable** on hook (from factory). Factory **`feeOracle` is factory-immutable** — **not** a per-deploy argument. All hooks from a given factory share that oracle. **`feeTo()` always live** on the oracle | **LOCKED** |
| D33 | Join surface (full book) | Mirror Balancer: (1) proportional multi-asset exact amounts / exact BPT; (2) **single-asset** exact-in and exact-BPT-out; (3) **unbalanced multi-asset** exact amounts; (4) exact-BPT-out unbalanced as Balancer supports via inverse paths. Taxable swap fee + invariant ratio caps | **LOCKED** |
| D34 | Exit surface (full book) | Mirror Balancer: proportional exact BPT in; single-asset exact BPT in / exact token out; unbalanced multi where peer BasePoolMath supports; ratio caps; **post-state all reserves > 0** (D67) | **LOCKED** |
| D35 | Zap | **Not in v1** — single-asset join is the one-token entry (full book only) | **LOCKED** |
| D36 | Partial book | **Allowed divergence.** Dual-mode rules **§4.7**. First mint may seed **≥2** positive legs for \(n \ge 3\) (zeros allowed for others). For **\(n = 2\)**, first mint **requires both** legs \(> 0\). Full Balancer unbalanced surface only when **full book** | **LOCKED** |
| D37 | Swap ratio caps | Keep Balancer **`_MAX_IN_RATIO` / `_MAX_OUT_RATIO` = 30%** of balance | **LOCKED** |
| D38 | Invariant ratio caps | Keep Balancer-style **max growth ~300%** / **min shrink ~70%** on unbalanced add/remove (peer `WeightedMath` / pool bounds) | **LOCKED** |
| D39 | Unsupported tokens | Rebasing **forbidden**; fee-on-transfer **forbidden** | **LOCKED** |
| D40 | Permit2 | **Required** on LP join/exit **pull** paths (empty data ⇒ transferFrom-only; non-empty ⇒ Permit2 for all pulled legs — packing law **peer Orbital §5.6**). Exit token transfers out do not require Permit2 | **LOCKED** |
| D41 | MINIMUM_LIQUIDITY | **1000** LP wei → **`address(0)`** permanently on first mint | **LOCKED** |
| D42 | Tick spacing | Package constant **`TICK_SPACING = 1`**. `beforeInitialize` enforces | **LOCKED** |
| D43 | Init sqrt price | Factory: `TickMath.getSqrtPriceAtTick(0)` (plumbing only; not used for product quotes) | **LOCKED** |
| D44 | PoolManager | Factory immutable = **canonical Uni V4 PoolManager** for the chain; hook binds same. Not per-deploy; not `feeTo()` | **LOCKED** |
| D45 | Deploy | CREATE3 via ecosystem `create3Factory`; flag-correct address via **off-chain mine**; **not** vault registry | **LOCKED** |
| D46 | Salt namespace default | **`"uv4-weighted-swap-hook-"`** | **LOCKED** |
| D47 | Salt material | namespace, poolManager, feeOracle, n, tokens, weights fingerprint, rateProviders fingerprint, mineNonce (encodePacked hash peer to family packages) | **LOCKED** |
| D48 | Mine APIs | **Primary DoD path:** off-chain mine + `deployWithMineNonce` (or equivalent) through factory → ecosystem CREATE3. On-chain mine loop is **optional / deferred** (not required for DoD). Minimum DoD: permissionless deploy + flag-correct address + all doors | **LOCKED** |
| D49 | Idempotent deploy | Same binding + namespace + mineNonce ⇒ same address; ensure all doors; wrong code reverts | **LOCKED** |
| D50 | Factory registry | Minimal `isDeployedByFactory`; events; not full vault registry | **LOCKED** |
| D51 | No LP in factory | Factory never pulls tokens or mints LP | **LOCKED** |
| D52 | Preview fidelity | **preview == execution** at same oracle fee reads and same rate reads; document ≤1 wei only if unavoidable and listed in plan | **LOCKED** |
| D53 | Public previews | Join/exit previews (all modes), swap exact-in/out, reserves, weights, rates, `dexSwapFee()`, `usageFee()`, `feeTo()`, `kLast()`, `kLastMode()`, tokens | **LOCKED** |
| D54 | Reentrancy | Global non-reentrant on LP surfaces + `beforeSwap` body (after PM check) | **LOCKED** |
| D55 | Zero amounts | Revert zero amountIn/out/shares where applicable | **LOCKED** |
| D56 | Post-swap floors | Successful swap must leave `reserves[in] > 0` and `reserves[out] > 0` | **LOCKED** |
| D57 | Donations | Stray transfers never update Repo reserves | **LOCKED** |
| D58 | Access control | Permissionless instance; fees via oracle only | **LOCKED** |
| D59 | LP name/symbol | Auto `WGT-{s0}-…-{s_{n-1}}` (cap length); address-fragment fallback; cache at ctor | **LOCKED** |
| D60 | License / style | BUSL-1.1 (or package peer); NatSpec + Crane code-style | **LOCKED** |
| D61 | Tests | Production-first; real V4 PM; **real Vault Fee Oracle** with defaults set; no mock hook SUT | **LOCKED** |
| D62 | Fork priority | **Base** and **Robinhood Chain** (equal DoD priority after hermetic); mintable test tokens OK | **LOCKED** |
| D63 | Impl plan follow-on | `UNISWAP_V4_WEIGHTED_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` | **LOCKED** |
| D64 | Math library | Pure `UniswapV4WeightedSwapHookMath` wrapping WeightedMath + join/exit + scale + growth helpers | **LOCKED** |
| D65 | Settle order | Pattern-copy peer hooks: take input; sync+transfer+settle output; BeforeSwapDelta matches (see §4.9) | **LOCKED** |
| D66 | Admin | **None** on hook — no weight update, no pause, no fee setter | **LOCKED** |
| D67 | Full-book exit floors | While mode is **FullProduct**, any remove must leave **all \(n\) reserves \(> 0\)**. Zeroing a leg via full-book exit **reverts**. Partial book is entered only via **partial first mint / seed path**, not by draining a full book leg | **LOCKED** |
| D68 | Factory doors only | `beforeInitialize` accepts **only** PoolKeys that match factory-door rules: both currencies in bound set, distinct, address-sorted as V4 requires, **`fee == DYNAMIC_FEE_FLAG`**, **`tickSpacing == TICK_SPACING`**, **`hooks == this`**. Extra keys (other tickSpacing, other fee) **revert**. No external “second door set” | **LOCKED** |
| D69 | CREATE3 model | **Ecosystem `create3Factory`** is the deploy engine. Factory is **not** its own CREATE3 system. **Off-chain-mined** `mineNonce` (or salt material) is the primary path so predicted addresses carry hook flags. Deployer for CREATE3 address prediction follows FactoryService / HookMiner peer (document exact `deployer` in plan — typically `address(create3Factory)`) | **LOCKED** |
| D70 | LP deadline | All LP **mutators** (join/exit) take **`deadline`** and **`require(block.timestamp <= deadline)`** (Orbital peer) | **LOCKED** |
| D71 | LP burn authority | **`remove` / exit burns `msg.sender` LP only** — no `burnFrom` / allowance burn for exits (Orbital Q41 peer). Joins may mint to a `to` recipient if surface includes `to` | **LOCKED** |
| D72 | Events (minimum) | At least: `HookDeployed` / `PairPoolsEnsured` (factory); LP join/exit events with used amounts + shares; `ProtocolFeeMinted`; `Swap` (or rely on V4 swap events + hook state — plan freezes). Field lists in §5.5 | **LOCKED** |
| D73 | Errors (minimum) | At least: bad tokens/weights/n; not full book for Balancer path; partial restricted; ratio caps; fee wad; rate fail; deadline; zero amounts; not factory-attested ensure; wrong init fee/tick; reentrancy; full-book zero-leg attempt | **LOCKED** |

### 3.1 Implementor edges — **LOCKED**

| ID | Topic | Locked value |
|----|--------|--------------|
| Q1 | Weight model | Global Option A only |
| Q2 | \(n\) | 2–8 at deploy |
| Q3 | Trading fee | Live `dexSwapFeeOfVault`; Balancer input residual; 0 OK |
| Q4 | Growth fee | Live `usageFeeOfVault` → LP mint to live `feeTo` on add+remove |
| Q5 | `k` full | Weighted invariant \(V\) on rate-scaled balances; **`rootK = V`** |
| Q6 | Partial book | Allowed; dual-mode §4.7; **not** via full-book exit zeroing |
| Q7 | Joins/exits | Mirror Balancer when full; restricted when partial |
| Q8 | No zap | Single-asset join is the one-token entry (full book) |
| Q9 | DYNAMIC_FEE_FLAG | Yes |
| Q10 | Oracle tests | Deploy oracle; set **defaults**; per-address optional |
| Q11 | Rates | Optional `IRateProvider`; fail-closed |
| Q12 | FOT/rebase | Forbidden |
| Q13 | Permit2 | Required DoD |
| Q14 | Factory | On-chain; all doors; ecosystem CREATE3 + off-chain mine |
| Q15 | Caps | Balancer 30% swap; 300%/70% invariant ratio |
| Q16 | feeOracle scope | Factory-immutable; shared by all hooks from that factory |
| Q17 | Doors after deploy | Factory doors only (no extra tickSpacing/fee keys) |
| Q18 | LP ops | Deadline required; exit burns `msg.sender` only |
| Q19 | Full-book remove | Must keep all reserves \(> 0\) |

### 3.2 Residual open decisions (plan-level only)

| # | Question | Default if unresolved |
|---|----------|------------------------|
| O1 | Exact FactoryService salt encoding + CREATE3 `deployer` field | Match quad / HookMiner peer; freeze in plan §deploy |
| O2 | Bit-exact first-mint `shares = V − MIN` vs Balancer INIT supply mapping | Prefer **`shares = V − MINIMUM_LIQUIDITY`** with rate-scaled `computeInvariantDown`; if Balancer peer differs by fixed mapping, plan documents and tests bit-exact |
| O3 | Exact ABI names for join/exit (Balancer-like vs compact) | Plan chooses ergonomic names; behavior law is D33–D34 |
| O4 | Partial-mode proportional / seed share formula bit-exact ordering and ε | §4.7.6 normative sketch; plan freezes ordering/rounding |
| O5 | Join mint recipient (`to` vs always `msg.sender`) | Prefer **`to` param** on joins (Orbital peer); exits pay amounts to `to`, burn `msg.sender` |
| O6 | Optional later on-chain mine loop helper | Deferred; not DoD |

---

## 4. Architecture

### 4.1 Stack

```text
┌──────────────────────────────────────────────────────────────────┐
│ Anyone (permissionless)                                          │
│   • off-chain mine mineNonce for flag-correct CREATE3 address    │
│   • factory.deployWithMineNonce(...)  →  hook + binom(n,2) doors │
│   • factory.ensurePairPools(hook)                                │
└───────────────────────────────┬──────────────────────────────────┘
                                │ CREATE3 (ecosystem) + initialize×N
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│ User / Router                                                    │
│   • join / exit / deadline / Permit2 on Hook                     │
│   • swapExact* via V4 on any factory door                        │
└───────────────┬─────────────────────────────┬────────────────────┘
                │                             │
                ▼                             ▼
┌───────────────────────────────┐   ┌──────────────────────────────────┐
│ UniswapV4WeightedSwapHook     │   │ Uniswap V4 PoolManager           │
│  reserves[n] + weights[n]     │◄──│  binom(n,2) pair pools           │
│  rates + feeOracle            │   │  fee=DYNAMIC_FEE_FLAG            │
│  ERC-20 LP + kLast            │   │  tickSpacing=1, hooks=hook       │
│  Math: WeightedMath + joins   │   │                                  │
└───────────────────────────────┘   └──────────────────────────────────┘
                │
                ▼
┌───────────────────────────────┐
│ IVaultFeeOracleQuery          │
│  dexSwapFeeOfVault(hook)      │
│  usageFeeOfVault(hook)        │
│  feeTo()  (live)              │
└───────────────────────────────┘
```

### 4.2 Virtual multi-pool (“many doors, one room”)

Uniswap V4 pools are **strictly 2-currency**. Multi-asset weighted state lives **only** on the hook:

```text
Pool t0/t1  ──┐
Pool t0/t2  ──┤
…             ├──► same UniswapV4WeightedSwapHook
Pool t_{n-2}/t_{n-1} ──┘
   shared reserves[n] + weights[n] + rates + LP + kLast
```

**Swap pricing** for pair \((i,j)\) uses only \((b_i, w_i, b_j, w_j)\) (Balancer). Other balances do **not** enter the swap formula (unlike StableSwap witnesses). They **do** enter full-book invariant \(V\) for LP and protocol growth.

**Factory obligation:** on successful deploy, **all** \(\binom{n}{2}\) doors exist as initialized V4 pools (address-sorted currencies, D68 params).

**Pair count examples:** \(n=2 → 1\) pool; \(n=3 → 3\); \(n=4 → 6\); \(n=8 → 28\).

### 4.3 Rate scaling (normative)

```text
RATE_PRECISION = 1e18
baseScale[i]   = 10^(36 - decimals(token_i))
oracleRate[i]  = provider == 0
                   ? 1e18
                   : staticcall IRateProvider(provider).getRate()  // fail-closed D18
effectiveRate  = baseScale * oracleRate / RATE_PRECISION

scaleTo(amount, rate)   = floor(amount * rate / 1e18)
scaleToUp(amount, rate) = ceil(amount * rate / 1e18)
descale(scaled, rate)   = floor(scaled * 1e18 / rate)
descaleUp(scaled, rate) = ceil(scaled * 1e18 / rate)
```

**Oracle rules:** fail-closed (D18). Wrong scale silently misprices — config hygiene + tests. Interface = Balancer-style `getRate() returns (uint256)` at 1e18; binding stores **provider addresses only** (no package adapters).

### 4.4 Weighted swap math (normative sketch)

Use Crane vendored **`WeightedMath`** (do not re-derive):

**Exact-in (Balancer fee on input — D21):**

```text
feeWad = feeOracle.dexSwapFeeOfVault(this)   // may be 0
require feeWad < 1e18
bIn  = scaleTo(reserves[in], rateIn)
bOut = scaleTo(reserves[out], rateOut)
// native amountIn from settlement path
amountInNet = amountIn - floor(amountIn * feeWad / 1e18)   // fee residual native stays in book
aInScaled   = scaleTo(amountInNet, rateIn)
require aInScaled <= bIn * 30e16 / 1e18                    // MAX_IN_RATIO
rawOutScaled = WeightedMath.computeOutGivenExactIn(bIn, wIn, bOut, wOut, aInScaled)
amountOut = descale(rawOutScaled, rateOut)                 // floor to user
require amountOut > 0
require reserves[out] > amountOut                          // post floors D56
// Repo: reserves[in] += amountIn (gross); reserves[out] -= amountOut
// return DYNAMIC fee override (D23)
```

**Exact-out:**

```text
// solve net in for desired out (WeightedMath.computeInGivenExactOut)
// amountInGross = ceil(netIn * 1e18 / (1e18 − feeWad))
// MAX_OUT_RATIO on amountOut vs bOut
// Repo: reserves[in] += amountInGross; reserves[out] -= amountOut
```

### 4.5 Fee law — two oracle channels

| Channel | Oracle API | When | Destination |
|---------|------------|------|-------------|
| **Trading** | `dexSwapFeeOfVault(this)` | Every swap (+ previews) | Residual in **input** reserve |
| **Protocol growth** | `usageFeeOfVault(this)` | Every join/exit | **Mint LP → live `feeTo()`** |

```text
feeOracle     = IVaultFeeOracleQuery (immutable on hook; factory-immutable shared)
tradeFeeWad   = feeOracle.dexSwapFeeOfVault(address(this))
usageFeeWad   = feeOracle.usageFeeOfVault(address(this))
feeTo         = address(feeOracle.feeTo())                 // live each LP op
ownerFeeShare = usageFeeWad * 100_000 / 1e18
feeOn         = feeTo != 0 && usageFeeWad != 0 && usageFeeWad < 1e18 && ownerFeeShare != 0

// Full book growth measure:
//   k = V = prod b_i^w_i   (rate-scaled)
//   rootK = V               // D28 literal — not cbrt, not extra root
// Partial: interim product on positive legs (§4.7.3); rootK = k_interim
// protocolLp algebra: D29 (ConstProdUtils / Orbital peer)
```

**Tests:** deploy production Vault Fee Oracle path; set **default** dex swap fee and default usage fee (and feeTo). Per-address overrides optional. Product always calls per-address APIs; oracle falls through to defaults.

**No double-haircut:** economic trading fee is hook residual only; V4 override is informational when custom curve consumes full specified amount.

### 4.6 Liquidity — full book (mirror Balancer)

When **all** `reserves[i] > 0` and `totalSupply > MINIMUM_LIQUIDITY` (or after first mint established full book):

#### 4.6.0 Protocol mint first

On every join/exit: if fee-on and same `kLastMode` and `kLast != 0`, mint protocol LP from pre-op \(V\) vs `kLast` (D29–D30). User share math uses **post-protocol** `totalSupply`.

#### 4.6.1 First mint

```text
require totalSupply == 0
// Preferred production path: all n amounts > 0 (enter FullProduct immediately)
// Allowed for n ≥ 3: ≥2 positive legs (partial first mint — §4.7)
// Required for n = 2: both legs > 0 (only one door; no partial first mint)

scaled[i] = scaleTo(amounts[i], rate[i]) for positive legs

// Full first mint (all n > 0):
  V = WeightedMath.computeInvariantDown(weights, scaled)   // peer name
  require V > MINIMUM_LIQUIDITY
  shares = V - MINIMUM_LIQUIDITY                           // O2 default
  mint MIN to address(0); pull; set reserves; set kLast/mode if feeOn

// Partial first mint (n ≥ 3 only): §4.7.7
```

**Normative intent for full first mint:** initial supply tracks rate-scaled weighted invariant, minus dead shares. Implementation plan freezes exact function names and rounding vs Crane `WeightedMath` so preview==exec.

#### 4.6.2 Proportional join / exit

Balancer `computeProportionalAmountsIn` / `Out` peer: shares ↔ pro-rata legs; no taxable fee (or fee=0 path). Slippage: `sharesMin` / `amountsMin`. **Exit (full book):** post-state **all** `reserves[i] > 0` (D67) — if proportional remove would zero any leg, **revert** (user must leave residual or use path that preserves floors).

#### 4.6.3 Unbalanced multi-asset join (exact amounts in)

Peer `BasePoolMath.computeAddLiquidityUnbalanced`:

1. Protocol mint.  
2. Apply amounts to balances; compute invariant ratio; enforce max ratio.  
3. Charge **swap fee** on **taxable** (above-proportional) portion of each leg.  
4. Recompute invariant with fees applied; mint BPT = `supply * (V' − V) / V` (round down).  
5. Require shares ≥ min; update Repo; set `kLast`.

#### 4.6.4 Single-asset join

- **Exact token in → BPT out:** special case of unbalanced (one positive amount).  
- **Exact BPT out → token in:** peer `computeAddLiquiditySingleTokenExactOut` (invariant ratio from supply; fee on taxable).

#### 4.6.5 Exits

- Proportional exact BPT in (subject to D67 floors).  
- Single-token exact BPT in / exact token out with taxable fee + min invariant ratio (subject to D67).  
- Unbalanced multi where BasePoolMath peer supports (subject to D67).  
- Protocol mint first.  
- **Never** leave full book with any `reserves[i] == 0` via these paths.

#### 4.6.6 Caps (normative)

| Cap | Value |
|-----|--------|
| Max swap in/out vs balance | **30%** (`_MAX_IN_RATIO` / `_MAX_OUT_RATIO`) |
| Max invariant growth (add) | **300%** (`_MAX_INVARIANT_RATIO`) |
| Min invariant after remove | **70%** (`_MIN_INVARIANT_RATIO`) |

### 4.7 Partial book — allowed Balancer divergence (normative)

**Definition:** any bound index \(i\) with `reserves[i] == 0`.

#### 4.7.1 Why diverge

Balancer Weighted **cannot** compute \(V\) if any \(b_i = 0\). This hook still wants:

- Deploy all pair doors before full capitalization.  
- Seed legs over time (**\(n \ge 3\)**).  
- Swap on any **swap-live** funded pair while other legs are empty.

Partial book is **not** entered by draining a full book (D67).

#### 4.7.2 Modes

| Mode | Condition | `k` / `rootK` | LP surface |
|------|-----------|---------------|------------|
| **`FullProduct`** | All \(n\) reserves \(> 0\) | \(V = \prod b_i^{w_i}\); **`rootK = V`** | Full Balancer join/exit (D33–D34) + D67 floors |
| **`PartialInterim`** | Any reserve \(= 0\) | Interim over **positive** legs only (§4.7.3) | **Restricted** — no full Balancer unbalanced requiring global \(V\) |

Repo stores `kLast` and `kLastMode`. **Cross-mode:** if current mode ≠ stored mode, **do not mint** protocol LP from incompatible `kLast` (treat as `kLast == 0` for mint); snapshot post-op mode.

#### 4.7.3 Interim \(k\) (partial)

Normative interim (deterministic, previewable):

```text
Let P = { i | reserves[i] > 0 }
require |P| >= 1 when totalSupply > 0 and any pricing uses interim
// Rate-scale balances in P
// Renormalize weights on P for interim product only:
//   w'_i = w_i * 1e18 / sum_{j in P} w_j    for i in P
// k_interim = prod_{i in P} (b_i ^ w'_i)
// rootK = k_interim   // literal product measure, same as full rootK=V style
```

**Rationale:** keeps a weighted product measure on the live sub-book without inventing Option B per-pair weights. Global \(w_i\) remain the binding weights for swaps (Balancer swap does **not** renormalize pair weights).

**Rejected for v1:** sum-of-balances interim (Orbital sphere-specific). Prefer weighted product on positive subset.

#### 4.7.4 Swap under partial

Allowed iff `reserves[in] > 0` and `reserves[out] > 0`. Math = full WeightedMath on those two legs + global \(w_{in}, w_{out}\). Empty legs ignored. Post floors D56.

#### 4.7.5 LP under partial (restricted)

| Op | Allowed? |
|----|----------|
| Seed zero legs (`amounts[i] > 0` for some `reserves[i]==0`) | **Yes** — pull full seed amounts; share mint §4.7.6 |
| Proportional over **positive** subset only | **Yes** — min-ratio on \(P\) |
| Balancer unbalanced / single-asset requiring full \(V\) | **No** — revert until full book |
| Remove proportional (all positive legs + zeros pay 0) | **Yes** — must leave ≥1 positive leg if supply remains after remove (excluding dead MIN accounting) |
| Single-asset exit that would require full \(V\) | **No** until full |
| Zero a previously positive leg on exit (partial mode) | **Allowed** only if post-state still has ≥1 positive leg when user supply remains; dust rules peer Orbital residual MIN when only dead liquidity left |

#### 4.7.6 Partial share mint (seed / prop subset)

**Normative sketch (plan freezes bit-exact — O4):**

```text
1. Protocol mint if feeOn && same PartialInterim mode
2. Determine used amounts:
   - Seed set Z = {i | r_i==0 && amount_i>0}: used_i = amount_i
   - Prop set P+ = {i | r_i>0 && amount_i>0}: Uni V2 min-ratio in rate-scaled units on P+
3. Share mint: supply' * (k_after_positive - k_before_positive) / k_before_positive
   using interim product on positive legs **after** applying used amounts to a working balance vector
   (zeros that remain zero excluded; newly seeded enter product after seed)
4. require shares >= sharesMin; update reserves; set kLast/mode
```

When seed completes all zeros → **FullProduct**: after op, set mode FullProduct and `kLast = V_full`.

#### 4.7.7 First mint partial

| \(n\) | First mint rule |
|-------|-----------------|
| **2** | **Both** legs **must** be \(> 0\). Partial first mint **forbidden** (only one door; full book required). |
| **≥ 3** | Require **≥ 2** positive legs; zeros allowed on other legs. |

```text
// n ≥ 3 partial first mint:
shares from interim product on positive legs (O2/O4 bit-exact in plan)
require shares > 0 after subtracting MINIMUM_LIQUIDITY
lock MINIMUM_LIQUIDITY to address(0)
no protocol mint; set kLast/mode if fee-on (PartialInterim)
```

#### 4.7.8 Returning to partial from full

**Forbidden as a product path (D67).** Full-book exits must not zero any leg. Therefore `FullProduct → PartialInterim` via remove **does not occur** in correct operation.

If an invariant violation ever left a zero under full mode, treat as **fatal** (tests assert unreachable). No “optional allow zeroing” branch.

**How partial exists:** only via **partial first mint / incomplete seed** for \(n \ge 3\), then seed to full.

### 4.8 Hook permissions

| Flag | Enabled | Behavior |
|------|---------|----------|
| `beforeInitialize` | yes | Enforce **factory door** rules (D68): currencies ⊂ bound set, distinct, **`fee == DYNAMIC_FEE_FLAG`**, **`tickSpacing == 1`**, hooks==this |
| `afterInitialize` | no | — |
| `beforeAddLiquidity` | yes | **Revert** |
| `beforeRemoveLiquidity` | yes | **Revert** |
| `beforeSwap` | yes | Weighted pricing + residual fee |
| `beforeSwapReturnDelta` | yes | Custom amounts |
| `beforeDonate` | yes | **Revert** |
| all after* / after*ReturnDelta | no | — |

### 4.9 Settlement (normative intent)

Pattern-copy single/dual buffer and Orbital Target peers (do **not** inherit `DeltaResolver`):

```text
// inside PoolManager.unlock / beforeSwap path (exact peer order in plan):
// 1. onlyPoolManager guard
// 2. reentrancy lock
// 3. load Repo + rates; compute amountIn/amountOut + fee residual (D21)
// 4. update Repo reserves before external token movement where peer does
// 5. take input currency from pool / settle; transfer output; sync+settle
// 6. return BeforeSwapDelta matching specified + unspecified deltas
// 7. return dynamic fee override (D23)
// do NOT mint protocol LP or update kLast on swap (D30)
```

---

## 5. Package surface (normative file plan)

```text
contracts/hooks/uniswap/v4/weighted/
  UNISWAP_V4_WEIGHTED_SWAP_HOOK_PRD.md                           # this file
  UNISWAP_V4_WEIGHTED_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on

  interfaces/
    IUniswapV4WeightedSwapHook.sol
    IUniswapV4WeightedSwapHookFactory.sol

  UniswapV4WeightedSwapHookMath.sol
  UniswapV4WeightedSwapHookRepo.sol
  UniswapV4WeightedSwapHookCommon.sol
  UniswapV4WeightedSwapHookTarget.sol
  UniswapV4WeightedSwapHook.sol

  UniswapV4WeightedSwapHook_FactoryService.sol
  UniswapV4WeightedSwapHookFactory.sol

  # FORBIDDEN:
  #   *Facet.sol, *DFPkg.sol for hook or factory (v1)
  #   Solidity inheritance of BaseHook / DeltaResolver
  #   Second CREATE3 infrastructure
```

### 5.1 Repo layout sketch (informative)

```solidity
struct Layout {
    uint256[] reserves;          // raw token units, length n
    // immutables preferred on wire: poolManager, feeOracle, tokens, weights, rateProviders, n
    uint256 kLast;
    uint8 kLastMode;             // FullProduct | PartialInterim
    string name;
    string symbol;
    // ERC-20 storage coherent with Solady/Crane / Uni V2–style helpers
}
```

### 5.2 Interface sketch (informative — names may tighten in plan; behavior is law)

```solidity
interface IUniswapV4WeightedSwapHook {
    function poolManager() external view returns (IPoolManager);
    function feeOracle() external view returns (IVaultFeeOracleQuery);
    function numTokens() external view returns (uint256);
    function tokens() external view returns (address[] memory);
    function token(uint256 index) external view returns (address);
    function getNormalizedWeights() external view returns (uint256[] memory);
    function rateProvider(uint256 index) external view returns (address);
    function effectiveRate(uint256 index) external view returns (uint256);

    function reserves() external view returns (uint256[] memory);
    function reserveOf(address token) external view returns (uint256);

    function dexSwapFee() external view returns (uint256); // WAD passthrough
    function usageFee() external view returns (uint256);
    function feeTo() external view returns (address);
    function kLast() external view returns (uint256);
    function kLastMode() external view returns (uint8);
    function isFullBook() external view returns (bool);

    // --- previews ---
    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external view returns (uint256 amountOut);
    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external view returns (uint256 amountIn);

    function previewJoinProportional(/* ... */) external view returns (/* ... */);
    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        external view returns (uint256 shares);
    function previewJoinUnbalanced(uint256[] calldata amounts)
        external view returns (uint256 shares);
    function previewExitProportional(uint256 shares)
        external view returns (uint256[] memory amounts);
    // + other Balancer-equivalent previews (growth-aware)

    // --- LP execute ---
    // All mutators: deadline; Permit2 data on pull paths (D40/D70)
    // Exit: burn msg.sender only (D71); payout to `to`
    function joinProportional(/* ... */, uint256 deadline, bytes calldata permit2Data) external returns (/* ... */);
    function joinSingleAssetExactIn(/* ... */, uint256 deadline, bytes calldata permit2Data) external returns (/* ... */);
    function joinSingleAssetExactOut(/* ... */, uint256 deadline, bytes calldata permit2Data) external returns (/* ... */);
    function joinUnbalanced(/* ... */, uint256 deadline, bytes calldata permit2Data) external returns (/* ... */);
    function exitProportional(/* shares, mins, to, deadline */) external returns (/* ... */);
    function exitSingleAsset(/* ... */, uint256 deadline) external returns (/* ... */);
    // exitUnbalanced if in DoD parity with Balancer peer surface
}
```

LP ERC-20: `name`, `symbol`, `decimals` (18), `totalSupply`, `balanceOf`, `transfer`, `approve`, `permit`, …

### 5.3 On-chain factory (normative intent)

```solidity
interface IUniswapV4WeightedSwapHookFactory {
    event HookDeployed(
        address indexed deployer,
        address indexed hook,
        address poolManager,
        address feeOracle,
        uint8 numTokens
        // + binding hash optional in plan
    );
    event PairPoolsEnsured(address indexed hook, uint8 createdCount, uint8 alreadyLiveCount);

    function poolManager() external view returns (IPoolManager);
    function feeOracle() external view returns (IVaultFeeOracleQuery); // factory-immutable
    function create3Factory() external view returns (ICreate3FactoryProxy);

    /// @dev Primary path: caller supplies off-chain-mined mineNonce (D48/D69).
    function deployWithMineNonce(
        address[] calldata tokens,           // strict ascending, length 2..8
        uint256[] calldata normalizedWeights,
        address[] calldata rateProviders,    // IRateProvider or 0, same length
        string calldata saltNamespace,       // empty → default
        uint256 mineNonce
    ) external returns (address hook, PoolKey[] memory poolKeys);

    /// @dev Optional convenience wrapper if plan adds it — still requires off-chain mine inputs.
    /// Not a gas-heavy on-chain mine loop.

    function ensurePairPools(address hook)
        external
        returns (PoolKey[] memory poolKeys, uint8 createdCount);

    function pairPoolKeys(address hook) external view returns (PoolKey[] memory);
    function isDeployedByFactory(address hook) external view returns (bool);
    function predictHookAddress(/* binding + namespace + mineNonce */) external view returns (address);
}
```

**Rules:**

| Rule | Law |
|------|-----|
| Permissionless | No owner gate on deploy / ensure |
| feeOracle | **Factory immutable** — not a `deploy*` argument (D32) |
| Atomic deploy | Hook + **all** \(\binom{n}{2}\) pools or full revert |
| PoolKey | address-sorted pair, `fee=DYNAMIC_FEE_FLAG`, `tickSpacing=1`, `hooks=hook` |
| ensure scope | **Factory-attested hooks only** |
| No LP | Factory never moves ERC-20 inventory |
| Events | `HookDeployed` only when **new** bytecode created |
| Mine | **Off-chain** mineNonce primary (D48/D69) |

**Bootstrap (ops, once per chain):** deploy factory with immutable `(create3Factory, poolManager, feeOracle)`; grant factory CREATE3 operator rights as required by ecosystem policy.

### 5.4 FactoryService

Salt + flag checks + `isExpectedHook` + `deployHook` pure/internal helpers used by factory and tests. Default namespace D46. CREATE3 prediction uses ecosystem factory as deployer peer (O1). Document exact ABI of `predictHookAddress` in plan.

### 5.5 Events and errors (minimum — plan freezes exact signatures)

**Factory events**

| Event | When |
|-------|------|
| `HookDeployed` | New hook bytecode created + doors initialized |
| `PairPoolsEnsured` | Repair path created missing doors |

**Hook events (minimum)**

| Event | When |
|-------|------|
| `ProtocolFeeMinted(address feeTo, uint256 shares)` | Growth mint \(> 0\) |
| Join/exit events | Include shares and per-leg used amounts (names free in plan) |

**Errors (minimum set)**

| Domain | Examples |
|--------|----------|
| Binding | `InvalidToken`, `InvalidWeight`, `InvalidN`, `TokensNotSorted` |
| LP | `DeadlineExpired`, `ZeroAmount`, `Slippage`, `NotFullBook`, `PartialPathRestricted`, `WouldZeroReserve` |
| Swap | `PairNotLive`, `MaxInRatio`, `MaxOutRatio` |
| Fees / rates | `InvalidFeeWad`, `RateProviderFailed` |
| Init / factory | `InvalidPoolKey`, `NotFactoryHook` |
| Safety | `Reentrancy` / lock error peer |

---

## 6. Operational / safety requirements

1. Token decimals ∈ **[6, 18]**; reject outside at deploy.  
2. Weights: each ≥ 1%, sum exact `1e18`.  
3. No rebasing / fee-on-transfer.  
4. Rate providers return `uint256` @ 1e18; fail-closed.  
5. Trading fee WAD **&lt; 1e18**; **0 allowed**.  
6. Max 30% swap in/out vs balance.  
7. Unbalanced join/exit invariant ratio caps.  
8. Remove always available for LP holders (including `feeTo`), subject to D67 floors on full book.  
9. Accounting before external transfers; reentrancy lock.  
10. Partial book: do not call full \(V\) join paths; dual-mode growth only.  
11. Oracle is SoT for fee rates; do not cache fees across txs.  
12. Amp/weight admin: **none**.  
13. Full-book remove must not zero any reserve leg (D67).  
14. Only factory-door PoolKeys initialize (D68).

---

## 7. Testing expectations (production-first)

1. **No mock of SUT** (hook, Math, Repo, Factory under test).  
2. **Real V4 PoolManager** (hermetic or fork).  
3. **Real Vault Fee Oracle**: deploy via project path; set **default** `dexSwapFee` and `usageFee` (+ feeTo). Exercise default fallthrough **and** optional per-address override.  
4. Gold TestBase: `TestBase_UniswapV4WeightedSwapHook`.  
5. Allowed harnesses: mintable ERC20; optional reentrancy ERC20 for adversarial suite.  
6. Cover at least:
   - Factory deploy for \(n \in \{2,3,4,8\}\) (or matrix sample); **all** pair doors  
   - Off-chain mine + `deployWithMineNonce`; predict address matches  
   - Sorted tokens enforced; bad weights revert  
   - Idempotent deploy; ensurePairPools factory-only  
   - First mint full; first mint partial (\(n\ge3\)); \(n=2\) rejects partial first mint  
   - Full-book: proportional join/exit; single-asset join; unbalanced join; exact BPT out paths  
   - Full-book exit that would zero a leg **reverts** (`WouldZeroReserve` peer)  
   - Partial: seed legs; swap on funded pair; full Balancer join reverts until full; mode switch seed→full  
   - Exact-in/out swaps on multiple doors; 30% ratio revert  
   - Trading fee 0 and non-zero; residual in input reserve  
   - Protocol growth mint on add and remove; **`rootK = V`**; preview includes dilution; `ProtocolFeeMinted`  
   - Cross-mode: no bogus mint  
   - Rate provider path + fail-closed  
   - DYNAMIC_FEE_FLAG only on init; wrong fee/tickSpacing reverts  
   - CL add/remove/donate revert  
   - Donation ignored  
   - Permit2 join path  
   - Deadline expiry reverts  
   - Exit burns msg.sender only  
   - preview == execution  
   - Mixed decimals  
7. Forks: **Base** + **Robinhood Chain** — production PM/CREATE3/oracle integration; mintable tokens OK.  
8. Optional comparative: quotes vs Balancer WeightedPool fixture for same balances/weights/fees (full book).

---

## 8. Definition of Done

- [ ] Package files under `contracts/hooks/uniswap/v4/weighted/` match §5 (hook **and** factory).  
- [ ] CREATE3 FactoryService + permissionless factory; ecosystem CREATE3; **off-chain mine** primary; no BaseHook inherit; no Facet/DFPkg.  
- [ ] Factory creates hook + **all** \(\binom{n}{2}\) pools; `ensurePairPools` factory-only; factory-immutable feeOracle.  
- [ ] Repo storage + Target settle pattern-copy (§4.9).  
- [ ] WeightedMath swaps + Balancer-equivalent joins/exits on full book.  
- [ ] Partial book dual-mode implemented and tested (§4.7); **no full-book leg zeroing** (D67).  
- [ ] Vault Fee Oracle dual channel: `dexSwapFeeOfVault` + `usageFeeOfVault` → `feeTo`; **`rootK = V`**.  
- [ ] DYNAMIC_FEE_FLAG + override report; no double-haircut; factory doors only (D68).  
- [ ] Optional IRateProvider fail-closed.  
- [ ] Permit2 + transferFrom LP pull paths; **deadline** on LP mutators; exit burns **msg.sender** only.  
- [ ] Public previews match execution (growth-aware).  
- [ ] Gold TestBase + hermetic suite green.  
- [ ] Fork DoD: Base + Robinhood Chain.  
- [ ] Implementation and test plan document present.  
- [ ] NatSpec + Crane style; no debug logs in production sources.

---

## 9. Security notes (product-level)

1. **Option A weights** avoid inconsistent multi-door arb from per-pair weight vectors.  
2. **Partial book** increases mode complexity — tests must cover seed → full, cross-mode no-mint, and **no** full→partial via exit.  
3. **Oracle liveness:** if fee oracle reverts, swaps/LP that read fees revert (fail closed). Ops must keep oracle healthy.  
4. **Rate providers** are trust-critical; malicious rate can misprice. Fail-closed does not prevent wrong-but-successful rates.  
5. **30% / invariant caps** limit single-tx manipulation and rounding abuse (Balancer heritage).  
6. **Custom curve / NoOp:** V4 fee override must not double-charge.  
7. **Donations** ignored — do not use `balanceOf` for pricing.  
8. **LP dilution** to `feeTo` is intentional protocol revenue; document for integrators.  
9. **`rootK = V`** (literal) can overflow earlier than a rooted measure at large \(n\) / balances — accept and document; tests probe scale bounds.  
10. **Factory-shared feeOracle** means ops/governance of that oracle affects all hooks from the factory.

---

## 10. Implementation plan follow-on

Create:

`contracts/hooks/uniswap/v4/weighted/UNISWAP_V4_WEIGHTED_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`

Suggested plan stages:

1. Math lib + unit tests (swap, invariant, scale, growth algebra with **`rootK = V`**, interim \(k\)).  
2. Repo + Common + wire hook permissions / mine flags.  
3. Swap path + settle + DYNAMIC fee.  
4. Full-book LP (prop → single → unbalanced) + D67 floors.  
5. Partial-book dual mode (seed → full only).  
6. Factory + off-chain mine + all doors + ensure.  
7. Permit2 packing + deadline + msg.sender burn.  
8. Fee oracle integration tests (defaults).  
9. Gold TestBase + matrix \(n\).  
10. Fork Base + Robinhood.  
11. Adversarial (reentrancy, donation, ratio caps, rate fail, would-zero-reserve).

---

## 11. Changelog

| Version | Date | Notes |
|---------|------|-------|
| **v0.1.0** | 2026-08-03 | Initial PRD from design Q&A: Option A weights; \(n\in[2,8]\); all pair doors; Balancer WeightedMath + joins/exits; Vault Fee Oracle dual channel; DYNAMIC_FEE_FLAG; partial book dual-mode as allowed Balancer divergence; Permit2; on-chain factory; name `UniswapV4WeightedSwapHook`. |
| **v0.2.0** | 2026-08-03 | Quality/clarity pass. Authority + law index. Locked: ecosystem CREATE3 + **off-chain mine** primary; **factory-immutable feeOracle**; **`rootK = V` literal**; **forbid full-book exit zeroing**; **factory doors only**; LP **deadline** + **msg.sender burn**. Fixed \(n=2\) first-mint law; added settle, events/errors; residual opens demoted to plan-level O1–O6. |

---

## 12. Decision log (stakeholder)

| Topic | Decision |
|-------|----------|
| Weight model | Option A global vector |
| Protocol fee field | `usageFeeOfVault` |
| Growth mint timing | Add **and** remove (peer) |
| Growth measure | Weighted invariant \(V\) (full); interim product on positive legs (partial) |
| Growth `rootK` | **`V` literal** (full); interim product (partial) |
| Trade fee method | Balancer input residual |
| PoolKey fee | DYNAMIC_FEE_FLAG |
| Zero swap fee | Allowed; oracle SoT |
| Join surface | Mirror Balancer (prop, single, unbalanced, exact BPT) |
| Exit surface | Mirror Balancer + **no full-book leg zeroing** |
| Caps | Mirror Balancer |
| Zap | Not needed |
| \(n\) | 2–8 |
| Doors | All pairs on deploy; **factory doors only** thereafter |
| feeOracle | Factory **immutable**; shared by all hooks; `feeTo()` live |
| Rates | Optional IRateProvider; fail-closed |
| FOT/rebase | Forbidden |
| Partial book | Allowed via seed/first mint (\(n\ge3\)); not via full exit |
| CREATE3 | Ecosystem `create3Factory` + **off-chain mined** values |
| Name / path | `UniswapV4WeightedSwapHook` / `weighted/` |
| Factory | On-chain, co-located |
| Permit2 | Required on LP pulls |
| LP deadline | Required on mutators |
| LP burn | `msg.sender` only on exit |
