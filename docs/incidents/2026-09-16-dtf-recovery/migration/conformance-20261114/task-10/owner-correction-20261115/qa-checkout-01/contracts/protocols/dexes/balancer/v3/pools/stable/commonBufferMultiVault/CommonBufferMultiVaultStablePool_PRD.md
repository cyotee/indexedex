# Product Requirements Document (PRD)

## Title

**CommonBufferMultiVaultStablePool** — one common `bufferToken` → up to 3 Standard Exchange vaults, Balancer V3 **Stable** market (“Stale” pool)

## Status

**LOCKED (product requirements) — 2026-07-25**

Product decisions **S1–S27** are locked. Do **not** reopen without an explicit PRD revision + log note.

- Next deliverable: `CommonBufferMultiVaultStablePool_IMPLEMENTATION_AND_TEST_PLAN.md` (may ship with this PRD).
- Do **not** implement production code until the implementation plan exists (or an explicit “implement now” instruction).
- **Parallel product forever** vs weighted CommonBuffer, MultiPair, MixedLeg, and single SE buffer (behavioral reference only; do not subclass those packages).

**Created:** 2026-07-25  
**Requirements locked:** 2026-07-25  
**Package path:** `contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/`

**Product name:** `CommonBufferMultiVaultStablePool`  
**Aliases:** “Stale pool”, “stable common buffer multi-vault”, “stable one-to-many buffer”

---

## Living progress log

> Newest first. Decisions go into tables, not only the log.

| Date | Note |
|------|------|
| 2026-07-25 | **Product LOCKED.** Session decisions: buffer + N shares only (N≤3); routing by **lowest/highest derived depth** (no weights); always-route shallowest/deepest; optional user-only share RPs; name `CommonBufferMultiVaultStablePool`. S1–S27 locked. |
| 2026-07-25 | Design session from weighted CommonBuffer + Crane Stable pool references. User corrected “by weight” → simple lowest liquidity. |

---

## Purpose

Expose a **Balancer V3 stable market** over **2..4 tokens**:

1. **Exactly one common bufferable token** (`bufferToken`) consolidated into one or more Standard Exchange vaults that process that token, and  
2. **One to three vault share tokens** (`vaultShare[i]`), one per configured SE vault,

…so a user can **compose several SE vaults that share a common asset** into a **near-parity** curve that **buffers free common token into the SE vault with the lowest liquidity** (and pulls from the vault with the highest liquidity when buffer is needed).

Primary goals:

1. **Stable like-kind composition** — vault shares of the same underlying (rate-normalized when RPs are set) price with **StableMath**, not fixed weights.  
2. **One-to-many buffer** — same gap as weighted CommonBuffer: one `bufferToken` → N SE vaults (here N ≤ 3).  
3. **Always “shallowest / deepest” fan-out** — deposit into lowest derived share depth; redeem from highest. Independent of which share token appeared on the trade.  
4. **Optional rate providers** — user may attach an SE rate provider (or any `IRateProvider`) to any subset of share legs; package never auto-deploys defaults.  
5. **Deploy-time vault capability** — every vault must accept and produce `bufferToken` (`IStandardVault` at deploy).  
6. **Composable with IndexedEx** — Crane Diamond, vault-registry DFPkg, production-first tests, opaque SE surfaces.

Non-goals (v1): unpaired free tokens; weighted / Gyro curves; routing weight vector; dynamic amp updates; DETF seigniorage / bond / claim; subclassing weighted CommonBuffer; multiple distinct buffer tokens; N > 3.

---

## Gap analysis (why a new package)

| Existing product | Curve | Token layout | Same token → many vaults? | Near-parity pricing? |
|------------------|-------|--------------|---------------------------|----------------------|
| Single SE Buffer | ConstProd / weighted peers | 1 buffer + 1 share | No | N/A |
| MultiPair | Weighted | P distinct buffers + P shares | **No** | No |
| MixedLeg | Weighted | Unpaired + 1:1 pairs | **No** | No |
| CommonBuffer **Weighted** | Weighted | U unpaired + 1 buffer + N shares | **Yes** | **No** (basket weights) |
| Crane Stable DFPkg | Stable | Arbitrary 2–5 tokens | N/A | Yes, no SE buffer hooks |
| **This product** | **Stable** | **1 buffer + N≤3 shares** | **Yes** | **Yes** (like-kind after rates) |

**Why not weighted CommonBuffer alone?** Weighted CommonBuffer intentionally prices vault shares as a **portfolio**. When vaults share one underlying and should trade near peg after rate scaling, **StableMath + amp** is the correct market.

**Why not plain Stable DFPkg?** No virtual buffer, no SE pre-seat / reconcile, no fan-out into shallowest vault.

---

## Behavioral references

| Reference | Take | Do not copy blindly |
|-----------|------|---------------------|
| **CommonBufferMultiVaultWeightedPool** | Virtual buffer; hook share deltas; always-route walk; deploy accept+produce; LP rules; DFPkg inventory; optional user-only RPs | WeightedMath; \(d_i/w_i\); weights array; unpaired legs; N≤7 |
| **Single SE Buffer** | SE I/O try/catch; CUSTOM; eventual-zero physical buffer | 2 tokens only; const-prod/weighted target |
| **Crane BalancerV3StablePool** | StableMath `onSwap` / invariant / `computeBalance`; amp bounds | No hooks; no SE; physical balances only; gradual amp surface |
| **Balancer StableMath** | Amp precision; MAX 5 tokens; invariant ratio bounds 60%/500% | — |

---

## Product shape

### Roles

| Role | Name | Meaning |
|------|------|---------|
| Common bufferable token | `bufferToken` | **Single** ERC-20 deposited into / redeemed from **any** configured vault; Balancer pool token |
| Standard Exchange vault | `standardExchangeVault[i]` | Vault `i` that **accepts and produces** `bufferToken` |
| Vault share | `vaultShare[i]` / `shareToken[i]` | Share of vault `i` (often `address(vault)`); Balancer pool token |
| Rate provider (share) | `vaultShareRateProvider[i]` | **Optional (user-supplied only).** `address(0)` ⇒ `STANDARD`; non-zero ⇒ `WITH_RATE` + that provider |
| Virtual common buffer | `virtualBuffer` | Scaled18 math depth for the buffer leg (physical eventual-zero at rest) |
| Share reshuffle offset | `hookShareDelta[i]` | Signed raw offset for derived share depth of vault `i` |
| Amplification | `amplificationParameter` | StableMath amp; **fixed at deploy** in v1 |

**Forbidden:** product tickers as role names; `WETH` as a role name unless WETH-specific code.

### Token layout (**LOCKED — S1**)

\[
T = 1 + N
\quad\text{with}\quad
1 \le N \le 3
\quad\Rightarrow\quad
2 \le T \le 4
\]

| Symbol | Meaning | Bounds |
|--------|---------|--------|
| `1` | Exactly **one** `bufferToken` | always |
| `N` | SE vault / share count | **1 … 3** |

Examples:

| Config | N | T | Meaning |
|--------|---|---|---------|
| Minimal / bridge | 1 | 2 | Single vault under Stable curve |
| Dual vault | 2 | 3 | Buffer + two SE shares |
| Max v1 | 3 | 4 | Buffer + three SE shares |

**No unpaired legs in v1.** No deploy-time **weights**.

### Token kinds and math balances

| Kind | TokenType | Math balance | SE I/O |
|------|-----------|--------------|--------|
| **Buffer** | `STANDARD` (never RP) | **`virtualBuffer`** | Fan-out deposit / fan-in redeem via routing |
| **Share** | `STANDARD` if RP `0`; `WITH_RATE` if user set RP | Derived via `hookShareDelta[i]` | Inventory for pre-seat / receives deposit mint |

**Uniqueness (all addresses after sort):**

1. All pool token addresses **unique**.  
2. All `vaultShare[i]` / vaults **distinct**.  
3. Exactly **one** buffer token in the pool.

### What users see

- A normal stable pool: one cash/buffer asset + one or more vault share assets of the same underlying family.  
- Full-graph swaps among all registered tokens with StableMath pricing (amp-controlled flatness near peg).  
- Under the hood: physical `bufferToken` is pushed into the **shallowest** SE vault and pulled from the **deepest**, independent of which share token appeared on the trade.

---

## Buffer routing policy (**LOCKED**)

### Principle (S2, S3)

Whenever hooks must move `bufferToken` through an SE vault:

| Direction | Rule | Formula |
|-----------|------|---------|
| **Deposit** (buffer → vault) | Vault with **lowest liquidity** | \( i^\* = \arg\min_i d_i \) |
| **Redeem** (vault → buffer) | Vault with **highest liquidity** | \( i^\dagger = \arg\max_i d_i \) |

Where \( d_i \) = **derived share depth** of vault share leg `i` (scaled18, rate-aware — same construction as weighted CommonBuffer `_derivedShareDepth`).

**No weight vector.** Earlier “by weight” language was **withdrawn**; routing is pure depth.

**Tie-break (S12):** among vaults with equal \(d_i\), prefer **lowest vault index \(i\)**.

### Always route — not implied-leg (S3)

The share token on the swap **does not** select the vault.

| Operation | Vault used |
|-----------|------------|
| Swap `bufferToken` → anything (including `vaultShare[k]`) | After swap, deposit received buffer into **\(i^\*\)** (shallowest) |
| Swap anything → `bufferToken` | Before/as needed, pre-seat buffer by redeeming from **\(i^\dagger\)** (deepest) |
| Swap share ↔ share | No buffer SE I/O unless residual policy says otherwise |
| Unbalanced LP **add** of buffer | Deposit into **\(i^\*\)** (walk next on fail) |
| Unbalanced LP **remove** of buffer only | **Not allowed (S16)** — proportional remove or share-side unbalanced only |
| Proportional LP | Scale `virtualBuffer` + all `hookShareDelta[i]`; no fan-out choice |

**Product consequence (explicit):** a user swap **buffer → vaultShare[k]** may still cause the hook to deposit into vault \(i^\* \neq k\). That is intentional continuous rebalancing toward **equalized liquidity** across vault share legs (in rate-aware depth). Math balances after the swap follow StableMath; inventory reshuffle adjusts physical shares/`hookShareDelta` so **derived** depths stay consistent with the AMM vector.

### Deploy-time vault capability (S9)

> Every configured `standardExchangeVault[i]` **MUST** be able to **accept** `bufferToken` (buffer → shares) **and produce** `bufferToken` (shares → buffer).

**Verification at deploy / `postDeploy` / registration (required):**

- Read vault configuration via **`IStandardVault`** (token list / `vaultConfig` includes `bufferToken`).  
- Reject deploy if `bufferToken` is not listed for any configured vault.  
- Runtime still uses **`IStandardExchange`** `exchangeIn` / `exchangeOut` (and previews) for actual I/O.

### Runtime I/O failure — walk next vault (S11)

**Policy:** build the ordered candidate list by depth rank + S12 ties, then:

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

### Formula equivalence (v1 bar — S25)

Given a math balance vector and amp, `onSwap` / invariant / `computeBalance` match Balancer **`StableMath`** with tokens:

\[
\{\texttt{bufferToken},\ \texttt{vaultShare}[0..N)\}
\]

(in Balancer address-sorted order).

### Why full trade-history parity is harder

Always-route means hooks **rebalance which vault holds cash** even when the user traded a different share. A reference stable pool that only moves physical balances on the two trade legs will **not** mirror post-hook share inventory. Therefore:

| Test bar | v1 intent |
|----------|-----------|
| **Formula equivalence** | **Required:** math engine matches StableMath on `_mathBalances` |
| **Routing unit tests** | **Required:** ranking by \(d_i\); S12 ties; S11 walk order |
| **Conservation** | **Required:** no free BPT; virtual ≥ 0; **eventual-zero** physical buffer (S14) |
| **Full freeze comparative vs naive reference** | **Not** required for histories that fan-out differently than trade legs |

**Economic non-equivalence:** buffer consolidates into vaults → different share NAV once underlyings/strategies diverge; rate providers express exchange rate, not full credit risk.

---

## Locked decisions (normative)

| # | Topic | Decision | Status |
|---|-------|----------|--------|
| S1 | Token layout | \( T = 1 + N \), \( 1 \le N \le 3 \), \( 2 \le T \le 4 \); **no unpaired** | **LOCKED** |
| S2 | Routing metric | Score \( d_i \) only (derived depth); deposit \(\arg\min\); redeem \(\arg\max\); **no weights** | **LOCKED** |
| S3 | When to route | **Always** shallowest deposit / deepest redeem — not implied by swap share leg | **LOCKED** |
| S4 | Share rate providers | **No default SE RP.** `address(0)` ⇒ STANDARD; non-zero ⇒ WITH_RATE + user RP. Package **must not** auto-deploy `StandardExchangeRateProvider` when arg is zero | **LOCKED** |
| S5 | Product name / path | `CommonBufferMultiVaultStablePool` under `pools/stable/commonBufferMultiVault/` | **LOCKED** |
| S6 | Curve | `StableMath` only (not Weighted / Gyro) | **LOCKED** |
| S7 | Amp at deploy | Fixed `amplificationParameter` in `PkgArgs` within StableMath min/max | **LOCKED** |
| S8 | Amp after deploy | **No** instance amp updates in v1 (no owner amp surface) | **LOCKED** |
| S9 | Deploy vault capability | Each vault accepts+produces `bufferToken`; verify via `IStandardVault` | **LOCKED** |
| S10 | SE I/O | Opaque `IStandardExchange` exchangeIn/Out + previews | **LOCKED** |
| S11 | Runtime I/O fail | Walk next vault by depth order; revert only if all fail | **LOCKED** |
| S12 | Tie-break | Equal \(d_i\): **lowest vault index** | **LOCKED** |
| S13 | Virtual accounting | `virtualBuffer` + `hookShareDelta[i]`; buffer math = virtual; share math = derived | **LOCKED** |
| S14 | Physical residual | **Eventual-zero** physical buffer at rest after success | **LOCKED** |
| S15 | Init seed | **All legs non-zero**; `virtualBuffer` = buffer scaled18 seed; `hookShareDelta[i]=0` | **LOCKED** |
| S16 | LP | Proportional + unbalanced **adds**; **no** buffer-only unbalanced **remove** | **LOCKED** |
| S17 | Swap surface | Full stable graph among all T tokens | **LOCKED** |
| S18 | Fee | Pool-wide static only; no dynamic fee hook | **LOCKED** |
| S19 | Pool + hooks | Hook facet on pool Diamond; `hooksContract == pool` | **LOCKED** |
| S20 | Deploy path | CREATE3 facets; Vault Registry DFPkg; `PkgInit`/`PkgArgs` on **interface** | **LOCKED** |
| S21 | Buffer TokenType | Always STANDARD (never RP) | **LOCKED** |
| S22 | Extra vault underlyings | Allowed if S9 holds | **LOCKED** |
| S23 | DETF/bond/claim | Out of scope | **LOCKED** |
| S24 | Router | No special router; normal Balancer V3 pool surface | **LOCKED** |
| S25 | v1 test bar | Formula + routing + conservation; not naive full-history comparative | **LOCKED** |
| S26 | Parallel forever | Fresh package; no subclass of weighted CommonBuffer / MultiPair / MixedLeg | **LOCKED** |
| S27 | Token cap | Package enforces T≤4 / N≤3; respect StableMath MAX_STABLE_TOKENS=5 | **LOCKED** |

---

## Open questions

**None for v1 product requirements.** Implementation-only choices (storage layout, exact error names, gas micro-opts) belong in the implementation plan.

Minor defaults already chosen:

| ID | Default |
|----|---------|
| O1 N=1 | Product-supported (bridge + production) |
| O2 Gradual amp | v1 no |
| O5 Unpaired | Out of v1; would need new PRD (and T≤5) |

---

## Scope

### In scope (v1)

- Path: `…/stable/commonBufferMultiVault/`
- Layout \(T = 1 + N \in [2,4]\), \(N \in [1,3]\)
- StableMath + fixed deploy amp
- Always-route shallowest / deepest + S12 ties + S11 walk
- Deploy-time `IStandardVault` accept+produce check
- LP: proportional; unbalanced **add** (incl. buffer-only add → \(i^\*\)); **no** buffer-only unbalanced remove
- Hook-driven pre-seat / reconcile; Diamond peer facet set; DFPkg + FactoryService + registry
- Optional per-share user rate providers
- Production-first tests per S25/S14

### Out of scope (v1)

- Weighted / Gyro math  
- Unpaired legs  
- Routing weights / \(d_i/w_i\)  
- Multiple buffer tokens  
- N > 3  
- Implied-leg routing  
- Buffer-only unbalanced **remove**  
- Instance amp updates  
- Auto-deploy default SE RPs  
- DETF seigniorage / bond / claim  
- Special-purpose router  
- Subclassing weighted CommonBuffer concrete targets  

---

## Architecture (target)

```
                    Balancer V3 Vault (singleton)
                     | swap / add / remove / rates
                     v
     CommonBufferMultiVaultStablePool Diamond  (== hooksContract)
       • StableMath(amp) over: virtualBuffer + derived shares
       • IHooks on THIS proxy
       • CUSTOM liquidity (NotHookCaller)
       • Repo: N, buffer, vaults[N], shares[N], RPs, amp,
               virtualBuffer, hookShareDelta[N]
                     |                              |
                     | rates (optional)             | exchangeIn / exchangeOut
                     v                              v
              rate providers                 standardExchangeVault[i*]
                                             (shallowest / deepest)

  Deploy: for each vault, IStandardVault config includes bufferToken.
```

### Facet / package inventory (sketch)

| Piece | Role |
|-------|------|
| `ICommonBufferMultiVaultStablePool` | Errors, views, `TokenKind`, routing views, amp views |
| `…Repo` | Storage (layout + amp + virtuals) |
| `…Common` | Math balances, derived depth, depth ranking, BV3 round-trips |
| `…Target` | StableMath `onSwap` / invariant / computeBalance |
| `…HookTarget` | Register, init, pre-seat via \(i^\dagger\), reconcile via \(i^\*\), LP |
| `…LiquidityTarget` | CUSTOM, hook-only |
| Facets / DFPkg / FactoryService | Peer pattern; Stable invariant ratio bounds |

---

## Registration (target)

### TokenConfig (after address sort)

- `bufferToken`: STANDARD (never RP)  
- Each `vaultShare[i]`: STANDARD if `vaultShareRateProviders[i] == 0`; else WITH_RATE + user RP (**no** auto default)

### LiquidityManagement (working)

- CUSTOM add/remove true; donation true; unbalanced allowed  

### HookFlags (working — CommonBuffer spirit)

beforeInit, before/after swap, before/after addLiquidity, after removeLiquidity; no dynamic fee; no hook-adjusted amounts.

### `onRegister` / deploy checks (minimum)

- `tokenConfig.length == 1 + N`  
- Exactly one buffer; N shares  
- Uniqueness  
- **S9:** each vault’s `IStandardVault` config lists `bufferToken`  
- Amp in range  
- `hooksContract == pool`  
- Invariant ratio bounds = StableMath (60% / 500%)

---

## Math and state (design sketch)

### Storage (conceptual)

```text
N, tokenCount
bufferToken, bufferIndex
for i in 0..N-1:
  vaultShare[i], standardExchangeVault[i], rateProvider[i], shareIndex[i]
amplification (startValue, endValue, startTime, endTime)  // v1: start == end
expectedFactory

virtualBuffer
hookShareDelta[0..N-1]
pendingPreSeat...
```

**Amp storage** lives in **this package’s Repo** (namespaced slot), not shared Crane `BalancerV3StablePoolRepo` slot on the same diamond.

### Balance vector

```text
buffer          -> virtualBuffer
vaultShare[i]   -> derivedShareDepth(i, balancesLiveScaled18)
```

### Ranking

```text
deposit order: ascending d_i, then ascending i
redeem  order: descending d_i, then ascending i on ties
```

### Init (S15)

- All legs non-zero seed (buffer + every share)  
- `virtualBuffer =` buffer scaled18 seed  
- `hookShareDelta[i] = 0`  
- Amp fixed from args  

### LP

- Proportional: scale virtual + all deltas  
- Unbalanced **add** of buffer: deposit via \(i^\*\) with S11 walk  
- Unbalanced **remove** of buffer only: **revert** (S16)  
- Share-side unbalanced: allowed as Balancer + peers permit  
- Donation: no free virtual  

### Security

- CUSTOM only `router == address(this)`  
- Hooks only from Vault, `pool == this`  
- Public views: `mostNeededVault()`, `mostExcessVault()`, `derivedShareDepth(i)` / liquidity depth  

---

## Deploy args (sketch)

```solidity
// On interface ICommonBufferMultiVaultStablePoolPkg — not on the contract body
struct PkgArgs {
    IERC20 bufferToken;
    uint8 vaultCount; // 1..3
    IStandardExchange[] standardExchangeVaults;
    // length == vaultCount.
    // address(0) => TokenType.STANDARD (no rate provider; package does NOT deploy a default SE RP).
    // non-zero => TokenType.WITH_RATE + that provider (user-supplied only).
    IRateProvider[] vaultShareRateProviders;
    uint256 amplificationParameter; // raw amp in StableMath range
    // NO weights
}
```

Validation (minimum):

- `1 ≤ vaultCount ≤ 3`  
- Array lengths match  
- Distinct vaults/shares; unique final token addresses  
- **S9:** for each vault, `IStandardVault` shows `bufferToken` as accepted/produced  
- Amp in `[MIN_AMP, MAX_AMP]`  

---

## Testing expectations (when implementing)

| Suite | Intent |
|-------|--------|
| Registration | N=1..3; reject bad N; reject vault missing buffer in `IStandardVault` |
| Routing unit | \(d_i\) ordering; S12 ties (lowest index); S11 walk order |
| Swap buffer↔share | Fan-out may differ from share leg `k`; math + conservation |
| Swap share↔share | No buffer SE I/O on pure share path |
| N=1 | Bridge case under Stable |
| Formula equivalence | StableMath on math vector (S25) |
| LP proportional / buffer **add** | Virtual + deltas; shallowest deposit + walk |
| LP buffer-only **remove** | Must revert (S16) |
| Walk-on-fail | Top vault fails → second succeeds when inventory allows |
| Amp bounds | Reject invalid amp |
| RP | Zero ⇒ STANDARD; non-zero ⇒ WITH_RATE; never auto-deploy |
| Adversarial | CUSTOM drain; virtual underflow; residual; reentrancy |
| Invariants | virtual ≥ 0; eventual-zero physical buffer (S14) |

**Forbidden:** mock SUT pool/pkg/manager/registry; mock SE vaults for lifecycle.

---

## Risks and sharp edges

| Risk | Mitigation |
|------|------------|
| Always-route surprises traders (swap B shares, inventory moves on A) | Document in NatSpec/UI; views for mostNeeded/mostExcess |
| Comparative tests vs naive reference fail | S25: formula + routing + conservation only |
| Depegged share with no RP or stale RP | Document RP responsibility; optional WITH_RATE |
| Amp too high masks divergence | Ops guidance; product docs |
| Pre-seat quote wrong if WeightedMath copied | Explicit StableMath-only quote path |
| Confusion with weighted CommonBuffer | Docs: weighted = basket; this = like-kind stable |
| Gas: score N + multi SE tries | N≤3; bound walk to N |

---

## Comparison table

| Dimension | Weighted CommonBuffer | **This product** |
|-----------|----------------------|------------------|
| Curve | WeightedMath + weights | **StableMath + amp** |
| Buffer tokens | 1 shared | **1 shared** |
| Vaults | N ≤ 7 (+ unpaired) | **N ≤ 3, no unpaired** |
| Fan-out score | \(d_i/w_i\) | **\(d_i\)** |
| Pre-seat quote | WeightedMath | **StableMath** |
| Rate providers | Optional user-only | Same |
| Invariant bounds | Weighted standard | **Stable 60%/500%** |

---

## Suggested next design / build sessions

1. ~~Lock product requirements~~ — **done** (S1–S27).  
2. Write implementation plan — `CommonBufferMultiVaultStablePool_IMPLEMENTATION_AND_TEST_PLAN.md`.  
3. Implement phases 0–8 (or explicit “implement now”).

---

## Document control

| Item | Value |
|------|--------|
| PRD path | `contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePool_PRD.md` |
| Implementation plan | `./CommonBufferMultiVaultStablePool_IMPLEMENTATION_AND_TEST_PLAN.md` |
| Behavioral references | weighted commonBufferMultiVault, single SE buffer, Crane pool-stable |

---

## Appendix A — Decision restatement (plain language)

| You said | PRD encoding |
|----------|----------------|
| Up to 3 SE vaults + 1 common token | **S1** |
| Buffer into vault with lowest liquidity (not “by weight”) | **S2** pure \(d_i\) |
| Always rebalance shallowest/deepest | **S3** |
| Optional SE RP for any combination of vaults | **S4** |
| Name CommonBufferMultiVaultStablePool | **S5** |
| Stable curve | **S6** |
| Fixed amp, no post-deploy amp admin | **S7–S8** |

## Appendix B — Worked example

Vaults A/B/C with depths \(d=(50,30,40)\).

- Shallowest (deposit) order: **B → C → A**.  
- Deepest (redeem) order: **A → C → B**.  

User swaps **buffer → share C**:

1. StableMath reduces C’s math balance, increases virtual buffer.  
2. Hook deposits physical buffer into **B** first.  
3. If B fails, try **C**, then **A**.  

User swaps **share C → buffer**:

1. Hook pre-seats from **A** first (not necessarily C).  
2. If A cannot redeem, try **C**, then **B**.  

## Appendix C — Glossary

| Term | Meaning |
|------|---------|
| Stale pool | Informal name for this stable common-buffer product |
| Common buffer | Single bufferable pool token shared across N vaults |
| Shallowest | Lowest \(d_i\) among share legs (deposit target) |
| Deepest | Highest \(d_i\) (redeem source) |
| Walk | Try next vault in ranked order after I/O failure (S11) |
| Accept + produce | Vault can exchange buffer↔shares; deploy-checked via `IStandardVault` |
| Always-route | Fan-out ignores which share token was on the user trade |
| Eventual-zero | No residual physical buffer in the pool at rest after success (S14) |

## Appendix D — Acceptance (PRD complete)

Product requirements are **LOCKED**. Proceed to implementation plan; do not reopen S1–S27 without log note.
