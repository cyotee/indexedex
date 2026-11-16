# Product Requirements Document (PRD)

## Title

**CommonBufferMultiVaultWeightedPool** — one common `bufferToken` → many Standard Exchange vaults, optional unpaired legs, fixed-weight Balancer V3 market

## Status

**LOCKED (product requirements) — 2026-07-20**

Product decisions **L1–L28** are locked. Do **not** reopen without an explicit PRD revision + log note.

- Next deliverable: `CommonBufferMultiVaultWeightedPool_IMPLEMENTATION_AND_TEST_PLAN.md`.
- Do **not** implement production code until the implementation plan exists (or an explicit “implement now” instruction).
- **Parallel product forever** vs single SE buffer, MultiPair, and MixedLeg (behavioral reference only; do not subclass those packages).

**Created:** 2026-07-20  
**Requirements locked:** 2026-07-20  
**Package path:** `contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/`

**Product name:** `CommonBufferMultiVaultWeightedPool`  
**Aliases:** “one-to-many buffer”, “common buffer multi-vault”, “fan-out buffer pool”

---

## Living progress log

> Newest first. Decisions go into tables, not only the log.

| Date | Note |
|------|------|
| 2026-07-20 | **L17 revised:** no auto-deploy of default SE rate providers. Share (and unpaired) RPs are **optional** via deploy args only: `address(0)` ⇒ `STANDARD`; non-zero ⇒ `WITH_RATE` + user RP. Plan + PRD updated. |
| 2026-07-20 | Implementation plan written: `CommonBufferMultiVaultWeightedPool_IMPLEMENTATION_AND_TEST_PLAN.md` (phases 0–8; status NOT STARTED). |
| 2026-07-20 | **Product LOCKED.** Remaining opens resolved: **O2** all-legs non-zero init; **O3-runtime** walk next vault by score; **O7** no buffer-only unbalanced remove; **O8** eventual-zero physical buffer; **O13** tie-break = larger weight then lowest index; **O14** always buffer + N≥1; **O10** name confirmed; **O6/O9/O12** drafts accepted. Status → LOCKED L1–L29. |
| 2026-07-20 | **Session locks:** **O1** always most underweight/excess; **O4** \(d_i/w_i\); **O5** N=1; unpaired legs; deploy accept+produce via `IStandardVault`. |
| 2026-07-20 | Initial draft. Gap: MultiPair/MixedLeg require **distinct** `bufferToken` per pair. |

---

## Purpose

Expose a **Balancer V3 weighted market** over up to **8 tokens** that may include:

1. **Exactly one common bufferable token** (`bufferToken`) that is consolidated into one or more Standard Exchange vaults,  
2. **One or more vault share tokens** (`vaultShare[i]`), one per configured SE vault that processes that same `bufferToken`, and  
3. **Zero or more unpaired tokens** — ordinary pool legs that are **not** buffered into any SE vault (physical Balancer balances only; optional rate providers),

…so a user can **compose several vaults on the same underlying**, mix in **other assets that stay unbuffered**, and price the basket with **weighted** (not stable) math.

Primary goals:

1. **Fill the one-to-many gap** — MultiPair/MixedLeg forbid the same `bufferToken` with two vaults. This product makes that legal and intentional.
2. **Support full 2..8 token weighted markets** — buffer + vault shares + optional unpaired legs under Balancer’s 8-token cap.
3. **Weighted composition, not stable** — vault shares of the same underlying are not assumed 1:1 like-kind.
4. **Always “most needed” fan-out** — whenever buffer must enter an SE vault, deposit into the vault that is **most underweight** by share-depth/weight; whenever buffer must leave an SE vault, redeem from the vault that is **most excess** (see § Buffer routing policy). **Does not** force the vault implied by the swap’s share token.
5. **Deploy-time vault capability** — every configured vault must be able to **accept and produce** `bufferToken` (verified via `IStandardVault` at deploy).
6. **Composable with IndexedEx** — Crane Diamond, vault-registry DFPkg, production-first tests, opaque SE surfaces.

Non-goals (v1): DETF seigniorage / bond / claim; stable or Gyro curves; dynamic governance reweight; subclassing MultiPair/MixedLeg; multiple distinct buffer tokens (that remains MultiPair); claiming full economic identity once vaults grow from buffer deposits.

---

## Gap analysis (why a new package)

| Existing product | Token layout | Uniqueness | Same token → many vaults? | Unpaired legs? |
|------------------|--------------|------------|---------------------------|----------------|
| Single SE Buffer | 1 buffer + 1 share | One pair | No | No |
| MultiPair | `P` buffers + `P` shares | Distinct buffers + shares | **No** | No |
| MixedLeg | `U` unpaired + `P` 1:1 pairs | Distinct addresses | **No** (pairs still 1:1) | Yes |
| **This product** | **`U` unpaired + 1 shared buffer + `N` shares** | One buffer; distinct shares/vaults; unpaired ≠ buffer/shares | **Yes** | **Yes** |

**Why not Stable?** Different SE vaults on the same underlying can diverge in NAV/risk; product is a **weighted basket**, not a peg curve.

**Why not MixedLeg alone?** MixedLeg pairs are still **one buffer address per vault** with **distinct** buffer tokens. It cannot express “one WETH leg → many SE vaults.”

---

## Behavioral references

| Reference | Take | Do not copy blindly |
|-----------|------|---------------------|
| **Single SE Buffer** | Virtual buffer + hook share delta; pre-seat / reconcile; hook-as-pool; CUSTOM + `NotHookCaller`; Vault-sourced rates | 2 tokens only; single vault; effective weights |
| **MultiPair** | Fixed weights; full graph; derived share depth; LP scaling; DFPkg inventory; freeze equivalence mindset | Distinct buffer per pair; `T=2P`; no unpaired |
| **MixedLeg** | Unpaired physical legs + optional unpaired RPs; token-kind resolution; uniqueness vs pairs | 1:1 buffer↔vault pairs; no multi-vault fan-out on one buffer |
| **Balancer V3 WeightedPool** | Reference AMM for formula equivalence | Physical balances; no SE hooks |

---

## Product shape

### Roles

| Role | Name | Meaning |
|------|------|---------|
| Common bufferable token | `bufferToken` | **Single** ERC-20 that may be deposited into / redeemed from **any** configured vault; Balancer pool token |
| Unpaired token | `unpairedToken[j]` | Pool token that is **never** SE-buffered; math = physical Vault live scaled balance |
| Standard Exchange vault | `standardExchangeVault[i]` | Vault `i` that **accepts and produces** `bufferToken` |
| Vault share | `vaultShare[i]` | Share of vault `i` (often `address(vault)`); Balancer pool token |
| Rate provider (share) | `vaultShareRateProvider[i]` | **Optional (user-supplied only).** `address(0)` ⇒ `STANDARD` (no RP, **no** package-deployed default SE RP). Non-zero ⇒ `WITH_RATE` + that provider (caller responsible for correct pricing, typically share in `bufferToken` terms) |
| Rate provider (unpaired) | `unpairedRateProvider[j]` | **Optional.** `address(0)` ⇒ `STANDARD`, else `WITH_RATE` |
| Virtual common buffer | `virtualBuffer` | Scaled18 math depth for the buffer leg (physical eventual-zero at rest) |
| Share reshuffle offset | `hookShareDelta[i]` | Signed raw offset for derived share depth of vault `i` |

**Forbidden:** product tickers as role names; `WETH` as a role name unless WETH-specific code.

### Token layout (**session-aligned**)

\[
T = U + 1 + N
\quad\text{with}\quad
2 \le T \le 8
\]

| Symbol | Meaning | Bounds |
|--------|---------|--------|
| `U` | Unpaired (non-buffered) token count | `0 … 6` (subject to `T`) |
| `1` | Exactly **one** `bufferToken` | always present when product is used for buffering |
| `N` | SE vault / share count | **`1 … 7`** (subject to `T`); **`N = 1` allowed** |

Examples under `T ≤ 8`:

| Config | U | N | T | Meaning |
|--------|---|---|---|---------|
| Minimal buffer | 0 | 1 | 2 | Twin of single-buffer shape (fixed weights) |
| Multi-vault only | 0 | 3 | 4 | One buffer + three vault shares |
| Mixed market | 2 | 2 | 5 | Two free tokens + buffer + two vaults |
| Max tokens | 0 | 7 | 8 | One buffer + seven vaults |
| Max mixed | 5 | 2 | 8 | Five unpaired + buffer + two vaults |

**Token kinds and math balances:**

| Kind | TokenType | Math balance | SE I/O |
|------|-----------|--------------|--------|
| **Unpaired** | `STANDARD` if RP `0`; `WITH_RATE` if RP set | Physical `balancesLiveScaled18` | None |
| **Buffer** | `STANDARD` | **`virtualBuffer`** | Fan-out deposit / fan-in redeem via routing |
| **Share** | `STANDARD` if RP `0`; `WITH_RATE` if user set RP | Derived via `hookShareDelta[i]` | Inventory for pre-seat / receives deposit mint |

**Uniqueness (all addresses after sort):**

1. All pool token addresses **unique**.  
2. All `vaultShare[i]` / vaults **distinct**.  
3. Unpaired tokens **≠** `bufferToken` and **≠** any `vaultShare[i]`.  
4. Exactly **one** buffer token in the pool.

**Weights:** fixed deploy-time length `T`, sum `1e18`, each ≥ min weight (~`1e16`).

### What users see

- A normal weighted pool: optional free assets + one cash/buffer asset + one or more vault share assets.  
- Full-graph swaps among all registered tokens.  
- Under the hood: physical `bufferToken` is pushed into / pulled from SE vaults chosen by **most underweight / most excess**, independent of which share token appeared on the trade.

---

## Buffer routing policy (**locked direction**)

### Principle (LOCKED — O1, O4)

Whenever hooks must move `bufferToken` through an SE vault:

| Direction | Rule | Formula |
|-----------|------|---------|
| **Deposit** (buffer → vault) | Vault that is **most needed** = **most underweight** | \( i^\* = \arg\min_i (d_i / w_i) \) |
| **Redeem** (vault → buffer) | Vault that is **most excess** | \( i^\dagger = \arg\max_i (d_i / w_i) \) |

Where:

- \( d_i \) = **derived share depth** of vault share leg `i` (scaled18, rate-aware — same construction as MultiPair `_derivedShareDepth`)  
- \( w_i \) = fixed weight of `vaultShare[i]`  

**Tie-break (LOCKED — L20 / O13):** among vaults with equal \(d_i/w_i\), prefer **larger share weight \(w_i\)**, then **lowest vault index \(i\)**.

### Always route — not implied-leg (LOCKED — O1)

The share token on the swap **does not** select the vault.

| Operation | Vault used |
|-----------|------------|
| Swap `bufferToken` → anything (including `vaultShare[k]` or unpaired) | After swap, deposit received buffer into **\(i^\*\)** (most underweight) |
| Swap anything → `bufferToken` (including from `vaultShare[k]` or unpaired) | Before/as needed, pre-seat buffer by redeeming from **\(i^\dagger\)** (most excess) |
| Swap share ↔ share, unpaired ↔ share, unpaired ↔ unpaired | No buffer SE I/O unless residual policy says otherwise |
| Unbalanced LP **add** of buffer | Deposit into **\(i^\*\)** (walk next on fail) |
| Unbalanced LP **remove** of buffer only | **Not allowed (L23)** — proportional remove or share-side unbalanced only |
| Proportional LP | Scale `virtualBuffer` + all `hookShareDelta[i]`; no fan-out choice |

**Product consequence (explicit):** a user swap **buffer → vaultShare[k]** may still cause the hook to deposit into vault \(i^\* \neq k\). That is intentional continuous rebalancing toward weights. Math balances after the swap follow WeightedMath; inventory reshuffle adjusts physical shares/`hookShareDelta` so **derived** depths stay consistent with the AMM vector.

### Deploy-time vault capability (LOCKED — user O3 intent)

This is **not** “what if inventory is empty.” It is **capability**:

> Every configured `standardExchangeVault[i]` **MUST** be able to **accept** `bufferToken` (buffer → shares) **and produce** `bufferToken` (shares → buffer).

**Verification at deploy / `postDeploy` / registration (required):**

- Read vault configuration via **`IStandardVault`** (e.g. `vaultConfig().tokens` includes `bufferToken`, or the project’s equivalent token list surface on the vault).  
- Reject deploy if `bufferToken` is not listed as a vault token for any configured vault.  
- Runtime still uses **`IStandardExchange`** `exchangeIn` / `exchangeOut` (and previews) for actual I/O — deploy check is membership / config, not a live mint test.

### Runtime I/O failure — walk next vault (LOCKED — L21 / O3-runtime)

Deploy guarantees vaults *can* process `bufferToken`. At runtime, pool share inventory or preview may still fail for the top-ranked vault.

**Policy:** build the ordered candidate list by the same score as deposit/redeem, apply **L20 tie-break**, then:

1. Try vault at rank 0 (\(i^\*\) or \(i^\dagger\)).  
2. On failure (preview fail, redeem/deposit fail, share side exhausted for that vault), try **next** vault in that ranking.  
3. If **all** vaults fail → revert with peer-style error (`PreSeatRedemptionFailed`, `PostSwapDepositFailed`, or multi-vault exhausted equivalent).

Applies to **both** deposit (most-needed order) and redeem/pre-seat (most-excess order).

### SE I/O policy (LOCKED — L22)

Per **selected** vault (after walk):

- Pre-seat: **preview-aligned** shares → buffer.  
- Reconcile: **best-effort full deposit** of received buffer.  
- Failures after full walk: peer-style errors as above.

---

## Equivalence thesis (updated for always-route)

### Formula equivalence (v1 bar — LOCKED L24 / O9)

Given a math balance vector, `onSwap` / invariant / `computeBalance` match Balancer **`WeightedMath`** with fixed weights — same as a normal weighted pool with tokens:

\[
\{\texttt{unpaired}[0..U),\ \texttt{bufferToken},\ \texttt{vaultShare}[0..N)\}
\]

(in Balancer address-sorted order).

### Why full trade-history parity is harder

Always-route means hooks **rebalance which vault holds cash** even when the user traded a different share. A reference weighted pool that only moves physical balances on the two trade legs will **not** mirror post-hook share inventory. Therefore:

| Test bar | v1 intent |
|----------|-----------|
| **Formula equivalence** | **Required:** math engine matches WeightedMath on `_mathBalances` |
| **Routing unit tests** | **Required:** ranking by \(d_i/w_i\); L20 ties; L21 walk order |
| **Conservation** | **Required:** no free BPT; virtual ≥ 0; **eventual-zero** physical buffer (L25); unpaired not virtualized |
| **Full freeze comparative vs naive reference** | **Not** required for histories that fan-out differently than trade legs |
| **Optional:** co-sim reference that applies same routing off-chain | Nice-to-have later |

**Economic non-equivalence:** buffer consolidates into vaults → different share NAV once underlyings trade (L19).

---

## Locked decisions (normative)

| # | Topic | Decision | Status |
|---|-------|----------|--------|
| L1 | Parallel forever | Fresh package under `commonBufferMultiVault/`; no subclass of peers | **LOCKED** |
| L2 | Curve | Fixed-weight `WeightedMath` only (not Stable) | **LOCKED** |
| L3 | Token layout | \( T = U + 1 + N \), \( 2 \le T \le 8 \): unpaired + **one** buffer + N vault shares | **LOCKED** |
| L4 | Vault count | \( 1 \le N \le 7 \) subject to T; **N=1 allowed** | **LOCKED** |
| L5 | Unpaired | **In scope**; physical balances; optional RP (`0` ⇒ STANDARD) | **LOCKED** |
| L6 | Routing when | **Always** most underweight deposit / most excess redeem — **not** implied by swap share leg | **LOCKED** |
| L7 | Need metric | \( i^\* = \arg\min_i d_i/w_i \), \( i^\dagger = \arg\max_i d_i/w_i \) (rate-aware derived depth) | **LOCKED** |
| L8 | Deploy vault capability | Each vault **accepts and produces** `bufferToken`; verify at deploy via **`IStandardVault`** token list / `vaultConfig` | **LOCKED** |
| L9 | Weights | Fixed deploy-time; sum `1e18`; min ≥ ~1% | **LOCKED** |
| L10 | Fee | Pool-wide static only | **LOCKED** |
| L11 | Swap surface | Full weighted graph | **LOCKED** |
| L12 | LP base | Proportional + unbalanced **adds** and share-side unbalanced allowed | **LOCKED** |
| L13 | Pool + hooks | Hook facet on pool Diamond; `hooksContract == pool` | **LOCKED** |
| L14 | Deploy path | CREATE3 facets; Vault Registry DFPkg; `PkgInit`/`PkgArgs` on interface | **LOCKED** |
| L15 | Opacity | Production SE I/O via exchange interfaces; config via `IStandardVault` as needed | **LOCKED** |
| L16 | DETF/bond/claim | Out of scope | **LOCKED** |
| L17 | Share rate providers | **No default SE RP.** User configures per vault share via deploy args only: `address(0)` ⇒ `STANDARD` (no RP deployed); non-zero ⇒ `WITH_RATE` + that address. Package **must not** auto-deploy `StandardExchangeRateProvider` when arg is zero | **LOCKED** (revised 2026-07-20) |
| L18 | Product name | **`CommonBufferMultiVaultWeightedPool`** | **LOCKED** |
| L19 | Economic vs AMM | Full economic parity not a goal when underlyings trade | **LOCKED** |
| L20 | Tie-break | Among equal \(d_i/w_i\): **larger \(w_i\)**, then **lowest index \(i\)** | **LOCKED** |
| L21 | Runtime I/O fail | **Walk next vault** by score order (deposit and redeem); revert only if all fail | **LOCKED** |
| L22 | SE I/O shape | Preview-aligned pre-seat; best-effort full deposit; per selected vault after walk | **LOCKED** |
| L23 | Buffer-only remove | **Disallowed** — no unbalanced remove of buffer only; proportional or share-side removes | **LOCKED** |
| L24 | v1 test bar | Formula + routing + conservation; not naive full-history comparative | **LOCKED** |
| L25 | Physical buffer residual | **Eventual-zero** at rest after successful ops (document ≤ few-wei only if BV3 forces) | **LOCKED** |
| L26 | Init seed | **All legs non-zero**; `virtualBuffer =` buffer scaled18 seed; `hookShareDelta[i]=0` | **LOCKED** |
| L27 | Extra vault underlyings | **Allowed** if L8 holds (vault may hold tokens beyond `bufferToken`) | **LOCKED** |
| L28 | Router | **No** special router; normal Balancer V3 pool surface | **LOCKED** |
| L29 | Instance shape | Always exactly one `bufferToken` and \(N \ge 1\); **no** unpaired-only / N=0 mode | **LOCKED** |

---

## Open questions

**None for v1 product requirements.** Implementation-only choices (storage layout, exact error names, gas micro-opts) belong in the implementation plan.

---

## Scope

### In scope (v1)

- Path: `…/weighted/commonBufferMultiVault/`
- Layout \(T = U + 1 + N \in [2,8]\), \(N \ge 1\), one shared buffer, optional unpaired (L3–L5, L29)
- Always-route most underweight / most excess + L20 ties + L21 walk (L6–L7, L20–L21)
- Deploy-time `IStandardVault` accept+produce check (L8)
- LP: proportional; unbalanced **add** (incl. buffer-only add → \(i^\*\)); **no** buffer-only unbalanced remove (L23)
- Hook-driven pre-seat / reconcile; Diamond peer facet set; DFPkg + FactoryService + registry
- Production-first tests per L24–L25: registration, validation, routing unit + walk, swaps, LP, conservation, eventual-zero, adversarial CUSTOM

### Out of scope (v1)

- Stable / Gyro math  
- Multiple buffer tokens (MultiPair)  
- `N = 0` unpaired-only or buffer-without-vaults (L29)  
- Implied-leg routing  
- Buffer-only unbalanced **remove** (L23)  
- DETF seigniorage / bond / claim  
- Dynamic reweight  
- Special-purpose router (L28)  
- Subclassing MultiPair/MixedLeg concrete targets  

---

## Architecture (target)

```
                    Balancer V3 Vault (singleton)
                     | swap / add / remove / rates
                     v
     CommonBufferMultiVaultWeightedPool Diamond  (== hooksContract)
       • WeightedMath over: unpaired physical + virtualBuffer + derived shares
       • IHooks on THIS proxy
       • CUSTOM liquidity (NotHookCaller)
       • Repo: U, N, unpaired[], buffer, vaults[N], shares[N], RPs, weights[T],
               virtualBuffer, hookShareDelta[N]
                     |                              |
                     | rates                        | exchangeIn / exchangeOut
                     v                              v
              rate providers                 standardExchangeVault[i*]
                                             (most needed / most excess)

  Deploy: for each vault, IStandardVault config includes bufferToken (accept+produce).
```

### Facet / package inventory (sketch)

| Piece | Role |
|-------|------|
| `ICommonBufferMultiVaultWeightedPool` | Errors, views, `TokenKind`, routing views, Pkg structs |
| `…Repo` | Storage |
| `…Common` | Math balances, derived depth, **need scores**, BV3 round-trips |
| `…Target` | WeightedMath `onSwap` / invariant / computeBalance |
| `…HookTarget` | Register, init, pre-seat via \(i^\dagger\), reconcile via \(i^\*\), LP |
| `…LiquidityTarget` | CUSTOM, hook-only |
| Facets / DFPkg / FactoryService | Peer pattern |

---

## Registration (target)

### TokenConfig (after address sort)

- Each unpaired: STANDARD or WITH_RATE per optional user RP  
- `bufferToken`: STANDARD (never RP)  
- Each `vaultShare[i]`: STANDARD if `vaultShareRateProviders[i] == 0`; else WITH_RATE + user RP (**no** auto default)  

### LiquidityManagement (working)

- CUSTOM add/remove true; donation true; unbalanced allowed  

### HookFlags (working — MultiPair/MixedLeg spirit)

beforeInit, before/after swap, before/after addLiquidity, after removeLiquidity; no dynamic fee; no hook-adjusted amounts.

### `onRegister` / deploy checks (minimum)

- `tokenConfig.length == U + 1 + N`  
- Exactly one buffer; N shares; U unpaired  
- Uniqueness  
- **L8:** each vault’s `IStandardVault` config lists `bufferToken` (accept+produce capability)  
- Weights sum/min  
- `hooksContract == pool`  

---

## Math and state (design sketch)

### Storage (conceptual)

```text
U, N
unpairedToken[j], unpairedRateProvider[j], unpairedIndex[j]
bufferToken, bufferIndex
for i in 0..N-1:
  vaultShare[i], standardExchangeVault[i], rateProvider[i], shareIndex[i]
weights[0..T-1]
expectedFactory

virtualBuffer
hookShareDelta[0..N-1]
pendingPreSeat...
```

### Balance vector

```text
unpaired[j]     -> balancesLiveScaled18[unpairedIndex[j]]
buffer          -> virtualBuffer
vaultShare[i]   -> derivedShareDepth(i, balancesLiveScaled18)
```

### Init (L26)

- All legs non-zero seed (unpaired + buffer + every share)  
- `virtualBuffer =` buffer scaled18 seed  
- `hookShareDelta[i] = 0`  

### LP

- Proportional: scale virtual + all deltas (unpaired physical scaled by Balancer)  
- Unbalanced **add** of buffer: deposit via \(i^\*\) with L21 walk  
- Unbalanced **remove** of buffer only: **revert** (L23)  
- Share-side / unpaired unbalanced: allowed as Balancer + peers permit  
- Donation: no free virtual  

### Security

- CUSTOM only `router == address(this)`  
- Hooks only from Vault, `pool == this`  
- Public views: `mostNeededVault()`, `mostExcessVault()`, per-vault `depthPerWeight(i)`  

---

## Deploy args (sketch)

```solidity
// On interface ICommonBufferMultiVaultWeightedPoolPkg — not on the contract body
struct PkgArgs {
    // Unpaired (non-buffered)
    uint8 unpairedCount;
    IERC20[] unpairedTokens;
    IRateProvider[] unpairedRateProviders; // 0 => STANDARD

    // Common buffer + vaults (one-to-many)
    IERC20 bufferToken;
    uint8 vaultCount; // 1..7, with unpairedCount + 1 + vaultCount in [2, 8]
    IStandardExchange[] standardExchangeVaults;
    // vaultShareRateProviders: length == vaultCount.
    // address(0) => TokenType.STANDARD (no rate provider; package does NOT deploy a default SE RP).
    // non-zero => TokenType.WITH_RATE + that provider (user-supplied only).
    IRateProvider[] vaultShareRateProviders;

    // length == unpairedCount + 1 + vaultCount; Balancer address-sorted order
    uint256[] weights;
}
```

Validation (minimum):

- `2 ≤ unpairedCount + 1 + vaultCount ≤ 8`  
- `vaultCount ≥ 1`  
- Array lengths match  
- Distinct vaults/shares; unique final token addresses  
- Unpaired ≠ buffer ≠ shares  
- **L8:** for each vault, `IStandardVault` shows `bufferToken` as accepted/produced token  
- Weights sum `1e18`, each ≥ min  

---

## Testing expectations (when implementing)

| Suite | Intent |
|-------|--------|
| Registration | Layout U/N/T; reject bad counts; reject vault missing buffer in `IStandardVault` config |
| Routing unit | \(d_i/w_i\) ordering; L20 ties (weight then index); L21 walk order |
| Swap buffer↔share | Fan-out may differ from share leg `k`; math + conservation |
| Swap unpaired↔buffer / unpaired↔share | Unpaired physical; buffer routing when buffer involved |
| N=1, U=0 | Bridge case |
| U>0, N>1 | Mixed layout smoke |
| Formula equivalence | WeightedMath on math vector (L24) |
| LP proportional / buffer **add** | Virtual + deltas; most-needed deposit + walk |
| LP buffer-only **remove** | Must revert (L23) |
| Walk-on-fail | Top vault fails redeem → second most-excess succeeds (when inventory allows) |
| Adversarial | CUSTOM drain; virtual underflow |
| Invariants | virtual ≥ 0; eventual-zero physical buffer (L25); unpaired never “virtualized” |

**Forbidden:** mock SUT pool/pkg/manager/registry; mock SE vaults for lifecycle.

---

## Risks and sharp edges

| Risk | Mitigation |
|------|------------|
| Always-route surprises traders (swap B shares, inventory moves on A) | Document in NatSpec/UI; views for mostNeeded/mostExcess |
| Comparative tests vs naive reference fail | L24: formula + routing + conservation only |
| Gas: score N + possibly multiple SE tries | N≤7; cheap metric; bound walk to N |
| Ties | L20: larger weight, then lowest index |
| Walk burns gas on failing vaults | Order by score; stop on first success |
| Confusion with MixedLeg | Docs: MixedLeg = many 1:1 pairs; this = one buffer → many vaults + unpaired |
| Stack-too-deep | Extract helpers; viaIR if needed |

---

## Comparison table

| Dimension | MultiPair | MixedLeg | **This product** |
|-----------|-----------|----------|------------------|
| Buffer tokens | P distinct | P distinct | **1 shared** |
| Vaults per buffer | 1 | 1 | **N (one-to-many)** |
| Unpaired | No | Yes | **Yes** |
| T | 2P | U+2P | **U+1+N** |
| Fan-out | N/A | N/A | **Always most underweight** |
| Deploy vault check | buffer in vault | buffer in vault | **Accept + produce via IStandardVault** |

---

## Suggested next design sessions

1. ~~Lock product requirements~~ — **done** (L1–L29).  
2. ~~Write implementation plan~~ — **done** (`CommonBufferMultiVaultWeightedPool_IMPLEMENTATION_AND_TEST_PLAN.md`).  
3. Review/revise plan if needed; then implement phases 0–8 (or explicit “implement now”).

---

## Document control

| Item | Value |
|------|--------|
| PRD path | `contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPool_PRD.md` |
| Implementation plan | `./CommonBufferMultiVaultWeightedPool_IMPLEMENTATION_AND_TEST_PLAN.md` |
| Behavioral references | single SE buffer, multiPairBuffer, mixedLegBuffer |

---

## Appendix A — Decision restatement (plain language)

| You said | PRD encoding |
|----------|----------------|
| Pool may use whichever vault is most underweight | **L6:** always deposit/redeem by score, not by swap share leg |
| Most needed = lowest share-depth by weight | **L7** |
| One vault OK; up to 8 tokens; non-buffered tokens too | **L3–L5, L29** |
| Vaults accept+produce buffer; deploy check via IStandardVault | **L8** |
| All legs non-zero at init | **L26** |
| On I/O fail, walk next vault by score | **L21** |
| No buffer-only unbalanced remove | **L23** |
| Eventual-zero physical buffer | **L25** |
| Tie: larger weight, then lowest index | **L20** |
| Name `CommonBufferMultiVaultWeightedPool` | **L18** |
| O6/O9/O12 drafts | **L27, L24, L28** |
| No default SE RP for vaults; user configures or not | **L17** (revised): `address(0)` ⇒ STANDARD; non-zero user RP only |

## Appendix B — Worked example (always-route + walk)

Weights: buffer 40%, shares A/B/C 20% each. Depths \(d=(50,30,40)\) → scores \(d/w = (250,150,200)\).

- Most needed order: **B → C → A**. Most excess order: **A → C → B**.  

User swaps **buffer → share C** (buys C):

1. WeightedMath reduces C’s math balance, increases virtual buffer.  
2. Hook deposits physical buffer into **B** first (most needed).  
3. If B deposit fails, try **C**, then **A** (L21).  

User swaps **share C → buffer**:

1. Hook pre-seats from **A** first (most excess), not necessarily C.  
2. If A cannot redeem, try **C**, then **B**.  

## Appendix C — Glossary

| Term | Meaning |
|------|---------|
| Unpaired | Non-buffered pool token; physical only |
| Common buffer | Single bufferable pool token shared across N vaults |
| Most underweight | Lowest \(d_i/w_i\) among share legs |
| Most excess | Highest \(d_i/w_i\) |
| Walk | Try next vault in ranked order after I/O failure (L21) |
| Accept + produce | Vault can exchange buffer↔shares; deploy-checked via `IStandardVault` |
| Always-route | Fan-out ignores which share token was on the user trade |
| Eventual-zero | No residual physical buffer in the pool at rest after success (L25) |

## Appendix D — Acceptance (PRD complete)

Product requirements are **LOCKED**. Proceed to implementation plan; do not reopen L1–L29 without log note.
