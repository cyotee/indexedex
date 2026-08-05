# PRD: Uniswap V4 Standard Exchange Weighted Buffer Hook

**Name:** `UniswapV4StandardExchangeWeightedBufferHook`  
**Date:** 2026-08-05  
**Status:** **Draft v0.3 — product law (plan-ready)**  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/weighted/`  
**Package kind:** IndexedEx **Uniswap V4 hook diamond package** that is **also** a vault-compatible multi-asset surface. Instance deploys via the **shared Hook Diamond Package Callback Factory** + Vault Registry `deployHookVault` (CREATE2-mined proxy). **Not** a concentrated-liquidity (CL) reimplementation. **Not** the raw-inventory monomorph `UniswapV4WeightedSwapHook` under `contracts/hooks/uniswap/v4/weighted/`.

**Decision ID note:** `D*`, `O*`, `Q*`, and `P*` IDs are **stable keys**, not document order.  
**v0.2 locks:** residual P1–P6 from stakeholder Q&A.  
**v0.3 locks:** Q7–Q12 — LP domain = SE-native inventory (not claim/RP); one-token path = Balancer single-asset join/exit (depositSingle aliases join); no multi-leg rebalance zap; exact-out single-asset only if closed-form else drop; MultiAssetLiquidity full matrix; factory-immutable PM+oracle; join mint to `to`, refunds to `msg.sender`.

**Authority (normative):**

| Layer | Role |
|-------|------|
| **This PRD** | Product law for SE-buffered weighted topology, per-leg optional SE + optional rate provider, swap-only rate scaling, native LP accounting, buffer/unwrap, full weighted join/exit surface, zap-in, SE In/Out (+ zap-out and multi-token SE liquidity extensions), fees, deploy shape |
| **Implementation plan** (follow-on) | Source of truth for coding phases once written against this PRD |
| Weighted product PRD | **Curve / weights / doors / partial book / join-exit surface / fee dual-channel / caps / settle** behavioral reference — do **not** subclass; do **not** copy monomorph CREATE3 factory law |
| Dual SE Buffer CP PRD | **Buffer / unwrap / claim-in composition / buffer-last process** reference — do **not** subclass; adapt from 2-leg CP to **n-leg weighted** |
| SE Orbital Buffer PRD | **Multi-leg optional SE slots, distinct SE binding, diamond package shape, SE In/Out funding, vault discovery** process/shape reference — do **not** subclass; curve is **weighted**, not sphere; **this product requires ≥1 SE** (not zero-SE pure raw) |
| Hook factory PRD | **Deploy / salt / flags / immutability law** — `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Skill | `indexedex-uniswap-v4-hook-packages` |

**Sibling packages (do not conflate):**

| Package | Path | Role |
|---------|------|------|
| **Weighted Swap Hook** (raw) | `contracts/hooks/uniswap/v4/weighted/` | 2–8 asset Balancer weighted curve on **raw ERC-20** inventory; all pair doors; **no** SE buffering |
| **Dual SE Buffer CP Hook** | `…/standardExchange/dual/` | **Two** SEs; CP on both claims; **one** V4 pair |
| **Single SE Buffer CP Hook** | `…/standardExchange/constantProduct/single/` | One SE + one raw leg; CP; one door |
| **SE Orbital Buffer Hook** | `…/standardExchange/orbital/` | Three tokens; optional SE per leg; **sphere** AMM |
| **This package** | `…/standardExchange/weighted/` | **2–8** tokens; **≥1 SE**; optional SE per remaining leg; **weighted** AMM on **rated swap balances**; native LP accounting; **all** \(\binom{n}{2}\) doors |

**Related references:**

- Weighted product law: `contracts/hooks/uniswap/v4/weighted/UNISWAP_V4_WEIGHTED_SWAP_HOOK_PRD.md`
- Dual SE BCP: `…/dual/UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`
- SE Orbital Buffer: `…/orbital/UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md`
- Crane Balancer WeightedMath / BasePoolMath (math peers only)
- SE rate providers (composition tooling): `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`
- Fee oracle: `contracts/interfaces/IVaultFeeOracleQuery.sol`
- Permit2: Uniswap well-known `0x000000000022D473030F116dDEE9F6B43aC78BA3`
- AGENTS.md — production-first tests; CREATE3 facets; hook instances via hook factory; no mock SUT

---

## 0. Terminology (normative)

| Term | Meaning in this PRD |
|------|---------------------|
| **Binding order** | Deploy/init order `tokens[0..n-1]` — **strict address ascending** (weighted peer). Weights, SE slots, rate providers, reserves, LP views, events, Permit2 batch index order use this index |
| **Pool currency order** | V4 `currency0` / `currency1` = pair tokens **sorted by address** (always matches binding for a given pair since binding is address-sorted) |
| **Pool token / leg token** | One of the \(n\) ERC-20s registered as Uniswap V4 pool currencies. **Never** SE share addresses as pool currencies |
| **Raw leg** | Leg with `standardExchange[i] == address(0)`. Hook holds **face ERC-20** inventory as that leg’s book |
| **Buffered leg / SE leg** | Leg with non-zero `standardExchange[i]`. Hook holds **SE shares**; free pool-token balance is **not** book (dust/refund only) |
| **Standard Exchange / SE** | Bound `IStandardExchange` for a leg; **at most one SE per token**; optional per leg; **at least one** non-zero SE in the instance; **non-zero SE addresses pairwise distinct** |
| **SE claim / claim supply** | Pool-token value of hook-held SE shares via fee-inclusive SE unwrap preview: \(c_i = \mathrm{previewExchangeIn}(SE_i,\ seBal_i,\ token_i)\) |
| **Rate provider** | Optional Balancer-style `IRateProvider` **per SE leg only** (`address(0)` = none). Purpose: **accurately value SE vault inventory as the pair token** for **swap pricing**. Must be consistent with that leg’s pair token (share → pair-token units @ 1e18) |
| **Native inventory / native balance** | Physical book for **all liquidity accounting**: raw face ERC-20 for raw legs; **SE vault share balance** for buffered legs. LP mint/burn, join/exit, first-mint \(V\), and `kLast` use **only** these units (plus decimal→WAD). **Not** live SE claim, **not** `getRate()`. Changing SE share price / claim / RP **must not** by itself mint/burn LP or rewrite ownership |
| **Rated balance \(b_i^{\mathrm{rated}}\)** | Balance fed into **WeightedMath for swaps only** (V4 doors, SE In/Out swap paths, internal swap legs if any): face / shares×rate / claim per §4.3. **Never** enters join/exit/zap LP algebra |
| **One-token entry / exit** | Balancer **single-asset** join/exit on the native inventory domain. **`depositSingle` is an alias** of single-asset join (no multi-leg internal rebalance). **`withdrawSingle`** aliases single-asset exit (exact BPT in). Exact-token-out single-asset exit only if closed-form exists (Q9) |
| **Inventory** | Physical holdings: raw ERC-20 for raw legs; SE share balances for buffered legs |
| **Hook LP / shares** | Fungible ERC-20 on **this** hook (18 decimals). API params named `shares` mean **hook LP**, never SE vault shares |
| **Full book** | All \(n\) **native inventory** legs \(> 0\) (and, for swap-live directed pairs, rated balances \(> 0\)) — mirror weighted “full book” |
| **Partial book** | At least one leg has native inventory \(= 0\) (and `totalSupply > 0` after seed). Dual-mode rules mirror weighted §4.7 |
| **Factory doors** | All \(\binom{n}{2}\) Uni V4 pair pools created at deploy: `fee = DYNAMIC_FEE_FLAG`, `tickSpacing = TICK_SPACING` (1), `hooks = this`. **Only** these keys may initialize against the hook |
| **Buffer-last** | Quote / size / residual math on **pre-buffer** book; execute non-buffer moves; **buffer pair→SE as final SE inventory step**; then LP mint / `kLast` from **post-buffer** native inventory |
| **Claim-in / claim-out** | SE fee-inclusive preview of how much **SE shares** a raw pool-token buffer mints / how much token an unwrap delivers — not assumed 1:1 with raw amount |
| **Zap-eligible** | Full book **and** `totalSupply > MINIMUM_LIQUIDITY` (same gate as Weighted full-book single-asset paths) |
| **Zap-in (alias)** | **`depositSingle` ≡ Balancer single-asset join** (exact token in → BPT out, taxable). **No** multi-leg internal rebalance. Name kept for SE/UX familiarity |
| **Zap-out exact shares (alias)** | **`withdrawSingle` ≡ Balancer single-asset exit** (exact BPT in → one token out). **No** multi-leg force-sell basket |
| **Zap-out exact out** | **`withdrawSingleExactOut` ≡ Balancer single-asset exact-token-out** **only if** WeightedMath / BasePoolMath peer admits a **closed-form** path with preview==exec. If not, **omit from v1 DoD** (Q9) — do **not** binary-search |
| **IStandardExchangeMultiAssetLiquidity** | Dedicated SE-family extension interface for multi-token deposit/withdraw + zap-in/out. Canonical `IStandardExchangeIn` / `Out` remain **swap-only** |
| **DoD** | Definition of Done — package complete when §11 is satisfied |

**Role naming:** use `token(i)`, `standardExchange(i)`, `rateProvider(i)`, `nativeReserve(i)`, `ratedBalance(i)` — **no** brand tickers; **no** DETF-specific type names on the hook ABI.

---

## 1. Goal

Ship a **production-first Uniswap V4 hook package** that:

1. Binds **\(n \in [2, 8]\)** ERC-20 pool tokens, one V4 `PoolManager`, and one Vault Fee Oracle per instance.
2. Implements **Balancer Weighted Pool math** with a **global** immutable weight vector (Option A):
   \[
   V = \prod_{i=0}^{n-1} b_i^{w_i},\quad \sum w_i = 1\mathrm{e}18,\quad w_i \ge 1\%
   \]
   on the appropriate balance domain per surface (rated for swaps; native for LP — §4.3).
3. For **each** pool token, accepts an **optional** Standard Exchange into which that token is **buffered** when non-zero — **at most one SE per token**; **non-zero SE addresses pairwise distinct**; **at least one** leg **must** be buffered (else use raw `UniswapV4WeightedSwapHook`).
4. For **each** non-zero SE, accepts an **optional** Balancer-style **`IRateProvider`** that values **SE shares as the pair token** for **swap** pricing only.
5. Exposes **all** \(\binom{n}{2}\) Uni V4 pair pools as swap doors into the **same** shared \(n\)-asset book (factory/postDeploy creates all doors).
6. **Buffers** pool tokens into the bound SE on liquidity add and on swap token-in when that leg is buffered; **unwraps** SE → pool token on liquidity remove and on swap token-out when that leg is buffered — **buffer-last** and share/claim composition (dual / SE Orbital process peer).
7. Holds inventory as: **raw ERC-20** for raw legs + **SE shares** for buffered legs. Pool currencies remain the \(n\) tokens — **never** SE share addresses.
8. Mints a **single fungible ERC-20 LP** representing pro-rata claim on all inventory components (raw balances + SE share balances).
9. Mirrors the **full weighted join/exit surface** of the unbuffered Weighted Hook as closely as feasible: proportional, single-asset, unbalanced multi-asset, exact-BPT-out joins; matching exits; invariant-ratio and max-in/out caps; **partial book** dual mode.
10. Provides one-token LP paths as **Balancer single-asset join/exit** with UX aliases **`depositSingle` / `withdrawSingle`** (and exact-out only if closed-form — Q9). **No** multi-leg internal rebalance “zap” (unlike dual / SE Orbital).
11. Exposes **`IStandardExchangeIn` / `IStandardExchangeOut`** for tokenᵢ ↔ tokenⱼ **swaps**, **plus** **`IStandardExchangeMultiAssetLiquidity`** mirroring the **full** weighted join/exit matrix including one-token aliases (§5.4).
12. Settles public swaps via **`beforeSwap` + `beforeSwapReturnDelta`** — pattern-copy settle; **no** inheritance of OZ/`BaseHook` / `BaseTokenWrapperHook` / `DeltaResolver`.
13. Deploys as an **immutable hook diamond package** via registry `deployHookVault` + shared hook factory (CREATE2 + `mineNonce`); initializes **all** factory doors in postDeploy.
14. Uses **live Vault Fee Oracle** dual-channel rates: `dexSwapFeeOfVault` = trading residual (Balancer **input** fee); `usageFeeOfVault` = protocol growth LP mint to `feeTo`.

### 1.1 Canonical user story (n=4, two SE legs)

```text
Binding (example):
  tokens  = [A, B, C, D]   // address ascending
  weights = [0.40e18, 0.30e18, 0.20e18, 0.10e18]
  SE      = [SE_A, 0, SE_C, 0]     // ≥1 SE; SE_A ≠ SE_C
  RP      = [RP_A, 0, 0, 0]        // RP only allowed where SE set
  require A ∈ SE_A.vaultTokens(), C ∈ SE_C.vaultTokens()
  require RP_A values SE_A shares as token A (pair-token units @ 1e18)

Uniswap V4 doors (all 6 pairs), fee = DYNAMIC_FEE_FLAG, hooks = this:
  A/B, A/C, A/D, B/C, B/D, C/D

Inventory after liquidity:
  hook holds SE_A shares + face B + SE_C shares + face D
  free A/C on hook is dust only (refunded after liquidity ops)

Rated balances for SWAPS (when RP set on SE leg):
  b_A_rated = scale( seBal_A * getRate(RP_A) / 1e18 )   // SE valued as A
  b_B_rated = scale( face_B )
  b_C_rated = scale( claim_C )                            // no RP → SE claim
  b_D_rated = scale( face_D )
  WeightedMath exact-in/out on (b_in, w_in, b_out, w_out) only

LP joins/exits (NO getRate, NO live claim in algebra):
  inventory = face(B), face(D), seBal(SE_A), seBal(SE_C)
  user-facing amounts = pair tokens; buffer-last / unwrap at edges
  LP ownership is pro-rata of inventory shares/face — SE yield ↑ claim
  does NOT mint/burn LP by itself (Q7)

--- First mint (full book preferred) ---
joinProportional / multi-amount with all legs > 0 preferred
  → pull A,B,C,D; buffer-last A→SE_A, C→SE_C; credit raw B,D
  → mint LP from inventory-domain V − MIN (§4.6 / Q7)
  → set kLast if fee-on

--- Swap A → B via A/B door ---
  take A → claim-in / shares-in composition vs SE_A
  → WeightedMath on **rated** balances + input trading fee residual
  → buffer A into SE_A last; update SE share inventory
  → pay B from raw face inventory

--- One-token entry (full book) ---
depositSingle ≡ joinSingleAssetExactIn(tokenIn, amountIn, …)
  → Balancer taxable single-asset join on **inventory** domain
  → buffer-last if tokenIn SE; mint LP to `to`
  → NO multi-leg internal rebalance (Q8)

--- One-token exit ---
withdrawSingle ≡ exitSingleAssetExactBptIn(shares, tokenOut, …)
  → burn msg.sender LP; single-asset exit math; unwrap if needed; pay `to`

--- Exact-token-out exit (v1 only if closed-form) ---
withdrawSingleExactOut only if BasePoolMath/WeightedMath peer closed-form (Q9)
  else omit from v1 DoD — no binary search

--- SE surfaces ---
exchangeIn / exchangeOut token_i → token_j (swap-only; rated book)
IStandardExchangeMultiAssetLiquidity: full join/exit matrix + one-token aliases

Product thesis:
  Add SE buffering + optional share→token rate valuation for swaps to the
  weighted multi-door Uniswap V4 book — mirror raw Weighted as closely as
  possible while composing yield-bearing SE inventory.
```

### 1.2 Why this exists (product problem)

| Approach | Limitation |
|----------|------------|
| Raw Weighted Hook | Shared n-asset weighted book + all doors, but inventory is **idle** ERC-20 — **no** yield / SE composition |
| Dual SE BCP | SE composition for **two** legs only; **one** door; CP not weighted |
| SE Orbital Buffer | SE composition + multi-door, but **sphere** curve and **fixed n=3** |
| Balancer Weighted + SE RPs | Off Uniswap V4 door topology |
| **This package** | Weighted **curve + all doors + partial book + full join/exit** + **≥1 SE buffer** + optional swap-side rate |

v1 is the **composition layer**: weighted multi-door topology with dual/SE-orbital-style buffering generalized to **n ∈ [2,8]** with **at least one** SE leg.

### 1.3 Product shape (locked)

| Layer | Role |
|-------|------|
| Uniswap V4 | \(\binom{n}{2}\) pair pool identities; **swaps** + currency settlement via hook deltas |
| Hook | Binding (tokens + weights + optional SE + optional RP), full weighted LP surface, zap-in/out, SE In/Out (+ extensions), weighted math, per-leg buffer/unwrap, `beforeSwap` |
| SE vault(s) | Yield-bearing inventory for each **buffered** leg (at most one SE per token; ≥1 required) |
| Rate provider(s) | Optional **swap-side** valuation of SE shares as pair token |
| Concentrated liquidity | **Not used** — native `modifyLiquidity` **forbidden** |
| Book shape | n-leg weighted; **partial book** allowed (weighted peer) |
| LP shape | **One** fungible ERC-20 only |

---

## 2. Product summary

### 2.1 What this package is

| Attribute | Value |
|-----------|--------|
| Primary artifact | CREATE2-mined **hook diamond** (facets + Repo) implementing V4 `IHooks` **plus** n-asset LP ERC-20 + multi-asset vault discovery + SE surfaces |
| Binding | `(poolManager, feeOracle, n, tokens[n], weights[n], standardExchange[n], rateProvider[n])` — set-once at init; **no** post-deploy rebind |
| Pool currencies | The \(n\) bound tokens; postDeploy creates **all** \(\binom{n}{2}\) pair doors |
| Inventory | Per leg: raw ERC-20 **or** SE shares (not both as book for the same leg) |
| Swap balances | **Rated** balances (§4.3) into WeightedMath |
| LP balances | **Native** inventory (§4.3) — **no** `IRateProvider` in join/exit share formulas |
| Pricing (swap) | `WeightedMath.computeOutGivenExactIn` / `computeInGivenExactOut` on the **two trade legs** only (weighted peer) |
| Pricing (LP) | Full-book: Balancer invariant / BasePoolMath-equivalent on **native** path; partial: dual-mode (§4.7) |
| LP | Fungible ERC-20 + EIP-2612; decimals always 18; auto name/symbol |
| Trading fee | Live `dexSwapFeeOfVault(this)` WAD; Balancer **input** residual; 0 allowed |
| Protocol growth | Live `usageFeeOfVault(this)` → mint LP to live `feeTo()` on add **and** remove; `rootK` from full/partial measures (§4.5) |
| V4 PoolKey.fee | **`DYNAMIC_FEE_FLAG`** |
| Deposit / withdraw | Full weighted join/exit surface; one-token paths = Balancer single-asset (aliases depositSingle/withdrawSingle) |
| SE surface | SE In/Out swaps **+** `IStandardExchangeMultiAssetLiquidity` **full** join/exit matrix (§5.4 / Q10) |
| poolManager / feeOracle | **Factory immutables** — shared by all hooks from that factory (Q11); not per-PkgArgs |
| Deploy path | Hook diamond package → registry `deployHookVault` → shared hook factory |

### 2.2 What this package is not

- Not the raw `UniswapV4WeightedSwapHook` monomorph (no SE requirement; CREATE3 factory; no SE In/Out product surface).
- Not Dual SE BCP (not CP; not one-pool-only; n may exceed 2).
- Not SE Orbital Buffer (not sphere; not fixed n=3; **requires ≥1 SE**; **includes zap-out**).
- Not a wrapper-only buffer hook (`underlying ↔ SE` without multi-asset AMM).
- Not Uni V4 concentrated liquidity / Position Manager LP.
- Not a DETF, bond NFT, or rebasing claim package (consumers may compose later — **out of this PRD**).
- Not “SE shares as pool currencies.”
- Not multi-SE per single token; not the same SE address on two legs.
- Not an all-raw (zero SE) configuration — use the unbuffered Weighted Hook instead.
- Not subclassing weighted / dual / orbital / single contracts (fresh codepath; pure libs OK).
- Not applying `IRateProvider` to LP deposit/remove share math.

### 2.3 Non-goals (v1)

1. \(n \notin [2, 8]\) or post-deploy change of \(n\) / token set / weights / SE / RP bindings.  
2. Gradual weight change (LBP).  
3. Morpho / non-SE buffering primitives inside this package.  
4. Native ETH as a pool currency (use WETH).  
5. Fee-on-transfer / rebasing **pool tokens** (unsupported).  
6. Binary-search solvers as primary product law — closed Balancer / closed-form zap only.  
7. Auto-deploying SE vaults or rate providers inside the package.  
8. Owner / pause / admin surface on the **hook instance** after deploy (immutable diamond; fees via oracle only).  
9. Hook/protocol ERC-20 skim buckets (growth is LP mint only; trade residual stays in book).  
10. Treating V4 `sqrtPriceX96` as product mid after init.  
11. Shared TestBases with DETF packages.  
12. Using `dexSwapFeeOfVault` as protocol growth rate (growth uses **`usageFeeOfVault`**).  
13. Rate provider on **raw** legs (RP only valid when SE is set).  
14. Multiple concurrent SEs for the same token **or** the same SE address on multiple legs.  
15. Package-owned global token↔SE registry (binding is **instance-local**).  
16. Mapping canonical `exchangeIn` → mint LP or `exchangeOut` → burn LP without going through the **extended** multi-token / zap selectors (swap selectors remain swap-only).  
17. Zero-SE deployments (must use raw Weighted Hook).  
18. Subclassing peer hook contracts.  
19. Bare monomorph CREATE3 / HookMinerCreate3 as production instance path.  
20. Factory-owned first liquidity seed.  
21. Zeroing any leg via full-book exit while the book remains multi-leg live (weighted D67 peer).  
22. Leaving `console.log` / debug logs in production sources.

### 2.4 Allowed divergence from raw Weighted Hook (explicit)

| Topic | Raw Weighted | This package |
|-------|--------------|--------------|
| Inventory | Raw ERC-20 only | Raw **and/or** SE shares per leg |
| SE requirement | N/A | **≥1** SE leg required |
| Rate on LP | Optional RP scales **all** algebra including LP | RP **swap-only**; LP on **native** inventory |
| Rate on swaps | Optional RP on any token | Optional RP **only on SE legs**; SE claim when buffered + no RP |
| One-token LP | Single-asset join only | Same Balancer single-asset; **aliases** `depositSingle` / `withdrawSingle` (no multi-leg zap) |
| Exact-out one-token exit | Balancer peer | Only if closed-form (Q9); else **out of v1** |
| PM / feeOracle | Factory immutables | **Same** (Q11) |
| SE In/Out | Not present | **Required** + multi-token SE liquidity extensions |
| Deploy | CREATE3 monomorph factory | Hook diamond package + registry + hook factory |
| Package kind | Single contract | Diamond + shared ERC20/vault facets |

When full book is live, join/exit/swap **math structure** should match Balancer Weighted + BasePoolMath behavior as closely as fixed-point peers allow, under the **native vs rated domain split** in §4.3.

---

## 3. Locked product decisions

### 3.1 Identity & binding

| # | Decision | Value |
|---|----------|--------|
| D1 | Product name | **`UniswapV4StandardExchangeWeightedBufferHook`** |
| D2 | Package location | `contracts/hooks/uniswap/v4/standardExchange/weighted/` |
| D3 | Peers | Weighted = curve/doors/partial/joins/fees **behavioral** reference. Dual SE BCP = buffer/unwrap/claim/buffer-last **process** reference. SE Orbital Buffer = multi-leg SE slots / diamond package / SE funding **shape** reference. **No** required inheritance from any |
| D4 | Asset count | **Variable \(n \in [2, 8]\)** fixed at deploy (same as Weighted) |
| D5 | Weight model | **Option A** — one global immutable normalized weight vector |
| D6 | Weights | Each \(w_i \ge\) **`MIN_WEIGHT = 1e16`**; \(\sum w_i =\) **`1e18`** exactly; immutable |
| D7 | SE slots | **Exactly one optional SE per token** — `standardExchange[i]` is `address(0)` **or** one `IStandardExchange` |
| D7a | Minimum SE | **At least one** `standardExchange[i] != 0`** — zero-SE binding **reverts** at deploy/init |
| D7b | Distinct SEs | **When non-zero, SE addresses must be pairwise distinct** |
| D8 | Rate provider slots | **Optional per SE leg only** — `rateProvider[i]` non-zero **only if** `standardExchange[i] != 0`; else must be `address(0)` |
| D8a | Rate provider purpose | Balancer `IRateProvider.getRate()` @ 1e18 = **pair-token units per SE share** for that leg’s pair token. **Swap valuation only** (D20–D22). Must **match** the pair token for that SE (config hygiene + validation where enforceable) |
| D9 | Binding | Set-once at diamond init: `tokens[n]`, `weights[n]`, `standardExchange[n]`, `rateProvider[n]`. **`poolManager` + `feeOracle` from factory immutables** (Q11) — same for every hook from that factory; copied onto instance at deploy. Permit2 = well-known constant (not binding arg) |
| D10 | Token validation | Non-zero; **pairwise distinct**; **strict address ascending**; decimals in **[6, 18]** (weighted peer); standard ERC-20 + USDT-style SafeERC20. Fee-on-transfer / rebasing **unsupported**. **No native ETH** |
| D11 | SE validation (when non-zero) | `token_i ∈ SE_i.vaultTokens()`; `token_i != address(SE_i)`; SE exposes closed-form **token ↔ SE** buffer and unwrap routes with preview == execution; **D7b** distinctness |
| D12 | Empty SE at deploy | **Allowed** (inert SE until first buffer) |
| D13 | Pool set | Package **must create all** \(\binom{n}{2}\) pair pools on successful deploy (postDeploy). Permissionless `ensurePairPools(hook)` may repair. All doors: `hooks = this` |
| D14 | Pool fee (V4 key) | **`LPFeeLibrary.DYNAMIC_FEE_FLAG` only**. Economic trading fee SoT = hook residual math |
| D15 | Native CL | **Forbidden** — `beforeAddLiquidity` / `beforeRemoveLiquidity` **revert** |
| D16 | Donate | **Forbidden** — `beforeDonate` **reverts** |
| D17 | Package shape | **Hook diamond package** (`IUniswapV4HookDiamondPackage` + vault surfaces). Facets via CREATE3; instance via CREATE2 mine + hook factory. **Immutable** after postDeploy (no live `diamondCut`) |
| D18 | Hook inheritance | **No** inheritance of Crane/OZ `BaseHook`, `BaseTokenWrapperHook`, `DeltaResolver` — full **pattern-copy** settle. May use Crane facet bases for diamond plumbing |
| D19 | Shared facets | Cut **ERC20PermitDFPkg** facets (`ERC20Facet` + `ERC5267Facet` + `ERC2612Facet`) + MultiAsset Basic/Standard vault facets for LP + discovery. Product facets = hooks + book + join/exit/zap + SE buffer routes only |
| D19a | Full type/file names | Full product names on contracts/files; short labels OK in prose. LP symbol prefix may be short (D46) |

### 3.2 AMM, reserves, SE composition, rates

| # | Decision | Value |
|---|----------|--------|
| D20 | AMM model | **Balancer WeightedMath** on **rated** balances for **swaps** (and swap previews / SE In/Out swap paths). **Not** StableSwap / Orbital / CP |
| D21 | Native inventory SoT | **Repo** authoritative: `nativeReserve[i]` = intentional **raw face** **or** intentional **SE share balance**. Donations of inventory assets **dilute** LPs; stray unrelated ERC-20s **ignored**. Free pair-token dust on buffered legs is **not** native reserve |
| D22 | Rated balance (swaps **only**) | For each leg \(i\), pair-token valuation then decimal→WAD scale: **(a)** raw → face; **(b)** buffered + RP → `seBal * getRate() / 1e18` (**fail-closed**); **(c)** buffered + no RP → SE **claim** via fee-inclusive unwrap preview. **Do not** also multiply claim by RP. **Do not** use free `token.balanceOf(hook)` for buffered legs. **Never used for LP mint/burn / kLast** |
| D23 | LP domain (Q7) | **All liquidity ops** (join/exit/first-mint/`kLast`/one-token aliases): **inventory only** — raw face or **SE share balances**. **No** `getRate()`. **No** live claim in LP algebra. User-facing deposit/withdraw amounts are **pair tokens** at the edge (buffer/unwrap). **SE yield / RP changes do not mint or burn LP** and do not rewrite ownership. Taxable unbalanced join fees use inventory-domain Balancer taxable logic (plan freezes bit-exact) |
| D24 | Growth measure domain | \(k\) / `kLast` on **inventory-domain** weighted product (or partial interim) — face WAD and **share** WAD per leg decimals — **not** claim, **not** RP. SE yield that increases claim without changing share balance does **not** by itself update \(V\) for growth until inventory moves |
| D25 | Yield in **swap** price | Re-read SE balances + claim and/or rate each **swap** quote; SE profit / rate moves **swap** mid without a swap. LP token supply/ownership unchanged until a liquidity op |
| D26 | Swap ratio caps | Balancer **`_MAX_IN_RATIO` / `_MAX_OUT_RATIO` = 30%** of **rated** trade-leg balances |
| D27 | Invariant ratio caps | Balancer-style **max growth ~300%** / **min shrink ~70%** on unbalanced add/remove (native domain) |
| D28 | Share / claim composition | For buffered **tokenIn**: map raw amountIn → SE shares (buffer preview) → **rated inflow** via rate (if RP) or claim delta (if no RP). Never feed raw amountIn into WeightedMath as if 1:1 under SE fees. Buffered **tokenOut**: invert rated → shares/claim → native token. Raw legs: face amounts. Same composition for V4 swaps, zap internal swaps, and SE In/Out swaps |
| D28a | SE exact-out / invert unsupported | If a bound SE **does not support** the required exact-out (or invert) route for buffer/unwrap composition on a path, the **entire transaction reverts**. No partial fill; no approximate solver |
| D29 | Buffer-last | Normative multipath / join / zap process: quote/size on pre-buffer book → inventory moves → **buffer all SE legs last** (binding index order) → mint / `kLast` on post-buffer native inventory. Do **not** re-quote weighted mid-flight after buffer |
| D30 | SE I/O to bound vaults | Bound SE: `exchangeIn` / `exchangeOut` only; tight minOut/maxIn = fee-inclusive SE preview; SE deadline `block.timestamp` if required. Under-delivery or missing route → **full tx revert** (D28a) |
| D31 | SE usage fees | **Orthogonal** to product design. Inside SE previews/execution only. Product fees = trading residual + growth mint |
| D32 | Free pair dust | **`MAX_DUST_WEI = 10`**. After liquidity ops, free balances of **buffered** pool tokens **> 10 wei** **refund to `msg.sender`**. Raw-leg intentional inventory is **not** refunded |
| D33 | Post-swap floors | Successful swap must leave both trade-leg **native** inventories \(> 0\) and both **rated** balances \(> 0\) |
| D34 | Quote matrix | Exact-in + exact-out both directions on every directed pair door **and** on SE In/Out; closed form |

### 3.3 LP & liquidity surfaces

| # | Decision | Value |
|---|----------|--------|
| D35 | LP token | Single fungible **ERC-20 on the hook** (proxy is LP); decimals **18**; free transfer; EIP-2612 via shared facets |
| D36 | LP ownership | Pro-rata of **all inventory components** (raw balances + SE share balances) |
| D37 | MINIMUM_LIQUIDITY | **1000** LP wei to `address(0)` on first mint; **never burned** |
| D38 | Join surface (full book) | Mirror Weighted / Balancer on **inventory domain**: (1) proportional multi-asset; (2) **single-asset** exact-in and exact-BPT-out; (3) **unbalanced multi-asset**; (4) exact-BPT-out unbalanced as peer supports. Taxable fee + invariant ratio caps. Buffer-last on SE legs. User pulls **pair tokens** |
| D39 | Exit surface (full book) | Mirror Weighted / Balancer: proportional exact BPT in; single-asset exact BPT in; exact token out **only if closed-form** (D42a); unbalanced multi where peer supports; ratio caps; **post-state all inventory reserves > 0** (D48). Unwrap SE legs to pair tokens |
| D40 | Partial book | **Allowed** — mirror Weighted §4.7 / P3. First mint ≥2 positive legs for \(n \ge 3\); \(n=2\) both legs. Full unbalanced only when full book. **Single-asset join/exit aliases forbidden while partial** (same as Weighted restricted surface) |
| D41 | One-token entry (Q8) | **`depositSingle` ≡ `joinSingleAssetExactIn`** (and exact-BPT-out single-asset peer). **Required v1** when full book. **No** multi-leg internal rebalance. Taxable Balancer single-asset economics. Mint LP to **`to`** (Q12) |
| D42 | One-token exit exact BPT (Q8) | **`withdrawSingle` ≡ single-asset exit exact BPT in → one `tokenOut`**. Burn **`msg.sender`** LP; pay pair tokens to **`to`**. Full book only; floors D48 |
| D42a | One-token exit exact out (Q9) | **`withdrawSingleExactOut` only if** Crane WeightedMath / BasePoolMath peer provides **closed-form** single-token exact-out with bit-exact preview. If not available without search → **omit from v1 DoD** (do not ship binary search). Prefer shipping exact-BPT-in path only |
| D43 | No multi-leg zap | **Forbidden in v1:** dual-style internal multi-leg rebalance for single-asset deposit/withdraw. One-token paths are **only** Balancer single-asset join/exit |
| D44 | First mint | Preferred all \(n > 0\); partial seed per D40. **Not** via one-token join. **`shares = V_inv − MINIMUM_LIQUIDITY`** where \(V_inv\) is inventory-domain weighted invariant (face WAD / **share** WAD — Q7/P2); dead MIN to `address(0)`; buffer-last; no protocol mint while `kLast == 0` |
| D45 | Funding (LP) | SafeERC20 `transferFrom` **and** Permit2 on join / one-token entry pulls. Empty `permit2Data` ⇒ transferFrom only; non-empty ⇒ Permit2 all pulled legs — **no mixed**. **Refunds of unused deposit tokens → `msg.sender`**. **LP minted to `to`** (Q12). Exit burns **`msg.sender` LP only** |
| D46 | LP name/symbol | Auto **`SEWGT-{s0}-…-{s_{n-1}}`** (Standard Exchange Weighted); address-fragment fallback; cap length. Prefix **`SEWGT`** is locked (not a Solidity type name) |
| D47 | LP deadline | All LP **mutators** (join/exit/zap) take **`deadline`** and **`require(block.timestamp <= deadline)`** |
| D48 | Full-book exit floors | While mode is **FullProduct**, any remove must leave **all \(n\) native reserves \(> 0\)**. Zeroing a leg via full-book exit **reverts**. Partial book is entered only via **partial first mint / seed path**, not by draining a full book leg |
| D49 | Reentrancy | One global non-reentrant lock on join/exit/zap/SE surfaces **and** `beforeSwap` body (after PM sender check) |
| D50 | Preview fidelity | **Bit-exact** `preview* == execution` at same oracle fee reads, same SE previews, same rate reads, same ceil/floor path (incl. zap + SE In/Out + multi-token SE liquidity) |

### 3.4 SE In/Out and interface extensions

| # | Decision | Value |
|---|----------|--------|
| D51 | SE In/Out swaps | **Required v1:** implement `IStandardExchangeIn` + `IStandardExchangeOut` for exact-in/out **tokenᵢ ↔ tokenⱼ** (`i ≠ j`, both bound) against the **same** rated weighted book as public V4 swaps. **Internal settle** (no PoolManager unlock). **Not** LP mint/burn on these selectors. Previews required and bit-exact |
| D52 | SE In/Out token domain | Only the \(n\) bound pool tokens. Revert if token is SE share address, unbound, or same token in/out |
| D53 | SE In/Out funding | **Canonical** pull when `!pretransferred`: BasicVaultCommon peer — ERC-20 `transferFrom` if allowance to hook, else Permit2 **AllowanceTransfer**. `pretransferred` requires balance already on hook. **No** SignatureTransfer on canonical SE In/Out ABI. Hook is Permit2-aware |
| D54 | SE one-token aliases | **Required v1** on **`IStandardExchangeMultiAssetLiquidity`**: same economics as D41–D42 (and D42a iff in DoD). Shared implementation with hook join/exit OK. Previews bit-exact |
| D55 | Multi-token SE liquidity (Q10) | **Required v1:** **`IStandardExchangeMultiAssetLiquidity`** mirrors the **full** weighted join/exit matrix available on the hook (proportional, single-asset, unbalanced as supported). **Not** merged into In/Out. Selector packing frozen in plan; no DETF-specific names |
| D56 | SE liquidity ≠ swap | Multi-token deposit/withdraw and zap-in/out **mint/burn hook LP**. Canonical two-token `exchangeIn`/`exchangeOut` remain **swap-only** (D51) |

### 3.5 Fees, protocol growth, ops

| # | Decision | Value |
|---|----------|--------|
| D57 | Trading (swap) fee | **Live** `feeOracle.dexSwapFeeOfVault(address(this))` WAD; 0 allowed; require `< 1e18`. **Balancer Weighted input residual** (exact-in net after fee; exact-out ceil gross-up). Residual stays in **input** inventory/book. Applies to V4 swaps, zap internal swaps, SE In/Out swaps |
| D58 | Trading fee → V4 units | Floor map WAD → pips + `OVERRIDE_FEE_FLAG` on `beforeSwap`. Economic SoT = hook residual — **no double-haircut** |
| D59 | Protocol growth fee | **Yes** — Uni V2–style. Live `usageFeeOfVault(this)`; mint LP to live `feeTo()` on add/remove when fee-on. **Not** on every swap |
| D60 | fee-on predicate | `feeTo != 0 && usageFeeWad != 0 && usageFeeWad < 1e18 && ownerFeeShare != 0` with `ownerFeeShare = usageFeeWad * 100_000 / 1e18` (floor) |
| D61 | `kLast` measure | **Full book:** \(k = V_inv = \prod b_i^{w_i}\) on **inventory** WAD (face / SE shares — Q7); **`rootK = V_inv` (literal)**. **Partial:** interim product on positive inventory legs; `kLast` + `kLastMode`. Cross-mode: no mint from incompatible `kLast` |
| D62 | Growth timing | Protocol mint from **pre-intake** \(k\) on add; mint before user burn on remove; set `kLast` post-op when fee-on. Swaps do not mint protocol LP or update `kLast` |
| D63 | Previews + growth | LP previews **simulate** protocol mint dilution when fee-on |
| D64 | Tick spacing | Package constant **`TICK_SPACING = 1`**. `beforeInitialize` enforces |
| D65 | Init sqrt price | postDeploy: `TickMath.getSqrtPriceAtTick(0)` (plumbing only) |
| D66 | Factory doors only | `beforeInitialize` accepts **only** PoolKeys that match factory-door rules: both currencies in bound set, distinct, **`fee == DYNAMIC_FEE_FLAG`**, **`tickSpacing == TICK_SPACING`**, **`hooks == this`**. Extra keys **revert** |
| D67 | Access | Liquidity + views + SE surfaces permissionless; hook callbacks `msg.sender == poolManager` only |
| D68 | Admin | **None** on hook — no weight/SE/RP update, no pause, no fee setter |

### 3.6 Deploy, vault surface, tests

| # | Decision | Value |
|---|----------|--------|
| D69 | Deploy path | **Required:** `IUniswapV4HookDiamondPackage` + Vault Registry `deployHookVault` + shared `UniswapV4HookDiamondPackageCallBackFactory`. Facets CREATE3 via FactoryService. **Never** `new` SUT; **never** vault factory salt for V4 flag addresses |
| D70 | Salt law | Factory PRD: `packageSalt` from stable `PRODUCT_ID` + binding fields (**n, tokens, weights, SEs, RPs** — **and** factory identity for PM/oracle scope as plan freezes; **no** package/facet addresses). `poolManager`/`feeOracle` are factory immutables (Q11) so salt need not re-encode them if factory address is in the preimage (plan freezes). `finalSalt = keccak256(abi.encode(packageSalt, mineNonce))` |
| D71 | Mine flags | At least `BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_REMOVE_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA \| BEFORE_DONATE` (plan locks exact mask vs `Hooks.ALL_HOOK_MASK`) |
| D72 | Pool init UX | **postDeploy:** on successful instance deploy, package initializes **all** \(\binom{n}{2}\) pair doors with shared `tickSpacing` + `sqrtPriceX96` plumbing. Currencies address-sorted per pair; `hooks = this`; `fee = DYNAMIC_FEE_FLAG`. Atomic with deploy from integrator POV |
| D73 | Deposit vs pool init | LP add/remove/previews **do not require** V4 initialize. **Swaps** require first-minted book, initialized directed pair pool, both trade-leg native + rated \(> 0\) |
| D74 | Vault discovery | **Required v1:** `IBasicVault` + `IStandardVault` multi-asset discovery: `vaultTokens()` = binding tokens; **`reserveOfToken(token_i)`** = **raw face** for raw legs; **SE share balance** (`IERC20(SE_i).balanceOf(hook)`) for buffered legs (P4). **Not** free pair-token dust; **not** SE claim; **not** shares×rate. Consumers that need pair-token units use `seClaim(i)` / `ratedBalance(i)` / previews |
| D75 | Test matrix (min) | Production-first; real V4 PM; real Vault Fee Oracle with defaults; real SE ports / ERC-4626 Wrapper SE. Matrix covers: (a) **1 SE** + raw rest; (b) **all legs SE**; (c) mixed; (d) RP zero/non-zero on buffered legs; (e) \(n \in \{2,3,4\}\) minimum hermetic (8 optional stress); partial book (P3); first mint `V−MIN` (P2); full join/exit; zap-in + **both** zap-out paths (P5); SE In/Out; `IStandardExchangeMultiAssetLiquidity` (P1); `reserveOfToken` shares (P4); protocol growth; rate fail-closed. **No** mock hook / mock SE SUT |
| D76 | Fork DoD | **Base + Robinhood (4663)** equal priority after hermetic; Ethereum optional stretch. Production PM/Permit2/fee oracle when present |
| D77 | DETF coupling | Fully independent product/test surface — **no DETF work in this PRD** |
| D78 | Impl plan follow-on | `UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` |

### 3.7 Implementation edges (locked)

| ID | Topic | Value |
|----|--------|-------|
| O1 | Native / rated views | Required public `nativeReserve(uint8 i)` / `nativeReserves()`; `ratedBalance(uint8 i)` / `ratedBalances()`; also per-token `reserveOfToken` |
| O2 | SE / RP views | `standardExchange(uint8 i)`, `rateProvider(uint8 i)`, `isBuffered(uint8 i)`, `seClaim(uint8 i)`, `seBalance(uint8 i)` |
| O3 | One-token aliases | `depositSingle` + `withdrawSingle` required (= single-asset join/exit); `withdrawSingleExactOut` only if Q9 closed-form |
| O4 | Internal settle | Buffer/unwrap helpers shared; V4 swaps settle via PM deltas; zap + SE surfaces **do not** unlock PM for curve settle |
| O5 | Rate fail-closed | Non-zero RP: failed `getRate` or non-positive rate **reverts** any path that needs that leg’s **rated** balance |
| O6 | Multi-SE buffer order | Binding index order after all used amounts finalized |
| O7 | Swap inventory order | Take tokenIn → weighted settle amounts → buffer tokenIn if SE → unwrap/pay tokenOut if SE; never leave free buffered-token inventory as book |
| O8 | LP ERC-20 location | Same mined hook proxy |
| O9 | Math library | Pure Math: WeightedMath wrappers, scale, growth, zap multi-leg split, native join/exit helpers — **no** SE external calls inside pure Math |
| O10 | Inventory re-read | Re-read SE balances + claims + rates when next step needs post-inventory state. **Do not** re-solve weighted mid-flight after buffer (buffer-last) |
| O11 | Adversarial DoD | Reentrancy (LP↔swap↔SE), donation dilution, `feeTo` non-receivable, SE revert mid-buffer/zap, RP fail-closed, partial-book drain attempts, distinct-SE / zero-SE binding rejects, full-book zero-leg exit |
| O12 | SE multi-token ABI | Interface name **locked:** `IStandardExchangeMultiAssetLiquidity` (P1). Plan freezes selectors and packing only; law is D54–D56 |

### 3.8 Stakeholder pins (P1–P6) — **LOCKED** v0.2

Former “residual opens.” Product law below; implementation plan freezes only bit-exact rounding / full ABI field lists.

| # | Topic | Locked value |
|---|--------|--------------|
| **P1** | Multi-token SE interface | **New `IStandardExchangeMultiAssetLiquidity`**. Canonical `IStandardExchangeIn` / `Out` stay swap-only. Selectors/packing frozen in plan |
| **P2** | First-mint shares | **`shares = V_inv − MINIMUM_LIQUIDITY`**. \(V_inv =\) WeightedMath `computeInvariantDown` on **inventory** WAD: face for raw; **SE share balance** for buffered (Q7 — **not** claim, **not** RP). `MINIMUM_LIQUIDITY = 1000` → `address(0)` |
| **P3** | Partial-book mint | **Mirror Weighted §4.7 sketch** on inventory legs. Plan freezes bit-exact ordering/rounding only |
| **P4** | `reserveOfToken` buffered | **SE share balance**. Raw legs = face. Claim/rated = separate getters |
| **P5** | One-token / “zap” model (superseded v0.2 multi-leg) | **v0.3:** Balancer **single-asset join/exit only** (Q8). `depositSingle`/`withdrawSingle` are **aliases**. Multi-leg force-sell zap **out**. Exact-out exit **only if closed-form** else drop (Q9) |
| **P6** | Events (minimum DoD) | Weighted peer join/exit; `ProtocolFeeMinted`; `DepositSingle` / `WithdrawSingle` (alias events OK if same as join/exit); `WithdrawSingleExactOut` only if shipped; **no** required `ZapSwap` (no multi-leg internal zap); SE multi-token events; factory deploy/ensure. V4 Swap logs for public swaps |

### 3.9 Stakeholder pins (Q7–Q12) — **LOCKED** v0.3

| # | Topic | Locked value |
|---|--------|--------------|
| **Q7** | LP vs rate/claim | RP **only** for swap amount calculation. **All liquidity ops** in SE-native inventory (shares) / raw face. **LP ownership does not change** solely because SE valuation (claim/RP) changes |
| **Q8** | One-token entry | **Balancer single-asset join only**; `depositSingle` **aliases** it — **no** multi-leg rebalance |
| **Q9** | Exact-out one-token | **Closed-form only**; if none, **drop exact-out from v1** — no binary search |
| **Q10** | MultiAssetLiquidity breadth | **Full** weighted join/exit matrix mirrored on the SE multi-asset interface |
| **Q11** | PM + feeOracle | **Factory immutables only** (raw Weighted peer) |
| **Q12** | Recipients | Joins/one-token entry mint LP to **`to`**; unused deposit **refunds → `msg.sender`**; exits burn `msg.sender` LP, pay tokens to **`to`** |

---

## 4. Architecture

### 4.1 Stack

```text
┌──────────────────────────────────────────────────────────────────┐
│ Integrator / anyone (permissionless liquidity + swaps)           │
│   • registry/pkg deployHookVault(args, mineNonce)                │
│   • join / exit / depositSingle / withdrawSingle* on Hook        │
│   • SE In/Out + IStandardExchangeMultiAssetLiquidity             │
│   • swapExact* via V4 on any factory door                        │
└───────────────┬─────────────────────────────┬────────────────────┘
                │                             │
                ▼                             ▼
┌───────────────────────────┐   ┌──────────────────────────────────┐
│ Hook Diamond Factory      │   │ Uniswap V4 PoolManager           │
│  CREATE2 proxy + flags    │──►│  init all binom(n,2) pair pools  │
│  registry.deployHookVault │   │  fee = DYNAMIC_FEE_FLAG          │
└───────────────┬───────────┘   │  tickSpacing=1, hooks = this     │
                │               └──────────────────────────────────┘
                ▼
┌──────────────────────────────────────────────────────────────────┐
│ UniswapV4StandardExchangeWeightedBufferHook (diamond)            │
│  tokens[n] + weights[n] + SE[n]? + RP[n]?   (≥1 SE)              │
│  native inventory + rated swap balances + V + kLast              │
│  LP ERC-20 + feeOracle                                           │
└───────────┬───────────────────────────────┬──────────────────────┘
            │ buffer / unwrap               │ optional getRate (swaps)
            ▼                               ▼
┌───────────────────────┐         ┌───────────────────────┐
│ IStandardExchange ×1–n│         │ IRateProvider ×0–n    │
└───────────────────────┘         └───────────────────────┘
```

### 4.2 Virtual multi-pool (“many doors, one room”)

Uniswap V4 pools are **strictly 2-currency**. Multi-asset weighted state lives **only** on the hook:

```text
Pool t0/t1  ──┐
Pool t0/t2  ──┤
…             ├──► same UniswapV4StandardExchangeWeightedBufferHook
Pool t_{n-2}/t_{n-1} ──┘
   shared native inventory[n] + weights[n] + SE/RP slots + LP + kLast
```

**Swap pricing** for pair \((i,j)\) uses only rated \((b_i, w_i, b_j, w_j)\) (Balancer). Other balances do **not** enter the swap formula. They **do** enter full-book native invariant \(V\) for LP and protocol growth.

**Pair count examples:** \(n=2 → 1\) pool; \(n=3 → 3\); \(n=4 → 6\); \(n=8 → 28\).

### 4.3 Native vs rated domains (normative — product lock)

```text
RATE_PRECISION = 1e18
baseScale[i]   = 10^(36 - decimals(token_i))   // weighted peer

// --- NATIVE inventory (LP, kLast, full-book floors) ---
for i in 0..n-1:
  if standardExchange[i] == 0:
      native[i] = Repo.rawReserve[token_i]           // face ERC-20
  else:
      native_shares[i] = IERC20(SE_i).balanceOf(hook) // SE shares as inventory unit
      // Pair-token claim (for views / unwrap sizing; NOT multiplied by RP):
      claim[i] = previewExchangeIn(SE_i, native_shares[i], token_i)

// Join/exit / V_inv / kLast (Q7 / D23) — INVENTORY ONLY
//   - Raw legs: face amounts → WAD via token decimals (baseScale peer)
//   - Buffered legs: SE **share** balances → WAD via share token decimals
//   - User edge: pair tokens in/out; buffer-last / unwrap convert at boundaries
//   - getRate() and live claim MUST NOT enter LP algebra
//   - SE yield changing claim/share price does NOT mint/burn LP by itself
//
// vault reserveOfToken(token_i) (D74 / P4):
//   raw leg  → face reserve
//   SE leg   → seBal shares (NOT claim, NOT rated)

// --- RATED balances (SWAPS only + swap previews + SE swap paths) ---
for i in 0..n-1:
  if standardExchange[i] == 0:
      pairUnits = native[i]                          // face
  else if rateProvider[i] != 0:
      rate = IRateProvider(rateProvider[i]).getRate() // fail-closed; pair-token per share
      pairUnits = native_shares[i] * rate / 1e18     // RP IS share→token conversion
  else:
      pairUnits = claim[i]                           // SE claim, no RP

  rated[i] = floor(pairUnits * baseScale[i] / 1e18)  // 1e18 domain for swap WeightedMath
```

**Note (mixed inventory units):** \(V_inv\) multiplies WAD(face) and WAD(shares) across legs. That is **intentional** under Q7 (inventory co-ownership, not mark-to-market claim). Swap pricing separately uses rated pair-token units. Implementors must not “fix” LP domain by reintroducing claim/RP.

**RP validation intent:** RP only on SE legs; values shares as pair token for **swaps**. Runtime fail-closed on bad rates.

### 4.4 Weighted swap math (normative sketch)

Use Crane vendored **`WeightedMath`** on **rated** balances:

```text
feeWad = feeOracle.dexSwapFeeOfVault(this)   // may be 0; require < 1e18
bIn  = rated[in]
bOut = rated[out]
// Map amountIn native → rated inflow via SE composition (D28)
amountInNet_rated = ratedInflow - floor(ratedInflow * feeWad / 1e18)
require amountInNet_rated <= bIn * 30e16 / 1e18
rawOut_rated = WeightedMath.computeOutGivenExactIn(bIn, wIn, bOut, wOut, amountInNet_rated)
// Map rated out → native out (descale + SE unwrap invert if buffered)
// Inventory: credit input inventory (gross native / shares); debit output inventory
// DYNAMIC fee override (D58)
```

Exact-out dual with ceil gross-up of input fee (weighted peer).

### 4.5 Fee law — two oracle channels

| Channel | Oracle API | When | Destination |
|---------|------------|------|-------------|
| **Trading** | `dexSwapFeeOfVault(this)` | Every swap (+ previews) | Residual in **input** inventory |
| **Protocol growth** | `usageFeeOfVault(this)` | Every join/exit/zap | **Mint LP → live `feeTo()`** |

```text
// Full book growth measure (native domain — D24 / D61):
//   k = V = prod b_i^w_i   (native pair-token WAD, no RP)
//   rootK = V
// Partial: interim product on positive native legs
// protocolLp algebra: weighted / ConstProdUtils peer (FEE_DENOMINATOR = 100_000)
```

**Tests:** deploy production Vault Fee Oracle; set **default** dex swap fee and default usage fee (and feeTo).

### 4.6 Liquidity — full book (mirror Weighted, buffer-last)

When **all** native inventories \(> 0\) and `totalSupply > MINIMUM_LIQUIDITY` (or after first mint established full book):

#### 4.6.0 Protocol mint first

On every join/exit/zap: if fee-on and same `kLastMode` and `kLast != 0`, mint protocol LP from pre-op \(V\) vs `kLast`. User share math uses **post-protocol** `totalSupply`.

#### 4.6.1 First mint

```text
require totalSupply == 0
// Preferred: all n amounts > 0
// Allowed for n ≥ 3: ≥2 positive legs (partial — §4.7)
// Required for n = 2: both legs > 0

Pull pair tokens
// Map each leg to inventory delta: raw face credit OR SE shares via buffer preview
invWad[i] = toWad(inventoryAmount_i)  // face or shares — Q7
V_inv = WeightedMath.computeInvariantDown(weights, invWad)
require V_inv > MINIMUM_LIQUIDITY
shares = V_inv - MINIMUM_LIQUIDITY   // P2 / D44
Buffer-last SE legs; credit raw legs; mint MIN to address(0); mint user LP to `to`; set kLast if feeOn
```

#### 4.6.2 Proportional / unbalanced / single-asset join-exit

Behavioral peer: Weighted PRD §4.6 on **inventory** domain (Q7), then:

```text
// Size share mint/burn from inventory balances (face | SE shares)
// User edge always pair tokens: buffer-last SE legs; unwrap on exit
// Join: mint LP to `to`; refund unused pair tokens to msg.sender (Q12)
// Exit: burn msg.sender LP; pay pair tokens to `to`
// Full-book exit floors: all inventory reserves remain > 0 (D48)
```

#### 4.6.3 One-token entry — `depositSingle` ≡ single-asset join (Q8)

**Eligibility:** full book (Weighted single-asset rules).

```text
1) Protocol growth mint if fee-on
2) Pull amountIn of tokenIn (transferFrom or Permit2)
3) Balancer single-asset exact-in join on inventory domain (taxable)
4) Buffer-last if tokenIn is SE leg; else credit raw face
5) Mint LP to `to`; set kLast; refund dust
// NO multi-leg internal swaps
```

#### 4.6.4 One-token exit — `withdrawSingle` ≡ single-asset exact BPT in (Q8)

```text
1) Protocol growth mint if fee-on
2) Burn exact shares from msg.sender
3) Balancer single-asset exit → inventory out of tokenOut leg only
4) Unwrap if SE; pay pair tokens to `to`; set kLast
// NO multi-leg force-sell of other legs
```

#### 4.6.5 Exact-token-out exit — optional closed-form only (Q9)

```text
If WeightedMath/BasePoolMath peer has closed-form single-token exact-out:
  ship withdrawSingleExactOut with bit-exact preview
Else:
  omit from v1 DoD entirely — users use withdrawSingle or proportional exit
// NEVER binary-search
```

### 4.7 Partial book (mirror Weighted) — P3

Normative behavioral peer: Weighted PRD **§4.7**, adapted to **inventory** + SE buffer-last:

- Partial first mint / seed for \(n \ge 3\) with ≥2 positive legs.  
- Interim product on **positive inventory legs**; seed zero legs with full maxes.  
- Restricted joins/exits while partial.  
- **Single-asset aliases forbidden** while partial.  
- Full-book exit must not zero a leg (D48).  
- Plan freezes bit-exact ordering/rounding only.

### 4.8 SE In/Out and `IStandardExchangeMultiAssetLiquidity` (P1 / Q10)

```text
// Swaps (canonical IStandardExchangeIn / Out) — SWAP ONLY
exchangeIn / exchangeOut (token_i ↔ token_j)
  → WeightedMath on **rated** balances + trading fee
  → buffer/unwrap + RP composition
  → internal settle; NEVER mint/burn LP

// IStandardExchangeMultiAssetLiquidity — FULL join/exit matrix (Q10)
// proportional / unbalanced / single-asset + depositSingle/withdrawSingle aliases
// optional exact-out single-asset only if D42a shipped
// Previews bit-exact; selectors frozen in plan
```

### 4.9 Settle order (V4 swaps)

Pattern-copy peer hooks (weighted / dual / SE orbital):

```text
// beforeSwap (msg.sender == poolManager)
// 1) Load rated balances; compose amountIn → rated inflow (SE if needed)
// 2) WeightedMath + input fee residual
// 3) Take tokenIn from PM accounting path
// 4) Buffer tokenIn if SE (buffer-last relative to quote)
// 5) Unwrap tokenOut if SE; sync+transfer+settle tokenOut
// 6) Update native inventory; return BeforeSwapDelta + fee override
```

---

## 5. Package layout & public surface

### 5.1 Layout (normative target)

```text
contracts/hooks/uniswap/v4/standardExchange/weighted/
  UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md              # this file
  UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on

  interfaces/
    IUniswapV4StandardExchangeWeightedBufferHook.sol      # surface + PkgInit/PkgArgs if co-located
    IUniswapV4StandardExchangeWeightedBufferHookPackage.sol

  facets/
    …HooksFacet.sol
    …LiquidityFacet.sol          # join/exit/zap
    …SeFacet.sol                 # SE In/Out + multi-token + zap SE surface
    …

  UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol
  UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol
  UniswapV4StandardExchangeWeightedBufferHookRepo.sol
  UniswapV4StandardExchangeWeightedBufferHookTarget.sol
  UniswapV4StandardExchangeWeightedBufferHookMath.sol
  …
```

### 5.2 Hook permissions (flags)

Minimum product flags (plan freezes exact mask):

| Flag | Role |
|------|------|
| `BEFORE_INITIALIZE` | Factory-door validation (D66) |
| `BEFORE_ADD_LIQUIDITY` | Ban native CL |
| `BEFORE_REMOVE_LIQUIDITY` | Ban native CL |
| `BEFORE_SWAP` + `BEFORE_SWAP_RETURNS_DELTA` | Custom weighted curve settle |
| `BEFORE_DONATE` | Ban donate |

### 5.3 Core public surface (sketch — plan freezes ABI names)

```text
// Identity / binding
n(), tokens(), weights(), standardExchange(i), rateProvider(i), isBuffered(i)
poolManager(), feeOracle()
nativeReserve(i), ratedBalance(i), seClaim(i), seBalance(i)

// Fees
dexSwapFee(), usageFee(), feeTo(), kLast(), kLastMode()

// LP ERC-20 + EIP-2612 (shared facets)
// Weighted joins/exits (Balancer-mirrored; deadline + Permit2 on pulls)
// depositSingle / withdrawSingle / withdrawSingleExactOut (zap)
// previews for all mutators + swap exact-in/out

// V4 IHooks callbacks
```

### 5.4 SE interface extensions (law) — P1 locked

| Capability | v1 | Notes |
|------------|----|-------|
| `IStandardExchangeIn` / `Out` exact-in/out tokenᵢ↔tokenⱼ | **Required** | **Swap-only**; rated weighted book |
| **`IStandardExchangeMultiAssetLiquidity`** | **Required** | Dedicated interface (P1); not merged into In/Out |
| Full join/exit matrix (on MultiAssetLiquidity) | **Required** | Same as hook (Q10) |
| `depositSingle` / `withdrawSingle` aliases | **Required** | = single-asset join/exit (Q8) |
| Exact-out one-token on MultiAssetLiquidity | **Iff D42a shipped** | Closed-form only (Q9) |
| Previews for all shipped mutators | **Required** | Bit-exact |

Interface **type name locked**. Selector names and argument packing frozen in the implementation plan only.

### 5.5 Events / errors (minimum) — P6 locked

**Events (DoD minimum):**

| Event | When |
|-------|------|
| `HookDeployed` / `PairPoolsEnsured` | Package/factory deploy + door repair |
| Join/exit (amounts + shares) | Weighted LP mutators |
| `ProtocolFeeMinted` | Growth mint to `feeTo` |
| `DepositSingle` / join events | One-token entry alias (may share Join event) |
| `WithdrawSingle` / exit events | One-token exit alias |
| `WithdrawSingleExactOut` | Only if D42a shipped |
| SE multi-token deposit/withdraw | `IStandardExchangeMultiAssetLiquidity` ops |

**Public V4 pool swaps:** rely on **PoolManager / V4 Swap logs** — no required product-level `Swap` event (P6).

**Errors:** bad tokens/weights/n; zero SE / non-distinct SE; RP without SE; not full book for Balancer path; partial restricted; ratio caps; fee wad; rate fail; deadline; zero amounts; wrong init fee/tick; reentrancy; full-book zero-leg attempt; SE invert unsupported; zap not eligible; exact-out zap exceeds `maxShares` / no solution.

---

## 6. Deploy path (normative)

```text
1. Owner/operator: setHookDiamondPackageFactory(hookFactory) once
2. registry.deployPkg(hookPkg initCode, pkgInit, salt)   // CREATE3 package
3. Off-chain mine mineNonce so CREATE2 address has requiredHookFlags
4. HookPackage.deployVault(pkgArgs, mineNonce)
     → registry.deployHookVault(pkg, abi.encode(args), mineNonce)
       → hookFactory.deployWithMineNonce(...)
       → postDeploy: init all binom(n,2) doors + register vault
```

**Salt:** `PRODUCT_ID` + binding fields only (D70).  
**Immutability:** no live `diamondCut` after postDeploy.

---

## 7. Testing expectations

Production-first (`indexedex-testing` + `indexedex-uniswap-v4-hook-packages`):

1. **No mocks of SUT** — hook diamond, facets, DFPkg, manager, registry, fee oracle, bound SE vaults.  
2. Real Uni V4 PoolManager (Crane port / hermetic).  
3. Real Vault Fee Oracle with defaults.  
4. Real SE legs (ERC-4626 Wrapper SE and/or production ports).  
5. Cover: inert deploy; ≥1 SE; distinct SE; RP-only-on-SE; first mint inventory `V−MIN`; partial book; full join/exit; single-asset aliases; **no** multi-leg zap; SE In/Out swaps; MultiAssetLiquidity full matrix; rated swaps ±RP; LP inventory domain (shares/face); yield does not mint LP; `reserveOfToken` = shares; buffer-last; protocol growth; preview==execution; reentrancy; factory-immutable PM/oracle; factory doors; fork Base + 4663.

---

## 8. Definition of Done

- [ ] Product PRD **v0.3+** accepted (this file).  
- [ ] Implementation + test plan written from this PRD (`D78`).  
- [ ] Package implements D1–D78 + P1–P6 + Q7–Q12 (plan freezes selector packing + rounding only).  
- [ ] Deploy path: Package → Vault Registry → Hook Diamond Factory only.  
- [ ] All \(\binom{n}{2}\) doors initialized on deploy.  
- [ ] ≥1 SE; distinct SEs; optional RP on SE legs only.  
- [ ] Swaps = rated; LP = inventory shares/face (Q7); no multi-leg zap (Q8).  
- [ ] First mint `shares = V_inv − MIN` (P2).  
- [ ] Full join/exit + partial book + single-asset aliases; exact-out only if closed-form (Q9).  
- [ ] SE In/Out + MultiAssetLiquidity **full matrix** (Q10).  
- [ ] Factory-immutable PM + feeOracle (Q11); mint to `to`, refunds to `msg.sender` (Q12).  
- [ ] `reserveOfToken` = face / SE shares (P4).  
- [ ] Dual-channel fees; hermetic D75; fork D76; no DETF.

---

## 9. Out of scope (explicit)

- Building any DETF family on this hook.  
- Migrating the raw Weighted monomorph onto this package.  
- LBP weight ramps, Morpho buffering, native ETH, fee-on-transfer pair tokens.  
- Zero-SE “just use weighted” mode inside this package.

---

## 10. Revision history

| Version | Date | Notes |
|---------|------|-------|
| **v0.1** | 2026-08-05 | Initial PRD from stakeholder lock pass: optional SE/RP with **≥1 SE**; \(n\in[2,8]\); distinct SE per token; Balancer `IRateProvider` **swap-only**; LP native domain; partial book + full weighted join/exit; zap-in **and** zap-out; dual-channel fee oracle; DYNAMIC_FEE_FLAG + all doors; hook diamond package deploy; SE In/Out + multi-token SE liquidity extensions; no DETF; non-goals locked |
| **v0.2** | 2026-08-05 | Lock residual P1–P6 |
| **v0.3** | 2026-08-05 | Q7–Q12: LP inventory = SE shares/face (not claim/RP); no multi-leg zap — single-asset aliases only; exact-out closed-form or drop; MultiAssetLiquidity full matrix; factory-immutable PM+oracle; mint to `to`, refunds to `msg.sender` |

---

## 11. Next step

Write **`UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`** from this PRD (phases, inventory WAD rules for mixed face/share legs, MultiAssetLiquidity selector packing, closed-form audit for D42a, test matrix).

**End of PRD — UniswapV4StandardExchangeWeightedBufferHook (Draft v0.3)**
