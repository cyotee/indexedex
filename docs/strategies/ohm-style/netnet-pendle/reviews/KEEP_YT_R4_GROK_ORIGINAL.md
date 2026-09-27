# KEEP_YT_R4 Grok original — Pendle Keep YT vs swap, rollover impact

| Field | Value |
| --- | --- |
| Researcher | Grok |
| Routing | `xai/grok-4.6` — not provider attestation |
| Read | PRD v0.14 R03/R09–R10/§11; matrix 02–03/08–10/42; `ActionAddRemoveLiqV3.sol`; `MarketMathCore.sol`; `PendleYieldToken.sol`; `PendleMarketV3.sol`; `SYBase.sol`; Context7 `/websites/pendle_finance` (2026-09-24) |
| Peers | unread |
| Status | Research. Local Crane port, **not** live Robinhood proof. Unauthorized. |

**Do not reopen:** selected HLP proportional / unbalanced / single-token join-exit on NET,sNET,USDG,NET-DETF; USDG bonds share other fresh-bond locks; public HLP; R51 first-bond seeds HLP.

**Atomic vs staged:** owner **prefers** atomic; that is **not** a final selection. Below: Keep YT **removes Pendle AMM impact**; remaining impact is Weighted-hook domain, SY wrap, empty successor.

## Evidence

**Keep YT = mint PY, then dual mint — no market swap.** `addLiquiditySingleTokenKeepYt` / `_addLiquiditySingleSyKeepYt` (`ActionAddRemoveLiqV3.sol:236–303`): mint SY; split  
`netSyMintPy = netSyIn * totalPt / (totalPt + syToAsset(totalSy))`; send that SY to YT, rest to market; `YT.mintPY(market, receiver)` (`PendleYieldToken.sol:88–102`, `notExpired`) mints **equal PT+YT**; `IPMarket.mint(receiver, netSyAddLiquidity, netYtOut)` (`PendleMarketV3.sol:92–123`). Docs (Context7 Ch.7): Keep YT “avoids buying PT … **no price impact**.”

**Contrast:** `addLiquiditySingleToken` / `_addLiquiditySingleSy` (`:136–220`) **`swapSyForExactPt` then mint** — AMM fee + impact. Do **not** use this for R03 Keep YT.

**Live-pool Keep YT** is already ratio-matched; **looping swap/deposit does not reduce Pendle impact** (there is none). Loops **can** help: (1) **Weighted** large unbalanced DETF/HLP joins (Balancer `WeightedMath` domain / swap-ratio guards — **flag**, do not drop approved LP modes); (2) SY wrap size limits.

**Expired removal:** `mint`/`addLiquidityCore` revert `MarketExpired` (`MarketMathCore.sol:119`; `PendleMarketV3.sol:55–58`). `burn` still returns SY+PT (`:129–146`) — **prefer this**, not zap-out. After expiry, `redeemPY` PT-only (no YT). `executeTradeCore` reverts expired (`:187`).

**Old→new SY:** `SY.redeem` then successor `SY.deposit` (`SYBase.sol:37–76`). Wrap/unwrap fees possible; **not** PT/SY AMM. Distinct old vs new SY (PRD §11.1). Interest vs principal both may be SY — do not dump principal into R40 interest inventory.

**Empty successor:** Keep YT **divides by `totalPt + syToAsset(totalSy)`** (`:285–286`). Both zero → **div-by-zero**. First join instead: `totalLp==0` uses `sqrt(sy*pt)-MINIMUM_LIQUIDITY` and **requires both SY and PT > 0** (`MarketMathCore.sol:118–128,143`). Seed by `mintPY` then `market.mint` with **chosen** SY/PT (still **no swap**). Do not call Keep YT ratio on empty reserves.

## Recommendation

1. **NET/sNET Keep YT** = SY mint → `mintPY` → `market.mint(SY,PT)` + retain YT. **Never** single-token swap-zap for this product.
2. **Rollover (atomic preference):** claim old interest (old SY); `burn` old LP; post-expiry redeem PT; convert SY via redeem/deposit; **if successor has reserves**, Keep YT; **if empty**, explicit first `mintPY`+dual mint. Atomic is **feasible** without Pendle AMM. Fail if wrap/`minLpOut`/`minYtOut` fail — **no** silent swap fallback.
3. **Split loops** only for Weighted imbalance or SY wrap chunks — not for Keep YT itself.
4. Opening **1 DETF = 1000 NET** and **0.5%/epoch** are owner parameters, not implied by Pendle.

## Uncertainty
Vendored V3 router vs Robinhood deployed router/factory; live wrap fees; successor already-initialized vs empty; Weighted first-join vs Pendle first-join **composition** in the same atomic tx.

## ≤2 owner economic clarifications
1. **0.5% expansion:** of **which base** (total DETF supply, liquid only, staked backing)? Accrues to **sDETF-held minted DETF (R43)** or another recipient? **Gated** below / at / above 1 NET per DETF, or every processed epoch regardless of peg?
2. **Opening 1000 NET per DETF vs peg target 1 NET per DETF:** confirm these are **different** (bootstrap `P0` vs ongoing peg), including **decimals** (DETF 9 vs NET native). If `P0=1000` is the intended peg, that **replaces** the 1:1 target — say so explicitly.
