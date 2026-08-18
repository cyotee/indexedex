# Implementation & Test Plan: Uniswap V4 Weighted Swap Hook

**PRD (product law SoT):** [`UNISWAP_V4_WEIGHTED_SWAP_HOOK_PRD.md`](./UNISWAP_V4_WEIGHTED_SWAP_HOOK_PRD.md) (**v0.2.0**)  
**This plan (implementor SoT once accepted):** phases, file map, math pins, ABI names, salt encoding, settle notes, test matrix.  
**Package:** `contracts/hooks/uniswap/v4/weighted/`  
**Date:** 2026-08-03  
**Status:** **Canonical plan v1.0** — written from PRD v0.2.0 + plan-level pins O1–O5. Greenfield package (no production sources yet). **Plan-only; no product code in this file.**

**Authority**

| Layer | Role |
|-------|------|
| **PRD v0.2.0** | Product law (D1–D73, Q1–Q19, §0–§12). **PRD wins** on conflict |
| **This plan** | Implementor SoT for phases, files, **O1–O5 pins**, ABI names, salt encoding, test IDs |
| Peer packages / Balancer `WeightedMath` | Pattern and math references only — **not** deploy law; do not copy CREATE2 / BaseHook / console.log |

**Process rule:** If this plan and the PRD disagree, **PRD wins** and this plan must be patched. Do **not** reopen locked PRD decisions without a PRD revision. After each phase: `forge build` green and that phase’s tests green before the next.

**Read order for implementors**

1. PRD §0 terminology + §1.1 user story + canonical law index  
2. PRD §3 locked decisions (D1–D73) + Q1–Q19  
3. **This plan** §0–§6 (scope, layout, phases, math/LP pins)  
4. PRD §4–§5 for normative detail when implementing a phase  
5. This plan §7–§9 for tests and DoD exit  

**Methodology skills:** `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `indexedex-adversarial-testing`, `crane-uniswap` / `uniswap-v4-hooks` / `v4-security-foundations` (permissions + NoOp deltas — **behavioral** only; no BaseHook inheritance).

---

## 0. Locked decisions (copy — PRD is source of truth)

| Topic | Decision |
|-------|----------|
| Product | **`UniswapV4WeightedSwapHook`** — CREATE3 single contract (IHooks + ERC-20 LP + EIP-2612) |
| Package path | `contracts/hooks/uniswap/v4/weighted/` |
| Shape | **Repo + Common + Math + Target + wire** + **FactoryService** + **on-chain Factory**. No Facet/DFPkg |
| Math | Balancer **WeightedMath** + BasePoolMath-equivalent joins/exits; **not** StableSwap / Orbital |
| Weights | **Option A** global immutable vector; each \(w_i \ge 1\mathrm{e}16\); \(\sum w_i = 1\mathrm{e}18\) |
| Assets | **\(n \in [2, 8]\)** fixed at deploy; strict address ascending `tokens[0] < … < tokens[n-1]` |
| Pool doors | Factory creates **all** \(\binom{n}{2}\) pairs; `fee = DYNAMIC_FEE_FLAG`; `tickSpacing = 1`; **factory doors only** thereafter (D68) |
| Inventory | Repo **`reserves[i]`** only (donations ignored) |
| Trading fee | Live **`dexSwapFeeOfVault`**; fee on **input**; residual in input reserve; **0 OK** |
| Protocol growth | Live **`usageFeeOfVault`** → mint LP to live **`feeTo`** on add **and** remove; **`rootK = V`** (full) |
| Partial book | Allowed via seed / first mint (\(n \ge 3\)); **not** via full-book exit zeroing (D67) |
| feeOracle | **Factory-immutable**; all hooks from a factory share it |
| Deploy | Ecosystem **`create3Factory`** + **off-chain-mined `mineNonce`**; primary API **`deployWithMineNonce`** |
| LP ops | **Deadline** required; exit burns **`msg.sender` only**; joins mint to **`to`** |
| Permit2 | Required on LP **pull** paths; packing **peer Orbital PRD §5.6** (this plan §6.8 freezes weighted deltas) |
| Access | Fully permissionless on hook and factory deploy; no owner/pause/weight admin |
| Inheritance | **No** `BaseHook` / `BaseTokenWrapperHook` / `DeltaResolver` — full pattern-copy |
| Forks | **Base + Robinhood Chain (4663)** equal DoD after hermetic; mintable test tokens OK |

### 0.1 Plan-pinned constants

| Constant | Value | Notes |
|----------|-------|-------|
| `MIN_N` / `MAX_N` | `2` / `8` | Deploy-time bounds |
| `MIN_WEIGHT` | `1e16` | 1% WAD |
| `ONE` / `WAD` | `1e18` | Weight sum target; rate precision |
| `MINIMUM_LIQUIDITY` | `1000` | LP wei → `address(0)` |
| `TICK_SPACING` | `1` | All factory doors |
| `MAX_IN_RATIO` / `MAX_OUT_RATIO` | `30e16` | Balancer `_MAX_IN_RATIO` / `_MAX_OUT_RATIO` |
| `MAX_INVARIANT_RATIO` | `300e16` | Balancer growth cap |
| `MIN_INVARIANT_RATIO` | `70e16` | Balancer shrink floor |
| `FEE_DENOMINATOR` | `100_000` | Growth algebra (`ownerFeeShare` branch) |
| `RATE_PRECISION` | `1e18` | |
| `DEFAULT_SALT_NAMESPACE` | `"uv4-weighted-swap-hook-"` | D46 |
| `LP_PREFIX` | `WGT-` | Auto symbol body |
| `LP_SYMBOL_MAX` | **32** | UTF-8 hard cut |
| `LP_NAME_MAX` | **64** | UTF-8 hard cut |
| `MAX_LOOP` | **`HookMinerCreate3.MAX_LOOP`** | Off-chain mine tooling only (not on-chain DoD path) |
| CREATE3 `deployer` | **`address(create3Factory)`** | **O1 pin** — peer dual/quad FactoryService |
| Preview residual | Prefer **exact**; **≤ 1 wei** only if listed | Document per-path if any |

### 0.2 Plan pins for PRD residual opens (O1–O5)

| Open | Pin (this plan) |
|------|-----------------|
| **O1** Salt + CREATE3 deployer | See §6.7: `hookSalt` via `BetterEfficientHashLib._hash()` on packed preimage; prediction `deployer = address(create3Factory)` |
| **O2** First-mint shares | **`shares = V − MINIMUM_LIQUIDITY`** with `V = computeInvariantDown(weights, scaledAmounts)`; require `V > MINIMUM_LIQUIDITY` |
| **O3** ABI names | §5.2 canonical function names (Balancer-flavored, compact) |
| **O4** Partial seed/prop shares | §6.5: interim \(k\) product; `shares = supply' * (k_after − k_before) / k_before` (floor); prop min-ratio on positive legs in rate-scaled units |
| **O5** Join recipient | All joins take **`address to`**; mint user LP to `to`. Exits take **`address to`** for token payout; burn **`msg.sender`** only |

### 0.3 Deliberate divergences from peer packages

| Topic | This package | Peer |
|-------|--------------|------|
| Curve | Weighted product \(V = \prod b_i^{w_i}\) | Orbital sphere; Quad StableSwap \(A\) |
| Asset count | Variable 2–8 | Orbital 3; Quad 4 |
| Trading fee | Live oracle WAD, **input** residual | Quad: static pips, **output** residual |
| PoolKey.fee | **`DYNAMIC_FEE_FLAG`** | Quad: static `lpFeePips` |
| Growth `rootK` | **`V` literal** (full) | Orbital: `cbrt(product)` full / sum interim |
| Partial entry | Seed / first mint only | Orbital allows exit zeroing modes differently |
| CREATE3 | Ecosystem factory + off-chain mineNonce | Orbital: factory local CREATE3 + user salt |
| Zap | **None** | Quad: zap-in DoD |

Implementors: do **not** “align” fee-on-input to quad, or `rootK` to orbital cbrt, without a PRD revision.

---

## 1. Scope (v1 DoD)

Ship production-first:

1. Bind \(n \in [2,8]\) sorted ERC-20s + factory-supplied canonical `IPoolManager` + factory-immutable `IVaultFeeOracleQuery` + weights + optional `IRateProvider`s.  
2. Balancer Weighted pricing on **rate-scaled 1e18** reserves with global weights.  
3. All \(\binom{n}{2}\) V4 pair doors → one shared Repo book. Doors are opened after `deployVault` by `deployPair` for every `i<j`, then `finalizeInitialization`. `postDeploy` does not initialize pools. See staged init PRD + plan.  
4. Fungible ERC-20 LP on the hook; custom join/exit surface (full Balancer when full book; restricted partial).  
5. Swaps via `beforeSwap` + `beforeSwapReturnDelta` (custom accounting).  
6. Dual fee channels: trading residual + protocol growth (`kLast` / dual mode).  
7. Hook diamond package: `deployVault` (bootstrap) then `deployPair` × \(C(n,2)\) then `finalizeInitialization`. No `ensurePairPools` / `ensureAllPairPools`. See staged init PRD + plan.  
8. Permit2 + transferFrom LP pulls; deadline; msg.sender burn.  
9. Hermetic TestBase + Base + Robinhood forks green per §8–§9.

**Out of scope (v1 — PRD §2.3):** \(n \notin [2,8]\); LBP weight ramps; SE/Morpho buffering; native ETH; Facet/DFPkg; second CREATE3 system; on-chain mine loop DoD; subclassing peer hooks; shared TestBases with DETF Uni V4; factory-seeded liquidity; full-book exit zeroing a leg; extra non-factory PoolKeys.

**Peer patterns (copy, do not inherit):**

| Asset | Path | Use |
|-------|------|-----|
| Dual FactoryService | `…/standardExchange/dual/…_FactoryService.sol` | Salt hash, mineNonce, idempotent deploy, `isExpectedHook` |
| Dual / single Target | `…/standardExchange/dual|single/…Target.sol` | take / sync / transfer / settle order |
| Dual growth / ConstProdUtils | Crane `ConstProdUtils` + dual D57 | Protocol LP algebra |
| Orbital PRD §5.6 | Permit2 packing spirit | Weighted packing §6.8 |
| Quad PRD / plan | Multi-door factory + rate fail-closed | Doors, rates, TestBase layout |
| `HookMinerCreate3` | Crane `…/hooks/public/utils/HookMinerCreate3.sol` | `computeAddress`, flags, off-chain mine |
| Balancer `WeightedMath` | Crane `…/balancer/v3/…/WeightedMath.sol` | Swap + invariant |
| Balancer `BasePoolMath` | Crane `…/vault/…/BasePoolMath.sol` | Unbalanced join/exit reference |
| Balancer `IRateProvider` | Crane/Balancer port | `getRate() → uint256` @ 1e18 |
| `LPFeeLibrary` | Crane Uni V4 | `DYNAMIC_FEE_FLAG`, `OVERRIDE_FEE_FLAG` |
| `BetterMath` / `FixedPointMathLib` | Crane utils | mulDiv, overflow helpers |
| `BetterEfficientHashLib` | Crane utils | salt `encodePacked(...)._hash()` |

---

## 2. Current-state gap audit

| Item | Status (as of plan write) | Work |
|------|---------------------------|------|
| PRD v0.2.0 | Present | Law |
| This plan | **This file** | Implementor SoT |
| Production sources under `weighted/` | **None** (docs only) | Full greenfield build |
| TestBase / specs / forks | **None** | §8 |
| Orbital / quad production sources | May be partial or greenfield | Pattern-copy peers only; do not depend on unfinished orbital sources |

---

## 3. File map (target)

```text
contracts/hooks/uniswap/v4/weighted/
  UNISWAP_V4_WEIGHTED_SWAP_HOOK_PRD.md
  UNISWAP_V4_WEIGHTED_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # this file

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

  TestBase_UniswapV4WeightedSwapHook.sol   # gold TestBase (package-adjacent)
```

**Forbidden in package:** `*Facet.sol`, `*DFPkg.sol`, Solidity inheritance of BaseHook / BaseTokenWrapperHook / DeltaResolver, second CREATE3 infrastructure.

### 3.1 Tests (canonical names)

```text
# Gold TestBase (LOCKED path)
contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol

test/foundry/spec/hooks/uniswap/v4/weighted/
  UniswapV4WeightedSwapHook_Math.t.sol
  UniswapV4WeightedSwapHook_Deploy.t.sol
  UniswapV4WeightedSwapHook_Factory.t.sol
  UniswapV4WeightedSwapHook_Liquidity.t.sol
  UniswapV4WeightedSwapHook_Partial.t.sol
  UniswapV4WeightedSwapHook_Swap.t.sol
  UniswapV4WeightedSwapHook_Fees.t.sol
  UniswapV4WeightedSwapHook_Preview.t.sol
  UniswapV4WeightedSwapHook_Rates.t.sol
  UniswapV4WeightedSwapHook_Permit2.t.sol
  UniswapV4WeightedSwapHook_Safety.t.sol
  UniswapV4WeightedSwapHook_Reentrancy.t.sol

test/foundry/fork/base_main/hooks/uniswap/v4/weighted/
  UniswapV4WeightedSwapHook_Base.t.sol

test/foundry/fork/robinhood_4663/hooks/uniswap/v4/weighted/   # LOCKED path convention
  UniswapV4WeightedSwapHook_Robinhood.t.sol
```

---

## 4. Error surface (recommended)

Prefer custom errors; keep names stable for tests. Exact selectors are implementor choice if NatSpec-documented.

### 4.1 Hook / math

| Error | When |
|-------|------|
| `InvalidTokenOrder` | Tokens not strict ascending or duplicates |
| `InvalidToken` | Zero address, native ETH, decimals ∉ [6,18] |
| `InvalidWeight` | \(w_i < MIN_WEIGHT\) or \(\sum w_i \ne 1\mathrm{e}18\) |
| `InvalidN` | \(n \notin [2,8]\) or array length mismatch |
| `ZeroAmount` | Zero amountIn / amountOut / shares |
| `DeadlineExpired` | `block.timestamp > deadline` |
| `Slippage` | shares &lt; sharesMin; leg &lt; amountsMin |
| `NotFullBook` | Caller used full Balancer unbalanced/single path while partial |
| `PartialPathRestricted` | Forbidden op under PartialInterim |
| `WouldZeroReserve` | Full-book exit would set any `reserves[i] == 0` (D67) |
| `SwapNotLive` | `reserves[in] == 0` or `reserves[out] == 0` |
| `MaxInRatio` / `MaxOutRatio` | Exceeds 30% balance caps |
| `MaxInvariantRatio` / `MinInvariantRatio` | Unbalanced join/exit bounds |
| `InvalidFeeWad` | Trading or usage fee ≥ 1e18 (where validated) |
| `RateProviderFailed` | Bad staticcall / length ≠ 32 / rate == 0 |
| `InvalidPair` | tokenIn/out not bound or same token |
| `InvalidPoolKey` | `beforeInitialize`: wrong fee, tickSpacing, hooks, unbound currency |
| `NotPoolManager` | Non-PM caller into hook callbacks |
| CL / donate | Dedicated reverts on `beforeAddLiquidity`, `beforeRemoveLiquidity`, `beforeDonate` |
| `Reentrancy` / lock peer | Nested LP or swap |
| `InsufficientLP` | Remove shares &gt; balance of msg.sender |
| `InvalidPermit2Data` | Wrong mode/length/order/sig |

### 4.2 Factory / deploy

| Error | When |
|-------|------|
| `InvalidMineNonce` | Nonce does not yield required hook flags |
| `HookDeployCollision` | Predicted address occupied by unexpected code |
| `NotFactoryHook` | `ensurePairPools` on non-attested hook |
| `ZeroAddress` | Zero create3Factory / pm / feeOracle / token |
| Ctor validation bubbles | Same as hook invalid token/weight/n |

---

## 5. Architecture notes for implementors

### 5.1 Layer responsibilities

| File | Responsibility |
|------|----------------|
| **Math** | Pure: scale/descale, WeightedMath wrappers, join/exit share math, growth algebra, interim \(k\). **No storage, no external calls.** |
| **Repo** | Namespaced `Layout`: dynamic `reserves` length \(n\), `kLast`, `kLastMode`, reentrancy, name/symbol cache, ERC-20 balances/allowances/nonces (Uni V2–style — **must** allow balance on `address(0)`). Slot e.g. `keccak256("indexedex.hooks.uv4.weighted.swap.storage")` |
| **Common** | Immutables access, `tokenIndex`, `effectiveRate` (fail-closed), load scaled reserves, pull/push ERC-20, fee oracle reads, LP metadata, guards, deadline |
| **Target** | `IHooks` callbacks + join/exit execute + settle pattern-copy + previews |
| **Wire** | Thin CREATE3 contract: Target/Common/ERC-20/EIP-2612; ctor validation + `Hooks.validateHookPermissions` |
| **FactoryService** | Salt, flags, `deployHookWithMineNonce`, `isExpectedHook`, `predictHookAddress` — **library / factory+tests only**; not on public hook ABI |
| **Factory** | Permissionless `deployWithMineNonce` / `ensurePairPools`; immutables `create3Factory`, `poolManager`, `feeOracle`; `isDeployedByFactory` |

### 5.2 Canonical ABI names (O3 pin)

#### Hook views

```text
poolManager(), feeOracle(), numTokens(), tokens(), token(uint256)
getNormalizedWeights(), rateProvider(uint256), effectiveRate(uint256)
reserves(), reserveOf(address)
dexSwapFee(), usageFee(), feeTo(), kLast(), kLastMode(), isFullBook()
name(), symbol(), decimals() // 18
```

#### Swap previews

```text
previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn) → amountOut
previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut) → amountIn
```

#### LP previews (growth-aware)

```text
previewJoinProportional(uint256[] amounts) → (shares, usedAmounts)
previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn) → shares
previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut) → amountIn
previewJoinUnbalanced(uint256[] amounts) → shares
previewExitProportional(uint256 shares) → amounts
previewExitSingleAssetExactIn(address tokenOut, uint256 sharesIn) → amountOut
previewExitSingleAssetExactOut(address tokenOut, uint256 amountOut) → sharesIn
// + unbalanced exit if parity with BasePoolMath peer is in scope for DoD
```

#### LP execute

```text
joinProportional(
  uint256[] amounts, uint256[] amountsMax, // or amounts as max — plan freezes: amounts = maxes, used computed
  address to, uint256 sharesMin, uint256 deadline, bytes permit2Data
) → (uint256 shares, uint256[] usedAmounts)

joinSingleAssetExactIn(
  address tokenIn, uint256 amountIn, address to, uint256 sharesMin, uint256 deadline, bytes permit2Data
) → uint256 shares

joinSingleAssetExactOut(
  address tokenIn, uint256 sharesOut, address to, uint256 amountInMax, uint256 deadline, bytes permit2Data
) → uint256 amountIn

joinUnbalanced(
  uint256[] amounts, address to, uint256 sharesMin, uint256 deadline, bytes permit2Data
) → uint256 shares

exitProportional(
  uint256 shares, address to, uint256[] amountsMin, uint256 deadline
) → uint256[] amounts

exitSingleAssetExactIn(
  address tokenOut, uint256 sharesIn, address to, uint256 amountOutMin, uint256 deadline
) → uint256 amountOut

exitSingleAssetExactOut(
  address tokenOut, uint256 amountOut, address to, uint256 sharesInMax, uint256 deadline
) → uint256 sharesIn
```

**First mint** uses the same join entrypoints with `totalSupply == 0` branch (full preferred; partial rules §6.5).

#### Factory

```text
deployWithMineNonce(
  address[] tokens,
  uint256[] normalizedWeights,
  address[] rateProviders,
  string saltNamespace,   // empty → default
  uint256 mineNonce
) → (address hook, PoolKey[] poolKeys)

ensurePairPools(address hook) → (PoolKey[] poolKeys, uint8 createdCount)
pairPoolKeys(address hook) → PoolKey[]
isDeployedByFactory(address hook) → bool
predictHookAddress(tokens, weights, rateProviders, saltNamespace, mineNonce) → address
poolManager(), feeOracle(), create3Factory()
```

### 5.3 Immutables (preferred on wire)

```text
poolManager, feeOracle,
numTokens (uint8),
// tokens / weights / rateProviders: fixed-size arrays max 8 with length = n
//   OR immutable packed storage strategy — plan pin:
// Prefer: immutable addresses/weights via ctor-encoded fixed arrays of length n
//         (Solidity 0.8.x: use address[8] + uint8 n, unused slots zero-checked)
// baseScale[i] cached at ctor from decimals
```

**Ctor validation (LOCKED):**

1. `2 ≤ n ≤ 8`; array lengths equal.  
2. Tokens non-zero, pairwise distinct, **strict ascending**.  
3. Decimals fail-closed ∈ [6,18]; cache `baseScale[i] = 10^(36 - d_i)`.  
4. Weights: each ≥ `MIN_WEIGHT`; sum **exactly** `1e18`.  
5. `rateProviders[i]` may be 0; if non-zero, **do not** call `getRate` in ctor (fail-closed on first op).  
6. Build LP metadata (§5.4); `Hooks.validateHookPermissions`.  
7. Never initialize V4 pools in hook ctor (factory does).

### 5.4 LP metadata (LOCKED shapes)

```text
s_i = token.symbol() if staticcall ok + non-empty string
    else last 4 hex of address (lowercase, no 0x)
body = s0 + "-" + … + s_{n-1}
symbol = truncate("WGT-" + body, 32)
name   = truncate("Weighted " + ("WGT-" + body), 64)
```

Hard UTF-8 cut; cache in Repo at ctor. Do not revert deploy solely for missing `symbol()`.

### 5.5 Hook permissions (mine flags)

```text
BEFORE_INITIALIZE
| BEFORE_ADD_LIQUIDITY
| BEFORE_REMOVE_LIQUIDITY
| BEFORE_SWAP
| BEFORE_SWAP_RETURNS_DELTA
| BEFORE_DONATE
```

All `after*` and after-return-delta **off**. CREATE3 address must encode these flags.

### 5.6 Settle order (pattern-copy — D65 / PRD §4.9)

Peer dual/single Target order (**do not inherit**):

```text
beforeSwap:
  1. require msg.sender == poolManager; acquire reentrancy lock
  2. Identify tokenIn / tokenOut from PoolKey + zeroForOne; map to binding indices
  3. Gate swap-live (reserves[in/out] > 0); load rates fail-closed; load Repo
  4. feeWad = dexSwapFeeOfVault(this); require feeWad < 1e18
  5. Exact-in or exact-out WeightedMath + input fee (D21) → amountIn, amountOut
  6. Update Repo reserves BEFORE external token movement
     reserves[in]  += amountIn   // gross for exact-in
     reserves[out] -= amountOut
  7. Require post floors: reserves[in] > 0 && reserves[out] > 0
  8. Take input via PoolManager; sync + transfer output + settle
  9. Return BeforeSwapDelta matching taken/paid
 10. Return dynamic fee override: uint24(feeWad * 1e6 / 1e18) | OVERRIDE_FEE_FLAG
 11. Do NOT mint protocol LP or update kLast
```

**Delta convention:** tests with real V4 router/quoter are law — multiple directed pairs, exact-in and exact-out.

### 5.7 Events (minimum)

| Event | Fields (informative) |
|-------|----------------------|
| `HookDeployed` (factory) | `deployer`, `hook`, `poolManager`, `feeOracle`, `numTokens` |
| `PairPoolsEnsured` | `hook`, `createdCount`, `alreadyLiveCount` |
| `LiquidityJoined` | `sender`, `to`, `shares`, `amounts` (binding order) |
| `LiquidityExited` | `sender`, `to`, `shares`, `amounts` |
| `ProtocolFeeMinted` | `feeTo`, `shares` |
| `Swap` (optional hook event) | `sender`, `tokenIn`, `tokenOut`, `amountIn`, `amountOut`, `feeWad` |

---

## 6. Math & algorithm cards

### 6.1 Scaling (PRD §4.3)

```text
baseScale[i] = 10^(36 - decimals_i)
oracleRate   = provider==0 ? 1e18 : staticcall getRate()  // fail-closed D18
effectiveRate = baseScale * oracleRate / 1e18

scaleTo(a,r)   = floor(a * r / 1e18)
scaleToUp(a,r) = ceil(a * r / 1e18)
descale(s,r)   = floor(s * 1e18 / r)
descaleUp(s,r) = ceil(s * 1e18 / r)
```

### 6.2 Weighted swap (wrap Crane `WeightedMath`)

**Do not re-derive.** Import / call:

- `WeightedMath.computeOutGivenExactIn(balanceIn, weightIn, balanceOut, weightOut, amountIn)`  
- `WeightedMath.computeInGivenExactOut(...)`  
- Caps: `_MAX_IN_RATIO` / `_MAX_OUT_RATIO` = **30e16**

**Exact-in (D21):**

```text
feeWad = dexSwapFeeOfVault(this)   // 0 OK; require < 1e18
amountInNet = amountIn - floor(amountIn * feeWad / 1e18)
aInScaled = scaleTo(amountInNet, rateIn)
// WeightedMath enforces MAX_IN_RATIO on scaled domain
rawOutScaled = computeOutGivenExactIn(bIn, wIn, bOut, wOut, aInScaled)
amountOut = descale(rawOutScaled, rateOut)  // floor to user
require amountOut > 0
// Repo: +gross amountIn on in; −amountOut on out
```

**Exact-out:**

```text
// amountOut raw → scaleToUp for curve depth (pool-favoring)
// netInScaled = computeInGivenExactOut(...)
// netIn = descaleUp(netInScaled, rateIn)
// amountInGross = ceil(netIn * 1e18 / (1e18 - feeWad))   // pure ceil helper preferred
// MAX_OUT_RATIO on out
```

**Note:** Swap formula uses **only** the two trade legs’ balances and **global** weights \(w_{in}, w_{out}\) (no renormalization).

### 6.3 Invariant \(V\) and growth (D28–D29)

```text
// Full book only:
V = WeightedMath.computeInvariantDown(weights, scaledBalances)  // or peer name
// rootK = V   // LITERAL — no cbrt, no extra root

ownerFeeShare = usageFeeWad * 100_000 / 1e18
feeOn = feeTo != 0 && usageFeeWad != 0 && usageFeeWad < 1e18 && ownerFeeShare != 0

// when feeOn && same mode && kLast != 0 && rootK > rootKLast:
protocolLp = totalSupply * (rootK - rootKLast)
           / (rootK * 100_000 / ownerFeeShare + rootK - rootKLast)
```

**Partial interim \(k\)** (§6.5): same algebra with `rootK = k_interim`.

**Overflow:** accepted Uni V2–class / Balancer FixedPoint scale risk; Math uses Balancer FixedPoint path; tests probe large balances at \(n=8\).

### 6.4 Full-book LP (mirror Balancer)

#### First mint (all \(n\) legs > 0) — O2 pin

```text
require totalSupply == 0
require all amounts[i] > 0
scaled[i] = scaleTo(amounts[i], rate[i])
V = computeInvariantDown(weights, scaled)
require V > MINIMUM_LIQUIDITY
shares = V - MINIMUM_LIQUIDITY
mint MINIMUM_LIQUIDITY to address(0)
pull amounts; set reserves
no protocol mint
if feeOn: kLast = V_post; kLastMode = FullProduct else kLast = 0
```

#### Proportional join / exit

Peer Balancer proportional: `shares ↔ pro-rata raw or scaled legs` — implement via invariant-ratio identity:

```text
// Join exact BPT out or exact amounts in (pick peer BasePoolMath helpers)
// No taxable fee on pure proportional
// Exit: amounts[i] = shares * reserves[i] / supply'  (floor)
// D67: after exit, require all reserves[i] > 0  (else WouldZeroReserve)
```

#### Unbalanced join (exact amounts in)

Peer `BasePoolMath.computeAddLiquidityUnbalanced`:

1. Protocol mint first (D30).  
2. Working balances += amounts (rate-scaled domain for invariant).  
3. Enforce `MAX_INVARIANT_RATIO`.  
4. Taxable portion of each leg charged **swap fee** (trading fee WAD from oracle at call time).  
5. `shares = supply' * (V' - V) / V` (floor).  
6. Pull; update Repo; set `kLast`.

#### Single-asset join/exit

Special cases of unbalanced / BasePoolMath single-token exact-out peers. Full book only.

#### Full-book exit floors (D67)

```text
// After computing used exit amounts, before commit:
for each i: require reserves[i] > amountOut[i]   // strict post > 0
// If proportional would zero a tiny leg → Slippage/WouldZeroReserve — user reduces shares
```

**Dust residual:** When only `MINIMUM_LIQUIDITY` supply remains, residual inventory locked with dead shares — peer Orbital full liquid exit. Mode stays FullProduct if all legs still > 0; if inventory residual cannot keep all legs > 0 under dead MIN only, document peer residual dust rule and **prefer** keeping all legs dust-positive with dead MIN (tests assert invariant).

### 6.5 Partial book (O4 pin)

#### Modes

```text
enum KLastMode { FullProduct = 0, PartialInterim = 1 }
isFullBook <=> all reserves[i] > 0
```

#### Interim \(k\)

```text
P = { i | reserves[i] > 0 }
require |P| >= 1 when totalSupply > MINIMUM_LIQUIDITY
sumW = sum_{i in P} w_i
w'_i = w_i * 1e18 / sumW     for i in P
k_interim = prod_{i in P} (b_i ^ w'_i)   // FixedPoint powDown peer
rootK = k_interim
```

Cross-mode: if `mode != kLastMode`, `protocolLp = 0`; snapshot post-op.

#### First mint partial (\(n \ge 3\))

```text
require totalSupply == 0
require count(amounts[i] > 0) >= 2
// n == 2: FORBIDDEN — both legs required (use full first mint)
scaled positive legs; k = interim product on positive set
require k > MINIMUM_LIQUIDITY
shares = k - MINIMUM_LIQUIDITY
mint MIN to address(0); pull positive; zeros stay 0
kLastMode = PartialInterim if any zero else FullProduct
```

#### Subsequent partial join (seed + prop)

```text
1. protocol mint if feeOn && PartialInterim && kLast != 0
2. Z = { i | r_i==0 && amount_i>0 }  // seed full amount_i
3. P+ = { i | r_i>0 && amount_i>0 }
   // Uni V2 min-ratio on rate-scaled: shares_prop = min_{i in P+}(a_iWad * supply' / r_iWad)
   // used_i for P+ from shares_prop; require used_i > 0 for each i in P+ when P+ non-empty
4. If P+ empty (seed-only): shares from:
     shares = supply' * (k_after - k_before) / k_before
     with k_before on pre positive set; k_after after applying seeds into working balances
   If P+ non-empty and Z empty: pure prop min on P+ (same as Uni V2 subset)
   If both: apply prop used on P+ then seeds; shares = supply' * (k_after - k_before) / k_before
5. require shares >= sharesMin; pull; update; set kLast/mode
6. if all reserves > 0 post: mode = FullProduct; kLast = V_full
```

#### Partial exit

```text
// Proportional over positive legs only; zeros pay 0
// require after exit: at least one positive reserve if totalSupply > MINIMUM_LIQUIDITY
// Full Balancer single/unbalanced exit: revert NotFullBook / PartialPathRestricted
```

### 6.6 Fee-on timing (D30)

```text
join:
  1. deadline; lock
  2. compute mode + rootK_pre from current reserves
  3. if feeOn && same mode && kLast != 0: mint protocolLp to feeTo; emit
  4. user join math on post-protocol totalSupply
  5. pull Permit2/transferFrom; update reserves; mint user LP to `to`
  6. if feeOn: kLast = rootK_post, kLastMode = mode_post; else kLast = 0

exit:
  1. deadline; lock
  2. protocol mint first (same rules)
  3. burn msg.sender shares; compute amounts; D67 if FullProduct
  4. pay `to`; set kLast post

first mint: skip step 3 protocol; set kLast post if feeOn
swaps: never mint / never update kLast
```

### 6.7 Factory + salt (O1 pin)

```text
// FactoryService
DEFAULT_SALT_NAMESPACE = "uv4-weighted-swap-hook-"

function hookSalt(
  string namespace,           // empty → default
  address poolManager,
  address feeOracle,
  address[] tokens,        // already sorted, length n
  uint256[] weights,
  address[] rateProviders,
  uint256 mineNonce
) → bytes32:
  if namespace empty: namespace = DEFAULT
  return abi.encodePacked(
    namespace, poolManager, feeOracle,
    uint8(n), tokens packed in order, weights packed, rateProviders packed,
    mineNonce
  )._hash()   // BetterEfficientHashLib

// CREATE3 prediction:
//   deployer = address(create3Factory)
//   HookMinerCreate3.computeAddress(create3Factory, salt, creationCode+ctor) or peer API
//   require (uint160(predicted) & FLAG_MASK) == requiredFlags()

// deployWithMineNonce:
//   1. validate tokens/weights/n/rates
//   2. salt = hookSalt(...)
//   3. if predicted.code.length != 0:
//        require isExpectedHook(predicted, binding); ensurePairPools; return (no HookDeployed for new code)
//   4. else: create3Factory deploy with salt + creationCode + ctorArgs
//   5. initialize ALL binom(n,2) PoolKeys:
//        currency0/1 address-sorted pair; fee=DYNAMIC_FEE_FLAG; tickSpacing=1; hooks=hook
//        sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0)
//   6. isDeployedByFactory[hook] = true; emit HookDeployed; return poolKeys array
//
// ensurePairPools: factory-attested only; create missing doors; emit PairPoolsEnsured
```

**Off-chain mine tooling (tests + ops):**

```text
// Loop mineNonce = 0..MAX_LOOP until flags match; tests call this helper then deployWithMineNonce
// On-chain mine loop NOT required for DoD (PRD D48 / O6 deferred)
```

**Ctor args pin:**

```text
abi.encode(
  poolManager,
  feeOracle,
  tokens,              // address[]
  normalizedWeights,   // uint256[]
  rateProviders        // address[]
)
```

### 6.8 Permit2 packing (weighted — peer Orbital §5.6)

Canonical Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3`.  
No witness. Owner = `msg.sender`. Recipient = hook.  

| Rule | Value |
|------|--------|
| Empty `permit2Data` | SafeERC20 `transferFrom` for **every** pulled leg |
| Non-empty | **All** pulled legs via Permit2 only — **no mixed** |
| Modes | `uint8 mode`: `0` = Signature batch; `1` = Allowance transfer |
| Batch order | Ascending **binding index** among legs with `used_i > 0` |
| Swaps | No hook Permit2 |
| Exit | No inventory Permit2 (burns LP only) |

Signature mode packing:

```text
permit2Data = abi.encode(
  uint8(0),
  ISignatureTransfer.PermitBatchTransferFrom permit,
  bytes signature
)
// permitted.length == count(used_i > 0)
// permitted[k].token == token of k-th pulled binding index
```

Allowance mode:

```text
permit2Data = abi.encode(uint8(1))
// IAllowanceTransfer.transferFrom per pulled leg in binding order
```

### 6.9 Required Math.t.sol fixtures (law)

| ID | Setup | Assert |
|----|-------|--------|
| FIX-V1 | \(n=2\), 50/50, equal scaled balances | `computeInvariantDown` stable; re-run bit-identical or ≤1 |
| FIX-V2 | \(n=4\), weights 40/30/20/10, mild imbalance | \(V\) converges; swap exact-in then reconverge \(V' > V\) with residual fee |
| FIX-SW1 | Exact-in 50/50; feeWad=0 | out matches WeightedMath direct call |
| FIX-SW2 | Exact-in feeWad=0.003e18 | net in after fee; residual accounting identity |
| FIX-SW3 | Exact-out fee gross-up | round-trip identities pool-favoring |
| FIX-CAP1 | amountIn &gt; 30% balance | reverts MaxInRatio |
| FIX-G1 | Full book growth algebra worked example | `protocolLp` matches D29 formula with rootK=V |
| FIX-P1 | Partial interim renormalize weights on 2 of 3 | \(k\) deterministic; seed completes → full \(V\) |
| FIX-S1 | Scale/descale mixed 6/8/18 decimals | floor/ceil identities |

Optional: comparative vector vs Balancer WeightedPool fixture (full book) within documented tolerance.

---

## 7. Implementation phases

Ordered for reviewable green slices. **Math + LP can start before factory**, but package DoD requires factory path for production deploy tests.

### Phase 0 — Skeleton + interfaces + Repo

**Deliverables**

1. `IUniswapV4WeightedSwapHook` / `IUniswapV4WeightedSwapHookFactory` per §5.2.  
2. `UniswapV4WeightedSwapHookRepo` under unique slot; ERC-20 Uni V2–style (balance on `address(0)`).  
3. Empty Target/Common/Math/wire compiling with correct permissions bitmask.  
4. Factory stub with immutables `create3Factory`, `poolManager`, `feeOracle`.  

**Exit:** `forge build` green; NatSpec headers; BUSL/peer license.

### Phase 1 — Math library (pure)

**File:** `UniswapV4WeightedSwapHookMath.sol`

| Function group | Law |
|----------------|-----|
| scale / descale | §6.1 |
| swap exact-in/out + fee residual/gross-up | §6.2 / D21 |
| V4 pips override | D23 |
| invariant \(V\) + interim \(k\) | §6.3 / §6.5 |
| first mint shares | O2 / §6.4 |
| proportional / unbalanced join-exit helpers | §6.4 (wrap WeightedMath / BasePoolMath peers) |
| protocol LP algebra | D29; rootK = V |
| ratio cap checks | D37–D38 |

**Tests:** `*_Math.t.sol` FIX-* green without PoolManager.

**Exit:** Math covered; NatSpec states rootK=V and Balancer peer paths.

### Phase 2 — Common + Target LP (no swap)

**Implement**

1. Ctor validation + baseScale cache + LP name/symbol.  
2. EIP-2612 permit.  
3. Global reentrancy lock on LP entrypoints.  
4. Full-book joins/exits + first mint + previews (growth-aware).  
5. D67 WouldZeroReserve on full-book exits.  
6. Protocol mint first (fee-on); events.  
7. deadline; `to` on joins; burn msg.sender on exits.  
8. Permit2 can be transferFrom-only stub until Phase 6.  
9. `beforeAddLiquidity` / `beforeRemoveLiquidity` / `beforeDonate` revert.  
10. `beforeInitialize`: factory door rules (D68).  

**Exit:** Hermetic TestBase deploys hook (temporary CREATE3 helper or early factory); first LP + remove; preview==exec; MIN on address(0); growth mint after synthetic reserve growth (controlled later via swaps).

### Phase 3 — Swap settle + dynamic fee

**Implement**

1. `beforeSwap` + settle §5.6.  
2. Exact-in/out; multi-door matrix for \(n=3\) and \(n=4\).  
3. Fee 0 and non-zero residual.  
4. MAX_IN/OUT ratio reverts.  
5. Post floors D56.  
6. No kLast update on swap.  

**Exit:** Router/quoter-driven swaps green; donation ignored.

### Phase 4 — Partial book dual mode

**Implement**

1. Partial first mint \(n \ge 3\); \(n=2\) rejects partial.  
2. Seed + prop subset joins.  
3. Restricted paths revert until full.  
4. Mode switch seed→full; cross-mode no bogus mint.  
5. Partial exit rules.  

**Exit:** `*_Partial.t.sol` green.

### Phase 5 — Factory + all doors + off-chain mine

**Implement**

1. FactoryService salt + predict + deployWithMineNonce.  
2. Atomic all \(\binom{n}{2}\) initializes.  
3. ensurePairPools factory-only.  
4. Idempotent redeploy.  
5. Invalid mineNonce reverts.  
6. Matrix \(n \in \{2,3,4,8\}\) (or sample 2,4,8 if gas).  

**Exit:** Production deploy path is factory-only in TestBase.

### Phase 6 — Permit2 packing

**Implement** §6.8 empty / signature batch / allowance; wrong order reverts; no mixed.

### Phase 7 — Rates + fee oracle integration

1. Optional IRateProvider path + fail-closed.  
2. Real Vault Fee Oracle: set **defaults** for dexSwapFee + usageFee + feeTo.  
3. Per-address override optional test.  
4. fee-off / ownerFeeShare==0.  

### Phase 8 — Gold TestBase polish + preview suite

Bit-exact previews across join/exit/swap; mixed decimals; reentrancy adversarial; safety (CL, donate, donation, deadline, WouldZeroReserve).

### Phase 9 — Forks

Base + Robinhood 4663: production PM/CREATE3/oracle/Permit2; mintable tokens OK.

### Phase 10 — Adversarial / comparative

Reentrancy, donation, ratio caps, rate fail, would-zero-reserve, cross-mode kLast. Optional Balancer WeightedPool comparative quotes (full book).

---

## 8. Testing plan

### 8.1 Gold TestBase

**Path (LOCKED):** `contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol`

**Inheritance ladder (production-first):**

```text
CraneTest
  → IndexedexTest   // manager + real Vault Fee Oracle path where available
  → TestBase_UniswapV4WeightedSwapHook
```

**Peer reference for V4 hook TestBase structure:**  
`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol` (layout spirit only).

**TestBase must:**

1. Bootstrap ecosystem `create3Factory` + canonical hermetic V4 `PoolManager` (Crane peer).  
2. Deploy production Vault Fee Oracle; set **default** `dexSwapFee`, `usageFee`, `feeTo`.  
3. Deploy **factory** with immutables `(create3Factory, poolManager, feeOracle)`.  
4. Grant factory CREATE3 operator rights as required.  
5. Helpers: `mineNonceFor(...)`, `deployHook(n, tokens, weights, providers)`, fund users, approve Permit2, join full book, swap on door.  
6. **No mock** of hook / factory / Math / Repo / oracle under test.

### 8.2 Hermetic suite matrix

| Suite | IDs (suggested) | Coverage |
|-------|-----------------|----------|
| Math | FIX-* | §6.9 |
| Deploy | D1–D10 | flags, immutables, weights validation, LP metadata |
| Factory | F1–F20 | mineNonce, all doors, ensure, idempotent, not-factory ensure, n=2/3/4/8 |
| Liquidity | L1–L30 | first mint full; prop join/exit; single; unbalanced; D67; deadline; msg.sender burn |
| Partial | P1–P20 | n≥3 first partial; seed; restricted reverts; mode switch; n=2 rejects partial |
| Swap | S1–S30 | multi-door exact-in/out; fee 0/nonzero; caps; not live |
| Fees | G1–G15 | growth add/remove; rootK=V; cross-mode; fee-off; ProtocolFeeMinted |
| Preview | Q1–Q20 | preview==execution growth-aware |
| Rates | R1–R10 | provider path; fail-closed |
| Permit2 | P2-1–P2-12 | empty/sig/allowance; bad packing |
| Safety | X1–X15 | CL/donate/donation/deadline/WouldZeroReserve/InvalidPoolKey |
| Reentrancy | RE1–RE5 | LP↔swap lock |

### 8.3 Fork DoD

| Chain | Path | Goal |
|-------|------|------|
| Base | `test/foundry/fork/base_main/hooks/uniswap/v4/weighted/` | Production PM + CREATE3 + oracle + Permit2 |
| Robinhood 4663 | `test/foundry/fork/robinhood_4663/hooks/uniswap/v4/weighted/` | Same |

Tokens: mintable OK. Assert factory deploy + one join + one swap + one exit minimum each.

### 8.4 Production-first rules (IndexedEx)

- **Never** mock hook, factory, Math under test, PoolManager (use real), or fee oracle (use real package).  
- Allowed: mintable ERC20; reentrancy hostile ERC20 for adversarial only.  
- Prefer factory deploy path in all integration tests.

---

## 9. Definition of Done (exit checklist)

Matches PRD §8 + this plan:

- [ ] Package files under `contracts/hooks/uniswap/v4/weighted/` match §3.  
- [ ] CREATE3 FactoryService + permissionless factory; ecosystem CREATE3; **off-chain mine** primary; no BaseHook inherit; no Facet/DFPkg.  
- [ ] Factory creates hook + **all** \(\binom{n}{2}\) pools; `ensurePairPools` factory-only; factory-immutable feeOracle.  
- [ ] Repo + Target settle pattern-copy (§5.6).  
- [ ] WeightedMath swaps + Balancer-equivalent joins/exits on full book.  
- [ ] Partial dual-mode + **no full-book leg zeroing**.  
- [ ] Oracle dual channel; **`rootK = V`**.  
- [ ] DYNAMIC_FEE_FLAG + override; factory doors only.  
- [ ] Optional IRateProvider fail-closed.  
- [ ] Permit2 + transferFrom; deadline; msg.sender burn.  
- [ ] Previews match execution (growth-aware).  
- [ ] Gold TestBase + hermetic suites green.  
- [ ] Fork DoD: Base + Robinhood 4663.  
- [ ] NatSpec + Crane style; no debug logs.

---

## 10. Suggested implementation order (summary)

```text
0 Skeleton → 1 Math → 2 Full-book LP → 3 Swap → 4 Partial → 5 Factory
  → 6 Permit2 → 7 Oracle/Rates → 8 Preview/Safety/Reentrancy → 9 Forks → 10 Adversarial
```

Each phase: build green + that phase’s tests green before merge to next.

---

## 11. Open items after plan (should stay empty)

| # | Item | Disposition |
|---|------|-------------|
| — | O1–O5 | **Pinned in §0.2 / §6** |
| O6 | On-chain mine loop helper | Deferred; not DoD |
| — | Exact `joinProportional` max vs used array naming | §5.2: amounts as maxes; return `usedAmounts` |
| — | Unbalanced exit full BasePoolMath parity | DoD if BasePoolMath peer supports; else document deferred exit variants with PRD-aligned proportional + single-asset only |

If a new product choice arises, **revise PRD first**, then patch this plan.

---

## 12. Changelog

| Version | Date | Notes |
|---------|------|-------|
| **v1.0** | 2026-08-03 | Initial canonical plan from PRD v0.2.0. Pins O1–O5 (salt/deployer, first-mint `V−MIN`, ABI names, partial shares, join `to`). Phases 0–10; Math FIX-*; factory off-chain mine; Permit2 packing; test matrix; DoD checklist. |
