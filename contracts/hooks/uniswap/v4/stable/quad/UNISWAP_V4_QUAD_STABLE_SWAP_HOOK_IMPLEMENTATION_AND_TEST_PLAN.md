# Implementation & Test Plan: Uniswap V4 Quad Stable Swap Hook

**PRD (product law SoT):** [`UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md`](./UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md) (**v0.5.2** — plan-ready)  
**This plan (implementor SoT once accepted):** phases, file map, zap algorithm pins, constants, settle notes, test matrix.  
**Package:** `contracts/hooks/uniswap/v4/stable/quad/`  
**Date:** 2026-08-03  
**Status:** **Canonical plan v1.3** — write from PRD v0.5.2 + stakeholder pin pass (zap clamp, Newton reference, label recompute, LP metadata, dual TestBase path). Greenfield package (no production sources yet). **Plan-only; no product code in this file.**

**Authority**

| Layer | Role |
|-------|------|
| PRD v0.5.2 | Product law (D1–D74, Q1–Q33, §0–§8, §10–§11) |
| **This plan** | Implementor source of truth for phases, file layout, **Ann convention**, **zap pins** (incl. `maxViableIn`), **ctor metadata / LP strings**, **TestBase peer path**, test IDs |
| Peer buffer / dual hooks | Pattern-copy only (CREATE3 mine, settle order, Repo shape) — **do not subclass** |

**Process rule:** If this plan and the PRD disagree, **PRD wins** and this plan must be patched. Do **not** reopen locked PRD decisions without a PRD revision.

**Read order for implementors**

1. PRD §0 terminology + §1.1 user story  
2. PRD §3 locked decisions (D1–D74) + Q1–Q33  
3. **This plan** §1–§6 (scope, layout, phases, math/zap pins)  
4. PRD §4–§5 for normative detail when implementing a phase  
5. This plan §8–§9 for tests and DoD exit  

**Methodology skills:** `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `indexedex-adversarial-testing`, `crane-uniswap` (V4 settle **behavioral** reference only — no BaseHook inheritance).

---

## 0. Locked decisions (copy — PRD is source of truth)

| Topic | Decision |
|-------|----------|
| Product | **`UniswapV4QuadStableSwapHook`** — CREATE3-mined single contract (IHooks + ERC-20 LP) |
| Package path | `contracts/hooks/uniswap/v4/stable/quad/` |
| Shape | **Repo + Common + Math + Target + wire** + **FactoryService** + **on-chain Factory**. No Facet/DFPkg for hook or factory |
| Math | StableSwap \(n=4\); not Orbital; not Balancer WeightedMath |
| Assets | Exactly **four** ERC-20s; strict **`token0 < token1 < token2 < token3`** by address |
| Pool doors | Factory creates **all six** \(\binom{4}{2}\) pairs; `fee = lpFeePips`; `tickSpacing = 1`; `sqrtPrice = TickMath.getSqrtPriceAtTick(0)` |
| Inventory | Repo **`reserves[4]`** only (donations ignored) |
| LP fee | Deploy-time immutable `uint24 lpFeePips`; **`0 < lpFeePips < 1e6`**; fee on **output** (exact-in deduct; exact-out gross-up); residual stays in reserves |
| Amp | Deploy-time immutable `baseAmp`; `AMP_PRECISION = 100`; **`0 < baseAmp < MAX_AMP`**; no ramp |
| Rates | **`IRateProvider` addresses only** (or `address(0)`); always `getRate()`; **fail-closed** (D74); no package adapters |
| First mint | All four amounts > 0; geometric mean of rate-scaled − `MINIMUM_LIQUIDITY`; lock **1000** to **`address(0)`** |
| Zap | Algorithm **A** target-ratio sequential; any non-empty subset; public slippage **`sharesMin` only**; **closed-form inverse sizing only**; **clamp** unviable inverse via **leave ≥1 scaled unit on out-leg** (§6.5.4); **reclassify surplus/deficit after every internal swap**; **working-snapshot until final mint** (see §6.5) |
| Ctor metadata | **`decimals()`** fail-closed ∈ [6,18]; **`symbol()`** soft-fallback = **last 4 hex** of token (no `0x`) (see §5.2) |
| LP strings | Auto `QS-…`; name **`Quad Stable ` + QS body**; **symbol ≤ 32 bytes**, **name ≤ 64 bytes** (hard UTF-8 cut — §5.2) |
| TestBase peer | **LOCKED path:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol` (see §8.1) |
| Math reference | **Classic Curve StableSwap** (Vyper-style) Newton `get_D`/`get_y` for \(n=4\); **not** StableSwapNG; **not** Balancer StableMath (§6.2) |
| Swap gate | **Pair legs only** (`reserves[in/out] > 0` + convergent); witnesses may be zero |
| Access | Fully permissionless on hook and factory deploy; no owner/pause/skim |
| Deploy | Existing **`create3Factory`** + `HookMinerCreate3`; factory immutable **canonical chain V4 PoolManager** (D67); not vault registry |
| Inheritance | **No** `BaseHook` / `BaseTokenWrapperHook` / `DeltaResolver` — full pattern-copy |
| Forks | **Base + Robinhood Chain** equal DoD priority after hermetic; mintable test tokens OK |

### 0.1 Plan-pinned constants (PRD §10 + peer)

| Constant | Value | Notes |
|----------|-------|-------|
| `N_TOKENS` | `4` | Compile-time |
| `FEE_DENOMINATOR` | `1_000_000` | |
| `RATE_PRECISION` | `1e18` | |
| `AMP_PRECISION` | `100` | `getCurrentAmp() = baseAmp * AMP_PRECISION` |
| `MAX_AMP` | `1_000_000` | Exclusive upper bound on unscaled `baseAmp` |
| `MINIMUM_LIQUIDITY` | `1000` | To `address(0)` |
| `TICK_SPACING` | `1` | |
| `PAIR_COUNT` | `6` | |
| `MAX_NR_ITERS` | `255` | Newton; converge \(\lvert\Delta\rvert \le 1\) |
| `MAX_LOOP` | **`160_444`** | = `HookMinerCreate3.MAX_LOOP` (peer buffer FactoryService) |
| `DEFAULT_SALT_NAMESPACE` | `"uv4-quad-stable-swap-hook-"` | D33 |
| `LP_PREFIX` | `QS-` | Auto `QS-{s0}-{s1}-{s2}-{s3}` |
| `LP_SYMBOL_MAX` | **32** | UTF-8 byte length; truncate if over (see §5.2) |
| `LP_NAME_MAX` | **64** | UTF-8 byte length; truncate if over (see §5.2) |
| Demo `lpFeePips` | `500` | 0.05% (tests) |
| Demo `baseAmp` | `100`–`1000` | Prefer \(A \ge 10\) |
| `Ann` convention | **`Ann = A' * N_TOKENS`** | \(A' = baseAmp \cdot AMP\_PRECISION\); classic Curve iterative form — see §6.2 |
| FIX-D1 tolerance | **`\|D − S\| ≤ 1`** | Equal-balance scaled units; see §6.2 FIX-* |
| Zap `maxViableIn` | **Leave ≥1 scaled unit on out-leg** | Closed-form bound only — see §6.5.4 |
| Preview / residual dust | Prefer **exact** match; **≤ 1 wei** only where ceil/descale forces | Applies to swap/LP/zap previews **and** zap refund residual free inventory |

### 0.2 Deliberate divergences from peer packages (document in NatSpec)

| Topic | This package | Peer (e.g. Orbital / dual) |
|-------|--------------|----------------------------|
| LP fee side | **Fee on output** (D20) | Orbital: fee on **input** (oracle WAD) |
| PoolKey.fee | **`lpFeePips` static** (not dynamic flag) | Orbital: `DYNAMIC_FEE_FLAG` |
| Fee source | Deploy-time immutable | Orbital: Vault Fee Oracle `dexSwapFeeOfVault` |
| Admin / skim | None | Some peers have feeTo growth paths |
| Asset count | 4 StableSwap | Orbital 3 sphere; dual SE 2 CP |

Implementors: do **not** “align” fee-on-output to orbital without a PRD revision.

---

## 1. Scope (v1 DoD)

Ship production-first:

1. Bind four sorted ERC-20s + factory-supplied canonical `IPoolManager` + `lpFeePips` + `baseAmp` + four optional `IRateProvider`s.  
2. StableSwap pricing on **rate-scaled 1e18** reserves with witness legs.  
3. Six V4 pair doors → one shared Repo book.  
4. Fungible ERC-20 LP on the hook; custom `addLiquidity` / `removeLiquidity` / `zapIn`.  
5. Swaps via `beforeSwap` + `beforeSwapReturnDelta` (custom accounting).  
6. On-chain **`UniswapV4QuadStableSwapHookFactory`**: `deploy`, `deployWithMineNonce`, `ensurePairPools` (factory-attested only).  
7. Hermetic TestBase + Base + Robinhood forks green per §8–§9.

**Out of scope (v1 — PRD §2.3 / §11):** \(n \ne 4\); Balancer weights; SE buffering; amp ramp; fee skim; owner/pause; Permit2 on hook; native ETH; Facet/DFPkg; second CREATE3 system; subclassing peer hooks; shared TestBases with DETF Uni V4 packages; factory-seeded liquidity.

**Peer patterns (copy, do not inherit):**

| Asset | Path | Use |
|-------|------|-----|
| Buffer FactoryService | `…/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService.sol` | Mine loop, salt hash, idempotent deploy |
| Buffer Target | `…/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHookTarget.sol` | Permissions, take/sync/settle order |
| Dual Target | `…/standardExchange/dual/…Target.sol` | Multi-leg LP + reentrancy patterns |
| `HookMinerCreate3` | Crane `…/hooks/public/utils/HookMinerCreate3.sol` | `computeAddress`, `MAX_LOOP` |
| `BaseTokenWrapperHook` / `BaseHook` | Crane V4 base | **Behavioral settle only** — no inheritance |
| `BetterMath` / `FixedPointMathLib` | Crane utils | mulDiv, geometric mean helpers |
| `BetterEfficientHashLib` | Crane utils | salt `encodePacked(...)._hash()` |
| Balancer `IRateProvider` | Crane/Balancer port | `getRate() → uint256` @ 1e18 |

---

## 2. Current-state gap audit

| Item | Status (as of plan write) | Work |
|------|---------------------------|------|
| PRD v0.5.2 | Present | Law |
| This plan | **This file** | Implementor SoT |
| Production sources under `stable/quad/` | **None** (docs only) | Full greenfield build |
| TestBase / specs / forks | **None** | §8 |
| Orbital package | PRD only (no impl) | Do not depend on orbital sources |

---

## 3. File map (target)

```text
contracts/hooks/uniswap/v4/stable/quad/
  UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md
  UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # this file

  interfaces/
    IUniswapV4QuadStableSwapHook.sol
    IUniswapV4QuadStableSwapHookFactory.sol

  UniswapV4QuadStableSwapHookMath.sol
  UniswapV4QuadStableSwapHookRepo.sol
  UniswapV4QuadStableSwapHookCommon.sol
  UniswapV4QuadStableSwapHookTarget.sol
  UniswapV4QuadStableSwapHook.sol
  UniswapV4QuadStableSwapHook_FactoryService.sol
  UniswapV4QuadStableSwapHookFactory.sol

  TestBase_UniswapV4QuadStableSwapHook.sol   # gold TestBase (LOCKED path)
```

**Forbidden in package:** `*Facet.sol`, `*DFPkg.sol`, Solidity inheritance of BaseHook / BaseTokenWrapperHook / DeltaResolver, second CREATE3 infrastructure.

### 3.1 Tests (canonical names)

**Gold TestBase (LOCKED):** package-adjacent under this package. Specs under `test/foundry/…`.

```text
# Gold TestBase (LOCKED path)
contracts/hooks/uniswap/v4/stable/quad/TestBase_UniswapV4QuadStableSwapHook.sol

test/foundry/spec/hooks/uniswap/v4/stable/quad/
  UniswapV4QuadStableSwapHook_Math.t.sol
  UniswapV4QuadStableSwapHook_Deploy.t.sol
  UniswapV4QuadStableSwapHook_Factory.t.sol
  UniswapV4QuadStableSwapHook_Liquidity.t.sol
  UniswapV4QuadStableSwapHook_Zap.t.sol
  UniswapV4QuadStableSwapHook_Swap.t.sol
  UniswapV4QuadStableSwapHook_Rates.t.sol
  UniswapV4QuadStableSwapHook_Safety.t.sol
  UniswapV4QuadStableSwapHook_Reentrancy.t.sol

test/foundry/fork/base_main/hooks/uniswap/v4/stable/quad/
  UniswapV4QuadStableSwapHook_Base.t.sol

test/foundry/fork/robinhood_4663/hooks/uniswap/v4/stable/quad/   # LOCKED (not robinhood_main)
  UniswapV4QuadStableSwapHook_Robinhood.t.sol
```

---

## 4. Error surface (recommended)

Prefer custom errors; keep names stable for tests. Exact selectors are implementor choice if NatSpec-documented.

### 4.1 Hook / math

| Error | When |
|-------|------|
| `InvalidTokenOrder` | Tokens not strict ascending or duplicates |
| `InvalidToken` | Zero address, native ETH, decimals ∉ [6,18] |
| `InvalidFee` | `lpFeePips == 0` or `>= FEE_DENOMINATOR` |
| `InvalidAmp` | `baseAmp == 0` or `>= MAX_AMP` |
| `ZeroAmount` | Zero amountIn / amountOut / zero shares |
| `Slippage` | shares &lt; sharesMin; leg &lt; minAmounts; actual &gt; amounts on add |
| `NotZapEligible` | Zap before first-minted book or any reserve == 0 |
| `SwapNotLive` | `reserves[in] == 0` or `reserves[out] == 0` |
| `InvariantFailed` | Newton non-converge or post-state priceability fail (D38/D39) |
| `RateProviderFailed` | Bad staticcall / length ≠ 32 / rate == 0 (D74) |
| `InvalidRoute` / `InvalidPair` | tokenIn/out not bound or same token |
| CL / donate | Dedicated reverts on `beforeAddLiquidity`, `beforeRemoveLiquidity`, `beforeDonate` |
| `InvalidPoolKey` | `beforeInitialize`: wrong fee, tickSpacing, hooks, unbound currency |

### 4.2 Factory / deploy

| Error | When |
|-------|------|
| `HookMineExhausted` | Path A: no flag match within `MAX_LOOP` |
| `HookDeployCollision` | Predicted address occupied by unexpected code |
| `InvalidMineNonce` | Path B: nonce does not yield required flags |
| `NotFactoryHook` | `ensurePairPools` on non-attested hook (D59) |
| Ctor validation bubbles | Same as hook invalid token/fee/amp |

---

## 5. Architecture notes for implementors

### 5.1 Layer responsibilities

| File | Responsibility |
|------|----------------|
| **Math** | Pure: scale/descale, geometric mean4, `getD`, `getY`, fee gross-up/deduct, zap sizing helpers. **No storage, no external calls.** |
| **Repo** | Namespaced `Layout`: `reserves[4]`, reentrancy status, cached name/symbol if not immutable; ERC-20 balances/allowances via **same pattern as dual buffer hook** (Solady/Crane peer ERC-20 layout — pattern-copy, do not invent a third storage style). Slot e.g. `keccak256("indexedex.hooks.uv4.stable.quad.storage")` |
| **Common** | Immutables access, `tokenIndex`, `effectiveRate` (fail-closed), load scaled reserves, pull/push ERC-20, LP metadata build, guards |
| **Target** | `IHooks` callbacks + `addLiquidity` / `removeLiquidity` / `zapIn` execute; settle pattern-copy; previews |
| **Wire** | Thin CREATE3-mined contract: inherits Target/Common/ERC-20 surface; ctor validation + `Hooks.validateHookPermissions` |
| **FactoryService** | Salt, flags, mine loop, `deployHook`, `isExpectedHook` — **library / factory+tests only**; **not** on public hook ABI. Factory may expose binding views; hook self-describes tokens/fee/amp/providers as PRD §5.2 |
| **Factory** | Permissionless `deploy` / `deployWithMineNonce` / `ensurePairPools`; immutable `poolManager` + `create3Factory`; `isDeployedByFactory` |

### 5.2 Immutables (preferred on wire)

```text
poolManager, token0, token1, token2, token3,
lpFeePips, baseAmp, rateProvider0..3 (or address[4]),
baseScale0..3 and/or decimals0..3 (if not re-read)
```

**Ctor validation + metadata (LOCKED):**

1. Validate D6–D7, D15, D20; never initialize V4 pools (D61).  
2. **`decimals()` (each token) — fail-closed:** staticcall must succeed; decode `uint8`; require **∈ [6, 18]**. Revert `InvalidToken` otherwise (bad returndata, revert, out of range). Cache `decimals` / `baseScale` as preferred.  
3. **Per-leg display segment `s_i` (LOCKED — D45):**  
   - Prefer `token.symbol()` via staticcall when it succeeds with non-empty string returndata.  
   - **Soft-fallback:** if staticcall fails, empty, or non-string returndata → **`s_i` = last 4 hex characters of `token` address** (lowercase hex, **no** `0x` prefix).  
   - **Do not** revert deploy solely for missing/reverting `symbol()`.  
4. Build LP metadata (**LOCKED** shapes):  
   - `qsBody = s0 + "-" + s1 + "-" + s2 + "-" + s3`  
   - `symbol = truncate(LP_PREFIX + qsBody, LP_SYMBOL_MAX)` → e.g. `QS-USDC-USDT-DAI-USDS`  
   - `name = truncate("Quad Stable " + (LP_PREFIX + qsBody), LP_NAME_MAX)` → e.g. `Quad Stable QS-USDC-…`  
5. **Truncation rule (LOCKED):** if UTF-8 byte length exceeds the max, **hard cut** to `MAX` bytes (do not require ellipsis). Prefer cutting so the string remains valid UTF-8 (drop incomplete trailing code units). Cache both strings in Repo at ctor.  
6. `Hooks.validateHookPermissions(this, permissions)`.

### 5.3 Hook permissions (mine flags)

```text
BEFORE_INITIALIZE
| BEFORE_ADD_LIQUIDITY
| BEFORE_REMOVE_LIQUIDITY
| BEFORE_SWAP
| BEFORE_SWAP_RETURNS_DELTA
| BEFORE_DONATE
```

All `after*` and after-return-delta **off**. Address must encode these flags via CREATE3 mine.

### 5.4 Settle order (pattern-copy — D40)

Peer buffer/dual Target order (adapt for multi-asset book; **do not inherit**):

```text
beforeSwap (specified / unspecified amounts via V4 params):
  1. Identify tokenIn / tokenOut indices from PoolKey currencies + zeroForOne
  2. Gate swap-live (D72); load rates (D74); load reserves; compute amp, D
  3. Exact-in or exact-out StableSwap + fee (D20/D20a) → amountIn, amountOut
  4. Update Repo reserves BEFORE any external token movement
  5. Take input from PoolManager (amount owed by user path)
  6. Sync + transfer output token to PoolManager + settle
  7. Return BeforeSwapDelta matching taken/paid
  8. Require post-state invariant converges (D39)
```

**Delta convention (D41):** tests with real V4 router/quoter are law — all six directed pairs, exact-in and exact-out.

**Fee residual:** never transfer fee as a separate leg; leave un-sent output in `reserves[out]`.

### 5.5 Fee-on-output vs fee-on-input (implementation card)

```text
Exact-in:
  rawOut = curve out for full amountIn
  fee = ceil(rawOut * lpFeePips / 1e6)
  userOut = rawOut - fee
  reserves[in]  += amountIn
  reserves[out] -= userOut          // fee stays in reserves[out]

Exact-out:
  grossOut = ceil(amountOut * 1e6 / (1e6 - lpFeePips))
  curve uses grossOut depth
  reserves[out] -= amountOut        // (grossOut - amountOut) residual in book
  reserves[in]  += amountIn (ceil)
  require amountIn > 0
```

Orbital peer applies fee on **input** — do not mix formulas.

---

## 6. Math implementation card

### 6.1 Scaling (PRD §4.3)

```text
baseScale[i] = 10^(36 - decimals_i)
oracleRate   = provider==0 ? 1e18 : getRate()  // fail-closed
effectiveRate = baseScale * oracleRate / 1e18

scaleTo / scaleToUp / descale / descaleUp as PRD
```

### 6.2 Invariant \(D\) and target \(y\) (LOCKED — Ann + Newton)

**Normative continuous form (PRD §4.4):**
\[
A\, n^{n} \sum x_i + D = A\, D\, n^{n} + \frac{D^{n+1}}{n^{n} \prod x_i}
\]
with \(n = 4\), \(x_i\) rate-scaled 1e18 units.

**Normative iterative reference (LOCKED — stakeholder pin v1.3):**

- **Classic Curve StableSwap** (Vyper `StableSwap` / historical 4-coin pool style) Newton **`get_D` / `get_y`**.  
- **Not** Curve **StableSwapNG** (unless a future PRD revises).  
- **Not** Balancer V2/V3 StableMath.  
- Agents may re-implement in pure Solidity for fixed `n=4`; structure and constants must match classic Curve, not invent a third iteration.

**Code mapping (LOCKED — classic Curve iterative form):**

```text
N          = N_TOKENS = 4
A'         = baseAmp * AMP_PRECISION     // getCurrentAmp()
Ann        = A' * N                      // LOCKED: Curve Ann = amp * N_COINS (not A' * n^n)
A_PRECISION = AMP_PRECISION              // 100 — same role as Curve A_PRECISION in D iteration
```

- Implement Newton `get_D` / `get_y` for fixed `n=4` using **`Ann = A' * N`** and the standard iterative update that divides by `A_PRECISION` in the \(D\) step (same structure as classic Curve `get_D` / `get_y`).  
- **Do not** use `Ann = A' * n^n` in code. The PRD LaTeX \(A n^n\) is the continuous identity; production Curve maps amp into the iterative form via `Ann = amp * N`.  
- Inputs: rate-scaled `x[4]`, `A'`, `Ann`.  
- Max **`MAX_NR_ITERS = 255`**; stop when \(\lvert\Delta\rvert \le 1\); else revert `InvariantFailed`.  
- Zero or near-zero product of balances: solver must **revert**, not return garbage.  
- **NatSpec** must restate this Ann pin, classic Curve reference, and point at `Math.t.sol` fixtures as law.

**Required fixtures (Math.t.sol is law — Phase A exit):**

| ID | Setup (rate-scaled units) | Assert |
|----|---------------------------|--------|
| FIX-D1 | Equal balances `x = [1e24, 1e24, 1e24, 1e24]`, `baseAmp = 100` → \(A' = 10\_000\) | `getD` converges; **`\|D − S\| ≤ 1`** with \(S = 4e24\); re-run `getD` after noop is stable (bit-identical or same bound) |
| FIX-D2 | Mild imbalance e.g. `x = [2e24, 1e24, 1e24, 1e24]`, same \(A'\) | `getD` converges; `getY` for out-leg after +Δ on in-leg preserves \(D\) within **1 wei** on reconverge |
| FIX-Y1 | From FIX-D1 state: exact-in scale add on index 0, solve `getY` for index 1 | `y_out' < x[1]`; post-state `getD` converges |
| FIX-FEE1 | Fee helpers only: `lpFeePips = 500` | exact-in deduct + exact-out gross-up round-trip identities (pool-favoring ceils) |
| FIX-NR1 | Pathological balances / amp that cannot converge within 255 | reverts `InvariantFailed` |

Optional: one comparative vector vs classic Curve `n=4` reference within documented tolerance — **not** required if FIX-* green and NatSpec matches this pin.

### 6.3 Geometric mean4 (D26)

```text
// pairwise to reduce overflow; all args rate-scaled
geometricMean4(a,b,c,d) = sqrt( sqrt(a*b) * sqrt(c*d) )
// use BetterMath / FixedPointMathLib sqrt; document zero-input handling (first mint forbids zeros)
```

### 6.4 First / later mint / remove

Implement **exactly** PRD §4.6 (D23–D25). Subsequent mint uses **raw** reserve ratios (not rate-scaled min). First mint uses rate-scaled geometric mean.

### 6.5 Zap algorithm A — plan pins (PRD left open; **LOCKED** below)

These pins make Algorithm A **deterministic** and force `previewZapIn == zapIn`.

#### 6.5.1 Units & mutation model (LOCKED)

```text
W[i]        = working user raw amounts (starts as amounts[i] for positive legs)
workingR[i] = memory copy of Repo.reserves[i] at zap start
// rates r[i] loaded fail-closed once at start (D74); reused for whole path
wS[i]       = scaleTo(W[i], r[i])
rS[i]       = scaleTo(workingR[i], r[i])   // targets use workingR (starts = Repo)
```

**Mutation (LOCKED):**

- Internal rebalance swaps update **`W[]` and `workingR[]` only** (memory).  
- **Do not** write Repo, mint/burn LP, or transfer tokens during internal swap steps.  
- Tokens for positive legs are pulled **once up front** onto the hook; internal swaps are **accounting-only** until the single final commit (§6.5.5).  
- Public exact-in math (fee-on-output, same `getD`/`getY` as swaps) is applied to **`workingR`**, not live Repo, so multi-leg sequencing is pure and previewable.

#### 6.5.2 Eligibility

```text
zapEligible =
  totalSupply > MINIMUM_LIQUIDITY
  && reserves[0]>0 && reserves[1]>0 && reserves[2]>0 && reserves[3]>0
```

#### 6.5.3 Targets

```text
V = Σ wS[i]
S = Σ rS[i]
T_s[i] = V * rS[i] / S          // target scaled contribution of deposit
// ε: treat as matched if |wS[i] - T_s[i]| <= 1 (scaled unit)
```

If all legs match within ε → **skip swaps**, go to proportional mint sizing (balanced path).

#### 6.5.4 Surplus → deficit ordering + closed-form sizing (LOCKED)

1. Classify indices (on current `wS` / `T_s`):  
   - surplus if `wS[i] > T_s[i] + 1`  
   - deficit if `wS[i] + 1 < T_s[i]`  
2. **Surplus walk order:** ascending index `i = 0..3`.  
3. For each surplus `i`, **deficit walk order:** ascending index `j = 0..3`, `j != i`, only deficits.  
4. For each `(i,j)` pair while both still surplus/deficit:  
   - `need_j_scaled = T_s[j] - wS[j]`  
   - `wantUserOut_raw = descaleUp(need_j_scaled, r[j])` (soft target; pool-favoring descale for out leg).  
   - **Size `swapIn` with closed-form inverse only (LOCKED — no iterative refinement):**

```text
// Inverse of fee-on-output exact-in for a desired userOut (raw):
//   userOut = rawOut - ceil(rawOut * lpFeePips / FEE_DENOMINATOR)
// ⇒ gross rawOut needed for wantUserOut:
rawOutNeeded = ceil( wantUserOut_raw * FEE_DENOMINATOR
                     / (FEE_DENOMINATOR - lpFeePips) )

// Curve inverse on workingR (same getY path as public exact-out depth, without
// charging a second fee — fee already folded into rawOutNeeded):
//   y_out' = scaleTo(workingR[j], r[j]) - scaleToUp(rawOutNeeded, r[j])
//   x_in'  = getY(in=i, out reserve fixed at y_out', other legs from workingR, A', D)
//   amountInIdeal = descaleUp(x_in' - scaleTo(workingR[i], r[i]), r[i])
// Round amountInIdeal UP (pool-favoring) where intermediate ceils apply.

rawSurplus_i = descale( wS[i] - T_s[i], r[i] )   // floor surplus raw ≤ true surplus
swapIn = min( rawSurplus_i, amountInIdeal )
```

   - If `need_j` exceeds what surplus `i` can produce: **`swapIn = rawSurplus_i`** (full surplus of `i` toward `j`), then continue walk (do not partial-pro-rata split).  
   - **Unviable inverse → clamp (LOCKED — stakeholder pin v1.3):** if the ideal inverse would drain more than `workingR[j]` allows, `getY` reverts / fails to converge, `amountInIdeal == 0`, or post-swap working state would be non-priceable, **do not fail the whole zap**. Use this **single** closed-form bound (no binary search, no open solver):

```text
// Leave ≥ 1 scaled unit on the out-leg after fee-on-output exact-in:
//   max userOut (raw) such that scaleToUp(rawOutNeeded, r[j]) <= max(outScaled - 1, 0)
outScaled     = scaleTo(workingR[j], r[j])
maxOutScaled  = outScaled > 1 ? outScaled - 1 : 0   // if 0 → no positive viable out
// Invert fee-on-output for maxOutScaled (same rawOutNeeded / getY path as amountInIdeal above)
//   wantUserOut_raw_max from maxOutScaled via descale (pool-favoring as needed)
//   amountInIdeal_max = closed-form inverse for that want (same as § above)
maxViableIn   = min(rawSurplus_i, amountInIdeal_max)   // 0 if inverse fails / non-priceable

if maxViableIn == 0: swapIn = 0; skip this (i,j); continue walk
else: swapIn = min(swapIn, maxViableIn); then execute
```

     Remaining imbalance is absorbed later by proportional mint + refund (`sharesMin` still enforces user floor). Preview and execution **must** share the **same** pure clamp helper.  
   - If `swapIn == 0` break/skip inner for this pair.  
   - **Execute** exact-in StableSwap fee-on-output on **`workingR`** with input `swapIn`:  
     update `workingR[i]`, `workingR[j]`, `W[i] -= swapIn`, `W[j] += userOut` (same amounts public exact-in would yield on that snapshot).  
   - **Reclassify after every internal swap (LOCKED):** recompute `wS` from current `W`; re-evaluate surplus/deficit vs **current outer-pass** `T_s` (ε rules above) before choosing the next `(i,j)`. Do **not** keep a frozen surplus/deficit set for the whole pass.  
5. After full pass, if still unbalanced, **second full pass** only (max **2** outer passes). **`T_s` is recomputed only at the start of each outer pass** from current `W` and current `workingR`. Remaining imbalance absorbed by proportional min-share sizing (user accepts leftover in refund).

**ε:** 1 scaled unit (1e18 stable-unit wei).  
**Multi-deficit split:** sequential full-need toward each deficit in index order (not pro-rata split of one surplus across deficits in one step).  
**Forbidden:** multi-step `previewSwapExactIn` refinement loops for *target* sizing; binary search for `maxViableIn`; a second public sizing API; recompute of `T_s` mid-pass (only at outer-pass start).

#### 6.5.5 Mint after rebalance + single Repo commit (LOCKED)

```text
// After rebalance: W[i] = post-swap working user raw; workingR = post-swap pool snapshot
// supply = live totalSupply (unchanged during working steps)
shares = min_i ( W[i] * supply / workingR[i] )   // D24 formula vs post-rebalance workingR
// if any W[i]==0 while workingR[i]>0 → that leg contributes 0 → shares may 0 → revert ZeroAmount
actual[i] = ceil(shares * workingR[i] / supply)
require actual[i] <= W[i]
require shares >= sharesMin
```

**Commit (single state write — LOCKED):**

1. **Pull (execution only):** `transferFrom` full `amounts[i]` for positive legs into hook before working steps (preview skips transfers).  
2. **Working steps:** §6.5.3–6.5.4 on memory only (no Repo writes).  
3. **Commit Repo once:**  
   `Repo.reserves[i] = workingR[i] + actual[i]` for all `i`  
   (post-swap book + proportional mint legs).  
4. Mint `shares` to `to`; refund `W[i] - actual[i]` (and any unused original dust) to `msg.sender`.  
5. Require post-commit invariant converges (D39).  
6. Residual free inventory on hook after success: **0 preferred**; if ceil dust remains, **≤ 1 wei per token** documented in tests (same dust policy as preview).

#### 6.5.6 Preview

`previewZapIn` must execute the **identical** pure path (same ordering, ε, outer passes, **closed-form inverse**, working snapshot) against a memory copy of reserves — **no** state writes and **no** token transfers. Fail-closed rates same as execution. Return shares / used / refunds consistent with §6.5.5.

---

## 7. Implementation phases

Ordered for incremental green slices. After each phase: `forge build` green; phase tests green before claiming next.

### Phase 0 — Scaffold + constants + interfaces

1. Create file tree §3.  
2. Interfaces match PRD §5.2 / §5.5.3 (hook + factory).  
3. Constants library or Math/Common immutables per §0.1.  
4. Repo layout + reentrancy status.  
5. Wire stub with disabled hooks reverting “not implemented” except `beforeInitialize` skeleton.  
6. `forge build` green.

**Exit:** package compiles; no Facet/DFPkg; no BaseHook import.

### Phase A — Math library (pure unit tests)

1. scale/descale round-trip (6 and 18 decimals).  
2. geometricMean4.  
3. `getD` / `getY` with **§6.2 FIX-*** vectors (classic Curve StableSwap; `Ann = A' * N`; FIX-D1 `|D−S|≤1`).  
4. Exact-in/out fee helpers (output fee + gross-up) — FIX-FEE1.  
5. Newton exhaust / non-converge reverts — FIX-NR1.  
6. Optional: comparative fixture vs known Curve `n=4` reference within documented tolerance.

**Exit:** `UniswapV4QuadStableSwapHook_Math.t.sol` green with all required FIX-* cases; no external protocol deps.

### Phase B — FactoryService + hook ctor + permissions

1. `requiredFlags()` match §5.3.  
2. Salt material D33–D34; fingerprint = `keccak256(abi.encodePacked(p0,p1,p2,p3))` or peer hash of four addresses.  
3. Mine loop using `HookMinerCreate3.MAX_LOOP` (160_444); idempotent expected return; collision revert.  
4. Hook ctor: D6–D7, D15, D20; **decimals fail-closed**; **symbol soft-fallback**; LP name/symbol with **§5.2 caps**; `Hooks.validateHookPermissions`.  
5. `isExpectedHook` views: pm, four tokens, fee, amp, four rate providers, code.

**Exit:** hermetic CREATE3 deploy of empty hook (no pools yet) via FactoryService under test operator; metadata tests (missing symbol still deploys; bad decimals reverts).

### Phase C — On-chain factory (six doors)

1. Factory ctor: `(create3Factory, poolManager)` immutables (D67).  
2. `deploy` path A: mine + create3 + initialize ×6 (D54–D58).  
3. `deployWithMineNonce` path B: verify flags, no search (D62).  
4. `ensurePairPools` factory-attested only (D59).  
5. Events: `HookDeployed` only on new code (D68); `PairPoolsEnsured`.  
6. `pairPoolKeys` / `predictHookAddress` / `isDeployedByFactory`.  
7. Token sort enforced; zero fee/amp reject; unsorted revert.

**Exit:** `Factory.t.sol` — non-operator EOA can call `deploy` **after** factory is create3 operator; six pools exist; idempotent redeploy.

### Phase D — Liquidity (add / remove)

1. `nonReentrant` on LP surfaces (D30).  
2. First mint D23/D26/D47; open doors allowed with zero prior swaps (D70).  
3. Subsequent mint D24; mins + sharesMin.  
4. Remove D25; **no** post invariant require; accounting before transfers.  
5. Previews D27–D28; donations do not change reserves (D36).  
6. Post add: invariant converge (D39).

**Exit:** `Liquidity.t.sol` green including mixed decimals 6/6/18/18.

### Phase E — Swaps (all six pairs)

1. `beforeInitialize` gates (D31/D48).  
2. CL add/remove + donate revert.  
3. Swap-live D72; inert book reverts.  
4. Exact-in / exact-out both directions × 6 pairs.  
5. Fee residual in reserves; preview == execution.  
6. Exact-out zero-input reverts; zero amount reverts.  
7. Real V4 router or PoolManager unlock test harness (production-first).

**Exit:** `Swap.t.sol` green; delta convention proven (D41).

### Phase F — Zap-in

1. Gate `NotZapEligible`.  
2. Algorithm A with §6.5 pins: surplus→deficit order, **closed-form inverse**, **clamp = leave ≥1 scaled unit on out-leg**, **reclassify after every swap**, **working-snapshot until single Repo commit**, `sharesMin` only.  
3. Single-leg and multi-leg; balanced skip-swap path.  
4. Case: inverse would overshoot out-leg → clamp / skip pair; zap still succeeds if `sharesMin` met.  
5. `previewZapIn == execution` (**≤ 1 wei** max documented).  
6. Internal swaps = public exact-in math on `workingR`; no mid-zap Repo writes; post-commit invariant.  
7. Refund unused; residual free inventory **0 or ≤ 1 wei/token**.

**Exit:** `Zap.t.sol` green.

### Phase G — Rates + safety

1. `IRateProvider` mock **only as non-SUT harness** (mintable rate oracle contract) — never mock hook/math.  
2. Fail-closed: revert / zero rate / bad returndata (D74) on swap/add/zap/previews that read rates.  
3. `address(0)` provider → decimal scale only.  
4. Prefer \(A \ge 10\) ops guidance in NatSpec; still allow low A in bounds for tests if desired.  
5. Witness-zero stress: if constructible, swap with zero witness reverts cleanly or succeeds only if solver converges (document).

**Exit:** `Rates.t.sol` + `Safety.t.sol` green.

### Phase H — Reentrancy + adversarial

1. Hostile ERC-20 as a configured bound token **only** for attack tests (IndexedEx adversarial skill).  
2. Reenter `addLiquidity` / `removeLiquidity` / `zapIn` → lock.  
3. Donation attack does not inflate pricing reserves.  
4. Optional: attempt CL liquidity, wrong init keys.

**Exit:** `Reentrancy.t.sol` green.

### Phase I — Forks (Base + Robinhood)

1. Bootstrap factory with **canonical chain PoolManager** (see §7.1 address table — verify on-chain at implement time).  
2. Grant factory operator on ecosystem `create3Factory` as in production ops.  
3. Deploy four **mintable test tokens** on fork if needed (D71).  
4. Path B preferred for gas; smoke path A optional.  
5. First mint → one pair swap → remove smoke.

**Exit:** both fork suites green; equal DoD priority.

### Phase J — Polish

1. NatSpec: fee-on-output callout; rate fail-closed; no admin.  
2. `forge build --sizes`; externalize pure Math if size pressure.  
3. Remove any `console.log`.  
4. Confirm no mock SUT; no `new` hook without CREATE3 path in production factory.  
5. Cross-check PRD §8 checklist.

---

## 7.1 Factory bootstrap & PoolManager addresses

**Ops (once per chain):**

```text
1. Resolve CANONICAL_V4_POOL_MANAGER for chain (official Uni V4 singleton).
2. Deploy UniswapV4QuadStableSwapHookFactory via CREATE3 with:
     create3Factory = ecosystem CREATE3 factory
     poolManager    = CANONICAL_V4_POOL_MANAGER
3. Grant factory address operator (or owner) on create3Factory.
4. Publish factory; users never pass PoolManager.
```

**Hermetic:** deploy Crane/test `PoolManager` once; pass **only** into factory ctor; still immutable thereafter.

**Address table (implementor must re-verify before mainnet scripts; not a substitute for on-chain checks):**

| Chain | Chain ID | Notes |
|-------|----------|--------|
| Base mainnet | 8453 | Use official Uniswap V4 PoolManager deployment for Base |
| Robinhood Chain | 4663 | Crane notes V4 PM often shares CREATE2 addresses with mainnet — **verify** on fork before DoD |
| Hermetic / Anvil | local | Test-deployed PM only |

Pin concrete addresses in deploy scripts / constants when known; do **not** invent a second production PM; do **not** use `feeOracle.feeTo()` (D67).

---

## 8. Testing plan

### 8.1 Rules

1. **No mock of SUT:** hook, Math (as library under test is real), Repo, FactoryService, Factory, PoolManager, create3Factory.  
2. Allowed harnesses: mintable ERC-20; simple `IRateProvider` harness; hostile reentrancy ERC-20 for adversarial only.  
3. Real V4 PoolManager (Crane hermetic or fork).  
4. Gold TestBase: package-adjacent `TestBase_UniswapV4QuadStableSwapHook` (`§3.1`).  
   - Inherit `CraneTest` → `IndexedexTest` (if create3/manager needed).  
   - **Peer pattern-copy (LOCKED — stakeholder pin v1.3):**  
     - **TestBase:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol`  
     - **Production settle/mine peers:** dual package under `contracts/hooks/uniswap/v4/standardExchange/dual/` (`…Target.sol`, `…_FactoryService.sol`) + single buffer Target for settle order if dual omits a step.  
     - **Do not** hunt for a TestBase under `contracts/hooks/.../dual/` (there is none).  
     - **Do not** subclass dual production types; copy structure/helpers only.  
     - Cite the dual TestBase path in this package’s TestBase NatSpec at Phase 0.  
   - **Fork path convention (LOCKED):** `test/foundry/fork/base_main/hooks/uniswap/v4/stable/quad/` and `test/foundry/fork/robinhood_4663/hooks/uniswap/v4/stable/quad/` (match dual SE fork layout; not `robinhood_main` unless that tree is later unified).  
5. **preview == execution** on swap, LP, zap (**≤1 wei** documented).  

### 8.2 Minimum DoD matrix

| ID | Case | PRD |
|----|------|-----|
| M1 | scale/descale; geometricMean4; getD/getY **§6.2 FIX-*** (`Ann = A' * N`) | D17, D26, D38 |
| M2 | Fee exact-in deduct / exact-out gross-up edge (FIX-FEE1) | D20, D20a |
| F1 | Path A deploy: hook + **six** pools | D54–D58, D62 |
| F2 | Path B `deployWithMineNonce` | D62 |
| F3 | Non-operator EOA deploy (factory is operator) | D52 |
| F4 | Unsorted / duplicate tokens revert | D7 |
| F5 | Zero fee / zero amp / bad decimals revert | D6, D15, D20 |
| F5a | Missing/reverting `symbol()` still deploys (**last 4 hex** fallback); name = **`Quad Stable QS-…`**; length caps 32/64 | D45, §5.2 |
| F6 | Idempotent redeploy; `HookDeployed` only once | D35, D68 |
| F7 | `ensurePairPools` factory-only; foreign hook reverts | D59 |
| F8 | `pairPoolKeys` match D55–D56 | D55, D56 |
| F9 | Mine flags match permissions | §5.3 |
| I1 | `beforeInitialize` wrong fee / tickSpacing / unbound token | D31, D48 |
| I2 | CL add/remove + donate revert | D10, D11 |
| L1 | First mint all four; min liq to `address(0)` | D23, D47 |
| L2 | First mint with open doors, no prior swaps | D70 |
| L3 | Subsequent proportional; mins + sharesMin | D24 |
| L4 | Remove pro-rata; mins | D25 |
| L5 | Mixed decimals 6/6/18/18 | D6 |
| L6 | Donation does not change Repo pricing | D36 |
| S0 | Inert book: swaps revert (doors may exist) | D70, D72 |
| S1–S6 | Exact-in both directions on all six pairs | D19, D41 |
| S7–S12 | Exact-out both directions on all six pairs | D20a, D41 |
| S13 | preview == exec (≤1 wei) | D27 |
| S14 | Exact-out zero input reverts | D20a, D29 |
| Z1 | Single-leg zap when eligible | D22a, D73 |
| Z2 | Multi-leg zap; balanced skip path; closed-form sizing | §6.5 |
| Z3 | Zap reverts pre-live / not eligible | D23 |
| Z4 | `previewZapIn == zapIn` (≤1 wei; working-snapshot path) | D27, D73 |
| Z5 | No mid-zap Repo write; single commit reserves = workingR + actual | §6.5.1, §6.5.5 |
| Z6 | Unviable inverse clamps / skips pair; preview==exec; sharesMin still enforced | §6.5.4 |
| R1 | Rate provider leg scales correctly | D17, D69 |
| R2 | Fail-closed bad/zero/revert provider | D74 |
| R3 | `address(0)` providers decimal-only | D17 |
| A1 | Reentrancy on add/remove/zap | D30 |
| K1 | Base fork smoke factory + mint + swap | D43, D71 |
| K2 | Robinhood fork smoke | D43, D71 |

### 8.3 Suggested TestBase helpers

```text
_deployFactory(create3, pm)
_deployQuad(tokens[4], fee, amp, providers[4], namespace) → (hook, keys[6])
_fund(user, amounts[4])
_addLiquidityFirst(...)
_addLiquidityLater(...)
_swapExactIn(poolKey, zeroForOne, amountIn, ...)
_assertPreviewSwap(...)
_assertSixPoolsInitialized(hook)
```

---

## 9. Definition of Done (plan exit)

Matches PRD §8; expand with plan artifacts:

- [ ] All §3 production files present; no Facet/DFPkg; no BaseHook inheritance.  
- [ ] FactoryService mine + Factory paths A+B + ensure; six doors; D67 PM law.  
- [ ] Math pure; classic Curve StableSwap Newton; **`Ann = A' * N`** + §6.2 FIX-* green (FIX-D1 **`|D−S|≤1`**); NR bounds in NatSpec.  
- [ ] LP first/later/remove + zap A with §6.5 pins (closed-form inverse, **≥1 scaled out-leg clamp**, reclassify after each swap, working-snapshot commit); `sharesMin` only.  
- [ ] Package-adjacent gold TestBase under `stable/quad/`; peer = **`TestBase_UniswapV4DualSEBCPHook`** documented in NatSpec.  
- [ ] Ctor: decimals fail-closed; symbol soft-fallback **last 4 hex**; name **`Quad Stable QS-…`**; caps 32/64.  
- [ ] All six pairs exact-in/out; preview fidelity; pair-leg swap gate.  
- [ ] Rate fail-closed; IRateProvider-only public surface.  
- [ ] Safety: non-zero fee, zero-input exact-out, post priceability, no native ETH, donation ignore.  
- [ ] Hermetic + Base + Robinhood green.  
- [ ] `forge build --sizes` reviewed; no debug logs.  
- [ ] This plan’s phase exit criteria all met.

---

## 10. Threat notes (implementor awareness — not new product law)

| Risk | Mitigation in law |
|------|-------------------|
| Broken rate oracle bricks rate-using paths | Fail-closed D74; immutable binding → abandon instance |
| Permissionless factory grief (bad A/fee/tokens) | User chooses binding; no protocol bailout; validation gates |
| Mid-zap MEV | `sharesMin` only; user sizes via preview |
| Zap preview ≠ exec | Single closed-form inverse + shared clamp helper + identical working path |
| Zap inverse overshoots liquidity | Clamp via leave ≥1 scaled unit on out-leg or skip pair; `sharesMin` is user floor |
| Fee-on-output / zap refund dust | Pool-favoring ceils; tests document ≤1 wei |
| Long / missing token symbols | Last-4-hex fallback + `Quad Stable QS-…` + hard-cut 32/64 |
| Zero witness / drained leg | Swap gate pair-only; solver reverts if non-priceable |
| Donation inflation | Repo reserves ignore stray balances |

---

## 11. Suggested build order (summary)

```text
Phase 0  Scaffold + interfaces
Phase A  Math pure + unit tests
Phase B  FactoryService + hook ctor/flags
Phase C  On-chain factory + six pools
Phase D  addLiquidity / removeLiquidity
Phase E  beforeSwap all pairs
Phase F  zapIn algorithm A
Phase G  rates + safety
Phase H  reentrancy / adversarial
Phase I  Base + Robinhood forks
Phase J  polish + size + PRD §8 check
```

---

## 12. Revision log

| Version | Date | Notes |
|---------|------|-------|
| **v1.0** | 2026-08-03 | Initial plan from PRD **v0.5.2**. Pins `MAX_LOOP = 160_444`; zap surplus→deficit ordering; fee-on-output vs orbital note; factory bootstrap; full phase + test matrix. |
| **v1.1** | 2026-08-03 | Plan refinement locks: (1) zap sizing = **closed-form inverse of exact-in only** (no iterative refinement); (2) zap mutation = **memory working snapshot until single Repo commit**; (3) Math **`Ann = A' * N`** Curve-style + FIX-* fixtures; (4) gold TestBase path = **package-adjacent** `stable/quad/`. Dust ≤1 wei aligned; F9 → §5.3; Z5 commit assert. |
| **v1.2** | 2026-08-03 | (1) Zap unviable inverse → **clamp** to max viable exact-in or skip pair (no whole-zap fail); (2) ctor **decimals fail-closed**, **symbol soft-fallback**; (3) LP **symbol ≤32 / name ≤64** hard-cut; (4) hermetic TestBase peer = **dual SE buffer** pattern-copy. Matrix F5a, Z6. |
| **v1.3** | 2026-08-03 | Stakeholder pin pass: (1) `maxViableIn` = **leave ≥1 scaled unit on out-leg** closed-form; (2) Newton = **classic Curve StableSwap** (not NG/Balancer); FIX-D1 **`|D−S|≤1`**; (3) reclassify surplus/deficit **after every internal swap**; `T_s` only at outer-pass start; (4) LP symbol fallback **last 4 hex**; name **`Quad Stable QS-…`**; (5) TestBase peer path = **`TestBase_UniswapV4DualSEBCPHook`**; fork dir **`robinhood_4663`**. |

---

**End of plan — UniswapV4QuadStableSwapHook (v1.3 / PRD v0.5.2)**
