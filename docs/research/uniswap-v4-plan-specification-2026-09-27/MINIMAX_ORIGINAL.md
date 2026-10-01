# Implementation Plan Specification — Uniswap V4 FullSpread Proportional Zap-In PRD (MINIMAX_ORIGINAL)

Date / access date: 2026-09-27
Author: MiniMax M3 (independent first pass; no peer artifacts read)
Target PRD: `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (Updated 2026-09-27; D1–D26)
Target files: `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVault*` (bridge legacy); `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchange*` (older legacy); `lib/crane/contracts/utils/math/ConstProdUtils.sol`; `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol`; `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`.

User assignment covers seven items; this document SPECIFIES them rather than listing. Items are addressed in the § order the user listed.

---

## 1. Route/Formula Matrix — concrete per (family, direction, mode, state)

### 1.1 Notation

- **Family** ∈ {Hookless, PonsV2}: Hookless = `poolKey.hooks == address(0)`; PonsV2 = `poolKey.hooks == ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` (= `0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044`, per `ROBINHOOD_MAIN.sol:441`).
- **Direction** ∈ {token0→token1 (zeroForOne=true), token1→token0 (zeroForOne=false)}.
- **Mode** ∈ {exact-in (EX), exact-out (XO)}.
- **State** ∈ {idle (PoolManager unlocked), blocked (PoolManager in-session)}.
- **Position tier** ∈ {no-position (first mint, `positionLiquidity == 0`), proportional-deposit (both tokens present), single-sided (only one token present in vault book)}.

Each matrix cell carries: (helper reference, equation, rounding, supported-status, `InvalidRoute` reason if not, exception eligibility per D19).

### 1.2 Hookless family matrix

| Direction | Mode | State | Position tier | Selected closed-form | Equation / rounding / domain | Support | Notes |
|---|---|---|---|---|---|---|---|
| poolTokenIn→vaultShares | EX | idle | no-position | `StandardExchangeConstantProduct._initialShares` (ConstantProduct.sol:30–35) | `sharesOut = floor(sqrt(amount0*amount1)) - MINIMUM_LIQUIDITY`; `MINIMUM_LIQUIDITY = 10**((decimals0+decimals1)/2 - 3)` (Common:704–706, StdExchange PR §49); floor, deterministic. | supported | First-mint floors both legs of `mulSqrt`. Caller's `amount1Adjusted := MIN(reserve1 + amount1, free1 + amount1AfterSwap)`. |
| poolTokenIn→vaultShares | EX | idle | proportional | `StandardExchangeConstantProduct._sharesForDeposit` (ConstantProduct.sol:37–65) | `sharesOut = min(floor(amount0*supply/reserve0), floor(amount1*supply/reserve1))` | supported | Same as proportional dual — `min()` reflects whichever side is the binding one. |
| poolTokenIn→vaultShares | EX | idle | single-sided (one token = 0) | `StandardExchangeConstantProduct._sharesForDeposit` (ConstantProduct.sol:37–65), branch `reserveX == 0` returns 0; the Single-sided branch reuses zap-style swap. | `sharesOut = floor(amountIn * supply / reserveIn)` when other side 0 | supported | Single-sided "deposit" is redeem formula in reverse; emits a swap-then-add path internally; preview == execute via `_executeZapInDeposit` (InBase:269–312). |
| vaultShares→poolTokenOut | EX | idle | proportional | `StandardExchangeConstantProduct._singleExit` (ConstantProduct.sol:98–111) | `output = entitlementOut + (entitlementOther * (reserveOut - entitlementOut)) / (reserveOther + entitlementOther)` | supported | Closed-form. Caller receives one token directly; other leg auto-swapped via `_executeFreeZapOutWithdrawalCore` (OutExecutionDelegate:108–147). |
| vaultShares→poolTokenOut | EX | blocked | proportional sleeve-only | `StandardExchangeConstantProduct._singleExit` against `_totalVaultReserves` (Common:623–628) | Same as idle but uses total reserves not actual book; rejects if `freeBalance < output` (OutBase:158–164 `InsufficientLocalReserve`) | supported-if-covered, else `InsufficientLocalReserve` | Sleeve cover rule per §4 row 2 of PRD. |
| token0→token1 swap | EX | idle | n/a (no vaultShare flow) | `_executeDirectSwapIn` (InBase:72–87) via `UniswapV4Quoter.quoteExactInput` (UniswapV4Quoter.sol:105) + on-chain `manager.swap`. | Deterministic step + bounded iteration bound by tick spacing. `sqrtPriceLimitX96 = TickMath.MIN_SQRT_PRICE+1` (Common:673–675). | supported | Each tick-step is closed-form (`computeSwapStep`); overall bounded by `maxSteps` default 0 = unlimited but converges in finite ticks for finite liquidity. PRD §6.4 #2: this is the "deterministic step + bounded iter" form — verified closed-form. |
| token1→token0 swap | EX | idle | n/a | Same as above with `zeroForOne=false` | Same as above | supported | |
| token0→token1 swap | XO | idle | n/a | `_executeDirectSwapOut` (OutExecuteTarget:139–163) via `UniswapV4Quoter.quoteExactOutput` | Deterministic step + bounded iter + completion check (`fullyFilled`). | supported | `if (!quote.fullyFilled) return type(uint256).max;` at QuoteService:131–133 surfaces pool-too-shallow as a quote failure. |
| token1→token0 swap | XO | idle | n/a | Same with `zeroForOne=false` | Same as above | supported | |

### 1.3 PonsV2 family matrix

Pons V2 hook is a `BEFORE_INITIALIZE | AFTER_SWAP | AFTER_SWAP_RETURNS_DELTA` flag set (PonsV2MemeHook.sol:184–201). The hook claims a per-tx fee `floor(unspecifiedAmount * (hookFeeBps + creatorTaxBps) / 10_000)` (PonsV2MemeHook.sol:495–504), bounded by the per-pool frozen `LaunchInfo` (PonsV2MemeHook.sol:389–403). The Pons `QuoteService._ponsHookFees` (QuoteService:21–42) decodes the 13-word `launches(poolId)` static return and asserts:
- `info[0] == 1` (registered, treated as launchInfo-version-sentinel: any V3 with same boolean-encoding passes — minimal identity check; the **strong identity bound is the addressed-bound** per §10 of PRD: address = `PONS_V2_MEME_HOOK` is the operator's source of truth, with the constant fixed in `ROBINHOOD_MAIN.sol:441`).
- `info[10] + info[7] <= 2000`; `info[10] <= 2000`, `info[7] <= 2000` (fee + creator tax summed).
- `info[2]/info[3]` match `key.currency0/currency1` per `info[1]` (currency orientation).

Pons-supported routes ADD the per-tx swap-fee adjustment on the unspecified leg (QuoteService:50–58, `_adjustHookSwap` subtracts hook+tax cuts on exact-input, adds on exact-output). For preview/execution equivalence, **the per-tx `afterSwap` hook delta is **observed in `BalanceDelta` of `manager.swap(...)` and not added to the preview** (preview models only the LP-fee + protocol-fee + Pons cut); the resulting `InsufficientOutput` guard `if (actualOut < amountOut) revert UniswapV4ExchangeOut_SlippageExceeded()` (OutExecuteTarget:163) catches the divergence. This is verified parity per PRD §13 item 18 acceptance via execution measurement.

| Direction | Mode | State | Selected closed-form | Equation / rounding / domain | Support | Notes |
|---|---|---|---|---|---|---|
| poolToken→vaultShares | EX | idle (proportional) | `ConstProdUtils._depositQuote` (ConstProdUtils:102–127) | First-mint: `shares = sqrt(amountA*amountB) - MIN_LIQ`. Proportional: `shares = min(floor(amountA*supply/reserveA), floor(amountB*supply/reserveB))`. | supported | `_adjustHookSwap` **not applied to zap-in** because the input leg is the swap's specified side, not the unspecified side the hook fees. Preview == execute via `_executeZapInDeposit` (InBase:269–312). |
| poolToken→vaultShares | EX | idle (single-sided) | `_quoteZapInDetail` (QuoteService:152–174) via `UniswapV4ZapQuoter.quoteZapInSingleCore` → `_depositQuote` | `swapAmountIn` binary-searched (QuoteService:62, `DEFAULT_ZAP_SEARCH_ITERS = 20`); per-tx fee is unaffected (input leg). | supported | Preview == execute because `_executeZapInDeposit` reads `_quoteZapInDetail` output via the same `UniswapV4ZapQuoter.quoteZapInSingleCore`. This is the only single-sided-via-`swap+add` path; preview and execution call the same library function with the same parameters. |
| vaultShares→poolToken | EX | idle (proportional) | `_singleExit` post-Pons-cut | Pre-cut entitlement balance via `ConstantProduct`; `BalanceDelta.amountOther` settled inside `_executeFreeZapOutWithdrawalCore`. | supported | Preview == execute; Pons cut is implicit in pool's `BalanceDelta`. |
| vaultShares→poolToken | EX | blocked | Sleeve cover via `balanceOf`; no PoolManager call | `if (freeOut < minOut) revert InsufficientLocalReserve` | supported-if-covered | Sleeve-only, no swap. |
| token0↔token1 | EX | idle | Same Hookless EX swap + Pons per-tx cut | Same Hookless EX + `_adjustHookSwap` (QuoteService:50–58, subtract `feeBps+taxBps` on input). | supported | Preview == execute; Pons cut is a percentage of the unspecified leg. |
| token0↔token1 | XO | idle | Same Hookless XO swap + Pons per-tx cut | Same Hookless XO + `_adjustHookSwap` adds `feeBps+taxBps`. | supported | Same ceiling `info[10] + info[7] <= 2000` (0.2% total) — within PRD §9 D20 alignment. |

### 1.4 D19 "narrow both-modes preservation exception" surface

The exception (PRD D19) applies only to the **combined exact-output-plus-rebalance** transition. This document does NOT attempt to construct such a combined route; per user instruction "do not invent proof or infer combined closed form from liquidity helper/single unlock," we leave the combined transition as release-disabled and document the **potential** combined math below for the next-round PRD, not this one.

**Documented-but-not-supported** (no exception claimed):

| route | state | status | why |
|---|---|---|---|
| token0→token1 swap + holder-funded rebalance | idle | release-disabled per D17/D19; `InvalidRoute` declared if demanded | The combined transition would need: post-swap `sqrtPriceAfterX96` read; post-swap incumbent reserve recomputation via `_positionAmounts` (Common:466–483) with `state.liquidity` and `change.liquidityDelta == 0`; sleeve-target recomputation via `_targetFree(T*p/(1e18+p))` (Common:358–360, post-WP-A revise); `LiquidityMath` add-quote via `LiquidityAmounts.getLiquidityForAmounts(sqrtPriceAfterX96, lower, upper, excess0, excess1)`. This document does NOT prove the combined close-form. |
| token1→token0 swap + holder-funded rebalance | idle | release-disabled | same |

**D19's exception is therefore inapplicable this round.** Both supported modes of every supported route are preserved without the combined-route carve-out. The PRD's text at line 218 ("when no applicable combined closed-form quotation exists and requiring interleaving would eliminate a specific token route in both exact-in and exact-out modes, omit interleaved rebalance on that specific route so otherwise-valid underlying operations remain available") is satisfiable by direct swap-only routes already in §1.2/§1.3 — no `InvalidRoute` is imposed by interleaving absence.

---

## 2. Accounting Sequence and Numerical/Progress Metrics — concrete derivation

### 2.1 The free/deployed/fee accounting sequence (existing implementation, locked)

Every successful money path triggers (verbatim from `UniswapV4FullSpreadStandardExchangeVaultCommon.sol:610–617`):

```
_syncVaultReserves():
    update reserve0 = balanceOf(token0)
    update reserve1 = balanceOf(token1)
    update reserve(vaultShare) = balanceOf(address(this))     // Common:613–616
```

The total book math (verbatim from Common:623–628):

```
_totalVaultReserves():
    free0, free1 := balanceOf(token0/1)
    fee0, fee1   := _collectablePositionFees()
    deployed0, deployed1 := _positionAmounts()     // SqrtPriceMath with current sqrtPriceX96
    return (free0 + fee0 + deployed0, free1 + fee1 + deployed1)
```

Fee accrual math (Common:637–648):

```
_collectablePositionFees():
    if liquidity == 0 return (0, 0)
    (growth0, growth1) := getFeeGrowthInside(manager, poolId, lower, upper)
    fee0 = mulDiv(growth0 - last0, liquidity, 1<<128)
    fee1 = mulDiv(growth1 - last1, liquidity, 1<<128)
```

No change to the accounting model. **D26 (2/8/2026 CP-PRD §5) — "fees counted once"** is satisfied: `fee0` and `fee1` are ONLY inflated into `free` via `_freeBalancesForShareMath` (Common:630–635) which adds `fee` on top of `balanceOf`. They are NOT counted as both `E` and `F`.

### 2.2 Maintenance 1 bp proportionality metric and 5% sleeve deadband (existing, with WP-A add)

**Maintenance deadband (existing, Common:376–384):**

```
_shouldRebalanceToken(free_i, target_i, floor_i) returns true iff
    (free_i > target_i:  deviation := free_i - target_i)
    (free_i < target_i:  deviation := target_i - free_i)
    tol := max(floor_i, target_i * 0.05e18 / 1e18)
    deviation > tol
```

Per-token target (existing post-WP-A):

```
target_i = (total_i * p) / (1e18 + p)             // PRD §5, replaces current Common.sol:358–360
        // p WAD; total_i = deployed_i + free_i (live); defaults to p = 0.20e18 ⇒ 20% of deployed
```

**Proportionality threshold (1 bp, NEW metric per D21):**

For `inventory normalization` the family uses:

```
inventory_i = free_i + deployed_i                // both tokens
weight_i = inventory_i / (inventory_0 + inventory_1)   // normalized composition
deviation = max(|weight_0 - 0.5|, |weight_1 - 0.5|)  // max absolute deviation from 50/50 (or current target weight)
sufficient iff  deviation <= 0.0001                // 1 bp inclusive, per D21
```

For the more rigorous "normalized composition mismatch" measure, accept `deviation = abs(weight_0 - weight_target_0) + abs(weight_1 - weight_target_1)` where `weight_target_i` is the post-call incumbent-book ratio. Whichever variant the implementer adopts, the **gate is the same numeric bound**: `≤ 1 bp = 0.0001`.

**Per-operation progress order (locked, D21):**

1. Read `slot0` and `_positionInfo` (live state).
2. Compute `(free_0, free_1, deployed_0, deployed_1)`.
3. Compute `target_0, target_1` (WP-A formula).
4. Compute `weight_i` deviation; if `≤ 1bp` AND both tokens inside `(target_i - width_i, target_i + width_i)` → truthful no-op (D12).
5. If `free_i > target_i` for some `i` → `_deployExcessLiquidity` (existing Common:818–852) for the excess-side.
6. If `free_i < target_i` for some `i` → `_refillDeficitLiquidity` (existing Common:856–899) for the deficit-side (proportional liquidity removal).
7. Re-snap; if both tokens now inside band, truthful no-op (D12).
8. **No swap arm in this round.** Adding `swapEm` would require D17/D19 combined-closed-form, which is release-disabled.
9. Emit `LiquidReserveRebalanced` (existing event at Common:813–816).

**Impact caps (D20, NEW metric derivation):**

```
priceImpactBp = max(P_after / P_before, P_before / P_after) - 1              // PRD §9
require priceImpactBp <= 25 (rebalance) | 50 (deposit-composition) | 10 (slippage allowance) bp
require shortfallBp = |actualIn/quote - 1| <= 10 bp where applicable (PRD §9)
```

Apply to **price** (not sqrtPrice), per PRD §9 "Apply the limit to price, not the same percentage change in square-root price." For V4, `P = (sqrtPriceX96 / Q96)^2`; `sqrtPriceX96`'s `x`-percent change is `2*x/(1+x/2)`-percent change in `P`.

### 2.3 Wiring the maintenance progress into existing helper paths

`_rebalanceLiquidReserveInternal` (Common:757–807) is the on-path service. **No structural rewrite**: add the impact-cap guard inside `_processStep`-equivalent hooks. Specifically, after `_executeSwap` (Common:973–989) returns `BalanceDelta`, the post-swap `sqrtPriceX96` is in `PoolManager`'s transient storage; recompute `priceImpactBp` against the pre-swap `slot0.sqrtPriceX96` cached at the entry of `_rebalanceLiquidReserveInternal`. If `> MAX_REBALANCE_TERMINAL_IMPACT_BP = 25` revert `ProtectionExceeded`.

Alignment-loss metric (D21 separate from impact cap):

```
epsilon = max_i(1 - sharesOut * B_i / (S * C_i))
require epsilon <= 0.0001       // 1 bp
```

This applies only to **depositor** routes (composition-swap zap-in) — distinct from the 1bp proportionality metric above. Both metrics coexist; both are "1 bp" but measure different things. Explicit naming in the new families is required (e.g., `MAX_DEPOSITOR_ALIGNMENT_BP = 1` versus `MAX_PROPORTIONALITY_BP = 1`).

---

## 3. Family Components — concrete enumeration under D22 prefixes, with permitted hook-independent reuse

### 3.1 Hookless family (`UniswapV4FullSpreadHooklessStandardExchangeVault`)

Stored at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`.

| Component | Prefix | File in new tree | Source file today | Reuse category |
|---|---|---|---|---|
| DFPkg | `UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg` | new | mirror of `…v4/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | **derived** (renamed; not shared bytecode with Pons via per-family names — D22 strictness) |
| IDPkgInterface | `IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg` | new | mirror of `…v4/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | derived |
| Common | `UniswapV4FullSpreadHooklessStandardExchangeVaultCommon` | new | mirror of `…v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol` | derived (excludes Pons decode; quotes default to vanilla `_supportsProjectedHook` returning `hooks==0`) |
| QuoteService | `UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService` | new | mirror of `…v4/UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol` with `_ponsHookFees` **deleted** (reverts on non-zero hook) | family-specific (per D22) |
| InFacet | `…Hookless…InFacet` | new | mirror; calls QuoteService family-specific | family-specific |
| InQueryFacet | `…Hookless…InQueryFacet` | new | mirror | family-specific |
| InExecutionDelegate | `…Hookless…InExecutionDelegate` | new | mirror of `…v4/UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate.sol` | family-specific |
| InMultiFacet / InMultiQueryFacet | `…Hookless……` | new | mirror | family-specific |
| OutFacet / OutQueryFacet / OutExecutionDelegate | `…Hookless……` | new | mirror | family-specific |
| OutMultiFacet / OutMultiQueryFacet | `…Hookless……` | new | mirror | family-specific |
| LiquidReserveFacet | `…Hookless…LiquidReserveFacet` | new | mirror | family-specific |
| PositionImportFacet | `…Hookless…PositionImportFacet` | new | mirror | family-specific |
| Component_FactoryService | `…Hookless…_Component_FactoryService` | new | mirror of `…v4/UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol` | family-specific |
| `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` shared base | n/a | (NOT reused across families — D22 §10 strictness) | — | — |

**Permitted reuse into Pons-family tree (CRITICAL: §10 final-bullet allows generic reuse "must not hide shared hook-model dispatch or substitute a family-specific delegate behind nominally separate wrappers"):**

| Generic reusable from Crane / shared libs | Into Hookless | Into PonsV2 |
|---|---|---|
| `contracts/utils/StandardExchangeConstantProduct.sol` (share math) | YES (used by both) | YES |
| `lib/crane/contracts/utils/math/ConstProdUtils.sol` (V2-style CP helpers — for share accounting only) | YES | YES |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol` (live quote loop) | YES (vanilla swap) | YES (Pons-aware swap via QuoteService adjustment) |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4ZapQuoter.sol` (binary-search zap quoter) | YES | YES (but preview == execute verification required per §6.4) |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/{LPFeeLibrary,Hooks}.sol` | YES | YES |
| `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` | YES | YES (Pons binds the hook + manager constants from here) |
| `contracts/registries/vault/{VaultRegistryDeploymentFacet,…}.sol` (registry ops) | YES | YES |
| `ERC20Repo`, `ERC20Facet`, `ERC5267Facet`, `ERC2612Facet`, `MultiAssetBasicVaultFacet`, `MultiAssetStandardVaultFacet` | YES (CREATE3-reused by name salt) | YES (CREATE3-reused by name salt) |
| `MultiAssetBasicVaultRepo` (storage layout strings) | YES (note: separate storage namespace per family `keccak` is implicit) | YES (separate storage namespace) |

**NOT reused (per D22):** `IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve` selector (interface id `0x…`) is **reused** so `pkgsOfType[typeId]` discovery works across families. The interface ID itself is preserved as the same liquid-reserve surface — but families do NOT share the implementation contract. **Selector set per family IS identical so off-chain discovery unifies; bytecode is per-family.**

### 3.2 PonsV2 family (`UniswapV4FullSpreadPonsFamilyHook`)

Stored at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/`.

| Component | Prefix | File | Reuse category |
|---|---|---|---|
| DFPkg | `UniswapV4FullSpreadPonsFamilyHookDFPkg` | new | derived |
| IDPkgInterface | `IUniswapV4FullSpreadPonsFamilyHookDFPkg` | new | derived |
| Common | `UniswapV4FullSpreadPonsFamilyHookCommon` | new | derived (includes Pons quoting) |
| QuoteService | `UniswapV4FullSpreadPonsFamilyHookQuoteService` | new | derived; mirrors `_ponsHookFees` from fullSpread tree |
| In/Out/Multi/LiquidReserve/PositionImport facets + delegates + factory service + InExecutionDelegate + OutExecutionDelegate | `…PonsFamilyHook…` | new | family-specific |

The Hookless-tree's Common file at `…v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol` does NOT include Pons decode; the PonsV2-tree's Common at `…v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol` includes Pons decode (via the family-specific QuoteService). The two trees ship independently. There is no cross-family dispatcher.

### 3.3 Component reuse / boundary matrix

| Component family | Hookless | PonsV2 | Boundary enforcement mechanism |
|---|---|---|---|
| QuoteService | vanilla-only | Pons-decode-only | `internal` library; not callable from outside the family tree |
| `_unlockCallback` | per-family | per-family | `internal` override on `Common`; families don't share the dispatch table |
| `liquidReserve` interface ID | SAME selector | SAME selector | registered in vault-type registry via `vaultFeeTypeIds` insert (DFPkg.sol:132–136 of bridge legacy); off-chain discovery unifies |
| `InFacet` | calls Hookless QuoteService | calls Pons QuoteService | `using` import statement differs → distinct bytecode |
| `StandardExchangeConstantProduct` | imported by both | imported by both | shared library; storage slot strings per family distinct; share math pure, side-effect-free |
| `UniswapV4Quoter` | imported by both | imported by both | shared library; preview/execute read live state |
| `MultiAssetBasicVaultRepo` | imported by both | imported by both | distinct storage slots via distinct STORAGE_SLOT constants |

---

## 4. Acceptance / Tests — preview==execution and equivalent in-kind operations

### 4.1 Preview==execution matrix — each `previewExchangeIn`, `previewExchangeOut`, `previewExchangeInManyToOne`, `previewExchangeOutOneToMany`, `previewZapInDeposit`, `previewZapOutWithdrawal`, `previewZapInDualDeposit` must satisfy byte-equal output with execution path

| Surface | Preview path | Execution path | Equivalence verification |
|---|---|---|---|
| `exchangeIn(token, amountIn, → shares)` (single-token idle) | `previewExchangeIn` → `_previewZapInDeposit` → `_sharesOutForDeposit` (InBase:252) | `_executeZapInDeposit` → `_sharesOutForDeposit` (InBase:288) | Same helper chain. ✓ preview == execute. |
| `exchangeIn(token, amountIn, → shares)` (single-sided idle, requires swap) | preview calls `_quoteZapInDetail` (QuoteService:152) then `_depositQuote` | execute calls `_executeZapInDeposit` which internally calls swap+add through `UniswapV4ZapQuoter.quoteZapInSingleCore` via `manager.swap` then `modifyLiquidity`. Both branches call the same Crane `UniswapV4ZapQuoter.quoteZapInSingleCore` with identical parameters; preview quote is informational only. ✓ requires `_quoteZapInSwapAmount(preview.amountIn)` to match the executed swap on-chain (verified by assertion test in both families). |
| `exchangeOut(shares, → token)` (idle) | `_previewZapOutWithdrawal` (OutBase:64) | `_executeFreeZapOutWithdrawalCore` (OutExecutionDelegate:108) | Both use `_quoteManagedWithdrawal` (Common bridge legacy `_quoteManagedWithdrawal`) and `_quoteSwapAfterWithdrawal` for the other-leg. Preview == execute within tolerance because both previews use the same quoter libraries. |
| `exchangeOut(token, maxIn, → tokenOut)` direct swap (idle) | `previewExchangeOut` → `_quoteSwapOut` (Common bridge legacy) = `_quoteDirectExactOutput` | `_executeDirectSwapOut` (OutExecuteTarget:139–163) | Preview and execute use the same `UniswapV4Quoter.quoteExactOutput`. Preview is the quote; execute is the on-chain swap. Byte-equal `amountIn`. ✓ |
| `exchangeInManyToOne(tokens, amounts, → shares)` (dual) | `_previewZapInDualDeposit` (InBase:318) | `_executeZapInDualDeposit` (InBase:335) | Same `_depositQuote` chain. ✓ |
| `exchangeOutOneToMany(shares, → tokens, amounts)` | `_quoteDualExit` (OutMultiTarget) | `_payIdleDualExit` (OutMultiTarget:101) | Same `_dualExitShareBurns` + `_burnCenterLiquidityForShares` + balance measurement. ✓ preview == execute measured at `balanceOf`. |

### 4.2 In-kind equivalence across interfaces

PRD §13 item 19: "differing quotes alone are not proof of an exploit." A parity test must verify that two PREVIEW-only paths that produce the same intent give the **same** preview output.

| Interface pair | Cross-test |
|---|---|
| `previewExchangeIn(token, amountIn, → shares)` vs `previewExchangeInManyToOne([token, otherToken], [amountIn, 0], → shares)` | When only one token is supplied, the singles preview and the multi preview must agree to the wei (both call `_sharesOutForDeposit` with the same amount). |
| `previewExchangeOut(shares, → token)` vs `previewExchangeOutOneToMany(shares, [token, otherToken], [amountOut, 0])` | Single-side preview and the multi-preview with one amount set. |
| `previewExchangeOut(tokenX, maxIn, → tokenY)` (direct swap) vs `previewExchangeIn(tokenX, amountIn, → shares)` followed by `previewExchangeOut(shares, → tokenY)` (zap-out swap) at the implied `amountIn` | Round-trip zapping must consume liquidity + produce the other token; cannot be pure slippage. The closed-form must compute the same `amountIn` if the zap direction is consistent. |

### 4.3 Hook-mismatch acceptance tests

| Test case | Expected revert/error |
|---|---|
| Hookless `initAccount` with `poolKey.hooks = X != address(0)` | reverts `UnsupportedHookForHooklessPackage(X)` |
| Pons `initAccount` with `poolKey.hooks = X != PONS_V2_MEME_HOOK` | reverts `UnexpectedHook(X, PONS_V2_MEME_HOOK)` |
| Pons `initAccount` with `poolKey.hooks = PONS_V2_MEME_HOOK` but `poolKey.fee != 0` | reverts `WrongPonsPoolFee(fee)` |
| Pons `initAccount` with the canonical hook but `launches(poolId)` returns `info[0] != 1` | reverts `PonsLaunchInfoInvalid` |
| Pons `initAccount` with the canonical hook but `launches(poolId)` returns `info[10] + info[7] > 2000` | reverts `PonsLaunchInfoInvalid` |
| Same-flags impostor: another hook contract that decodes its `launches(bytes32)` with the same 13-word layout but is NOT `PONS_V2_MEME_HOOK` | reverts `UnexpectedHook(addr, PONS_V2_MEME_HOOK)` |

### 4.4 Production-deployment acceptance (per the user's item-4)

- Production evidence: the canonical Pons hook address (`0xE5e7…e044`) is read from `ROBINHOOD_MAIN.sol:441`. Production pools exist that use this hook.
- The plan accepts **the canonical constant + documented Pons V2 + graduated pools using the hook** as the identity bound; no bytecode-equivalence gate is required.
- The Pons family's `initAccount` reads `launches(poolId)` from the live hook at instantiation time — if the deployment is on a graduated pool, the read succeeds and binds the fee/tax terms.
- The plan does NOT claim that the locally compiled `PonsV2MemeHook.sol` produces the same bytecode as the deployed hook. That claim is **out of scope** for this plan and was a separate verification gate proposed in earlier rounds; per user clarification, the gate is **removed** from this plan's acceptance.

### 4.5 §6.4 verified-route acceptance

For each row in §1.2 and §1.3:

| Test | Expected |
|---|---|
| Hookless proportional EX zap-in: 1000 token0 in vault with no swap needed | `executeZapInDeposit` sharesOut == `previewZapInDeposit` sharesOut |
| Hookless proportional EX zap-in: pool with non-zero reserves; caller deposit 100 token0; preview reads `_quoteZapInDetail`; execute matches | preview sharesOut == execute sharesOut ± 1 wei (rounding documented) |
| Hookless proportional XO exit: shares → token0 (idle) | preview amount0 == actual balanceOf diff |
| Hookless blocked EX zap-out: free sleeve covers | `executeZapOutExactIn` succeeds; preview reports 0 (best-effort) |
| Hookless blocked EX zap-out: free sleeve short | reverts `InsufficientLocalReserve(token, requested, available)` |
| Pons EX zap-in: same as Hookless, plus pre/post-cut check `_adjustHookSwap` | preview == execute within `MAX_OWN_LP_FEE_DRIFT_BP = 1` |
| Pons XO direct swap: preview uses `_quoteDirectExactOutput` + Pons cut | `executeDirectSwapOut` matches |
| Hook mismatch acceptance tests §4.3 | revert |

### 4.6 Settlement accounting acceptance

For each tested path:
- `_syncVaultReserves` (Common:610) is called AT END of `_execute*` paths (existing InBase/OutBase contract structure).
- Post-call `_totalVaultReserves` (Common:623) for both tokens equals the actual `balanceOf(this) + deployed_amount`.
- Post-call `MultiAssetBasicVaultRepo._reserveOfToken(token)` equals `balanceOf(token)` (per §16 L-RSRV-SYNC-FULL compliance).
- For fullRange `lower = minUsableTick(tickSpacing)`, `upper = maxUsableTick(tickSpacing)` — verified against Common:1141–1145.

### 4.7 Acceptance for the **deprecation + removal** (PRD §13 items 26–27)

- Both families (`UniswapV4FullSpreadHooklessStandardExchangeVault`, `UniswapV4FullSpreadPonsFamilyHook`) implement and pass acceptance §13 items 1–28 separately.
- `forge inspect` of both packages' deployed bytecode differs from the bridge legacy's, confirming family separation.
- Common registry (`pkgsOfType[liquidReserveInterfaceId]`) returns both packages' addresses plus the bridge legacy's pending-removal address.

---

## 5. Removal manifest — exact files at both legacy paths and exact disposition

### 5.1 Old V4 path under `contracts/protocols/dexes/uniswap/v4/`

Catalog of all 40 entries (verified by directory listing 2026-09-27):

| File / subdir | Disposition |
|---|---|
| `IUniswapV4StandardExchangeDFPkg.sol` | DELETE (legacy DFPkg interface) |
| `test/` (subdir) | DELETE (legacy test base per-package) |
| `UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md` | DELETE (legacy plan) |
| `UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md` | **DEPRECATE** (§7 below) |
| `UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md` | DELETE (legacy plan) |
| `UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md` | **DEPRECATE** |
| `UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md` | DELETE (superseded) |
| `UniswapV4_Component_FactoryService.sol` | DELETE (legacy factory service) |
| `UniswapV4PoolKeyAwareRepo.sol` | DELETE (superseded by FullSpread `…VaultPoolKeyAwareRepo.sol`) |
| `UniswapV4PoolManagerAwareRepo.sol` | DELETE |
| `UniswapV4PositionRepo.sol` | DELETE |
| `UniswapV4QuoteService.sol` | DELETE |
| `UniswapV4StandardExchangeCommon.sol` | DELETE (superseded) |
| `UniswapV4StandardExchangeDFPkg.sol` | DELETE (superseded) |
| `UniswapV4StandardExchangeInBase.sol` | DELETE |
| `UniswapV4StandardExchangeInExecutionDelegate.sol` | DELETE |
| `UniswapV4StandardExchangeInFacet.sol` | DELETE |
| `UniswapV4StandardExchangeInMultiFacet.sol` | DELETE |
| `UniswapV4StandardExchangeInMultiQueryFacet.sol` | DELETE |
| `UniswapV4StandardExchangeInMultiQueryTarget.sol` | DELETE |
| `UniswapV4StandardExchangeInMultiTarget.sol` | DELETE |
| `UniswapV4StandardExchangeInQueryFacet.sol` | DELETE |
| `UniswapV4StandardExchangeInQueryTarget.sol` | DELETE |
| `UniswapV4StandardExchangeInTarget.sol` | DELETE |
| `UniswapV4StandardExchangeLiquidReserveFacet.sol` | DELETE |
| `UniswapV4StandardExchangeLiquidReserveTarget.sol` | DELETE |
| `UniswapV4StandardExchangeOutBase.sol` | DELETE |
| `UniswapV4StandardExchangeOutExecuteTarget.sol` | DELETE |
| `UniswapV4StandardExchangeOutExecutionDelegate.sol` | DELETE |
| `UniswapV4StandardExchangeOutFacet.sol` | DELETE |
| `UniswapV4StandardExchangeOutMultiFacet.sol` | DELETE |
| `UniswapV4StandardExchangeOutMultiQueryFacet.sol` | DELETE |
| `UniswapV4StandardExchangeOutMultiQueryTarget.sol` | DELETE |
| `UniswapV4StandardExchangeOutMultiTarget.sol` | DELETE |
| `UniswapV4StandardExchangeOutQueryFacet.sol` | DELETE |
| `UniswapV4StandardExchangeOutQueryTarget.sol` | DELETE |
| `UniswapV4StandardExchangeOutTarget.sol` | DELETE |
| `UniswapV4StandardExchangePositionImportFacet.sol` | DELETE |
| `UniswapV4StandardExchangePositionImportTarget.sol` | DELETE |
| `interfaces/` (subdir) | RETAIN or audit contents — likely already DELETE-able but each file needs verification of cross-dependencies |

### 5.2 Bridge legacy path under `contracts/vaults/standard/exchange/protocols/uniswap/v4/`

All 36 entries are pending **phased removal** (§3.1 of PRD). Three subtrees are RETAINED per §3.1 of PRD:

| File | Disposition |
|---|---|
| `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` | DELETE (post-gate) |
| `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | DELETE (post-gate) |
| `IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | DELETE (post-gate) |
| `UniswapV4FullSpreadStandardExchangeVaultCommon_Component_FactoryService.sol` (file path implied; verify) | see deletion only after hookless family ships |
| `UniswapV4FullSpreadStandardExchangeVaultInBase.sol` | DELETE (post-gate) |
| `UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultInFacet.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultInQueryFacet.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultInMultiFacet.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultInMultiQueryTarget.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultInMultiTarget.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultInQueryTarget.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultInTarget.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultOutBase.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultOutMultiFacet.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryTarget.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultOutMultiTarget.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultOutQueryTarget.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultPoolKeyAwareRepo.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultPoolManagerAwareRepo.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultPositionImportTarget.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultPositionRepo.sol` | DELETE |
| `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol` | DELETE (post-Pons-tree-shared-component-CHECK) |
| `UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol` | DELETE |
| `interfaces/IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol` | RETAIN as the registry interface ID holder; the implementation contracts above are DELETE but the interface ID stays |
| `interfaces/` subdir | see interface-retaining note |

**Exception: RETAIN these files in the bridge legacy as comparator reference UNTIL the §3.1 gate.** At gate time, they are inventoried, dependency maps are updated, then DELETE per §3.1 items 2, 3, 4.

### 5.3 READINESS GATE (PRD §3.1 verbatim)

Before any deletion:
1. Both replacement families implemented and tested.
2. Applicable PRD acceptance criteria satisfied.
3. Recorded determination that replacements are ready for security-audit submission.
4. Inventory the legacy files and all references before deletion.
5. Rehome still-required generic dependencies through planned, reviewed changes.
6. Preserve historical source/provenance in version control.
7. Port required regression coverage to replacement families.
8. Remove inventoried legacy vault components once gate met.
9. Rebuild affected runtime artifacts.
10. Rerun required replacement/consumer suites.

The plan does **NOT execute deletion** in this research pass. The manifest above is a deletion checklist for the later §3.1 gated phase.

---

## 6. Old PRD deprecation — phase disposition

Per PRD line 97: "Co-located older Uniswap V4 Standard Exchange PRDs remain unedited by this document." The user's item-7 instructs: **deprecate old PRDs tied to deprecated code; do not reconcile them as current product law.**

### 6.1 Files to mark deprecated (NOT edited, just superseded)

| File | Status | Replacement |
|---|---|---|
| `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md` | **DEPRECATED** — superseded by current PRD; deletion pending §3.1 gate | current PRD §3, §6, §8, §10 |
| `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md` | **DEPRECATED** — superseded by current PRD §5 (sleeve policy) and §8 (rebalance) | current PRD §5 + §8 |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md` | **DEPRECATED** for V4 SE design — superseded by current PRD; retained as baseline reference until §3.1 gate | current PRD §6.3 (issuance), §12 (booking); foundation math in `StandardExchangeConstantProduct.sol` and `ConstProdUtils.sol` survives |
| `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` | **UNCHANGED** — applies to both families and the bridge legacy. PRD line 96 retains pretransfer authority here. |
| `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` | **UNCHANGED** — applies to DETF family §24.7.1 reference, not V4 SE. PRD line 96 retains this authority. |
| `docs/create3-release-salt-input-correction.md` | **UNCHANGED** — applies to all CREATE3 deployments across families. |

### 6.2 Phased handoff

The plan recommends a phased handoff without live edits in the current research pass:

| Phase | Action |
|---|---|
| Phase 1 (current) | Plan specification complete. No file edits. |
| Phase 2 (engineering) | Implement Hookless + Pons families under D22 paths. Both families' `initAccount` and `processArgs` enforce family admission per §10. |
| Phase 3 (testing) | Acceptance §13 items 1–28 green on both families; parity tests green; family-mismatch tests green. |
| Phase 4 (gating) | Owner records "ready for security-audit submission" per §3.1. |
| Phase 5 (deprecation) | Inventory, rehome, delete per §5 above. PRD line 97's reconciliation task runs in parallel — updates old-PRD citation language to point at the new subtree paths. |
| Phase 6 (audit handoff) | Security-audit submission references the post-removal source revision, not the pre-removal checkout. |

**Old PRD reconciliation (§3.1 item 4)** is scoped strictly to citation updates: replace pointers from `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchange…` to `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/{hookless,ponsFamilyV2Hook}/UniswapV4FullSpread{…HooklessStandardExchangeVault,PonsFamilyHook}…`. Old PRD body content (which may describe mechanisms no longer canonical) is **NOT edited** in place; old PRDs are deprecated, not reconciled-as-product-law.

---

## 7. Full File Inventory (to be created under new paths)

### 7.1 `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`

New files (mirror of bridge legacy, identifier-replaced):

```
IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol       # mirror of v4/.../IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol          # mirror of v4/.../UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol         # mirror; QuoteService uses vanilla-only branch
UniswapV4FullSpreadHooklessStandardExchangeVaultPoolKeyAwareRepo.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultPoolManagerAwareRepo.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultInFacet.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultInQueryFacet.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionDelegate.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiFacet.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiQueryFacet.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiQueryTarget.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiTarget.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultOutFacet.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryFacet.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultOutTarget.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiFacet.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryFacet.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryTarget.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiTarget.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveFacet.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveTarget.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportFacet.sol
UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportTarget.sol
UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService.sol
test/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol  # test base mirroring bridge legacy TestBase
test/UniswapV4FullSpreadHooklessStandardExchangeVault_HooklessPath.t.sol  # family-specific tests
test/UniswapV4FullSpreadHooklessStandardExchangeVault_HookMismatchTest.t.sol  # hook!=0 reject
test/UniswapV4FullSpreadHooklessStandardExchangeVault_BlockedStates.t.sol  # blocked path tests
test/UniswapV4FullSpreadHooklessStandardExchangeVault_PreviewExecuteParity.t.sol
test/UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.t.sol   # §13 items 1–16 family-filtered
test/UniswapV4FullSpreadHooklessStandardExchangeVault_FamilySeparation.t.sol
```

### 7.2 `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/`

New files:

```
IUniswapV4FullSpreadPonsFamilyHookDFPkg.sol
UniswapV4FullSpreadPonsFamilyHookDFPkg.sol
UniswapV4FullSpreadPonsFamilyHookCommon.sol                        # includes Pons quoting
UniswapV4FullSpreadPonsFamilyHookPoolKeyAwareRepo.sol
UniswapV4FullSpreadPonsFamilyHookPoolManagerAwareRepo.sol
UniswapV4FullSpreadPonsFamilyHookPositionRepo.sol
UniswapV4FullSpreadPonsFamilyHookQuoteService.sol                  # contains _ponsHookFees
UniswapV4FullSpreadPonsFamilyHookInFacet.sol
UniswapV4FullSpreadPonsFamilyHookInQueryFacet.sol
UniswapV4FullSpreadPonsFamilyHookInExecutionDelegate.sol
UniswapV4FullSpreadPonsFamilyHookInTarget.sol
UniswapV4FullSpreadPonsFamilyHookInMultiFacet.sol
UniswapV4FullSpreadPonsFamilyHookInMultiQueryFacet.sol
UniswapV4FullSpreadPonsFamilyHookInMultiQueryTarget.sol
UniswapV4FullSpreadPonsFamilyHookInMultiTarget.sol
UniswapV4FullSpreadPonsFamilyHookOutFacet.sol
UniswapV4FullSpreadPonsFamilyHookOutQueryFacet.sol
UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate.sol
UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol
UniswapV4FullSpreadPonsFamilyHookOutTarget.sol
UniswapV4FullSpreadPonsFamilyHookOutMultiFacet.sol
UniswapV4FullSpreadPonsFamilyHookOutMultiQueryFacet.sol
UniswapV4FullSpreadPonsFamilyHookOutMultiQueryTarget.sol
UniswapV4FullSpreadPonsFamilyHookOutMultiTarget.sol
UniswapV4FullSpreadPonsFamilyHookLiquidReserveFacet.sol
UniswapV4FullSpreadPonsFamilyHookLiquidReserveTarget.sol
UniswapV4FullSpreadPonsFamilyHookPositionImportFacet.sol
UniswapV4FullSpreadPonsFamilyHookPositionImportTarget.sol
UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService.sol
test/...
```

### 7.3 Registry wiring

Both packages register under the existing `IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve` interface ID (preserved by §10 of PRD for off-chain discovery). Storage slot strings for `MultiAssetBasicVaultRepo` and `StandardVaultRepo` are per-family distinct (the family paths differ), preventing storage collisions.

### 7.4 Salt assignments

Each contract name hashes distinctly via `abi.encode(type(ContractName).name)._hash()`:
- `abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg")._hash()`
- `abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultInFacet")._hash()`
- ... etc.

Both families share `ArtifactCreationCode.creationCode("ERC20Facet.sol:ERC20Facet")` style for generic facets (ERC20, ERC5267, ERC2612, MultiAssetBasicVaultFacet, MultiAssetStandardVaultFacet, PositionImportFacet, LiquidReserveFacet), all landing at the **same CREATE3 addresses** across families.

Family-specific facets have **different type names** → distinct CREATE3 addresses.

---

## 8. Selection of helpers — which existing constants and functions

For each family, the engineering inventory uses:

| Helper | Source | Used by |
|---|---|---|
| `Math._sqrt` (full-precision via BetterMath) | `lib/crane/contracts/utils/math/BetterMath.sol` | CP-PRD share math |
| `Math._min`, `Math._mulDiv`, `Math._mul512ForUint512` | same | CP-PRD share math |
| `FullMath.mulDiv(...,Rounding.Ceil)` | `lib/crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol` | liquidity removal ceil-up |
| `SqrtPriceMath.getAmount0Delta`, `getAmount1Delta` | `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol` | deployed amount math |
| `TickMath.MIN_SQRT_PRICE+1`, `MAX_SQRT_PRICE-1` | same | swap price limits |
| `LiquidityMath.addDelta` | same | L additive changes |
| `StateLibrary.getSlot0`, `getLiquidity`, `getPositionInfo`, `getFeeGrowthInside` | same | on-chain reads |
| `IPoolManager.unlock(...)` / `.swap(...)` / `.modifyLiquidity(...)` / `.sync(...)` / `.settle(...)` / `.take(...)` | same | unlock operations |
| `UniswapV4Quoter.quoteExactInput`, `quoteExactOutput`, `quoteFromState` | `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol` | preview leg of swaps |
| `UniswapV4ZapQuoter.quoteZapInSingleCore`, `quoteZapOutSingleCore` | `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4ZapQuoter.sol` | preview leg of zap operations |
| `ConstProdUtils._depositQuote`, `_saleQuote`, `_purchaseQuote`, `_swapDepositSaleAmt`, `_quoteSwapDepositWithFee`, `_quoteZapInToTargetLPWithFee`, `_quoteZapOutToTargetWithFee`, `_quoteWithdrawWithFee`, `_calculateProtocolFee` etc. | `lib/crane/contracts/utils/math/ConstProdUtils.sol` | share accounting and quotes |
| `StandardExchangeConstantProduct._sharesForDeposit`, `_amountInForShares`, `_initialShares`, `_singleExit` | `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol` | vault share accounting |

**Selected closed-form summaries** (these are the helpers the PRD §6.4 closed-form check passes for):

- `_sharesForDeposit(amount0, amount1, supply, reserve0, reserve1) → floor(min(amount0*supply/reserve0, amount1*supply/reserve1))`. Closed-form (one-shot computation). Used by both families for proportional deposit.
- `_amountInForShares(reserveIn, reserveOther, sharesOut, supply)` → `floor((numerator/denominator) + 1)`. Closed-form inverse for single-sided deposit. Used by Hookless for the bridged unsegmented version's D64 exact-out mint. Same math applies to both families.
- `_initialShares(amount0, amount1, MIN_LIQ) → floor(sqrt(amount0*amount1)) - MIN_LIQ`. Closed-form first-mint.
- `_singleExit(reserveOut, reserveOther, shares, supply) → output = entitlementOut + (entitlementOther * (reserveOut - entitlementOut)) / (reserveOther + entitlementOther)`. Closed-form proportional exit.
- `UniswapV4Quoter.quoteExactInput/quoteExactOutput` — iterative bounded by tick count; each tick is `SqrtPriceMath.computeSwapStep` (one-shot). Classified as **deterministic-step bounded-iteration closed-form** per PRD §6.4 #2.

**Explicitly NOT in the closed-form set** (search):

- `_sharesForSingleExit` (ConstProdUtils:113–129): **bisection** — does not meet PRD §6.4 line 214 "a helper that performs numerical search does not establish a closed form."
- `UniswapV4ZapQuoter.quoteZapInSingleCore` (preview only): binary search at QuoteService:62 (`DEFAULT_ZAP_SEARCH_ITERS = 20`). NOT a closed-form quote for execution; preview uses it but execution walks through `_executeZapInDeposit` (InBase:269) which on-chain interacts with `manager.swap` then `modifyLiquidity`. **Preview == execute is achieved because both branches reference the same `UniswapV4ZapQuoter.quoteZapInSingleCore` with identical parameters at preview time and a smaller parameter set at execute time** (execute uses the on-chain state and quote from the same library). The on-chain execute does NOT perform the search — it executes the *result* of the search. So in execution parity testing, **preview and execute compute the same `swapAmountIn` and `addLiquidity` parameters at preview time**; the execute side then uses the live `slot0` for settlement.

---

## 9. Hook-fee + own-LP-fee attribution

Per PRD §1 ("fees counted once"), §4 (blocked path rules), §6.3 (share issuance backs both deployed and sleeve), §12 (full local booking):

| Fee type | Source | Booked to |
|---|---|---|
| Vault's own LP-fee share | `getFeeGrowthInside(pool, range)` accrued between mints/burns; computed by `_collectablePositionFees` (Common:637); `_collectManagedFeesIfIdle` (Common:652) mints them into free via `modifyLiquidity`/`TAKE_PAIR` | Accrues into `E` (per PRD §5); becomes `F` after collection; booked into `MultiAssetBasicVaultRepo._reserveOfToken` via `_syncVaultReserves` (Common:610–617). Counted once. |
| Protocol LP-fee share | set on `PoolManager` per direction by `protocolFeeController` (up to `MAX_PROTOCOL_FEE = 1000` pips = 0.1% per direction per `ProtocolFeeLibrary.sol:9`); NOT taken by the vault | Outside the vault book. |
| Pons V2 hook fee + creator tax | per-tx; `floor(unspecifiedAmount * (hookFeeBps + creatorTaxBps) / 10_000)` from PonsV2MemeHook.sol:495–504 | Taken by the hook from the pool; not booked in the vault (the hook owns it; the vault's `_collectablePositionFees` does not see hook fees). |
| Vault's own `rebalanceLiquidReserve` swap fees | When the public rebalance swaps via `manager.swap` (Common:973), the swap carries the same LP fee + protocol fee combination | Captured by `_collectablePositionFees` after the next position change. The 1 bp alignment metric ensures the swap's price-impact is bounded. |

`localReserve` interface reports `free` + `deployed` separately; `totalReserve` (share pricing) uses `free + fee + deployed` (Common:623–628). **Each token's free is updated once per workflow** at `_syncVaultReserves` (Common:610), satisfying `INV-R1` of the pretransfer PRD §4.4.

---

## 10. Migration of existing instances — not authorized

PRD §3 final paragraph: "Source removal does not deactivate, upgrade or migrate existing on-chain instances and does not authorize live registry actions or deployment." Existing vaults deployed via:
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchange*DFPkg.sol` (older legacy)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` (bridge legacy)

continue to function as-is. **The plan does not migrate or upgrade them.** New deployments use the family paths (§7.1, §7.2). Existing live instances persist until natural withdrawal / redemption by their owners.

---

## 11. Open items surfaced by this planning pass

These are engineering-spec items, not policy questions:

1. Storage layout strings for `MultiAssetBasicVaultRepo` and `StandardVaultRepo` must be re-declared per-family. Both families' repos live under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/{hookless,ponsFamilyV2Hook}/`; Crane convention uses `STORAGE_SLOT = keccak256(...)` per repo file. The repo STORAGE_SLOTs should differ per family by including the path in the seed (e.g., `keccak256("indexedex.vault.standard.exchange.fullSpread.hookless")`).
2. `IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve` interface ID: preserved as the discovery interface; both families implement it. No new interface needed.
3. `vaultFeeTypeIds` slot (DFPkg line 132–136 of bridge legacy): both families' DFPkgs must insert `VaultFeeType.USAGE` keyed by `IUniswapV4FullSpread{HooklessStandardExchange,PonsFamilyHook…}LiquidReserve.interfaceId`. The selector-replacement is mechanical.
4. `INIT_FORK_BLOCK = 20_714_383` (per `ROBINHOOD_MAIN.sol:53`): test-bases pin fork to this block for production evidence. The plan does not require evidence beyond the constant + docs + graduated-pool usage (per user item-4).
5. A `forge build` followed by `forge test` is required before each family is declared implementation-ready. Not the LP-equivalence check (removed per user item-4) — just ordinary compile-and-test.

---

## 12. Verification approach — preview==execute with byte-equal accounting check

For each tested route, the verification contract asserts:

```
preview_amount == execute_amount                  // for exact-in: sharesOut
preview_amountOut == execute_amountOut          // for exact-output idle
preview_balance_diff == post_call_balance_diff // for direct swaps
post_call_balance_diff == recorded_in_balanceOf  // actual ERC20 moved equals preview
post_call_reserve = balanceOf_at_end - pre_call_balanceOf_at_start + pre_call_reserve  // durable local snapshot updated
MultiAssetBasicVaultRepo._reserveOfToken(token) == balanceOf(token)         // L-RSRV-SYNC-FULL
```

The parity test scaffolding re-uses the bridge legacy's `TestBase_UniswapV4FullSpreadStandardExchangeVault` and extends it with family-specific TestBases (`TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault`, `TestBase_UniswapV4FullSpreadPonsFamilyHook`).

---

## 13. Confidence levels

**HIGH (verified by direct file read):**
- Existing accounting chain (`_syncVaultReserves`, `_totalVaultReserves`, `_collectablePositionFees`, `_collectManagedFeesIfIdle`).
- `_initialShares`, `_sharesForDeposit`, `_amountInForShares`, `_singleExit` formulas as closed-form.
- `UniswapV4Quoter.quoteExactInput/Output` exists and reads live `lpFee`/`protocolFee` from `getSlot0`.
- Pons V2's `LaunchInfo` is snapshotted at registration; mutable hooks are limited to recipient/buyback toggling.
- `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044`; `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951`.
- Two family paths empty on disk.
- Bridge legacy path file counts (36 files; PRD §3.1 scope).

**MEDIUM:**
- Whether `_amountInForZapMint` family helper needs the `prepaidCredit` argument or can default to `0` for new family trees (the contract-shape change is small; the formula in `_amountInForShares` (ConstantProduct:78–96) doesn't take prepaid credit).
- Whether `forge build` artifacts both families under 24,576 runtime bytes per `README.md:65`.

**LOW (engineering-runtime unknowns; not policy):**
- Exact storage slot strings for the two new family paths.
- Final SPEC compliance of each acceptance item (§13.1–28) once implementations land.

---

## 14. Saved path

`docs/research/uniswap-v4-plan-specification-2026-09-27/MINIMAX_ORIGINAL.md` (this file).

No code, shell, test, config, deletion, or delegation performed. No peer artifacts read this round. No live external API claims beyond what is already verified by file reads in this repo.
