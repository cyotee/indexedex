# PRD: Uniswap V4 Standard Exchange Orbital Buffer Hook

**Name:** `UniswapV4StandardExchangeOrbitalBufferHook`  
**Date:** 2026-08-04  
**Status:** **Draft v0.3 — product law (open items resolved; plan-ready for impl plan)**  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/orbital/`  
**Package kind:** IndexedEx **Uniswap V4 hook diamond package** that is **also** a vault-compatible multi-asset surface. Instance deploys via the **shared Hook Diamond Package Callback Factory** + Vault Registry `deployHookVault` (CREATE2-mined proxy). **Not** a concentrated-liquidity (CL) reimplementation. **Not** the raw-inventory monomorph `UniswapV4OrbitalSwapHook` under `contracts/hooks/uniswap/v4/orbital/`.

**Decision ID note:** `D*`, `O*`, and `Q*` IDs are **stable keys**, not document order.

**v0.2 locks:** Q1 distinct SEs; orbital dual-channel fees; zap-in only; RP rates SE shares; SE In/Out required.  
**v0.3 locks:** SE route without exact-out → **full tx revert**; Q2 native×rate then `toWad`; Q4 `MAX_DUST_WEI = 10`; Q5 **postDeploy** pool init; Q9 **zap-in high-level algorithm in PRD**; Q11 SE In/Out **Permit2 only**.

**Authority (normative):**

| Layer | Role |
|-------|------|
| **This PRD** | Product law for SE-buffered orbital topology, per-leg SE + rate provider binding, effective-reserve sphere pricing, buffer/unwrap process, LP, fees, zap-in, SE In/Out, deploy shape |
| **Implementation plan** (follow-on) | Source of truth for coding phases once written against this PRD |
| Orbital product PRD | **Curve / topology / multipath LP / fee / partial-book behavioral reference only** — do **not** subclass; do **not** copy monomorph CREATE3 factory law; **do not** inherit orbital’s “no zap” non-goal (this product **requires zap-in**) |
| Single SE Buffer CP PRD | **SE buffer / unwrap / buffer-last / zap-in UX / SE In/Out process reference only** — do **not** subclass; adapt to **N ≤ 3 optional SE legs** + sphere (not CP) |
| Weighted / SE rate provider | **`IRateProvider` on SE share balances** (Balancer SE RP peer: shares → token units @ 1e18) + fail-closed |
| Hook factory PRD | **Deploy / salt / flags / immutability law** — `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Skill | `indexedex-uniswap-v4-hook-packages` |

**Sibling packages (do not conflate):**

| Package | Path | Role |
|---------|------|------|
| **Orbital Swap Hook** (raw) | `contracts/hooks/uniswap/v4/orbital/` | 3-asset sphere on **raw ERC-20** inventory; three V4 doors; **no** SE buffering |
| **Single SE Buffer CP Hook** | `…/standardExchange/constantProduct/single/` | **One** SE + **one raw** leg; CP on raw × SE claim; **one** V4 pool |
| **Dual SE Buffer CP Hook** | `…/standardExchange/dual/` | **Two** SEs; CP on **both** claims; **one** V4 pool |
| **Single SE Buffer Hook** | `…/standardExchange/single/` | Wrapper portal `underlying ↔ SE`; **no** multi-asset AMM / no fungible LP book |
| **This package** | `…/standardExchange/orbital/` | **Three** pool tokens; **optional SE per token** (0–3); sphere AMM on **effective reserves**; **three** V4 pair doors |

**Related references:**

- Orbital product law: `contracts/hooks/uniswap/v4/orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md`
- Orbital factory refactor (deploy shape peer): `…/orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_HOOK_FACTORY_REFACTOR_PRD.md`
- Single SE BCP: `…/constantProduct/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`
- Dual SE BCP: `…/dual/UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`
- Weighted rate law: `…/weighted/UNISWAP_V4_WEIGHTED_SWAP_HOOK_PRD.md` (D17 / D18)
- SE rate providers (composition tooling, not required binding type): `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`
- Fee oracle: `contracts/interfaces/IVaultFeeOracleQuery.sol`
- Permit2: Uniswap well-known `0x000000000022D473030F116dDEE9F6B43aC78BA3`
- AGENTS.md — production-first tests; CREATE3 facets; hook instances via hook factory; no mock SUT

---

## 0. Terminology (normative)

| Term | Meaning in this PRD |
|------|---------------------|
| **Binding order** | Deploy/init order `(token0, token1, token2)` — LP views, events `amount0/1/2`, Permit2 batch index order, SE/rateProvider index order |
| **Pool currency order** | V4 `currency0` / `currency1` = pair tokens **sorted by address** (may differ from binding indices) |
| **Pool token / leg token** | One of the three ERC-20s registered as Uniswap V4 pool currencies. **Never** SE share addresses as pool currencies |
| **Raw leg** | Leg with `standardExchange_i == address(0)`. Hook holds **face ERC-20** inventory as that leg’s book |
| **Buffered leg / SE leg** | Leg with non-zero `standardExchange_i`. Hook holds **SE shares**; free pool-token balance is **not** book (dust/refund only) |
| **Standard Exchange / SE** | Bound `IStandardExchange` for a leg; **at most one SE per token**; optional per leg; **non-zero SE addresses pairwise distinct** |
| **SE claim / claim supply** | Pool-token value of hook-held SE shares via fee-inclusive SE unwrap preview: \(c_i = \mathrm{previewExchangeIn}(SE_i,\ seBal_i,\ token_i)\). Used when **no** rate provider is set, and for buffer/unwrap I/O previews |
| **Rate provider** | Optional Balancer-style `IRateProvider` **per SE leg** (`address(0)` = none). When set: **primary** conversion is **SE share balance → token units** via `getRate()` @ 1e18 (Balancer **SE rate provider** peer — rates **shares**, not a second scale on top of claim) |
| **Effective reserve \(e_i\)** | Normative sphere input for leg \(i\): raw face **or** SE-share×rate **or** SE claim (if buffered + no RP) — §4.3 |
| **Inventory** | Physical holdings: raw ERC-20 balances for raw legs; SE share balances for buffered legs |
| **Hook LP / shares** | Fungible ERC-20 on **this** hook (18 decimals). API params named `shares` mean **hook LP**, never SE vault shares |
| **Full book** | All three **effective** reserves \(e_0,e_1,e_2 > 0\) |
| **Partial book** | At least one effective reserve is 0 (and `totalSupply > 0`) |
| **Three doors** | The three Uni V4 pair pools (01, 12, 02) that all set `hooks = this` and share one 3-asset book |
| **Buffer-last** | Quote / size / residual math on **pre-buffer** effective book; execute non-buffer moves; **buffer pair→SE as final SE inventory step**; then LP mint / `kLast` from **post-buffer** effective reserves |
| **Claim-in / claim-out** | SE fee-inclusive preview of how much **SE shares** a raw pool-token buffer mints / how much token an unwrap delivers — not assumed 1:1 with raw amount. When RP set, map share deltas ↔ effective via `getRate()` |
| **Zap-eligible** | Full book **and** `totalSupply > MINIMUM_LIQUIDITY` (Uni V2 locked-dust residual is not zap-eligible) |
| **Zap-in** | Single-asset **deposit** (`depositSingle`): internal sphere rebalance + multipath proportional add → mint same LP. **v1 required.** **No zap-out** in v1 |
| **Witness token** | The third bound token not in the directed swap pair; still participates in sphere \(L^2\) via its effective reserve (may be 0) |
| **DoD** | Definition of Done — package complete when §11 is satisfied |

**Role naming:** use `token0/1/2`, `standardExchange0/1/2` (or indexed `standardExchange(i)`), `rateProvider(i)`, `effectiveReserve(i)` — **no** brand tickers; **no** DETF-specific type names on the hook ABI (DETF is a consumer).

---

## 1. Goal

Ship a **production-first Uniswap V4 hook package** that:

1. Binds **exactly three** ERC-20 pool tokens and one V4 `PoolManager` + fee oracle per instance.
2. For **each** pool token, accepts an **optional** Standard Exchange into which that token is **buffered** when non-zero — **at most one SE per token**; **non-zero SE addresses pairwise distinct**.
3. For **each** non-zero SE, accepts an **optional** Balancer-style **rate provider** that converts **SE share balances → pool-token units** for effective reserves (when unset: SE **claim** via unwrap preview).
4. Implements the **Orbital sphere invariant** on **effective reserves** \(e_0,e_1,e_2\) (raw face and/or SE-share×rate and/or SE claim), not on free idle pair balances:
   \[
   (R - e_0)^2 + (R - e_1)^2 + (R - e_2)^2 = L^2
   \]
   with \(e_i\) in **1e18** domain; radius \(R\) set once from first liquidity (orbital peer).
5. Exposes **three Uni V4 pair pools** as swap entry points (token pairs 01, 12, 02), **all pointing at the same hook address**, so every pair trade is priced against the **shared 3D effective-reserve state** (witness always participates).
6. **Buffers** pool tokens into the bound SE on liquidity add and on swap token-in when that leg is buffered; **unwraps** SE → pool token on liquidity remove and on swap token-out when that leg is buffered — **buffer-last** and share/claim composition (Single SE BCP process peer).
7. Holds inventory as: **raw ERC-20** for raw legs + **SE shares** for buffered legs. Pool currencies remain the three tokens — **never** SE share addresses.
8. Mints a **single fungible ERC-20 LP** representing pro-rata claim on all inventory components (raw balances + SE share balances).
9. Provides **custom** multipath `addLiquidity` / `removeLiquidity` **and** **`depositSingle` (zap-in only)** on the hook; **forbids** native V4 `modifyLiquidity` / CL; **no zap-out** in v1.
10. Exposes **`IStandardExchangeIn` / `IStandardExchangeOut`** for exact-in/out **tokenᵢ ↔ tokenⱼ** against the **same** sphere book (internal settle; not LP mint/burn).
11. Settles public swaps via **`beforeSwap` + `beforeSwapReturnDelta`** (custom accounting / NoOp curve) — pattern-copy settle; **no** Solidity inheritance of OZ/`BaseHook` / `BaseTokenWrapperHook` / `DeltaResolver`.
12. Deploys as an **immutable hook diamond package** via registry `deployHookVault` + shared hook factory (CREATE2 + `mineNonce`); initializes **all three** pair doors as first-class product UX (postDeploy or package helper).
13. Uses **live Vault Fee Oracle** rates (**orbital dual-channel**): `dexSwapFeeOfVault` = trading residual in book; `usageFeeOfVault` = protocol growth LP mint to `feeTo`.

### 1.1 Canonical user story — all three legs buffered

```text
Binding (example — all three buffered):
  token0 = A,  SE0 = SE_A,  rateProvider0 = RP_A or 0
  token1 = B,  SE1 = SE_B,  rateProvider1 = RP_B or 0
  token2 = C,  SE2 = SE_C,  rateProvider2 = RP_C or 0
  require A ∈ SE_A.vaultTokens(), B ∈ SE_B.vaultTokens(), C ∈ SE_C.vaultTokens()
  require SE_i distinct or same only if product explicitly allows (v1: SEs may equal
    only when the same vault can hold multiple tokens — prefer distinct SEs in DoD)

Uniswap V4 pools (three doors, currencies = A/B/C only — not SE shares):
  Pool A/B, B/C, A/C  with hooks = this instance, fee = DYNAMIC_FEE_FLAG

Inventory after liquidity:
  hook holds SE_A shares + SE_B shares + SE_C shares
  free A/B/C on hook is dust only (refunded after liquidity ops)

Effective reserves for sphere:
  e_i = rateScale_i( claim_i ) where claim_i = preview unwrap SE_i shares → token_i
  (if rateProvider_i == 0: rateScale is identity after decimal→WAD)

--- First liquidity ---
User addLiquidity(a0Max, a1Max, a2Max, …) with ≥2 positive maxes
  → size used amounts on pre-buffer effective book (empty → first-mint path)
  → pull A, B, C
  → buffer-last: exchangeIn each token_i → SE_i
  → set R from max effective used × 10; mint LP; set kLast if fee-on

--- Swap A → C on pool A/C ---
  witness = B (effective claim of SE_B)
  take A → claim-in vs SE_A → sphere exact-in on (e_A, e_C) with witness e_B
  → buffer A into SE_A last
  → unwrap claim-out C from SE_C → pay C
  trading residual stays in input effective reserve path (grows book / L²)

--- Partial buffer configs (also first-class) ---
  SE0 set, SE1=0, SE2=0  → only A buffered; B and C are raw face inventory
  SE0 set, SE1 set, SE2=0 → A and B buffered; C raw
  all SE_i = 0            → pure raw orbital book (degenerate config; allowed)
  Non-zero SE addresses must be pairwise distinct (no shared multi-token SE in v1)

--- Zap-in (single asset, full book only) ---
User depositSingle(tokenIn ∈ {A,B,C}, amountIn, …) when zap-eligible
  → internal sphere rebalance of a slice of tokenIn into the other two legs
  → multipath proportional add of residual + proceeds
  → buffer SE legs last; mint same LP
  → depositor accepts sphere impact + SE costs
  → NO withdrawSingle / zap-out in v1 (use removeLiquidity)

--- SE In/Out (compatibility swap surface) ---
exchangeIn / exchangeOut token_i → token_j against same effective book as V4 doors
  → internal settle (no PoolManager unlock); same sphere + fee + buffer/unwrap law
  → does NOT mint or burn LP

Product thesis:
  Compose yield-bearing / multi-protocol SE positions into a single three-door
  Uniswap V4 orbital market whose mid/depth track SE share rates or claims.
```

### 1.2 Why this exists (product problem)

| Approach | Limitation |
|----------|------------|
| Raw Orbital | Shared 3-asset sphere, but inventory is idle ERC-20 — **no** yield / protocol composition |
| Single SE BCP | SE composition for **one** pair only; **two** currencies; CP not sphere; **one** door |
| Dual SE BCP | Two buffered legs; still **one** V4 pair; CP not multi-asset sphere |
| Balancer multi-asset + SE rate providers | Off Uniswap V4 door topology; different deploy/UX surface |
| **This package** | Orbital **curve + three doors** + **optional per-token SE buffer** + optional rate scale |

v1 is the **composition layer**: orbital multi-door topology with Single-SE-style buffering generalized to **0–3** legs.

### 1.3 Product shape (locked)

| Layer | Role |
|-------|------|
| Uniswap V4 | Three pair pool identities; **swaps** + currency settlement via hook deltas |
| Hook | Binding (tokens + optional SE + optional RP), deposit/withdraw, LP ERC-20, sphere math on **effective** reserves, per-leg buffer/unwrap, `beforeSwap` |
| SE vault(s) | Yield-bearing inventory for each **buffered** leg (at most one SE per token) |
| Rate provider(s) | Optional rate scale on SE claim for sphere inputs (Balancer `getRate` peer) |
| Concentrated liquidity | **Not used** — native `modifyLiquidity` **forbidden** |
| Book shape | Three-leg sphere; **partial book** allowed (orbital peer) |
| LP shape | **One** fungible ERC-20 only |

---

## 2. Product summary

### 2.1 What this package is

| Attribute | Value |
|-----------|--------|
| Primary artifact | CREATE2-mined **hook diamond** (facets + Repo) implementing V4 `IHooks` **plus** 3-asset LP ERC-20 + multi-asset vault discovery surfaces |
| Binding | `(poolManager, feeOracle, token[3], standardExchange[3], rateProvider[3])` — set-once at init; **no** post-deploy rebind |
| Pool currencies | The three bound tokens; factory/postDeploy creates **all three** pair doors |
| Inventory | Per leg: raw ERC-20 **or** SE shares (not both as book for the same leg) |
| Effective reserves | Per leg: raw face **or** rate-scaled SE claim |
| Pricing | Orbital sphere on WAD effective reserves; \(L^2\) stored sphere parameter (recompute after state changes) |
| Swap (trading) fee | **Live** `dexSwapFeeOfVault(this)` WAD; residual stays in book (orbital peer) |
| Protocol growth fee | **Live** `usageFeeOfVault(this)` WAD; Uni V2–style `kLast` + mint LP to `feeTo` (orbital dual-mode product/sum peer) |
| V4 PoolKey.fee | **`DYNAMIC_FEE_FLAG`** |
| LP | Fungible ERC-20 + EIP-2612; decimals always 18; auto name/symbol |
| Deposit / withdraw | Orbital multipath three-leg surface **+ zap-in (`depositSingle`)**; buffer/unwrap on SE legs; **no zap-out** |
| SE In/Out | Required v1: exact-in/out tokenᵢ ↔ tokenⱼ on the sphere book (internal settle) |
| Deploy path | Hook diamond package → registry `deployHookVault` → shared hook factory |

### 2.2 What this package is not

- Not the raw `UniswapV4OrbitalSwapHook` monomorph (no SE legs; no zap-in; no SE In/Out product surface).
- Not Single SE BCP or Dual SE BCP (not CP; not one-pool-only topology).
- Not a wrapper-only buffer hook (`underlying ↔ SE` without AMM book).
- Not Uni V4 concentrated liquidity / Position Manager LP / tick bitmap.
- Not a DETF, bond NFT, or rebasing claim package (consumers may compose later).
- Not “SE shares as pool currencies.”
- Not multi-SE per single token (exactly **0 or 1** SE slot per token).
- Not the same SE address on two legs (v1 **forbids** shared multi-token SE binding).
- Not subclassing orbital / single / dual / weighted contracts (fresh codepath; libs OK).
- Not zap-out / `withdrawSingle` in v1.

### 2.3 Non-goals (v1)

1. Nested multi-orbit “ticks” / concentric spherical caps (Paradigm full product).  
2. \(n > 3\) assets (hypersphere).  
3. **Zap-out** / `withdrawSingle` — use multipath `removeLiquidity` only.  
4. Native ETH as a pool currency (wrap to WETH off-hook).  
5. Fee-on-transfer / rebasing **pool tokens** (unsupported).  
6. Binary-search solvers as **primary** product law — exact-in/out and zap-in split must be **closed form** (or one-shot closed-form multi-leg) on the sphere; SE invert via fee-inclusive previews / closed-form dilution only.  
7. Auto-deploying SE vaults or rate providers inside the package.  
8. Owner / pause / admin surface on the **hook instance** after deploy (immutable diamond; fee rates via oracle only).  
9. Growing \(R\) after first mint; resetting \(R\) after full liquid exit.  
10. Treating V4 `sqrtPriceX96` as product mid after init.  
11. Shared TestBases with DETF packages (DETF may consume later; not v1 DoD).  
12. Using `dexSwapFeeOfVault` as protocol growth rate (growth uses **`usageFeeOfVault`** — orbital fee split).  
13. Rate provider on **raw** legs (rate provider only valid when SE is set).  
14. Multiple concurrent SEs for the same token **or** the same SE address on multiple legs.  
15. Package-owned global token↔SE registry (binding is **instance-local**).  
16. Mapping `exchangeIn` → mint LP or `exchangeOut` → burn LP (wrong surface — SE In/Out is swap-only).

---

## 3. Locked product decisions

### 3.1 Identity & binding

| # | Decision | Value |
|---|----------|--------|
| D1 | Product name | **`UniswapV4StandardExchangeOrbitalBufferHook`** |
| D2 | Package location | `contracts/hooks/uniswap/v4/standardExchange/orbital/` |
| D3 | Peers | Orbital = sphere/topology/LP/fee/partial-book **behavioral** reference. Single SE BCP = buffer/unwrap/claim/buffer-last **process** reference. Weighted = rate-provider **law** reference. **No** required inheritance from any |
| D4 | Asset count (v1) | **Exactly three** pool tokens per instance |
| D5 | SE slots | **Exactly one optional SE per token** — `standardExchange[i]` is `address(0)` **or** one `IStandardExchange`. **Not** a list of SEs per token |
| D5a | Distinct SEs | **When non-zero, SE addresses must be pairwise distinct** — no binding the same vault on two legs in v1 (even if multi-token SE) |
| D6 | Rate provider slots | **Optional per SE leg only** — `rateProvider[i]` non-zero **only if** `standardExchange[i] != 0`; else must be `address(0)` |
| D6a | Rate provider semantics | **Balancer SE RP peer:** when RP set, effective reserve from **SE share balance × `getRate()` / 1e18** (rate = pool-token units per share @ 1e18). RP is **primary** conversion of shares — **not** a second multiplier on top of SE claim. When RP unset on a buffered leg: effective = **SE claim** via fee-inclusive unwrap preview. Fail-closed on non-zero RP |
| D7 | Binding | Set-once at diamond init: `poolManager`, `feeOracle` (`IVaultFeeOracleQuery`), `token0..2`, `standardExchange0..2`, `rateProvider0..2`. Permit2 = well-known constant (not binding arg). **\(R\) not a deploy arg** (set on first liquidity) |
| D8 | Token validation | Non-zero; **pairwise distinct**; standard ERC-20 + USDT-style SafeERC20. Fee-on-transfer / rebasing **unsupported** |
| D9 | SE validation (when non-zero) | `token_i ∈ SE_i.vaultTokens()`; `token_i != address(SE_i)`; SE exposes closed-form **token ↔ SE** buffer and unwrap routes with preview == execution; **D5a** distinctness |
| D10 | Empty SE at deploy | **Allowed** (inert SE until first buffer) |
| D11 | Zero-SE config | **Allowed** — all three legs raw ⇒ pure orbital-style inventory (still this package’s codepath, not a call into monomorph orbital) |
| D12 | Binding token order | Caller-supplied order is **canonical binding order** for LP / views / SE indices; pool keys still sort by address for V4 |
| D13 | Pool set | Package/postDeploy path **always creates all three** pair pools (01, 12, 02). External actors may still initialize **additional** PoolKeys (e.g. other `tickSpacing`) with `hooks = this` + `DYNAMIC_FEE_FLAG` |
| D14 | Pool fee (V4 key) | **`LPFeeLibrary.DYNAMIC_FEE_FLAG` only**. SoT for trading rate = oracle |
| D15 | Native CL | **Forbidden** — `beforeAddLiquidity` / `beforeRemoveLiquidity` **revert** |
| D16 | Package shape | **Hook diamond package** (`IUniswapV4HookDiamondPackage` + vault surfaces). Facets via CREATE3; instance via CREATE2 mine + hook factory. **Immutable** after postDeploy (no live `diamondCut`) |
| D17 | Hook inheritance | **No** inheritance of Crane/OZ `BaseHook`, `BaseTokenWrapperHook`, `DeltaResolver` — full **pattern-copy** settle. May use Crane facet bases for diamond plumbing |
| D18 | Shared facets | Cut **ERC20PermitDFPkg** facets (`ERC20Facet` + `ERC5267Facet` + `ERC2612Facet`) + MultiAsset Basic/Standard vault facets for LP + discovery. Product facets = hooks + book + deposit/withdraw + SE buffer routes only |
| D19 | Full type/file names | Full product names on contracts/files; short labels OK in prose. LP symbol prefix may be short (D44) |

### 3.2 AMM, reserves, SE composition

| # | Decision | Value |
|---|----------|--------|
| D20 | AMM model | **Orbital sphere** single orbit on **effective reserves**: \((R-e_0)^2+(R-e_1)^2+(R-e_2)^2=L^2\) |
| D21 | Radius \(R\) | **Set once on first successful `addLiquidity`**. \(R = \max(e_i^{\mathrm{used,18}}) \times\) **`R_SAFETY_MULTIPLIER = 10`**. Later ops with any 1e18 effective reserve **≥ \(R\)** **revert**. Pre-first-mint: \(R = 0\); swaps revert |
| D22 | Sphere parameter \(L^2\) | Repo **stored**; **recompute** after every successful LP/swap from current WAD effective reserves. Not a fee-conserved invariant |
| D23 | Decimal / WAD law | Orbital peer: any `uint8` decimals; **all sphere/fee/LP algebra in 1e18**; `toWad` floor; `fromWadFloor` / `fromWadCeil` per pay/receive; preview bit-exact on shared path |
| D24 | Raw leg reserve | \(e_i^{\mathrm{native}} =\) intentional raw inventory of `token_i` (Repo SoT; ignore stray donations for pricing — orbital peer) |
| D25 | Buffered leg without RP | \(e_i = c_i = \mathrm{previewExchangeIn}(SE_i,\ seBal_i,\ token_i)\) fee-inclusive unwrap SoT. **Not** free `token_i.balanceOf(hook)` |
| D26 | Buffered leg with RP | **Native then toWad (Q2):** \(e_i^{\mathrm{native}} = seBal_i \cdot \mathrm{getRate}() / 10^{18}\), then \(e_i^{\mathrm{wad}} = \mathrm{toWad}(e_i^{\mathrm{native}},\ \mathrm{decimals}_i)\). `getRate()` via `staticcall`; **fail-closed**. **Do not** also multiply by SE claim — RP **is** the share→token conversion (Balancer SE RP peer) |
| D27 | Effective reserve | Raw face **or** (shares×rate) **or** SE claim (no RP). Sphere + LP NAV + `kLast` use **effective** only |
| D28 | Yield in price | Re-read SE balances + claim and/or rate each quote; SE profit / rate moves mid without a swap |
| D29 | Witness token | Third bound token always in formulas via **effective** reserve (may be **0**) |
| D30 | Full trade-leg drain | **Forbidden** — pre- and post-swap both trade-leg **effective** (and underlying inventory) reserves **> 0** (orbital Q27 peer adapted to SE inventory) |
| D31 | Share / claim composition | For buffered **tokenIn**: map raw amountIn → SE shares (buffer preview) → **effective inflow** via rate (if RP) or claim delta (if no RP). Never feed raw amountIn into sphere as if 1:1 under SE fees. Buffered **tokenOut**: invert effective → shares → native token. Raw legs: face amounts. Same composition for V4 swaps, zap internal swaps, and SE In/Out |
| D31a | SE exact-out / invert unsupported | If a bound SE **does not support** the required exact-out (or invert) route for buffer/unwrap composition on a path, the **entire transaction reverts**. No partial fill, no soft-fail, no alternate approximate solver. Prefer exact-in SE legs when the SE surface only guarantees exact-in; when product path **requires** exact-out invert and SE cannot, **revert** |
| D32 | Buffer-last | Normative multipath / zap process: quote/size on pre-buffer book → inventory moves → **buffer all SE legs last** → mint / `kLast` on post-buffer effective reserves. Do **not** re-quote sphere mid-flight after buffer |
| D33 | SE I/O | Bound SE: `exchangeIn` / `exchangeOut` only; tight minOut/maxIn = fee-inclusive SE preview; SE deadline `block.timestamp` if required. Under-delivery or missing route → **full tx revert** (D31a) |
| D34 | SE usage fees | **Orthogonal** to product design. Inside SE previews/execution only. Product fees = trading residual + growth mint |
| D35 | Free pair dust | **`MAX_DUST_WEI = 10`** (Q4). After liquidity ops, free balances of **buffered** pool tokens **> 10 wei** **refund to `msg.sender`**. Raw-leg intentional inventory is **not** refunded |
| D36 | Donations | Donated SE shares or raw inventory **count** into book (dilute LPs) for held assets that are inventory components. Stray unrelated ERC-20s **ignored** |
| D37 | Quote matrix | Exact-in + exact-out both directions on every directed pair door **and** on SE In/Out; closed form on sphere + SE invert peers |

### 3.3 LP & liquidity surfaces

| # | Decision | Value |
|---|----------|--------|
| D38 | LP token | Single fungible **ERC-20 on the hook** (proxy is LP); decimals **18**; free transfer; EIP-2612 via shared facets |
| D39 | LP ownership | Pro-rata of **all inventory components** (raw balances + SE share balances) |
| D40 | MINIMUM_LIQUIDITY | **1000** LP wei to `address(0)` on first mint; **never burned** |
| D41 | Multipath deposit | **`addLiquidity(a0Max, a1Max, a2Max, to, sharesMin, deadline, permit2Data) returns (shares, a0, a1, a2)`** — three-leg / partial multipath surface |
| D41a | Zap-in | **`depositSingle` required v1** when **zap-eligible** (full book **and** `totalSupply > MINIMUM_LIQUIDITY`). **Any** of the three pool tokens. Internal sphere rebalance + multipath proportional add → **same** LP. Empty / partial / dust-only book → **revert**. Depositor accepts impact + SE costs |
| D41b | Zap-out | **Out of v1** — no `withdrawSingle`. Users use `removeLiquidity` only |
| D41c | Zap-in accounting | Normative **high-level algorithm §4.5.3** (Q9). Summary: (1) protocol mint if fee-on from pre-zap \(k\); (2) closed-form solve sale slices \(s_j,s_k\) of `tokenIn` toward the other two legs so residual + proceeds are proportional to current effective reserves; (3) two internal sphere exact-in swaps (emit `ZapSwap` each); (4) multipath prop add; (5) **buffer SE legs last**; (6) mint LP; (7) update `kLast`. Math lib must expose pure closed-form split; **no** unbounded binary search. `previewDepositSingle` / `previewZapSplit` bit-exact |
| D42 | First mint | **≥2** positive legs via **multipath only** (not zap); sum of **WAD effective used** > MINIMUM_LIQUIDITY; set \(R\); dead MIN to `address(0)`; buffer SE legs last; no protocol mint while `kLast == 0` |
| D43 | Subsequent full book | Three-leg Uni V2 min-ratio on **WAD effective reserves**; all three legs participate; buffer SE legs last |
| D44 | Partial book | Orbital peer: prop min over maxed positive effective legs; seed zero legs with full max; **sphere-NAV** share mint; seed-only OK when partial. **Zap-in forbidden** while partial (not full book) |
| D45 | Withdraw | **`removeLiquidity(shares, to, a0Min, a1Min, a2Min, deadline)`** — burn `msg.sender` LP only; pro-rata inventory; unwrap buffered legs to pool tokens; pay binding-order amounts to `to` |
| D46 | LP name/symbol | Auto e.g. `SEORB-{s0}-{s1}-{s2}` (Standard Exchange Orbital Buffer); address-fragment fallback |
| D47 | Funding | SafeERC20 `transferFrom` **and** Permit2 (signature + allowance) on **addLiquidity and depositSingle** paths. Empty `permit2Data` ⇒ transferFrom only; non-empty ⇒ Permit2 for every pulled leg — **no mixed** path. Refunds of unused deposit tokens to **`msg.sender`** |
| D48 | Reentrancy | One global non-reentrant lock on add/remove/**depositSingle**/SE In/Out **and** `beforeSwap` body (after PM sender check) |
| D49 | Preview fidelity | **Bit-exact** `preview* == execution` at same oracle fee reads, same SE previews, same rate reads, same ceil/floor path (incl. zap + SE In/Out) |
| D49a | SE In/Out surface | **Required v1:** implement `IStandardExchangeIn` + `IStandardExchangeOut` for exact-in/out **tokenᵢ ↔ tokenⱼ** (`i ≠ j`, both bound) against the **same** effective sphere book as public V4 swaps (D50 trading fee + D31 composition). **Internal settle** (no PoolManager unlock). **Not** LP mint/burn. Previews required and bit-exact. SE missing exact-out invert → **full tx revert** (D31a) |
| D49b | SE In/Out token domain | Only the three bound pool tokens. Revert if token is SE share address, unbound, or same token in/out |
| D49c | SE In/Out funding | **Permit2 only (Q11)** for pulling `tokenIn` on SE In/Out paths (SignatureTransfer and/or AllowanceTransfer as plan packs). **No** classic `transferFrom` on SE In/Out in v1. LP deposit paths still support transferFrom **and** Permit2 (D47). Payout of `tokenOut` is ordinary transfer to recipient |

### 3.4 Fees, protocol growth, ops

| # | Decision | Value |
|---|----------|--------|
| D50 | Trading (swap) fee | **Live** `feeOracle.dexSwapFeeOfVault(address(this))` WAD; 0 allowed; require `< 1e18`. Input residual; **not** PoolKey static fee. Residual stays in book |
| D51 | Trading fee → V4 units | Floor map WAD → pips + `OVERRIDE_FEE_FLAG` on `beforeSwap` (informational / router UX). Economic SoT = hook residual — **no double-haircut** |
| D52 | Protocol growth fee | **Yes** — Uni V2–style. Live `usageFeeOfVault(this)`; mint LP to `feeTo` on add/remove when fee-on. **Not** on every swap |
| D53 | fee-on predicate | `feeTo != 0 && usageFeeWad != 0 && usageFeeWad < 1e18 && ownerFeeShare != 0` with `ownerFeeShare = usageFeeWad * 100_000 / 1e18` (floor) |
| D54 | `kLast` measure (3-asset) | **Full book** (all three **effective** reserves > 0): \(k = e_0^{18}\cdot e_1^{18}\cdot e_2^{18}\); root = **cbrt**. **Partial book**: sum-based interim \(k = e_0^{18}+e_1^{18}+e_2^{18}\); root = \(k\). Store `kLast` + `kLastMode`. Cross-mode: no mint from incompatible `kLast` |
| D55 | Growth timing | Orbital peer: protocol mint from **pre-intake** \(k\) on add; mint before user burn on remove; set `kLast` post-op when fee-on. Swaps do not mint protocol LP or update `kLast` |
| D56 | Previews + growth | LP previews **simulate** protocol mint dilution when fee-on |

### 3.5 Deploy, permissions, tests

| # | Decision | Value |
|---|----------|--------|
| D57 | Deploy path | **Required:** `IUniswapV4HookDiamondPackage` + Vault Registry `deployHookVault` + shared `UniswapV4HookDiamondPackageCallBackFactory`. Facets CREATE3 via FactoryService. **Never** `new` SUT; **never** vault factory salt for V4 flag addresses |
| D58 | Salt law | Factory PRD: `packageSalt` from stable `PRODUCT_ID` + binding fields (**tokens, SEs, RPs, feeOracle, poolManager** — **no** package/facet addresses); `finalSalt = keccak256(abi.encode(packageSalt, mineNonce))` |
| D59 | Mine flags | At least `BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_REMOVE_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA` (plan locks exact mask vs `Hooks.ALL_HOOK_MASK`) |
| D60 | Pool init UX | **postDeploy on package (Q5):** on successful instance deploy, package **`postDeploy` initializes all three** pair doors with shared `tickSpacing` + `sqrtPriceX96` plumbing (defaults: spacing 60, 1:1 mid; args from `PkgArgs` or product defaults). Currencies address-sorted per pair; `hooks = this`; `fee = DYNAMIC_FEE_FLAG`. Atomic with deploy from integrator POV |
| D61 | One product pool-set | Multiple tickSpacings for the same pair on this hook **allowed** (share reserves). `beforeInitialize` validates pair ⊂ bound tokens + dynamic fee |
| D62 | Deposit vs pool init | LP add/remove/previews **do not require** V4 initialize. **Swaps** require \(R > 0\), initialized directed pair pool, both trade-leg effective reserves > 0 |
| D63 | Access | Liquidity + views permissionless; hook callbacks `msg.sender == poolManager` only |
| D64 | Vault/SE compatibility surface | **Required v1:** `IBasicVault` + `IStandardVault` multi-asset discovery: `vaultTokens()` = binding tokens; `reserveOfToken(token_i)` = **effective** reserve (shares×rate, claim, or raw face), never free dust of buffered tokens. **Plus** SE In/Out per **D49a** |
| D65 | Test SE | Hermetic DoD uses production **ERC-4626 Wrapper SE** (and/or production SE ports) with mintable pool tokens. Matrix must cover: (a) **0 SE** raw-only, (b) **1 SE**, (c) **2 SE**, (d) **3 SE** all buffered; plus rateProvider zero/non-zero rows for at least one buffered config; zap-in on full book; SE In/Out both directions for each pair. **No** mock hook / mock SE SUT |
| D66 | Fork DoD | **Base** + **Robinhood (4663)** required; Ethereum optional stretch. Production PM/Permit2/fee oracle when present; deploy-if-missing production-equivalent. May deploy mintable tokens + wrapper SEs on fork |
| D67 | DETF coupling | Fully independent product/test surface from DETF packages |
| D68 | Impl plan follow-on | `UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` |

### 3.6 Implementation edges (locked)

| ID | Topic | Value |
|----|--------|-------|
| O1 | Effective reserve view | Required public `effectiveReserve(uint8 i)` / `effectiveReserves()` in binding order; also per-token `reserveOfToken` |
| O2 | SE / RP views | `standardExchange(uint8 i)`, `rateProvider(uint8 i)`, `isBuffered(uint8 i)`, `seClaim(uint8 i)` (unwrap claim), `seBalance(uint8 i)`, `effectiveFromShares` helpers as needed |
| O3 | First vs subsequent mint | First: multipath only, sum-WAD effective − MIN; subsequent full book: three-leg min-ratio on effective WAD; partial: sphere-NAV |
| O4 | Zap-in only | `depositSingle` required; **no** `withdrawSingle` |
| O5 | Internal settle | Buffer/unwrap helpers shared; V4 swaps settle via PM deltas; zap + SE In/Out **do not** unlock PM; LP paths do not unlock PM for SE I/O beyond token pulls |
| O6 | Rate fail-closed | Non-zero RP: failed `getRate` or non-positive rate **reverts** quote/execution paths that need that leg |
| O7 | Multi-SE buffer order | When multiple legs buffer in one op, buffer in **binding index order** after all used amounts finalized (deterministic) |
| O8 | Swap inventory order | Take tokenIn → (optional unwrap tokenOut prep) → sphere settle amounts → buffer tokenIn if SE → unwrap/pay tokenOut if SE; never leave free buffered-token inventory as book |
| O9 | LP ERC-20 location | Same mined hook proxy |
| O10 | Math library | Pure Math: sphere exact-in/out, WAD, sphere-NAV, cbrt/sum growth, zap multi-leg split, shares×rate helpers — **no** SE external calls inside pure Math |
| O11 | Inventory re-read | Re-read SE balances + claims + rates when next step needs post-inventory state. **Do not** re-solve sphere mid-flight after buffer (buffer-last) |
| O12 | Adversarial DoD | Reentrancy (LP↔swap↔SE In/Out), donation dilution, `feeTo` non-receivable (protocol mint reverts whole op), SE revert mid-buffer/zap (full tx reverts), RP fail-closed, partial-book drain attempts, distinct-SE binding rejects |

---

## 4. Architecture

### 4.1 Stack

```text
┌──────────────────────────────────────────────────────────────────┐
│ Integrator / anyone (permissionless liquidity + swaps)           │
│   • registry/pkg deployHookVault(args, mineNonce)                │
│   • addLiquidity / removeLiquidity on Hook                       │
│   • swapExact* via V4 on any of the three pair pools             │
└───────────────┬─────────────────────────────┬────────────────────┘
                │                             │
                ▼                             ▼
┌───────────────────────────┐   ┌──────────────────────────────────┐
│ Hook Diamond Factory      │   │ Uniswap V4 PoolManager           │
│  CREATE2 proxy + flags    │──►│  init Pool 01 + 12 + 02          │
│  registry.deployHookVault │   │  fee = DYNAMIC_FEE_FLAG          │
└───────────────┬───────────┘   │  hooks = this diamond            │
                │               └──────────────────────────────────┘
                ▼
┌──────────────────────────────────────────────────────────────────┐
│ UniswapV4StandardExchangeOrbitalBufferHook (diamond)             │
│  tokens[3] + SE[3]? + RP[3]?                                     │
│  effective e0,e1,e2 + L² + R + kLast                             │
│  inventory: raw and/or SE shares                                 │
│  LP ERC-20 + feeOracle                                           │
└───────────┬───────────────────────────────┬──────────────────────┘
            │ buffer / unwrap               │ optional getRate
            ▼                               ▼
┌───────────────────────┐         ┌───────────────────────┐
│ IStandardExchange ×0–3│         │ IRateProvider ×0–3    │
└───────────────────────┘         └───────────────────────┘
```

### 4.2 Virtual multi-pool (“three doors, one room”)

Uniswap V4 pools are **strictly 2-currency**. Orbital multi-asset state lives **only** on the hook:

```text
Pool token0/token1  ──┐
Pool token1/token2  ──┼──► same hook (shared effective reserves + L² + inventory)
Pool token0/token2  ──┘
```

Pool currencies are always the **three ERC-20 tokens**. SE shares never appear in `PoolKey` currencies.

A token0→token2 swap still uses **token1 effective reserve as witness** in \(L^2\).

### 4.3 Effective reserves (normative)

```text
for i in 0..2:
  if standardExchange[i] == address(0):
      // RAW LEG
      e_i_native = Repo.rawReserve[token_i]          // intentional raw inventory
  else:
      seBal_i = IERC20(SE_i).balanceOf(hook)         // intentional SE inventory
      if rateProvider[i] != address(0):
          // BUFFERED + RP (Q2): native shares×rate FIRST, then toWad
          rate = IRateProvider(rateProvider[i]).getRate()  // 1e18 token per share; fail-closed
          e_i_native = seBal_i * rate / 1e18
      else:
          // BUFFERED, no RP: SE claim via fee-inclusive unwrap preview
          e_i_native = SE_i.previewExchangeIn(SE_i, seBal_i, token_i)

  e_i_wad = toWad(e_i_native, decimals(token_i))  // always after native effective amount

// Sphere / kLast / NAV use e_i_wad only
// Free token_i on hook when buffered is NOT e_i (dust/refund only)
```

**Live swap legs:** both trade-leg `e_in_wad > 0` and `e_out_wad > 0` before and after.  
**Full book / zap-eligible base:** all three `e_i_wad > 0` (zap also requires `totalSupply > MINIMUM_LIQUIDITY`).

### 4.4 Sphere pricing (normative math)

Behavioral peer: orbital §4.3 with \(x,y,z := e_0,e_1,e_2\) in WAD.

**Exact-in** (buffered input maps to effective inflow before sphere):

```text
// 1) Map native amountIn → effective inflow
if legIn buffered:
    sharesIn = preview_buffer_token_to_shares(SE_in, amountInNative)  // fee-aware
    if RP_in:
        dIn_native = sharesIn * getRate() / 1e18
    else:
        dIn_native = preview claim delta for those shares / buffer claim-in peer
else:
    dIn_native = amountInNative

dIn_wad = toWad(dIn_native)
dIn_net = dIn_wad - floor(dIn_wad * feeWad / 1e18)
// 2) Sphere solve Δe_out_wad on (e_in, e_out, e_wit, R, L²)
// 3) Map effective out → native out
if legOut buffered:
    if RP_out:
        sharesOut = invert (Δe_out_native = fromWadFloor(Δe_out_wad)) via rate
        amountOutNative = unwrap sharesOut → token (floor; fee-inclusive SE)
    else:
        amountOutNative = fromWadFloor( claim-out path for Δe_out )
else:
    amountOutNative = fromWadFloor(Δe_out_wad)

// 4) Settle: take in → buffer-last if needed → unwrap/pay out
// 5) Recompute L² from post-state effective reserves
```

**Exact-out** dual invert (ceil native in; floor constraints on residual inventory).  
Same composition for **V4 doors**, **SE In/Out**, and **zap internal** swaps.

**SE invert failure (D31a — normative):** If composition requires an SE **exact-out** / buffer-invert / unwrap-invert and the bound SE **does not support** that route (missing function, preview reverts, or non-closed-form), the **whole transaction reverts**. Do not approximate; do not partial-settle.

Domain constraints (must revert if violated): \(R > 0\); \(0 \le e_i < R\); \(T\) under sqrt non-negative; no full drain of trade legs; interior branch only; SE invert supported when required (D31a).

### 4.5 Liquidity flows (summary)

#### 4.5.1 Proportional / multipath add

```text
Protocol growth mint first if fee-on (pre-intake k vs kLast)
Determine used amounts from maxes (first / full / partial laws on EFFECTIVE book)
Pull native tokens (transferFrom or Permit2)
// buffer-last:
for i in binding order where SE_i != 0 and used_i > 0:
    exchangeIn(token_i → SE_i, used_i) with tight SE preview minOut
for i where SE_i == 0 and used_i > 0:
    credit raw Repo inventory (already held)
Re-read effective reserves; mint user LP; set kLast if fee-on
Refund free buffered-token dust to msg.sender
```

#### 4.5.2 Remove

```text
Protocol growth mint first if fee-on
Compute pro-rata raw and/or SE share amounts on pre-burn supply
Burn msg.sender LP
Pay raw legs; unwrap SE share slices → pool tokens; pay to `to`
Set kLast; refund dust
// No zap-out path in v1
```

#### 4.5.3 Zap-in (`depositSingle`) — high-level algorithm (normative, Q9)

**Eligibility:** full book (all effective \(e_i > 0\)) **and** `totalSupply > MINIMUM_LIQUIDITY`.  
**tokenIn** ∈ `{token0, token1, token2}`. Label legs: **in** = `i`, **others** = `j`, `k` (the two non-input indices).

**Goal:** spend a single `amountIn` of token `i` such that, after two internal directed sphere swaps and a residual hold of `i`, the three native amounts \((a_i, a_j, a_k)\) used in the multipath add are **proportional** to current **pre-zap** effective reserves \((e_i, e_j, e_k)\) in WAD:

\[
\frac{\mathrm{toWad}(a_i)}{e_i^{\mathrm{wad}}}
=
\frac{\mathrm{toWad}(a_j)}{e_j^{\mathrm{wad}}}
=
\frac{\mathrm{toWad}(a_k)}{e_k^{\mathrm{wad}}}
= \lambda
\quad (\lambda > 0)
\]

**Structure (locked):**

```text
1) Protocol growth mint if fee-on (pre-zap k vs kLast); work on post-protocol totalSupply
2) Snapshot pre-buffer effective reserves e_i, e_j, e_k (and R, L²) — ALL quotes use this book
3) Pull amountIn of token i (transferFrom or Permit2 — D47)
4) CLOSED-FORM solve (pure Math; no unbounded binary search):
     find sale natives s_j, s_k ≥ 0 with s_j + s_k ≤ amountIn such that:
       a_i = amountIn - s_j - s_k                    // residual of token i
       a_j = sphereExactIn(i → j, s_j) on snapshot   // effective→native out of j
       a_k = sphereExactIn(i → k, s_k) on snapshot   // note: second swap must use
                                                     // post-first-swap book OR a
                                                     // simultaneous closed-form that
                                                     // is bit-identical to sequential
                                                     // execution order (plan locks
                                                     // sequential: j then k in index order)
       and (a_i, a_j, a_k) satisfy prop ratios above in WAD
     Depositor accepts trading residual on both internal swaps + SE composition costs
5) Execute internal swaps in fixed order: lower other-index first, then higher
     (deterministic). Each emits ZapSwap. No PoolManager unlock.
     SE exact-out invert on an internal path that needs it → full tx revert (D31a)
6) Multipath proportional add of (a0,a1,a2) in binding order (used amounts from step 4/5)
7) Buffer-last: buffer any SE legs for used amounts (binding order)
8) Mint user LP; set kLast from post-buffer effective product/mode; refund free buffered dust > 10 wei
```

**Closed-form requirement:** Math must admit a **one-shot** solution for \((s_j, s_k)\) (or an equivalent parameterization, e.g. solve \(\lambda\) then back out sales) under the sphere exact-in map + prop constraint. Plan derives the algebra and proves invertibility in the interior domain; if a path has no solution or would drain a leg / exceed \(R\), **revert**.

**Previews:** `previewZapSplit` returns `(s_j, s_k, a_i, a_j, a_k, shares)`; `previewDepositSingle` returns `shares`; both **bit-exact** vs execution at same oracle/SE/RP reads.

**First mint / partial book:** zap **reverts** — use multipath `addLiquidity` only.  
**Zap-out:** **not in v1**.

#### 4.5.4 SE In/Out (required)

```text
exchangeIn(tokenIn, tokenOut, amountIn, minOut, …) / exchangeOut(…)
  → same sphere quote as V4 directed pair (tokenIn, tokenOut)
  → same trading fee residual (dexSwapFee WAD)
  → same buffer/unwrap + RP composition (D31)
  → internal settle only
  → pull tokenIn via **Permit2 only** (D49c) — no transferFrom on this surface
  → pay tokenOut to recipient
  → NEVER mint/burn hook LP
  → SE missing exact-out invert when required → full tx revert (D31a)
previewExchangeIn / previewExchangeOut bit-exact with execution
```

### 4.6 Fee law (v1) — two oracle channels

| Channel | Oracle API | When | Destination |
|---------|------------|------|-------------|
| Trading residual | `dexSwapFeeOfVault(this)` | Every swap + swap preview | Stays in book (effective reserves / inventory) |
| Protocol growth | `usageFeeOfVault(this)` + `feeTo()` | add/remove + LP previews | Mint hook LP to `feeTo` |

V4 PoolKey uses `DYNAMIC_FEE_FLAG`; hook returns override pips for UX only.

---

## 5. Package layout (normative target)

```text
contracts/hooks/uniswap/v4/standardExchange/orbital/
  UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md              # this file
  UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on

  interfaces/
    IUniswapV4StandardExchangeOrbitalBufferHook.sol                    # PkgInit/PkgArgs + surface
    IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol             # optional split

  UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol
  UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol
  UniswapV4StandardExchangeOrbitalBufferHookRepo.sol
  UniswapV4StandardExchangeOrbitalBufferHookMath.sol
  UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol               # SE claim + rate helpers
  UniswapV4StandardExchangeOrbitalBufferHookPullLib.sol                # optional
  UniswapV4StandardExchangeOrbitalBufferHookTarget.sol                 # or split Targets
  facets/
    UniswapV4StandardExchangeOrbitalBufferHook*Facet.sol

  TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol
```

**Naming:** full product type/file names only (skill law). Prose shorthand: **“SE Orbital Buffer Hook”**.

---

## 6. Public surface (required sketch)

### 6.1 Binding & reserves

```text
poolManager()
feeOracle()
token0() / token1() / token2()          // or token(uint8 i)
standardExchange(uint8 i)               // address(0) if raw
rateProvider(uint8 i)                   // address(0) if none
isBuffered(uint8 i)
currencyPair01() / 12() / 02()          // optional PoolKey views
permit2()

rawReserve(uint8 i)                     // face raw inventory (0 if buffered-only book)
seBalance(uint8 i)
seClaim(uint8 i)                        // claim before rate
effectiveReserve(uint8 i)               // normative book amount (native units pre-WAD or document unit)
effectiveReserves()                     // (e0,e1,e2)
radius() / lSquared()
```

### 6.2 LP

```text
addLiquidity(a0Max,a1Max,a2Max,to,sharesMin,deadline,permit2Data)
  → (shares, a0, a1, a2)
depositSingle(tokenIn, amountIn, to, sharesMin, deadline, permit2Data)
  → shares   // zap-in only; zap-eligible required
previewAddLiquidity(...)
previewDepositSingle(...)
previewZapSplit(...)            // sale slices + residual + expected other-leg proceeds
removeLiquidity(shares,to,a0Min,a1Min,a2Min,deadline)
  → (a0, a1, a2)
previewRemoveLiquidity(...)
// NO withdrawSingle in v1
// IERC20 + EIP-2612 via shared facets
```

### 6.3 Swap previews & fees

```text
previewSwapExactIn(tokenIn, tokenOut, amountIn) → amountOut
previewSwapExactOut(tokenIn, tokenOut, amountOut) → amountIn
dexSwapFee() / usageFee() / feeTo() / kLast() / kLastMode()
```

### 6.4 SE In/Out (required)

```text
// IStandardExchangeIn / IStandardExchangeOut peer surface (names per plan)
exchangeIn / exchangeOut  (token_i ↔ token_j, i ≠ j)
previewExchangeIn / previewExchangeOut
// Funding: Permit2 only for tokenIn (D49c)
// Internal settle; same book as V4; not LP
// SE exact-out unsupported → whole tx reverts (D31a)
```

### 6.5 Vault discovery

```text
vaultTokens() → [token0, token1, token2]
reserveOfToken(token) → effective reserve for bound token
reserves()
vaultConfig / vaultTypes / contentsId / vaultFeeTypeIds  // MultiAsset Standard vault peer
// vaultTypes includes SE In, SE Out, BasicVault, StandardVault, product interface ids
```

---

## 7. Deploy architecture (normative)

| Requirement | Law |
|-------------|-----|
| Instance address | CREATE2-mined proxy; flags match `requiredHookFlags()` |
| Factory | Shared `UniswapV4HookDiamondPackageCallBackFactory` only |
| Registry | `deployPkg` for package; `deployHookVault` for instances |
| Salt | Stable product binding fields only — **include** all three tokens, SE addresses, RP addresses, feeOracle, poolManager, PRODUCT_ID |
| Immutability | No diamondCut facet on product config; no rebind |
| Pool doors | **`postDeploy` initializes all three** pair pools (D60 / Q5) |
| Facets | CREATE3 via FactoryService; cut shared ERC20+vault facets |

Monomorph CREATE3 product factory (legacy orbital style) is **out of scope** for this package.

---

## 8. Testing expectations (DoD sketch)

Production-first (AGENTS + `indexedex-testing` + hook package skill):

1. **Hermetic:** real hook package + registry + hook factory + PM port + Permit2 + fee oracle + ERC-4626 wrapper SE(s) + mintable tokens.  
2. **Config matrix:** 0/1/2/3 buffered legs; RP on/off for ≥1 buffered config.  
3. **Liveness:** inert \(R=0\) swaps revert; first add (≥2 legs) sets \(R\); all three doors swap after init.  
4. **Buffer process:** pair-in buffers SE; pair-out unwraps; free buffered dust refunded; claim-in ≠ raw under SE dilution.  
5. **Sphere:** exact-in/out closed form; witness participation; no full drain; reserves &lt; \(R\).  
6. **Partial book:** seed + sphere-NAV; full book three-leg only.  
7. **Fees:** trading residual; growth mint on add/remove; previews bit-exact at same oracle/SE/RP reads.  
8. **Permit2 + transferFrom** deposit paths.  
9. **Reentrancy / donation / SE revert / RP fail-closed** adversarial cases.  
10. **Forks:** Base + Robinhood (4663) smoke with production stack deploy-if-missing.  
11. **No** mock SUT hook/SE/manager/registry/factory.

---

## 9. Clarification lock table (resolved)

| ID | Topic | Locked value |
|----|--------|--------------|
| Q1 | Same SE on multiple legs | **Forbid** — D5a |
| Q2 | Rate → WAD | **Native `seBal * rate / 1e18` then `toWad`** — D26 |
| Q3 | SE In/Out | **Required v1** — D49a |
| Q4 | Dust | **`MAX_DUST_WEI = 10`** — D35 |
| Q5 | Pool init host | **`postDeploy` initializes all three doors** — D60 |
| Q6 | Growth fee channel | **Orbital dual-channel** — `usageFee` growth; `dexSwapFee` trading |
| Q7 | 0-SE config in DoD | **Yes** — D65 |
| Q8 | Rate provider on raw legs | **Forbidden** — D6 |
| Q9 | Zap-in algorithm | **High-level algorithm locked in §4.5.3**; plan derives closed-form algebra; sequential internal swaps j then k by index order |
| Q10 | Zap-out | **Out of v1** — D41b |
| Q11 | SE In/Out funding | **Permit2 only** (no transferFrom on SE In/Out) — D49c |
| Q12 | SE exact-out unsupported | **Full transaction reverts** — D31a |

**Plan-only remaining work (not product forks):** expand §4.5.3 into explicit Math identities / proofs; wire Permit2 packing bytes for SE In/Out; name custom errors.

---

## 10. Future (non-goals now)

1. Zap-out / `withdrawSingle`.  
2. \(n > 3\) hypersphere.  
3. Nested multi-orbit concentration.  
4. Same SE bound on multiple legs / multi-token SE sharing.  
5. DETF family that uses this hook as reserve host (separate family PRD).  
6. Native ETH currency.  
7. Keeper-based rebalance / inventory management.  
8. Dynamic SE rebinding (instances remain immutable).

---

## 11. Definition of Done (package)

- [ ] Diamond package deploys via registry + hook factory with correct flags.  
- [ ] Binding validates tokens, optional SEs (distinct when set), optional RPs (only with SE).  
- [ ] All three pair doors initialize; swaps work on each door against shared book.  
- [ ] Effective reserves = raw **or** shares×rate **or** SE claim; free buffered dust not book.  
- [ ] Buffer-last + share/claim composition green under SE dilution.  
- [ ] Sphere exact-in/out + partial book + full-book multipath LP green.  
- [ ] **Zap-in** green when zap-eligible; reverts when partial/empty/dust-only; **no zap-out**.  
- [ ] **SE In/Out** green both directions for each token pair; Permit2-only pulls; not LP.  
- [ ] SE missing exact-out invert on a required path **reverts whole tx** (D31a) — covered by test.  
- [ ] Trading + growth fee channels green (orbital dual-channel); previews bit-exact.  
- [ ] LP: Permit2 + transferFrom; SE In/Out: Permit2 only.  
- [ ] Config matrix 0–3 SEs + RP rows green.  
- [ ] `postDeploy` creates all three pair doors.  
- [ ] Adversarial suite green.  
- [ ] Fork smoke Base + Robinhood (4663) green.  
- [ ] No monomorph CREATE3 product factory; no SE shares as pool currencies; no subclassing peer hooks.

---

## 12. Revision log

| Version | Date | Notes |
|---------|------|-------|
| **v0.1** | 2026-08-04 | Initial PRD: orbital curve/topology + per-token optional SE buffer + optional rate provider; hook diamond deploy; buffer-last/claim process from Single SE BCP; three doors; 0–3 SE matrix |
| **v0.2** | 2026-08-04 | Conversation locks: distinct SEs; orbital dual-channel fees; **zap-in only**; RP rates **SE shares** (Balancer SE RP peer); **SE In/Out required v1**; updated DoD + surfaces |
| **v0.3** | 2026-08-04 | D31a SE exact-out fail → full revert; Q2 native×rate→toWad; Q4 dust=10; Q5 postDeploy pools; Q9 zap-in algorithm §4.5.3; Q11 SE In/Out Permit2-only; open-item table closed |

---

## 13. Canonical law index (planner shortcut)

| Topic | Normative pointer |
|-------|-------------------|
| Product shape / non-goals | §1–§2.3 |
| Binding tokens / SE / RP | D4–D12, D5a, D6–D6a, D9 |
| Effective reserves + rate | D24–D28, D26 Q2, §4.3 |
| Sphere / \(R\) / \(L^2\) | D20–D23, §4.4 |
| SE invert / exact-out fail | **D31a**, §4.4, §4.5.4 |
| Buffer-last + composition | D31–D33, O7–O8, O11, §4.5 |
| Three doors topology | D13–D14, D60, §4.2 |
| LP multipath / partial book | D38–D45, O3 |
| Zap-in only | D41a–D41c, O4, **§4.5.3 algorithm** |
| SE In/Out | D49a–D49c, §4.5.4, §6.4 |
| Fees (trading + growth) | D50–D56, §4.6 |
| Deploy / salt / diamond | D57–D62, §7 |
| Test matrix | D65–D66, §8, §11 |
| Resolved clarifications | §9 |
