# PRD: Uniswap V4 Standard Exchange — Local Liquid Buffer (PoolManager Lock-Safe)

**Name:** Uniswap V4 Standard Exchange local liquid buffer refactor  
**Date:** 2026-08-05  
**Status:** **Draft v1.6 — product law for planning** (Phase 0 complete for product decisions; no implementation yet)  
**Package path:** `contracts/protocols/dexes/uniswap/v4/`  
**Package kind:** Production refactor of the existing **Uniswap V4 Standard Exchange** vault (multi-asset SE shares over one managed V4 CL position + optional free ERC-20 sleeve).

**Related (do not conflate):**

| Artifact | Role |
|----------|------|
| [`UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md) | **Coding plan** — phases, file map, algorithms, test matrix, DoD. |
| [`UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md) | **Range / fee-exposure product law** (D30/D31). This buffer PRD owns sleeve + PoolManager lock. |
| [`UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md`](./UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md) | Original bring-up plan for the V4 SE vault (scaffold + routes). |
| Staking SE liquid sleeve (Lido / Rocket Pool / EtherFi) | **Behavioral peer** for `liquidReservePercentage` + rebalance math. |
| Single / Dual SE Buffer CP hooks | **Primary consumers** that call SE `exchangeIn` / buffer paths **during** a V4 `unlock` session. |
| Vault Fee Oracle | Already exposes **`liquidReservePercentage`** three-tier cascade — **reuse**, do not invent a parallel knob. |

**Authority:**

| Layer | Role |
|-------|------|
| **This PRD (v1.6)** | Product law for local liquid buffer + lock-safe interaction with PoolManager |
| [**Implementation & test plan**](./UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md) | Coding phases, file list, algorithms, test matrix DoD (PRD wins on product conflicts) |
| Staking SE PRDs | Pattern reference only — **do not subclass**; V4 SE remains multi-asset CL vault |

---

## 0. Terminology (normative)

| Term | Meaning |
|------|---------|
| **PoolManager** | Uniswap V4 singleton (`IPoolManager`) bound on this vault. |
| **Idle (Manager locked)** | Transient lock is **not** open: `!isUnlocked(poolManager)`. Vault **may** call `poolManager.unlock(...)` to start its own session. |
| **In-session (Manager unlocked)** | Transient lock is open: `isUnlocked(poolManager) == true`. Nested `unlock` reverts `AlreadyUnlocked`. Vault **must not** call `unlock`. |
| **Interaction-free / can open unlock** | Product gate: Manager is **idle**. Normative predicate: `canOpenPoolManagerUnlock() == true`. |
| **Interaction-blocked** | Product gate: Manager is **in-session**. Normative predicate: `canOpenPoolManagerUnlock() == false`. |
| **Deployed inventory** | Token0/token1 value locked in this vault’s managed V4 position (full-range center, D30) or an imported PositionManager position (D15). |
| **Local liquid sleeve / free inventory** | Token0 and/or token1 ERC-20 balances held **on the vault diamond** and counted as vault reserves, **not** in the V4 position. Still **vault-controlled assets**. **SoT for free:** `IERC20(token).balanceOf(address(this))` for each pool currency (D29) — includes unsolicited transfers/donations. |
| **Total vault reserve** | Deployed inventory + local liquid sleeve. **Share SoT:** assets the vault controls, regardless of free vs V4 placement. |
| **Target liquid percentage** | WAD fraction of **total** reserve that should remain in the local liquid sleeve under steady state. Resolved via fee oracle `liquidReservePercentageOfVault(this)`. |
| **Buffer-last / lock-safe deposit** | When interaction-blocked, accept deposit into the local sleeve (mint shares against total reserve) **without** opening PoolManager. |
| **Sleeve-then-deploy (free deposit)** | When interaction-free, deposit still **credits the sleeve first** and mints shares; then **tail-rebalance deploys only excess** free above target into the V4 position (D27). Do not “fully deploy then pull back” as the primary free-deposit shape. |
| **Rebalance** | When interaction-free, move inventory so actual liquid ≈ target liquid: **deploy excess free into position** or **remove liquidity to refill sleeve**. **No token0↔token1 swap** as a rebalance tool (D28). |

**V4 lock naming pitfall (LOCKED for docs and NatSpec):**

Uniswap V4 source uses **locked = idle** and **unlocked = mid-batch**. Product copy and this PRD prefer **`canOpenPoolManagerUnlock` / interaction-blocked** so operators do not invert the gate. Do **not** write “if unlocked, use local buffer” without defining which `isUnlocked()` sense is meant.

---

## 1. Problem statement

### 1.1 What works today

The Uniswap V4 Standard Exchange vault:

1. Owns a managed CL position (or imported position) on a bound `PoolKey` / `PoolManager`.
2. Implements `IUnlockCallback` and routes swaps / add / remove liquidity through **`poolManager.unlock(...)`**.
3. Treats vault reserves as **position amounts only** (`_totalVaultReserves()` → `_positionAmounts()`).
4. Works for external users and for nesting under **non-V4** hosts (Balancer SE buffer pools, other SE legs, etc.) where PoolManager is idle when the vault is called.

### 1.2 Failure mode (root cause)

Uniswap V4 is a **singleton** with a **single reentrancy lock** around flash accounting:

```text
unlock() {
  if (already unlocked) revert AlreadyUnlocked;
  unlock;
  callback(...);   // swaps, modifyLiquidity, hooks, settlements
  require deltas settled;
  lock;
}
```

IndexedEx V4 **hooks** (Single SE Buffer CP, Dual SE Buffer CP, etc.) run **inside** an outer unlock session (router / PoolManager batch). They buffer `pairToken` into a bound Standard Exchange via `IStandardExchangeIn.exchangeIn` (or equivalent).

If that SE is **this Uniswap V4 vault** (or any vault that must open its own `unlock` to place inventory):

```text
Outer unlock (router / another vault / hook host)
  └─ beforeSwap / deposit / buffer-last
       └─ SE.exchangeIn → V4 SE tries poolManager.unlock()
            └─ AlreadyUnlocked  ✗  (nested unlock forbidden)
```

The vault does **not** fail because the *pool* is wrong; it fails because the **singleton is already unlocked** for someone else’s batch. Nested V4-on-V4 inventory placement is therefore unsafe without a **local inventory path that does not call unlock**.

### 1.3 Product requirement (one sentence)

The V4 SE vault must **always** be able to accept deposits and **serve any amount-out that the local sleeve can cover** when PoolManager interaction is blocked, by holding a **policy-sized local liquid sleeve** (default **20%**), so **any outer V4 pool / hook that buffers into this vault mid-swap or mid-deposit can complete**; when interaction is free it must **run normal V4 ops and rebalance** toward the oracle liquid target.

### 1.4 Nested swap / deposit support (first-class)

This is not an edge case. Product law requires that **swaps (and LP ops) through any Uniswap V4 pool whose hook or path deposits into this vault** succeed even though PoolManager is already in-session for that outer pool:

```text
Any outer V4 pool (hook buffers pairToken / vault share path → this SE)
  during outer unlock + swap or liquidity callback
    → this vault exchangeIn / buffer deposit MUST succeed via sleeve
    → this vault amount-out / unwrap / zap-out MUST pay from sleeve when possible
```

The **20% default sleeve** exists so steady-state free inventory is large enough that typical nested buffer and nested amount-out flows do not immediately exhaust free inventory. Operators may raise the type/vault override further for high nested volume.

---

## 2. Goals

1. **Lock-safe deposits:** When `canOpenPoolManagerUnlock() == false`, `exchangeIn` / share mint paths that receive pool currencies **must succeed** without calling `poolManager.unlock`, by retaining tokens in the local sleeve.
2. **Lock-safe amount-out from sleeve (only when blocked):** When interaction-blocked, every path that pays pool currencies out **must pay from the local sleeve if the requested token’s free balance covers the full required amount**; else **revert and cancel the tx**. Document this rule in **code comments / NatSpec** on the gate and out paths (D21). When interaction-**free**, amount-out **always uses PoolManager** (remove liquidity / swap as today) — even if free balance would cover — then tail-rebalance (D3). Sleeve is **not** an opportunistic free-path funding source.
3. **Batch compatibility (preventative sleeve only):** Remain operable when nested inside a batch that already holds the PoolManager lock (D19). **No** outer-pool/hook tracking (D25); **no** native-currency scope (D26).
4. **Target sleeve in steady state:** When interaction-free: **complete the user operation first**, then **rebalance** toward  
   `targetFree_i = total_i * liquidReservePercentageOfVault(this) / 1e18` with type default **`0.20e18` (20%)**. Always **re-read** the oracle on each op/rebalance — no cached pct (D20). Free-path **deposits** use sleeve-then-deploy-excess (D27).
5. **Permissionless rebalance:** Public `rebalanceLiquidReserve()` when free; **revert** when blocked (D10). Rebalance is **add/remove liquidity only** — no cross-token swap (D28).
6. **Shares = vault-controlled assets:** Share mint/burn use **total** reserves = free + deployed. Free SoT is ERC-20 `balanceOf` (D29). Sleeve capital is first-class. User always gets the correct share delta for deposit/withdraw even when assets stay in or leave the sleeve (D9/D13). **Preview ignores rebalance** side-effects (D24).
7. **Fee oracle only:** Live `liquidReservePercentageOfVault(this)` fall-through; type default **20%**.
8. **Production-first tests:** Blocked deposit/amount-out with correct shares; free path deposit sleeve-then-deploy + amount-out via PM + tail-rebalance (incl. direct swaps); preview user-path parity; harness + one hook.
9. **Opacity:** Consumers keep using `IStandardExchange*` / multi-asset vault surfaces only.

### 2.1 Non-goals (v1)

1. Joining an **existing** outer unlock session as a co-settler (no “piggyback unlockCallback” protocol in v1).
2. Multi-PoolManager or cross-manager inventory.
3. Changing hook product law (hooks still buffer-last into SE; this PRD makes SE accept that call under lock).
4. Tick recast / recenter / JIT. Managed (non-imported) range is **full-range** (D30) and frozen at first create; rebalance is **liquid vs deployed** only.
5. ERC-4626 conversion of the multi-asset V4 SE.
6. Guaranteeing amount-out **while interaction-blocked** if free inventory of the requested token is insufficient (D18).
7. A new fee-oracle field named “locked buffer percentage” if `liquidReservePercentage` already models the same sleeve.
8. **Native V4 currency (`address(0)` / ETH)** as a sleeve or vault concern (D26) — out of scope.
9. Tracking **which** outer pool/hook/batch holds or routes through this vault (D25) — unmanageable; preventative sleeve only.

---

## 3. Design decisions (LOCKED for planning)

| ID | Decision | Choice |
|----|----------|--------|
| **D1** | Interaction gate | `canOpenPoolManagerUnlock() := !TransientStateLibrary.isUnlocked(poolManager)` (or equivalent `exttload` of `Lock.IS_UNLOCKED_SLOT`). |
| **D2** | When blocked | **Never** call `poolManager.unlock`. Deposits stay in local sleeve. Amount-out: **pay from sleeve only if free balance of the requested token(s) fully covers**; else **revert / cancel tx** (D18). |
| **D3** | When free — amount-out / direct swaps | **Always use PoolManager** for amount-out and for direct token0↔token1 swaps. Do **not** opportunistically pay amount-out from the sleeve when free, even if free balance fully covers. After the user op completes, **tail-rebalance** toward target (D10). (Free-path **deposits** are separate — see D27 sleeve-then-deploy.) |
| **D4** | Blocked deposit vs target | When blocked, **accept full deposit into sleeve regardless of target percentage**. Mint shares against **total** reserves (D9/D13). Rebalance on later free ops / public rebalance. |
| **D5** | Oracle knob | **Reuse** `liquidReservePercentageOfVault`. No parallel “locked buffer %” field. “Liquid” = free ERC-20 sleeve on the diamond. |
| **D6** | Units | WAD: `1e18 = 100%`. Same validation as existing fee oracle. |
| **D7** | Default sleeve size | **Type-level default for Uni V4 SE = `0.20e18` (20%).** Type fall-through so operators need not touch each vault. Vault override still allowed. |
| **D8** | Stored `0` = unset | Preserve oracle semantics: stored `0` means fall through, not “0% liquid.” |
| **D9** | Reserve + share SoT | `_totalVaultReserves()` = `positionAmounts + freeBalances`. **Shares represent all assets controlled by the vault** (sleeve + V4 position), never “position-only.” |
| **D10** | Rebalance placement | **LOCKED:** (1) After **every** free-path state-changing SE entry (zap-in after sleeve mint, zap-out after PM amount-out, **and direct pool token0↔token1 swaps**): complete user op first, then best-effort rebalance (deadband D22; no swaps D28). (2) Permissionless public `rebalanceLiquidReserve()` when free. (3) When blocked: public rebalance **reverts** with a clear error. |
| **D11** | Rebalance failure on free user op | Do not fail the whole user op solely because rebalance cannot perfect the target. User share/amount delta already finalized; rebalance best-effort after. |
| **D12** | Direct pool swaps (token0↔token1) | Require interaction-free. When blocked, revert interaction-blocked (not a sleeve route). When free: execute via PM, then **tail-rebalance** (D10). |
| **D13** | Share mint / burn deltas | User always receives the share (or burn) delta for **their** operation against total vault-controlled reserves — including when deposit stays in sleeve or amount-out is paid from sleeve. Placement free vs deployed does **not** change economic share math for that op. |
| **D14** | Fee / usage fee | Unchanged; sleeve is not a new fee domain. |
| **D15** | Imported PositionManager positions | **Same interaction gate.** Growing/shrinking imported liquidity via PM requires interaction-free. When **blocked**, position-import ops that need `unlock` **hard-revert** `PoolManagerInteractionBlocked` (or equivalent) — **no** partial free-only import semantics. |
| **D16** | Production-first testing | No mock vault/manager/oracle/PoolManager as SUT. |
| **D17** | Target shape | **Per-token:** `targetFree_i = total_i * liquidPct / 1e18` for token0 and token1. |
| **D18** | Blocked amount-out + wrong token | **Pay if sleeve free balance of the requested currency covers the full required amount; else revert (cancel tx).** No free-token swap while blocked. Document in NatSpec/comments (D21). Previews when blocked use the same branch. |
| **D19** | Compatibility scope / DoD | Vault is **not** concerned with *where* it is used as liquidity. Concern is **batch compatibility**: a vault op nested in an outer unlock must not need nested `unlock`. **DoD = generic unlock harness + one real buffer-hook integration.** Multi-hook matrix is follow-on, not merge-blocking. |
| **D20** | Live oracle reads | **Every** rebalance / target computation calls `feeOracle.liquidReservePercentageOfVault(address(this))` (or equivalent) **at call time**. No vault storage cache of the percentage. Fall-through in the oracle is how defaults and type updates propagate without updating individual vaults. |
| **D21** | Code documentation | Gate, blocked deposit, blocked amount-out, and rebalance entrypoints **must** carry NatSpec/comments stating: sleeve is for when PM interaction is blocked; cover → pay; short → revert; free path uses PM then rebalances. |
| **D22** | Rebalance deadband (dust) | **LOCKED product law** (§6.3.1): rebalance token `i` only if `\|free_i - targetFree_i\| > max(ABSOLUTE_FLOOR_i, targetFree_i * 0.05e18 / 1e18)` with `RELATIVE_TOL_WAD = 0.05e18` (5% of target free). Once triggered, rebalance **to target** (not to band edge). Within band: skip unlock. Off-target within deadband is **policy band**, not inconsistent accounting. Not fee-oracle configurable in v1. |
| **D23** | Route set (existing code) | Public SE surface is **single-token** in/out only: pool token↔pool token; single pool token → shares; shares → single pool token. Blocked amount-out rules apply **per requested `tokenOut` only**. |
| **D24** | Preview vs rebalance | **Preview ignores rebalance / sleeve-policy moves.** Preview quotes only the **user route** (swap / zap-in share mint / zap-out amount or shares) under the current free/blocked gate for that route. It does **not** simulate post-op deadband rebalance. Execution of the user path still mints/burns shares (or delivers amountOut) for vault-controlled totals (D9/D13). Preview == execution for the **user path**; rebalance may change free/deployed split afterward without changing the already-returned user amounts. |
| **D25** | No outer-context tracking | Vault does **not** record or special-case which outer pool, hook, or batch called it. Sleeve is a **preventative** compatibility measure only. Tracking holders/contexts would balloon scope. |
| **D26** | Native currency | **Out of scope.** No native ETH / `address(0)` Currency sleeve design. Follow existing package behavior for non-native ERC-20 pool currencies only. |
| **D27** | Free-path deposit order | **Sleeve-then-deploy-excess (LOCKED).** When interaction-free: (1) pull tokens into vault free balances; (2) mint shares against total reserves (user op complete); (3) tail-rebalance **deploys only** `free_i - targetFree_i` (when excess beyond deadband) into the V4 position. Do **not** use “fully deploy deposit into position then remove liquidity back to 20% free” as the primary free-deposit shape. Blocked path is the same (1)–(2) without step (3). |
| **D28** | Rebalance composition / no swaps | **No token0↔token1 swap as a rebalance tool.** Rebalance may only **add liquidity** (deploy excess free) or **remove liquidity** (refill free toward target) via PoolManager. If pool range / ratio prevents both tokens from hitting targetFree independently, apply **best-effort per token** without deliberate cross-token rebalance swaps. Incidental residual handling inside existing liquidity math is OK; do not add a “rebalance swap” route. |
| **D29** | Free inventory SoT / donations | **`free_i = IERC20(token_i).balanceOf(address(this))`** for pool currencies. Unsolicited transfers (donations/dust) **count** as free sleeve and therefore as total vault reserves (share-price donation surface — accepted; cover in adversarial notes). Do **not** maintain a separate internal free ledger that ignores `balanceOf` in v1. Never double-count PoolManager ERC-6909 claims as free unless the package already treats them as vault inventory. |
| **D30** | Managed range (non-imported) | **One** full-range position: `tickLower = minUsableTick(tickSpacing)`, `tickUpper = maxUsableTick(tickSpacing)`, salt = center salt (`bytes32(0)`). Wings are **not** created and must hold 0 liquidity. Ticks freeze at first create; no recast. Deployed capital stays in range for every tradable price. |
| **D31** | `widthMultiplier` | Remains on `PkgArgs` / `deployVault` (`>= 1`) for ABI compatibility. **Does not size ticks.** Allocation is 100% of deployable inventory to the full-range center. |

---

## 4. Interaction model

### 4.1 Normative gate

```solidity
/// @dev True iff this vault may safely call poolManager.unlock.
function canOpenPoolManagerUnlock() public view returns (bool) {
    return !TransientStateLibrary.isUnlocked(_poolManager());
}
```

| `isUnlocked(PM)` | Product state | Vault may call `unlock`? | Deposit / zap-in | Amount-out / zap-out | Direct pool swap |
|------------------|---------------|---------------------------|------------------|----------------------|------------------|
| `false` (idle) | Interaction-free | Yes | Sleeve credit + mint, then **deploy excess** via rebalance (D27) | **Always PM** (D3), then rebalance | PM then rebalance (D12) |
| `true` (in-session) | Interaction-blocked | **No** | Local sleeve only; mint; **no** rebalance (D4) | Free sleeve if covered; else revert (D18) | **Revert** interaction-blocked |

### 4.2 Why not “join” the outer unlock

Joining another locker’s session would require:

- knowing the outer unlocker,
- settling deltas under that identity,
- and a shared protocol for credit/debt attribution.

That is a larger architecture change and couples the SE to every possible outer unlocker. **v1 deliberately uses a free token sleeve** so the SE remains callable as a normal ERC-20 / SE endpoint from hooks without PoolManager collaboration.

### 4.3 Nested V4 topology (motivating diagram)

```text
Pool A (hook = Single SE Buffer CP)
  currencies: rawToken ↔ pairToken
  during unlock + buffer-last:
      pairToken → SE.exchangeIn  ──►  Uniswap V4 Standard Exchange
                                        pool B = (token0, token1) on SAME PoolManager
                                        needs unlock to modifyLiquidity on pool B
                                        WITHOUT sleeve: AlreadyUnlocked ✗
                                        WITH sleeve: credit free inventory + mint shares ✓
```

Works even when pool A and pool B differ; the singleton lock is global per Manager.

---

## 5. Fee oracle: liquid reserve percentage

### 5.1 Existing surface (already shipped)

```text
IVaultFeeOracleQuery:
  defaultLiquidReservePercentage()
  defaultLiquidReservePercentageOfTypeId(bytes4 vaultTypeId)
  liquidReservePercentageOfVault(address vault)
  liquidReservePercentageOfVaultAndFeeTo(address vault)

IVaultFeeOracleManager:
  setDefaultLiquidReservePercentage(uint256)
  setDefaultLiquidReservePercentageOfTypeId(bytes4, uint256)
  setLiquidReservePercentageOfVault(address, uint256)
```

**Resolution (already implemented):** vault override → type default (via usage fee type id / marker) → global default. Stored `0` = unset.

### 5.2 Semantics for Uni V4 SE (normative)

```text
liquidReservePercentage ∈ [0, 1e18]   // WAD; 0 stored = unset at that tier

// free_i from ERC-20 balanceOf (D29); deployed_i from position amounts
totalReserve0 = deployed0 + free0
totalReserve1 = deployed1 + free1

// LOCKED per-token targets (D17) — same WAD % on each currency; no numeraire FX:
targetFree_i = totalReserve_i * liquidReservePercentage / 1e18
// for i in {0,1}
```

**Rationale for per-token target (D17):** The vault is dual-currency. A single ETH-style numeraire is not free on a CL vault without introducing a price. **v1 locks per-token sleeve targets** using the same WAD percentage on each token’s total reserve.

**Rebalance vs composition (D28):** Rebalance does **not** swap token0↔token1 to force both targets. It only deploys excess free or removes liquidity toward targetFree per token (best-effort if range/ratio limits how much of one currency can move alone).

**Why 20% (D7):** Nested buffer hooks deposit **during** outer swaps. A thin sleeve (e.g. 5%) is easily exhausted by nested amount-out or leaves little free inventory for concurrent mid-batch deposits. **20%** is the product default headroom for “any outer pool that buffers into this vault.” Operators may set vault override higher for thin books / high nested flow.

### 5.3 Naming vs user language

User narrative: “locked vault buffer percentage.”  
Repo law: **`liquidReservePercentage`** (fraction **free / local**, not locked).

Document in NatSpec:

```text
// Uni V4 SE: fraction of each currency’s total reserve held as free ERC-20 sleeve
// so deposits can complete when PoolManager is already unlocked (nested batches).
// Deployed fraction ≈ 1e18 - liquidReservePercentage in steady state.
```

**Oracle work for this refactor:**

1. **No new oracle fields** expected.
2. Wire Uni V4 SE package **type id** so type-level default applies via fall-through.
3. **Set type default = `0.20e18` (20%)** for Uni V4 SE (D7).
4. Vault **always** queries `liquidReservePercentageOfVault(this)` on rebalance / target calc (**D20** — live read, no cache).
5. Tests: cascade vault → type → global; change type default mid-test and assert next rebalance sees new pct without per-vault write.
6. No ABI rename of liquid reserve APIs.

If product later insists on a separate knob name, open a PRD revision — do not ship two knobs with the same meaning.

---

## 6. Behavioral specification

### 6.1 Inventory accounting

**Before (today):**

```text
_totalVaultReserves() = positionAmounts only
// free ERC-20 on the vault is invisible to share math (dangerous if any residual exists)
```

**After (required):**

```text
// D29: free = raw ERC-20 balance on the diamond (includes donations/dust)
free0 = IERC20(token0).balanceOf(address(this))
free1 = IERC20(token1).balanceOf(address(this))
(deployed0, deployed1) = positionAmounts()   // V4 position only; do not double-count as free
_totalVaultReserves() = (deployed0 + free0, deployed1 + free1)
_syncVaultReserves() writes these totals into MultiAssetBasicVaultRepo
```

**Donation surface (accepted, D29):** Anyone may transfer token0/token1 to the vault without minting. That raises free balances and total reserves, diluting existing share price (standard vault donation risk). Tests/adversarial notes should acknowledge this; v1 does **not** ignore unsolicited balances via a separate free ledger.

Views for operators / tests (recommended public surface on marker or query facet):

| View | Meaning |
|------|---------|
| `canOpenPoolManagerUnlock()` | Gate |
| `localReserve(token)` / free balances | Sleeve inventory (`balanceOf`) |
| `deployedReserve()` / position amounts | CL inventory |
| `targetLiquidReservePercentage()` | Oracle effective WAD |
| `actualLiquidReservePercentage(token)` optional | free / total for that token |

### 6.2 Deposit / zap-in (share mint)

**Unified deposit shape (D4 + D27):** both free and blocked deposits **credit the sleeve and mint first**. Only the free path then rebalances.

```text
Pull tokens (existing secure transfer / pretransferred rules)
// Deposit capital is now in free ERC-20 balances on the diamond
Compute sharesOut from total reserves (free + deployed) via existing formulas
Mint sharesOut to recipient
Sync reserves (totals = free + deployed)

if canOpenPoolManagerUnlock():
    // LOCKED free-path order (D27 + D10): user op already complete above
    // Tail-rebalance deploys ONLY excess free above target (deadband D22)
    //   free_i > targetFree_i + deadband  →  deploy free_i - targetFree_i into position
    // Do NOT: fully deploy the deposit into the position then pull liquidity back to 20%
    Best-effort rebalance toward live oracle target (D10/D11/D20/D28)
else:
    // Interaction-blocked (D4)
    Do NOT unlock
    Do NOT rebalance
    // Temporary liquid % may exceed target until a later free op / public rebalance
```

**Invariants (both paths):**

1. Blocked path: **no** `unlock` call.
2. `sharesOut` uses **post-pull vs pre-pull total vault reserves** (free + deployed) — same economic mint whether capital stays free or is later deployed (D9/D13).
3. Free path may leave liquid % above target only within deadband after rebalance; blocked path may leave liquid % far above target.
4. `minSharesOut` / slippage checks apply to the **user share delta**, not to whether assets are free or deployed.
5. Free-path deposit does **not** require a user-facing PM swap for the mint itself; PM is used only inside rebalance (and only when deadband trips).

### 6.3 Rebalance (interaction-free only)

```text
// Always read live:
//   liquidPct = feeOracle.liquidReservePercentageOfVault(address(this))  // D20
// For each token i in {0,1}:
//   targetFree_i = total_i * liquidPct / 1e18
//   if free_i > targetFree_i beyond deadband: excess → add liquidity / deploy into position
//   if free_i < targetFree_i beyond deadband: need → remove liquidity into free
//
// D28: NO token0↔token1 swap as rebalance tooling.
// Best-effort if CL range/ratio cannot move only one currency to target.

Entry points (D10):
  1) Tail of every free-path state-changing SE op after user op completes:
     - zap-in (after sleeve mint — D27)
     - zap-out (after PM amount-out — D3)
     - direct pool token0↔token1 swaps
  2) Public permissionless rebalanceLiquidReserve() when canOpenPoolManagerUnlock()
```

**Gas:** single unlock per rebalance preferred when free.

### 6.3.1 Rebalance deadband / dust (D22) — **LOCKED**

**Status:** Product-locked. Implement exactly; change only via PRD revision.

**Goal:** Never leave **accounting** inconsistent (shares, free, deployed always reconciled). Do **not** spend gas chasing wei-level sleeve drift.

**Inconsistent vs off-target:**

| Concept | Meaning |
|---------|---------|
| **Accounting consistent** | Always: `total_i = free_i + deployed_i`; share mint/burn use totals; balances match. **Required always.** |
| **On-target sleeve** | `free_i ≈ targetFree_i` within deadband. **Best-effort within band**; small residual is OK and expected. |

**Normative deadband (per token `i`) — LOCKED formula:**

```text
liquidPct   = feeOracle.liquidReservePercentageOfVault(this)   // live (D20)
targetFree  = total_i * liquidPct / 1e18
deviation   = |free_i - targetFree|

// Rebalance token i only if:
deviation > max(ABSOLUTE_FLOOR_i, targetFree * RELATIVE_TOL_WAD / 1e18)

// If targetFree == 0: rebalance only if free_i > ABSOLUTE_FLOOR_i
```

**LOCKED constants (v1):**

| Constant | Value | Rationale |
|----------|-------|-----------|
| `RELATIVE_TOL_WAD` | **`0.05e18` (5% of target free)** | At 20% sleeve target, ignore drift until free is off by ~**1% of total inventory**. Absorbs swap residual / round dust; keeps nested batch headroom meaningful. |
| `ABSOLUTE_FLOOR_i` | **`10^max(0, decimals_i - 6)`** raw units (18-dec → `1e12` wei; 8-dec → `100`; 6-dec → `1` raw unit) | Stops thrash when totals are tiny or token is low-decimal. Hermetic 18-dec tests may hardcode `1e12` if decimals plumbing is awkward. |

Not fee-oracle configurable in v1 (oracle owns liquid % only).

**Worked example (18-dec, total = 100e18, liquidPct = 20%):**

```text
targetFree = 20e18
deadband   = max(1e12, 20e18 * 0.05) = 1e18   // 5% of target = 1 token
// free in [19e18, 21e18] → skip rebalance for this token
// free = 22e18 → rebalance TO target 20e18 (not merely to 21e18)
```

**LOCKED rules:**

1. After free-path user op: run rebalance helper; **skip** unlock work if **both** tokens within deadband.  
2. Public `rebalanceLiquidReserve`: if both within deadband, **return success without unlock** (idle success). If blocked, **revert** (D10).  
3. Once deadband **trips** for a token, rebalance that token **to `targetFree`** (one settle), not only to the band edge.  
4. Do not fail the user op solely because rebalance is skipped for dust or best-effort rebalance partially fails (D11).

### 6.4 Withdraw / zap-out / amount-out (normative — D3 + D18)

**Two branches:**

```text
// amountOut / zap-out / SE token-out routes:

if canOpenPoolManagerUnlock():
    // FREE path (D3): ALWAYS PoolManager — even if free[tokenOut] fully covers
    // Do NOT opportunistically pay from sleeve when free
    Use PoolManager (remove liquidity / swap) as today to satisfy amountOut
    Complete user op (share burn / transfers)
    Then best-effort rebalance toward live oracle target (may refill or trim sleeve)

else:
    // BLOCKED path (D18): sleeve only
    if free[tokenOut] >= required (and minAmountOut / slippage ok):
        pay fully from free sleeve
        complete share burn / SE accounting
        sync reserves
        // do NOT unlock; do NOT rebalance while blocked
    else:
        revert InsufficientLocalReserve(token, requested, available)
        // cancels the transaction — no partial under min
```

**Blocked amount-out rules (LOCKED):**

1. **Cover → pay** from free balance of the **requested token**.
2. **Short → revert** (cancel tx). No nested unlock; no silent under-delivery.
3. **Wrong-token sleeve:** if user needs token0 but free is only token1, **revert** (no swap while blocked). Document in comments (D21).
4. Previews when blocked must use the sleeve-only branch.

**Free amount-out rules (LOCKED — D3):**

1. **Always PM** when interaction-free, regardless of sleeve cover.
2. Then tail-rebalance (deadband).
3. Previews when free model the PM user path only (D24) — not a sleeve shortcut.

### 6.4.1 Routes are single-token only (D23 — from existing code)

**Verified against current package** (`UniswapV4StandardExchangeInTarget.exchangeIn`, `UniswapV4StandardExchangeOutTarget.exchangeOut`):

| Route | tokenIn | tokenOut |
|-------|---------|----------|
| Direct pool swap | token0 or token1 | the other pool token |
| Zap-in / mint shares | token0 **or** token1 | vault shares (`address(this)`) |
| Zap-out / redeem | vault shares | token0 **or** token1 |

There is **no** user route that burns shares and pays **both** currencies in one call. Internal zap-out may burn shares and remove liquidity / swap residual to deliver a **single** `tokenOut` when free.

**Blocked amount-out (D18) only checks free balance of the requested `tokenOut`.** Dual-leg pro-rata burn is **out of scope / N/A** unless a new route is added later (would need a PRD revision).

### 6.5 Direct token0 ↔ token1 swaps

Require interaction-free (D12). When free: existing PM swap path, then **tail-rebalance** (D10). When blocked: execution reverts (not a sleeve route). Previews quote the swap only (D24).

### 6.6 Preview / execution parity (D24) — LOCKED

**Shares and amounts for the user op:**

- Mint/burn share math always uses **total vault-controlled reserves** (free + deployed).
- Deposit into sleeve and amount-out from sleeve still give the user the **correct share delta / amountOut** for that contribution or claim — as if those assets count fully toward vault capital (because they do).

**Previews ignore rebalance:**

| What preview models | What preview does **not** model |
|---------------------|----------------------------------|
| User route under current gate (free PM path vs blocked sleeve path) | Post-op deadband rebalance free↔deployed moves |
| Share mint/burn from total reserves for that deposit/withdraw | Oracle liquid % policy moves |
| Direct swap quote when free | Tail-rebalance after swap |

| Route | When free | When blocked |
|-------|-----------|--------------|
| Zap-in / deposit | Preview share mint from total reserves for amountIn; exec mints same against free credit (D27); rebalance deploy **not** in preview | Preview share mint from total reserves; assets stay free (no deploy in preview or exec) |
| Zap-out / amount-out | Preview **PM** path user amounts (not sleeve shortcut); exec PM then rebalance | Preview sleeve-only cover/short; exec pays free or reverts |
| Direct pool swap | Preview swap only | N/A (reverts) |

**Rule:** Preview == execution for the **user-returned** amounts (sharesOut, amountOut, amountIn). Free/deployed split after rebalance is allowed to differ from a hypothetical “preview after rebalance” view.

Gate can change between eth_call and send (same class of race as other lock-sensitive systems).

### 6.7 First deposit / empty vault

| State | Free | Blocked |
|-------|------|---------|
| No position, zero supply | Mint shares against free (same first-mint formula as blocked); then rebalance **creates/seeds position** by deploying excess free above target (D27). If target is 100% liquid, position may remain uncreated. | Mint shares 1:1 (or existing first-mint formula) against free balances only; position remains uncreated until a later free op / public rebalance |

First-mint formulas must not divide by empty deployed-only reserves when free balances exist (D9).

---

## 7. Errors and events (normative intent)

**Errors (names illustrative — align with existing `UniswapV4Exchange_*` style):**

| Error | When |
|-------|------|
| `PoolManagerInteractionBlocked()` | Direct swap or path that **requires** unlock while blocked |
| `InsufficientLocalReserve(token, requested, available)` | Withdraw/zap-out blocked and free inventory short |
| Existing deadline / slippage / zero amount / disabled vault | Unchanged |

**Events (optional but recommended):**

| Event | When |
|-------|------|
| `LiquidReserveRebalanced(free0, free1, deployed0, deployed1, liquidPct)` | After successful rebalance |
| `LocalDepositWhileBlocked(token, amount, sharesOut)` | Optional telemetry for nested-hook path |

---

## 8. Surfaces and file impact (expected)

### 8.1 In package (`contracts/protocols/dexes/uniswap/v4/`)

| Area | Change |
|------|--------|
| `UniswapV4StandardExchangeCommon.sol` | Gate helper; `_totalVaultReserves`; rebalance helpers; free vs deployed split |
| `UniswapV4StandardExchangeInBase.sol` / InTarget / delegate | Branch zap-in deposit on gate; rebalance when free |
| `UniswapV4StandardExchangeOutTarget.sol` | Branch withdraw/zap-out; liquid-capped blocked path |
| Position import path | Same gate; blocked import that needs unlock → **hard-revert** interaction-blocked (D15) |
| Marker / query facet (if any) | Expose views §6.1 |
| DFPkg / FactoryService | Type id / fee type registration for liquid % type default if missing |
| `UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md` | Progress note pointing at this PRD |

### 8.2 Fee oracle

| Area | Change |
|------|--------|
| Repo / facets / interfaces | **No new fields expected** |
| Deploy / test setup | Set type default for Uni V4 SE; assert cascade |
| Unit tests | Existing liquid reserve tests remain; add type id row for V4 SE if useful |

### 8.3 Consumers

Hooks and DETFs **should not** need ABI changes. Nested-hook integration tests **must** be added so buffer-last into V4 SE succeeds mid-unlock.

---

## 9. Security and economic considerations

| Risk | Mitigation |
|------|------------|
| Nested unlock grief / DoS of SE | Local sleeve path when blocked (primary goal) |
| Sleeve drained while position remains | Blocked withdraw caps at free; free path can refill via rebalance |
| Share inflation if free not counted | D9 total reserves mandatory |
| Share dilution if free counted twice | Free = ERC-20 balance; deployed from position state only — never add PM ERC-6909 claims unless product already does |
| Share-price donation via free transfers | Accepted (D29): unsolicited token0/token1 raise free + totals. Document; adversarial note; no internal free ledger in v1 |
| Permanent under-deployment if always blocked | In steady state outer unlock ends; subsequent free ops rebalance. No keeper required if user traffic exists; optional public rebalance |
| Malicious token reentrancy | Keep existing `nonReentrant` / SE locks; adversarial suite for nested reenter during blocked deposit |
| Sandwich / MEV on rebalance | Rebalance is add/remove liquidity only (D28), best-effort (D11); no rebalance swap route to sandwich |
| Oracle set to 0% liquid via fall-through | Non-zero type default for V4 SE; document 0=unset; avoid “all deployed” for nested product instances |
| Oracle set to 100% liquid | Allowed: vault becomes fully free inventory (still SE shares); no V4 deploy until % reduced |

---

## 10. Testing requirements (DoD for implementation plan)

Production-first: `CraneTest` → `IndexedexTest` → `TestBase_UniswapV4StandardExchange` (extend). Real PoolManager (Crane port), real fee oracle, real DFPkg path. No mock vault/manager/oracle/PoolManager as SUT.

### 10.1 Unit / hermetic matrix

| ID | Case | Expect |
|----|------|--------|
| **T1** | Idle deposit / zap-in | Credits sleeve + mints shares; **then** rebalance **deploys excess only** (D27); free ≈ **20%** within deadband |
| **T1b** | Idle deposit does not fully-deploy-then-pull | After free zap-in, position growth equals excess above target, not “100% deploy then remove 20%” as primary shape |
| **T2** | Force in-session then SE deposit | Deposit to sleeve; **no** nested unlock; **sharesOut** matches total-reserve mint (not “zero because not in V4”) |
| **T3** | After T2, public rebalance when idle | Excess free deploys; free → **~20%** |
| **T4** | Blocked amount-out **≤ free[token]** | Pay from sleeve; share burn correct for total reserves |
| **T5** | Blocked amount-out **> free[token]** | Revert `InsufficientLocalReserve` |
| **T4b** | Blocked amount-out wrong token only free | Revert |
| **T4c** | Free amount-out with large sleeve | **Always PM path** even if sleeve covers; then rebalance |
| **T4d** | Donation of token0/token1 without mint | Free + total reserves rise; share price dilutes (D29) |
| **T4e** | Position import while blocked | **Reverts** interaction-blocked (D15) |
| **T4f** | Rebalance does not swap token0↔token1 | Deploy/remove only; no rebalance swap route (D28) |
| **T6** | Blocked direct pool swap | Revert interaction-blocked |
| **T7** | Idle direct swap | PM success; **then** tail-rebalance (D10/D12) |
| **T8** | Preview == exec user path: free zap-in, blocked zap-in, blocked amount-out covered | Shares/amounts match; **preview does not require post-rebalance free==target** |
| **T8b** | Free zap-in when rebalance would move inventory | preview sharesOut == exec sharesOut; free/deployed may differ after rebalance |
| **T9** | Reserves = free + deployed | Views match |
| **T10** | Oracle cascade | Vault → type → global |
| **T11** | Fresh V4 SE type default | Effective **`0.20e18`** without vault override |
| **T11b** | Change type default mid-test; call rebalance | New pct applied (**live read D20**) |
| **T12** | First mint while blocked | Free only; later free rebalance creates position |
| **T13** | Reentrancy adversarial on blocked deposit | Nested reenter fails safely |
| **T14** | Public rebalance while blocked | **Reverts** clear error; no unlock |
| **T15** | Rebalance within deadband | No unlock / no deploy; free may stay slightly off 20% |
| **T16** | Rebalance outside deadband | Moves toward target; free within deadband after |

### 10.2 Nested hook integration (required)

| ID | Case | Expect |
|----|------|--------|
| **H1** | Generic harness: call SE deposit inside outer `unlockCallback` | Succeeds via sleeve; no `AlreadyUnlocked` |
| **H2** | **One** real buffer-hook path (e.g. Single SE Buffer CP) with SE = this V4 vault, mid-**swap** buffer | Outer unlock completes; SE shares ↑ |
| **H3** | Same family mid-session amount-out if applicable | Sleeve cover → pay; short → revert; no nested unlock |
| **H4** | Type default 20% | `liquidReservePercentageOfVault(v4Se) == 0.20e18` without vault override |

Multi-hook families are **not** merge-blocking (D19).

If full hook deploy is heavy, a **minimal unlock harness** that calls SE.exchangeIn inside `unlockCallback` is acceptable for T2/H1-equivalent **in addition to** at least one real hook path when feasible.

### 10.3 Explicitly out of test scope (v1)

1. Multi-manager.
2. Cross-hook economic optimization of liquid %.
3. Fork matrix beyond existing V4 SE / hook fork smoke unless implementation plan expands.

---

## 11. Implementation plan

**Normative coding plan (phases, files, algorithms, test DoD):**

[`UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md)

Phase outline (detail lives in that doc):

1. **Phase 0 — Spec freeze:** D1–D29 locked; plan authored.
2. **Phase 1 — Accounting:** Free (`balanceOf`) + deployed = share SoT; donation D29; T9, T4d.
3. **Phase 2 — Gate + blocked deposit/amount-out + import:** T2, T4–T5, T4b, T12, T4e; NatSpec D21.
4. **Phase 3 — Free sleeve-then-deploy + rebalance + free out/swap:** T1, T1b, T3, T4c, T4f, T7, T14–T16.
5. **Phase 4 — Preview user-path parity:** T8, T8b.
6. **Phase 5 — Oracle live cascade / type default 20%:** T10, T11, T11b.
7. **Phase 6 — Batch compatibility DoD:** H1 + H2 (+ H3); T13.
8. **Phase 7 — Docs / cleanup.**

---

## 12. Open questions

### Locked (product Q&A)

| ID | Resolution |
|----|------------|
| **Q1** | Default liquid % = **20%** type default |
| **Q-amount-out blocked** | Cover requested token free → pay; else revert; document in code |
| **Q-amount-out free** | **Use PoolManager** when free — not sleeve-first (D3) |
| **Q-rebalance order** | User op first, then rebalance when free (D10) |
| **Q-public rebalance** | **Yes**, permissionless (D10) |
| **Q-rebalance-blocked** | **Revert** with clear error if PM interaction blocked (D10) |
| **Q-oracle** | Always live `liquidReservePercentageOfVault(this)`; fall-through for defaults (D20) |
| **Q-DoD** | Generic unlock harness + **one** real buffer hook (D19) |
| **Q-routes** | **Single-token in/out only** per existing vault code (D23); dual-leg pro-rata N/A |
| **Q-dust / deadband** | **LOCKED (D22 / §6.3.1):** 5% of target free + absolute floor; rebalance **to target** when tripped |
| **Q-preview** | **LOCKED (D24):** preview ignores rebalance; user share/amount deltas use total vault-controlled assets |
| **Q-tail-rebalance** | **LOCKED (D10/D12):** all free-path SE state-changers including direct swaps |
| **Q-outer-tracking** | **LOCKED (D25):** no tracking which pool/hook holds the vault |
| **Q-native** | **LOCKED (D26):** native currency out of scope |
| **Q-free-deposit-order** | **LOCKED (D27):** sleeve-then-deploy-excess when free; not fully-deploy-then-pull |
| **Q-rebalance-swaps** | **LOCKED (D28):** rebalance add/remove liquidity only; no token0↔token1 rebalance swap |
| **Q-free-sot-donations** | **LOCKED (D29):** free = `balanceOf`; donations count / dilutes share price |
| **Q-import-blocked** | **LOCKED (D15):** position import needing unlock hard-reverts when blocked |

### Still open (low priority)

None blocking Phase 0. Implementation plan may still pick concrete error names and absolute-floor helper details within D22.

---

## 13. Acceptance criteria (product)

This refactor is **done** when:

1. Nested vault call during outer unlock does **not** nested-`unlock` on deposit; sleeve accepts inventory; **shares still mint against total vault assets**.
2. When interaction-blocked, amount-out pays from **requested-token free sleeve** if covered; else reverts; share burn still correct for totals.
3. When free: **deposits** sleeve-then-deploy-excess (D27); **amount-out / direct swaps** always via PM (D3/D12); user op completes **before** deadband rebalance.
4. Rebalance is add/remove only (D28); permissionless when free; live oracle **20%** type default; blocked rebalance reverts; blocked position import reverts.
5. Free inventory SoT is `balanceOf` (donations count, D29).
6. Previews ignore rebalance; preview == exec for **user-returned** amounts.
7. No outer-context tracking; no native-currency scope creep.
8. DoD: generic harness + one real hook path; §10 matrix green.

---

## 14. Summary (for stakeholders)

**Problem:** Uniswap V4’s singleton lock prevents nested `unlock`. A vault op inside a batch can fail if it tries to open PoolManager itself.

**Solution:** A **local liquid sleeve** (oracle `liquidReservePercentage`, default **20%**) so the vault stays batch-compatible without tracking who called it. Shares always represent **all assets the vault controls** (sleeve via `balanceOf` + V4 position). When blocked: deposit and amount-out use the sleeve (cover or revert). When free: deposits **credit sleeve then deploy excess**; amount-out and direct swaps **always use PoolManager**; then deadband rebalance (**add/remove only**, no rebalance swaps). Previews ignore rebalance side-effects.

**Compatibility framing:** Preventative measure only — not a registry of outer pools, hooks, or native special cases.

---

## Changelog

| Date | Note |
|------|------|
| 2026-08-05 | v1.0 draft: local buffer, lock-safe nested deposits, reuse `liquidReservePercentage` |
| 2026-08-05 | v1.1: default sleeve **20%**; nested mid-swap first-class; blocked amount-out from sleeve |
| 2026-08-05 | v1.2: free path **PM not sleeve-first** (D3); user-op-then-rebalance + **permissionless rebalance** (D10); **live oracle reads** (D20); DoD = harness + one hook (D19); blocked cover/revert + NatSpec (D18/D21) |
| 2026-08-05 | v1.3: confirm **single-token routes only** from existing code (D23); close mistaken dual-leg burn question; blocked public rebalance **reverts** (D10); rebalance deadband drafted (D22) |
| 2026-08-05 | v1.4: **lock deadband product law** (D22 / §6.3.1): 5% of target free + absolute floor; rebalance **to target** when tripped; not oracle-configurable in v1 |
| 2026-08-05 | v1.5: **preview ignores rebalance** (D24); shares = all vault-controlled assets incl. sleeve (D9/D13); tail-rebalance after **all** free SE ops incl. direct swaps (D10/D12); **no outer tracking** (D25); **native out of scope** (D26) |
| 2026-08-05 | v1.6: **free deposit = sleeve-then-deploy-excess** (D27); free amount-out **always PM** even if sleeve covers (D3 clarified); rebalance **no swaps** (D28); free SoT = `balanceOf` + **donations count** (D29); blocked **position import hard-reverts** (D15); clarity pass on goals/gate table/§6 |
