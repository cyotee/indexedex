# Kimi K3 — Independent first pass: Uniswap V4 SE sleeve zap-in (proportional deploy)

**Date:** 2026-09-26. **Scope:** research only; no code/config edits, no tests run.
**Question:** repeated single-token deposits into the Uniswap V4 Standard Exchange vault remain undeployed because the sleeve lacks proportional counter-token. Human wants a PRD making idle zap-in swap into a proportional distribution and deploy, retaining the policy sleeve for PoolManager-blocked operations.

## 1. Root cause (verified against code — FACT)

Chain of custody for an idle single-token zap-in:

1. `UniswapV4StandardExchangeInTarget.exchangeIn` routes single pool-token → shares to `_executeZapInDeposit` (`contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol:63-68`).
2. `_executeZapInDeposit` pulls tokens, mints shares against **total** reserves (free+deployed), then calls `_rebalanceLiquidReserveBestEffort()` only when `canOpenPoolManagerUnlock()` (`UniswapV4StandardExchangeInBase.sol:273-315`, gate at 309).
3. `_rebalanceLiquidReserveInternal` computes per-token excess over `targetFree_i = total_i * liquidPct / 1e18` and calls `_deployExcessLiquidity(excess0, excess1)` (`UniswapV4StandardExchangeCommon.sol:751-781`).
4. `_deployExcessLiquidity` → `_managedLiquidityPlan` → `_setCenterPlan` → `LiquidityAmounts.getLiquidityForAmounts(sqrtP, sqrtA, sqrtB, excess0, excess1)` (Common.sol:557-576). D30 makes the managed book **full-range** (`minUsableTick`/`maxUsableTick`), which is **always in range**, so `getLiquidityForAmounts` is `min(liquidityForAmount0, liquidityForAmount1)` (standard v3-style math; Context7 `/uniswap/v4-periphery`, accessed 2026-09-26).
5. A same-token repeated deposit leaves the **counter-token** free balance at/below its target → `excess_counter = 0` → `plan.centerLiquidity == 0` → early `return false` (Common.sol:843-845). The excess of the deposited token **stays free forever**. D28 forbids a token0↔token1 rebalance swap (LOCAL_LIQUID_BUFFER_PRD D28, line 171) and D32 explicitly accepts binding-token leftovers staying free (FULL_RANGE_DEPLOYED_BOOK_PRD D32, line 143).

**Precise root cause:** the conjunction of (a) D30 full-range always-in-range book (deploy needs *both* tokens at the CL ratio), (b) D27 deploy-excess-only tail rebalance, (c) D28 no rebalance swaps, and (d) D32 leftover-stays-free. A one-sided excess can *never* deploy; each repeated same-token deposit raises `total_i` and `targetFree_i` but the growing free balance can never convert. This is structural, not a bug in any single function.

Corollary (FACT): blocked-path deposits (`!canOpenPoolManagerUnlock()`) also stay sleeve by design (D4) and later idle rebalance hits the same wall. Note the V4 naming pitfall is handled correctly in code: `canOpenPoolManagerUnlock() := !TransientStateLibrary.isUnlocked(pm)` (Common.sol:315-317; PRD §0 lines 38-52) — PM *idle* = V4 "locked"; PM *in-session* = V4 "unlocked".

Bootstrap (FACT): first mint at `totalSupply == 0` requires **both** tokens — `_sharesOutForDeposit` returns 0 for one-sided first mint (Common.sol:693-695), reverting `ZeroAmount` (InBase.sol:293-294). This matches D59 two-token activation (DETF_ALIGNMENT_PRD §0 line 99, §24.7.1 line 1159). Zap-in swap therefore applies only to *subsequent* deposits unless the PRD deliberately reopens D59.

## 2. Supersession required (explicit)

The human request is a **proposed change** conflicting with locked law:

| Existing law | Conflict | Required action |
|---|---|---|
| **D28** (no token0↔token1 swap as rebalance tool) | Zap-in swap is a swap on the deposit path | **Carve-out, not repeal:** deposit-completion swap inside idle zap-in is part of the *user route*; public/tail `rebalanceLiquidReserve` stays add/remove-only |
| **D27** (sleeve-then-deploy-excess is THE free-deposit shape) | New shape: sleeve-credit, mint, ratio-forming swap of excess, deploy | Amend D27 step (3) to permit an optional ratio-forming swap of the excess before `modifyLiquidity` |
| **D32** (leftover of binding token stays free) | Swap is intended to *eliminate* the one-sided leftover | Supersede for the zap-in path when swap succeeds; D32 remains the fallback (best-effort, swap failure/dust → leftover stays free) |
| **D24** (preview ignores rebalance) | If the swap is part of the user route, previews must model it or explicitly classify it as rebalance-like | Decision required (§6) |
| **D45** (Multi join/exit must not swap) | None — keep unchanged | Explicitly restate: swap applies to single-token `IStandardExchangeIn` zap-in only |
| **D59 / D58 / D57** (two-token activation; count sleeve+fees once; full range) | None — preserved | Bootstrap stays dual-funded; accounting unchanged |

**Precedent (FACT):** the idle *zap-out* path already swaps the other pool token (`InBase.sol:200-202` `_swapExactIn(!outIsToken0, otherForUser)`; FULL_RANGE PRD §0 line 60 "Idle zap-out may swap"). A symmetric idle zap-in swap is consistent with existing product shape — strong support for the carve-out framing rather than a D28 repeal.

## 3. Recommended product requirements (INFERENCE → PRD skeleton)

1. **Idle single-token zap-in (new shape):** pull → mint shares against total reserves (mint math **unchanged**, D9/D13) → compute per-token excess above live `targetFree_i` (D20 live read) → if exactly one token has excess beyond deadband, swap the optimal fraction of that excess into the counter-token inside one `unlock` session, then add full-range liquidity with the resulting pair → deadband + best-effort rules unchanged (D11/D22). Leftover dust stays free (D32 fallback).
2. **Blocked path unchanged:** no swap, sleeve-only, mint against totals (D4/D18). `rebalanceLiquidReserve()` stays swap-free and reverts when blocked (D10) — backlog from blocked deposits is only ratio-fixed by later *deposit-path* swaps or dual joins, never by public rebalance (keeps D28's MEV surface small).
3. **Sleeve retention:** swap+deploy sized so post-op `free_i ≥ targetFree_i` per token (deploy only the excess); never dip the sleeve to form ratio (FULL_RANGE PRD rejected-alternatives line 254 already forbids dipping the scarce-token sleeve).
4. **Slippage guard (mandatory):** swap `minOut` from the bound TWAP oracle (`twapOracle()` / `_pokeBoundPoolTwap`, Common.sol:319-329) with a deviation bound, consistent with DETF law "mandatory price gates with reserve-swap fallback" (CLAUDE.md non-negotiable 5). Quote via existing `UniswapV4Quoter`/`UniswapV4QuoteService._adjustHookSwap` so hook-adjusted pools price correctly (Common.sol:226, 1134).
5. **Scope:** single-token `exchangeIn` zap-in only. Multi join/exit (D41-D52) unchanged and swap-free. Direct pool swaps unchanged (D12). Imported positions: ratio-forming swap uses the NFT's ticks for the deploy ratio; when imported position is out of range one-sided deploy already works — swap optional/skip. Native currency: WETH-face mapping `_erc20Face` and WETH wrap/unwrap settlement (Common.sol:411-425, 1096-1118) already handle native legs in swap settlement; zap-in swap inherits this. D26 (no native sleeve design) unaffected.
6. **Optimal swap size:** solve for the split of the excess that maximizes `getLiquidityForAmounts` at current `slot0` for the full-range (or imported) ticks — closed-form "optimal single-sided deposit" math (v3-style); account for swap price impact or accept spot-approximation + deadband (decision, §7).

## 4. Economics (normative honesty)

- **Today:** single-sided deposit mints via invariant-growth (Common.sol:706-712) — depositor is already charged an implicit join penalty, and the deposit then earns **zero** V4 fees while stranded in the sleeve (sleeve = no fee exposure, FULL_RANGE PRD §8). Repeated same-token deposits compound the fee-idle fraction far above 20%.
- **With zap-in swap:** depositor pays swap fee + price impact instead of indefinite fee idleness; the vault's own full-range position captures a pro-rata share of the swap fee (self-fee rebate). Deployed-ratio residue stays free per D32 fallback. Share mint math unchanged → no change to D9/D13/D29 donation accounting; swap occurs with vault inventory post-mint, so residual slippage-vs-TWAP error is socialized across holders and bounded by the price gate.
- **Risk:** swap moves the pool's own price; the deploy ratio is computed at post-swap price or pre-swap spot — mismatch leaves D32 leftover. TWAP-gated minOut bounds sandwich loss; hook-fee pools need `_adjustHookSwap` handling.

## 5. Previews

Two coherent options (decision required):
- **(A) Swap = user route:** `previewExchangeIn` for shares models mint math only (already share-identical, D24 trivially holds since shares don't depend on placement) and a *new/extended* quote view exposes expected deployed/sleeve split. Recommended: shares preview unchanged → preview==exec for user-returned amounts preserved verbatim.
- **(B) Swap = rebalance-like:** classify the swap+deploy as tail-rebalance → D24 already says previews ignore it. Simplest legally, but then previews can't warn on swap slippage; the `minSharesOut` check still binds only the mint.
Recommendation: (B) for law-minimal supersession, plus an informational view quoting expected post-zap split.

## 6. Security requirements

1. Swap only when `canOpenPoolManagerUnlock()`; blocked path must never enter the swap branch (extends D2/D12).
2. TWAP-gated `minOut` on the zap-in swap; revert-or-skip semantics: skip (leave free, D32) rather than revert the whole mint on gate failure is more consistent with D11 best-effort — decision (§7).
3. Reentrancy: `nonReentrant` already on `exchangeIn` (InTarget.sol:45); swap+deploy occurs inside `_executeUnlock` with `unlockCallback` caller check (Common.sol:996-999).
4. Donation surface unchanged (D29); deadband (D22) still gates whether deploy is attempted.
5. Hook-fee / projected-hook pools: use `UniswapV4QuoteService` adjustment paths for quotes; `_supportsInventoryQuote` excludes imported positions (Common.sol:94-96).
6. Adversarial additions: sandwich on zap-in swap; donation between mint and swap within same tx (impossible — atomic, but cross-block MEV); price manipulation of slot0 before zap-in (mitigated by TWAP gate); reenter during blocked deposit (existing T13).

## 7. Test acceptance (production-first, extends T1-T16/FR1-6/MJ/ME)

| ID | Case | Expect |
|----|------|--------|
| Z1 | Idle single-token zap-in, counter-token at target | Excess swapped + deployed; position L grows; `free_i ≥ targetFree_i` within deadband both tokens |
| Z2 | **Repeated same-token zap-ins (reported bug)** | Sleeve fraction of deposited token returns toward ~20% each time; deployed book grows (this is the regression test) |
| Z3 | Blocked zap-in | No swap, no unlock; sleeve-only; `LocalDepositWhileBlocked` emitted (unchanged) |
| Z4 | After Z3, idle public rebalance | Still swap-free (D28); may leave one-sided excess (documented) |
| Z5 | TWAP gate failure mid zap-in | Per chosen semantics: revert, or skip swap with D32 leftover and successful mint |
| Z6 | Preview parity | `previewExchangeIn` sharesOut == exec sharesOut for idle zap-in with swap (D24) |
| Z7 | Hook-fee pool zap-in swap | Quote uses `_adjustHookSwap`; deploy succeeds |
| Z8 | Native currency0 pool zap-in swap | WETH wrap/unwrap settlement correct both directions |
| Z9 | Imported position zap-in swap | Deploy ratio uses NFT ticks; ticks unchanged (D34/D35) |
| Z10 | First-mint single-token | Still reverts (D59 preserved) or, if D59 reopened, swap-bootstraps — must be explicit either way |
| Z11 | Adversarial: sandwich/donation/reentrancy on new path | Loss bounded by TWAP gate; no share-math drift |

## 8. Unresolved decisions for the PRD owner

1. **D28 carve-out wording** (deposit-route swap vs rebalance swap) — recommend carve-out.
2. **Swap-failure semantics:** revert user op vs skip-to-D32-leftover (recommend skip, D11-consistent).
3. **Preview classification** (§5 A vs B) — recommend B + informational view.
4. **D59 scope:** does single-token *first* activation stay forbidden? Recommend unchanged (dual bootstrap stays).
5. **Optimal-swap formula:** exact closed-form vs spot approximation + deadband.
6. Whether blocked-deposit backlog ever gets ratio-fixed (recommend: only via later deposit-path swaps / dual Multi joins; public rebalance never swaps).

## 9. Environment / versions / sources

- solc 0.8.35, optimizer_runs=1, `via_ir` forbidden (`foundry.toml:29,34-36`); pragma ^0.8.0; Crane via `lib/crane` submodule (`@crane/` remapping).
- Context7 `/uniswap/v4-periphery` (LiquidityAmounts = v3-style min-binding math) and `/uniswap/v4-core` (singleton unlock flash-accounting session, deltas must settle), accessed 2026-09-26.
- PRDs read: LOCAL_LIQUID_BUFFER v1.6 (D1-D29), FULL_RANGE_DEPLOYED_BOOK v1.2 (D30-D52), DETF_ALIGNMENT_PRD §0 D57-D59 (lines 97-99), §24.7.1 (1153-1163), §24.8 supersession map.

## 10. Confidence and gaps

- **High confidence:** root-cause mechanism and code citations; supersession targets; blocked-path invariants; bootstrap constraint.
- **Medium:** recommended swap-sizing/gate semantics (product choices, not facts).
- **Gaps:** (1) could not enumerate `test/foundry/spec/protocols/dexes/uniswap/v4/standardExchange/` — glob aborted twice on broken `lib/crane/.grok/skills/*` symlinks (recorded, not retried); exact existing T1-T16 test file locations unverified. (2) Optimal-swap formula not derived here. (3) No peer artifacts read (independent pass). (4) `apply_patch` tool unavailable in this environment; report authored with the file-write tool instead.
