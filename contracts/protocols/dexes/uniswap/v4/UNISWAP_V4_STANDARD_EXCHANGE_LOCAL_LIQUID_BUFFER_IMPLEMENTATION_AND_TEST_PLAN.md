# Implementation & Test Plan: Uniswap V4 SE — Local Liquid Buffer

**Status:** Ready for coding (product law frozen)  
**Date:** 2026-08-05  
**Product law (normative):** [`UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md) (**v1.6**, D1–D29)  
**Bring-up plan (historical):** [`UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md`](./UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md)  
**Package path:** `contracts/protocols/dexes/uniswap/v4/`

This document is the **coding plan**. Do not re-open locked PRD decisions without a PRD revision. When product text and this plan conflict, **the PRD wins**.

---

## 0. Mission (one sentence)

Make the Uniswap V4 Standard Exchange **batch-compatible** under the PoolManager singleton lock by counting a **local free sleeve** in share math, accepting deposits without nested `unlock`, paying blocked amount-out from free inventory when covered, and **rebalancing free↔deployed** when interaction is free—using fee-oracle `liquidReservePercentage` (type default **20%**).

---

## 1. Authority & constraints

| Layer | Role |
|-------|------|
| PRD v1.6 | Product law (D1–D29) |
| **This plan** | Phases, files, APIs, algorithms, test matrix, DoD |
| Crane / IndexedEx testing skills | Production-first: real DFPkg + real PoolManager (Crane port) + real fee oracle; no mock SUT |
| Staking SE liquid sleeve (Lido / Rocket / EtherFi) | **Behavioral peer only** — do **not** subclass |

### Hard rules (from PRD + repo)

1. **Never** `new` facets/DFPkgs; CREATE3 + FactoryService + manager vault registry for packages.
2. **Never** mock vault / manager / oracle / PoolManager as SUT.
3. **No** outer-pool/hook tracking (D25); **no** native currency scope (D26).
4. **No** rebalance swaps (D28); **no** opportunistic free-path amount-out from sleeve (D3).
5. Free deposit = **sleeve-then-deploy-excess** (D27), not fully-deploy-then-pull.
6. Preview models **user path only**; ignores post-op rebalance (D24).

---

## 2. Current state (baseline)

| Area | Today | Required after this work |
|------|-------|--------------------------|
| `_totalVaultReserves()` | `_positionAmounts()` only | `position + free ERC-20 balances` (D9/D29) |
| Zap-in | Swap residual → add liquidity → mint on amounts **used** → **refund remainder** to caller | Pull → credit free → mint on **total** reserves → (if free) rebalance deploy **excess only**; remainder stays as sleeve (not refunded as “unused zap dust” when it is vault capital) |
| Zap-out / amount-out | Always PM remove/swap | **Blocked:** sleeve cover or revert (D18). **Free:** always PM then rebalance (D3) |
| Direct swap | Always PM | Free: PM + tail-rebalance. Blocked: `PoolManagerInteractionBlocked` (D12) |
| Gate | None | `canOpenPoolManagerUnlock()` (D1) |
| Rebalance | None | Deadband deploy/remove; public + tail (D10/D22/D28) |
| Fee type id | `IStandardVault.interfaceId` for USAGE | Prefer **V4-specific** marker interface id (staking pattern) so type default 20% does not hit all standard vaults |
| Nested hook buffer | Fails `AlreadyUnlocked` if SE tries nested unlock | Sleeve path succeeds mid-outer-unlock |

---

## 3. Target architecture

```text
                    ┌─────────────────────────────────────┐
                    │  Uniswap V4 Standard Exchange       │
                    │  shares = free + deployed (totals)  │
                    └──────────────┬──────────────────────┘
                                   │
           canOpenPoolManagerUnlock()  :=  !isUnlocked(PM)
                    ┌──────────────┴──────────────┐
                    │ free (idle)                 │ blocked (in-session)
                    ▼                             ▼
         deposit: sleeve mint                  deposit: sleeve mint
         then rebalance deploy excess          no unlock / no rebalance
         amount-out: ALWAYS PM                 amount-out: free cover → pay
         then rebalance                        else InsufficientLocalReserve
         direct swap: PM + rebalance           direct swap: REVERT
         public rebalanceLiquidReserve()       public rebalance: REVERT
         import needing unlock: OK             import needing unlock: REVERT
```

### 3.1 Recommended module split

| Module | Responsibility |
|--------|----------------|
| **Common** (`UniswapV4StandardExchangeCommon.sol`) | Gate; free/deployed views; `_totalVaultReserves`; deadband math; rebalance helpers; `_executeUnlock` guard; NatSpec D21 |
| **In paths** (`InBase` / `InTarget` / delegate) | Sleeve mint deposit; branch free vs blocked; tail-rebalance when free |
| **Out paths** (`OutTarget`) | Blocked sleeve pay / free PM; tail-rebalance when free; direct swap gate |
| **Rebalance surface** (new facet or fold into In/query facet) | Public `rebalanceLiquidReserve()` |
| **Query / marker** | Operator views: gate, free, deployed, target %, optional actual % |
| **DFPkg / FactoryService** | Facet cuts; V4 fee type id; type default wiring in tests/setup |
| **Position import** | Gate: hard-revert when blocked (D15) |

---

## 4. Concrete APIs (implementation choices)

Names may align to existing `UniswapV4Exchange_*` style; keep selectors stable for existing SE surface (`exchangeIn` / `exchangeOut` / previews).

### 4.1 Errors (normative intent)

| Error | When |
|-------|------|
| `UniswapV4Exchange_PoolManagerInteractionBlocked()` | Path requires unlock while `!canOpenPoolManagerUnlock()` (direct swap, blocked rebalance, blocked import, free-path PM when wrongly called while blocked) |
| `UniswapV4Exchange_InsufficientLocalReserve(address token, uint256 requested, uint256 available)` | Blocked amount-out short on requested `tokenOut` |
| Existing deadline / slippage / zero / disabled | Unchanged |

### 4.2 Events (recommended)

| Event | When |
|-------|------|
| `LiquidReserveRebalanced(uint256 free0, uint256 free1, uint256 deployed0, uint256 deployed1, uint256 liquidPct)` | After successful rebalance that performed unlock work **or** optional emit on idle deadband skip (prefer emit only when state moved) |
| `LocalDepositWhileBlocked(address token, uint256 amount, uint256 sharesOut)` | Optional telemetry |

### 4.3 Public / external surface (new)

```solidity
// Views (query facet or marker)
function canOpenPoolManagerUnlock() external view returns (bool);
function localReserve(address token) external view returns (uint256);      // free balanceOf for pool currencies; 0 otherwise
function deployedReserve() external view returns (uint256 amount0, uint256 amount1);
function targetLiquidReservePercentage() external view returns (uint256);  // live oracle WAD
function actualLiquidReservePercentage(address token) external view returns (uint256); // optional

// State-changing
function rebalanceLiquidReserve() external; // nonReentrant; free only; idle success if both in deadband
```

**Interface placement:** define structs/selectors on a dedicated interface, e.g. `IUniswapV4StandardExchangeLiquidReserve` (or extend a thin marker). **PkgInit/PkgArgs stay on DFPkg interface** (Crane rule). Prefer a **package-specific** fee type id:

```solidity
// DFPkg.vaultFeeTypeIds — prefer (staking pattern):
// USAGE → type(IUniswapV4StandardExchangeLiquidReserve).interfaceId
// NOT shared IStandardVault.interfaceId for liquid % type defaults (avoids cross-product pollution)
```

If changing fee type id is migration-sensitive for already-deployed test artifacts only, still prefer the specific id for hermetic greenfield; document any registry mapping.

### 4.4 Internal helpers (Common)

```solidity
function canOpenPoolManagerUnlock() public view returns (bool); // D1

function _freeBalances() internal view returns (uint256 free0, uint256 free1); // D29 balanceOf
function _deployedAmounts() internal view returns (uint256, uint256);         // existing _positionAmounts
function _totalVaultReserves() internal view returns (uint256, uint256);      // free + deployed

function _liveLiquidReservePercentage() internal view returns (uint256);      // D20 oracle live
function _targetFree(uint256 total_i, uint256 liquidPct) internal pure returns (uint256);
function _absoluteFloor(address token) internal view returns (uint256);       // 10^max(0, decimals-6)
function _shouldRebalanceToken(uint256 free_i, uint256 targetFree_i, uint256 floor_i) internal pure returns (bool);

function _rebalanceLiquidReserveBestEffort() internal; // D10/D11/D22/D28; no-op if blocked? only called when free
function _requireCanOpenPoolManagerUnlock() internal view;
function _requireCannotNestedUnlock() — prefer positive canOpen checks at call sites
```

**Unlock guard:** every `_executeUnlock` entry (or wrapper) should `require(canOpenPoolManagerUnlock())` so a missed branch cannot nested-unlock.

---

## 5. Algorithms (LOCKED product → implement exactly)

### 5.1 Deadband (D22)

```text
RELATIVE_TOL_WAD = 0.05e18   // 5% of target free
ABSOLUTE_FLOOR_i = 10^max(0, decimals_i - 6)

targetFree_i = total_i * liquidPct / 1e18
deviation    = |free_i - targetFree_i|

rebalance token i iff:
  if targetFree_i == 0: free_i > ABSOLUTE_FLOOR_i
  else: deviation > max(ABSOLUTE_FLOOR_i, targetFree_i * RELATIVE_TOL_WAD / 1e18)

When tripped: move free_i TO targetFree_i (not merely to band edge).
If both tokens within band: skip unlock (public rebalance returns success).
```

### 5.2 Rebalance actions (D28 — no swaps)

**Deploy excess (free_i > targetFree_i beyond deadband):**

1. Compute `excess_i = free_i - targetFree_i` for each token that trips high.
2. Use existing managed-liquidity plan / add-liquidity path with **available free balances** as budgets (not a swap of one token for the other).
3. Prefer single unlock: add liquidity to center (and wings if package still allocates free budgets via existing `_managedLiquidityPlan`).
4. Only spend free inventory; do not pull from outside.
5. Best-effort: if range allows only one currency (OOR), deploy what the plan can; leave residual free (D11).

**Refill deficit (free_i < targetFree_i beyond deadband):**

1. Compute `need_i = targetFree_i - free_i`.
2. Remove liquidity proportionally from managed positions (existing `_burnPositionLiquidity` / remove path) such that free inventory of the short token increases toward target.
3. **Caveat (implement carefully):** remove-liquidity yields **both** currencies. Heuristic (v1 acceptable):
   - Estimate liquidity to burn so that the short token’s free approaches target.
   - After remove, if the other token’s free overshoots target beyond deadband, a **subsequent** rebalance (same call if still free, or next free op) may deploy that excess without swapping.
   - Prefer **one unlock** that removes a conservative liquidity amount; recompute free/targets mid-callback only if stack-safe; otherwise remove once, sync, and optionally second unlock in same `rebalanceLiquidReserve` only if still outside deadband and gas-reasonable.
4. **No** token0↔token1 swap to rebalance composition.

### 5.3 Deposit / zap-in (D4 / D27)

```text
// Both free and blocked:
1. Secure pull of amountIn (existing pretransferred rules)
2. Capture totals BEFORE mint (post-pull free already includes deposit)
3. sharesOut = existing multi-asset mint math on TOTAL reserves
   - first mint: use package first-mint formula on free totals (must not require deployed)
   - subsequent: ConstProdUtils-style or package equivalent on free+deployed
4. minSharesOut check; mint to recipient; sync reserves
5. if canOpenPoolManagerUnlock():
      _rebalanceLiquidReserveBestEffort()  // deploy excess only; D11 swallow rebalance failure
   else:
      // stay sleeve; optional LocalDepositWhileBlocked
```

**Breaking change vs current zap-in:** do **not** swap+fully-deploy+refund-remainder as the primary deposit shape. User pays `amountIn`; capital remains vault-owned free inventory until rebalance deploys excess.  
**Refund policy:** only refund true excess that is **not** part of the user’s deposited amountIn (e.g. if pull overshot). Do not refund the sleeve that backs minted shares.

**Preview zap-in:** share mint from total reserves under current free/blocked gate; **do not** simulate rebalance deploy (D24). When free or blocked, user-returned `sharesOut` matches exec mint; free/deployed split after free exec may differ.

### 5.4 Amount-out / zap-out (D3 / D18)

```text
if canOpenPoolManagerUnlock():
  // Always PM even if free[tokenOut] covers
  existing remove-liquidity / swap residual path for single tokenOut
  burn shares / settle
  sync; then _rebalanceLiquidReserveBestEffort()
else:
  if free[tokenOut] >= required and slippage ok:
    pay from free; burn shares using TOTAL reserve math; sync
  else:
    revert InsufficientLocalReserve
```

**Preview:** free → PM quote path; blocked → sleeve cover/short only.

### 5.5 Direct pool swaps (D12)

- Free: existing PM swap; then tail-rebalance.
- Blocked: revert `PoolManagerInteractionBlocked`.
- Preview: swap only when free; blocked N/A / revert.

### 5.6 Position import (D15)

- Any import path that needs PoolManager / PositionManager liquidity mutation while blocked → hard-revert interaction-blocked.
- Do not invent free-only import.

### 5.7 Share math notes (D9 / D13)

- Totals always `free_i + deployed_i`.
- Donation of token0/token1 increases free and dilutes share price (accepted D29).
- Never add ERC-6909 PM claims into free unless the package already treats them as inventory (today: do not).

---

## 6. File impact map

### 6.1 Production (primary)

| File | Work |
|------|------|
| `UniswapV4StandardExchangeCommon.sol` | Gate; free+deployed totals; deadband; rebalance helpers; unlock guard; errors/events constants; NatSpec |
| `UniswapV4StandardExchangeInBase.sol` | Replace primary zap-in with sleeve mint + optional rebalance; preview share mint from totals |
| `UniswapV4StandardExchangeInTarget.sol` | Wire exchangeIn tail-rebalance; NatSpec |
| `UniswapV4StandardExchangeInExecutionDelegate.sol` | Only if stack/delegate path needs gate/rebalance plumbing |
| `UniswapV4StandardExchangeOutTarget.sol` | Free vs blocked amount-out; direct swap gate + tail-rebalance |
| `UniswapV4StandardExchangePositionImportTarget.sol` | Blocked → hard-revert |
| **New** `IUniswapV4StandardExchangeLiquidReserve.sol` (or under package interfaces) | Views + `rebalanceLiquidReserve` |
| **New** `UniswapV4StandardExchangeLiquidReserveTarget.sol` | Public rebalance + views implementation |
| **New** `UniswapV4StandardExchangeLiquidReserveFacet.sol` | Facet cut |
| `UniswapV4StandardExchangeDFPkg.sol` | Facet cut + interface id; **V4-specific USAGE fee type id** |
| `UniswapV4_Component_FactoryService.sol` | Deploy new facet CREATE3 helper |
| `UniswapV4QuoteService.sol` | Only if preview helpers need total-reserve inputs (likely small) |

### 6.2 Fee oracle

| File | Work |
|------|------|
| Oracle repo/facets | **No new fields** |
| Test / deploy setup | `setDefaultLiquidReservePercentageOfTypeId(v4UsageFeeTypeId, 0.20e18)` |
| Optional unit row | Cascade vault → type → global for V4 type id |

### 6.3 Tests

| Path | Work |
|------|------|
| `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol` | Extend: type default 20%; helpers for force-in-session; rebalance; free/deployed asserts |
| **New** `test/foundry/spec/protocols/dexes/uniswap/v4/UniswapV4StandardExchange_LocalLiquidBuffer.t.sol` (or co-located under package test/) | T1–T16 matrix |
| **New** harness `.../harness/PoolManagerUnlockSeCaller.sol` (or test contract) | Outer unlock → SE.exchangeIn (H1) |
| **New** integration test | H2 (+ H3 if path): Single SE Buffer CP hook with SE = V4 vault |
| Adversarial | T13 reentrancy on blocked deposit (existing reentrancy patterns) |

### 6.4 Docs

| File | Work |
|------|------|
| This plan | Living checklist; mark phases done |
| PRD | Authority already points here after link update |
| `UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md` | Already points at PRD; add one line to this plan when Phase 7 lands |

---

## 7. Phased delivery

Each phase ends with **compile + listed tests green**. Do not start the next phase with red tests unless blocked by an explicit PRD gap.

### Phase 0 — Spec freeze (done)

- [x] PRD v1.6 D1–D29 locked  
- [x] This implementation plan authored  

**Exit:** product + plan authority clear.

---

### Phase 1 — Accounting SoT (D9 / D29)

**Goal:** Shares and reserves see free + deployed; donations count.

**Tasks:**

1. Implement `_freeBalances()` via `balanceOf` for token0/token1.
2. Change `_totalVaultReserves()` → free + `_positionAmounts()`.
3. Ensure `_syncVaultReserves()` writes totals.
4. Add views: `localReserve`, `deployedReserve` (can be temporary public for tests if facet not yet cut—prefer facet early if diamond needs it).
5. Audit all mint/burn call sites that assumed position-only reserves.

**Tests:** T9, T4d (donation dilutes).  
**Risk:** Existing zap tests assume refund of residual free balances—expect breakage; fix in Phase 3 deposit rewrite, not by reverting accounting.

**Exit:** Totals always include free; no double-count of position.

---

### Phase 2 — Gate + blocked deposit/amount-out + import (D1/D2/D4/D15/D18/D21)

**Goal:** Nested unlock impossible on deposit; blocked out is sleeve cover/revert.

**Tasks:**

1. `canOpenPoolManagerUnlock()` using `TransientStateLibrary.isUnlocked` (Crane import path).
2. Guard `_executeUnlock` (or all unlock call sites).
3. Blocked deposit path: pull → mint → no unlock (may temporarily share code with Phase 3 free deposit before rebalance exists—OK if free path still old until Phase 3, **but** free path must not leave accounting inconsistent).
4. Blocked amount-out: cover/revert; wrong-token free reverts.
5. Position import: blocked hard-revert.
6. NatSpec on gate and blocked paths (D21).

**Practical ordering note:** If free-path still fully deploys in this phase, free tests may still pass old semantics; prioritize **blocked** tests + unlock guard.

**Tests:** T2, T4, T4b, T5, T12, T4e; harness sketch for T2 (outer unlock optional here, required Phase 6).  
**Exit:** Force in-session deposit succeeds without nested unlock; short amount-out reverts.

---

### Phase 3 — Free deposit sleeve-then-deploy + rebalance + free out/swap (D3/D10/D12/D22/D27/D28)

**Goal:** Steady-state ~20% free; free ops correct.

**Tasks:**

1. **Rewrite free zap-in** to D27 sleeve mint + `_rebalanceLiquidReserveBestEffort`.
2. Implement deadband + deploy excess / remove refill (no swaps).
3. Public `rebalanceLiquidReserve()` + facet/DFPkg wiring.
4. Free amount-out: always PM then rebalance (even if sleeve covers)—T4c.
5. Free direct swap: PM + rebalance; blocked swap reverts—T6/T7.
6. Public rebalance blocked reverts—T14; deadband T15/T16; no-swap T4f.
7. Event emit after meaningful rebalance.

**Tests:** T1, T1b, T3, T4c, T4f, T6, T7, T14, T15, T16.  
**Exit:** Idle vault holds free ≈ 20% within deadband after free ops; blocked rebalance reverts.

**Implementation tips:**

- Mirror staking rebalance target structure (`*RebalanceTarget`) but dual-token + PM.
- Keep rebalance best-effort: try/catch or internal bool; **never** revert user op for rebalance miss (D11)—except public rebalance may revert on blocked or hard failures (document: public rebalance reverts only on interaction-blocked; soft skip on dust; hard failure on unexpected PM error may revert public call—acceptable).
- For stack-too-deep: push rebalance into separate internal function / external self-call via facet already on diamond.

---

### Phase 4 — Preview user-path parity (D24)

**Goal:** `preview == execution` for user-returned amounts.

**Tasks:**

1. Zap-in preview: total-reserve mint math; no rebalance simulation.
2. Zap-out preview: free → PM path; blocked → sleeve branch.
3. Direct swap preview: free only.
4. Assert T8 / T8b: free zap-in sharesOut equal even when rebalance moves inventory after.

**Tests:** T8, T8b.  
**Exit:** Preview/exec user amounts match under same gate snapshot.

---

### Phase 5 — Oracle type default + live cascade (D5–D8/D20)

**Goal:** Fresh V4 SE sees 20% without vault override; live reads.

**Tasks:**

1. Introduce V4-specific USAGE fee type id (recommended).
2. TestBase / Indexedex setup: `setDefaultLiquidReservePercentageOfTypeId(..., 0.20e18)`.
3. No vault-side cache of percentage.
4. Mid-test type default change → next rebalance uses new pct.

**Tests:** T10, T11, T11b, H4.  
**Exit:** Cascade proven; type default 20%.

---

### Phase 6 — Batch compatibility DoD (D19) + adversarial

**Goal:** Merge-blocking nested proof.

**Tasks:**

1. **H1** generic harness: contract `unlockCallback` calls `SE.exchangeIn` (and optionally amount-out) while PM unlocked.
2. **H2** one real buffer hook (prefer Single SE Buffer Constant Product or Single SE Buffer) with bound SE = this V4 vault; mid-swap buffer deposits succeed.
3. **H3** if applicable: mid-session amount-out cover/short.
4. **T13** reentrancy hostile ERC20 as deposit token only if package allows; else reenter via malicious callback pattern on blocked deposit.

**Tests:** H1–H4, T13.  
**Exit:** No `AlreadyUnlocked` on nested deposit; outer batch completes.

---

### Phase 7 — Docs & cleanup

**Tasks:**

1. NatSpec complete on gate, deposit, amount-out, rebalance (D21).
2. Point vault plan at this plan’s completion status.
3. Mark PRD “implementation in progress / done” only if product owner wants—optional.
4. `forge fmt`; remove dead refund paths that break sleeve accounting.
5. Grep for “position-only” reserve assumptions and leftover “refund all free balance” patterns.

**Exit:** Docs consistent; full §8 matrix green.

---

## 8. Test matrix (DoD)

Production-first: extend `TestBase_UniswapV4StandardExchange` (or successor). Real PoolManager (Crane port), real fee oracle, real DFPkg path.

### 8.1 Hermetic unit / integration

| ID | Case | Expect | Phase |
|----|------|--------|-------|
| **T1** | Idle deposit / zap-in | Sleeve mint then deploy excess; free ≈ 20% within deadband | 3 |
| **T1b** | Idle deposit shape | Not fully-deploy-then-pull as primary shape | 3 |
| **T2** | In-session SE deposit | Sleeve; no nested unlock; shares vs total reserves | 2 |
| **T3** | After T2, public rebalance idle | Excess free deploys → ~20% | 3 |
| **T4** | Blocked amount-out ≤ free | Pay sleeve; share burn correct | 2 |
| **T4b** | Blocked amount-out wrong token free | Revert | 2 |
| **T4c** | Free amount-out large sleeve | Always PM, not sleeve-first; then rebalance | 3 |
| **T4d** | Donation token0/token1 | Free+totals ↑; share price dilutes | 1 |
| **T4e** | Position import blocked | Revert interaction-blocked | 2 |
| **T4f** | Rebalance no swap | Deploy/remove only | 3 |
| **T5** | Blocked amount-out > free | `InsufficientLocalReserve` | 2 |
| **T6** | Blocked direct swap | Revert interaction-blocked | 3 |
| **T7** | Idle direct swap | PM then tail-rebalance | 3 |
| **T8** | Preview == exec user path | Free zap-in, blocked zap-in, blocked covered out | 4 |
| **T8b** | Free zap-in with rebalance | sharesOut preview == exec; free/deployed may differ after | 4 |
| **T9** | Reserves = free + deployed | Views match balances + position | 1 |
| **T10** | Oracle cascade | Vault → type → global | 5 |
| **T11** | Type default 20% | No vault override | 5 |
| **T11b** | Change type default live | Next rebalance sees new pct | 5 |
| **T12** | First mint blocked | Free only; later free rebalance creates position | 2→3 |
| **T13** | Reentrancy blocked deposit | Nested reenter fails safely | 6 |
| **T14** | Public rebalance blocked | Reverts; no unlock | 3 |
| **T15** | Within deadband | No unlock | 3 |
| **T16** | Outside deadband | Moves to target; then within band | 3 |

### 8.2 Nested / hook DoD

| ID | Case | Expect | Phase |
|----|------|--------|-------|
| **H1** | Outer unlock harness → SE deposit | Success via sleeve | 6 |
| **H2** | One real buffer hook mid-swap | Outer completes; SE shares ↑ | 6 |
| **H3** | Mid-session amount-out (if path) | Cover/short rules | 6 |
| **H4** | Type default on live vault | `0.20e18` | 5–6 |

### 8.3 Explicitly out of scope (v1)

1. Multi-PoolManager.  
2. Multi-hook economic matrix.  
3. Native ETH currency sleeve.  
4. Piggyback outer unlock settlement.  
5. Fee-on-transfer pool tokens (assume standard ERC-20; if needed, note as non-goal).  
6. New fee-oracle field names.

---

## 9. Suggested test helpers

```solidity
// On TestBase or harness:
function _forcePoolManagerUnlocked(address poolManager, function() external callback) internal;
// Implementation: deploy UnlockHarness that calls poolManager.unlock and runs callback.

function _assertFreeWithinDeadband(address vault, uint256 liquidPct) internal view;
function _free0() / _free1() / _deployed() internal view;
function _setTypeLiquidPct(bytes4 typeId, uint256 wad) internal; // prank oracle owner
```

**Harness sketch:**

```text
contract UnlockSeDepositHarness is IUnlockCallback {
  function run(IPoolManager pm, address se, ...) external {
    pm.unlock(abi.encode(...));
  }
  function unlockCallback(bytes calldata data) external returns (bytes memory) {
    // assert TransientStateLibrary.isUnlocked(pm)
    IStandardExchangeIn(se).exchangeIn(...);
  }
}
```

---

## 10. Risk register (implementation)

| Risk | Mitigation |
|------|------------|
| Existing tests expect full deploy + refund free dust | Rewrite expectations for sleeve; update TestBase seed flows |
| Remove-liquidity dual-token overshoot | Best-effort; second rebalance pass; D28 no swap |
| Fee type id shared with all `IStandardVault` | Use V4-specific interface id (staking pattern) |
| Stack-too-deep in rebalance + zap | External facet function / extra internal frames (existing pattern) |
| Preview gate race eth_call vs send | Document; same class as other lock-sensitive systems |
| Rebalance failure reverts user op | D11: best-effort after user delta finalized |
| Double-count free vs position | Free = ERC-20 only; deployed = position math only |
| First mint with free-only | Fix formulas that divide by empty deployed |

---

## 11. Verification commands

```bash
# Package-focused (adjust match paths as tests land)
forge test --match-path '*UniswapV4StandardExchange*' -vv

# Liquid buffer suite
forge test --match-contract UniswapV4StandardExchange_LocalLiquidBuffer -vvv

# Nested / hook integration when present
forge test --match-test 'test_H|test_Nested|test_LocalLiquid' -vvv

forge fmt
```

Definition of **merge-ready:** §8.1 + §8.2 required IDs green; production-first (no SUT mocks); NatSpec D21 present; type default 20% proven.

---

## 12. Definition of Done (product acceptance map)

| Product acceptance (PRD §13) | Plan coverage |
|------------------------------|---------------|
| Nested deposit no nested unlock; shares on totals | T2, H1, H2, Phase 2–3 |
| Blocked amount-out cover/revert; share burn correct | T4, T4b, T5 |
| Free deposit sleeve-then-deploy; free out/swap PM + rebalance | T1, T1b, T4c, T7 |
| Rebalance add/remove only; public free; blocked reverts; import blocked reverts | T4f, T14, T4e, T15–T16 |
| Free SoT balanceOf; donations | T4d, T9 |
| Preview ignores rebalance; user amounts match | T8, T8b |
| No outer tracking / native creep | Code review checklist Phase 7 |
| Harness + one hook; matrix green | H1–H4 + §8.1 |

---

## 13. Work sequence (recommended single-thread)

```text
Phase 1 accounting
  → Phase 2 gate + blocked paths + import
  → Phase 3 free deposit rewrite + rebalance + free out/swap
  → Phase 4 previews
  → Phase 5 oracle type default
  → Phase 6 harness + one hook + reentrancy
  → Phase 7 docs/fmt/grep cleanup
```

Parallelization (if multiple agents): Phase 5 oracle setup can draft TestBase hooks early; Phase 6 harness can be written against Phase 2 blocked deposit before Phase 3 completes free rebalance.

---

## 14. Open implementation choices (non-product)

These do **not** require PRD revision:

| Item | Recommendation |
|------|----------------|
| Exact error symbol prefixes | `UniswapV4Exchange_*` as above |
| Rebalance as own facet vs Out facet | **Own facet** + interface (cleaner diamond cuts; staking peer) |
| Second unlock inside one public rebalance if still off-band | Allowed if gas OK; prefer one unlock when possible |
| Absolute floor helper | Read `decimals()`; tests may hardcode `1e12` for 18-dec |
| H2 which hook | Prefer lightest real buffer path already tested in repo (Single SE Buffer CP if available; else Single SE Buffer) |
| Emit event on deadband no-op | Prefer **no** event if no inventory moved |

---

## 15. Changelog

| Date | Note |
|------|------|
| 2026-08-05 | v1.0 plan: phases 0–7, file map, algorithms from PRD v1.6, test matrix, DoD |
