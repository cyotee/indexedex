# MiniMax-M3 — Round 4 cross-review

**Author:** minimax/MiniMax-M3 (independent) — round 4 cross-review
**Date:** 2026-09-26
**Originals preserved:** all prior `*-original.md`, `*-cross-review.md`, `*-round2-*`, `*-round3-*` in `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/`.
**Peers reviewed (verbatim, untrusted):** `astra-round4-original.md`, `grok-round4-original.md`, `kimi-round4-original.md`. No cross-review artifacts read.
**Authority re-read this pass:** `BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` §1.1 / §4.2–4.9 (locked); `BasicVaultCommon.sol:80–138`; `Common.sol:1270–1289` (V4 SE override); moderator PRD `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` §5/§6/§7/§9; primary URLs (all accessed 2026-09-26/27 by peers): `https://raw.githubusercontent.com/Uniswap/universal-router/main/contracts/base/Dispatcher.sol`, `.../modules/V3ToV4Migrator.sol`, `.../v4-periphery/main/src/PositionManager.sol`, `.../v4-core/main/src/libraries/Hooks.sol`. Context7 `/uniswap/docs` and `/uniswap/v4-periphery` consulted first.

PZ-1..8 + G1..G4 fixed; latest owner overrides swap-free public rebalance (now: bounded permissionless rebalance swaps allowed) and hook admission gate (deployer-responsible fallback). All three peers **withdraw** round-3 pretransfer provenance / nonce / measured-pull objections; settled law applies.

---

## A. Substantive corrections to my round-4 original

| My claim | Correction | Source |
|---|---|---|
| **"1e-4 (10 bps)"** | **Numeric error.** 1e-4 = 1 bp = 0.01%. The phrase "much tighter than 1 bp nominal" was incoherent. Correct default: **1 bp = 1e-4 = 0.0001**. | prompt sanity check; Grok/Kimi/Astra all state 1 bp |
| **"≥2 × pool LP fee slippage"** | **Wrong.** A fee-inclusive quote already prices the LP fee; subtracting it twice double-counts. The slippage check is **10 bps vs fee-inclusive quote**, not ≥ 2 × fee. | prompt; Grok "Fees excluded: a 30 bps pool fee is not 30 bps of impact"; Kimi retracted via prompt |
| **Per-call 50/30/50/10 bps + cumulative 2×** | **Insufficient.** Per-block reset does not bound multi-block drift (Grok "patient caller can still walk the price over many blocks"). Net anchored displacement doesn't bound roundtrip churn (Astra "reversing trades can charge fees even with little net price displacement"). Need: **window-level cumulative** (e.g., 100 bp absolute log-price travel per 30-min window) **+ gross input turnover cap** (e.g., 10% of window-start owned book per token) **+ reference freshness** (e.g., TWAP ≤ 30 min, freshness ≤ 5 min, fail-closed). | prompt; Kimi §1.3, Astra §3 |
| **"Absolute floor unchanged"** | **Missed the escape.** `_absoluteFloor` is a wei threshold for *zero-out reverts*; a deposit 1 wei above floor with 100% alignment loss can still revert incorrectly. Per-token absolute floor must be **combined** with the 1 bp relative alignment tolerance; the floor is a separate dust rule, not a substitute. | prompt; Kimi §4 |
| **V4 SE pretransfer "code-law gap" framing** | **Sharpen.** All three peers confirm **same gap** but add: (a) local snapshot vs economic totals collision — `BasicVaultRepo.sol:25, 92–97` documents `reserveOfToken` as **locally held**, but V4 SE `_syncVaultReserves` (`Common.sol:605–613`) stores **economic totals** (free + deployed); the V4 override's `faceBooked = R − deployed` is correct **at sync time** but **drifts between syncs** as deployed changes from fee accrual and price movement; (b) **EOA guard absent** confirmed by package grep — no `LocalCreditLib.requirePretransferCaller` call in V4 entry/override (`InTarget:37–67`, `Common:1270–1289`). | prompt clarification; Kimi §3.1, Astra §1 |
| **Hook UR compatibility as "behavior proof"** | **Wrong framing.** UR `V4_POSITION_MANAGER_CALL` is **mint-only**: `V3ToV4Migrator._checkV4PositionManagerCall` reverts `INCREASE_LIQUIDITY`, `INCREASE_LIQUIDITY_FROM_DELTAS`, `DECREASE_LIQUIDITY`, `BURN_POSITION` with `OnlyMintAllowed()`. PositionManager itself supports all four; our vault uses **direct `poolManager.modifyLiquidity`** (`Common.sol:1033–1063`) for the managed book and **direct PositionManager** for imports (`Common.sol:963–980`) — **not UR**. Hook flags mark which callbacks fire; they do not prove behavior. | Grok §2; Kimi §2.1; Astra §4; prompt |
| **Crane PositionManager selector parity "deployment verification"** | **Sharpen.** Upstream `PositionManager.sol` on `main` **explicitly warns** that `MINT_POSITION` and `INCREASE_LIQUIDITY` lack minimum-liquidity protection (delta-derived mint/increase). This is a **warning from upstream main**, not a claim of a current vault exploit. Crane port verification remains required. | prompt; primary source `PositionManager.sol` warning |

## B. Cross-peer convergence (high confidence)

1. **Hook admission** is permissive by deployer-supplied `PoolKey` (owner fallback); quote accuracy and settlement checks are restrictive. **No discretionary on-chain whitelist.** Hook flags are permission sets, not behavior proofs. UR is mint-only; the vault does not use UR for the managed book. No-liquidity-callback flags are limited evidence only. (Astra §4, Grok §2, Kimi §2.1.)
2. **Pretransfer** is settled law = `claimed ≤ B − R`; no provenance; integrator atomic discipline; EOA guard required. **All three peers withdraw** prior objections. (BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md §1.1, §4.2; APEX D9.)
3. **V4 SE pretransfer override = code-law gap** (`Common.sol:1270–1289`) for both **U mis-sizing under drift** and **missing EOA guard** (`LocalCreditLib.requirePretransferCaller` absent in `InTarget`/`Common`). Fix: align with `BasicVaultCommon._secureTokenTransfer` exactly; add guard. (All three.)
4. **Permissionless repair swaps** are now allowed (owner override). They are **structural inverse of deposit swaps**: incumbent inventory input, no user bound, socialized cost. Distinct from deposit composition. (Astra §3, Kimi §1.1.)
5. **Best-effort boundary**: silent single-sided invariant-growth fallback on the composed route **rejected** by all three. Either revert (preferred) or skip-swap + disclose residual. Do not change share law silently. (Astra §5, Grok §4, Kimi §4.)
6. **Alignment tolerance**: 1 bp unitless (1e-4) plus per-token absolute floor (separate dust rule); revert if exceeded. All three formulas equivalent up to constant. (Astra §5, Grok §4, Kimi §4.)

## C. Cross-peer divergence (with positions)

- **Per-call spot impact**: Kimi 25 bps; Astra/Grok 50 bps (Astra notes "25 bp conservative"). I adopt **25 bps** as conservative default; owner may raise to 50.
- **Cumulative anchor**: Astra proposes **100 bp absolute log-price travel per 30-min window + 10% gross input turnover per token** (combined); Grok proposes **per-block 100 bp only** (insufficient); Kimi proposes **25% of backlog value at campaign start**. I adopt **Astra's combined rule** as the most defensive; cross-block drift bounded.
- **Reference freshness**: Kimi 1 h; Astra 30 min TWAP, freshness ≤ 5 min. I adopt **Astra's shorter freshness** + fail-closed on stale.
- **Configuration authority**: Grok type-default + cascade; Kimi immutable package constants; Astra not explicit. I adopt **Grok's cascade** for compatibility with `liquidReservePercentage` precedent (no new oracle field, D5 spirit).

## D. Two remaining owner decision bundles

### Bundle A — Numeric/config/risk
**Question.** Approve the protection envelope and configuration source for permissionless repair swaps?

| Quantity | Recommended default | Source |
|---|---|---|
| Per-call terminal spot impact | **25 bps** | Kimi (conservative); 50 bps available if owner raises |
| Per-call execution slippage | **10 bps** worse than fee-inclusive executable quote at call-start state | Grok; prompt "no ≥ 2× fee" |
| Anchor deviation (optional) | **100 bps** from TWAP ≤ 30 min, freshness ≤ 5 min, fail-closed | Astra |
| Alignment loss (deposit route) | **1 bp (1e-4)** unitless + per-token absolute floor as separate dust rule | All three (numeric error in my round-4 corrected) |
| Cumulative aggregate | **100 bp absolute log-price travel per 30-min window + 10% gross input turnover per token** | Astra; Grok acknowledges per-block alone is insufficient |
| Reference freshness | **≤ 5 min**; fail-closed | Astra |
| Termination | Within D22 sleeve deadband = no-op success | Kimi (geometric-convergence observation) |
| Configuration authority | **Type-default + vault override cascade** (no new oracle field) | Grok; matches `liquidReservePercentage` precedent |
| Source of anchor reference | **External TWAP accessor with freshness check** — no DETF TWAP mandate | PRD §7; moderator G5 |

**Remaining owner micro-decisions**: (a) 25 vs 50 bps spot; (b) cumulative = 100 bp / 30 min / 10% turnover vs other; (c) reference required vs off.

### Bundle B — Best-effort fallback
**Question.** If the solver cannot reach `e ≤ 1 bp` within the impact budget, what is the safe fallback on the deposit composition path?

**Recommended answer.** **Revert** with explicit error (e.g., `AlignmentUnachievable`). **Reject silent single-sided invariant-growth fallback on the composed route.** The composed route must either succeed with alignment in bound, or revert. Public repair path may stop with disclosed residual and no new shares.

**Alternative the owner may explicitly approve**: skip the swap entirely; mint shares on the existing single-sided invariant-growth branch (`Common.sol:706–712`) using the raw deposit; disclose that the deposit did not compose. This is a **shape choice, not a numerical proposal**, and must be tagged in NatSpec as a degraded-mode path.

## E. Code-law gaps (not owner questions, surfaced for the implementation plan)

| Gap | Location | Fix |
|---|---|---|
| V4 SE `_secureTokenTransfer` override mis-sizes `U` under drift | `Common.sol:1270–1289` | Align with `BasicVaultCommon.sol:80–106` exactly (face balance, no subtraction). |
| EOA guard absent in V4 entry | `InTarget:37–67`, `InMultiTarget:11–30`, `Common:1270–1289` | Add `LocalCreditLib.requirePretransferCaller(msg.sender)` at each `pretransferred=true` entry. |
| End-of-op full-set sync gap in `_executeDirectSwapIn` | `InBase.sol:72–87` | Add `_syncAllExpectedHoldReserves()` per L-RSRV-SYNC-FULL. |
| Post-rebalance sync timing in `_executeFreeZapOutExactIn` | `InBase.sol:174–216` | Re-sync after `_rebalanceLiquidReserveBestEffort()`. |
| Crane PositionManager selector parity | `POSITION_MANAGER` from PkgInit | Verify byte-for-byte match with upstream `main`; record in deployment evidence. |

## F. Already-resolved (do not re-ask)

PZ-1..8; D59 dual bootstrap; full-range imports; native/WETH face; **permissionless repair swaps are now allowed** (owner override); pretransfer settled; hook admission deployer-responsible; no whitelist; denominator recalibration (`0.25e18`) rejected; opt-in selector rejected; TWAP mandate not law; backlog repair on its own scope.

## G. Confidence and gaps

- **High** Bundle B fallback (silent invariant-growth on composed rejected; revert or explicit degraded-mode); V4 SE pretransfer override gap; EOA guard gap; hook admission framing.
- **Medium** Bundle A numeric defaults (reasoned, not measured); 25 vs 50 bps spot; cumulative aggregate choice.
- **Low** Crane PositionManager selector parity (deployment evidence); upstream PositionManager minimum-liquidity warning (warning, not exploit).
- **Gaps**: `_checkV4PositionManagerCall` raw source 404 (Astra); PositionManager raw file not opened by Kimi (search-highlight evidence); no peer reads beyond originals; no Context7 re-query this pass; `apply_patch` unavailable; no shell/tests.

Stopping per assigned task. Cross-review is research-only; no PRD edits, no code, no shell, no delegation. Originals preserved.
