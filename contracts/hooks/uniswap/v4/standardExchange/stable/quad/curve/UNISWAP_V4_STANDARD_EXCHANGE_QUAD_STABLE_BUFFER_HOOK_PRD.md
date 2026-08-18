# PRD: Uniswap V4 Standard Exchange Quad Stable Buffer Hook

**Name:** `UniswapV4StandardExchangeCurveQuadStableBufferHook`  
**Date:** 2026-08-07  
**Status:** **LOCKED v0.2 — product law (implementation-plan SoT)**  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/`  
**Package kind:** IndexedEx **Uniswap V4 hook diamond package** that is **also** a vault-compatible multi-asset surface. Instance deploys via the **shared Hook Diamond Package Callback Factory** + Vault Registry `deployHookVault` (CREATE2-mined proxy). **Not** a concentrated-liquidity (CL) reimplementation. **Not** the raw-inventory `UniswapV4CurveQuadStableSwapHook` under `contracts/hooks/uniswap/v4/stable/quad/curve/`.

**Decision ID note:** `D*`, `O*`, `Q*`, and `P*` IDs are **stable keys**, not document order.

**v0.1 locks (co-design):** Q1–Q6 — ≥1 SE required; SE RP only on buffered legs + claim when no RP; native inventory LP domain; Balancer-style single-asset join/exit aliases (no multi-leg rebalance zap); live fee-oracle dual-channel; first mint all four legs + post-seed partial swap book.

**v0.2 pins (review LOCK):** Q7–Q9 + D refinements — zero-witness = **defensive solver only** (not a required reachable product state); single-asset taxable fee = live **`dexSwapFeeOfVault`** (Weighted peer); full shared **`IStandardExchangeMultiAssetLiquidity`** with unsupported paths → **`InvalidRoute`**; Phase 0 ship exact-LP-out / exact-token-out / unbalanced only if closed-form.

**Authority (normative):**

| Layer | Role |
|-------|------|
| **This PRD** | Product law for SE-buffered **4-asset StableSwap** topology, per-leg optional SE + optional SE rate provider, dual balance domains (inventory LP vs rated swaps), buffer/unwrap, join/exit surface, single-asset aliases, SE In/Out (+ MultiAssetLiquidity), fees, deploy shape |
| **Implementation plan** | Implementor SoT: [`UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md) (**v1.0** — co-located) |
| Raw Quad StableSwap PRD | **Curve / \(A\) / \(n=4\) / six doors / witness / first-mint-all-four / swap-live with zero witnesses / post-state priceability** behavioral reference — do **not** subclass; do **not** copy monomorph CREATE3 factory law; **do not** inherit deploy-time pips fee-on-output or raw-only inventory |
| SE Orbital Buffer PRD | **Per-leg SE slots, distinct SE, buffer-last, claim-in composition, diamond package / SE In/Out funding, vault discovery** process/shape reference — do **not** subclass; curve is **StableSwap**, not sphere; **this product requires ≥1 SE** |
| SE Weighted Buffer PRD | **Native inventory LP domain, dual WAD scales, single-asset aliases, MultiAssetLiquidity surface, ≥1 SE, gross buffer on swaps, live dual-channel fees, taxable single-asset fee via `dexSwapFeeOfVault`** process/accounting reference — do **not** subclass; curve is **StableSwap**, not weighted |
| Dual SE Buffer CP PRD | Buffer/unwrap / claim-in / buffer-last **process** peer only |
| Hook factory PRD | **Deploy / salt / flags / immutability law** — `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Skill | `indexedex-uniswap-v4-hook-packages` |

**Sibling packages (do not conflate):**

| Package | Path | Role |
|---------|------|------|
| **Quad Stable Swap Hook** (raw) | `contracts/hooks/uniswap/v4/stable/quad/curve/` | 4-asset StableSwap on **raw ERC-20** inventory; six V4 doors; optional **pair-token** rate providers; **no** SE buffering |
| **SE Orbital Buffer Hook** | `…/standardExchange/orbital/` | Three tokens; optional SE per leg; **sphere** AMM; multi-leg zap-in |
| **SE Weighted Buffer Hook** | `…/standardExchange/weighted/` | 2–8 tokens; ≥1 SE; **weighted** AMM; single-asset aliases |
| **Dual SE Buffer CP Hook** | `…/standardExchange/dual/` | Two SEs; CP; one V4 pair |
| **This package** | `…/standardExchange/stable/quad/curve/` | **Exactly four** tokens; **≥1 SE**; optional SE per remaining leg; **classic Curve StableSwap \(A\)** on **rated** balances for swaps; **native inventory** for LP; **six** V4 doors |

**Related references:**

- Raw Quad product law: `contracts/hooks/uniswap/v4/stable/quad/curve/UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md`
- SE Orbital Buffer: `…/standardExchange/orbital/UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md`
- SE Weighted Buffer: `…/standardExchange/weighted/UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md`
- Dual SE BCP: `…/standardExchange/dual/UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`
- Fee oracle: `contracts/interfaces/IVaultFeeOracleQuery.sol`
- Permit2: Uniswap well-known `0x000000000022D473030F116dDEE9F6B43aC78BA3`
- AGENTS.md — production-first tests; CREATE3 facets; hook instances via hook factory; no mock SUT

**Future consumer (out of this PRD’s DoD):** a Uni V4 Standard Exchange Quad Stable DETF may later bind this hook as reserve (peer: Orbital DETF ↔ Orbital Buffer). **This package ships and tests independently of any DETF.**

---

## 0. Terminology (normative)

| Term | Meaning in this PRD |
|------|---------------------|
| **Quad / n=4** | Exactly **four** bound ERC-20 pool tokens per instance (v1). Not variable \(n\). |
| **Binding order** | Deploy/init order `tokens[0..3]` — **strict address ascending**. SE slots, rate providers, reserves, LP views, events, and multi-token amount arrays use this index |
| **Pool currency order** | V4 `currency0` / `currency1` = pair tokens **sorted by address** (matches binding for any pair since binding is address-sorted) |
| **Pool token / leg token** | One of the four ERC-20s registered as Uniswap V4 pool currencies. **Never** SE share addresses as pool currencies |
| **Raw leg** | Leg with `standardExchange[i] == address(0)`. Hook holds **face ERC-20** inventory as that leg’s book |
| **Buffered leg / SE leg** | Leg with non-zero `standardExchange[i]`. Hook holds **SE shares**; free pool-token balance is **not** book (dust/refund only) |
| **Standard Exchange / SE** | Bound `IStandardExchange` for a leg; **at most one SE per token**; optional per leg; **at least one** non-zero SE in the instance; **non-zero SE addresses pairwise distinct** |
| **SE claim / claim supply** | Pool-token value of hook-held SE shares via fee-inclusive SE unwrap preview: \(c_i = \mathrm{previewExchangeIn}(SE_i,\ seBal_i,\ token_i)\) |
| **Rate provider** | Optional Balancer-style `IRateProvider` **per SE leg only** (`address(0)` = none). Purpose: **accurately value SE vault inventory as the pair token** for **swap pricing** (and other rated paths). Must be consistent with that leg’s pair token (share → pair-token units @ 1e18). **Not** raw-quad pair-token LST RPs on bare legs |
| **Native inventory / native balance** | Physical book for **all liquidity accounting**: **live** raw face ERC-20 for raw legs (`token.balanceOf(hook)` is SoT — donations dilute LPs); **live SE vault share `balanceOf(hook)`** for buffered legs. LP mint/burn, join/exit, first-mint shares, and `kLast` use **only** these units (plus inventory decimal→WAD). **Not** live SE claim, **not** `getRate()`. Changing SE share price / claim / RP **must not** by itself mint/burn LP or rewrite ownership |
| **Rated balance \(b_i^{\mathrm{rated}}\)** | Balance fed into **StableSwap math for swaps only** (V4 doors, SE In/Out swap paths): face / shares×rate / claim per §4.3, then **pair-token** decimal→WAD. **Never** enters join/exit LP algebra |
| **Inventory scale / rated scale** | **Two independent WAD maps.** **Inventory:** raw face → WAD via pair-token `decimals()`; SE shares → WAD via **share-token** `decimals()`. **Rated (swaps):** pair-token units (face / claim / `seBal×rate`) → WAD via **pair-token** `decimals()` always |
| **Stable units / \(x_i\)** | Rated WAD balances after scale — inputs to StableSwap invariant \(D\) and target-reserve solves |
| **Witness legs** | For a swap on pair \((i,j)\), the other two tokens \(k,\ell\) still enter the invariant. Solver **must tolerate** zero-rated witnesses (**defensive robustness**, raw-quad spirit — Q7). v1 product paths do **not** intentionally create native-zero legs |
| **One-token entry / exit** | StableSwap / Balancer-stable **single-asset** join/exit on the **native inventory** domain. **`depositSingle` is an alias** of single-asset join (no multi-leg internal rebalance). **`withdrawSingle`** aliases single-asset exit (exact BPT in). Exact-token-out / exact-LP-out variants only if closed-form (Phase 0 / D41–D42a) |
| **Single-asset eligible** | **Full book** (all four native inventories \(> 0\)) **and** `totalSupply > MINIMUM_LIQUIDITY` |
| **Taxable single-asset fee** | Balancer-style fee on the **taxable portion** of single-asset join/exit, charged with live **`dexSwapFeeOfVault(this)`** WAD (Weighted peer). Residual stays in inventory book. **Not** a second `usageFeeOfVault` haircut on the single-asset path (growth remains usageFee + `kLast`) |
| **depositSingle (alias)** | **`depositSingle` ≡ single-asset join** (exact token in → LP out, taxable per **taxable single-asset fee**). **No** multi-leg internal rebalance. Legacy UX name “zap-in” means **only** this alias — **not** raw-quad multi-leg force-buy, **not** orbital multi-leg zap |
| **withdrawSingle (alias)** | **`withdrawSingle` ≡ single-asset exit** (exact LP in → one token out; taxable portion uses same fee channel). **No** multi-leg force-sell basket |
| **Full book** | All four **native inventory** legs \(> 0\) (and, for swap-live directed pairs, trade-leg rated balances \(> 0\)) |
| **Partial book** | At least one leg has native inventory \(= 0\) (and `totalSupply > 0` after seed). **Forbidden as first-mint outcome**. **v1 operational paths do not intentionally create partial book** (full-book exits must leave all four native \(> 0\) — D48). Zero-witness rated solves remain **defensive only** (Q7) |
| **Factory doors** | All **six** Uni V4 pair pools created at deploy: `fee = DYNAMIC_FEE_FLAG`, `tickSpacing = TICK_SPACING` (1), `hooks = this` |
| **Buffer-last** | Quote / size / residual math on **pre-buffer** book; execute non-buffer moves; **buffer pair→SE as final SE inventory step**; then LP mint / `kLast` from **post-buffer** native inventory |
| **Claim-in / claim-out** | SE fee-inclusive preview of how much **SE shares** a raw pool-token buffer mints / how much token an unwrap delivers — not assumed 1:1 with raw amount |
| **Hook LP / shares** | Fungible ERC-20 on **this** hook (18 decimals). API params named `shares` mean **hook LP**, never SE vault shares |
| **IStandardExchangeMultiAssetLiquidity** | Shared SE-family extension at `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol` for multi-token deposit/withdraw + one-token aliases. Canonical `IStandardExchangeIn` / `Out` remain **swap-only**. This package **implements the full shared interface**; Phase-0-unsupported selectors **revert `InvalidRoute`** (exec + preview) |
| **DoD** | Definition of Done — package complete when **§8** is satisfied |

**Role naming:** use `token(i)`, `standardExchange(i)`, `rateProvider(i)`, `nativeReserve(i)`, `ratedBalance(i)` — **no** brand tickers; **no** DETF-specific type names on the hook ABI.

---

## 1. Goal

Ship a **production-first Uniswap V4 hook package** that:

1. Binds **exactly four** ERC-20 pool tokens, one V4 `PoolManager`, and one Vault Fee Oracle per instance.
2. Implements the **StableSwap invariant** for **swap pricing** on **rated** 1e18 balances with amplification coefficient \(A\):
   \[
   A \cdot n^{n} \cdot \sum x_i + D = A \cdot D \cdot n^{n} + \frac{D^{n+1}}{n^{n} \cdot \prod x_i}
   \]
   with \(n = 4\), \(x_i\) **rated WAD** reserves, \(D\) the invariant, \(A\) the **deploy-time immutable** amplification (no ramp in v1).
3. For **each** pool token, accepts an **optional** Standard Exchange into which that token is **buffered** when non-zero — **at most one SE per token**; **non-zero SE addresses pairwise distinct**; **at least one** leg **must** be buffered (else use raw `UniswapV4CurveQuadStableSwapHook`).
4. For **each** non-zero SE, accepts an **optional** Balancer-style **`IRateProvider`** that values **SE shares as the pair token** for **swap** (rated) pricing only.
5. Exposes **all six** \(\binom{4}{2}\) Uni V4 pair pools as swap doors into the **same** shared 4-asset book (staged `deployPair` × 6 then `finalizeInitialization`; `postDeploy` does not init doors).
6. **Buffers** pool tokens into the bound SE on liquidity add and on swap token-in when that leg is buffered; **unwraps** SE → pool token on liquidity remove and on swap token-out when that leg is buffered — **buffer-last** and share/claim composition (dual / SE Orbital process peer).
7. Holds inventory as: **raw ERC-20** for raw legs + **SE shares** for buffered legs. Pool currencies remain the four tokens — **never** SE share addresses.
8. Mints a **single fungible ERC-20 LP** representing pro-rata claim on all inventory components (raw balances + SE share balances).
9. Provides **proportional** multi-asset join/exit on **native inventory**, plus **single-asset join/exit** (Stable/Balancer-stable taxable single-token paths) with UX aliases **`depositSingle` / `withdrawSingle`**. **No** multi-leg internal rebalance “zap” (raw-quad / orbital multi-leg force-buy is **out**).
10. Exposes **`IStandardExchangeIn` / `IStandardExchangeOut`** for tokenᵢ ↔ tokenⱼ **swaps**, **plus** the **full shared** **`IStandardExchangeMultiAssetLiquidity`** (unsupported Phase-0 paths **`InvalidRoute`**).
11. Settles public swaps via **`beforeSwap` + `beforeSwapReturnDelta`** — pattern-copy settle; **no** inheritance of OZ/`BaseHook` / `BaseTokenWrapperHook` / `DeltaResolver`.
12. Deploys as an **immutable hook diamond package** via registry `deployHookVault` + shared hook factory (CREATE2 + `mineNonce`); product doors via permissionless `deployPair` × 6 then `finalizeInitialization`.
13. Uses **live Vault Fee Oracle** dual-channel rates: `dexSwapFeeOfVault` = trading residual **and** single-asset taxable portion; `usageFeeOfVault` = protocol growth LP mint to `feeTo`.

### 1.1 Canonical user story (four stables, two SE legs)

```text
Binding (example):
  tokens  = [A, B, C, D]   // address ascending
  baseAmp = 200            // deploy-time immutable (unscaled user units)
  SE      = [SE_A, 0, SE_C, 0]     // ≥1 SE; SE_A ≠ SE_C
  RP      = [RP_A, 0, 0, 0]        // RP only allowed where SE set
  require A ∈ SE_A.vaultTokens(), C ∈ SE_C.vaultTokens()
  require RP_A values SE_A shares as token A (pair-token units @ 1e18)

Uniswap V4 doors (all 6 pairs), fee = DYNAMIC_FEE_FLAG, hooks = this:
  A/B, A/C, A/D, B/C, B/D, C/D

Inventory after liquidity:
  SE_A shares + face B + SE_C shares + face D
  free A/C on hook is dust only (refunded after liquidity ops)

Rated balances for StableSwap swaps:
  b_A = seBal_A * getRate(RP_A) / 1e18   (or claim if no RP)
  b_B = face B
  b_C = claim(SE_C) or seBal_C * rate
  b_D = face D
  then pair-token decimal → WAD → x_i for invariant

--- First liquidity ---
User joinProportional(amounts[4] all > 0, …)
  → size on inventory domain; pull A,B,C,D
  → buffer-last A→SE_A, C→SE_C
  → shares = geometricMean(inventoryWadAmounts) − MINIMUM_LIQUIDITY
  → dead MIN to address(0); kLast if fee-on

--- Swap A → B on pool A/B ---
  witnesses C,D (rated; solver tolerates 0 — defensive only, Q7)
  take A → claim-in vs SE_A → StableSwap exact-in on rated book
  → buffer full gross A into SE_A last
  → pay B from raw inventory
  trading residual (dexSwapFeeOfVault) stays in input book path

--- Single-asset entry (full book only) ---
User depositSingle(tokenIn = A, amountIn, …)
  ≡ joinSingleAssetExactIn on inventory domain (Stable single-asset)
  → taxable portion charged with live dexSwapFeeOfVault (Q9); residual in book
  → buffer-last if A buffered; mint LP; growth via usageFee + kLast if fee-on
  → NO multi-leg internal rebalance to other legs

--- SE In/Out ---
exchangeIn / exchangeOut token_i → token_j against same rated StableSwap book
  → internal settle; same fee + buffer/unwrap; does NOT mint/burn LP

--- MultiAssetLiquidity ---
full shared interface cut; unsupported paths (e.g. joinUnbalanced if no closed-form)
  → revert InvalidRoute (exec + preview)
```

### 1.2 Why this exists (product problem)

| Approach | Limitation |
|----------|------------|
| Raw Quad StableSwap | Shared 4-asset StableSwap + six doors, but inventory is idle ERC-20 — **no** yield / SE composition |
| SE Orbital Buffer | Yield-aware multi-door, but **3** assets and **sphere** geometry (not StableSwap \(A\)) |
| SE Weighted Buffer | Yield-aware \(n\)-asset, but **weighted** invariant (not like-kind stable curve) |
| Dual SE BCP | Two buffered legs; **one** V4 pair; CP not multi-stable |
| **This package** | Quad **StableSwap curve + six doors** + **≥1 SE buffer** + optional SE rate scale |

v1 is the **composition layer**: raw-quad multi-door StableSwap topology with SE-buffer process generalized from orbital/weighted buffer peers, with **inventory-domain LP** and **rated-domain swaps**.

### 1.3 Product shape (locked)

| Layer | Role |
|-------|------|
| Uniswap V4 | Six pair pool identities; **swaps** + currency settlement via hook deltas |
| Hook | Binding (tokens + optional SE + optional RP + amp), join/exit, LP ERC-20, StableSwap math on **rated** balances, inventory LP algebra, per-leg buffer/unwrap, `beforeSwap` |
| SE vault(s) | Yield-bearing inventory for each **buffered** leg (at least one required) |
| Rate provider(s) | Optional rate scale on SE shares for **rated** balances (Balancer SE RP peer) |
| Concentrated liquidity | **Not used** — native `modifyLiquidity` **forbidden** |
| Book shape | Four-leg StableSwap; first mint **full** four; solver **tolerates** zero **witness** rated legs (**defensive only** — not a required product state) |
| LP shape | **One** fungible ERC-20 only |

---

## 2. Product summary

### 2.1 What this package is

| Attribute | Value |
|-----------|--------|
| Primary artifact | CREATE2-mined **hook diamond** (facets + Repo) implementing V4 `IHooks` **plus** 4-asset LP ERC-20 + multi-asset vault discovery surfaces |
| Binding | `(poolManager, feeOracle, token[4], standardExchange[4], rateProvider[4], baseAmp)` — set-once at init; **no** post-deploy rebind |
| Pool currencies | The four bound tokens; staged `deployPair` × 6 then `finalizeInitialization` opens **all six** pair doors |
| Inventory | Per leg: raw ERC-20 **or** SE shares (not both as book for the same leg) |
| Swap pricing | StableSwap on **rated WAD** balances; witnesses in invariant; Newton-Raphson for \(D\) and target \(y\) |
| LP accounting | **Native inventory** only (face / live SE shares + inventory WAD scales) |
| Swap (trading) fee | **Live** `dexSwapFeeOfVault(this)` WAD; residual stays in book (input residual peer) |
| Single-asset taxable fee | **Same channel** `dexSwapFeeOfVault` on taxable portion (D41a / Q9); residual stays in inventory book |
| Protocol growth fee | **Live** `usageFeeOfVault(this)` WAD; Uni V2–style `kLast` + mint LP to `feeTo` |
| V4 PoolKey.fee | **`DYNAMIC_FEE_FLAG`** |
| LP | Fungible ERC-20 + EIP-2612; decimals always 18; auto name/symbol prefix **`SEQS`** |
| Deposit / withdraw | Proportional multi-asset + single-asset aliases; buffer/unwrap on SE legs; **no multi-leg rebalance zap**; full MultiAssetLiquidity cut with unsupported → `InvalidRoute` |
| SE In/Out | Required v1: exact-in/out tokenᵢ ↔ tokenⱼ on the rated StableSwap book (internal settle) |
| Deploy path | Hook diamond package → registry `deployHookVault` → shared hook factory |

### 2.2 What this package is not

- Not the raw `UniswapV4CurveQuadStableSwapHook` monomorph (no SE legs; deploy-time pips fee; pair-token RPs; multi-leg zap-in).
- Not SE Orbital Buffer (not sphere; not 3 assets; not multi-leg zap).
- Not SE Weighted Buffer (not free weights; fixed \(n=4\) StableSwap).
- Not Dual / Single SE BCP (not CP; not one-pool-only topology).
- Not a wrapper-only buffer hook (`underlying ↔ SE` without multi-asset AMM).
- Not Uni V4 concentrated liquidity / Position Manager LP / tick bitmap.
- Not a DETF, bond NFT, or rebasing claim package (consumers may compose later).
- Not “SE shares as pool currencies.”
- Not multi-SE per single token (exactly **0 or 1** SE slot per token).
- Not the same SE address on two legs.
- Not zero-SE configuration (use raw Quad package).
- Not subclassing quad / orbital / weighted / dual contracts (fresh codepath; pure libs OK).
- Not multi-leg internal rebalance deposit/withdraw (raw-quad zap-in **out** of this product).

### 2.3 Non-goals (v1)

1. \(n \neq 4\) (dual/triple stable buffer packages would be separate PRDs).  
2. Arbitrary Balancer-style weights / non-equal unit preferences beyond rate-scaled rated balances.  
3. Pair-token rate providers on **raw** legs (raw-quad LST RP surface) — yield composition uses SE + optional SE RP only.  
4. Multi-leg force-buy/sell rebalance “zap” (raw-quad / orbital style).  
5. Native ETH as a pool currency (wrap to WETH off-hook).  
6. Amp ramping / post-deploy \(A\) mutation.  
7. Fee-on-transfer / rebasing **pool tokens**.  
8. Binary-search solvers as primary product law — StableSwap Newton solvers + SE fee-inclusive invert only.  
9. Auto-deploying SE vaults or rate providers inside the package.  
10. Owner / pause / admin surface on the **hook instance** after deploy.  
11. Treating V4 `sqrtPriceX96` as product mid after init.  
12. Shared TestBases with DETF packages (DETF may consume later; not v1 DoD).  
13. Using `dexSwapFeeOfVault` as protocol growth rate (growth uses **`usageFeeOfVault`**).  
14. Multiple concurrent SEs for the same token **or** the same SE address on multiple legs.  
15. Mapping `exchangeIn` → mint LP or `exchangeOut` → burn LP (wrong surface).  
16. Deploy-time immutable `lpFeePips` fee-on-output as economic SoT (raw-quad fee law **superseded** for this package by live oracle dual-channel).

---

## 3. Locked product decisions

### 3.1 Identity & binding

| # | Decision | Value |
|---|----------|--------|
| D1 | Product name | **`UniswapV4StandardExchangeCurveQuadStableBufferHook`** |
| D2 | Package location | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/` |
| D3 | Peers | Raw Quad = StableSwap curve / doors / first-mint-all-four / witness-tolerant solver **behavioral** reference. SE Orbital Buffer = multi-leg SE slots / diamond / buffer-last / SE funding **shape** reference. SE Weighted Buffer = inventory LP domain / dual WAD / single-asset aliases / MultiAssetLiquidity / ≥1 SE / dual-channel fees / **taxable single-asset via `dexSwapFeeOfVault`** **accounting** reference. Dual SE BCP = buffer/unwrap process. **No** required inheritance from any |
| D4 | Asset count (v1) | **Exactly four** pool tokens per instance |
| D5 | SE slots | **Exactly one optional SE per token** — `standardExchange[i]` is `address(0)` **or** one `IStandardExchange` |
| D5a | Minimum SE | **At least one** `standardExchange[i] != 0` — zero-SE binding **reverts** at deploy/init |
| D5b | Distinct SEs | **When non-zero, SE addresses must be pairwise distinct** |
| D6 | Rate provider slots | **Optional per SE leg only** — `rateProvider[i]` non-zero **only if** `standardExchange[i] != 0`; else must be `address(0)` |
| D6a | Rate provider semantics | **Balancer SE RP peer:** when RP set, rated pair-units from **SE share balance × `getRate()` / 1e18**. RP is **primary** conversion of shares — **not** a second multiplier on top of SE claim. When RP unset on a buffered leg: rated = **SE claim** via fee-inclusive unwrap preview. Fail-closed on non-zero RP. **No pair-token RP on raw legs in v1** |
| D7 | Amplification \(A\) | Deploy-time **immutable** `baseAmp` (unscaled). Internal math uses \(A \cdot\) `AMP_PRECISION` with **`AMP_PRECISION = 100`**. Bounds: `0 < baseAmp < MAX_AMP` with **`MAX_AMP = 1_000_000`**. Product guidance: prefer \(A \ge 10\). **No amp ramp** |
| D8 | Binding | Set-once at diamond init: `token0..3`, `standardExchange0..3`, `rateProvider0..3`, `baseAmp`. **`poolManager` + `feeOracle` from factory immutables** (weighted/orbital peer) — copied onto instance at deploy. Permit2 = well-known constant (not binding arg) |
| D9 | Token validation | Non-zero; **pairwise distinct**; **strict address ascending** `token0 < token1 < token2 < token3`; decimals in **[6, 18]**; standard ERC-20 + USDT-style SafeERC20. Fee-on-transfer / rebasing **unsupported**. **No native ETH** |
| D10 | SE validation (when non-zero) | `token_i ∈ SE_i.vaultTokens()`; `token_i != address(SE_i)`; SE exposes closed-form **token ↔ SE** buffer and unwrap routes with preview == execution; **D5b** distinctness |
| D11 | Empty SE at deploy | **Allowed** (inert SE until first buffer) |
| D12 | Pool set | Product doors open via shared `deployPair(address,address)` for each unordered pair among t0..t3, then `finalizeInitialization`. `postDeploy` does **not** init doors. Permissionless `ensurePairPools()` may repair after finalize. All doors: `hooks = this` |
| D13 | Pool fee (V4 key) | **`LPFeeLibrary.DYNAMIC_FEE_FLAG` only**. Economic trading fee SoT = hook residual math |
| D14 | Native CL | **Forbidden** — `beforeAddLiquidity` / `beforeRemoveLiquidity` **revert** |
| D15 | Donate | **Forbidden** — `beforeDonate` **reverts** |
| D16 | Package shape | **Hook diamond package** (`IUniswapV4HookDiamondPackage` + vault surfaces). Facets via CREATE3; instance via CREATE2 mine + hook factory. **Immutable** after `finalizeInitialization` (no public `diamondCut`) |
| D17 | Hook inheritance | **No** inheritance of Crane/OZ `BaseHook`, `BaseTokenWrapperHook`, `DeltaResolver` — full **pattern-copy** settle. May use Crane facet bases for diamond plumbing |
| D18 | Shared facets | Cut **ERC20PermitDFPkg** facets (`ERC20Facet` + `ERC5267Facet` + `ERC2612Facet`) + MultiAsset Basic/Standard vault facets for LP + discovery. Product facets = hooks + book + join/exit + SE buffer routes only |
| D19 | Full type/file names | Full product names on contracts/files; short labels OK in prose. LP symbol prefix may be short (D46) |

### 3.2 AMM, reserves, SE composition, rates

| # | Decision | Value |
|---|----------|--------|
| D20 | AMM model | **StableSwap** (\(n=4\), amplification \(A\)) on **rated** balances for **swaps** (and swap previews / SE In/Out swap paths). **Not** WeightedMath / Orbital / CP |
| D21 | Native inventory SoT | **Book = live balances of inventory assets.** Raw leg: **`token.balanceOf(hook)` is the book** (Repo may cache for gas/events but must re-read live when next step needs post-inventory state; donations of **inventory** assets **dilute** LPs). Buffered leg: **`IERC20(SE_i).balanceOf(hook)` is the book** — SE share donations **dilute** LPs; free pair-token dust on buffered legs is **not** native reserve. Stray unrelated ERC-20s **ignored**. Views, LP algebra, growth, and swap composition re-read live inventory when the next step needs post-inventory state |
| D22 | Rated balance (swaps **only**) | For each leg \(i\), compute **pair-token units** then scale with **pair-token** `baseScale`: **(a)** raw → live face; **(b)** buffered + RP → `seBal * getRate() / 1e18` (**fail-closed**); **(c)** buffered + no RP → SE **claim** via fee-inclusive unwrap preview. **Do not** also multiply claim by RP. **Do not** use free pair-token `token.balanceOf(hook)` for buffered legs. **Never used for LP mint/burn / kLast** |
| D23 | LP domain | **All liquidity ops** (join/exit/first-mint/`kLast`/one-token aliases): **inventory only** — raw face or **live SE share balances**. **No** `getRate()`. **No** live claim in LP algebra. User-facing deposit/withdraw amounts are **pair tokens** at the edge (buffer/unwrap). **SE yield / RP changes do not mint or burn LP** and do not rewrite ownership. Taxable single-asset join/exit fees use inventory-domain Stable single-asset logic with fee channel **D41a** |
| D23a | Dual WAD scales | **(1) Inventory WAD** — `invScale_i = 10^(36 - invDecimals_i)` where raw legs use pair-token `decimals()`, SE legs use **`IERC20(SE_i).decimals()`** (share token). Used for join/exit/first-mint/`kLast`. **(2) Rated WAD** — `ratedScale_i = 10^(36 - pairDecimals_i)` for every leg’s **pair-token** `decimals()` after pairUnits are in pair-token space. Fail if any used `decimals()` out of **[6, 18]** or reverts |
| D24 | Growth measure domain | \(k\) / `kLast` on **inventory-domain** product measure (full-book geometric / product peer; plan freezes exact root form) — face WAD and **share** WAD via **inventory** scales — **not** claim, **not** RP, **not** pair-token mark-to-market |
| D25 | Yield in **swap** price | Re-read **live** SE share balances + claim and/or rate each **swap** quote; SE profit / rate moves **swap** mid without a swap. LP supply/ownership unchanged until a liquidity op |
| D26 | Witness tokens | For pair \((in,out)\), the **other two** indices always enter StableSwap invariant / target-reserve solves on **rated** balances. Solver **must tolerate** zero-rated witnesses (**defensive only** — Q7 / D49 / D72). v1 does **not** require constructing native partial books in product tests |
| D27 | Solver | Newton-Raphson; max **255** iterations; convergence when \(\lvert\Delta\rvert \le 1\); on failure **revert** |
| D28 | Share / claim composition | For buffered **tokenIn**: map raw amountIn → SE shares (buffer preview) → **rated inflow** via rate (if RP) or claim delta (if no RP). Never feed raw amountIn into StableSwap as if 1:1 under SE fees. Buffered **tokenOut**: invert rated → shares/claim → native token. Raw legs: face amounts. Same composition for V4 swaps and SE In/Out swaps |
| D28a | SE exact-out / invert unsupported | If a bound SE **does not support** the required exact-out (or invert) route for buffer/unwrap composition on a path, the **entire transaction reverts**. No partial fill; no approximate solver |
| D29 | Buffer-last | Normative join / single-asset / multipath process: quote/size on pre-buffer book → inventory moves → **buffer all SE legs last** (binding index order) → mint / `kLast` on post-buffer native inventory. Do **not** re-quote StableSwap mid-flight after buffer |
| D30 | SE I/O to bound vaults | Bound SE: `exchangeIn` / `exchangeOut` only; tight minOut/maxIn = fee-inclusive SE preview; SE deadline `block.timestamp` if required. Under-delivery or missing route → **full tx revert** (D28a) |
| D31 | SE usage fees | **Orthogonal** to product design. Inside SE previews/execution only. Product fees = trading residual + growth mint |
| D32 | Free pair dust | **`MAX_DUST_WEI = 10`**. After liquidity ops, free balances of **buffered** pool tokens **> 10 wei** **refund to `msg.sender`**. Raw-leg live inventory is **not** refunded |
| D33 | Post-swap floors | Successful swap must leave both trade-leg **native** inventories \(> 0\) and both **rated** balances \(> 0\) |
| D34 | Post-state priceability | After **swap** and **join** paths that claim to leave a priceable book: re-run invariant on **rated** balances; if non-convergent, **revert**. **Proportional remove** exempt when leaving residual book that still passes exit floors |
| D35 | Quote matrix | Exact-in + exact-out both directions on every directed pair door **and** on SE In/Out; closed form |

### 3.3 LP & liquidity surfaces

| # | Decision | Value |
|---|----------|--------|
| D36 | LP token | Single fungible **ERC-20 on the hook** (proxy is LP); decimals **18**; free transfer; EIP-2612 via shared facets |
| D37 | LP ownership | Pro-rata of **all inventory components** (raw balances + SE share balances) |
| D38 | MINIMUM_LIQUIDITY | **1000** LP wei to `address(0)` on first mint; **never burned** |
| D39 | Join surface (full book) | **(1) Proportional multi-asset** on inventory domain — **required v1**. **(2) Single-asset exact-in** — **required v1**. **(3) Single-asset exact-LP-out join** — ship **iff** closed-form (Phase 0 / D41); else selector remains on MultiAssetLiquidity and **reverts `InvalidRoute`**. **(4) Unbalanced multi-asset** — ship **iff** closed-form + preview==exec (Phase 0 / I3); else **`InvalidRoute`**. Taxable fee (D41a) + invariant safety. Buffer-last on SE legs. User pulls **pair tokens** |
| D40 | Exit surface (full book) | Proportional exact LP in — **required**. Single-asset exact LP in — **required**. Exact token out — ship **iff** closed-form (D42a); else **`InvalidRoute`**. **post-state all four native inventories > 0** (D48). Unwrap SE legs to pair tokens |
| D41 | One-token entry | **`depositSingle` ≡ `joinSingleAssetExactIn`** — **required v1** when full book. Exact-LP-out single-asset join = **`joinSingleAssetExactOut`**: Phase 0 audit; **ship if closed-form + bit-exact preview; else leave selector and revert `InvalidRoute`** (exec + preview). **No** multi-leg internal rebalance. Taxable economics per **D41a**. Mint LP to **`to`** |
| D41a | Single-asset taxable fee channel | **Live `feeOracle.dexSwapFeeOfVault(address(this))` WAD** on the **taxable portion** of inventory-domain Stable/Balancer single-asset join and exit (Weighted peer). Residual stays in **inventory book**. 0 allowed; require `< 1e18`. **Not** `usageFeeOfVault` as the single-asset curve tax (usage remains protocol growth / `kLast` only — D61). Applies to hook liquidity surface and MultiAssetLiquidity aliases equally |
| D42 | One-token exit exact LP | **`withdrawSingle` ≡ single-asset exit exact LP in → one `tokenOut`** — **required v1**. Burn **`msg.sender`** LP; pay pair tokens to **`to`**. Full book only; floors D48; taxable portion per D41a |
| D42a | One-token exit exact out | **Implementation plan Phase 0:** audit StableMath / raw-quad / Balancer Stable for closed-form single-token exact-out. **If yes** → ship `withdrawSingleExactOut` / `exitSingleAssetExactTokenOut` + bit-exact preview. **If no** → selectors remain (shared MultiAssetLiquidity) and **revert `InvalidRoute`** (exec + preview); **omit from behavioral DoD** (not from ABI cut). **Never** binary-search |
| D43 | No multi-leg rebalance “zap” | **Forbidden in v1:** raw-quad multi-leg force-buy, dual/orbital multi-leg rebalance for single-asset deposit/withdraw. One-token paths are **only** Stable single-asset join/exit. Do **not** use “zap” to mean multi-leg rebalance |
| D44 | First mint | **All four amounts > 0** (pair-token edge amounts that settle to four positive **native** inventories after buffer). **Not** via one-token join. **`shares = geometricMean(inventoryWadAmounts) − MINIMUM_LIQUIDITY`** (4-value pairwise geometric mean peer raw-quad D26, but on **inventory** WAD: face for raw, **share** WAD for buffered — **not** claim, **not** RP). Require shares > 0; dead MIN to `address(0)`; buffer-last; no protocol mint while `kLast == 0`; post-state rated invariant must converge |
| D45 | Subsequent proportional mint | Classic proportional: `shares = min_i(used_i * supply / inv_i)` on **inventory** units; clamp used ≤ provided; buffer-last |
| D46 | LP name/symbol | Auto **`SEQS-{s0}-{s1}-{s2}-{s3}`**. Prefix **`SEQS`** locked (not a Solidity type name). **Hard caps:** symbol ≤ **32** chars; name ≤ **64** chars. Truncate middle token symbols with `..` when over cap; if still over → **address-fragment fallback** `SEQS-{hookAddress hex slice}`. Cache at init |
| D47 | Funding (LP) | **ERC-20 `transferFrom`** when allowance to hook is sufficient; else **Permit2 AllowanceTransfer only** (`permit2.transferFrom` — user must approve Permit2 → hook). **No SignatureTransfer on LP joins** (no `permit2Data` signature blob on join ABI). Same pull law for MultiAssetLiquidity deposits. **Refunds → `msg.sender`**. **LP minted to `to`**. Exit burns **`msg.sender` LP only** |
| D48 | Full-book exit floors | Any remove while full book must leave **all four native reserves \(> 0\)**. Zeroing a leg via full-book exit **reverts**. **v1 first mint never creates partial book**. **v1 operational paths do not intentionally create native partial book** |
| D49 | Partial book / zero-witness after seed | **Operational:** v1 does **not** intentionally create native-zero legs (D48 + first mint all four). Multi-asset LP while any native leg is zero **reverts**. Single-asset join/exit requires full book. **Solver (defensive):** directed swap allowed iff both trade-leg **native > 0**, both trade-leg **rated > 0**, and invariant solve + post-state priceability succeed — **witness rated legs may be zero** (raw-quad D72 spirit). Hermetic DoD need **not** construct partial books as a matrix row; optional defensive unit tests may force zero witnesses in pure Math only |
| D50 | LP deadline | All LP **mutators** take **`deadline`** and **`require(block.timestamp <= deadline)`** |
| D51 | Reentrancy | One global non-reentrant lock on join/exit/one-token/SE surfaces **and** `beforeSwap` body (after PM sender check) |
| D52 | Preview fidelity | **Bit-exact** `preview* == execution` at same oracle fee reads, same SE previews, same rate reads, same ceil/floor path (incl. one-token aliases + SE In/Out + multi-token SE liquidity) |

### 3.4 SE In/Out and interface extensions

| # | Decision | Value |
|---|----------|--------|
| D53 | SE In/Out swaps | **Required v1:** implement `IStandardExchangeIn` + `IStandardExchangeOut` for exact-in/out **tokenᵢ ↔ tokenⱼ** (`i ≠ j`, both bound) against the **same** rated StableSwap book as public V4 swaps. **Internal settle** (no PoolManager unlock). **Not** LP mint/burn. Previews required and bit-exact |
| D54 | SE In/Out token domain | Only the four bound pool tokens. Revert if token is SE share address, unbound, or same token in/out |
| D55 | SE In/Out funding | **Canonical** pull when `!pretransferred`: BasicVaultCommon peer — ERC-20 `transferFrom` if allowance to hook, else Permit2 **AllowanceTransfer**. `pretransferred` requires balance already on hook. **No** SignatureTransfer on canonical SE In/Out ABI. Hook is Permit2-aware |
| D56 | SE one-token aliases | **Required v1** on **`IStandardExchangeMultiAssetLiquidity`**: **identical** selectors/args to hook `depositSingle` / `withdrawSingle` / exact-out variants when shipped; when not shipped, same selectors **revert `InvalidRoute`**. Shared Target implementation |
| D57 | Multi-token SE liquidity | **Required v1:** implement **full shared** `IStandardExchangeMultiAssetLiquidity` (`contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol`) as a **thin facade** over shared Target — **same function names, argument order, and return types as the interface**. Hook liquidity surface exposes the **same** selectors. **Not** merged into In/Out. No DETF-specific names. Phase-0-unsupported methods **must still be present** and **revert `InvalidRoute`** (exec + matching `preview*`) — Q8 |
| D57a | Frozen liquidity function names | **Normative external names (hook + MultiAssetLiquidity — full shared interface cut):** `joinProportional`, `joinUnbalanced`, `joinSingleAssetExactIn`, `joinSingleAssetExactOut`, `exitProportional`, `exitSingleAssetExactBptIn`, `exitSingleAssetExactTokenOut`, plus aliases `depositSingle` → `joinSingleAssetExactIn`, `withdrawSingle` → `exitSingleAssetExactBptIn`, `withdrawSingleExactOut` → `exitSingleAssetExactTokenOut`. Each mutator has matching `preview*`. Args always include `to`, `deadline`, and slippage mins as applicable. **No** `permit2Data` arg. **Behavioral ship set:** proportional + `joinSingleAssetExactIn` + `exitSingleAssetExactBptIn` + aliases **required**. `joinSingleAssetExactOut` / `exitSingleAssetExactTokenOut` / `joinUnbalanced` **ship iff Phase 0 closed-form**; otherwise **`InvalidRoute`** forever in v1 until PRD revision |
| D57b | Unsupported path error | Canonical revert for Phase-0-omitted or never-supported MultiAssetLiquidity / liquidity selectors: **`InvalidRoute`**. Previews of those selectors **must also revert** (no optimistic fake amounts) |
| D58 | SE liquidity ≠ swap | Multi-token deposit/withdraw and one-token aliases **mint/burn hook LP**. Canonical two-token `exchangeIn`/`exchangeOut` remain **swap-only** (D53) |

### 3.5 Fees, protocol growth, ops

| # | Decision | Value |
|---|----------|--------|
| D59 | Trading (swap) fee | **Live** `feeOracle.dexSwapFeeOfVault(address(this))` WAD; 0 allowed; require `< 1e18`. **Input residual** (exact-in: StableSwap on **net** after fee; exact-out: ceil gross-up). Residual stays in **input** inventory/book. Applies to V4 swaps and SE In/Out swaps. **Supersedes** raw-quad fee-on-output pips for this package. **Same channel** feeds single-asset taxable portion (D41a) — not a separate deploy-time fee |
| D59a | Buffer gross amountIn | On buffered **tokenIn**: after take, **buffer the full gross `amountIn`** taken from the swapper (exact-in) / paid input (exact-out gross). StableSwap uses **fee-net** for the curve only. Residual is **not** left as free pair dust — it becomes SE shares (or raw face inventory) with the gross buffer/credit |
| D59b | Single-asset fee vs growth | Single-asset **taxable** fee = **`dexSwapFeeOfVault`** residual into book (D41a). Protocol growth mint = **`usageFeeOfVault` + `kLast`** on LP add/remove when fee-on (D61–D64). **Do not** double-charge usage as a single-asset curve tax |
| D60 | Trading fee → V4 units | Floor map WAD → pips + `OVERRIDE_FEE_FLAG` on `beforeSwap`. Economic SoT = hook residual — **no double-haircut** |
| D61 | Protocol growth fee | **Yes** — Uni V2–style. Live `usageFeeOfVault(this)`; mint LP to live `feeTo()` on add/remove when fee-on. **Not** on every swap |
| D62 | fee-on predicate | `feeTo != 0 && usageFeeWad != 0 && usageFeeWad < 1e18 && ownerFeeShare != 0` with `ownerFeeShare = usageFeeWad * 100_000 / 1e18` (floor) |
| D63 | `kLast` measure | **Full book:** inventory-domain product / geometric measure of four inventory WAD balances (plan freezes exact root form peer Uni V2 / multi-asset growth). Store `kLast` + mode if needed. **v1 does not mint growth from partial-book modes** (full four only for growth) |
| D64 | Growth timing | Protocol mint from **pre-intake** \(k\) on add; mint before user burn on remove; set `kLast` post-op when fee-on. Swaps do not mint protocol LP or update `kLast` |
| D65 | Previews + growth | LP previews **simulate** protocol mint dilution when fee-on |
| D66 | Tick spacing | Package constant **`TICK_SPACING = 1`**. `beforeInitialize` enforces |
| D67 | Init sqrt price | Each `deployPair`: `TickMath.getSqrtPriceAtTick(0)` (plumbing only) |
| D68 | Factory doors only | `beforeInitialize` accepts **only** PoolKeys that match factory-door rules: both currencies in bound set, distinct, **`fee == DYNAMIC_FEE_FLAG`**, **`tickSpacing == TICK_SPACING`**, **`hooks == this`**. Extra keys **revert** |
| D69 | Access | Liquidity + views + SE surfaces permissionless; hook callbacks `msg.sender == poolManager` only |
| D70 | Admin | **None** on hook — no SE/RP/amp update, no pause, no fee setter |

### 3.6 Deploy, vault surface, tests

| # | Decision | Value |
|---|----------|--------|
| D71 | Deploy path | **Required:** `IUniswapV4HookDiamondPackage` + Vault Registry `deployHookVault` + shared `UniswapV4HookDiamondPackageCallBackFactory`. Facets CREATE3 via FactoryService. **Never** `new` SUT; **never** vault factory salt for V4 flag addresses |
| D72 | Directed swap gate | Swap allowed iff trade-leg **native > 0**, trade-leg **rated > 0**, invariant solve + post-state priceability succeed. **Witness rated legs may be zero** — **defensive solver only** (Q7); not a required product matrix row. First-minted book required (\(totalSupply > 0\) after MIN) |
| D73 | Salt law / PRODUCT_ID | **`PRODUCT_ID = "UniswapV4StandardExchangeCurveQuadStableBufferHook"`** (full type name). `packageSalt` from `PRODUCT_ID` + binding fields (**tokens, SEs, RPs, baseAmp**) + factory-scope identity as factory PRD requires (**no** package/facet addresses). PM/oracle are factory immutables. `finalSalt = keccak256(abi.encode(packageSalt, mineNonce))` |
| D74 | Mine flags | At least `BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_REMOVE_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA \| BEFORE_DONATE` (plan locks exact mask vs `Hooks.ALL_HOOK_MASK`) |
| D75 | Pool init UX | Staged: permissionless `deployPair(tokenA, tokenB)` opens one product door (both args distinct bound tokens; key from PairPoolLib after sort). `finalizeInitialization` succeeds only when all six product doors are live. Extra tick/fee pools do not count. See staged PRD. |
| D75a | ensurePairPools | Permissionless **`ensurePairPools()`** may repair missing product doors after finalize. Does **not** pull tokens or mint LP. Not the required bootstrap path. |
| D76 | Deposit vs pool init | LP add/remove/previews **do not require** V4 initialize. **Swaps** require first-minted book, initialized directed pair pool, both trade-leg native + rated \(> 0\) |
| D77 | Vault discovery | **Required v1:** `IBasicVault` + `IStandardVault` multi-asset discovery: `vaultTokens()` = binding tokens; **`reserveOfToken(token_i)`** = **raw face** for raw legs; **live SE share balance** for buffered legs. **Not** free pair-token dust; **not** SE claim; **not** shares×rate. Consumers that need pair-token units use `seClaim(i)` / `ratedBalance(i)` / previews |
| D78 | Test matrix (min) | Production-first; real V4 PM; real Vault Fee Oracle with defaults; real SE ports / ERC-4626 Wrapper SE. **Hermetic required:** (a) **1 SE** + three raw; (b) **2 SE**; (c) **3 SE**; (d) **4 SE** all buffered; (e) RP zero/non-zero on ≥1 buffered config; first mint all-four inventory geo-mean; proportional join/exit; single-asset aliases + taxable fee via `dexSwapFeeOfVault`; SE In/Out full directed matrix; full MultiAssetLiquidity cut (shipped paths bit-exact; unsupported → `InvalidRoute`); gross buffer on swaps; `reserveOfToken` shares; protocol growth; rate fail-closed; `ensurePairPools`; mixed decimals 6/18; amp bounds; zero-SE deploy **reverts**; full-book exit floors. **Not required:** construct native partial-book / zero-witness product states (defensive Math unit tests optional). **No** mock hook / mock SE SUT |
| D79 | Fork DoD | **Ethereum + Base + Robinhood (4663) all required, equal priority** after hermetic. Production PM/Permit2/fee oracle when present; deploy-if-missing production-equivalent. May deploy mintable tokens + wrapper SEs on fork |
| D80 | DETF coupling | Fully independent product/test surface — **no DETF work in this PRD** |
| D81 | Impl plan follow-on | `UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` |

### 3.7 Implementation edges (locked)

| ID | Topic | Value |
|----|--------|-------|
| O1 | Native / rated views | Required public `nativeReserve(uint8 i)` / `nativeReserves()`; `ratedBalance(uint8 i)` / `ratedBalances()`; also per-token `reserveOfToken` — re-read **live** inventory |
| O2 | SE / RP / amp views | `standardExchange(uint8 i)`, `rateProvider(uint8 i)`, `isBuffered(uint8 i)`, `seClaim(uint8 i)`, `seBalance(uint8 i)`, `baseAmp()`, `getCurrentAmp()` (scaled) |
| O3 | One-token aliases | `depositSingle` + `withdrawSingle` required; exact-out / exact-LP-out variants ship if Phase 0 closed-form else `InvalidRoute` |
| O4 | Internal settle | Buffer/unwrap helpers shared; V4 swaps settle via PM deltas; LP + SE surfaces **do not** unlock PM for curve settle |
| O5 | Rate fail-closed | Non-zero RP: failed `getRate` or non-positive rate **reverts** any path that needs that leg’s **rated** balance |
| O6 | Multi-SE buffer order | Binding index order after all used amounts finalized |
| O7 | Swap inventory order | Take tokenIn → StableSwap settle amounts → buffer tokenIn if SE → unwrap/pay tokenOut if SE; never leave free buffered-token inventory as book |
| O8 | LP ERC-20 location | Same mined hook proxy |
| O9 | Math library | Pure Math: StableSwap invariant / target \(y\) / fee residual / dual scale helpers / first-mint geo-mean / growth helpers — **no** SE external calls inside pure Math; **no** multi-leg rebalance “zap split” helper; witness-zero defensive unit tests OK in pure Math |
| O10 | Inventory re-read | Re-read **live** SE share balances + claims + rates when next step needs post-inventory state. **Do not** re-solve StableSwap mid-flight after buffer (buffer-last) |
| O11 | Adversarial DoD | Reentrancy (LP↔swap↔SE), donation dilution (incl. SE share donations), `feeTo` non-receivable, SE revert mid-buffer/join, RP fail-closed, full-book zero-leg exit, distinct-SE / zero-SE binding rejects, amp bounds, unsupported MultiAssetLiquidity → `InvalidRoute` |
| O12 | SE multi-token ABI | Interface name **locked:** shared `IStandardExchangeMultiAssetLiquidity`. **Full interface cut**; unsupported → **`InvalidRoute`** (D57 / D57b) |
| O13 | Single-asset taxable fee | Taxable portion uses **`dexSwapFeeOfVault`** (D41a / D59b); growth uses **`usageFeeOfVault`** — never conflate |

### 3.8 Stakeholder pins (Q1–Q9) — **LOCKED**

| # | Topic | Locked value |
|---|--------|--------------|
| **Q1** | SE binding | **≥1 SE required** (Weighted peer). Optional SE per remaining leg. Non-zero SEs pairwise distinct. Zero-SE → use raw Quad package |
| **Q2** | Rate providers | **SE RP only on buffered legs** (Orbital peer). No RP → SE claim for rated. **No pair-token RP on raw legs in v1** |
| **Q3** | LP domain | **Native inventory only** (Weighted peer). Swaps use rated balances. SE yield/RP does not mint/burn LP |
| **Q4** | One-token LP | **Balancer/Stable single-asset join/exit aliases** only. **No** multi-leg rebalance zap (raw-quad / orbital style out) |
| **Q5** | Fees | **Live Vault Fee Oracle dual-channel** (Orbital/Weighted SE peer). Trading residual + protocol growth. `DYNAMIC_FEE_FLAG` |
| **Q6** | First mint / partial | **First mint requires all four legs > 0**. Full-book exits must leave all four native \(> 0\). Single-asset requires full book. **v1 does not intentionally create partial book** |
| **Q7** | Zero-witness | **Defensive solver only** — StableSwap must tolerate zero-rated witnesses if they occur (raw-quad spirit). **Not** a required reachable product state or hermetic matrix row. Optional pure-Math unit tests only |
| **Q8** | MultiAssetLiquidity ABI | Implement **full shared** `IStandardExchangeMultiAssetLiquidity`. Phase-0 / never-shipped paths **revert `InvalidRoute`** (exec + preview). Do not drop selectors from the cut |
| **Q9** | Single-asset taxable fee | Taxable portion of single-asset join/exit = live **`dexSwapFeeOfVault`** (Weighted peer). Residual stays in inventory book. Protocol growth remains **`usageFeeOfVault` + `kLast`** |

---

## 4. Architecture

### 4.1 Stack

```text
┌──────────────────────────────────────────────────────────────────┐
│ Integrator / anyone (permissionless liquidity + swaps)           │
│   • registry/pkg deployHookVault(args, mineNonce)                │
│   • join / exit / depositSingle / withdrawSingle* on Hook        │
│   • SE In/Out + IStandardExchangeMultiAssetLiquidity             │
│   • swapExact* via V4 on any of the 6 pair doors                 │
└───────────────┬─────────────────────────────┬────────────────────┘
                │                             │
                ▼                             ▼
┌───────────────────────────┐   ┌──────────────────────────────────┐
│ Hook Diamond Factory      │   │ Uniswap V4 PoolManager           │
│  CREATE2 proxy + flags    │──►│  init all 6 pair doors           │
│  registry.deployHookVault │   │  fee = DYNAMIC_FEE_FLAG          │
└───────────────┬───────────┘   │  hooks = this diamond            │
                │               └──────────────────────────────────┘
                ▼
┌──────────────────────────────────────────────────────────────────┐
│ UniswapV4StandardExchangeCurveQuadStableBufferHook (diamond)          │
│  tokens[4] + SE[4]? (≥1) + RP[4]? + baseAmp                      │
│  inventory: raw and/or SE shares                                 │
│  rated book for StableSwap D / y                                 │
│  LP ERC-20 + feeOracle + kLast                                   │
└───────────┬───────────────────────────────┬──────────────────────┘
            │ buffer / unwrap               │ optional getRate (swaps)
            ▼                               ▼
┌───────────────────────┐         ┌───────────────────────┐
│ IStandardExchange ×1–4│         │ IRateProvider ×0–4    │
└───────────────────────┘         └───────────────────────┘
```

### 4.2 Virtual multi-pool (“six doors, one room”)

```text
Pool t0/t1  ──┐
Pool t0/t2  ──┤
Pool t0/t3  ──┼──► same hook (shared inventory + rated StableSwap book + A)
Pool t1/t2  ──┤
Pool t1/t3  ──┤
Pool t2/t3  ──┘
```

Pool currencies are always the **four ERC-20 tokens**. SE shares never appear in `PoolKey` currencies.

A `t0→t1` swap still uses **t2 and t3 rated balances as witnesses** in the StableSwap solve. The solver **must tolerate** zero-rated witnesses (**defensive robustness** — Q7); v1 product paths do not intentionally create native-zero legs.

### 4.3 Native vs rated balances (normative)

```text
// --- Inventory (LP / kLast / reserveOfToken) — live balances ---
for i in 0..3:
  if standardExchange[i] == address(0):
      inv_i = token_i.balanceOf(hook)               // live face; donations dilute
      invWad_i = toWad(inv_i, decimals(token_i))
  else:
      inv_i = IERC20(SE_i).balanceOf(hook)          // live SE shares
      invWad_i = toWad(inv_i, decimals(SE_i))       // share decimals

// --- Rated (StableSwap swaps only) ---
for i in 0..3:
  if standardExchange[i] == address(0):
      pairUnits_i = token_i.balanceOf(hook)         // live face
  else:
      seBal_i = IERC20(SE_i).balanceOf(hook)
      if rateProvider[i] != address(0):
          rate = IRateProvider(rateProvider[i]).getRate()  // fail-closed
          pairUnits_i = seBal_i * rate / 1e18
      else:
          pairUnits_i = SE_i.previewExchangeIn(SE_i, seBal_i, token_i)  // claim

  ratedWad_i = toWad(pairUnits_i, decimals(token_i))  // always pair-token decimals
  // Free token_i on hook when buffered is NOT inventory and NOT rated book
  // Witness rated legs may be 0 for solver robustness only (Q7)
```

### 4.4 StableSwap pricing (normative sketch)

Behavioral peer: raw Quad §4.4 with \(x_i := ratedWad_i\), amp scaled by `AMP_PRECISION`, fee residual per **D59** (input residual), **not** raw-quad fee-on-output.

**Exact-in (sketch):**

```text
// 1) Fee-net amountIn for curve (dexSwapFee WAD)
amountInNet = amountIn * (1e18 - feeWad) / 1e18   // floor; residual stays in book path
// 2) Map amountInNet → rated inflow (SE buffer preview if buffered)
ratedIn = map_pair_to_rated_inflow(tokenIn, amountInNet)
// 3) x_in' = x_in + ratedIn; y_out' = getY(...); rawOutRated = x_out - y_out'
// 4) Map rated out → native out (descale + SE unwrap invert if buffered)
// 5) Inventory in: buffer/credit FULL gross amountIn (SE shares or raw face)  // D59a
// 6) post-state: getInvariant on rated must converge
```

**Exact-out:** dual with ceil gross-up of input fee; buffer/credit that **gross** input; invert SE as needed; full tx revert if SE cannot invert.

### 4.5 Liquidity — inventory domain

#### 4.5.1 First mint (all four required)

```text
require all four provided amounts map to native inventory deltas > 0 after buffer preview
// protocol growth: skip while kLast == 0
// pull pair tokens; buffer-last SE legs
invWad[i] = inventory WAD of each leg after buffer
shares = geoMean4(invWad) - MINIMUM_LIQUIDITY
require shares > 0
mint MINIMUM_LIQUIDITY → address(0)
mint shares → to
set kLast if fee-on
// rated invariant must converge post-state
```

#### 4.5.2 Subsequent proportional join / exit

Uni V2-style min-ratio on **inventory** balances (face or SE shares), not on rated claims. Buffer-last on join; unwrap on exit. Protocol mint dilution when fee-on (pre-intake on join; before burn on exit).

#### 4.5.3 Single-asset join / exit

When full book and `totalSupply > MINIMUM_LIQUIDITY`:

- **`depositSingle` / `joinSingleAssetExactIn`:** Stable single-asset join on **inventory** domain. **Taxable portion** charged with live **`dexSwapFeeOfVault`** (D41a / Q9); residual stays in inventory book. Pull one pair token; buffer-last if SE; mint LP.
- **`withdrawSingle` / `exitSingleAssetExactBptIn`:** Stable single-asset exit exact LP in → one pair token out (unwrap if SE); same taxable fee channel on taxable portion.
- Exact-LP-out join / exact-token-out exit: **Phase 0 closed-form only** — ship bit-exact if admitted; else selectors present and **`InvalidRoute`**.
- Protocol growth still via **`usageFeeOfVault` + `kLast`** on LP paths (D59b) — not a second curve tax.

**Forbidden:** multi-leg internal StableSwap rebalance to force-buy missing legs (raw-quad zap-in / orbital zap).

### 4.6 SE In/Out and MultiAssetLiquidity

| Surface | Role |
|---------|------|
| `IStandardExchangeIn` / `Out` | Swap-only tokenᵢ ↔ tokenⱼ on rated StableSwap book; internal settle |
| `IStandardExchangeMultiAssetLiquidity` | **Full shared interface** cut (`contracts/interfaces/…`). Thin facade over Target. Required behavioral paths bit-exact; Phase-0 / never-shipped paths **`InvalidRoute`** on exec **and** preview (D57 / D57b / Q8) |

---

## 5. Deploy shape

```text
1. Deploy facets via CREATE3 FactoryService
2. registry.deployPkg(quadStableBufferPkg initCode, PkgInit, salt)
3. registry.deployHookVault(pkg, PkgArgs, mineNonce)
     → hook factory CREATE2 flag-mine diamond
     → postDeploy: no-op (does not init doors)
4. Permissionless `deployPair` × 6 then `finalizeInitialization`. `ensurePairPools()` may repair after finalize.
```

**PkgArgs (normative fields):**

| Field | Notes |
|-------|--------|
| `tokens[4]` | Strict address ascending |
| `standardExchanges[4]` | ≥1 non-zero; non-zero pairwise distinct |
| `rateProviders[4]` | Non-zero only where SE set |
| `baseAmp` | Immutable amplification (unscaled) |
| `mineNonce` | Flag-mine salt component |

`poolManager` and `feeOracle` come from factory immutables (not per-deploy free args) unless factory PRD requires otherwise — align with weighted/orbital buffer packages.

**Salt:** `PRODUCT_ID = "UniswapV4StandardExchangeCurveQuadStableBufferHook"` + binding fields (D73).

**Flags:** at least beforeInitialize / beforeAddLiquidity / beforeRemoveLiquidity / beforeSwap / beforeSwapReturnDelta / beforeDonate (D74).

---

## 6. Events (minimum DoD)

| Event | Minimum fields |
|-------|----------------|
| Join / Exit / MultiAsset same | `sender`, `to`, `shares`, `int256[4] deltas` (binding order; pair-token edge amounts), `protocolSharesMinted` |
| DepositSingle | `sender`, `to`, `token`, `amountIn`, `shares`, `protocolSharesMinted` |
| WithdrawSingle | `sender`, `to`, `token`, `amountOut`, `shares`, `protocolSharesMinted` |
| WithdrawSingleExactOut (iff shipped) | `sender`, `to`, `token`, `amountOut`, `sharesBurned`, `protocolSharesMinted` |
| ProtocolFeeMinted | `feeTo`, `shares` |
| EnsurePairPools | `hook`, `doorsEnsured` |
| **No** product-level `Swap` event | V4 Swap logs cover public swaps |

---

## 7. Security properties (normative)

1. **Immutable binding** after deploy — no SE/RP/amp/token rebind.  
2. **Reentrancy:** single lock across LP, SE surfaces, and `beforeSwap` body.  
3. **No CL / donate** surfaces.  
4. **SE invert fail-closed** — missing exact-out/invert reverts entire tx.  
5. **RP fail-closed** on rated paths.  
6. **Donation dilution** accepted for inventory assets (raw face / SE shares); free pair dust on buffered legs refunded (≤10 wei residual).  
7. **Distinct SE** and **≥1 SE** validated at init.  
8. **Full-book exit floors** prevent draining a leg via proportional/single-asset exit.  
9. **`feeTo` non-receivable** → protocol mint reverts whole LP op (peer).  
10. **No mixed** transferFrom + Permit2 SignatureTransfer on joins (AllowanceTransfer peer only).  
11. **Unsupported liquidity selectors** → **`InvalidRoute`** on exec and preview (no silent no-op or approximate fill).

---

## 8. Definition of Done

Package is **done** when:

- [ ] Files under `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/` (facets, Repo, Target, Math, DFPkg, FactoryService, interfaces, TestBase).  
- [ ] Deploy path: facets CREATE3; instance via `deployHookVault` + shared hook factory; **all six** doors via `deployPair` × 6 then `finalizeInitialization`.  
- [ ] Binding: four ascending tokens; ≥1 SE; distinct SEs; RP only on SE legs; immutable `baseAmp`.  
- [ ] First mint: all four legs; inventory geo-mean − MIN; buffer-last.  
- [ ] Proportional join/exit inventory domain; single-asset aliases (no multi-leg zap); single-asset taxable fee = **`dexSwapFeeOfVault`**.  
- [ ] Swaps: rated StableSwap + witnesses; live dual-channel fees; gross buffer; post-state priceable; solver tolerates zero-rated witnesses (**defensive only**).  
- [ ] SE In/Out + **full** MultiAssetLiquidity cut; shipped paths preview == execution; unsupported → **`InvalidRoute`**.  
- [ ] `reserveOfToken` = live face | live SE shares; `ratedBalance` / `seClaim` separate.  
- [ ] Protocol growth on LP paths; `PRODUCT_ID` full type name; LP prefix `SEQS`.  
- [ ] Hermetic matrix D78; forks Ethereum + Base + 4663.  
- [ ] Adversarial O11 green.  
- [ ] **No** DETF / mock SUT in DoD.

---

## 9. Open items for implementation plan only (non-blocking)

| # | Item | Notes |
|---|------|-------|
| I1 | Exact `kLast` root form for 4-asset inventory product | Peer multi-asset growth; freeze bit-exact in plan |
| I2 | Phase 0: closed-form Stable single-asset exact-LP-out join / exact-token-out exit | Ship bit-exact if closed-form; else keep selectors and **`InvalidRoute`** (D41 / D42a / Q8) |
| I3 | Phase 0: unbalanced multi-asset join/exit | Ship only if closed-form + preview==exec; else **`InvalidRoute`** on `joinUnbalanced` |
| I4 | Exact mine flag mask vs `Hooks.ALL_HOOK_MASK` | Factory peer |
| I5 | Concrete facet cut list + storage layout | Crane diamond patterns |
| I6 | Numeric test vectors for geo-mean first mint under mixed decimals + SE buffer fees | Must match previews |
| I7 | Optional pure-Math unit vectors with zero-rated witnesses | Defensive only; not product integration matrix (Q7) |

---

## 10. Comparison matrix

| | Raw Quad Stable | SE Orbital Buffer | SE Weighted Buffer | **This package** |
|--|-----------------|-------------------|--------------------|------------------|
| Assets | 4 | 3 | 2–8 | **4** |
| Curve | StableSwap \(A\) | Sphere | Weighted | **StableSwap \(A\)** |
| SE | None | 0–3 optional | ≥1 required | **≥1 required** |
| LP domain | Repo raw / rate-scaled | Effective | Native inventory | **Native inventory** |
| Swap domain | Rate-scaled reserves | Effective | Rated | **Rated** |
| One-token LP | Multi-leg zap-in | Multi-leg zap-in | Single-asset alias | **Single-asset alias** |
| Single-asset tax | N/A (zap) | N/A (zap) | `dexSwapFee` taxable | **`dexSwapFee` taxable** |
| MultiAssetLiquidity | N/A | N/A | Full interface | **Full shared interface; unsupported → `InvalidRoute`** |
| Zero-witness | Allowed product-wise | N/A | Partial book modes | **Defensive solver only** |
| Fees | Deploy pips fee-on-output | Oracle dual-channel | Oracle dual-channel | **Oracle dual-channel** |
| Doors | 6 | 3 | \(\binom{n}{2}\) | **6** |
| Deploy | Hook factory (after refactor) | Hook diamond package | Hook diamond package | **Hook diamond package** |

---

## 11. Suggested file layout

```text
contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/
  UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_PRD.md          # this file
  UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md
  interfaces/
    IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol
  facets/
    UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet.sol
    UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet.sol
    UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHookPullLib.sol
  TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol
```

---

## 12. Revision log

| Version | Date | Notes |
|---------|------|-------|
| **v0.1** | 2026-08-07 | Initial PRD. Co-design Q1–Q6 locked: ≥1 SE; SE RP + claim; native LP / rated swaps; single-asset aliases (no multi-leg zap); oracle dual-channel fees; first mint all four + witness-zero swaps. Curve from raw Quad StableSwap; buffer process from SE Orbital / Weighted Buffer peers. Plan-ready for implementation plan. |
| **v0.2** | 2026-08-07 | **Product LOCK.** Review pins: Q7 zero-witness = defensive solver only (not required product matrix); Q8 full shared `IStandardExchangeMultiAssetLiquidity` with unsupported → `InvalidRoute`; Q9 single-asset taxable = `dexSwapFeeOfVault` (Weighted peer). Live inventory SoT wording (D21); D41a / D57b / D59b; test matrix and DoD updated. Co-located implementation plan **v1.0** is implementor SoT for phases/tests. |

---

## 13. Acceptance criteria for product LOCK — **SATISFIED (v0.2)**

Product law is **LOCKED**. Stakeholders / review confirmed:

1. ✅ Name + path + PRODUCT_ID.  
2. ✅ ≥1 SE + distinct SE + SE-only RP.  
3. ✅ Dual domains (inventory LP vs rated StableSwap).  
4. ✅ Single-asset aliases only (no multi-leg zap).  
5. ✅ Oracle dual-channel fees (no deploy-time pips economic SoT).  
6. ✅ First mint all four; **zero-witness = defensive solver only** (Q7); full-book exits leave all four native \(> 0\).  
7. ✅ Six doors + hook diamond package deploy path.  
8. ✅ DETF out of DoD.  
9. ✅ Single-asset taxable fee = live **`dexSwapFeeOfVault`** (Q9 / D41a).  
10. ✅ Full shared MultiAssetLiquidity cut; unsupported → **`InvalidRoute`** (Q8 / D57 / D57b).  
11. ✅ Phase 0: ship exact-LP-out / exact-token-out / unbalanced **iff** closed-form; never binary-search.

**Implementation plan** (`UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`) is now the implementor SoT for phases/tests. Further product changes require **explicit PRD revision** (v0.3+).
