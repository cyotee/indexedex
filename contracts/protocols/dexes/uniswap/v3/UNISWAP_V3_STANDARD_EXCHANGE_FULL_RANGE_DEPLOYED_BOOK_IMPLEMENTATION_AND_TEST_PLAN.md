# Implementation & Test Plan: Uniswap V3 SE — Sleeve + Full-Range Book + Multi Join/Exit

**Status:** Ready for coding (product law frozen v1.2)  
**Date:** 2026-08-24  
**Product law (normative):** [`UNISWAP_V3_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md`](./UNISWAP_V3_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md) (**v1.2**, D1–D61)  
**Bring-up (historical):** [`UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PLAN.md`](./UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PLAN.md)  
**Family gold (behavior, not copy-paste unlock):** V4 sleeve + full-range + Multi plans under `../uniswap/v4/`  
**Package path:** `contracts/protocols/dexes/uniswap/v3/`

This document is the **coding plan**. Do not re-open locked PRD decisions. When this plan and the PRD conflict, **the PRD wins**. This plan may order work; it may not choose among §6 rejected alternatives.

V3 has **no** prior sleeve PRD. This epic is sleeve + full-range center + Multi in one delivery.

---

## 0. Mission (one sentence)

Give this vault a **20% fee-oracle sleeve** so nested same-pool `LOK` can complete, put deployed inventory in **one full-range** vault-owned Uniswap V3 position, and add **exact-in dual join** / **exact-out dual proportional exit**, without token0↔token1 rebalance swaps.

---

## 1. Authority & constraints

| Layer | Role |
|-------|------|
| PRD v1.2 D1–D61 | Product law |
| **This plan** | Phases, files, algorithms, test matrix, DoD |
| `crane-testing` / `indexedex-testing` | Production-first: CREATE3 + `indexedexManager.deployUniswapV3StandardExchangeDFPkg` + `pkg.deployVault`. No mock SUT |
| `crane-deployment` | Never `new` facets/DFPkgs. `PkgInit` / `PkgArgs` on the **interface** |
| Foundry | Hermetic = default `forge test`. Fork = `FOUNDRY_PROFILE=fork`. **No third profile. `via_ir` forbidden.** Forge patience: first compile 20–40+ minutes; do not kill. Seed `cache_forge/` + `out/` in a new worktree before the first compile |

### Hard rules

1. Never `new` facets, DFPkgs, or execution delegates. CREATE3 via `UniswapV3_Component_FactoryService`.
2. Never mock vault / manager / registry / fee oracle / bound pool as SUT.
3. Gate is bound-pool `slot0.unlocked` (**true = idle**). Opposite of V4 `isUnlocked`.
4. Do not `pool.mint` / `burn` / `swap` / `collect` when `canOpenBoundPoolOps() == false`.
5. Existing `IStandardExchangeIn` / `Out` / import selectors stay. Multi is new cuts. Out preview moves to OutQueryFacet.
6. Multi arrays: **exactly two pool currencies**, strictly ascending addresses, amounts > 0.
7. Dual **exit** `S0 == S1` or revert; no tokens sent. Dual **join** unbalanced OK; user pays both `amountsIn`.
8. Sleeve-then-deploy-excess (D27). Idle amount-out always uses the pool (D3). Preview ignores rebalance (D24).
9. `widthMultiplier` stays on `deployVault` (`>= 1`) and does **not** size ticks.
10. Delete wing storage (D55). Delete `_feeFirstCompound` / `_feeFirstCompoundReservingPrincipal` (D57).
11. Crane V3 `TickMath.minUsableTick` / `maxUsableTick` (D54). Do not import V4 TickMath. Delete `_snapTick`.
12. CREATE3 In/Out execution delegates (D56). **No** Multi execution delegates. Stack-too-deep on Multi = Target-local structs (V4 `DualExitLocal`).
13. A0 dead shares to `0x…dEaD` (D53).
14. Do not implement `IStandardExchangeMultiAssetLiquidity`. Do not implement Slipstream Multi.
15. Do not invent a Stage. Do not edit `anvil_robinhood_main` unless it constructs this `PkgInit` (it does not).

---

## 2. Current state (baseline)

| Area | Today | Required after this work |
|------|-------|--------------------------|
| Tick derive | `_snapTick` around current tick; center + wings from `widthMultiplier` / `centerWidthMultiplier` | Crane V3 `minUsableTick` / `maxUsableTick`; **no** `_snapTick` |
| Storage | `center` + `lowerWing` + `upperWing`; `StrategyConfig` has width, centerWidth, `activeLiquidityBps = 1000` | One `centerPosition`; `StrategyConfig { widthMultiplier }` only |
| Share SoT | `_totalVaultReserves` = position amounts + `tokensOwed`; free only in `_totalVaultValue` | `free balanceOf + deployed` (D9). Collect before mint/burn totals when idle. Do not add `tokensOwed` on top of `balanceOf` after collect |
| Compound | `_feeFirstCompound` deploys **all** free into L | Deleted. Collect + D27 |
| Sleeve | None | 20% type default on `IUniswapV3StandardExchangeLiquidReserve` |
| Gate | None | `canOpenBoundPoolOps()` |
| Out facet | Preview + mutate on one facet (2 selectors) | OutFacet mutate only; OutQueryFacet preview; `OutExecuteTarget` + CREATE3 `OutExecutionDelegate` |
| In facet | Mutate + mint/swap callbacks; no constructor | Constructor-injected CREATE3 `InExecutionDelegate`; **keep** mint/swap callbacks on InFacet only |
| Multi | Interfaces exist (`IStandardExchangeOutMulti.sol` already renamed) | Four facets cut; ERC165 |
| USAGE fee type | `IStandardVault.interfaceId` | `IUniswapV3StandardExchangeLiquidReserve.interfaceId` |
| Crane V3 TickMath | No usable-tick helpers | Additive `minUsableTick` / `maxUsableTick` |
| Tests | Routes / Import / FeeCompound / Previews / DFPkg / 3 IFacet / adversarial / Base fork smoke | Those retargeted + T1–T16 analog + FR + MJ/ME + A0 + new IFacet + 4663 fork |
| PkgInit writers | 9 SE-related fields (In, InQuery, Out, Import) | + liquid-reserve, OutQuery, four Multi (D61) |
| Diamond cuts | **9** | **15** |

Treat in-tree v1 as **draft relative to this law**. Phase 2–3 rewrite Common/Repo/In/Out; do not leave fee-first or wing plan paths.

---

## 3. Target architecture

```text
IStandardExchangeIn / Out          IStandardExchangeInMulti / OutMulti
  one pool token ↔ shares            exactly two pool tokens ↔ shares
  zap-out MAY swap other token       NO swap
  length-1 only                      length === 2, sorted addresses
                                     join: unbalanced OK
                                     exit: S0 == S1 or revert
                │                              │
                └──────────┬───────────────────┘
                           ▼
         canOpenBoundPoolOps() := pool.slot0().unlocked
                    ┌──────┴──────┐
                    │ idle        │ blocked (LOK if mint/swap)
                    ▼             ▼
         sleeve mint then         sleeve mint; no pool op
         tail-rebalance           amount-out: free cover or revert
         amount-out: ALWAYS pool  public rebalance: revert
         then tail-rebalance      import needing mint: revert
         public rebalance OK
                           │
              idle rebalance add/remove L
              on FULL-RANGE (or imported) center only
              no token0↔token1 swap
```

### 3.1 Module split

| Module | Responsibility |
|--------|----------------|
| Crane `TickMath` (V3) | `minUsableTick` / `maxUsableTick` (D54) |
| `UniswapV3VaultRepo` | One center; `widthMultiplier` only; import metadata; last tick/price/timestamp |
| `UniswapV3StandardExchangeCommon` | Gate; D9 totals; deadband; rebalance; D52; dual-token validate; mint/burn/collect **center only**; A0 sink constant |
| `InBase` (new, peer of V4) + `InTarget` + CREATE3 `InExecutionDelegate` | Zap-in sleeve mint; branch idle/blocked; tail-rebalance when idle |
| `InQueryTarget` / `InQueryFacet` | Preview In; no pool mutate |
| `OutExecuteTarget` (new) + `OutTarget` leftovers + CREATE3 `OutExecutionDelegate` | Zap-out; constructor-injected delegate |
| `OutQueryTarget` / `OutQueryFacet` | `previewExchangeOut` only |
| `OutFacet` | `exchangeOut` only |
| Liquid-reserve Target + Facet | D59 views + `rebalanceLiquidReserve` |
| InMulti / OutMulti Targets + Query + Facets | Dual join/exit. **No** extra CREATE3 delegates |
| DFPkg / FactoryService / TestBase / D61 writers | 15 cuts; type default 20% |

`uniswapV3MintCallback` / `uniswapV3SwapCallback` stay on **InFacet only**. Do not cut them on Multi or Out.

---

## 4. Concrete APIs

### 4.1 Gate (D1 / D58)

```text
canOpenBoundPoolOps() := pool.slot0().unlocked     // true = idle

Every pool.mint / burn / swap / collect:
  if !canOpenBoundPoolOps(): revert UniswapV3Exchange_BoundPoolInteractionBlocked()

public rebalanceLiquidReserve():
  if !canOpenBoundPoolOps(): revert same
  if both tokens in deadband: return (no pool op)
  else: _rebalanceLiquidReserveInternal()
```

Do not name this `canOpenPoolManagerUnlock`. NatSpec must say bound-pool `slot0.unlocked`, not V4 `isUnlocked`.

### 4.2 Dual-pool validate (D41 / D42)

```text
_requireDualPoolCurrencies(address[] tokens):
  require length == 2
  require tokens[0] < tokens[1]
  require tokens[0] == pool.token0() && tokens[1] == pool.token1()
```

Amounts each `> 0`. Join `tokenOut == address(this)`. Exit `tokenIn == address(this)`. Else `ExchangeInNotAvailable` / `ExchangeOutNotAvailable`. Descending `[token1, token0]` reverts (MJ8).

### 4.3 D52 share burns

Rounding-up muldiv (Uniswap `FullMath.mulDivRoundingUp` or Crane equivalent). **Not** overflowing `amount * supply`.

```text
if (total0 == 0 || total1 == 0 || supply == 0) revert
S0 = mulDivRoundingUp(amount0, supply, total0)
S1 = mulDivRoundingUp(amount1, supply, total1)
if (S0 != S1) revert ExchangeOutNotAvailable
if (S0 > maxAmountIn) revert existing Out insufficient-input / TooMuchInput
S = S0
```

Preview uses the same `S` and does **not** simulate tail-rebalance (D24). Blocked preview requires D52 and `free_i >= amountsOut[i]` else `UniswapV3Exchange_InsufficientLocalReserve`.

### 4.4 Join (`exchangeInManyToOne`)

```text
1. deadline / not-disabled / dual-pool validate
2. amount0 = amountsIn[0]; amount1 = amountsIn[1]
3. Pull both via _secureTokenTransfer (D49). One ABI bool for both.
   pretransferred=true without delivery of BOTH: revert / zero mint (I1). Do not mint from inventory.
4. Collect fees if idle (D9). Blocked: skip collect.
5. sharesOut = _sharesOutForDeposit(amount0, amount1, supply, reserve0Before, reserve1Before)
   empty supply user shares = amount0+amount1
   if supply==0 and residual = reserve0Before+reserve1Before > 0:
       mint residual to DEAD_SHARES_SINK (D53)  // extra, not added to user shares
6. minAmountOut (min shares)
7. mint to recipient; sync
8. if canOpenBoundPoolOps(): _rebalanceLiquidReserveBestEffort()   // D11: must not revert mint
   else: emit LocalDepositWhileBlocked per token (or once each)
9. return sharesOut
```

Preview: steps 1–5 as view (reserves pre-deposit; no pull).

### 4.5 Exit (`exchangeOutOneToMany`)

```text
1. deadline / not-disabled / dual-pool validate / tokenIn == this
2. if idle: collect then totals; if blocked: totals without collect
3. S = D52(amount0, amount1); require S <= maxAmountIn
4. Pull shares: _secureShareDelivery(maxAmountIn, pretransferred)
5. Blocked:
     require free0 >= amount0 && free1 >= amount1 else InsufficientLocalReserve
     burn S; send exact amount0 and amount1; refund maxAmountIn - S to msg.sender
     sync; return S
6. Idle (D3, even if sleeve covers):
     burn center L fraction floor(S * centerL / supply) (imported: same center ticks)
     require balanceOf each token >= amountsOut after burn+collect
     transfer exact amountsOut; burn S; refund leftover shares
     sync; _rebalanceLiquidReserveBestEffort(); return S
```

If idle remove cannot pay exact `amountsOut`: revert slippage / insufficient output. Measure balances; do not assume. **No** swap of the other token on Multi.

### 4.6 Errors

| Error | When |
|-------|------|
| `IStandardExchangeIn.ExchangeInNotAvailable()` | Bad join arrays / `tokenOut != shares` |
| `IStandardExchangeOut.ExchangeOutNotAvailable()` | Bad exit arrays / `tokenIn != shares` / unbalanced exit (`S0 != S1`) |
| `UniswapV3Exchange_InsufficientLocalReserve(token, requested, available)` | Blocked amount-out / dual exit short |
| `UniswapV3Exchange_BoundPoolInteractionBlocked()` | Public rebalance or idle-only path while pool locked. **Not** for Multi join (join works blocked) |
| Existing deadline / slippage / zero / disabled / callback auth | Unchanged |

Do not invent a second unbalanced-exit error.

### 4.7 Facet selectors

| Facet | `facetInterfaces` | `facetFuncs` |
|-------|-------------------|--------------|
| `UniswapV3StandardExchangeInFacet` | `IStandardExchangeIn`, `IUniswapV3MintCallback`, `IUniswapV3SwapCallback` | `exchangeIn`, `uniswapV3MintCallback`, `uniswapV3SwapCallback` |
| `UniswapV3StandardExchangeInQueryFacet` | `IStandardExchangeIn` | `previewExchangeIn` |
| `UniswapV3StandardExchangeOutFacet` | `IStandardExchangeOut` | `exchangeOut` |
| `UniswapV3StandardExchangeOutQueryFacet` | `IStandardExchangeOut` | `previewExchangeOut` |
| `UniswapV3StandardExchangeLiquidReserveFacet` | `IUniswapV3StandardExchangeLiquidReserve` | D59 methods |
| `UniswapV3StandardExchangeInMultiFacet` | `IStandardExchangeInMulti` | `exchangeInManyToOne` |
| `UniswapV3StandardExchangeInMultiQueryFacet` | `IStandardExchangeInMulti` | `previewExchangeInManyToOne` |
| `UniswapV3StandardExchangeOutMultiFacet` | `IStandardExchangeOutMulti` | `exchangeOutOneToMany` |
| `UniswapV3StandardExchangeOutMultiQueryFacet` | `IStandardExchangeOutMulti` | `previewExchangeOutOneToMany` |
| Import facet | Unchanged | Unchanged |

`nonReentrant` on mutate. Query facets view-only; no pool mutate.

Existing Out IFacet test today expects **2** funcs. After split: OutFacet **1** (`exchangeOut`); OutQueryFacet **1** (`previewExchangeOut`).

---

## 5. Full-range book (D30–D35, D54–D55)

### 5.1 Crane V3 TickMath (D54)

File: `lib/crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol`

Add (same bodies as V4 TickMath; do **not** change `getSqrtRatioAtTick` / `getTickAtSqrtRatio`):

```solidity
function maxUsableTick(int24 tickSpacing) internal pure returns (int24) {
    unchecked { return (MAX_TICK / tickSpacing) * tickSpacing; }
}
function minUsableTick(int24 tickSpacing) internal pure returns (int24) {
    unchecked { return (MIN_TICK / tickSpacing) * tickSpacing; }
}
```

`unchecked` is valid under this repo’s solc 0.8.35 (`pragma >=0.5.0` allows it). Do not bump the pragma unless compile requires it.

Crane tests: `lib/crane/test/foundry/spec/protocols/dexes/uniswap/v3/libraries/TickMath.t.sol` — spacings **1, 10, 60, 200**: divisible by spacing, `>= MIN_TICK`, `<= MAX_TICK`, `min - spacing < MIN_TICK`, `max + spacing > MAX_TICK`. Copy the V4 `test_usableTicks` assertions.

### 5.2 Derive / create

```solidity
int24 spacing = pool.tickSpacing();
centerLower = TickMath.minUsableTick(spacing);
centerUpper = TickMath.maxUsableTick(spacing);
```

No `widthMultiplier` in tick math. Delete `_snapTick`. Import stores NFT ticks as-is (D34).

`_createOrganicPositionsIfNeeded`: create **center only**. Delete wing `_createPositionIfNeeded` calls.

`ManagedTicks`: `centerLower` / `centerUpper` only. Delete wing fields from the struct.

`_managedLiquidityPlanAtState`: `_setCenterPlan` only. **Delete** `_setLowerWingPlan` / `_setUpperWingPlan`.

`_mintManagedLiquidity`: center only.

`_totalVaultReserves` after D9: do **not** sum wings; do **not** add `tokensOwed` once collect has moved them to `balanceOf`. Deployed = LiquidityAmounts for **center** at current sqrt price. Free = `balanceOf`. Idle mint/burn path: `_collectManagedFees` first, then totals.

### 5.3 Repo (D55)

`UniswapV3VaultRepo.Storage`:

- Keep: `centerPosition`, `StrategyConfig { uint24 widthMultiplier }`, `lastSqrtPriceX96`, `lastTick`, `lastTimestamp`, import fields.
- **Delete:** `lowerWingPosition`, `upperWingPosition`, `PositionKind` enum, `centerWidthMultiplier`, `activeLiquidityBps`.
- `_initialize`: `require(widthMultiplier_ >= 1)`; store only that field.
- `_isPositionCreated()` := `centerPosition.created`.
- `_getOwnPositionKey`: center ticks only (no kind argument, or center-only helper).
- `_initializeImportedCenter`: set center ticks from NFT; do not mention wings.

Layout change is allowed (D36). No live-book migration.

### 5.4 Rebalance vs ticks (D35)

Idle rebalance add/remove on stored center ticks only. Never rewrite ticks.

---

## 6. Sleeve algorithms (D1–D29, D53, D57)

Copy V4 buffer math. Replace every PoolManager `unlock` with bound-pool `mint` / `burn` / `collect` / `swap` behind `canOpenBoundPoolOps`.

### 6.1 Deadband (D22)

```text
RELATIVE_TOL_WAD = 0.05e18
ABSOLUTE_FLOOR_i = 10^max(0, decimals_i - 6)   // 1 wei if decimals <= 6

targetFree_i = total_i * liquidPct / 1e18
rebalance token i iff:
  if targetFree_i == 0: free_i > ABSOLUTE_FLOOR_i
  else: |free_i - targetFree_i| > max(ABSOLUTE_FLOOR_i, targetFree_i * RELATIVE_TOL_WAD / 1e18)

When tripped: move TO target, not to band edge.
If both in band: public rebalance returns without pool ops.
```

Live oracle every time (D20): `liquidReservePercentageOfVault(address(this))`. No vault cache of the pct.

### 6.2 Rebalance (D10 / D11 / D28)

Same shape as V4 `_rebalanceLiquidReserveInternal`:

1. Deploy excess (`free > target`) as center L via existing `_mintLiquidity` / plan with **excess** budgets (not all free).
2. Reload snap. Refill deficit by `pool.burn` + `collect` on center so the short token’s free rises toward target. Remove yields **both** tokens; overshoot on the other token is OK; optional second deploy pass in the same call if still idle.
3. **No** token0↔token1 swap.
4. Tail-rebalance (`_rebalanceLiquidReserveBestEffort`): if blocked, **return** (do not revert the user op) (D11). Public `rebalanceLiquidReserve` **reverts** when blocked.

### 6.3 Zap-in (replace `_executeZapInDeposit`)

Delete `_feeFirstCompound` call sites (D57).

```text
1. Secure pull
2. If idle: collect
3. totals after pull; back out deposit for reserveBefore
4. A0 if supply==0 and residual > 0: mint residual to DEAD_SHARES_SINK
5. mint user shares vs totals (empty: shares = amountIn for single-token)
6. if idle: tail-rebalance (D27 deploy excess only)
   else: LocalDepositWhileBlocked
```

Single-token first mint: L **may be 0** (D33 / FR5). Do not swap the other token to mint L. Do not recreate wings.

### 6.4 Zap-out / amount-out

- **Blocked:** pay from `balanceOf(tokenOut)` if `>= minAmountOut` (requested amount); else `InsufficientLocalReserve`. No swap. No burn L.
- **Idle:** always `burn`/`collect` and/or `swap` as today, even if sleeve covers (D3), then tail-rebalance.

Direct pool swap (token0↔token1 on In): idle only; blocked reverts `BoundPoolInteractionBlocked`; then tail-rebalance.

### 6.5 Import (D15 / D34)

Idle: NPM `decreaseLiquidity` + `collect` + vault `mint` at **NFT ticks** as center. Then D27 sleeve-then-deploy-excess on **that** range.

Blocked: **hard-revert** `BoundPoolInteractionBlocked`. No partial free-only import.

A0 applies on import-at-empty-supply (D53).

### 6.6 USAGE type id (D7)

`UniswapV3StandardExchangeDFPkg.vaultFeeTypeIds`: USAGE key = `type(IUniswapV3StandardExchangeLiquidReserve).interfaceId`. **Not** `IStandardVault.interfaceId`.

TestBase `setUp` (owner prank, before deployPkg):

```solidity
IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
    type(IUniswapV3StandardExchangeLiquidReserve).interfaceId,
    0.20e18
);
```

Fork tests that deploy the pkg must set the same type default.

---

## 7. File impact map

### 7.1 Production (IndexedEx)

| File | Work |
|------|------|
| **New** `interfaces/IUniswapV3StandardExchangeLiquidReserve.sol` | D59 |
| `UniswapV3VaultRepo.sol` | D55 |
| `UniswapV3StandardExchangeCommon.sol` | Gate, D9, deadband, rebalance, D52, dual validate, center-only mint/burn/collect, A0 constant, delete `_snapTick` / wing plans / `_feeFirstCompound` |
| **New** `UniswapV3StandardExchangeInBase.sol` | Sleeve zap-in / A0 (peer of V4 InBase) |
| `UniswapV3StandardExchangeInTarget.sol` | Call delegate / InBase; delete fee-first; constructor `executionDelegate` |
| `UniswapV3StandardExchangeInFacet.sol` | Constructor-injected delegate; keep callbacks |
| `UniswapV3StandardExchangeInQueryTarget.sol` | Preview under gate (D24) |
| **New** `UniswapV3StandardExchangeInExecutionDelegate.sol` | CREATE3; zap-in / zap-out-from-in if V4 does |
| **New** `UniswapV3StandardExchangeOutExecuteTarget.sol` | Mutate out; constructor delegate |
| **New** `UniswapV3StandardExchangeOutQueryTarget.sol` | Preview out |
| **New** `UniswapV3StandardExchangeOutQueryFacet.sol` | `previewExchangeOut` |
| **New** `UniswapV3StandardExchangeOutExecutionDelegate.sol` | CREATE3 |
| `UniswapV3StandardExchangeOutFacet.sol` | `exchangeOut` only; inherit OutExecuteTarget; constructor |
| `UniswapV3StandardExchangeOutTarget.sol` | Split: preview leaves; keep shared helpers or fold into Execute/Query |
| **New** LiquidReserve Target + Facet | D59 |
| **New** four Multi Targets + four Multi Facets | D48. OutMulti: `DualExitLocal` + quote/pay helpers if stack-too-deep (copy V4 OutMultiTarget). **No** Multi CREATE3 delegate |
| `UniswapV3StandardExchangePositionImportTarget.sol` | Gate; A0; no `_snapTick`; blocked revert |
| `UniswapV3StandardExchangeDFPkg.sol` | `PkgInit` +6 facets; cuts **9→15**; `facetInterfaces` + liquid-reserve + InMulti + OutMulti (Out already listed); `vaultFeeTypeIds` D7 |
| `UniswapV3_Component_FactoryService.sol` | CREATE3 deploy* for every new facet + both delegates (V4 `bytes.concat(creationCode, abi.encode(delegate))` for In/Out mutate facets); `attachUniswapV3StandardExchangeMultiFacets` |
| D61 PkgInit writers | Sequential field writes + attach helper (TestBase already sequential to avoid 13-arg stack) |

`IStandardExchangeOutMulti.sol` is already renamed. Do not resurrect the typo filename.

### 7.2 Crane

| File | Work |
|------|------|
| `lib/crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol` | D54 helpers |
| `lib/crane/test/foundry/spec/protocols/dexes/uniswap/v3/libraries/TickMath.t.sol` | `test_usableTicks` for 1/10/60/200 |

Additive only. Faithful port otherwise.

### 7.3 Tests

| Path | Work |
|------|------|
| `contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol` | Deploy all new facets + delegates via FactoryService; type default 20%; sequential `PkgInit` + attach Multi |
| **New** `test/foundry/spec/protocol/dexes/uniswap/v3/harness/UniswapV3BoundPoolLockSeCaller.sol` | Starts a **bound-pool swap**; in `uniswapV3SwapCallback` calls this vault (In, Out, Multi, rebalance). Pays swap deltas. Mint/approve tokens **on the harness** (msg.sender = harness), or `pretransferred` + transfer to vault |
| **New** `UniswapV3StandardExchange_LocalLiquidBuffer.t.sol` | T1–T16 analog |
| **New** `UniswapV3StandardExchange_FullRangeBook.t.sol` | FR1–FR6 |
| **New** `UniswapV3StandardExchange_MultiJoinExit.t.sol` | MJ1–MJ8, ME1–ME7, A0 |
| Existing Routes / Import / Previews / FeeCompound | Drop center+wings; FeeCompound becomes collect + D27 (not 100% deploy) |
| `UniswapV3StandardExchangeDFPkg_Deploy.t.sol` | 15 cuts; new interface ids; `widthMultiplier` still stored |
| IFacet | Update Out (1 func). **New:** OutQuery, LiquidReserve, InMulti, InMultiQuery, OutMulti, OutMultiQuery. Add missing **InQuery** IFacet while here. `TestBase_IFacet` + CREATE3 |
| `adversarial/*` | Stay green. Extend SecRemediation / SecurePull: Multi I1 (MJ5) + J1–J3 loupe on new facets |
| `test/foundry/fork/base_main/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Fork.t.sol` | Type default 20%; new `PkgInit` fields; at least FR1 or MJ2, one blocked sleeve path, A0 |
| **New** `test/foundry/fork/robinhood_4663/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Robinhood.t.sol` | D60 pins |

### 7.4 Launch / PkgInit (D61)

| File | Work |
|------|------|
| `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol` | Deploy new facets; sequential `PkgInit`; attach Multi |
| `scripts/foundry/anvil_robinhood_fee_detf/Script_05_DeployUniV3SeOnRichPool.s.sol` | Same (compile break if skipped) |

Do **not** invent a Stage. Do **not** add a 4663 launch tree. `anvil_robinhood_main` untouched.

### 7.5 Docs

| File | Work |
|------|------|
| This plan | Checklist |
| Full-range PRD | Related row points here |
| V3 v1 vault PRD / vault plan | Tick/rebalance/compound rows already yield to the PRD; plan tick section: full-range center, no wing storage |
| Uni V4 D51 | This package is the V3 copy |
| Crane V3 TickMath NatSpec | New helpers |

---

## 8. CREATE3 delegates (D56) — copy V4 wiring

```text
FactoryService.deployUniswapV3StandardExchangeInFacet:
  delegate = create3.create3(InExecutionDelegate.creationCode, nameHash)
  facet = create3.deployFacet(bytes.concat(InFacet.creationCode, abi.encode(delegate)), nameHash)

Same for OutFacet + OutExecutionDelegate.

Never `new` either contract.
Multi: no delegate. If stack-too-deep: DualExitLocal struct + quote/pay helpers on the Target (V4 OutMultiTarget).
Never via_ir.
```

InExecutionDelegate / OutExecutionDelegate expose the same execute entrypoints as V4 (`executeZapInDeposit`, zap-out execute, etc.). Targets `this.delegate.function(...)` or inherit+forward exactly as V4 InTarget / OutExecuteTarget.

---

## 9. Blocked harness (D19)

**New** `UniswapV3BoundPoolLockSeCaller`:

1. Holds token balances and approvals.
2. Calls `boundPool.swap` with a small exact-in so the pool takes the `lock`.
3. In `uniswapV3SwapCallback`, while `slot0.unlocked == false`, calls the diamond (`exchangeIn`, `exchangeOut`, Multi, `rebalanceLiquidReserve`).
4. Pays `amount0Delta` / `amount1Delta` to the pool so the outer swap completes.

Do not invent a PoolManager. Do not use mint-callback as the DoD harness (PRD locks swap callback).

Tests that call through the harness must mint/approve **the harness**, not `address(this)`, unless using `pretransferred` with tokens already on the vault.

---

## 10. Phased delivery

Each phase ends **compile + listed tests green**. Do not start the next phase red unless blocked by a PRD gap (there are none).

### Phase 0 — Spec freeze

- [x] PRD v1.2 D1–D61 locked  
- [x] This implementation plan authored  

**Exit:** product + plan authority clear.

---

### Phase 1 — Crane V3 TickMath (D54)

**Goal:** Usable min/max ticks exist on Crane V3 TickMath with unit tests.

**Tasks:**

1. Add `minUsableTick` / `maxUsableTick` to Crane V3 `TickMath.sol`.
2. Add `test_usableTicks` to Crane V3 `TickMath.t.sol` (spacings 1, 10, 60, 200).
3. Run that Crane file. IndexedEx SE need not compile against it until Phase 2.

**Exit:** Crane tests green. `getSqrtRatioAtTick` unchanged.

**Risk:** `unchecked` vs `pragma >=0.5.0`. Compile with repo solc 0.8.35.

---

### Phase 2 — Book geometry (D30–D31, D55)

**Goal:** New organic books are one full-range center; wing storage gone.

**Tasks:**

1. Rewrite `UniswapV3VaultRepo` (D55).
2. Rewrite `_deriveManagedTicks` / plan / mint / create / `_managedTicks` / `_totalVaultReserves` position sum (still position-only until Phase 3 D9).
3. Delete `_snapTick`, wing plan setters, wing mint branches.
4. Retarget Routes / Import / Previews / FeeCompound / adversarial that read wings or `PositionKind`.
5. Import still uses NFT ticks (D34).

**Exit:** Dual-sided organic create (via current zap, even if still fee-first) stores center ticks = `minUsableTick` / `maxUsableTick`. No wing slots to query. `widthMultiplier` still required `>= 1` at `deployVault`.

**Risk:** FeeCompound still 100% deploys free into **center** until Phase 3. Update asserts from wings to center; do not keep 10/90.

---

### Phase 3 — Sleeve + Out split + delegates (D1–D29, D48 Out, D53, D56–D59)

**Goal:** Nested `LOK` deposits succeed; 20% sleeve; Out mutate/query split; CREATE3 In/Out delegates.

**Tasks:**

1. Interface + Target + Facet + CREATE3 liquid reserve. DFPkg cut + USAGE type id. TestBase type default 20%.
2. Gate, D9 SoT, deadband, rebalance, NatSpec D21.
3. Rewrite zap-in/out; delete `_feeFirstCompound*`. A0 on first mint.
4. InBase + InExecutionDelegate + InFacet constructor. OutExecuteTarget + OutQuery* + OutExecutionDelegate + OutFacet constructor.
5. FactoryService deploy wiring (V4 `bytes.concat`).
6. Import blocked-revert. Direct swap blocked-revert.
7. D61 writers that compile: TestBase + Base fork `_buildPkgInit` at least for liquid-reserve + OutQuery (Multi fields can wait until Phase 5 **if** `PkgInit` adds Multi as zero-address-illegal — **do not** allow `address(0)` facets. If `PkgInit` gains Multi fields, Phase 3 must pass real CREATE3 Multi facets even if Targets still revert `Exchange*NotAvailable`, **or** add Multi fields only in Phase 5 as one struct change).

**Locked here:** add **all** D48 `PkgInit` fields in Phase 3 **or** Phase 5 as a single struct bump, never a two-step `address(0)` hole. **This plan: one struct bump in Phase 5.** Phase 3 `PkgInit` adds **liquid-reserve + OutQuery only** (cuts 9→11). Phase 5 adds four Multi (11→15). Both bumps update **every** D61 writer the same commit. LR-7: no zero facets.

**Exit:** Idle dual-token sequential zap-in leaves ~20% free (deadband). Blocked `exchangeIn` via harness sleeves without `LOK`. Blocked amount-out cover/short. Public rebalance reverts when locked. Out preview lives on OutQueryFacet. Existing Out IFacet updated.

---

### Phase 4 — Sleeve tests T1–T16 analog

**Goal:** V4 buffer T1–T16 meaning on this package.

**Tasks:**

1. Harness + `UniswapV3StandardExchange_LocalLiquidBuffer.t.sol`.
2. T1 idle dual-sided: **sequential token0 then token1** (or later Multi). Full-range L needs both tokens; do not assert 20% after a **single**-token zap (V4 lesson). T1b: do not require 20% after token0-only.
3. Blocked join sleeve-only; blocked amount-out; deadband; donations count as free; public rebalance reverts when locked.
4. Rewrite `UniswapV3StandardExchange_FeeCompound.t.sol` to collect + D27 (free remains ~20%, not ~0).

**Exit:** T1–T16 analog green. FeeCompound suite green under new law.

---

### Phase 5 — Multi facet scaffold (D48 remainder, D61)

**Goal:** Diamond exposes Multi selectors. Cuts **11→15** (after Phase 3) or **9→15** if Phase 3 deferred OutQuery into this phase — **this plan Phase 3 already cut OutQuery + liquid-reserve (11).**

**Tasks:**

1. Four Multi Facets + four Targets (logic may still revert `Exchange*NotAvailable` only if the same phase cannot fill them; **prefer real Targets in Phase 6 immediately**; do not ship a green IFacet with permanently empty mutate).
2. FactoryService `deploy*` + `attachUniswapV3StandardExchangeMultiFacets`.
3. DFPkg `facetCuts` 11→15; `facetInterfaces` + InMulti + OutMulti.
4. TestBase + **all D61 writers** in the same commit.
5. IFacet tests: InMulti, InMultiQuery, OutMulti, OutMultiQuery. Add InQuery IFacet if still missing.
6. DFPkg deploy: `supportsInterface` InMulti + OutMulti; In/Out/Import/liquid-reserve still true.

**Exit:** New vault has **15** cuts; IFacet metadata green; launch scripts compile.

---

### Phase 6 — Dual join / exit (D41–D52, D49)

**Goal:** `exchangeInManyToOne` / `exchangeOutOneToMany` + previews.

**Tasks:**

1. Validation, pull, A0, mint, tail-rebalance. Preview parity for **user-returned shares** (D24).
2. D52 helper in Common; idle remove center only; blocked sleeve cover; share refund `maxAmountIn - S`.
3. OutMulti stack-too-deep: `DualExitLocal` + helpers (copy V4). No Multi delegate.
4. Tests MJ1–MJ8, ME1–ME7, A0 on Multi join. Harness for blocked Multi. I1 both tokens.

**Exit:** Idle proportional join produces full-range L and ~20% sleeve. Unbalanced exit reverts with no send. Blocked short reverts whole tx. Descending token order reverts.

---

### Phase 7 — Full-range book tests (FR1–FR6)

**Goal:** Range law independent of Multi (may use sequential zaps and/or Multi join).

**Tasks:** FR1–FR6 on `UniswapV3StandardExchange_FullRangeBook.t.sol`. FR2: external swapper walks many spacings; center still in range; fees owed and/or totals increase. FR6: import NFT ticks ≠ min/max.

**Exit:** FR1–FR6 green. Import suite still green.

---

### Phase 8 — Forks (D16 / D60)

**Goal:** Base + Robinhood 4663 production-path smoke.

**Base:** `FOUNDRY_PROFILE=fork`. Extend existing `UniswapV3StandardExchange_Fork.t.sol`. Factory `BASE_MAIN.UNISWAP_V3_FACTORY`. Pool WETH/USDC fee **500**. Type default 20%. At least FR1 or MJ2, one blocked sleeve path, A0. No share-math reimplementation.

**Robinhood 4663:** new `UniswapV3StandardExchange_Robinhood.t.sol`. `FOUNDRY_PROFILE=fork`. RPC `robinhood_mainnet_alchemy` else `robinhood_mainnet`. Factory `ROBINHOOD_MAIN.UNISWAP_V3_FACTORY` (`0x1f7d7550B1b028f7571E69A784071F0205FD2EfA`). Pool `WETH9` × `USDG` fee **500**, else **3000**, else **100**. Missing factory code or `getPool == 0`: **`require` fail (env blocker)**, not `vm.skip`. Same FR1-or-MJ2 + blocked + A0.

**Exit:** Both fork suites green, or 4663 fails loudly with the blocker message.

---

### Phase 9 — Docs + DoD

1. V3 vault plan tick paragraph: full-range center; wing storage deleted.
2. NatSpec D21 + D30–D35 + D39–D61.
3. PRD related row points at this file.
4. Mark phases done only after listed tests are green.

**Exit:** PRD §7.4 items 1–13 true.

---

## 11. Test matrix (IDs)

Gold: `TestBase_UniswapV3StandardExchange` → `indexedexManager.deployUniswapV3StandardExchangeDFPkg` → `pkg.deployVault(pool, widthMultiplier)` (`DEFAULT_WIDTH_MULTIPLIER = 10` is fine; ignored for ticks).

Production-first. No mock SUT.

### 11.1 Existing (must remain green after retarget)

| Suite | Note |
|-------|------|
| Routes / Previews | Full-range center; D9 SoT; preview ignores rebalance |
| Import | NFT ticks; blocked revert; empty NFT retained |
| FeeCompound | Collect + D27, not 100% deploy |
| DFPkg_Deploy | 15 cuts + new interface ids |
| In/Out/Import IFacet | Out funcs length 1; add OutQuery |
| adversarial/* | Drop wing asserts; keep I1 single-token; add Multi I1 |

### 11.2 Sleeve (T analog)

Same meaning as V4 buffer T1–T16. V3 “blocked” = harness swap callback. Dual-sided T1 uses **both** tokens (sequential zap or Multi). Token0-only must **not** require 20% sleeve + in-range L.

### 11.3 Full-range (FR)

PRD §7.2 FR1–FR6. FR1: ticks = Crane V3 `minUsableTick` / `maxUsableTick`; **no wing storage**.

### 11.4 Multi join / exit

PRD MJ1–MJ8, ME1–ME7, A0.

| ID | Assertion |
|----|-----------|
| MJ1 | Length ≠ 2 / unsorted / not pool tokens / zero amount → `ExchangeInNotAvailable` |
| MJ2 | Idle proportional join: full-range L; sleeve ~20% |
| MJ3 | Unbalanced join: both `amountsIn` pulled; surplus free; no swap |
| MJ4 | Blocked join: no `mint`/`swap`; shares minted |
| MJ5 | `pretransferred=true` without both deliveries: no mint from inventory |
| MJ6 | Preview shares == exec shares (idle and blocked) |
| MJ7 | (alias of MJ6 if numbered in V4 extra) Preview join shares == exec |
| MJ8 | `[token1, token0]` reverts |
| ME1 | Dual-exit validation |
| ME2 | D52 proportional pays both; burns S |
| ME3 | Unbalanced exit reverts; **no** tokens sent |
| ME4 | Blocked cover vs short |
| ME5 | `S > maxAmountIn` reverts |
| ME6 | Preview exit shares == exec |
| ME7 | `maxAmountIn > S` refunds unused shares to `msg.sender` |
| A0 | Residual at `totalSupply == 0`; dead-sink shares > 0; first minter not 100% of that residual; redeem cannot take the donation |

---

## 12. Definition of done

Copied from PRD §7.4, operationalized:

1. New non-imported vaults: one full-range center; **no wing storage**.
2. Idle ops: sleeve ~20% within D22 after dual-sided inventory exists.
3. Blocked nested In/Out: sleeve deposit; amount-out cover or revert; no nested pool `mint`/`burn`/`swap`/`collect`.
4. FR1–FR6, MJ1–MJ8, ME1–ME7, A0, T1–T16 analog, retargeted route/import/adversarial green on the hermetic gold path.
5. Base-main fork and Robinhood 4663 fork green (D60), or 4663 **fails** as env blocker (not skip).
6. NatSpec D1–D61 (V3 gate wording).
7. Diamond cuts: liquid-reserve, OutQuery, four Multi; existing In/Out/Import work; Out preview on OutQueryFacet.
8. Liquid-reserve interface id is USAGE / type-default key; 20% set in TestBase.
9. Out Multi file remains `IStandardExchangeOutMulti.sol`.
10. Crane V3 TickMath helpers + Crane unit tests green.
11. CREATE3 In/Out execution delegates exist; Multi has none.
12. Every D61 `PkgInit` writer compiles with the new fields.
13. No `via_ir`. No new Foundry profile.

---

## 13. Suggested forge commands

```bash
# Phase 1
forge test --match-path lib/crane/test/foundry/spec/protocols/dexes/uniswap/v3/libraries/TickMath.t.sol

# Phase 2–4
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Routes.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_LocalLiquidBuffer.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_FeeCompound.t.sol

# Phase 5
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchangeInMultiFacet_IFacet_Test.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg_Deploy.t.sol

# Phase 6–7
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_FullRangeBook.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_MultiJoinExit.t.sol

# Phase 8
FOUNDRY_PROFILE=fork forge test --match-path test/foundry/fork/base_main/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Fork.t.sol
FOUNDRY_PROFILE=fork forge test --match-path test/foundry/fork/robinhood_4663/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Robinhood.t.sol
```

First compile in a worktree: seed `cache_forge/` + `out/` from a warm checkout; set tool timeouts to **hours**, not minutes. After green, copy cache back to the warm seed.

---

## 14. Out of scope (do not sneak in)

- Recast / JIT / D28 carve-out
- Multi on Slipstream or other SEs
- `IStandardExchangeMultiAssetLiquidity`
- Merging Multi into `IStandardExchange`
- Native ETH
- Live-book migration of old center+wings vaults
- A third Foundry profile
- `via_ir`
- Silent `vm.skip` on 4663
- New launch Stage / `anvil_robinhood_main` tree
- Importing V4 TickMath into the V3 package
- Multi CREATE3 execution delegates
