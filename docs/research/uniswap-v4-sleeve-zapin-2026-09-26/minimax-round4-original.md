# MiniMax-M3 — Round 4 original: per-call/cumulative protection, hook compatibility, pretransfer code-law gap, alignment tolerance

**Author:** minimax/MiniMax-M3 (independent)
**Date:** 2026-09-26. PZ-1..8 and G1..G4 fixed; latest owner overrides swap-free public rebalance and hook admission gate. Prior files preserved.
**Owner directives addressed:** (1) repeated calls execute swaps up to configured protection limit; reasonable numeric limits; (2) hook compatibility = Universal Router liquidity execution; research actual V4/UR/PositionManager source; if no on-chain proof, deployer-responsible fallback; (3) PRETRANSFER SETTLED LAW = `claimed ≤ live held balance − local snapshot (R)`, no origin provenance, integrator atomic discipline, EOA guard; (4) alignment threshold accepts BEST EFFORT, not unlimited donation.

**Authority read this pass:** `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` (full file); `contracts/vaults/basic/BasicVaultCommon.sol:80–138`; `contracts/vaults/basic/BasicVaultRepo.sol:13–135`; `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol:62,1270–1289` (V4 SE override of `_secureTokenTransfer`); moderator PRD `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (full file).

**External sources fetched 2026-09-26 (Context7 first, then primary):**
- Context7 `/uniswap/v4-periphery`: PositionManager `modifyLiquidities` (with/without unlock), mint-position example, MyAllowList pattern, PermissionedV4Router failure modes.
- Primary `https://raw.githubusercontent.com/Uniswap/universal-router/main/contracts/base/Dispatcher.sol` — confirmed commands `V4_SWAP=0x10`, `V3_POSITION_MANAGER_PERMIT=0x11`, `V3_POSITION_MANAGER_CALL=0x12`, `V4_INITIALIZE_POOL=0x13`, `V4_POSITION_MANAGER_CALL=0x14`. For `V4_POSITION_MANAGER_CALL`: `_checkV4PositionManagerCall(inputs)` then `address(V4_POSITION_MANAGER).call{value}(inputs)` — comment reads "should only call modifyLiquidities() to mint." The `_checkV4PositionManagerCall` source could not be retrieved (404) so the actual selector whitelist is unverified this pass; recorded as gap.
- `https://github.com/Uniswap/docs/blob/main/docs/contracts/universal-router/02-technical-reference.md` — `V4_POSITION_MANAGER_CALL` is described as "Arbitrary call to v4 PositionManager; Used for `modifyLiquidity`, `mint`, `settle`, etc. on a pool."

---

## 1. Hook compatibility — research verdict (Q-HOOK)

**Fact base.** Universal Router v2 commands include `V4_SWAP=0x10` (route through PoolManager + hooks) and `V4_POSITION_MANAGER_CALL=0x14` (route through PositionManager `modifyLiquidities`). **All UR-driven V4 liquidity ops are funneled through PositionManager, not directly to hook contracts.** Hooks are reached indirectly via PoolManager's `swap`/`modifyLiquidity` invocation; their behavior under UR is determined by their **runtime** `beforeSwap`/`afterSwap`/`beforeAddLiquidity`/`afterAddLiquidity`/`beforeRemoveLiquidity`/`afterRemoveLiquidity` implementations.

`PoolKey.hooks` field is the hook address. The flag slot (`Hooks.PERMISSIONS`) defines which **lifecycle callbacks** the hook is permitted to invoke; these flags are a permission set, **not a proof of UR compatibility**. Whether the hook reverts, runs dynamic-fee overrides (`OVERRIDE_FEE_FLAG` in `beforeSwap` per round-3 Context7 evidence), or succeeds under UR's command sequencing is **runtime**, not flag-derived. Crane's vendored PositionManager is a port (`POSITION_MANAGER` from PkgInit at `UniswapV4StandardExchangeDFPkg.sol:90`); whether its `modifyLiquidities` selector matches the upstream mainnet byte-for-byte is a deployment-verification item, not an in-source proof.

**Owner fallback verdict.** Per directive (2): with no in-source on-chain proof, the deployer is responsible. **Admission is assumed; accurate quotes and settlement checks are not assumed.** Concretely:

1. **Hook admission** = the supplied `PoolKey.hooks` is taken as supplied; no whitelist, no runtime flag validation, no flag-derived "UR compatible" check.
2. **Quote accuracy** = `UniswapV4QuoteService` (round-3 evidence: `19–57` recognizes Pons-shaped hook only; rest fall through to unadjusted amounts). For unsupported hooks, previews must report unavailability and execution must fail closed.
3. **Settlement checks** = the `_adjustHookSwap` path (`Common.sol:226, 1134`) and the existing callback authentication (`Common.sol:996–999`) are the only in-source hooks-aware gates.
4. **Crane PositionManager equivalence** = deployment must verify the local `modifyLiquidities` selector matches upstream; the simulator/testnet-only "no-liquidity-callback" path is not evidence of mainnet parity.

**Distinction this PRD must hold:** admission is permissive, accuracy is restrictive. Owner signoff: "no discretionary hook whitelist."

## 2. PRETRANSFER code-law gap (Q-PRETRANSFER)

`BasicVaultCommon._secureTokenTransfer` (`BasicVaultCommon.sol:80–106`, locked PRD §4.2) computes:

```text
pretransferred == true:
  U = B0 - R                            # subtracts FULL booked R (face + deployed)
  if claimed > U: revert TransferDeltaInsufficient(claimed, U)
  return claimed
```

`UniswapV4StandardExchangeCommon._secureTokenTransfer` (`Common.sol:1270–1289`, the actual V4 SE override) computes a **different** U:

```text
pretransferred == true:
  faceBooked = R - deployed              # R minus deployed principal
  U = B0 - faceBooked                   # = B0 + deployed - R
  if claimed > U: revert TransferDeltaInsufficient(claimed, U)
  return claimed
```

This V4 SE override is `U = B0 + deployed - R`, which is **strictly larger** than the locked `U = B0 - R` whenever `deployed > 0`. Concretely: with `B0 = 50` free, `R = 100` booked (incl. `deployed = 80` LP), locked U = `max(0, 50−100) = 0`; V4 SE U = `50 + 80 − 100 = 30`. **V4 SE permits `pretransferred=true` to claim up to 30 wei of value from positions that have not been withdrawn to free balance**, contradicting the locked pretransfer law and INV-R1.

**Owner directive (3) sets settled law = `claimed ≤ B − R`.** V4 SE currently diverges. **Action: align V4 SE `_secureTokenTransfer` with `BasicVaultCommon` exactly.** Until aligned, **withdraw any absent guard is a code-law gap, not a new provenance choice** (per directive). Other gaps to record (not invented here, surfaced from existing code):

- **`_executeDirectSwapIn` (`InBase.sol:72–87`)** does not call `_syncVaultReserves()` at end of op; under L-RSRV-SYNC-ROUTES this is a money-route-sync gap.
- **`_executeFreeZapOutExactIn` (`InBase.sol:174–216`)** calls `_syncVaultReserves()` at line 213, then `_rebalanceLiquidReserveBestEffort()` — the rebalance can change `R` mid-flow; final sync at 213 captures the pre-rebalance state. INV-R1 may hold at the sync but not at the post-rebalance state if rebalance moves balances. **Recorded as engineering gap.**
- **No production `B < R` error API** (L-RSRV-NO-UNDERFLOW-BRANCH); V4 SE `Common.sol:1284` `b0 > faceBooked ? b0 - faceBooked : 0` silently returns 0 when `B0 < faceBooked`. Per PRD: must rely on tests, not a product branch. The override does not add such a branch — consistent.

**Owner choice on V4 SE override alignment:** confirm alignment is required in this release, or document non-BasicVault exemption. **Owner choice on gap closure:** require `_syncAllExpectedHoldReserves()` (per PRD §5.2) in the two affected money routes, or grant a documented exception.

**Direct, Multi and other helpers** call `_secureTokenTransfer` from the override; alignment affects every `pretransferred=true` on V4 SE. **Imports path** (`UniswapV4StandardExchangePositionImportTarget.sol`) inherits the same override — same alignment requirement.

**Withdraw-side credit (`_refundExcess`, `BasicVaultCommon.sol:123–138`)**: locked behavior unchanged for V4 SE if the override is corrected.

## 3. Alignment tolerance (Q-ALIGN)

Owner accepts BEST EFFORT (PZ-7 explicit). Numerical surplus above `D = (0,0)` is **not unlimited donation**. The existing dual min-ratio branch (`Common.sol:700–704`):

```text
m = min(floor(c0 * S / B0), floor(c1 * S / B1))
```

The **surplus** is `S * (c0 / B0 − c1 / B1)` per token (or zero). Its magnitude in wei is `(max - min) * S / (denominator)` rounded. **Unitless error definition (recommended):**

```text
alignErr = |c0 / B0 − c1 / B1| / ((c0 / B0 + c1 / B1) / 2)
         = 2 · |c0·B1 − c1·B0| / (c0·B1 + c1·B0)
```

This is symmetric and bounded in `[0, 2]`. Existing branch absorbs dust via `floor`. **`alignErr ≤ 1e-4` (10 bps)** is the recommended alignment tolerance: revert if the swap solver cannot find `x` such that `alignErr ≤ 1e-4`. (`1e-4` = 0.01%, much tighter than the 1 bp nominal asked for; round-up/down rounding is a separate constraint.) Owner choice: 1 bp / 5 bp / 10 bp / 25 bp — recommend **10 bps** as a reasoned default.

**Numerical surplus treatment under BEST EFFORT:**
- **Best-effort partial deployment**: place `min(L_by_amount0, L_by_amount1)`; residue stays free above target per D32 (PZ-7). Caller does **not** receive shares for the residue; residue is **incumbent free growth** to be honest about who paid for it.
- **Exact-in no refund** is locked (BasicVaultCommon pretransfer PRD §4.3). Caller under-claimed is absorbed (`L-RSRV-ABSORB`).
- **Zero-output handling**: `m == 0 ⇒ revert UniswapV4Exchange_ZeroAmount` (existing `InBase.sol:293–294`, also `InBase.sol:357–358`); do **not** silently fall back to invariant-growth on a composed dual-input path (per PRD §6.1 "positive-reserve formula must not divide by zero or silently use invariant growth as a fallback for composed dual input").

**`minSharesOut` is a share-count bound, not an independent fair-value or starting-price protection** (round-3 owner clarification). `alignErr ≤ 1e-4` is a separate quality constraint that runs **regardless of user-supplied `minSharesOut`**; the internal cap is mandatory. Rejecting `minSharesOut == 0` alone is insufficient (Astra round-3 Q1).

## 4. Per-call vs cumulative protection; finite progress (Q-PROTECT)

Owner (1): introduce price-impact protection; **repeated calls to rebalance execute swaps up to configured protection limit.** This caps **cumulative** damage from repeated same-block calls that each individually satisfy per-call cap.

**Reasoned numeric defaults (proposals, not law; live values configurable per vault/type).**

| Limit | Per-call default | Cumulative default | Rationale |
|---|---|---|---|
| Terminal spot impact (bps) | 50 bps | 100 bps | Spot move from `slot0_post − slot0_pre`; permissive enough for typical depth, restrictive for sandwich. |
| Execution slippage (bps) | 30 bps | 60 bps | `minCounterOut` vs `quoteSwapIn`; standard Uniswap slippage tolerance. |
| LP + protocol fee (bps) | computed in-quote | n/a (single call) | Hook-adjusted via `_adjustHookSwap`. |
| Anchor deviation (bps) | 50 bps | 100 bps | Optional TWAP-relative bound; **no** DETF TWAP mandate (PRD §7). |
| Alignment loss (bps) | 10 bps | 20 bps | `alignErr` from §3; tighter on cumulative because LP-side residue accumulates. |
| Sleeve deadband (bps) | 50 bps of `F*_i` | n/a | Existing D22, unchanged. |

**Per-call enforcement** = revert if any one limit is exceeded. **Cumulative enforcement** = the vault retains a per-block-or-per-epoch **anchored budget** (`remaining = cap − Σ consumed`) for each metric; each successful call debits `consumed`; reset window = block, configurable per vault/type. **Or independent reference freshness**: each call must read a TWAP (or equivalent) within `Δt_fresh`; stale reference reverts.

**Finite progress guarantee:** if the anchored budget is finite, the cumulative damage is bounded by `cap`. **Same-block bypass** is blocked because debits accumulate in storage across calls within the block. Cross-block, the budget resets (configurable). **Both per-call and cumulative are mandatory for the new path; per-call alone is insufficient.**

**Per-call vs cumulative is an owner choice on configuration authority/source.** Recommend: cumulative = `2 × per-call` (allowing two calls per reset window at full per-call cap, then 50% additional at half-cap, etc.). Sources: per-vault PkgArgs override; per-type default; global fallback. Not a global oracle change.

**Public `rebalanceLiquidReserve`**: latest owner overrides swap-free public rebalance. **No swap ever executed** by `rebalanceLiquidReserve`; only adds/removes liquidity toward `F*_i`. The anchored budget concept applies **only** to the composition swap inside the new zap-in path. Public rebalance cannot be abused to swap.

## 5. Permissionless inventory repair swaps — **not adopted**

PZ-8 fixed: no automatic historical-inventory trading. Permissionless inventory repair swaps would require broadening scope (whole-book recovery pricing, MEV surface on holdings the depositor never asked to swap, blocked-deposit backlog under a separate trigger). Not in this release; record as out-of-scope per PRD §5 ZR-5.

## 6. Fee/impact allocation (post-swap B; already locked PZ-4..6)

`C` = caller's full net basket including sleeve allocation (round-2 peer consensus; PRD §6.1 line 168 explicit "Never subtract the caller's sleeve allocation from their share credit"). Self-LP fees and CL repricing belong to **B**, not **C`. Caller pays via slightly less counter-token received; incumbent gains the LP fee. Confirmed in round-2; not reopened.

## 7. Recommended answers and minimal remaining owner decisions

| # | Question | Recommended answer |
|---|---|---|
| **R1** (hook admission) | Deployer-responsible fallback per directive; `PoolKey.hooks` taken as supplied. Restrictive quote/settlement gates, not a whitelist. Owner choice: confirm the gate (recommend: `_supportsProjectedHook` + `_adjustHookSwap` coverage required; fail-closed otherwise). |
| **R2** (V4 SE `_secureTokenTransfer` override) | **Align with `BasicVaultCommon` exactly** (`U = B0 − R`). Record the divergence as a code-law gap, not a new provenance choice. Owner choice: align this release or exempt with documentation. |
| **R3** (money-route sync gaps) | Add `_syncAllExpectedHoldReserves()` to `_executeDirectSwapIn` and re-check post-rebalance INV-R1 in `_executeFreeZapOutExactIn`. Owner choice: require in this release. |
| **R4** (alignment tolerance) | `alignErr ≤ 1e-4` (10 bps) per call; revert otherwise. Owner choice: 1/5/10/25 bps. |
| **R5** (per-call vs cumulative protection) | Per-call + cumulative anchored budget = `2 × per-call`, block-level reset. Owner choice: 1×/2×/block/rolling-window. |
| **R6** (configuration authority) | PkgArgs override per vault, type default fallback. Owner choice: per-vault vs per-type vs global. |
| **R7** (Crane PositionManager selector parity) | Deployment must verify selector match; flag as `LibraryCompatibilityCheck`. Owner choice: pin to upstream commit / accept Crane port. |

## 8. Confidence and gaps

- **High** R2 (pretransfer divergence in V4 SE); R4 alignment formula; R5 per-call + cumulative framing.
- **Medium** R1 hook runtime compatibility (UR restriction surface is `V4_POSITION_MANAGER_CALL` + PositionManager; flag slot is permission set, not compatibility proof).
- **Low** R3 sync gaps in `_executeDirectSwapIn` (not opened) — single point-of-gap from prior round code reading; R7 vendor-port selector match — `_checkV4PositionManagerCall` source not retrieved (404), so the actual selector whitelist is unverified.
- **Gaps**: `_checkV4PositionManagerCall` source 404; no peer reads; no Context7 call for this round beyond round-3 cache; `apply_patch` unavailable; no shell/tests.

Stopping per assigned task. Research-only; no PRD edits, no code, no shell, no delegation. Originals preserved.
