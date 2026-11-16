# Product Requirements Document (PRD)

## Title

**MultiPairStandardExchangeBufferPool** — multi-pair weighted Standard Exchange buffer pool (Balancer V3)

## Status

**LOCKED (product requirements) — living doc for implementation refinements**

Product decisions **L1–L27** are locked. Do **not** reopen L-decisions without an explicit PRD revision + log note.

- Prefer editing this file for formula / TestBase refinements during planning.
- Append session notes to **§ Living progress log**.
- Implementation plan: `MultiPairStandardExchangeBufferPool_IMPLEMENTATION_AND_TEST_PLAN.md`.
- Production implementation should follow that plan (or an explicit “implement now” instruction).

**Created:** 2026-07-18  
**Requirements locked:** 2026-07-18 (through L27)  
**Behavioral reference:** `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/` (`StandardExchangeBufferPool`)  
**Package path (intended):** `contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/`

---

## Living progress log

> Newest first. Keep short; decisions go into tables, not only the log.

| Date | Note |
|------|------|
| 2026-07-18 | Added dedicated **adversarial test plan** (CUSTOM drain, donation, reentrancy, cross-pair accounting, residual inventory) — wired as Phase 5b in implementation plan. |
| 2026-07-18 | Clarified **L5**: Hook Facet **MUST** be included in the pool proxy Diamond (`hooksContract == pool`); no separate hooks contract. |
| 2026-07-18 | Post-lock clarifications: **init** seeds `virtualBuffer[i]` from **explicit buffer-leg scaled18 seed**; **invariant-ratio bounds** match **normal weighted pool** (not identity); **rate providers** allow optional non-zero override else default SE RP; next deliverable = **implementation & test plan only**. |
| 2026-07-18 | Final product clarifications locked: **O5** = distinct token/vault pairs only; **O8** = role name **`bufferToken`**; **O9** = single **pool-wide static fee**; **O10** = same SE I/O policy as single buffer (preview-aligned pre-seat; best-effort deposit reconcile). |
| 2026-07-18 | Requirements clarifications locked: **O1** = bufferToken + vaultShare per pair (`T = 2P`); **O2** = **full weighted graph** (any pool token → any other); **O6** = **unbalanced LP allowed** (parity with current single buffer); **O7** = multi-pair and single-pair buffer remain **parallel products forever**. |
| 2026-07-18 | **Equivalence thesis locked.** Multi-pair pool is the **weighted** analogue of the single-pair buffer: virtual + hook bookkeeping so AMM behavior matches a **normal** Balancer weighted pool with the same tokens/weights/rate providers. Full *economic* parity with that reference is impossible when SE vault underlyings trade (buffer consolidates more inventory → different share NAV path); **comparative equivalence tests freeze SE underlying reserves** (no trades through the vault’s underlying market). Weights model = **fixed deploy-time weights** (target A); single-buffer rate-scaled *effective* weights are a 2-token special case, not the multi-token requirement. Research written into § Equivalence thesis. |
| 2026-07-18 | Initial PRD from design discussion. Goal: weighted Balancer V3 pool with **up to 4 token/vault pairs**, buffering each configured token into its paired Standard Exchange vault. Reference: single-pair SE buffer (virtual reserve + hook pre-seat/reconcile). |

---

## Purpose

Expose a **Balancer V3–native weighted market** over **one to four** `(token, Standard Exchange vault)` pairs, where each pair’s **bufferable token** is consolidated into the vault configured for that pair — the same product idea as the single-pair **constant-product** buffer, generalized to **weighted** multi-token math.

Primary goals:

1. **Equivalence to a normal weighted pool (AMM behavior)** — under controlled conditions, swap amounts, spots, and post-trade math balances match a reference Balancer weighted pool with the **same tokens, fixed weights, fees, and rate providers** (see § Equivalence thesis).
2. **Multi-asset routing surface** — standard `IVault.swap` / BatchRouter / SE router paths across multiple buffered legs without one pool per pair.
3. **Liquidity consolidation** — each configured token is deposited into / redeemed from its SE vault via hooks; physical buffer tokens are eventual-zero in the Balancer pool at rest; inventory lives in Standard Exchange vaults.
4. **Weighted pricing** — Balancer `WeightedMath` with **deploy-time fixed normalized weights** (not forced 50/50 CP per pair).
5. **Composable with IndexedEx** — Crane Diamond, vault-registry DFPkg path, production-first tests, opaque SE vaults (including nested DETF / other SE).

Non-goals for this product (see Scope): DETF seigniorage, bond NFT, claim token, off-pool FX ledgers; **full economic identity** with a reference pool once SE underlyings trade and share NAV diverges.

---

## Behavioral references

| Reference | Take | Do not copy blindly |
|-----------|------|---------------------|
| **Single SE Buffer** (`constProd/standardExchange/`) | Virtual reserve for buffered side; `hookSharesDelta` / derived depth; pre-seat (`shares→token`) + post-swap reconcile (`token→shares`); hook-as-pool Diamond; CUSTOM LP passthrough + `NotHookCaller`; Vault-sourced rates; best-effort deposit reconcile; BV3 rate round-trip helpers; donation + CUSTOM remove dance; **equivalence mindset** vs a normal 2-token pool with the same rate provider | Hard-coded **exactly 2** tokens; single `virtualTTA` / single SE vault; **rate-scaled effective weights** (2-token NAV refinement — **not** copied as multi-token weight model); invariant ratio identity may need re-think for multi-token LP |
| **Balancer V3 WeightedPool** | **Reference AMM** for multi-pair: multi-token `WeightedMath`, fixed weights sum `1e18`, min weight bounds (~1%), MaxIn/MaxOut, rates in `balancesLiveScaled18` for `WITH_RATE` legs | Physical balances on every leg; no SE buffer hooks |
| **MultiVaultWeightedDetf** | Multi-leg deploy hygiene, optional per-leg rate providers, registry DFPkg packaging | DETF self-leg, seigniorage mint/burn, bonding/claim, synthetic thresholds |
| **Constant-product BV3 pool** (non-buffer) | Comparative pattern for **P=1** / 50–50 slice; same freeze-underlying discipline | No buffer hooks; not the multi-token reference |

---

## Product shape (working model)

### Pair

A **pair** is:

| Field | Role name | Meaning |
|-------|-----------|---------|
| Bufferable token | `bufferToken[i]` | ERC-20 that is **buffered into** the vault (analog of single-pool **TTA**) |
| Standard Exchange vault | `standardExchangeVault[i]` | Vault that accepts `bufferToken[i]` as an underlying (must be ∈ vault `tokens()`) |
| Vault share token | `vaultShare[i]` | Share ERC-20 of that vault (often `address(vault)`) — Balancer pool token for the share side |
| Rate provider | `rateProvider[i]` | Balancer `IRateProvider` for `vaultShare[i]` quoting value in `bufferToken[i]` terms (default: Standard Exchange rate provider for `(vault, bufferToken)`) |

**Locked (O1 / L17):** each pair contributes **two** Balancer pool tokens: `bufferToken[i]` (`STANDARD`) and `vaultShare[i]` (`WITH_RATE` + `rateProvider[i]`).

With **pair count `P`** where **`1 ≤ P ≤ 4`**:

- **Balancer token count** `T = 2P` → **2 … 8** tokens (fits Balancer weighted pool max 8).
- **Swap surface (O2 / L18):** full weighted graph — any registered pool token ↔ any other (subject to Balancer MaxIn/MaxOut and hook pre-seat/reconcile for buffer legs).
- **LP (O6 / L19):** proportional **and** unbalanced allowed (same spirit as current single buffer); donation + CUSTOM remain hook tools for reconcile.
- At rest, design intent for each buffered token: **eventual-zero physical `bufferToken[i]` in the Balancer pool** between operations (same spirit as single buffer), with accounting depth in pool storage.

### Naming (code / NatSpec)

| Use | Name |
|-----|------|
| Product / types | `MultiPairStandardExchangeBufferPool`, `MultiPairStandardExchangeBufferPoolDFPkg`, … |
| Bufferable token | **`bufferToken`** only (L22); not `TTA`/`tta`; not brand names; not `WETH` unless WETH-specific code |
| Vault / share | `standardExchangeVault` / `vaultShare` |
| Virtual depth for bufferable side | `virtualBuffer[i]` or `virtualBalance[i]` (generalizes `virtualTTA`) |
| Share reshuffle offset | `hookShareDelta[i]` (generalizes `hookSharesDelta`) |
| Deploy weights | `weight[t]` per Balancer token index; fixed; sum `1e18` |

**Forbidden:** product tickers as role names (`RICH`, etc.).

---

## Equivalence thesis (research + decisions)

### Product framing

The existing **Standard Exchange Buffer Pool** is a **two-token constant-product** (equivalently 50/50 weighted at baseline) Balancer pool that:

1. Does **not** hold physical `bufferToken` (TTA) at rest — it tracks how much has been deposited and exchanged through swaps via **`virtualTTA`** and **`hookSharesDelta`**.
2. Runs pre-seat / post-swap SE vault I/O so users still receive ordinary Balancer settlement.
3. Is designed so that, for AMM purposes, it **replicates a normal constant-product pool** registered with the **same two tokens** and the **same rate provider** on the share leg.

This multi-pair product is the **weighted-pool version of that idea**: same buffer/hook discipline, **`WeightedMath`** over a larger token set, **fixed deploy-time weights**.

### Is weighted equivalence feasible?

**Yes — for AMM-observable behavior.** Balancer weighted math only needs a **balance** and a **weight** per token. It does not require those balances to be physical Balancer Vault reserves:

| Reference weighted pool | Multi-pair buffer |
|-------------------------|-------------------|
| Physical balance of each `bufferToken[i]` | **`virtualBuffer[i]`** (math only; physical eventual-zero at rest) |
| Physical balance of each `vaultShare[i]` (rate-scaled by Vault) | Live Vault balance ± **`hookShareDelta[i]`** → derived share depth |
| Fixed weights \(w_t\), sum `1e18` | **Same fixed weights** |
| Same `IRateProvider` on each `WITH_RATE` share | **Same providers** (rates read as the Vault applies them) |
| Swap / invariant / proportional LP update those balances | Hooks reshape physical inventory **without corrupting** the math vector |

Swap amount calculation depends only on the in/out legs’ math balances and weights. Invariant and proportional LP use the **full** math vector. Therefore equivalence reduces to:

> After every successful operation, the buffer’s math balance vector equals the reference weighted pool’s live (rate-scaled) balance vector for the same history of user swaps and LP — **when rates and SE underlying state are controlled as specified below.**

Hooks may temporarily move tokens (redeem/deposit, DONATE, CUSTOM remove) exactly as the single buffer does, provided non-involved legs’ math balances stay correct (especially when pre-seating a buffer token from its own share inventory during a cross-pair swap).

### What “full equivalency” cannot mean

**Locked: we do not claim full economic equivalence** to a reference weighted pool that holds the same tokens purely as Balancer reserves, once the **Standard Exchange vault’s underlying market** is active.

Reasons:

1. **Inventory location** — The buffer **consolidates** buffer tokens into the SE vault. The vault’s total reserves (and thus share NAV / rate provider output) include buffered inventory **plus** whatever else is in the vault. A reference weighted pool keeps buffer tokens in the Balancer pool and only holds shares as a separate ERC-20 balance; it does **not** automatically enlarge the SE vault’s underlying by the same amount.
2. **Larger vault reserve ⇒ different earnings / NAV path** — If the SE vault’s underlying DEX (or other yield source) is traded, fees and inventory shifts accrue to **share holders**. Extra underlying deposited by the buffer increases that reserve relative to a world where those tokens sat idle in a normal weighted pool. Share **rate** then diverges between:
   - buffer world (vault grew from buffer deposits), and  
   - reference world (those tokens never entered the vault).
3. **Rate feedback into AMM** — Both pools use `WITH_RATE` scaled balances. Once rates diverge, even identical *raw* share balances produce different scaled depths and different subsequent quotes. That is expected, not a bug in the buffer math.

So: **AMM machinery can match; open-economy share NAV cannot stay identical** when buffer-driven vault size differs and underlyings trade.

### How we *do* test equivalence (decision)

**Locked comparative protocol:**

Prove AMM equivalence against a **normal Balancer V3 weighted pool** (same token list, same fixed weights, same rate providers, same swap fee) by:

1. **Matching init** — Seed so math/live balances match (reference physical `bufferToken` balances = buffer `virtualBuffer`; reference raw shares = buffer pool raw shares; same rate providers ⇒ identical scaled share legs).
2. **Freezing SE underlying markets** during comparative scenarios — **do not trade through the vault’s underlying reserve** (no swaps/liquidity ops on the SE vault’s paired DEX or other rate-moving underlyings that would change share NAV). Rate providers stay aligned between buffer and reference for the duration of the scenario.
3. **Driving only the two pools** — User swaps and LP only against buffer vs reference (and any funding of ERC-20 balances that does not move SE underlying markets).
4. **Asserting** — Swap outputs (both directions as in scope), spot / invariant-relevant state, and post-trade math balances within documented wei / relative tolerances (fees equalized).

Optional separate suites (not required for the core equivalence claim):

- Rate **movement** when underlyings *are* traded: exercise real SE behavior and buffer hooks; **do not** require numerical match to a static reference pool after those trades.
- Residual / eventual-zero physical buffer token invariants on the buffer alone.

This mirrors the single-pair comparative intent (“same tokens + same rate provider”) with an **explicit freeze** so vault-size / yield divergence does not invalidate the AMM check.

### Weights model (decision)

| Model | Role in this product |
|-------|----------------------|
| **Fixed deploy-time weights + rates in Vault scaled balances** | **LOCKED reference and production weight model** for multi-pair. Matches a normal BV3 weighted pool. |
| **Rate-scaled effective weights** (`currentRate/baselineRate` retuning \(w\)) | Used by the **two-token** single buffer as a NAV-tracking refinement. **Not** required for multi-pair equivalence to a normal weighted pool. Do not generalize as the multi-token weight engine unless a future PRD revision explicitly opts in. |

At **two tokens and 50/50 weights**, fixed-weight weighted math coincides with constant-product up to Balancer rounding / MaxIn-MaxOut — so `P=1` with equal weights remains a natural bridge to the existing buffer’s comparative story (still under freeze-underlying when comparing to a non-buffer reference).

### Cross-pair swaps under the thesis

If full weighted graph is allowed (O2 still open): a swap only changes math balances of **tokenIn** and **tokenOut**. Pre-seat of an out-buffer token may touch **that pair’s** share inventory with a delta adjustment so **that pair’s** derived share depth is unchanged for non-involved math. Reconcile of an in-buffer token deposits into **that** vault and adjusts **that** share delta only. Non-involved legs’ math balances must match the reference (unchanged). Feasible; complexity is bookkeeping, not a new AMM.

### Checklist for implementers (equivalence)

1. One math balance per pool token; always equal to reference after success (under freeze protocol).
2. Per-buffer-token virtuals + per-share hook deltas.
3. One `vaultShare` address at most once (one rate provider per share token).
4. Hooks preserve non-involved legs’ math balances.
5. Same fee, fixed weights, rate providers as reference registration.
6. Init match as above.
7. Proportional LP scales the whole virtual vector as BPT would scale reference balances.
8. Best-effort (or documented) deposit reconcile so hooks do not invent free share depth.
9. Comparative tests **freeze SE underlying trading**.

---

## Locked decisions

Resolved or **provisionally locked** for design. Change only via explicit PRD edit + log note.

| # | Topic | Decision | Status |
|---|-------|----------|--------|
| L1 | Pair count | **`1 ≤ P ≤ 4`** pairs per instance | **LOCKED** (product ask) |
| L2 | Packaging | **Single parameterized DFPkg**; `P` and per-pair config in `PkgArgs` | **LOCKED** |
| L3 | Codepath | **Fresh** under `pools/weighted/multiPairBuffer/`; single-pair buffer is **behavioral reference only** (do not subclass its targets as a multi-pair base; shared pure libs later optional per L20) | **LOCKED** |
| L4 | Deploy path | Facets: CREATE3 + FactoryService. DFPkg: **Vault Registry / manager** (`IStandardVaultPkg`). Never `new` facets/DFPkgs. | **LOCKED** (repo rule) |
| L5 | Pool + hook | **Single Crane Diamond**: the **Hook Facet MUST be cut into the pool proxy** (same address as the pool). `hooksContract == address(pool)` at Balancer registration. **Never** deploy a separate hooks contract or register an external hooks address | **LOCKED** (match single buffer; mandatory) |
| L6 | External SE surface | Production code talks to **`IStandardExchange*`** only for vault I/O; no concrete Uni/Aero/Camelot types in pool sources | **LOCKED** (repo opacity) |
| L7 | Rate reads in math/hooks | **Vault-sourced** for live rates used when lifting/raw round-tripping share amounts (`IVault.getPoolTokenRates`); production weights do **not** retune from rate (see L13) | **LOCKED** |
| L8 | Rate provider deploy | See **L27** (default SE RP or optional non-zero override) | **LOCKED** |
| L9 | Testing | **Production-first**; no mocks of SUT pool/facets/DFPkg/manager/registry; real SE vaults (hermetic ports and/or fork) | **LOCKED** (repo rule) |
| L10 | DETF / bond / claim | **Out of scope** for this pool product | **LOCKED** |
| L11 | Max tokens | **`T = 2P ≤ 8`** (two tokens per pair) | **LOCKED** (via L17) |
| L12 | **AMM equivalence thesis** | Multi-pair buffer is the **weighted** analogue of the single-pair buffer: virtual + hook accounting so behavior matches a **normal Balancer V3 weighted pool** with the same tokens, **fixed** weights, fees, and rate providers | **LOCKED** |
| L13 | **Weights model** | **Deploy-time fixed** normalized weights for all pool tokens; sum `1e18`; immutable; each weight ≥ Balancer min (~1%). **Not** multi-token rate-scaled effective weights | **LOCKED** |
| L14 | **Economic vs AMM equivalence** | **Full economic equivalence is not a goal** once SE vault underlyings trade: buffer consolidates inventory into vaults → larger vault reserve → different share NAV / earnings path than a reference pool that keeps buffer tokens only as Balancer balances | **LOCKED** |
| L15 | **Comparative test protocol** | Equivalence suites **must not trade the SE vault’s underlying reserve** (freeze rate-moving underlying activity). Match init live balances; drive only buffer vs reference pool ops; assert swap/spot/math-balance parity within documented tolerances | **LOCKED** |
| L16 | **Reference pool for tests** | Production-faithful **Balancer V3 weighted pool** (or project’s weighted DFPkg equivalent), not a mocked curve; same token config and rate providers as the buffer instance under test | **LOCKED** |
| L17 | **Pool token set** | Each pair registers **`bufferToken[i]` + `vaultShare[i]`** → `T = 2P` tokens | **LOCKED** |
| L18 | **Swap routes** | **Full weighted graph**: any pool token → any other (Balancer limits apply). Hooks must pre-seat/reconcile buffer legs for cross-pair as well as within-pair | **LOCKED** |
| L19 | **LP model** | **Unbalanced LP allowed** in v1 (plus proportional), aligned with current single buffer; hook DONATION/CUSTOM for reconcile; `NotHookCaller` on CUSTOM | **LOCKED** |
| L20 | **vs single-pair package** | **Parallel products forever**: `constProd/standardExchange` remains the 2-token buffer gold path; multi-pair is a separate weighted package under `weighted/multiPairBuffer/` (no planned replacement of single buffer) | **LOCKED** |
| L21 | **Pair uniqueness** | Deploy requires **distinct token/vault pairs**: all `bufferToken[i]` distinct; all `vaultShare[i]` / vaults distinct; every Balancer pool token address unique; one vault share address appears at most once (one rate target per share). Same multi-asset vault cannot be listed twice | **LOCKED** |
| L22 | **Role naming** | Bufferable token role is **`bufferToken`** (not `TTA` / `tta`) in multi-pair contracts, interfaces, storage, and normative NatSpec. Single-pair package may keep historical `TTA` names | **LOCKED** |
| L23 | **Swap fee** | **Single pool-wide static fee** (Balancer static swap fee on the pool). No per-pair fee schedule. Default at register may match single buffer / weighted peers (e.g. 0.05%); exact default is deploy-time / package constant | **LOCKED** |
| L24 | **SE I/O policy** | **Same as single-pair buffer**, generalized per pair: **preview-aligned pre-seat** when delivering `bufferToken` out (shares→buffer path); **best-effort full deposit** of received `bufferToken` into the configured vault on reconcile (buffer→shares / buffer-in paths), not exact share-mint targeting. Pre-seat / deposit failures surface as peer-style errors (`PreSeatRedemptionFailed`, `PostSwapDepositFailed`, or multi-pair equivalents) | **LOCKED** |
| L25 | **Init virtual seed** | On initialize, **`virtualBuffer[i]` = explicit buffer-leg scaled18 seed amount** for that pair (match intended reference live buffer balance). Do **not** derive virtuals solely from share-side scaled18 (single-buffer historical special case). Comparative tests set reference physical buffer balances equal to these virtuals | **LOCKED** |
| L26 | **Invariant ratio bounds** | Match **normal Balancer weighted pool** min/max invariant ratios (not single-buffer identity `1e18/1e18`), so unbalanced LP / rebalance paths align with the equivalence reference | **LOCKED** |
| L27 | **Rate provider override** | Per pair: if `rateProviders[i] != address(0)`, use it; else **deploy default** Standard Exchange rate provider for `(vault, bufferToken)`. Overrides must still price that vault share in `bufferToken` terms for WITH_RATE registration | **LOCKED** |

---

## Open questions

All product open questions for v1 scope are **resolved**. Remaining items are implementation-detail only (do not block PRD lock for requirements).

### O1 — Pool token set

**RESOLVED → L17.** Each pair adds **both** `bufferToken[i]` and `vaultShare[i]` → `T = 2P` (up to 8).

### O2 — Swap surface (allowed routes)

**RESOLVED → L18.** **Full weighted graph**: any registered pool token → any other (Balancer MaxIn/MaxOut). Cross-pair pre-seat/reconcile is **in scope for v1**.

### O3 — Weights model

**RESOLVED → L13.** Deploy-time **fixed** weights. Rate-scaled effective weights are out of scope for multi-pair v1 (single-buffer-only refinement).

### O4 — Virtual state representation

**Implementation default → per-pair storage (A):** `virtualBuffer[i]`, `hookShareDelta[i]`, buffer/share indices; global fixed `weights[]`. Cross-pair virtual updates are **single-in/single-out** weighted settlement only (L12) — not a synthetic multi-hop. Layout A vs B is an implementation detail unless it affects the public interface.

### O5 — Uniqueness constraints at deploy

**RESOLVED → L21.** Distinct token/vault pairs only:

1. All `vaultShare[i]` / vault addresses **distinct**.
2. All `bufferToken[i]` **distinct**.
3. All Balancer pool token addresses **unique**.
4. Same multi-asset SE vault **cannot** appear as two pairs (one share address ⇒ one pair, one rate target).
5. Same `bufferToken` with two different vaults **disallowed**.

### O6 — LP model

**RESOLVED → L19.** Proportional **and unbalanced** allowed (like current single buffer). DONATION/CUSTOM for hook reconcile; CUSTOM gated `NotHookCaller`.

### O7 — Relationship to single-pair package

**RESOLVED → L20.** **Parallel products forever.** Shared pure helpers only if extracted later without coupling package lifecycles.

### O8 — Name of bufferable token role

**RESOLVED → L22.** Use **`bufferToken`** in multi-pair code and NatSpec.

### O9 — Static swap fee / protocol fee

**RESOLVED → L23.** Single **pool-wide** static fee; no per-pair fees.

### O10 — Failure modes on SE I/O

**RESOLVED → L24.** Same SE I/O as single buffer: preview-aligned pre-seat for buffer out; best-effort full deposit reconcile for buffer in.

---

## Scope

### In scope (v1) — pending open-question resolution

- Directory: `contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/`
- Parameterized **`P ∈ [1, 4]`** pairs
- Balancer V3 **weighted** pool math over the registered token set
- Per-pair wiring: `bufferToken`, `standardExchangeVault`, `vaultShare`, `rateProvider` (default deployable)
- Hook-driven **buffer into vault** for each configured buffer token (pre-seat / post-swap generalize single buffer)
- Diamond facets: pool math, hooks, CUSTOM liquidity (hook-gated), standard BV3 pool token / fee bounds / auth / vault-aware as peers
- DFPkg + FactoryService + Vault Registry registration as `IStandardVaultPkg`
- Production-first Foundry tests: registration, init, swaps, LP proportional, **comparative equivalence under L15 freeze**, adversarial CUSTOM drain, eventual-zero buffer token invariants
- Optional: rate movement via **real** SE underlying trades (buffer correctness only — **not** vs frozen reference parity)

### Out of scope (v1)

- `P > 4` or `T > 8`
- DETF seigniorage, bond NFT, rebasing claim
- Dynamic governance reweight after deploy
- Multi-token **rate-scaled effective weights** (single-buffer-style \(w \propto rate\))
- Claiming **economic** parity with a reference pool after SE underlyings trade / vault size diverges
- Bare ERC-20 legs with **no** SE vault pairing
- Pool-owned strategies / rebalancing bots
- Subclassing concrete single-buffer contracts as the multi-pair implementation base (shared **libs** later OK)
- Cross-chain messaging
- Exact multi-token solvers beyond Balancer single-in/single-out weighted swaps
- Fee-on-transfer / weird tokens unless already supported by SE vaults under test

---

## Architecture (target)

```
                    Balancer V3 Vault (singleton)
                     | swap / add / remove / rates
                     v
        MultiPairStandardExchangeBufferPool Diamond  (== hooksContract)
          • IBalancerV3Pool (WeightedMath over virtual + derived balances)
          • IHooks via Hook Facet cut into THIS proxy (mandatory — L5)
          • IPoolLiquidity (CUSTOM passthrough, NotHookCaller)
          • BPT + fee bounds + pool info + vault-aware (peer facets)
          • Repo: per-pair config + virtualBuffer[i] + hookShareDelta[i] + fixed weights[]
                     |                              |
                     | getPoolTokenRates            | exchangeIn / exchangeOut
                     v                              v
              rateProvider[i]                 standardExchangeVault[i]
              (per vaultShare[i])             (buffer token i ↔ shares i)

  Anti-pattern: separate hooks contract address. Registration MUST set hooksContract = pool proxy.
```

### Facet / package inventory (sketch)

| Piece | Role |
|-------|------|
| `IMultiPairStandardExchangeBufferPool` | Errors, views, pair config getters |
| `MultiPairStandardExchangeBufferPoolRepo` | Storage slot + layout |
| `MultiPairStandardExchangeBufferPoolCommon` | Rate lift, weights, derived balances, BV3 round-trips |
| `MultiPairStandardExchangeBufferPoolTarget` | `computeInvariant`, `computeBalance`, `onSwap` |
| `MultiPairStandardExchangeBufferHookTarget` | Registration, init, pre-seat, reconcile, LP state |
| `MultiPair…LiquidityTarget` | CUSTOM add/remove, hook-only |
| `*Facet` wrappers | IFacet metadata |
| `MultiPair…StandardVaultPkg` | DFPkg + `PkgInit` / `PkgArgs` on **interface** |
| `MultiPair…_FactoryService` | CREATE3 facet deploy + manager `deploy*DFPkg` |

---

## Registration (target)

### TokenConfig

For each pair `i`, after address-sort into Balancer order:

- `bufferToken[i]`: `TokenType.STANDARD`, `rateProvider = 0`
- `vaultShare[i]`: `TokenType.WITH_RATE`, `rateProvider = rateProvider[i]`, `paysYieldFees = false`

### LiquidityManagement (working)

- `enableAddLiquidityCustom = true`
- `enableRemoveLiquidityCustom = true`
- `enableDonation = true`
- `disableUnbalancedLiquidity = false` (**L19** — unbalanced allowed)

### HookFlags (working, match single buffer spirit)

| Flag | Value |
|------|-------|
| `shouldCallBeforeInitialize` | true |
| `shouldCallAfterInitialize` | false |
| `shouldCallBeforeSwap` | true |
| `shouldCallAfterSwap` | true |
| `shouldCallBeforeAddLiquidity` | true |
| `shouldCallAfterAddLiquidity` | true |
| `shouldCallBeforeRemoveLiquidity` | false |
| `shouldCallAfterRemoveLiquidity` | true |
| `shouldCallComputeDynamicSwapFee` | false |
| `enableHookAdjustedAmounts` | false |

### Hook contract binding (**L5 — mandatory**)

- The **Hook Facet is a facet of the pool Diamond** (`facetCuts` includes `hookFacet` with full `IHooks` selectors).
- On `registerPool` / `postDeploy`: **`hooksContract = proxy`** (the pool address), never a sibling contract.
- `onRegister` requires `pool == address(this)` so only this proxy can bind as its own hooks.
- CUSTOM liquidity `router == address(this)` relies on hook code executing in the pool’s context (same diamond).

### `onRegister` checks (minimum)

- Caller is Vault; factory is expected DFPkg; `pool == address(this)` (hooks live here)
- `tokenConfig.length == 2P`
- Each pair’s tokens, types, and rate providers match stored config
- LiquidityManagement flags match package policy
- Uniqueness constraints from L21

---

## Math and state (design sketch — aligned with L12–L13)

### Storage (conceptual)

```text
// Immutable after init:
P
for i in 0..P-1:
  bufferToken[i], vaultShare[i], standardExchangeVault[i], rateProvider[i]
  bufferIndex[i], shareIndex[i]   // indices into Balancer token array
weights[0..T-1]                   // fixed, sum == 1e18 (Balancer token order)
expectedFactory

// Live:
for i in 0..P-1:
  virtualBuffer[i]      // scaled18 accounting depth for bufferToken[i]
  hookShareDelta[i]     // signed raw share offset for derived share depth

// Swap scratch (may be multi-field if multi-leg pre-seat):
pendingPreSeat...
```

### Balance vector used by WeightedMath

For each token index `t` in the Vault’s ordered list:

- If `t` is `bufferToken[i]`: use **`virtualBuffer[i]`** (not physical Balancer balance).
- If `t` is `vaultShare[i]`: use **`derivedShareDepth[i]`** = live scaled18 shares ± lifted `hookShareDelta[i]` (same construction as single-buffer `_derivedY`).

Invariant / swap / `computeBalance`: Balancer **`WeightedMath`** with **fixed** `weights[t]` (L13). Share rates enter **only** via Vault scaling of live share balances (and lift helpers for deltas) — **not** by retuning weights.

### Equivalence identity (AMM)

Under L15 (SE underlyings frozen) and matched init:

\[
B^{\text{buffer}}_t = B^{\text{reference}}_t \quad \forall t
\quad\Rightarrow\quad
\text{swap/LP outputs match within tolerance.}
\]

After a buffer-only trade history, hooks must restore that equality for the updated post-trade vector (reference updates physical balances; buffer updates virtuals / derived shares equivalently).

When SE underlyings **are** traded, rates may diverge; identity is **not** required (L14).

### Initialization (**L25**)

- Seed **`virtualBuffer[i] = exactAmountsInScaled18[bufferIndex[i]]`** (explicit buffer-leg seed from Balancer init).
- Share legs start with `hookShareDelta[i] = 0` (derived depth = Vault live scaled shares).
- Comparative tests: reference pool physical buffer balances = these virtuals; raw share balances matched; same rate providers.
- Single-buffer historical “seed virtual from shares side only” is **not** used for multi-pair.

---

## Hook lifecycle (generalization sketch)

### Classification of a swap leg

Given `tokenIn` / `tokenOut` (or indices):

1. Resolve which pair owns each token (buffer vs share).
2. Determine required SE operations (**L24** = single-buffer I/O policy, per owning pair):
   - **Any path with `bufferToken` out:** **pre-seat** that buffer token via its pair’s vault — preview-aligned redemption of that pair’s shares from pool inventory (within-pair or cross-pair; out-pair owns pre-seat).
   - **Any path with `bufferToken` in:** **no-op** in `onBeforeSwap` for seating; **reconcile** in `onAfterSwap` — best-effort full `exchangeIn` of received buffer into that pair’s vault, DONATE minted shares, CUSTOM-remove physical buffer, update `virtualBuffer` / `hookShareDelta` for that pair only.
   - **Share ↔ share (no buffer token):** no SE vault I/O; only weighted math + physical share balances / deltas as needed for equivalence.

### Within-pair (must match single buffer behavior for `P=1`)

Parity target when `P=1` and equal (or any fixed) weights: **same pre-seat / best-effort reconcile / virtual updates** as `StandardExchangeBufferPool` (modulo `bufferToken` naming and fixed weights instead of effective-weight retuning).

### Cross-pair (**required** — L18)

Under L12/L18, cross-pair is still **one weighted swap** on two legs: update only those two math balances to match reference. Pre-seat out-buffer via **out-pair** vault/share inventory with delta so out-pair derived share depth is unchanged for non-involved math; reconcile in-buffer into **in-pair** vault without inventing depth on other legs (see § Equivalence thesis). Full graph is **in scope for v1**; complexity is hook paths, not math.

### LP bookkeeping

- **Proportional:** scale **all** `virtualBuffer[i]` and `hookShareDelta[i]` by BPT ratio (signed).
- **Unbalanced / donation:** donation used by hook reconcile must **not** double-count virtuals (same DONATION no-op rule as single buffer).
- **Remove:** proportional scale-down with clamp at zero virtuals.

### Security

- CUSTOM liquidity: **`router == address(this)`** only.
- Every hook entry: `msg.sender == Vault`, `pool == address(this)`.
- SE router prepay auth pass/restore when present (parity with single buffer).

---

## Deploy args (sketch)

```solidity
// On interface IMultiPairStandardExchangeBufferPoolPkg — not on the contract body
struct PkgArgs {
    uint8 pairCount; // 1..4
    // parallel arrays length == pairCount
    IERC20[] bufferTokens;
    IStandardExchange[] standardExchangeVaults;
    // rateProviders: address(0) => deploy default for (vault, bufferToken)
    IRateProvider[] rateProviders;
    // weights: length == 2 * pairCount (or pairCount*2 after sort policy), sum == 1e18
    uint256[] weights;
    // optional: name/symbol overrides, swapFeePercentage
}
```

Validation (minimum) — includes **L21**:

- `pairCount ∈ [1,4]`
- Array lengths match
- Each `bufferToken[i] ∈ standardExchangeVault[i].tokens()` (or equivalent SE surface)
- `vaultShare[i] == address(standardExchangeVault[i])` if SE uses vault-as-share; otherwise explicit share token if SE surface requires it
- Weights positive, sum `1e18`, each ≥ min weight
- All `bufferToken[i]` distinct; all vault/`vaultShare[i]` distinct; no duplicate addresses in the Balancer token list

---

## User / integrator flows

### Deploy

1. Register multi-pair DFPkg on vault registry (ops).
2. `deployPool(PkgArgs)` → Diamond + Balancer `registerPool` in `postDeploy`.
3. Initialize pool with seed liquidity (both sides of each pair as required by Balancer init).

### Trade

1. Approve router / Permit2 as for any Balancer V3 pool.
2. `swap` exact-in or exact-out on allowed routes (O2).
3. Hooks buffer/unbuffer under the hood; user receives ordinary ERC-20 out.

### LP

1. Proportional join/exit with BPT (v1 baseline).
2. Unbalanced only if O6 allows.

### Quote

- Off-chain / on-chain: Balancer quoter or `querySwap` against Vault; pool math uses virtuals + derived shares so quotes reflect buffer state + rates.

---

## Acceptance criteria (PRD-level)

The PRD is **sufficient to implement** when:

1. **Product requirements** for v1 are locked (**L1–L24**; O1–O10 resolved). Implementation-only choices (e.g. O4 storage layout) may stay flexible.
2. **Math model** is written with formulas for: fixed weights, invariant balances, init seed, within-pair **and cross-pair** virtual updates — consistent with L12/L18/L24.
3. **Failure/error catalog** matches or extends single buffer (`NotHookCaller`, pre-seat/reconcile failures, exhausted side, weight bounds, invalid registration / duplicate pairs).
4. **Test matrix** lists required suites (at least):
   - **Comparative equivalence (required):** buffer vs normal weighted pool; **L15 freeze** (no SE underlying trades); matched init; swap + spot (+ LP if in scope) parity
   - `P=1` with 50/50 weights as bridge case (weighted reference and/or behavioral check vs single-buffer discipline)
   - `P=2` and `P=4` registration + init; **reject non-distinct pairs** (L21)
   - Full-graph swap matrix (within-pair and cross-pair); preview≈execution where closed-form (document wei tolerance if any)
   - Optional: rate shift via **real** underlying trades — buffer-only correctness, **not** reference parity
   - Physical buffer token balances **eventual-zero** invariant (or documented residual policy)
   - CUSTOM remove drain attack reverts
   - Proportional + unbalanced LP virtual updates (L19)
5. **PkgInit/PkgArgs** and facet list are stable enough for FactoryService + TestBase design.
6. Status line upgraded to **LOCKED** (or **LOCKED for v1** with only implementation-plan remaining).

**Requirements status:** product decisions are sufficient to treat this PRD as **ready for implementation planning**. Formal **LOCKED** stamp can be set when the implementation plan is cut or by explicit user mark.

---

## Testing expectations (when implementing)

Mirror `indexedex-testing` + single buffer suites; **L12–L16 are normative for comparative work.**

| Suite | Intent |
|-------|--------|
| Registration / init | TokenConfig, hooks, fixed weights, virtual seeds |
| Swap | Pre-seat + reconcile; directions in scope; EXACT_IN (EXACT_OUT as feasible) |
| **Comparative equivalence (required)** | Reference = normal weighted pool (L16); **freeze SE underlyings** (L15); assert AMM parity |
| Rate / vault stress (optional) | Real SE underlying trades move rate; assert buffer hooks/safety only — **no** reference match requirement (L14) |
| LP proportional | Virtual vector scale |
| LiquidityTarget adversarial | NotHookCaller drain |
| Invariant handler | Random swaps + LP; no free mint; virtual non-negative; eventual-zero buffer tokens |

**Forbidden:** mock SE vault as SUT dependency for lifecycle; `vm.mockCall` on pool diamond; comparative suites that trade SE underlyings and still demand reference parity.

---

## Risks and sharp edges

| Risk | Mitigation direction |
|------|----------------------|
| Cross-pair pre-seat complexity / stack-too-deep | Prefer O2-B for v1; extract helpers; viaIR if needed |
| Comparative false failures from SE underlying trades | **L15:** freeze underlyings in equivalence suites; document L14 |
| Gas on 8-token weighted + multi SE calls | Gas benchmarks; limit P in production deployments |
| BV3 rate round-trip vs SE rate mutation mid-hook | Preserve single-buffer ordering (removeLiquidity before exchangeOut rate shock) **per vault touched** |
| Double-count virtuals on DONATION | Explicit kind handling; no virtual bump on hook-internal donation |
| Same vault two buffer tokens | Careful rate providers (each share has one rate — **a single share token cannot have two rates**). **If one vault has one share token, it can only appear once** → pair (3) “same vault two underlyings” **cannot** put the same `vaultShare` twice. This **constrains O5**: multi-asset vault still has **one** share token → **one pair per vault share address**. Buffer token is the rate target of that provider. |

### Critical consistency note (add to O5)

A Standard Exchange vault that holds multiple underlyings still has **one** share token. The single-pair buffer chooses **one** TTA (rate target) for that share. Therefore:

- **One `vaultShare` address ⇒ at most one pair in this pool.**
- Multi-underlying vaults are supported by picking **one** `bufferToken` (rate target) per vault share, not by listing the vault twice.

If product needs two rate targets for the same share token, that is **out of scope** (would need a different rate model).

---

## Comparison: single-pair vs multi-pair

| Dimension | Single SE Buffer | MultiPair (this PRD) |
|-----------|------------------|----------------------|
| Pairs | 1 | 1–4 |
| Tokens | 2 | 2–8 |
| Math | CP / effective weights 50/50@baseline (rate-tracking refinement) | **Fixed-weight** multi-token `WeightedMath` (L13) |
| Equivalence target | Normal 2-token CP/weighted + same rate provider | Normal **weighted** pool + same tokens/weights/providers (L12) |
| Economic caveat | Vault size vs pure Balancer reserve | Same, multi-vault (L14); tests freeze underlyings (L15) |
| Virtual state | `virtualTTA`, `hookSharesDelta` | Per-pair vectors |
| SE vaults | 1 | up to 4 distinct share tokens / vaults |
| Cross routes | n/a | **Full graph required** (L18) |
| Path | `constProd/standardExchange/` | `weighted/multiPairBuffer/` |

---

## Suggested next design sessions

1. ~~Product lock~~ — **done** (L1–L27).
2. Write `MultiPairStandardExchangeBufferPool_IMPLEMENTATION_AND_TEST_PLAN.md` (in progress / next).
3. Execute plan phases with production-first tests.

---

## Document control

| Item | Value |
|------|--------|
| PRD path | `contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPool_PRD.md` |
| Implementation plan | *Not yet* — create after LOCKED |
| Reference implementation | `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/` |
| Related DETF (not this product) | Multi-vault weighted DETF uses a **normal** weighted pool + seigniorage; this product is a **buffering** pool |

---

## Appendix A — Single-pair buffer cheat sheet (reference)

- **x** = `virtualTTA` (storage); **y** = derived shares from Vault live balance ± `hookSharesDelta`.
- Production single buffer also uses **rate-scaled effective weights** (`wShares/wTta = currentRate/baselineRate`; 50/50 at equality) — multi-pair **does not** adopt this as its weight engine (L13).
- Shares→TTA: pre-seat redeem + DONATE TTA + CUSTOM remove shares; defer virtual decrement to after swap.
- TTA→shares: after swap, deposit all TTA to SE best-effort; DONATE shares; CUSTOM remove TTA; bump virtual + delta so derived y unchanged.
- CUSTOM LP: hook-only.
- Rates for lifts/round-trips: `IVault.getPoolTokenRates`.

## Appendix B — Glossary

| Term | Meaning |
|------|---------|
| Pair | One distinct `(bufferToken, standardExchangeVault / vaultShare, rateProvider)` configuration (L21) |
| `bufferToken` | Bufferable ERC-20 role name for multi-pair (L22); analog of single-pool TTA |
| Buffer | Deposit bufferToken into SE vault (and reverse redeem) so Balancer does not hold that token at rest |
| Virtual buffer | Accounting reserve for bufferToken used in AMM math |
| Derived share depth | Math-side share balance after hook reshuffle offset |
| Pre-seat | Hook action before swap to place real bufferToken in the pool for delivery (preview-aligned; L24) |
| Reconcile | Hook action after swap to push received bufferToken into SE (best-effort deposit; L24) |
| Reference weighted pool | Normal BV3 weighted pool used for comparative AMM equivalence (L16) |
| Freeze underlyings | Comparative protocol: no trades on SE vault underlying markets (L15) |
| AMM equivalence | Match swap/spot/math balances to reference under freeze (L12, L15) |
| Economic equivalence | Same vault size, yield, and NAV path — **not** a product goal (L14) |
| Pool-wide static fee | Single Balancer static swap fee for the whole pool (L23) |
