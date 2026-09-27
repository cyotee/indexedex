# KEEP_YT_R4 — Kimi K3 ORIGINAL independent first pass

Round scope: Keep-YT mechanics, rollover swap-impact mitigation, old/new SY conversion, expired-market removal, empty-target edge. Read: CLAUDE.md, PRD v0.14 (§§10.4, 11–11.4), consolidated matrix, and local vendored Pendle sources. No peer artifacts. No code/shell/tests. Research only.

## Evidence (local code, inspected 2026-09-24)

**Keep YT mints PT+YT and joins WITHOUT a swap.** `lib/crane/contracts/protocols/perps/pendle/router/ActionAddRemoveLiqV3.sol:272–303` (`_addLiquiditySingleSyKeepYt`): splits input SY as `netSyMintPy = netSyIn * totalPt / (totalPt + pyIndex.syToAsset(totalSy))` (:285–286); transfers that portion to YT and the rest to the market (:291–294); `YT.mintPY(market, receiver)` sends PT to the market and YT to the receiver (:297); then `IPMarket.mint(receiver, netSyAddLiquidity, netYtOut)` (:299). No `swap*` call appears. Contrast the non-Keep-YT path `:178–221`, which executes `swapSyForExactPt` on the market curve (:218) — that is the swap+deposit variant. Pendle docs corroborate: Keep YT ("Zero Price Impact Mode") wraps to SY, mints PT+YT from part of it, pairs PT with remaining SY, returns YT (docs.pendle.finance, Pool/Zap-In/Keep YT Mode; retrieved 2026-09-24 via Context7).

**Dual joins tolerate leftover without swap.** `addLiquidityDualSyAndPt` (:46–66) computes optimal `netSyUsed/netPtUsed` via `MarketState.addLiquidity` and pulls only those amounts; excess stays with the caller.

**Expired-market removal is swap-free.** `_removeLiquiditySingleSy` (:418–422) branches on `isExpired()`; post-expiry `__removeLpToSyAfterExpiry` (:426–433) burns LP → SY + PT, then `YT.redeemPY(receiver)` — after expiry PT redeems without YT, no swap.

**Empty-target edge.** The Keep-YT split divides by `totalPt + syToAsset(totalSy)` (:286): an empty successor market (both zero) reverts by division. Keep-YT single-asset entry therefore requires a pre-seeded market; a fresh market needs a dual SY+PT join (mint PY first, then `addLiquidityDualSyAndPt`) or external seed liquidity. PRD §11:459 already requires target "initialization/liquidity" validation.

## Practical recommendation (conditional, not a final selection)

Because rollover is already expiry-gated (matrix row 42; PRD §11), a **fully swap-free atomic rollover sequence exists**: (1) `removeLiquidityDualSyAndPt` on the expired market — no swap; (2) `redeemPY` for mature PT — no swap; (3) convert old SY → new SY via underlying round-trip (old SY redeem → underlying → new SY deposit); no direct SY→SY path exists in the router; (4) on the successor, split SY per the Keep-YT formula, `mintPY`, then dual join — no market swap anywhere. This directly answers the owner's price-impact worry: impact arises only from pre-expiry exits or SY conversion done by selling through pools, neither of which is required. Splitting swap/deposit loops is unnecessary on this path; if swaps ever are needed, tranching lowers per-trade impact at higher fee/gas cost (approx helpers `approxSwapPtToAddLiquidity` exist, :119–128). Atomicity risk then reduces to external-call failure handling, which favors the owner's atomic *preference* — still distinguish this from a final atomic selection (§11.4 remains "not yet selected"). Old-SY receipts must be accounted as old-SY, never relabeled new-SY (PRD §11.1:471).

**Weighted-math flag (no reopening):** owner-selected reused Weighted/Balancer math has domain/rounding guards; hook join/exit variants (proportional, subset, single-token in NET/sNET/USDG/NET-DETF) must map inputs into rated units before invariant math — an operation-domain limit to specify, not a reason to reopen the approved LP modes.

## Uncertainty

Local vendored snapshot, pragma `^0.8.17`; not a verified live Robinhood deployment. `MarketMathCore.addLiquidity` optimal-split internals not fully traced. NetNet SY wrap/unwrap may itself hit staking/tax mechanics (epoch queue, FoT) — unverified.

## Necessary economic clarifications (2)

1. **Opening price vs peg:** proposed opening "1 DETF = 1000 NET" conflicts with the selected peg target 1 NET-DETF = 1 NET (PRD R25) unless this is a unit-scaling statement (9-decimal DETF) or the peg target changed. Confirm which.
2. **0.5% expansion:** 0.5% of what base (total DETF supply? staked supply? reserve), minted to whom (staker rewards? bond funding? reserve self-leg?), and gated how (every processed NET epoch regardless of price?). Do not assume; Q7's objective was never answered.

Researcher: **Kimi K3** — assigned metadata `kimi-code-plan-global/k3` (variant high); routing metadata only, no provider attestation.
