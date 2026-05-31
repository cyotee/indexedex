# Standard Exchange Buffer Pool — Design Spec

**Date:** 2026-05-31
**Status:** Draft, pending user review.
**Authors:** cyotee (design), Claude (drafting).

## 1. Motivation

The Standard Exchange Vault is a multi-token vault that issues shares against deposits of any of its registered underlyings (e.g. TTA, TTB). Today, integrations route through a bespoke custom Router (`IBalancerV3StandardExchangeRouterExactInSwap`) that intermediates deposits and redeems around Balancer V3 pool swaps.

The goal of this pool is different: **expose a Balancer-V3-native market for a single (underlying, vault-share) pair**, so that any contract using standard Balancer interfaces (`IVault.swap`, `BatchRouter`, oracle-friendly rate provider reads on a registered pool) can quote and trade the share token without bespoke router glue. The pool is primarily a **price source and standardized trading surface** for one share token denominated in one of the vault's underlyings.

## 2. Scope and Decisions

The following decisions were finalized during brainstorming. Out-of-scope items are listed for completeness.

| Decision | Choice |
|---|---|
| Directionality | Bidirectional `TTA <-> shares` |
| Underlying scope | Single pair: one deployment per `(StandardExchangeVault, underlying TTA)` |
| Pricing source | Configurable `IRateProvider` on the shares token; default returns TTA-per-share via `previewExchangeOut` |
| Math | Constant product `x * y = k`, where `x = virtualTTA` (pool storage) and `y = max(0, balancesLiveScaled18[sharesIdx] - hookSharesDelta_scaled18_rated)` (Vault-supplied actual shares, less the running offset of net hook-deposited shares, clamped at zero) |
| Pool reserves at rest | Strict zero TTA invariant: pool's actual TTA balance held by the Balancer V3 Vault is always 0 between operations |
| LP model | Proportional only (`disableUnbalancedLiquidity = true`) |
| Pre-seat for `shares -> TTA` | Hook drains shares via `sendTo`, redeems for TTA via Standard Exchange Vault `exchangeOut`, seats TTA via `addLiquidity(DONATION)`, reconciles per-pool shares balance via `removeLiquidity(CUSTOM)`. The `hookSharesDelta` offset makes the CP `y` invariant under this reshuffling, so no residual-redeposit pass is needed and `Y_TTA_final == Y_TTA` by construction. |
| Pool + hook deployment | Single Crane Diamond. Hook is a facet of the pool. `hooksContract == address(pool)`. |
| Factory | `deployPool` on the Package, routes through `VaultRegistry.deployVault(this, pkgArgs)` |

Out-of-scope for this design (may be revisited later):
- ERC4626-buffer-style optimization (would relax the zero-TTA invariant).
- Multi-underlying pools (one deployment covers `shares + {TTA, TTB, ...}` simultaneously).
- Dynamic swap fees driven by hook.

## 3. Architecture

Four contracts in total (the Standard Exchange Vault is reused unchanged):

```
                       Balancer V3 Vault (singleton, unchanged)
                              |  onSwap        |  onBefore/AfterSwap
                              |  computeInv    |  onAdd/RemoveLiquidity (Custom)
                              v                v
       StandardExchangeBufferPool Diamond  ==  (pool address == hook address)
         - IBasePool facet (onSwap, computeInvariant, computeBalance)
         - IPoolLiquidity facet (onAddLiquidityCustom, onRemoveLiquidityCustom)
         - IHooks facet (onRegister, getHookFlags, onBefore*, onAfter*)
         - BalancerPoolToken (BPT ERC20 surface for the Vault to mint/burn)
         - Pool storage repo (virtualTTA, hookSharesDelta, refs to share token, TTA, SE vault, rate provider)
                              |                       |
                              | reads getRate()       | exchangeIn / exchangeOut
                              v                       v
              StandardExchangeShareRateProvider     Standard Exchange Vault
              (default impl; user-supplied also OK) (existing, unchanged)
```

### 3.1 `StandardExchangeBufferPool` (Crane Diamond)

A single Diamond containing facets that, together, present a complete Balancer V3 pool surface plus the hook:

- **IBasePool**: `onSwap`, `computeInvariant`, `computeBalance`. Math uses `(virtualTTA, balancesLiveScaled18[sharesIdx])` for constant product, substituting `virtualTTA` for the always-zero `balancesLiveScaled18[ttaIdx]`.
- **ISwapFeePercentageBounds / IUnbalancedLiquidityInvariantRatioBounds**: required by `IBasePool`. Fee bounds: 0.01% min, 10% max. Invariant ratio bounds: identity (1e18, 1e18) since unbalanced liquidity is disabled.
- **IPoolLiquidity**: `onAddLiquidityCustom`, `onRemoveLiquidityCustom`. Public callers are rejected (`NotHookCaller`); only the pool's own hook facet uses these paths to reconcile per-pool balances during pre-seat / post-swap.
- **IHooks**: all hook callbacks. Validates `msg.sender == BalancerV3Vault` on every entry.
- **BalancerPoolToken**: standard ERC20 surface backing BPT mint/burn calls from the Vault.
- **Pool storage repo (Crane AwareRepo)**: holds `virtualTTA` (unsigned scaled18), `hookSharesDelta` (signed int256, raw shares units), the three external addresses (TTA token, share token, Standard Exchange Vault), and the chosen rate provider. The two addresses + rate provider + token references are immutable after registration; `virtualTTA` and `hookSharesDelta` are live state.

### 3.2 `StandardExchangeShareRateProvider` (IRateProvider)

Default rate-provider implementation. `getRate()` returns `IStandardExchangeOut.previewExchangeOut(shareToken, ttaToken, 1e18)` scaled to 18-decimal FP. Stateless. Deployable per (vault, underlying) pair.

Users may supply an alternative `IRateProvider` at deployment if they want a smoothed or governance-managed rate. The pool does not care — it only consumes whatever rate the Balancer V3 Vault hands to `onSwap` via `balancesLiveScaled18`.

### 3.3 `StandardExchangeBufferPoolDFPkg` (Diamond Factory Package)

Implements `IStandardVaultPkg` so it can be registered with `VaultRegistry`. Exposes:

```
function deployPool(
    address standardExchangeVault,
    address tta,
    address shares,
    address rateProvider,     // address(0) -> deploy a default StandardExchangeShareRateProvider
    uint256 swapFeePercentage,
    PoolRoleAccounts memory roleAccounts,
    bytes32 salt
) external returns (address pool);
```

Internally:
1. If `rateProvider == address(0)`, deploys a fresh `StandardExchangeShareRateProvider(standardExchangeVault, shares, tta)` via the Crane CREATE3 factory using a deterministic sub-salt of `salt`.
2. Encodes the pkg args (the same parameters) and calls `VaultRegistry.deployVault(this, pkgArgs)`. The registry validates this DFPkg is registered, then calls `DiamondPackageFactory.deploy(this, pkgArgs)` which deploys the pool Diamond at the CREATE3 address derived from `salt`.
3. Inside the Diamond's init callback, the package calls `BalancerV3Vault.registerPool(pool, tokenConfig, ...)` with the configuration specified in Section 4.

The pool address is therefore deterministic given `(salt, standardExchangeVault, tta, shares, rateProvider, swapFeePercentage)`.

### 3.4 `StandardExchangeBufferPoolFactoryService` (existing Crane pattern)

The factory service is the on-chain singleton holding a reference to the DFPkg and exposing the same `deployPool` signature for off-chain / cross-chain symmetric deployment, following the convention established by `UniswapV4_Component_FactoryService` and `SingleVaultDetf_Component_FactoryService`.

## 4. Registration

When the Package's init callback fires inside `DiamondPackageFactory.deploy`, the pool registers itself with the Balancer V3 Vault:

### 4.1 TokenConfig (sorted by token address per Balancer convention)

```
[
  { token: TTA,    tokenType: STANDARD,  rateProvider: address(0),               paysYieldFees: false },
  { token: shares, tokenType: WITH_RATE, rateProvider: <configured rateProvider>, paysYieldFees: false }
]
```

### 4.2 LiquidityManagement

- `disableUnbalancedLiquidity = true`
- `enableAddLiquidityCustom = true`
- `enableRemoveLiquidityCustom = true`
- `enableDonation = true`

### 4.3 HookFlags (returned by `getHookFlags()`; `hooksContract == address(pool)`)

- `enableHookAdjustedAmounts = false`
- `shouldCallBeforeSwap = true` -- the hook *registers* for the call in both swap directions; the body is a no-op when `tokenIn == TTA` and performs the pre-seat when `tokenIn == shares`
- `shouldCallAfterSwap = true`
- `shouldCallBeforeAddLiquidity = true`
- `shouldCallAfterAddLiquidity = true`
- `shouldCallBeforeRemoveLiquidity = false`
- `shouldCallAfterRemoveLiquidity = true`
- `shouldCallBeforeInitialize = true`
- `shouldCallAfterInitialize = false`
- `shouldCallComputeDynamicSwapFee = false`

### 4.4 `onRegister` validation

Returns `false` (rejecting registration) if any of:

- `msg.sender != BalancerV3Vault`
- `factory != registeredDFPkg`
- `pool != address(this)`
- `tokenConfig.length != 2`
- Token order or addresses don't match `(TTA, shares)` wired into the package
- The rate provider on the shares token isn't a contract
- The liquidity-management flags don't match Section 4.2

## 5. Math and State

### 5.1 Storage

Pool repo (Crane AwareRepo, two slots for live state):

```
struct State {
    uint256 virtualTTA;       // scaled18 TTA-denominated; the "x" of x*y=k
    int256  hookSharesDelta;  // raw shares units (signed); cumulative
                              //   net shares deposited (+) or redeemed (-) by
                              //   the hook against the Standard Exchange Vault
}
```

Plus immutable references (set at registration, read-only thereafter): `TTA`, `shares`, `standardExchangeVault`, `rateProvider`, `swapFeePercentage`.

### 5.2 Derived CP `y`

The pool does not store `virtualShares` directly. It computes `y` at math-time from the Vault-supplied actual shares balance and the stored offset:

```
y = max(0, balancesLiveScaled18[sharesIdx] - hookSharesDelta_scaled18_rated)
```

where `hookSharesDelta_scaled18_rated` lifts the raw-shares signed counter into the Vault's scaled-18 + rate-adjusted units using the same `decimalScalingFactors[sharesIdx]` and `tokenRates[sharesIdx]` the Vault used to build `balancesLiveScaled18[sharesIdx]`. Since `hookSharesDelta` can be negative (the hook has net-redeemed more shares than it minted), the subtraction can produce values larger than the actual balance — that's correct and intentional, because the pool's economic shares position includes the value held as TTA at the Standard Exchange Vault.

**Clamp at zero (defensive floor):** any deduction operation that would drive the derived `y` below zero is clamped at zero instead. This applies to the subtraction itself (`max(0, …)`) and to any future code paths that compute "deduct from `y`" — they must check the clamped result rather than the raw arithmetic. If `y == 0` after clamping, `pool.onSwap` reverts with `PoolSharesSideExhausted` rather than attempting a degenerate swap.

The same defensive clamping applies anywhere we compute a deduction from a virtual quantity. We do not silently produce negative or arithmetic-underflowing values; we either clamp at zero (and revert on the resulting degenerate state where appropriate) or revert immediately with a typed error.

### 5.3 Swap math

Let:
- `x = virtualTTA` (from pool storage)
- `y` = derived per Section 5.2
- `f = swapFeePercentage`

`pool.onSwap(PoolSwapParams params)`:

**EXACT_IN tokenIn=TTA, tokenOut=shares:**
- Apply fee: `X_net = params.amountGivenScaled18 * (1e18 - f) / 1e18`
- `Y_rated = y * X_net / (x + X_net)`
- Return `Y_rated`

**EXACT_IN tokenIn=shares, tokenOut=TTA:**
- Apply fee: `X_net = params.amountGivenScaled18 * (1e18 - f) / 1e18`
- `Y_TTA = x * X_net / (y + X_net)`
- Return `Y_TTA`

**EXACT_OUT** flips the formulas symmetrically.

Revert paths inside `onSwap`:
- `y == 0` after clamping → `PoolSharesSideExhausted`.
- `x == 0` → `PoolTTASideExhausted`.

### 5.4 Invariant

`computeInvariant(balancesLiveScaled18, rounding)`:
- `y` = derived per Section 5.2, `x = virtualTTA`
- Return `sqrt(x * y)` rounded per `rounding`

`computeBalance(balancesLiveScaled18, tokenInIndex, invariantRatio)`:
- Standard CP balance-given-invariant-ratio. For TTA index, returns the virtual value; for shares index, returns the derived `y` from Section 5.2. Used by Balancer for SINGLE_TOKEN single-sided ops, which we disable; we still implement it for completeness and return correct values so any defensive callers don't break.

### 5.5 State update rules

| Event | `virtualTTA` | `hookSharesDelta` |
|---|---|---|
| Initialization (seed `s_init` shares) | `:= s_init * r` (rated) | `:= 0` |
| Hook deposits TTA into Standard Exchange Vault, gets `Y'` shares back | `+= amountDeposited_scaled18` | `+= Y'` (raw shares) |
| Hook redeems `S` shares from Standard Exchange Vault, gets TTA back | `-= amountTTARedeemed_scaled18` | `-= S` (raw shares) |
| LP proportional add of `Δbpt` BPT | `+= Δbpt * virtualTTA_pre / totalSupply_pre` | `+= Δbpt * hookSharesDelta_pre / totalSupply_pre` (signed; arithmetic carries the sign) |
| LP proportional remove of `Δbpt` BPT | `-= Δbpt * virtualTTA_pre / totalSupply_pre`; clamp at 0 | `-= Δbpt * hookSharesDelta_pre / totalSupply_pre` (signed; arithmetic carries the sign) |

`virtualTTA_pre`, `hookSharesDelta_pre`, and `totalSupply_pre` always mean the values *before* the in-flight operation: in `onAfterAddLiquidity` the hook reads `_totalSupply() - bptOut` to recover `totalSupply_pre`, since BPT minting happens before the after-hook fires; symmetrically in `onAfterRemoveLiquidity` the hook reads `_totalSupply() + bptIn`. `virtualTTA_pre` and `hookSharesDelta_pre` are read from storage at the top of the after-hook, before the updates are applied.

`virtualTTA` deduction is clamped at zero on LP remove only as a defensive floor — under normal CP semantics the proportional deduction cannot exceed the pre-balance, but rounding and signed-int arithmetic at the boundary of `hookSharesDelta` motivate a uniform "no negatives in `virtualTTA`" rule. `hookSharesDelta` is allowed to be negative without clamping (it is signed by design).

The LP update rule preserves the `virtualTTA / y` ratio (and therefore the CP price) across liquidity changes, because `actualShares` and `hookSharesDelta` both scale by the same `(T + Δbpt) / T` factor. Hook deposit/redeem activity is invisible to the CP `y` because the same raw-shares delta is applied to both `actualShares` (in the Vault) and `hookSharesDelta` (in pool storage).

## 6. Data Flows

Notation: `X` = user input (raw), `X_rated` = scaled18 + rate-adjusted by Vault, `r` = rate provider value, `s` = pool's actual shares balance (raw), `x` = `virtualTTA`, `h` = `hookSharesDelta`, `y = max(0, (s - h) * r)` in scaled-18 + rated units, `k = x * y`.

### 6.1 Initialization

1. LP calls `Vault.initialize(pool, [0, s_init], minBpt, false, userData)`. (If Balancer rejects 0 for any token, the package requires a dust TTA seed; the hook's `onBeforeInitialize` deposits the dust into the Standard Exchange Vault, mints dust shares, folds them into `s_init` and updates `hookSharesDelta` accordingly.)
2. `onBeforeInitialize` fires: hook writes `virtualTTA := s_init * r` and `hookSharesDelta := 0` (or `:= dust_shares_minted` if dust TTA was supplied). Returns true.
3. Vault calls `pool.computeInvariant`, mints BPT. Initial state: `x = y = s_init * r`.

### 6.2 Swap: TTA -> shares EXACT_IN

Pool state at start: actual TTA = 0, actual shares = `s`, `virtualTTA = x`, `hookSharesDelta = h`. Derived `y_pre = (s - h) * r`.

1. Router -> `Vault.unlock` -> `Vault.swap({EXACT_IN, TTA, shares, X, ...})`.
2. `_loadPoolDataUpdatingBalancesAndYieldFees`. `balancesLiveScaled18 = [0, s * r]`.
3. `onBeforeSwap` fires (the flag is true for both directions). Hook branches on `params.indexIn`: for `TTA -> shares` no action is needed (pool has shares to give; the swap only adds TTA, can't underflow). Returns true.
4. `_swap` -> `pool.onSwap`. Pool reads `virtualTTA = x` and `hookSharesDelta = h`, derives `y_pre = max(0, (s - h) * r)`, computes `Y_rated = y_pre * X_net / (x + X_net)`. Returns `Y_rated`.
5. Vault accounting: `_takeDebt(TTA, X)`, `_supplyCredit(shares, Y_shares)`, per-pool TTA balance: `0 -> X`, per-pool shares balance: `s -> s - Y_shares`. Deltas: `TTA = -X`, `shares = +Y_shares`.
6. `onAfterSwap`. Hook:
   a. `Vault.sendTo(TTA, hook, X)` -> `_reservesOf[TTA] -= X`, `TTA delta = -2X`.
   b. `IStandardExchangeIn.exchangeIn(TTA, X, shares, 0, balancerVault, false, deadline)` -> mints `Y' = X / r` shares to the Balancer Vault.
   c. `Vault.settle(shares, Y')` -> `_reservesOf[shares] += Y'`, `shares delta = Y_shares + Y'`.
   d. `Vault.removeLiquidity(pool, hook, 0, [X_raw, 0], CUSTOM, "")` -> `onRemoveLiquidityCustom` returns `(amountsOutScaled18=[X, 0], bptIn=0, fees=[0,0], "")`. Per-pool TTA balance: `X -> 0`. `_supplyCredit(TTA, X)` -> `TTA delta = -X`.
   e. `Vault.addLiquidity(pool, hook, [0, Y'_raw], 0, DONATION, "")` -> per-pool shares balance += `Y'`. `_takeDebt(shares, Y')` -> `shares delta = Y_shares`.
   f. State updates: `virtualTTA += X_scaled18`, `hookSharesDelta += Y'`.
7. Final deltas after hook: `TTA = -X`, `shares = +Y_shares`. Router settles user side normally.

End state: pool actual TTA = 0, pool actual shares = `s - Y_shares + Y'`, `virtualTTA = x + X_scaled18`, `hookSharesDelta = h + Y'`. Derived `y_post = (s - Y_shares + Y' - h - Y') * r = (s - h - Y_shares) * r = y_pre - Y_rated`. CP `y` moved by exactly the user-side change; hook reshuffle is invisible.

### 6.3 Swap: shares -> TTA EXACT_IN

Pool state at start: actual TTA = 0, actual shares = `s`, `virtualTTA = x`, `hookSharesDelta = h`. Derived `y_pre = max(0, (s - h) * r)`.

1. Router -> `Vault.unlock` -> `Vault.swap({EXACT_IN, shares, TTA, X_shares, ...})`.
2. `_loadPoolDataUpdatingBalancesAndYieldFees`. `balancesLiveScaled18 = [0, s * r]`, `amountGivenScaled18 = X_rated = X_shares * r`.
3. `onBeforeSwap` runs the pre-seat:
   a. Compute `Y_TTA = x * X_rated / (y_pre + X_rated)` (CP on the pre-swap derived state) and raw `Y_TTA_raw`. If `y_pre == 0` revert `PoolSharesSideExhausted`.
   b. Compute `S = IStandardExchangeOut.previewExchangeOut(shares, TTA, Y_TTA_raw)` -- exact shares needed to redeem.
   c. `Vault.sendTo(shares, hook, S)` -> `_reservesOf[shares] -= S`, `shares delta = -S`.
   d. `IStandardExchangeOut.exchangeOut(shares, S, TTA, Y_TTA_raw, balancerVault, false, deadline)` -> burns `S` shares, sends `Y_TTA_raw` TTA to Balancer Vault.
   e. `Vault.settle(TTA, Y_TTA_raw)` -> `_reservesOf[TTA] += Y_TTA_raw`, `TTA delta = +Y_TTA_raw`.
   f. `Vault.addLiquidity(pool, hook, [Y_TTA_raw, 0], 0, DONATION, "")` -> per-pool TTA balance: `0 -> Y_TTA_raw`. `_takeDebt(TTA, Y_TTA_raw)` -> `TTA delta = 0`.
   g. `Vault.removeLiquidity(pool, hook, 0, [0, S_raw], CUSTOM, "")` -> per-pool shares balance: `s -> s - S`. `_supplyCredit(shares, S)` -> `shares delta = 0`.
   h. State updates: `virtualTTA -= Y_TTA_scaled18` (revert `VirtualTTAUnderflow` if it would go negative), `hookSharesDelta -= S` (signed; may become negative).
4. `reloadBalancesAndRates`. `balancesLiveScaled18 = [Y_TTA, (s - S) * r]`.
5. `_swap` -> `pool.onSwap`. Pool reads `virtualTTA = x - Y_TTA` and `hookSharesDelta = h - S`, derives `y = max(0, ((s - S) - (h - S)) * r) = max(0, (s - h) * r) = y_pre`. The pre-seat reshuffling cancels exactly. Pool computes `Y_TTA_final = (x - Y_TTA) * X_rated / (y_pre + X_rated)`. By construction of step 3a, `Y_TTA_final == Y_TTA`. Returns `Y_TTA`.
6. Vault accounting: `_takeDebt(shares, X_shares)`, `_supplyCredit(TTA, Y_TTA)`, per-pool shares: `s - S -> s - S + X_shares`, per-pool TTA: `Y_TTA -> 0`.
7. `onAfterSwap`: **no further action**. The pre-seat already updated `virtualTTA` and `hookSharesDelta`; nothing residual to clean up because `Y_TTA_final == Y_TTA`. The hook's `onAfterSwap` body short-circuits for the `shares -> TTA` direction.
8. Final deltas: `shares = -X_shares`, `TTA = +Y_TTA`. Router settles user side normally.

End state: pool actual TTA = 0, pool actual shares = `s - S + X_shares`, `virtualTTA = x - Y_TTA_scaled18`, `hookSharesDelta = h - S`. Derived `y_post = ((s - S + X_shares) - (h - S)) * r = (s - h + X_shares) * r = y_pre + X_rated`. CP `y` moved by exactly the user-side change.

### 6.4 LP add (proportional)

Pool state at start: actual TTA = 0, actual shares = `s`, `virtualTTA = x`, `hookSharesDelta = h`, BPT supply = `T`.

1. LP calls `Router.addLiquidityProportional(pool, [maxTTA, maxShares], bptOut, ...)`.
2. `Vault.addLiquidity` computes the proportional amounts: `Delta_s = bptOut * s / T`, `Delta_TTA_pool = bptOut * 0 / T = 0` (actual TTA is 0). The LP's `maxTTA` is the TTA they're willing to contribute; the hook converts it.
3. `onBeforeAddLiquidity`: hook reads the LP's TTA contribution from the in-flight params, deposits it via `exchangeIn` into the Standard Exchange Vault, mints `Delta_shares' = Delta_TTA_user / r` shares. Uses the same `sendTo` / `settle` / `addLiquidity(DONATION)` / `removeLiquidity(CUSTOM)` reconciliation as the swap path so that, from the Vault's perspective, the LP's TTA contribution becomes a larger shares contribution. State update: `hookSharesDelta += Delta_shares'`.
4. `_addLiquidity` proceeds. Per-pool TTA balance: 0 -> 0. Per-pool shares balance: `s -> s + Delta_s + Delta_shares'`. BPT minted: `bptOut`.
5. `onAfterAddLiquidity`: scale state proportionally so the CP ratio is preserved. `T_pre = _totalSupply() - bptOut`.
   - `virtualTTA += bptOut * virtualTTA_pre / T_pre`
   - `hookSharesDelta += bptOut * hookSharesDelta_pre / T_pre` (signed; if `h < 0` the scaling carries the sign)

The hook's conversion of LP TTA in step 3 already shows up in both `actualShares` (via the donation) and `hookSharesDelta` (via the `+= Delta_shares'` update), so the derived `y = (actualShares - hookSharesDelta) * r` is invariant under that reshuffle. The step-5 proportional updates account only for the BPT-supply-scaled growth.

### 6.5 LP remove (proportional)

Pool state at start: actual TTA = 0, actual shares = `s`, `virtualTTA = x`, `hookSharesDelta = h`, BPT supply = `T`. LP wants to burn `Delta_bpt`.

1. LP calls `Router.removeLiquidityProportional(pool, Delta_bpt, [minTTA, minShares], ...)`.
2. `Vault.removeLiquidity` computes `Delta_s = Delta_bpt * s / T`, `Delta_TTA = 0`.
3. `_removeLiquidity` proceeds. Per-pool shares: `s -> s - Delta_s`. LP receives `Delta_s` shares; BPT burned.
4. `onAfterRemoveLiquidity`: scale state proportionally. `T_pre = _totalSupply() + Delta_bpt`.
   - `virtualTTA -= Delta_bpt * virtualTTA_pre / T_pre`; clamp at 0 if the deduction would underflow (defensive).
   - `hookSharesDelta -= Delta_bpt * hookSharesDelta_pre / T_pre` (signed).

The LP can subsequently swap the received shares for TTA via the Standard Exchange Vault directly or via this pool.

## 7. Error Handling

### 7.1 Hook-side rejections

`onRegister` returns false on any registration validation failure (Section 4.4).

`onBeforeInitialize` reverts `InitialInvariantTooSmall` if `s_init * r` does not clear Balancer's `_ensureValidTradeAmount` minimum.

`onBeforeSwap` / `onAfterSwap` and `onSwap` revert with typed custom errors:

- `PreSeatRedemptionFailed(uint256 sharesAttempted, uint256 ttaExpected)`
- `PostSwapDepositFailed(uint256 ttaAttempted)`
- `VirtualTTAUnderflow(uint256 current, uint256 deduct)` — raised when a swap or LP-remove deduction would drive `virtualTTA` below zero. Note: `virtualTTA` itself is clamped at zero on LP-remove only as a defensive floor (see Section 5.5); on swaps the underflow is treated as a hard error so the user gets a clear signal that the pool's TTA side is exhausted.
- `PoolSharesSideExhausted()` — raised from `pool.onSwap` when the derived `y` clamps to zero. The pool refuses degenerate swaps.
- `PoolTTASideExhausted()` — raised from `pool.onSwap` when `virtualTTA == 0`. Symmetric to the above.
- `RateProviderZero()`
- `SwapTooSmall()`

`onBeforeAddLiquidity` reverts `AddLiquidityNotProportional` if `params.kind` is neither `PROPORTIONAL` nor `CUSTOM`.

`onAddLiquidityCustom` and `onRemoveLiquidityCustom` revert `NotHookCaller(msg.sender)` unless the caller (from the Vault's `params.to` / hook context) is `address(this)`. CUSTOM paths are private to the hook's reconcile sequence.

### 7.2 Slippage and bounds

User slippage limits (`minAmountOut`, `maxAmountIn`) are enforced by the Router and Vault `_swap`, as for any other pool. The pool's `getMinimumSwapFeePercentage` / `getMaximumSwapFeePercentage` return 0.01% / 10%. `getMinimumInvariantRatio` / `getMaximumInvariantRatio` return identity (1e18) since unbalanced liquidity is disabled.

### 7.3 Standard Exchange Vault failures

`exchangeIn` / `exchangeOut` reverts propagate to the user. The hook passes `deadline = block.timestamp` on its intra-unlock calls; the Router enforces the user-facing deadline. If `exchangeOut` returns more TTA than requested (stale preview), the surplus arrives at the Balancer Vault but the hook only settles the requested amount; the surplus is wei-level dust held by the Vault (not lost, not credited).

### 7.4 Vault-imposed interactions

- The hook's `addLiquidity(DONATION)` sets `_addLiquidityCalled` for the session. A user who batches "swap + proportional remove" through one `unlock` would pay the round-trip fee. Documented; tests cover the surprise case.
- `_ensureValidTradeAmount` rejects scaled-18 amounts below threshold. Hook pre-seat sizes must clear it; the hook reverts `SwapTooSmall` otherwise.
- Recovery Mode skips all hooks. Recovery proportional withdrawals return shares only; LPs redeem TTA externally via the Standard Exchange Vault if needed. Documented as a known property.

### 7.5 Reentrancy

The Standard Exchange Vault as currently implemented does not call back into Balancer V3. If a future Standard Exchange Vault grew callbacks, the hook's `exchangeIn` / `exchangeOut` calls happen inside `onAfterSwap` (which executes under `_swap`'s `nonReentrant` lock) or `onBeforeSwap` (where the hook's own Vault calls each individually hold `nonReentrant` for their duration). Either way, the Balancer V3 Vault's reentrancy guard catches any reentry attempt. Covered by a malicious-callback mock test.

## 8. Testing

Following Crane conventions (`TestBase_`, `Behavior_`, handlers + invariants).

### 8.1 Test base

`TestBase_StandardExchangeBufferPool` extends `TestBase_VaultComponents` and provides:

- Balancer V3 Vault deployed in setUp.
- Standard Exchange Vault holding TTA and TTB.
- Pool DFPkg + factory deployed; one `StandardExchangeBufferPool` Diamond registered against the Balancer V3 Vault and initialized with a known shares seed.
- Funded test actors.

### 8.2 Behavior libraries

- `Behavior_StandardExchangeBufferPool_Registration`: registration with valid params succeeds; each failure condition in Section 4.4 rejects; written flags match Section 4.
- `Behavior_StandardExchangeBufferPool_Initialization`: `virtualTTA` seeded to `s_init * r`; `hookSharesDelta` seeded to 0 (or `dust_shares_minted` if dust path used); BPT minted matches invariant; undersized seed reverts.
- `Behavior_StandardExchangeBufferPool_Swap_TTAtoShares`: end-to-end; verifies user received expected `Y_shares`, pool TTA is 0 post-swap, `virtualTTA += X`, `hookSharesDelta += Y'`, derived `y` moved by exactly `-Y_rated` (proving hook reshuffle is invisible to CP), all Vault deltas net to zero.
- `Behavior_StandardExchangeBufferPool_Swap_SharesToTTA`: symmetric for the reverse direction; verifies `Y_TTA_final == Y_TTA` exactly (no residual pass), `virtualTTA -= Y_TTA`, `hookSharesDelta -= S` (may go negative), derived `y` moved by exactly `+X_rated`.
- `Behavior_StandardExchangeBufferPool_LP_AddProportional`: with and without LP supplying TTA (covers the hook conversion path); `virtualTTA` and `hookSharesDelta` scale proportionally; CP ratio preserved.
- `Behavior_StandardExchangeBufferPool_LP_RemoveProportional`: `virtualTTA` and `hookSharesDelta` decrease proportionally; LP receives shares only.
- `Behavior_StandardExchangeBufferPool_Clamping`: drive the pool to states where derived `y` would go negative (heavy `TTA -> shares` activity that exhausts the shares side) and verify `pool.onSwap` reverts `PoolSharesSideExhausted` rather than computing degenerate amounts; symmetric for `virtualTTA -> 0`; verify LP-remove clamping behaves correctly under rounding edge cases.
- `Behavior_StandardExchangeBufferPool_Errors`: each typed error in Section 7.1.

### 8.3 Invariant tests

`Handler_StandardExchangeBufferPool` exposes user-facing actions (`swap_TTA_in`, `swap_shares_in`, `add`, `remove`) plus an actor that mutates the Standard Exchange Vault's underlying state to simulate rate drift / yield accrual. Invariants:

- `invariant_PoolHoldsZeroActualTTABetweenOps`: after every handler call, `BalancerV3Vault.getPoolTokenBalance(pool, TTA) == 0`.
- `invariant_VaultReservesMatchPoolBalances`: per token, `Vault._reservesOf[token]` is consistent with the sum of `_poolTokenBalances` across all pools the handler touches.
- `invariant_VirtualTTANonNegative`: `pool.virtualTTA() >= 0`.
- `invariant_DerivedYNonNegative`: `(actualShares - hookSharesDelta * 1) >= 0` after every handler call, OR if violated, `onSwap` reverts `PoolSharesSideExhausted` (clamping floor holds).
- `invariant_HookReshufflesInvisible`: a sequence of (TTA->shares of X) followed by (shares->TTA of equivalent value) leaves derived `y` and `virtualTTA` within rounding tolerance of pre-sequence values, modulo accumulated CP slippage retained as deeper liquidity. Equivalently: `hookSharesDelta` changes from hook ops are perfectly cancelled by the matching `actualShares` changes from those same hook ops.
- `invariant_BPTSupplyTracksInvariant`: `pool.totalSupply()` is consistent with `sqrt(virtualTTA * derived_y)` within rounding tolerance.
- `invariant_NoFreeValue`: sum of value extracted by users (TTA-denominated) is at most sum of value contributed by users.
- `invariant_RateProviderConsistency`: pool quotes never deviate from `rateProvider.getRate() * 1 share` by more than expected CP slippage + swap fee across all reachable states.

### 8.4 Fork tests

`Fork_StandardExchangeBufferPool_Sepolia` deploys the package against the live Balancer V3 Vault on Sepolia, layers a pool over an existing Standard Exchange Vault test fixture, and runs the Section 8.2 Behavior libraries against live infrastructure. Validates that `sendTo` / `settle` / `addLiquidity(DONATION)` / `removeLiquidity(CUSTOM)` work against deployed Vault bytecode.

### 8.5 Adversarial tests

- **Stale-rate sandwich**: Standard Exchange Vault rate changes between `previewExchangeOut` and `exchangeOut`. Hook must not underflow or leak value.
- **Malicious rate provider**: wildly fluctuating `getRate()` returns. Pool must revert gracefully without breaking accounting.
- **Donation griefing**: an attacker calls `addLiquidity(DONATION)` directly. Verify that `onAfterAddLiquidity` correctly grows `virtualTTA` proportionally and BPT-holder value cannot be drained.
- **Reentrant Standard Exchange Vault**: malicious mock attempts to re-enter `Vault.swap` during `exchangeIn` / `exchangeOut`. Must revert on Balancer V3 Vault's `nonReentrant` guard.

## 9. Open Questions

1. Balancer V3's `initialize` may or may not accept `0` for a token amount. If it doesn't, the package requires a dust TTA seed; the hook's `onBeforeInitialize` converts it before writing `virtualTTA` and updating `hookSharesDelta`. Verify behavior in the first implementation step.
2. The hook's `addLiquidity(DONATION)` triggers `_addLiquidityCalled` for the session, which can surprise users batching "swap + proportional remove" in one `unlock` with a round-trip fee. Decision: document the interaction, do not attempt to mask it.

## 10. Out-of-Scope Follow-Ups (Future Work)

- Multi-underlying pool: single deployment registering shares + every Standard Exchange Vault underlying. Would require a different invariant (likely weighted-CP or stable) and a larger hook.
- ERC4626-buffer-style inventory: relax the zero-TTA invariant for cheaper average swaps.
- Dynamic swap fees: `onComputeDynamicSwapFeePercentage` integration with a fee oracle.
