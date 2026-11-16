# Product Requirements Document (PRD)

## Title

**MixedBufferMultiVaultStablePool** — one or more unpaired (unbuffered) tokens + exactly one common `bufferToken` → up to 3 Standard Exchange vaults, Balancer V3 **Stable** market

## Status

**LOCKED (product requirements) — 2026-07-25**

Product decisions **M1–M30** are locked. Do **not** reopen without an explicit PRD revision + log note.

- Implementation plan: `MixedBufferMultiVaultStablePool_IMPLEMENTATION_AND_TEST_PLAN.md` (**written** — status PLANNED).
- Do **not** implement production code until an explicit “implement now” instruction (or proceed phase-by-phase from the plan).
- **Parallel product forever** vs Stale (`commonBufferMultiVault` stable), weighted CommonBuffer, MultiPair, MixedLeg, and single SE buffer (behavioral reference only; do not subclass those packages).

**Created:** 2026-07-25  
**Requirements locked:** 2026-07-25  
**Package path:** `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/`

**Product name:** `MixedBufferMultiVaultStablePool`  
**Aliases:** “mixed stale”, “stable mixed buffer multi-vault”, “stable unpaired + common buffer”

---

## Living progress log

> Newest first. Decisions go into tables, not only the log.

| Date | Note |
|------|------|
| 2026-07-25 | **Implementation plan written** (`MixedBufferMultiVaultStablePool_IMPLEMENTATION_AND_TEST_PLAN.md`). Phases 0–8; config matrix C0–C4 / R0–R4; porting checklist from Stale + weighted CommonBuffer; adversarial P0 catalog. Status PLANNED. |
| 2026-07-25 | **Product LOCKED.** Session decisions: **U ≥ 1** (no U=0 — covered by Stale); **exactly one** `bufferToken`; **N ∈ [1,3]** SE vaults; **T = U + 1 + N ≤ 5** (StableMath `MAX_STABLE_TOKENS`); name `MixedBufferMultiVaultStablePool`; path `pools/stable/mixedBufferMultiVault/`. M1–M30 locked. |
| 2026-07-25 | Design session after Stale PRD lock: need DETF / reserve scenarios where ≥1 pool token is **not** accepted by composed SE vaults. |

---

## Purpose

Expose a **Balancer V3 stable market** over **3..5 tokens**:

1. **One or more unpaired tokens** (`unpairedToken[j]`) that are **never** buffered into any SE vault (physical Balancer balances only; optional rate providers),  
2. **Exactly one common bufferable token** (`bufferToken`) consolidated into one or more Standard Exchange vaults that process that token, and  
3. **One to three vault share tokens** (`vaultShare[i]`), one per configured SE vault,

…so a user can compose **like-kind** assets on a **StableMath** curve while still buffering free common token into the SE vault with the **lowest liquidity** (and pulling from the vault with the **highest liquidity** when buffer is needed), **even when some pool legs cannot enter those vaults**.

Primary goals:

1. **Stable like-kind composition** — unpaired legs + vault shares of the same underlying family (rate-normalized when RPs are set) price with **StableMath**, not fixed weights.  
2. **Unbuffered legs required** — support DETF / multi-asset reserves where ≥1 token is **not** accepted by the composed SE vaults (e.g. DETF self-leg / free rate asset that SE vaults do not list).  
3. **One-to-many buffer** — same gap as Stale / weighted CommonBuffer: one `bufferToken` → N SE vaults (here N ≤ 3), subject to StableMath token cap.  
4. **Always “shallowest / deepest” fan-out** — deposit into lowest derived share depth; redeem from highest. Independent of which share token appeared on the trade.  
5. **Optional rate providers** — user may attach an `IRateProvider` to any subset of unpaired and/or share legs; package never auto-deploys defaults.  
6. **Deploy-time vault capability** — every vault must accept and produce `bufferToken` (`IStandardVault` at deploy).  
7. **Composable with IndexedEx** — Crane Diamond, vault-registry DFPkg, production-first tests, opaque SE surfaces.

Non-goals (v1): U = 0 (use **Stale** / `CommonBufferMultiVaultStablePool`); weighted / Gyro curves; routing weight vector; dynamic amp updates; DETF seigniorage / bond / claim product logic; subclassing Stale or weighted CommonBuffer; multiple distinct buffer tokens; N > 3; T > 5.

---

## Gap analysis (why a new package)

| Existing product | Curve | Token layout | Same token → many vaults? | Unpaired legs? | Near-parity pricing? |
|------------------|-------|--------------|---------------------------|----------------|----------------------|
| Single SE Buffer | ConstProd / weighted peers | 1 buffer + 1 share | No | No | N/A |
| MultiPair | Weighted | P distinct buffers + P shares | **No** | No | No |
| MixedLeg | Weighted | Unpaired + 1:1 pairs | **No** | Yes | No |
| CommonBuffer **Weighted** | Weighted | U unpaired + 1 buffer + N shares (T≤8) | **Yes** | Yes (U≥0) | **No** (basket weights) |
| **Stale** (`commonBufferMultiVault` stable) | Stable | 1 buffer + N≤3 shares (T≤4) | **Yes** | **No** | Yes |
| Crane Stable DFPkg | Stable | Arbitrary 2–5 tokens | N/A | N/A | Yes, no SE buffer hooks |
| **This product** | **Stable** | **U≥1 unpaired + 1 buffer + N≤3 shares (T≤5)** | **Yes** | **Yes (U≥1)** | **Yes** (like-kind after rates) |

**Why not Stale alone?** Stale **forbids** unpaired legs (S1). DETF / reserve compositions that hold a non-vault-accepted token need physical free legs on the same stable market.

**Why not weighted CommonBuffer alone?** Weighted prices a **portfolio**. When unpaired + buffer + shares are **like-kind** after rate scaling, **StableMath + amp** is the correct market.

**Why not plain Stable DFPkg?** No virtual buffer, no SE pre-seat / reconcile, no fan-out into shallowest vault.

**Why not U = 0 here?** Covered by **Stale**. This package **requires** at least one unpaired token so product surfaces stay distinct and deploy validation is simple.

---

## Behavioral references

| Reference | Take | Do not copy blindly |
|-----------|------|---------------------|
| **Stale** (`CommonBufferMultiVaultStablePool`) | Virtual buffer; hook share deltas; always-route by \(d_i\); S11 walk; S9 accept+produce; fixed amp; LP rules; DFPkg inventory; optional user-only share RPs | No unpaired; T≤4 only; TokenKind without Unpaired |
| **Weighted CommonBuffer** | Unpaired physical legs + optional unpaired RPs; token-kind resolution; uniqueness vs buffer/shares; layout \(U+1+N\) | WeightedMath; \(d_i/w_i\); weights; U=0 allowed; T≤8; N≤7 |
| **MixedLeg** | Unpaired physical legs; mixed token kinds | 1:1 buffer↔vault pairs; weighted; no multi-vault fan-out on one buffer |
| **Crane BalancerV3StablePool** | StableMath `onSwap` / invariant / `computeBalance`; amp bounds | No hooks; no SE; physical balances only; gradual amp surface |
| **Balancer StableMath** | Amp precision; **MAX_STABLE_TOKENS = 5**; invariant ratio bounds 60%/500% | — |

---

## Product shape

### Roles

| Role | Name | Meaning |
|------|------|---------|
| Unpaired token | `unpairedToken[j]` | Pool token **never** SE-buffered; math = physical Vault live scaled18 balance |
| Common bufferable token | `bufferToken` | **Single** ERC-20 deposited into / redeemed from **any** configured vault; Balancer pool token |
| Standard Exchange vault | `standardExchangeVault[i]` | Vault `i` that **accepts and produces** `bufferToken` |
| Vault share | `vaultShare[i]` / `shareToken[i]` | Share of vault `i` (often `address(vault)`); Balancer pool token |
| Rate provider (unpaired) | `unpairedRateProvider[j]` | **Optional (user-supplied only).** `address(0)` ⇒ `STANDARD`; non-zero ⇒ `WITH_RATE` + that provider |
| Rate provider (share) | `vaultShareRateProvider[i]` | **Optional (user-supplied only).** Same STANDARD / WITH_RATE rule as unpaired |
| Virtual common buffer | `virtualBuffer` | Scaled18 math depth for the buffer leg (physical eventual-zero at rest) |
| Share reshuffle offset | `hookShareDelta[i]` | Signed raw offset for derived share depth of vault `i` |
| Amplification | `amplificationParameter` | StableMath amp; **fixed at deploy** in v1 |

**Forbidden:** product tickers as role names; `WETH` as a role name unless WETH-specific code.

### Token layout (**LOCKED — M1**)

\[
T = U + 1 + N
\quad\text{with}\quad
U \ge 1,\quad
1 \le N \le 3,\quad
3 \le T \le 5
\]

| Symbol | Meaning | Bounds |
|--------|---------|--------|
| `U` | Unpaired (non-buffered) token count | **≥ 1**; max = \(4 - N\) so \(T \le 5\) |
| `1` | Exactly **one** `bufferToken` | always |
| `N` | SE vault / share count | **1 … 3** |

**Hard caps (derived):**

| N | Max U | Max T |
|---|-------|-------|
| 1 | 3 | 5 |
| 2 | 2 | 5 |
| 3 | 1 | 5 |

Examples:

| Config | U | N | T | Meaning |
|--------|---|---|---|---------|
| Minimal mixed | 1 | 1 | 3 | One free leg + buffer + one SE share |
| Dual vault + free | 1 | 2 | 4 | DETF-ish: free + buffer + two vaults |
| Max vaults + free | 1 | 3 | 5 | One free + buffer + three SE shares |
| Dual free + dual vault | 2 | 2 | 5 | Two free + buffer + two vaults |
| Max free + single vault | 3 | 1 | 5 | Three free + buffer + one SE share |
| **Forbidden** U=0 | 0 | * | * | Use **Stale** |
| **Forbidden** T=6 | e.g. 2 | 3 | 6 | Exceeds StableMath |

**No deploy-time weights.** Exactly **one** buffer token. **U = 0 is invalid** for this package.

### Token kinds and math balances

| Kind | TokenType | Math balance | SE I/O |
|------|-----------|--------------|--------|
| **Unpaired** | `STANDARD` if RP `0`; `WITH_RATE` if user set RP | Physical `balancesLiveScaled18` | **None** |
| **Buffer** | `STANDARD` (never RP) | **`virtualBuffer`** | Fan-out deposit / fan-in redeem via routing |
| **Share** | `STANDARD` if RP `0`; `WITH_RATE` if user set RP | Derived via `hookShareDelta[i]` | Inventory for pre-seat / receives deposit mint |

**Uniqueness (all addresses after sort):**

1. All pool token addresses **unique**.  
2. All `vaultShare[i]` / vaults **distinct**.  
3. Unpaired tokens **≠** `bufferToken` and **≠** any `vaultShare[i]`.  
4. Exactly **one** buffer token in the pool.  
5. **U ≥ 1** and **N ≥ 1**.

### What users see

- A normal stable pool: one or more free assets + one cash/buffer asset + one or more vault share assets of the same underlying family.  
- Full-graph swaps among all registered tokens with StableMath pricing (amp-controlled flatness near peg).  
- Under the hood: physical `bufferToken` is pushed into the **shallowest** SE vault and pulled from the **deepest**, independent of which share token appeared on the trade; unpaired legs never enter SE vaults.

---

## Buffer routing policy (**LOCKED**)

### Principle (M2, M3)

Whenever hooks must move `bufferToken` through an SE vault:

| Direction | Rule | Formula |
|-----------|------|---------|
| **Deposit** (buffer → vault) | Vault with **lowest liquidity** | \( i^\* = \arg\min_i d_i \) |
| **Redeem** (vault → buffer) | Vault with **highest liquidity** | \( i^\dagger = \arg\max_i d_i \) |

Where \( d_i \) = **derived share depth** of vault share leg `i` (scaled18, rate-aware — same construction as Stale / weighted CommonBuffer `_derivedShareDepth`).

**No weight vector.** Routing is pure depth (same as Stale).

**Tie-break (M12):** among vaults with equal \(d_i\), prefer **lowest vault index \(i\)**.

### Always route — not implied-leg (M3)

The share token on the swap **does not** select the vault.

| Operation | Vault used |
|-----------|------------|
| Swap `bufferToken` → anything (including `vaultShare[k]` or unpaired) | After swap, deposit received buffer into **\(i^\*\)** (shallowest) |
| Swap anything → `bufferToken` (including from `vaultShare[k]` or unpaired) | Before/as needed, pre-seat buffer by redeeming from **\(i^\dagger\)** (deepest) |
| Swap share ↔ share, unpaired ↔ share, unpaired ↔ unpaired | No buffer SE I/O unless residual policy says otherwise |
| Unbalanced LP **add** of buffer | Deposit into **\(i^\*\)** (walk next on fail) |
| Unbalanced LP **remove** of buffer only | **Not allowed (M16)** — proportional remove or share/unpaired-side unbalanced only |
| Proportional LP | Scale `virtualBuffer` + all `hookShareDelta[i]`; unpaired physical scaled by Balancer; no fan-out choice |

**Product consequence (explicit):** a user swap **buffer → vaultShare[k]** may still cause the hook to deposit into vault \(i^\* \neq k\). That is intentional continuous rebalancing toward **equalized liquidity** across vault share legs (in rate-aware depth). Math balances after the swap follow StableMath; inventory reshuffle adjusts physical shares/`hookShareDelta` so **derived** depths stay consistent with the AMM vector.

### Deploy-time vault capability (M9)

> Every configured `standardExchangeVault[i]` **MUST** be able to **accept** `bufferToken` (buffer → shares) **and produce** `bufferToken` (shares → buffer).

Unpaired tokens are **not** required to be accepted by any vault.

**Verification at deploy / `postDeploy` / registration (required):**

- Read vault configuration via **`IStandardVault`** (token list / `vaultConfig` includes `bufferToken`).  
- Reject deploy if `bufferToken` is not listed for any configured vault.  
- Runtime still uses **`IStandardExchange`** `exchangeIn` / `exchangeOut` (and previews) for actual I/O.

### Runtime I/O failure — walk next vault (M11)

**Policy:** build the ordered candidate list by depth rank + M12 ties, then:

1. Try vault at rank 0 (\(i^\*\) or \(i^\dagger\)).  
2. On failure (preview fail, redeem/deposit fail, share side exhausted for that vault), try **next** vault in that ranking.  
3. If **all** vaults fail → revert (`AllVaultsExhausted`, `PreSeatRedemptionFailed`, `PostSwapDepositFailed`, or package equivalents).

### SE I/O policy

Per **selected** vault (after walk):

- Pre-seat: **preview-aligned** shares → buffer.  
- Reconcile: **best-effort full deposit** of received buffer.  
- Failures after full walk: peer-style errors as above.

### Pre-seat quote (**Stable-specific**)

Pre-seat amount must be computed with **`StableMath`** (current amp, math balance vector, pool static fee) — **not** `WeightedMath`. Copy-paste of weighted CommonBuffer quote helpers is a defect.

---

## Equivalence thesis

### Formula equivalence (v1 bar — M25)

Given a math balance vector and amp, `onSwap` / invariant / `computeBalance` match Balancer **`StableMath`** with tokens:

\[
\{\texttt{unpaired}[0..U),\ \texttt{bufferToken},\ \texttt{vaultShare}[0..N)\}
\]

(in Balancer address-sorted order).

### Why full trade-history parity is harder

Always-route means hooks **rebalance which vault holds cash** even when the user traded a different share. A reference stable pool that only moves physical balances on the two trade legs will **not** mirror post-hook share inventory. Therefore:

| Test bar | v1 intent |
|----------|-----------|
| **Formula equivalence** | **Required:** math engine matches StableMath on `_mathBalances` |
| **Routing unit tests** | **Required:** ranking by \(d_i\); M12 ties; M11 walk order |
| **Conservation** | **Required:** no free BPT; virtual ≥ 0; **eventual-zero** physical buffer (M14); **unpaired not virtualized** |
| **Full freeze comparative vs naive reference** | **Not** required for histories that fan-out differently than trade legs |

**Economic non-equivalence:** buffer consolidates into vaults → different share NAV once underlyings/strategies diverge; rate providers express exchange rate, not full credit risk. Unpaired legs remain pure AMM inventory.

---

## Locked decisions (normative)

| # | Topic | Decision | Status |
|---|-------|----------|--------|
| M1 | Token layout | \( T = U + 1 + N \), \( U \ge 1 \), \( 1 \le N \le 3 \), \( 3 \le T \le 5 \); **exactly one** buffer | **LOCKED** |
| M2 | Routing metric | Score \( d_i \) only (derived depth); deposit \(\arg\min\); redeem \(\arg\max\); **no weights** | **LOCKED** |
| M3 | When to route | **Always** shallowest deposit / deepest redeem — not implied by swap share leg | **LOCKED** |
| M4 | Rate providers | **No default RPs.** For each unpaired and each share: `address(0)` ⇒ STANDARD; non-zero ⇒ WITH_RATE + user RP. Package **must not** auto-deploy `StandardExchangeRateProvider` when arg is zero | **LOCKED** |
| M5 | Product name / path | `MixedBufferMultiVaultStablePool` under `pools/stable/mixedBufferMultiVault/` | **LOCKED** |
| M6 | Curve | `StableMath` only (not Weighted / Gyro) | **LOCKED** |
| M7 | Amp at deploy | Fixed `amplificationParameter` in `PkgArgs` within StableMath min/max | **LOCKED** |
| M8 | Amp after deploy | **No** instance amp updates in v1 (no owner amp surface) | **LOCKED** |
| M9 | Deploy vault capability | Each vault accepts+produces `bufferToken`; verify via `IStandardVault`. Unpaired not required on vaults | **LOCKED** |
| M10 | SE I/O | Opaque `IStandardExchange` exchangeIn/Out + previews | **LOCKED** |
| M11 | Runtime I/O fail | Walk next vault by depth order; revert only if all fail | **LOCKED** |
| M12 | Tie-break | Equal \(d_i\): **lowest vault index** | **LOCKED** |
| M13 | Virtual accounting | `virtualBuffer` + `hookShareDelta[i]`; buffer math = virtual; share math = derived; **unpaired math = physical** | **LOCKED** |
| M14 | Physical residual | **Eventual-zero** physical buffer at rest after success | **LOCKED** |
| M15 | Init seed | **All legs non-zero** (every unpaired + buffer + every share); `virtualBuffer` = buffer scaled18 seed; `hookShareDelta[i]=0` | **LOCKED** |
| M16 | LP | Proportional + unbalanced **adds**; **no** buffer-only unbalanced **remove** | **LOCKED** |
| M17 | Swap surface | Full stable graph among all T tokens | **LOCKED** |
| M18 | Fee | Pool-wide static only; no dynamic fee hook | **LOCKED** |
| M19 | Pool + hooks | Hook facet on pool Diamond; `hooksContract == pool` | **LOCKED** |
| M20 | Deploy path | CREATE3 facets; Vault Registry DFPkg; `PkgInit`/`PkgArgs` on **interface** | **LOCKED** |
| M21 | Buffer TokenType | Always STANDARD (never RP) | **LOCKED** |
| M22 | Extra vault underlyings | Allowed if M9 holds | **LOCKED** |
| M23 | DETF/bond/claim | **Out of scope** as product logic (pool may sit under a DETF reserve) | **LOCKED** |
| M24 | Router | No special router; normal Balancer V3 pool surface | **LOCKED** |
| M25 | v1 test bar | Formula + routing + conservation; not naive full-history comparative | **LOCKED** |
| M26 | Parallel forever | Fresh package; no subclass of Stale / weighted CommonBuffer / MultiPair / MixedLeg | **LOCKED** |
| M27 | Token cap | Package enforces \(T \le 5\) / \(N \le 3\) / \(U \ge 1\); respect StableMath `MAX_STABLE_TOKENS = 5` | **LOCKED** |
| M28 | U = 0 | **Invalid** — use `CommonBufferMultiVaultStablePool` (Stale) | **LOCKED** |
| M29 | Unpaired semantics | Physical only; optional RP; never SE-buffered; ≠ buffer ≠ shares | **LOCKED** |
| M30 | Buffer count | **Exactly one** `bufferToken` — no multi-buffer, no buffer-optional mode | **LOCKED** |

---

## Open questions

**None for v1 product requirements.** Implementation-only choices (storage layout, exact error names, gas micro-opts) belong in the implementation plan.

Minor defaults already chosen:

| ID | Default |
|----|---------|
| O1 N=1 | Product-supported (bridge + production) with U≥1 |
| O2 Gradual amp | v1 no |
| O3 U=0 | Rejected; Stale owns that surface |
| O4 Max free | \(U_{\max} = 4 - N\) so T≤5 |

---

## Scope

### In scope (v1)

- Path: `…/stable/mixedBufferMultiVault/`
- Layout \(T = U + 1 + N \in [3,5]\), \(U \ge 1\), \(N \in [1,3]\), exactly one buffer
- StableMath + fixed deploy amp
- Unpaired physical legs + optional unpaired RPs
- Always-route shallowest / deepest + M12 ties + M11 walk
- Deploy-time `IStandardVault` accept+produce check for buffer
- LP: proportional; unbalanced **add** (incl. buffer-only add → \(i^\*\)); **no** buffer-only unbalanced remove
- Hook-driven pre-seat / reconcile; Diamond peer facet set; DFPkg + FactoryService + registry
- Optional per-share and per-unpaired user rate providers
- Production-first tests per M25/M14

### Out of scope (v1)

- Weighted / Gyro math  
- **U = 0** (use Stale)  
- Routing weights / \(d_i/w_i\)  
- Multiple buffer tokens / zero buffer tokens  
- N > 3  
- T > 5 (StableMath hard limit)  
- Implied-leg routing  
- Buffer-only unbalanced **remove**  
- Instance amp updates  
- Auto-deploy default SE RPs  
- DETF seigniorage / bond / claim product surfaces  
- Special-purpose router  
- Subclassing Stale or weighted CommonBuffer concrete targets  

---

## Architecture (target)

```
                    Balancer V3 Vault (singleton)
                     | swap / add / remove / rates
                     v
     MixedBufferMultiVaultStablePool Diamond  (== hooksContract)
       • StableMath(amp) over: unpaired physical + virtualBuffer + derived shares
       • IHooks on THIS proxy
       • CUSTOM liquidity (NotHookCaller)
       • Repo: U, N, unpaired[U], buffer, vaults[N], shares[N], RPs, amp,
               virtualBuffer, hookShareDelta[N]
                     |                              |
                     | rates (optional)             | exchangeIn / exchangeOut
                     v                              v
              rate providers                 standardExchangeVault[i*]
                                             (shallowest / deepest)

  Deploy: for each vault, IStandardVault config includes bufferToken.
  Unpaired tokens are never required on vault configs.
```

### Facet / package inventory (sketch)

| Piece | Role |
|-------|------|
| `IMixedBufferMultiVaultStablePool` | Errors, views, `TokenKind` (Unpaired \| Buffer \| Share), routing views, amp views |
| `…Repo` | Storage (U, N, unpaired, layout + amp + virtuals) |
| `…Common` | Math balances, derived depth, depth ranking, BV3 round-trips |
| `…Target` | StableMath `onSwap` / invariant / computeBalance |
| `…HookTarget` | Register, init, pre-seat via \(i^\dagger\), reconcile via \(i^\*\), LP |
| `…LiquidityTarget` | CUSTOM, hook-only |
| Facets / DFPkg / FactoryService | Peer pattern; Stable invariant ratio bounds |

---

## Registration (target)

### TokenConfig (after address sort)

- Each unpaired: STANDARD if RP `0`; else WITH_RATE + user RP (**no** auto default)  
- `bufferToken`: STANDARD (never RP)  
- Each `vaultShare[i]`: STANDARD if `vaultShareRateProviders[i] == 0`; else WITH_RATE + user RP (**no** auto default)

### LiquidityManagement (working)

- CUSTOM add/remove true; donation true; unbalanced allowed  

### HookFlags (working — CommonBuffer / Stale spirit)

beforeInit, before/after swap, before/after addLiquidity, after removeLiquidity; no dynamic fee; no hook-adjusted amounts.

### `onRegister` / deploy checks (minimum)

- `tokenConfig.length == U + 1 + N`  
- `U ≥ 1`, `1 ≤ N ≤ 3`, `3 ≤ T ≤ 5`  
- Exactly one buffer; N shares; U unpaired  
- Uniqueness (M1 uniqueness rules)  
- **M9:** each vault’s `IStandardVault` config lists `bufferToken`  
- Amp in range  
- `hooksContract == pool`  
- Invariant ratio bounds = StableMath (60% / 500%)

---

## Math and state (design sketch)

### Storage (conceptual)

```text
U, N, tokenCount
for j in 0..U-1:
  unpairedToken[j], unpairedRateProvider[j], unpairedIndex[j]
bufferToken, bufferIndex
for i in 0..N-1:
  vaultShare[i], standardExchangeVault[i], rateProvider[i], shareIndex[i]
amplification (startValue, endValue, startTime, endTime)  // v1: start == end
expectedFactory

virtualBuffer
hookShareDelta[0..N-1]
pendingPreSeat...
```

**Amp storage** lives in **this package’s Repo** (namespaced slot), not shared Crane `BalancerV3StablePoolRepo` or Stale repo slots.

### Balance vector

```text
unpaired[j]     -> balancesLiveScaled18[unpairedIndex[j]]
buffer          -> virtualBuffer
vaultShare[i]   -> derivedShareDepth(i, balancesLiveScaled18)
```

### Ranking

```text
deposit order: ascending d_i, then ascending i
redeem  order: descending d_i, then ascending i on ties
```

### Init (M15)

- All legs non-zero seed (every unpaired + buffer + every share)  
- `virtualBuffer =` buffer scaled18 seed  
- `hookShareDelta[i] = 0`  
- Amp fixed from args  

### LP

- Proportional: scale virtual + all deltas (unpaired physical scaled by Balancer)  
- Unbalanced **add** of buffer: deposit via \(i^\*\) with M11 walk  
- Unbalanced **remove** of buffer only: **revert** (M16)  
- Share-side / unpaired unbalanced: allowed as Balancer + peers permit  
- Donation: no free virtual  

### Security

- CUSTOM only `router == address(this)`  
- Hooks only from Vault, `pool == this`  
- Public views: `shallowestVault()`, `deepestVault()`, `derivedShareDepth(i)`, unpaired / buffer / share resolution  

---

## Deploy args (sketch)

```solidity
// On interface IMixedBufferMultiVaultStablePool — not on the contract body
struct PkgArgs {
    // Unpaired (non-buffered); length == unpairedCount; unpairedCount >= 1
    IERC20[] unpairedTokens;
    // length == unpairedCount.
    // address(0) => TokenType.STANDARD
    // non-zero => TokenType.WITH_RATE + that provider (user-supplied only).
    IRateProvider[] unpairedRateProviders;

    IERC20 bufferToken; // exactly one; always STANDARD

    uint8 vaultCount; // 1..3
    IStandardExchange[] standardExchangeVaults;
    // length == vaultCount.
    // address(0) => TokenType.STANDARD
    // non-zero => TokenType.WITH_RATE + that provider (user-supplied only).
    IRateProvider[] vaultShareRateProviders;

    uint256 amplificationParameter; // raw amp in StableMath range
    // NO weights
}
```

Validation (minimum):

- `unpairedCount = unpairedTokens.length ≥ 1`  
- `1 ≤ vaultCount ≤ 3`  
- `3 ≤ unpairedCount + 1 + vaultCount ≤ 5`  
- Array lengths match  
- Distinct vaults/shares; unique final token addresses  
- Unpaired ≠ buffer ≠ any share  
- **M9:** for each vault, `IStandardVault` shows `bufferToken` as accepted/produced  
- Amp in `[MIN_AMP, MAX_AMP]`  

---

## Testing expectations (when implementing)

| Suite | Intent |
|-------|--------|
| Registration | U≥1, N=1..3, T∈[3,5]; reject U=0; reject T>5; reject vault missing buffer in `IStandardVault` |
| Routing unit | \(d_i\) ordering; M12 ties (lowest index); M11 walk order |
| Swap buffer↔share | Fan-out may differ from share leg `k`; math + conservation |
| Swap unpaired↔buffer | Unpaired physical; buffer SE path when buffer involved |
| Swap unpaired↔share / unpaired↔unpaired | No buffer SE I/O on pure non-buffer paths |
| Swap share↔share | No buffer SE I/O on pure share path |
| N=1 + U=1 | Minimal mixed under Stable |
| Max T configs | e.g. U=1 N=3; U=2 N=2; U=3 N=1 |
| Formula equivalence | StableMath on math vector (M25) |
| LP proportional / buffer **add** | Virtual + deltas; shallowest deposit + walk |
| LP buffer-only **remove** | Must revert (M16) |
| Walk-on-fail | Top vault fails → second succeeds when inventory allows |
| Amp bounds | Reject invalid amp |
| RP | Zero ⇒ STANDARD; non-zero ⇒ WITH_RATE; never auto-deploy (unpaired + shares) |
| Adversarial | CUSTOM drain; virtual underflow; residual; reentrancy |
| Invariants | virtual ≥ 0; eventual-zero physical buffer (M14); unpaired never virtualized |

**Forbidden:** mock SUT pool/pkg/manager/registry; mock SE vaults for lifecycle.

---

## Risks and sharp edges

| Risk | Mitigation |
|------|------------|
| Always-route surprises traders (swap B shares, inventory moves on A) | Document in NatSpec/UI; views for shallowest/deepest |
| Comparative tests vs naive reference fail | M25: formula + routing + conservation only |
| Depegged share/unpaired with no RP or stale RP | Document RP responsibility; optional WITH_RATE |
| Amp too high masks divergence | Ops guidance; product docs |
| Pre-seat quote wrong if WeightedMath copied | Explicit StableMath-only quote path |
| Confusion with Stale | Docs: Stale = no unpaired; this = U≥1 required |
| Confusion with weighted CommonBuffer | Docs: weighted = basket; this = like-kind stable + free legs |
| StableMath T=5 tight for DETF | Document max configs; refuse T>5 at deploy |
| Like-kind violation (unpaired not near peg) | Product guidance: RPs + amp selection; else use weighted |
| Gas: score N + multi SE tries | N≤3; bound walk to N |

---

## Comparison table

| Dimension | Stale | Weighted CommonBuffer | **This product** |
|-----------|-------|----------------------|------------------|
| Curve | StableMath + amp | WeightedMath + weights | **StableMath + amp** |
| Buffer tokens | 1 shared | 1 shared | **1 shared (exactly)** |
| Unpaired | **None** | U ≥ 0, T≤8 | **U ≥ 1**, T≤5 |
| Vaults | N ≤ 3 | N ≤ 7 (+ unpaired) | **N ≤ 3** |
| Fan-out score | \(d_i\) | \(d_i/w_i\) | **\(d_i\)** |
| Pre-seat quote | StableMath | WeightedMath | **StableMath** |
| Rate providers | Optional user-only (shares) | Optional (unpaired + shares) | **Optional (unpaired + shares)** |
| Token cap | T≤4 (package) | T≤8 (Vault) | **T≤5 (StableMath)** |
| Invariant bounds | Stable 60%/500% | Weighted standard | **Stable 60%/500%** |

---

## Suggested next design / build sessions

1. ~~Lock product requirements~~ — **done** (M1–M30).  
2. ~~Write implementation plan~~ — **done** (`MixedBufferMultiVaultStablePool_IMPLEMENTATION_AND_TEST_PLAN.md`).  
3. Implement phases 1–8 (or explicit “implement now”).

---

## Document control

| Item | Value |
|------|--------|
| PRD path | `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePool_PRD.md` |
| Implementation plan | `./MixedBufferMultiVaultStablePool_IMPLEMENTATION_AND_TEST_PLAN.md` |
| Behavioral references | Stale (`commonBufferMultiVault` stable), weighted `commonBufferMultiVault`, MixedLeg, single SE buffer, Crane pool-stable |

---

## Appendix A — Decision restatement (plain language)

| You said | PRD encoding |
|----------|----------------|
| U = 0 not allowed; covered by existing Stale | **M28** |
| Exactly one buffer token | **M30**, **M1** |
| 1–3 SE vaults; T max 5 | **M1**, **M27** |
| Name MixedBufferMultiVaultStablePool; path mixedBufferMultiVault | **M5** |
| Stable curve with free legs | **M6**, **M29** |
| Buffer into vault with lowest liquidity | **M2** pure \(d_i\) |
| Always rebalance shallowest/deepest | **M3** |
| Optional RPs for unpaired and shares | **M4** |
| Fixed amp, no post-deploy amp admin | **M7–M8** |

## Appendix B — Worked example

Unpaired token X; vaults A/B/C with depths \(d=(50,30,40)\).  
Layout: U=1, N=3, T=5.

- Shallowest (deposit) order: **B → C → A**.  
- Deepest (redeem) order: **A → C → B**.  

User swaps **buffer → share C**:

1. StableMath reduces C’s math balance, increases virtual buffer.  
2. Hook deposits physical buffer into **B** first.  
3. If B fails, try **C**, then **A**.  

User swaps **share C → buffer**:

1. Hook pre-seats from **A** first (not necessarily C).  
2. If A cannot redeem, try **C**, then **B**.  

User swaps **X ↔ share C** (unpaired ↔ share):

1. StableMath moves physical X and derived share balances.  
2. **No** buffer SE I/O on this pure non-buffer path.  

User swaps **X → buffer**:

1. Hook pre-seats from deepest vault as needed.  
2. User receives buffer; residual physical buffer still eventual-zero after reconcile path when applicable.

## Appendix C — Glossary

| Term | Meaning |
|------|---------|
| Mixed stale | Informal name for this stable unpaired + common-buffer product |
| Unpaired / unbuffered | Non-buffered pool token; physical math only; never SE I/O |
| Common buffer | Single bufferable pool token shared across N vaults |
| Shallowest | Lowest \(d_i\) among share legs (deposit target) |
| Deepest | Highest \(d_i\) (redeem source) |
| Walk | Try next vault in ranked order after I/O failure (M11) |
| Accept + produce | Vault can exchange buffer↔shares; deploy-checked via `IStandardVault` |
| Always-route | Fan-out ignores which share token was on the user trade |
| Eventual-zero | No residual physical buffer in the pool at rest after success (M14) |
| Stale | Sister product: buffer + N shares only (no unpaired) |

## Appendix D — Token budget cheat sheet

| U | N | T | Valid? |
|---|---|---|--------|
| 0 | 1–3 | 2–4 | **No** → use Stale |
| 1 | 1 | 3 | Yes |
| 1 | 2 | 4 | Yes |
| 1 | 3 | 5 | Yes |
| 2 | 1 | 4 | Yes |
| 2 | 2 | 5 | Yes |
| 2 | 3 | 6 | **No** (StableMath) |
| 3 | 1 | 5 | Yes |
| 3 | 2 | 6 | **No** |
| 4 | 1 | 6 | **No** |

## Appendix E — Acceptance (PRD complete)

Product requirements are **LOCKED**. Proceed to implementation plan; do not reopen M1–M30 without log note.
