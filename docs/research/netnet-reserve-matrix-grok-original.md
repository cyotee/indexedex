# Grok original — NetNet reserve / swap matrix (owner override)

| Field | Value |
| --- | --- |
| Researcher | Independent Grok first pass |
| Observed model metadata | Prompt names `grok-4.6`; ID `xai/grok-4.6`. Routing, not attestation. |
| Date | 2026-09-26 |
| Owner context | `docs/research/netnet-reserve-matrix-owner-input.md` (49 lines) |
| PRD | `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` **v0.20** (978 lines) |
| Authorization | Research only. Moderator owns PRD reconciliation. No implementation. |
| Peer artifacts | None read. |

**Verdict:** Owner’s four-leg Weighted HLP book and split swap-vs-HLP surfaces **override** v0.20 interest-only NET-out, Keep-YT-for-sNET-in, and “HLP tokens = NET/sNET/USDG/DETF.” Full PRD rewrite of those rows is required; a precedence banner is not enough (`owner-input.md:4,45`). Pre/post-expiry **quote** procedure matches local Pendle math **if** executed on one mutated `MarketState`. Names `exitPreExpToSy` / `exitPostExpToSy` are **not** in this snapshot. **sNET in** is incomplete — do not invent. Do **not** reopen v0.20 TWAP/catch-up/approval/reward/rollover decisions (`owner-input.md:47`).

## Preserve (unrelated, settled)

From `PRD.md:19–89` / owner-input `:47`: custom-family approval; 3600s arithmetic hook-spot and DETF-synthetic TWAPs; absent TWAP = above-1 branch; `floor(S0*n/200)`; pre-expansion participation; fee/creator internal shares; hold interest token, other rewards to dynamic `feeTo()`, non-blocking forwarding retries; factory-validated atomic rollover. Liquid DETF still has **no** proportional HLP claim (`PRD.md:91,159`).

## Owner matrix (facts of the instruction)

**HLP legs (Weighted process):** (1) NET-DETF raw balance; (2) custom V2 SE **share-token** raw; (3) Pendle SY = held claimed SY + unclaimed claimable SY; (4) `(PLP, YT)` Uniswap-V2-style **sub-reserve** → internal shares → HLP. Direct deposits of DETF / SE shares / SY. NET in → Keep-YT into the sub-reserve. Proportional HLP exit pays those components; SE exit is **shares**, not underlying. PLP/YT exit to SY via verified pre/post-expiry path. Owner accepts expired-YT risk; arbitrage is not guaranteed (`owner-input.md:7–15`).

**Swap pricing (distinct from HLP):** USDG = SE rate-provider virtual of held shares; USDG in deposits to SE, USDG out redeems from SE. sNET = virtual of claimable+held SY **expressed as sNET**; sentence ends **“sNET in”** — incomplete (`:19`). NET = amount-specific zap-out of the PLP/YT leg — **not** the SY-interest leg (`:20`). NET-DETF remains raw self-leg unless a concrete conflict is found.

## Pendle quote verification (local snapshot, unpinned)

| Owner claim | Evidence | Result |
| --- | --- | --- |
| Do not quote via state-changing `exitPreExpToToken` | No such selector in inspected router; execution helpers `__removeLpToSyBeforeExpiry` / `AfterExpiry` are **state-changing** (`ActionAddRemoveLiqV3.sol:410–432`) | Agree: quotes must be view/pure on a copy |
| Do not compose `swapExactPtForSyStatic` after a separate LP-burn static | `ActionMarketCoreStatic.sol:70–77` **re-reads** `_readState(market)` between approx and swap | Agree: live reread ignores prior burn |
| One in-memory `MarketState`; `removeLiquidity` mutates totals | `MarketMathCore.sol:11–24,69–78` memory struct; `removeLiquidity` returns SY/PT | **Confirmed** |
| `IPMarket.readTokens()` / `readState(router)` | `IPMarket.sol:52,57` | **Confirmed.** Router identity can change fees |
| `pyIndexCurrentViewYt(YT)` | `IPActionMintRedeemStatic.sol:36` **camelCase** `pyIndexCurrentViewYt` | Name matches; reuse one `PYIndex` |
| `assetToSy` floors `py*1e18/index` | `SYUtils.sol:15–16` `(assetAmount * 1e18) / exchangeRate` | **Confirmed** floor |
| `swapExactPtForSy` / `swapSyForExactPt` on post-burn state | `MarketMathCore.sol:80–104` mutate memory | **Confirmed** |
| YT excess: `syToAssetUp` then `assetToSy` residual | `PYIndex.sol:31–34,23–24` | Helpers exist; full YT-flash accounting is the owner’s specified sequence, not a separate Pendle “exit YT” helper |
| Aggregate then one `redeemSyToTokenStatic` / `previewRedeem` | `IPActionMintRedeemStatic.sol:29–32`; `IStandardizedYield.sol:153–156` | **Confirmed** |
| Post-expiry: `removeLiquidityDualSyAndPtStatic` or local remove; no swap | `ActionMarketCoreStatic.sol:166–173`; addLiquidity reverts expired (`MarketMathCore.sol:119`) | Dual remove is view-safe. `removeLiquiditySingleSyStatic:232–236` post-expiry is `syFromBurn + index.assetToSy(ptFromBurn)` — **LP-only**, ignores extra YT |
| Ignore `ytIn` after expiry; `redeemPY` consumes PT not user YT | Context7 `/websites/pendle_finance` 2026-09-26: post-expiry YT worthless; PT redeems 1:1 underlying. Local `__removeLpToSyAfterExpiry` burns LP to SY+YT then `YT.redeemPY` (`ActionAddRemoveLiqV3.sol:426–432`) | **Consistent** with ignoring leftover YT for payout |
| Frozen first-expiry index vs current user payout | Not re-verified in InterestManagerYT this pass | **Engineering verify**; owner’s treasury-interest split must not be dropped |
| `exitPreExpToSy` / `exitPostExpToSy` | **Not present** in this Crane Pendle tree | Do **not** treat as ABI. Specify `MarketMathCore` quote + `burn`/`swap`/`redeemPY` execution |

Primary docs: https://docs.pendle.finance/pendle-v2/ProtocolMechanics/YieldTokenization/SY and FAQ expiry (Context7 2026-09-26). Router URL 404 this pass.

## Reusable SY rate provider

**Fact.** `IStandardizedYield.exchangeRate()` (`:94–101`) is **asset** per SY (WAD), not `tokenOut`. `previewRedeem(tokenOut, shares)` is **token-specific** and need not be linear. `getTokensOut()` / `isValidTokenOut` bound legal faces (`:140–147`).

**Fact.** Existing `StandardExchangeRateProviderFacet.sol:45–125` implements Balancer `IRateProvider.getRate()` by sampling `previewExchangeIn` of **one whole share** (native decimals, binary shrink, ceil scale to 18). Empty-supply uses inverted mint preview (`:127–145`). This is the reusable **pattern** for “virtual balance = rate × raw shares.”

**Inference for Pendle SY → sNET:**

1. Do **not** publish `exchangeRate()` as an sNET rate unless `assetInfo().assetAddress` **is** sNET and decimals match.
2. Prefer `previewRedeem(sNET, sample)` analog of the SE sampler **if** `isValidTokenOut(sNET)`. If SY only redeems NET, an extra NetNet unstake/wrap is a **second** conversion — specify, do not assume.
3. Sample size ≠ whole-book zap (`PRD.md` E07 warning still applies). FoT NET and rebasing sNET make unit-preview unsafe as NAV; family is FoT/rebase-approved (`PRD.md:24`) but the provider must credit **observed** deltas at execution.
4. Owner’s sNET virtual = **held SY + unclaimed claimable SY**. `exchangeRate`/`previewRedeem` on `balanceOf(hook)` **omit** unclaimed YT `userInterest`. The provider must add a **view of claimable SY** or the Weighted sNET leg understates inventory.
5. Unclaimed interest is not principal SY inside the PLP sub-reserve — provenance (`PRD.md:53,710–712`).

No live SY/sNET identity is verified.

## Conflicts to **remove** from the PRD (operative text, not history)

Moderator should rewrite these as current law, not leave them below a banner:

| Location | Retired requirement | Replacement (owner) |
| --- | --- | --- |
| R03 `:146`; §5 `:280–291`; R04 `:147` | All **sNET in** Keep-YT; one R03 table for swaps and bonds | NET in → Keep-YT into PLP/YT sub-reserve. **sNET in unspecified.** USDG **swap** in → SE deposit (not “same as HLP”) |
| R40 `:183`; R49 `:192`; §6 `:309–311`; liquid blurb `:91` | NET-out **and** sNET-out from **same interest inventory**; no principal substitution for NET-out | **sNET swap** from SY interest virtual. **NET swap** from PLP/YT zap-out. Interest-drainage rule applies to the **SY/sNET** leg, not NET |
| R05 `:148` as if HLP were virtual USDG | “includes … rates the exposure in USDG” without split | HLP holds **raw SE shares**; **swap** USDG uses rate-provider virtual |
| R28/R32 `:171,175`; §1 `:101`; architecture `:93` | HLP components/tokens = NET, sNET, USDG, DETF; unbalanced/subset/single-token over those | Four Weighted legs: DETF, SE shares, SY, PLP/YT **sub-reserve**. Direct HLP payouts are DETF / SE shares / SY / (SY from PLP+YT), not USDG/NET unless via swap conversion |
| §2.3 `:138` | “revival of the superseded virtual USDG design” outside scope | Virtual **USDG** for **swaps** is now selected; HLP remains physical shares |
| O06 `:731`; O09 `:734` | “interest-only trading” covering NET-out | Restate: sNET-interest inventory; NET from principal sub-reserve |
| R10 `:153` vs owner YT-expiry acceptance | Expired **LP deposits** still blocked is compatible; post-exp **exit** of held LP+PT is required | Keep deposit block; add post-exp quote/exit; do not treat expired YT as payout |
| §5 USDG withdrawal `:285` | Always “V2 LP exit → USDG” | Split: **HLP** pays SE shares; **swap** redeems SE → USDG |

**Do not silently delete:** owned-reserve burn domain (R39); public shared HLP; Keep-YT for **NET**; tax in V2 SE not hook; no liquid-DETF LP quota.

## Genuinely incomplete — do not invent

1. **sNET in** (owner sentence ends there). Not Keep-YT, not SY deposit, not interest-leg top-up, not rejected. Bonds that currently inherit R03 for sNET are likewise unspecified.
2. **Subset / single-leg / unbalanced HLP** vs new proportional-component language. v0.20 R32 still selects Weighted unbalanced modes. Owner LP matrix describes proportional sub-reserve and Weighted process but does not reaffirm single-token USDG/NET HLP exits. Leave OPEN.
3. **Sub-reserve mint/init/rebalance** of `(PLP, YT)`: first-join, unmatched YT after public NET-out, Keep-YT residual, empty target, fee on internal shares.
4. **Virtual whole-book rate vs finite zap** for NET and sNET (same SE-provider nonlinearity).
5. **Independent HLP ownership vs DETF-owned book** for burns (R39) under four rated legs.
6. **Weights**, drainage of SY leg, whether retained interest-token **incentives** are spendable on the sNET swap (`PRD.md:53,712`).
7. **Token identity:** SY vs sNET vs NET vs unclaimed interest vs principal SY in LP.

## Engineering gates (not owner product forks)

Map four legs into `WeightedMath` (`MIN_N=2` `MAX_N=8` still fits). Quote NET with one `MarketState` copy using **execution** router in `readState`. Do not call RouterStatic as the fee identity. Pin Pendle revision. Crane: PkgInit on interface; never `new`; V4 hook via registry (`crane-architecture`; `indexedex-uniswap-v4-hook-packages`).

## Narrow owner questions

1. Complete **sNET in** (HLP and/or swap and/or bonds) — or explicitly “unsupported.”
2. Are unbalanced/subset/single-token HLP exits **still selected**, and in which of the four new units?
3. Confirm NET-DETF remains the raw Weighted self-leg (owner default unless conflict).

Do not ask TWAP window, catch-up equation, absent-TWAP branch, family approval, or feeTo set.

## Confidence / limits

**High:** conflict map vs R03/R40/R49/R32; MarketState mutation quote; `pyIndexCurrentViewYt` / `assetToSy` floor; sNET-in incomplete. **Medium:** post-expiry frozen-index treasury split; YT-overage residual SY. **None:** live market tokens, gas, solvency. No tests. No consensus.
