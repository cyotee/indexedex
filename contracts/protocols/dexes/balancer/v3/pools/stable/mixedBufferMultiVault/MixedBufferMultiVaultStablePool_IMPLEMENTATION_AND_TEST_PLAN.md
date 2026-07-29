# MixedBufferMultiVaultStablePool — Implementation and Testing Plan

## Purpose

Execute the [PRD](./MixedBufferMultiVaultStablePool_PRD.md): implement a **Balancer V3 Stable pool** with:

- **One or more unpaired** (non-buffered) tokens (`U ≥ 1`),
- **Exactly one** shared `bufferToken` consolidated into **N ∈ [1, 3]** Standard Exchange vaults,
- Token count \(T = U + 1 + N\) with \(3 \le T \le 5\) (StableMath `MAX_STABLE_TOKENS = 5`),
- **Always-route** fan-out: deposit to **shallowest** vault (lowest derived depth \(d_i\)), redeem from **deepest** (highest \(d_i\)),
- **Walk next vault** on SE I/O failure,
- **Optional user-only** rate providers on unpaired and share legs,
- Fixed deploy-time **amplification** (no post-deploy amp updates).

This plan is ordered for incremental delivery: each phase leaves a green, reviewable slice. **Execution cadence (locked):** drive phases 1→8 end-to-end and report when green (no mid-phase review gates required).

## Status

**IMPLEMENTED** — PRD **LOCKED** (M1–M30). Production package + hermetic suite green (2026-07-26, 55 tests).  
**Implementation choices locked** 2026-07-25 (see §0).

| Field | Value |
|-------|--------|
| PRD | `MixedBufferMultiVaultStablePool_PRD.md` (**LOCKED** M1–M30) |
| Package path | `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/` |
| Behavioral references | `stable/commonBufferMultiVault/` (Stale), `weighted/commonBufferMultiVault/`, `weighted/mixedLegBuffer/`, Crane `pool-stable/` |
| Tests root (intended) | `test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/` |

### Glossary (use full words in prose; symbols in tables)

| Symbol | Role name | Meaning |
|--------|-----------|---------|
| **U** | unpaired / free leg count | Pool tokens **never** SE-buffered (physical only). **≥ 1** for this package. |
| **N** | vault / share count | Standard Exchange vaults (and their share tokens on the pool). **1…3**. |
| **T** | token count | Total Balancer pool tokens: \(T = U + 1 + N\) (one buffer). **3…5**. |
| **buffer** | `bufferToken` | Exactly one common token that every configured vault accept+produces. |
| **\(d_i\)** | derived share depth | Rate-aware scaled18 depth of vault share leg `i` (ranking input). |

**Example configs:**

| ID | Free legs (U) | Buffer | Vaults (N) | T | Plain language |
|----|---------------|--------|------------|---|----------------|
| C0 | 1 | 1 | 1 | 3 | Minimal mixed |
| C1 | 1 | 1 | 2 | 4 | One free + dual vault |
| C2 | 1 | 1 | 3 | 5 | One free + max vaults |
| C3 | 2 | 1 | 2 | 5 | Dual free + dual vault |
| C4 | 3 | 1 | 1 | 5 | Max free + single vault |

### Locked decisions (summary from PRD)

| Topic | Decision |
|-------|----------|
| Layout | \(T = U + 1 + N\), \(U \ge 1\), \(1 \le N \le 3\), \(3 \le T \le 5\); **exactly one** buffer |
| U = 0 | **Invalid** — use Stale (`CommonBufferMultiVaultStablePool`) |
| Curve | StableMath + fixed deploy amp |
| Routing | Always shallowest deposit / deepest redeem |
| Need score | \(d_i\) only (no weights) |
| Ties | Lowest vault index |
| Runtime I/O fail | Walk next by depth; revert if all fail |
| Deploy vault check | Accept + produce buffer via `IStandardVault`; unpaired not required on vaults |
| Init | All legs non-zero (unpaired + buffer + every share); virtualBuffer = buffer seed |
| LP | Prop + unbalanced add; no buffer-only remove |
| Residual | Eventual-zero physical buffer; unpaired never virtualized |
| RPs | Optional user-only on unpaired + shares; no auto-deploy SE RP |
| Pre-seat quote | **StableMath** (not WeightedMath) |
| Parallel forever | Do not subclass Stale / weighted CommonBuffer / MultiPair / MixedLeg |

### §0 Locked implementation choices (2026-07-25)

Product requirements stay M1–M30. These tighten **test DoD / delivery**, not product math:

| Topic | Decision |
|-------|----------|
| Config coverage | **C0–C4 all green** before **IMPLEMENTED** (no deferral of dual-free / max-free) |
| Invariant suite | **Required in v1** — `Handler_*` + `*.invariant.t.sol` (not optional) |
| Hermetic SE legs | **Multi-protocol matrix** — equal-priority production SE ports (not Uni V2 only) |
| Rate providers in tests | **Full WITH_RATE matrix** — unpaired-with-RP, share-with-RP, and mixed (plus STANDARD baseline) |
| Execution cadence | **Full checklist, report when green** — phases 1→8 without required mid-phase gates |
| Copy-adapt base | **Hybrid free choice** — Stale and/or weighted CommonBuffer as reference only; no subclass; behavior must match PRD |

---

## 1. Goals and non-goals

### Goals

1. Ship production Diamond pool + hooks + CUSTOM liquidity under `stable/mixedBufferMultiVault/`.
2. Support **all** accepted token-budget configs in §4 (**C0–C4**) with full lifecycle coverage before **IMPLEMENTED**:
   - C0: 1 free + 1 buffer + 1 vault (T=3),
   - C1: 1 free + 1 buffer + 2 vaults (T=4),
   - C2: 1 free + 1 buffer + 3 vaults (T=5),
   - C3: 2 free + 1 buffer + 2 vaults (T=5),
   - C4: 3 free + 1 buffer + 1 vault (T=5).
3. Implement always-route depth ranking, M12 ties, M11 walk, SE I/O parity with Stale / CommonBuffer peers.
4. Prove **formula equivalence**: `onSwap` / invariant / `computeBalance` match `StableMath` on the math balance vector + amp (unpaired physical + virtualBuffer + derived shares).
5. Prove **routing + conservation**: correct ranking/walk; no free BPT; virtual ≥ 0; eventual-zero physical buffer; unpaired never virtualized.
6. Production-first tests; no mocks of SUT pool / manager / registry / SE vaults under test.
7. Adversarial P0: CUSTOM drain, donation, residual, reentrancy.
8. **Invariant handler** suite green (virtual ≥ 0; eventual-zero buffer; unpaired not virtualized).
9. **Multi-protocol hermetic SE matrix** + **full WITH_RATE rate-provider matrix** (see §8).

### Non-goals

- Replacing or subclassing Stale / weighted CommonBuffer / MultiPair / MixedLeg / single SE buffer.
- Supporting \(U = 0\) (Stale owns that surface).
- Implied-leg vault selection.
- Naive full-history comparative parity vs a reference stable pool after fan-out.
- Buffer-only unbalanced remove.
- Auto-deploying default SE RPs when user passes `address(0)`.
- Routing weights; gradual amp updates; DETF product logic; special router; mainnet scripts.
- Shared pure-lib extraction from Stale (optional later once both packages are stable).

---

## 2. Naming and layout

### Source

```text
contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/
  MixedBufferMultiVaultStablePool_PRD.md
  MixedBufferMultiVaultStablePool_IMPLEMENTATION_AND_TEST_PLAN.md  # this file
  IMixedBufferMultiVaultStablePool.sol
  MixedBufferMultiVaultStablePoolRepo.sol
  MixedBufferMultiVaultStablePoolCommon.sol
  MixedBufferMultiVaultStablePoolTarget.sol
  MixedBufferMultiVaultStablePoolFacet.sol
  MixedBufferMultiVaultStablePoolHookTarget.sol
  MixedBufferMultiVaultStablePoolHookFacet.sol
  MixedBufferMultiVaultStablePoolLiquidityTarget.sol
  MixedBufferMultiVaultStablePoolLiquidityFacet.sol
  MixedBufferMultiVaultStablePoolStandardVaultPkg.sol
  MixedBufferMultiVaultStablePool_FactoryService.sol
```

**Type names:** full words (`MixedBuffer`, `MultiVault`, `StablePool`).  
**Roles:** `unpairedToken`, `bufferToken`, `standardExchangeVault`, `vaultShare` / `shareToken`, `virtualBuffer`, `hookShareDelta`, `amplificationParameter`.  
**Forbidden:** product tickers; brand names; `WETH` as a generic role; `weights` storage/API; subclassing Stale contracts.

### Tests

```text
test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/
  bases/
    TestBase_MixedBufferMultiVaultStablePool.sol
    TestBase_MixedBufferMultiVaultStable_UniV2.sol      # hermetic SE legs (matrix row)
    TestBase_MixedBufferMultiVaultStable_CamelotV2.sol  # hermetic SE legs (matrix row)
    TestBase_MixedBufferMultiVaultStable_Aerodrome.sol  # hermetic SE legs (matrix row; or peer ports)
    # add further protocol TestBases as equal-priority matrix rows when ports exist
  behaviors/
    Behavior_Registration.sol
    Behavior_Initialization.sol
    Behavior_Routing.sol
    Behavior_Swap_BufferShare.sol
    Behavior_Swap_ShareShare.sol
    Behavior_Swap_Unpaired.sol
    Behavior_LP_Proportional.sol
    Behavior_LP_Unbalanced.sol
    Behavior_Validation.sol
    Behavior_Errors.sol
    Behavior_RateProviders.sol   # STANDARD + WITH_RATE matrix
  MixedBufferMultiVaultStablePool.spec.t.sol
  MixedBufferMultiVaultStablePool.invariant.t.sol   # REQUIRED v1
  Handler_MixedBufferMultiVaultStablePool.sol      # REQUIRED v1
  formula/
    MixedBufferMultiVaultStable_FormulaEquivalence.t.sol
  adversarial/
    TestBase_MixedBufferMultiVaultStable_Adversarial.sol
    Adversarial_CustomDrain.t.sol
    Adversarial_Donation.t.sol
    Adversarial_ResidualBuffer.t.sol
    Adversarial_Reentrancy.t.sol
```

**TestBase inheritance (intended):**  
`CraneTest` → `IndexedexTest` → vault components / Balancer SE stack → SE protocol TestBase → `TestBase_MixedBufferMultiVaultStablePool`.

**SE matrix (locked):** equal-priority hermetic production SE providers (Uni V2, Camelot V2, Aerodrome, and any other available hermetic ports). Do not treat one protocol as the sole proof path for C0–C4 lifecycle.

Mirror gold patterns from:

- `TestBase_CommonBufferMultiVaultStablePool` (Stable + buffer routing),
- `TestBase_CommonBufferMultiVaultWeightedPool` (unpaired deploy/seed),
- Stale / weighted CommonBuffer multi-protocol hermetic SE legs where present.

---

## 3. Math, routing, and state (normative for implementers)

### 3.1 Token kinds and indexing

After Balancer address-sort, store:

```text
unpairedCount U (>= 1), vaultCount N (1..3), tokenCount T = U + 1 + N (<= 5)
unpairedIndex[j], bufferIndex, shareIndex[i]
```

```text
TokenKind { Unpaired, Buffer, Share }

resolveTokenIndex(t) -> (TokenKind kind, uint256 legIndex)
resolveToken(address)  -> same
```

### 3.2 Derived share depth

Same construction as Stale / weighted CommonBuffer:

```text
actual = balancesLiveScaled18[shareIndex[i]]
if hookShareDelta[i] <= 0:
  depth = actual + liftToScaled18Rated(|delta|, shareIndex[i])
else:
  depth = max(0, actual - liftToScaled18Rated(delta, shareIndex[i]))
```

### 3.3 Math balances for StableMath

```text
balances[unpairedIndex[j]] = balancesLiveScaled18[unpairedIndex[j]]   // physical only
balances[bufferIndex]      = virtualBuffer
balances[shareIndex[i]]    = derivedShareDepth(i, balancesLiveScaled18)
```

### 3.4 Ranking

```text
score(i) = derivedShareDepth(i)
deposit preference: lower score first; ties → lower index
redeem preference:  higher score first; ties → lower index
```

Public views: `shallowestVault()`, `deepestVault()`, `derivedShareDepth(i)`.

### 3.5 Amplification

- Store amp with AMP_PRECISION multiplier (Crane Stable / Stale pattern).
- v1: startValue == endValue; no start/stop update functions on public surface (or leave unimplemented/revert).
- `onSwap` / invariant / computeBalance read **current** amp (constant when not updating).

### 3.6 Pre-seat quote

```text
// EXACT_IN path sketch
feeAmount = amountGiven * staticSwapFee / 1e18  (ceil as peer)
amountAfterFee = amountGiven - feeAmount
invariant = StableMath.computeInvariant(amp, mathBalances)
yOut = StableMath.computeOutGivenExactIn(amp, mathBalances, indexIn, indexOut, amountAfterFee, invariant)
// for buffer-out pre-seat, indexOut == bufferIndex; yOut is scaled18 buffer needed
```

Do **not** call WeightedMath.

### 3.7 SE I/O (peer shape)

- Pre-seat: `previewExchangeOut` → drain shares via vault custom remove / hook path → `exchangeOut`.
- Reconcile: pull physical buffer → `exchangeIn` into ranked vault → donate minted shares + adjust `hookShareDelta`.
- External-self `try/catch` pattern from Stale / CommonBuffer HookTarget for walk without poisoning whole tx until all fail.
- **Unpaired legs never participate in SE I/O.**

### 3.8 Repo layout (sketch)

```solidity
// STORAGE_SLOT namespaced uniquely — do NOT share Stale or Crane Stable repo slots
uint8 MAX_UNPAIRED = 3;  // T=5, N=1 => U max 3
uint8 MAX_VAULTS   = 3;
uint8 MAX_TOKENS   = 5;

struct Storage {
    uint8 unpairedCount;
    uint8 vaultCount;
    address expectedFactory;

    IERC20[MAX_UNPAIRED] unpairedTokens;
    IRateProvider[MAX_UNPAIRED] unpairedRateProviders;
    uint8[MAX_UNPAIRED] unpairedIndices;

    IERC20 bufferToken;
    uint8 bufferIndex;

    IERC20[MAX_VAULTS] shareTokens;
    IStandardExchange[MAX_VAULTS] standardExchangeVaults;
    IRateProvider[MAX_VAULTS] vaultShareRateProviders;
    uint8[MAX_VAULTS] shareIndices;

    uint256 virtualBuffer;
    int256[MAX_VAULTS] hookShareDeltas;
    // pending pre-seat fields (peer)
    uint64 ampStartValue;
    uint64 ampEndValue;
    uint32 ampStartTime;
    uint32 ampEndTime;
}
```

---

## 4. Config matrix (must cover)

**All accepted rows C0–C4 are required green before IMPLEMENTED** (no deferral). U = free/unpaired count; N = vault/share count; T = U + 1 buffer + N.

| ID | Free (U) | Vaults (N) | T | Priority | Intent |
|----|----------|------------|---|----------|--------|
| C0 | 1 | 1 | 3 | **Required** | Minimal mixed; smoke + lifecycle |
| C1 | 1 | 2 | 4 | **Required** | Dual vault + one free; fan-out ≠ trade leg |
| C2 | 1 | 3 | 5 | **Required** | Max vaults under StableMath |
| C3 | 2 | 2 | 5 | **Required** | Dual free + dual vault |
| C4 | 3 | 1 | 5 | **Required** | Max free + single vault |
| R0 | 0 | * | * | **Reject** | Must revert — Stale surface |
| R1 | 2 | 3 | 6 | **Reject** | T > 5 |
| R2 | 4 | 1 | 6 | **Reject** | T > 5 |
| R3 | * | 0 | * | **Reject** | N ≥ 1 required |
| R4 | * | 4 | * | **Reject** | N ≤ 3 |

---

## 5. Implementation phases

### Phase 0 — Docs

- [x] PRD locked (M1–M30)
- [x] This implementation plan
- [x] Implementation choices locked (§0): C0–C4 all green; invariant required; multi-protocol SE matrix; full WITH_RATE matrix; full checklist cadence; hybrid copy-adapt
- [x] Optional adversarial catalog doc (P0 catalog can live in this plan §8)

### Phase 1 — Interface + Repo + Common

**Deliverables:**

- [x] `IMixedBufferMultiVaultStablePool.sol` — errors, views, `TokenKind` (Unpaired \| Buffer \| Share), routing views, amp views, unpaired views
- [x] `…Repo.sol` — storage slot namespaced to this product; U + N layout + amp + virtuals + deltas
- [x] `…Common.sol` — rates lift, derived depth, math balances (incl. unpaired physical), rank deposit/redeem, resolve helpers

**Exit criteria:** unit-level pure helpers compile; no DFPkg yet.

### Phase 2 — Target + Facet (StableMath)

- [x] `…Target.sol` — StableMath `onSwap` / invariant / `computeBalance` over full math vector
- [x] `…Facet.sol` — IFacet + shallowest/deepest/derived depth/amp + unpaired/buffer/share views
- [x] Formula equivalence suite skeleton (can run against Target with seeded math state once TestBase exists)

**Exit criteria:** formula tests green for multi-token StableMath vector including unpaired indices.

### Phase 3 — Liquidity + CUSTOM

- [x] Liquidity Target/Facet
- [x] `NotHookCaller` tests green

### Phase 4 — HookTarget register + init

- [x] `onRegister`: length = U+1+N; U≥1; N∈[1,3]; T≤5; uniqueness; buffer STANDARD; RPs; hooksContract == pool; Stable invariant ratios
- [x] Init: all legs non-zero seed (every unpaired + buffer + every share); `virtualBuffer` = buffer scaled18; `hookShareDelta[i]=0`
- [x] C0 (U=1,N=1) smoke green after DFPkg or direct test wiring

### Phase 5 — HookTarget swap + LP SE I/O

- [x] Pre-seat via deepest walk (M11); StableMath quote only
- [x] Reconcile via shallowest walk; eventual-zero physical buffer
- [x] Buffer ↔ share: fan-out may differ from share leg `k`
- [x] Share ↔ share: no buffer SE I/O on pure share path
- [x] Unpaired ↔ buffer: SE path when buffer involved
- [x] Unpaired ↔ share / unpaired ↔ unpaired: no buffer SE I/O
- [x] LP proportional; buffer unbalanced **add** → shallowest; buffer-only **remove** reverts (M16)
- [x] C1 / C2 / C3 / C4 green for multi-vault and multi-free layouts

### Phase 6 — DFPkg + FactoryService

- [x] `IMixedBufferMultiVaultStablePoolPkg` (on package interface, peer pattern) holds **`PkgInit` / `PkgArgs`** — never on contract body
- [x] `…StandardVaultPkg.sol` — Vault Registry path; M9 checks; reject U=0 / T>5 / N out of range
- [x] `…_FactoryService.sol` — CREATE3 facets + typed `deploy*DFPkg` on manager
- [x] Registration matrix R0–R4 reject cases

### Phase 7 — Gold TestBase + suite

- [x] TestBase + **multi-protocol hermetic SE matrix** (Uni V2 + Camelot V2 + Aerodrome / available ports)
- [x] Spec covering **C0–C4** full lifecycle (all required)
- [x] Formula + routing + conservation + adversarial P0 green
- [x] **WITH_RATE matrix:** unpaired-with-RP, share-with-RP, mixed + STANDARD baseline
- [x] **Invariant handler required** (`Handler_*` + `*.invariant.t.sol`: virtual ≥ 0; residual buffer; unpaired not virtualized)

### Phase 8 — Polish

- [x] Role names / NatSpec compliance
- [x] `forge fmt` on package + tests
- [x] Stable invariant ratios 60e16 / 500e16 confirmed on package
- [x] Update this plan status → **IMPLEMENTED** when suite green (C0–C4 + matrix + invariants)

---

## 6. DFPkg sketch (normative constraints)

```solidity
interface IMixedBufferMultiVaultStablePoolPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        // facets: basicVault, standardVault, vaultAware, poolToken, poolInfo,
        // swapFeeBounds, unbalancedLiquidityInvariantRatioBounds (Stable ratios),
        // authentication, poolFacet, liquidityFacet, hookFacet
        // vaultRegistry, feeOracle, balancerV3Vault, diamondFactory
        // rateProviderPkg — present but never auto-used on zero args
    }

    struct PkgArgs {
        IERC20[] unpairedTokens;                 // length U >= 1
        IRateProvider[] unpairedRateProviders;   // 0 => STANDARD
        IERC20 bufferToken;                      // exactly one; always STANDARD
        uint8 vaultCount;                        // 1..3
        IStandardExchange[] standardExchangeVaults;
        IRateProvider[] vaultShareRateProviders; // 0 => STANDARD
        uint256 amplificationParameter;
        // NO weights
    }
}
```

**Validation (deploy / postDeploy / onRegister):**

1. `U = unpairedTokens.length ≥ 1`
2. `1 ≤ vaultCount ≤ 3`
3. `3 ≤ U + 1 + vaultCount ≤ 5`
4. Array length match
5. Unique addresses after sort; unpaired ≠ buffer ≠ shares; distinct vaults/shares
6. **M9:** each vault’s `IStandardVault` lists `bufferToken`
7. Amp in StableMath `[MIN_AMP, MAX_AMP]`
8. Never auto-deploy RP when arg is `address(0)`

**Invariant ratio bounds facet:** StableMath `MIN_INVARIANT_RATIO` / `MAX_INVARIANT_RATIO` (60e16 / 500e16), not weighted bounds. Prefer shared stable-bounds facet used by Stale if available; else package-local.

---

## 7. Porting checklist (behavioral reference only)

**Copy-adapt policy (locked):** hybrid free choice of starting reference (Stale **or** weighted CommonBuffer **or** interleaved). **Forbidden:** subclass concrete Stale / weighted CommonBuffer / MultiPair / MixedLeg contracts. Result must match PRD M1–M30 and this plan’s math/routing tables.

### From Stale (`stable/commonBufferMultiVault`)

| Stale piece | Action |
|-------------|--------|
| StableMath onSwap / invariant / computeBalance | **Keep** pattern |
| Amp storage + fixed deploy amp | **Keep** |
| Virtual buffer + hookShareDelta | **Keep** |
| Ranking by \(d_i\); lowest-index ties | **Keep** |
| Always-route walk SE I/O | **Keep** |
| Pre-seat StableMath quote | **Keep** |
| Buffer-only remove disallowed | **Keep** |
| Eventual-zero physical buffer | **Keep** |
| S9 accept+produce | **Keep** |
| TokenKind without Unpaired; T=1+N | **Extend** — add Unpaired, U≥1, T=U+1+N |
| Subclass Stale targets | **Forbidden** |

### From weighted CommonBuffer (`weighted/commonBufferMultiVault`)

| Weighted CommonBuffer piece | Action |
|-----------------------------|--------|
| Unpaired physical legs + optional unpaired RPs | **Keep** |
| TokenKind.Unpaired + resolve helpers | **Keep** |
| Uniqueness unpaired ≠ buffer ≠ shares | **Keep** |
| Init all legs including unpaired non-zero | **Keep** |
| Swap unpaired paths (no SE on pure unpaired) | **Keep** |
| `weights[]` / `_score = d/w` | **Delete** |
| Tie-break larger weight | **Delete** — use index only |
| WeightedMath | **Replace** with StableMath + amp |
| Weighted invariant ratios | **Replace** with Stable 60%/500% |
| U=0 allowed | **Reject** — M28 |
| T≤8 / N≤7 | **Replace** with T≤5 / N≤3 |
| Subclass weighted contracts | **Forbidden** |

---

## 8. Testing plan (normative)

### 8.1 Production-first rules

- **No mocks** of SUT: pool diamond, facets, DFPkg, manager, registry, fee oracle, SE vaults under test.
- Real SE vaults via protocol TestBases / hermetic ports.
- **Multi-protocol SE matrix (required):** equal-priority hermetic providers (at least Uni V2, Camelot V2, Aerodrome when ports exist). Lifecycle proof must not rest on a single SE family alone.
- Allowed non-SUT harnesses: mintable ERC20 for funding; controllable rate providers for WITH_RATE paths; reentrancy hostile ERC20 only for attack tests.
- Deploy path: CREATE3 facets + `indexedexManager.deploy*DFPkg` + package instance deploy.

### 8.2 Behavior suites

| Suite | Intent | PRD |
|-------|--------|-----|
| Registration | C0–C4 accept; R0–R4 reject; M9 buffer on vault | M1, M9, M27–M30 |
| Initialization | All legs non-zero; virtualBuffer seed; deltas 0 | M15 |
| Routing | \(d_i\) order; ties → lowest index; walk order | M2, M11, M12 |
| Swap buffer↔share | Fan-out may ≠ leg `k`; conservation | M3, M13, M14 |
| Swap share↔share | No buffer SE I/O | M3 |
| Swap unpaired↔buffer | Physical unpaired; SE when buffer out/in | M29 |
| Swap unpaired↔share / unpaired↔unpaired | No buffer SE I/O | M29 |
| LP proportional | Scale virtual + deltas; unpaired physical by Balancer | M16 |
| LP unbalanced | Buffer add → shallowest + walk; buffer-only remove reverts | M16 |
| Validation | Amp bounds; uniqueness; U≥1; T≤5 | M7, M27 |
| Rate providers | STANDARD baseline + **WITH_RATE full matrix** (unpaired, share, mixed) | M4 |
| Formula | StableMath parity on math vector | M25 |
| Adversarial P0 | CUSTOM drain; donation; residual buffer; reentrancy | — |
| Invariants | **Required v1:** virtual ≥ 0; eventual-zero buffer; unpaired not virtualized | M13, M14 |
| SE protocol matrix | Same behaviors across multi-protocol hermetic SE legs | — |

### 8.2.1 Rate-provider matrix (required)

| Case | unpaired RPs | share RPs | Intent |
|------|--------------|-----------|--------|
| RP0 | all `address(0)` STANDARD | all STANDARD | Baseline |
| RP1 | one or more WITH_RATE | all STANDARD | Unpaired-with-RP |
| RP2 | all STANDARD | one or more WITH_RATE | Share-with-RP |
| RP3 | WITH_RATE on ≥1 free | WITH_RATE on ≥1 share | Mixed |

Prove rate-aware derived depth + StableMath balances; `rate()==0` reverts peer-style (`RateProviderZero`).

### 8.3 Adversarial P0 catalog

| ID | Attack | Expected |
|----|--------|----------|
| A1 | External CUSTOM liquidity call | `NotHookCaller` / peer deny |
| A2 | Donation of buffer / unpaired | No free BPT; virtual not inflated by bare transfer unless donation path |
| A3 | Residual physical buffer after success path | Eventual-zero (document ≤ few-wei only if BV3 forces) |
| A4 | Reentrancy via hostile share/unpaired token during SE / hook | `IsLocked` or peer lock |
| A5 | Virtual buffer underflow attempt | Revert `VirtualBufferUnderflow` |
| A6 | All vaults fail pre-seat / deposit | `AllVaultsExhausted` / peer |

### 8.4 Suggested forge commands

```bash
# Package-focused
forge test --match-path test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/**

# Formula
forge test --match-path '**/mixedBufferMultiVault/formula/**' -vv

# Invariants (required)
forge test --match-path '**/mixedBufferMultiVault/**/*invariant*' -vv

# Adversarial
forge test --match-path '**/mixedBufferMultiVault/adversarial/**' -vvv
```

---

## 9. Risks during implementation

| Risk | Mitigation |
|------|------------|
| Accidental WeightedMath import in quote | Code review + formula tests assert StableMath |
| Accidental subclass of Stale | Fresh package only; copy-adapt patterns, not inheritance |
| Amp / storage slot collision with Stale or Crane stable | Unique `STORAGE_SLOT` string for this product |
| U=0 accidentally allowed | Explicit reject in DFPkg + onRegister + registration tests |
| T=6 slips past validation | Assert `U + 1 + N <= StableMath.MAX_STABLE_TOKENS` |
| Stack-too-deep in hooks (more legs than Stale) | Extract helpers; viaIR if needed |
| Rate=0 on WITH_RATE | Revert `RateProviderZero` like peer |
| Unpaired virtualized by mistake | Math balance table + tests: unpaired == live only |
| Like-kind depeg without RP | Document RP responsibility; not a math bug |
| N=1 edge ranking | Single-element order always |
| Multi-protocol SE matrix cost | Shared behavior libs; one primary layout matrix; protocol TestBases as rows |
| WITH_RATE matrix stack depth | Controllable RP harnesses; reuse peer rate-lift helpers |

---

## 10. Definition of done

1. PRD M1–M30 implemented.  
2. Deploy path: CREATE3 facets + manager `deploy*DFPkg` + instance via registry.  
3. Hermetic tests green for **all accepted configs C0–C4** covering registration, init, routing, swaps (incl. unpaired), LP, formula, adversarial P0. **No deferral** of C3/C4.  
4. Reject cases R0–R4 covered.  
5. **Multi-protocol SE matrix** green (equal-priority hermetic SE ports; not Uni V2 alone).  
6. **Full WITH_RATE matrix** green (RP0–RP3 in §8.2.1) plus STANDARD baseline.  
7. **Invariant handler suite** green (`Handler_*` + `*.invariant.t.sol`).  
8. No mocks of SUT; real SE vaults from protocol TestBases.  
9. NatSpec + role naming compliance.  
10. `forge fmt` clean on package + tests.  
11. This plan status updated to **IMPLEMENTED**.

---

## 11. Suggested build order (session checklist)

**Cadence (locked):** drive the full list, then report once green (mid-phase checkpoints optional, not required).

```text
1. Phase 1: Interface + Repo + Common (with Unpaired)
2. Phase 2: Target/Facet StableMath
3. Phase 3: Liquidity CUSTOM
4. Phase 6 early stub: DFPkg validation (U,N,T) so TestBase can deploy
5. Phase 4: Hook register/init → C0 smoke
6. Phase 5: Swap + LP SE I/O → C1/C2/C3/C4
7. Phase 6 complete: FactoryService + full registration rejects
8. Phase 7: full suite + multi-protocol SE matrix + WITH_RATE matrix + adversarial + invariants
9. Phase 8: polish + mark IMPLEMENTED
```

---

## Document control

| Item | Value |
|------|--------|
| Plan path | `./MixedBufferMultiVaultStablePool_IMPLEMENTATION_AND_TEST_PLAN.md` |
| PRD | `./MixedBufferMultiVaultStablePool_PRD.md` |
| Status | **IMPLEMENTED** (suite green 2026-07-26, 55 tests) |
| Created | 2026-07-25 |
| Updated | 2026-07-26 — **IMPLEMENTED**: hermetic suite green (55 tests) incl. reentrancy, unbalanced LP + buffer-only remove, M11 walk/exhaust, R2 reject, real UniV2 SE matrix row |
