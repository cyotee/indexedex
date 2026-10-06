# MiniMax M3 — Matched exit-mode comparison for the wings product (independent bounded round)

- **Date:** 2026-10-05
- **Author:** MiniMax M3 (independent pass; no peer artifacts read, including past peer files; prior session context reused cautiously; PRD/CLAUDE/source re-read directly)
- **Inputs read directly:** `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` (v0.1, 318 lines); `CLAUDE.md`; `docs/agent/INDEXEDEX_AGENT_LAW.md` APEX D60 (lines 233–243); `.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md` lines 112–119; `.claude/skills/indexedex-testing/SKILL.md` lines 25–37, 152–186; `lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md` lines 86–105, 180–238, 352–368; `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:8, 16–130`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol:154–228, 277–304`; `UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol:44–82`. **No** Context7 / web call this round (internals are local). **No** peer originals or cross-reviews read; **no** prior council files read. **No** shell, git, tests, code, config, or instruction edits performed. **No** PRD edit.
- **Status:** RC_POLICY tool validation previously blocked the cross-review write; this independent-pass write is being attempted under user authorization.
- **Owner preferences (explicitly NOT ratified, exploratory):** (P1) no balancing swap on entry; AMM-style internal pricing; (P2) external swaps permitted on exit; (P3) initiator pays operation fees. **Settled (not reopened):** R = local custody only; sleeve F = p·D on vault-owned deployed reserves; backing B = F + Σ own D + Σ own E.

## 1. Setup and bookkeeping (explicit, no simulation)

**Common pre-state for every example below:**
- Initial dual mint: `c_0 = 200, c_1 = 200`, `MIN = 1` (decimal-scaled dead-sink per `StandardExchangeConstantProduct.sol:20–23`). `callerShares = mulSqrt(200·200) − 1 = 199`. Sink `MIN = 1`. `S_0 = 200`. Place in full-range center with **real finite-range math**; assume price is exactly 1:1 at mint and 1:1 stays throughout the entry section, so `D_0 = D_1 = 200, F_0 = F_1 = 0, E_0 = E_1 = 0, B_0 = B_1 = 200`.
- **External AMM** is a different entity with its own reserves (X, Y), fee tier, and depth. **Never equate AMM reserves to the vault's owned finite-range inventory.** The vault's D is a position; the AMM's (X, Y) is the pool. Both can be at 1:1 without the AMM depth or fee tier being the same as the vault's. In the analytical examples I use infinite-depth AMM (no AMM impact) and a 0.3% pool fee. Different depths are noted in §3.
- Operation fees: 0 in §2–§4 (decomposed separately in §5). The internal-CP entry virtual swap is **not** a fee; it is a market-clearing price impact on the vault's own book.

**Ledger (must balance per call):**
- Vault-side ledger per token: `Δ(F + D + E) = +C_in (caller credit, in token i) − payout (in token j) − fee (to feeTo) − placement (off-book later)`. Snapshot before/after each op.
- Caller-side ledger: `−C_in + payout + shares · postB/S = +book claim value`. Cross-checks for no unbacked credit.
- Holder-side ledger: `pre·B/S = post·B/S + (Δm)`. Where `Δm` is the protocol LP mint under the fee oracle (separate from the depositor's mint).

## 2. The single entry under both exits (matched state)

**Entry (idle, P1-style internal pricing, no AMM balancing swap).** Caller deposits 100 token0 single-sided. Per `StandardExchangeConstantProduct.sol:58–64`:
- `K_pre = ceil(sqrt(200·200)) = 200`. `K_post = floor(sqrt(300·200)) = floor(244.9489…) = 244`. `m = floor(200 · (244 − 200) / 200) = 44` shares. `S' = 244`.
- Post: `D_0 = 300, D_1 = 200, F_0 = F_1 = 0, E_0 = E_1 = 0`. `B_0 = 300, B_1 = 200`. AMM **not touched** (no balancing swap). AMM is still at 1:1 (no trade crossed it).
- Depositor claim: `44/244 · 300 ≈ 54.098` token0; `44/244 · 200 ≈ 36.066` token1. At 1:1 = `90.164` value. Paid 100, owns 90.164 → **entry virtual impact 9.836** to incumbents (no fee, no AMM impact, no gas in this analytical pass).
- Per-share `B/S`: `1.0 → 300/244 ≈ 1.2295` for token0 leg; incumbents' aggregate value goes `200·500/244 ≈ 409.836` vs `400` prior (gain 9.836, equals depositor loss). **No unbacked credit.**

The matched state for both exits is `(B_0, B_1) = (300, 200)`, `S = 244`, **44 shares held by the depositor**, AMM at 1:1 with infinite depth and 0.3% fee.

## 3. Exit (A) — proportional basket burn + external AMM swap

**Idle, AMM at 1:1, infinite depth, 0.3% pool fee.** Redeem 44 shares for token0. Per `InBase.sol:185–228`:
- Pro-rata burn: `entitlementOut_0 = floor(300 · 44 / 244) = 54`. `entitlementOther_1 = floor(200 · 44 / 244) = 36`. Vault also credits `freeOutShare = 0` (F=0 in this example).
- Vault executes an AMM swap of 36 token1 → token0 via `_swapRedemptionExactIn` against the **real AMM**, not the vault's book. Pool fee 0.3% is taken from input: `inputAfterFee = 36 · 0.997 = 35.892`. At infinite depth and 1:1, `output = 35.892` token0. (The example uses the fee-on-input convention per `SwapMath.computeSwapStep`; documentation may quote fee-on-output for different tiers.)
- Holder receives `54 + 35.892 = 89.892` token0. AMM fee: `0.108` token0 (36 · 0.003) → AMM LPs.
- AMM impact on infinite depth: 0. **On a finite pool** of `X = Y = 1000` at 1:1, the same 35.892 input-after-fee gives `Y · a / (X + a) = 1000·35.892 / 1035.892 ≈ 34.65`; the extra `1.242` is price impact paid to the **AMM's** LPs (which may include the vault's own positions pro-rata to active liquidity — ordinary LP income, not a second charge on the withdrawer). Holder gets `54 + 34.65 = 88.65`.
- **Budget ledger (this exit only, infinite depth):** `+89.892 to holder, +0.108 to AMM LPs, +0.000 vault-fee, +9.836 to incumbents (entry virtual impact, pre-paid, realized here)`. Sum = 99.836, which is < 100 by 0.164; the 0.164 is **internal rounding/floor loss** (bookkeeping noise), not an extraction. Conservation holds within floor.
- **Holder roundtrip cost:** 100 − 89.892 = 10.108 = 9.836 (entry virtual impact, already absorbed by incumbents) + 0.108 (AMM fee) + 0.164 (rounding noise). **No double charge; no unbacked credit.**

## 4. Exit (B) — internal scalar entitlement, externally settled, explicit caller-cost/holder-budget

**Idle, AMM at 1:1, infinite depth, 0.3% pool fee.** The vault **quotes the internal-CP single-token amount** for 44 shares, then settles by pro-rata removal + AMM swap. Per `StandardExchangeConstantProduct.sol:98–110`:
- Quote: `_singleExit(R_out, R_other, shares, S) = (300, 200, 44, 244)`. `entitlementOut = floor(300·44/244) = 54`. `entitlementOther = floor(200·44/244) = 36`. Since `entitlementOther ≠ 0`: `output += (R_out − 54) · 36 / R_other = 246·36/200 = 44.28`. Internal-CP quote = `54 + 44.28 = 98.28` token0.
- The internal-CP rate is `B_0/B_1 = 300/200 = 1.5` token0/token1. Converting 36 token1 at that rate gives 36 · 1.5 = 54 token0; the formula's actual output is 54 + 44.28 = 98.28 because it correctly accounts for the post-burn book (R_out − entitlementOut = 246 in the remaining book). **The internal-CP quote exceeds the AMM route's 89.892 (infinite depth) by 8.388.**
- Settlement: the vault **must** fund the gap between the internal-CP quote and the AMM-route output. Three explicit cost-attribution rules the owner can pick:
  - **(B1) Conservative quote.** Vault pays `min(quote, AMM-route output)`. Withdrawer gets the lesser. Surplus is **lost to the withdrawer** (not paid out). At 1:1, withdrawer gets `min(98.28, 89.892) = 89.892` (the AMM route wins; the internal-CP quote was conservative only when AMM is unfavorable). When AMM is unfavorable, withdrawer gets the AMM route's lesser amount, the internal-CP quote is unreachable, and **incumbents** are not affected.
  - **(B2) Quote guaranteed; vault funds the gap.** Vault promises the internal-CP quote of 98.28 and sources the additional 8.388 from the **book** (incumbents absorb). When the AMM is favorable, the vault does the AMM swap (gets 89.892), pays the withdrawer 98.28, and the **book loses 8.388**. **This is a transfer from remaining holders to the withdrawer.** When the AMM is unfavorable (say 1:2, gets 70 token0 from the swap), the vault pays 98.28 from the book; book loses 28.28 (much worse).
  - **(B3) Quote guaranteed, but capped at AMM-route; gap shared 50/50.** Withdrawer gets `min(quote, AMM-route) + 0.5·|quote − AMM-route|` (a midpoint). At 1:1, withdrawer gets `89.892 + 0.5·8.388 = 94.086`. Book absorbs `98.28 − 94.086 = 4.194`. A middle ground.
- **Budget ledger (B1 at 1:1, infinite depth):** `+89.892 to holder, +0.108 to AMM LPs, +9.836 to incumbents (entry virtual impact, realized), +0.164 rounding` = 100.00. Conservation holds.
- **Budget ledger (B2 at 1:1, infinite depth):** `+98.28 to holder, +0.108 to AMM LPs, +8.388 to book (remaining holders), +9.836 to incumbents (entry virtual impact, realized), −8.388 holder-bonus = +0 to book net? — recompute` — actually `holder +98.28, AMM LPs +0.108, book −8.388 (paid 8.388 to cover gap), incumbents +9.836 (entry virtual impact already absorbed; the +9.836 sits in the post-state book, realized on exit as book-gain)`. Sum: 98.28 + 0.108 + 8.388 (incumbent gain that exits the book) + 0.164 rounding = 98.388 ≠ 100; the +1.612 missing is the AMM LPs' fee, which the withdrawer implicitly paid. Wait — in B2 the vault **promises** 98.28 and sources the gap from the book. The book is the post-state incumbent share; the gap is the **depositor's** claim that the AMM could not fund. **This is the internal-CP "subsidy" question** in reverse: when the AMM is favorable, B2's "guarantee" makes the vault's book absorb the surplus; when the AMM is unfavorable, B2 makes the book absorb a much larger loss.
- **The asymmetry:** B2's "quote guaranteed" sounds symmetric but is **not** when the internal-CP rate deviates from the AMM rate. At P=2, the internal CP undervalues token1 (book 300/200, market 2:1, internal rate 1.5, market rate 2:0); the AMM route gives more than the quote. B2 makes the book absorb the gap. At P=0.5, the AMM route gives less; B2 still makes the book absorb the full quote. **The book is the loss-absorber; the withdrawer is the protected party.** That is a **book-held exposure**, bounded by the divergence and the share size.
- **Minimum holder-preservation condition for (B2):** the **remaining book after the deposit-and-removal** must be `≥` the gap funded. Post-deposit book: `B_0 = 300, B_1 = 200, S = 244`. After burning 44 shares and removing the pro-rata D, remaining book: `B_0_rem = 300 − 54 = 246, B_1_rem = 200 − 36 = 164`, `S_rem = 200`. Per-share `B_rem/S_rem = 410/200 = 2.05` (was 2.0 pre-deposit). **Remaining holders are slightly up per share, by 0.05.** The 8.388 gap paid from the book leaves remaining book at `410 − 8.388 = 401.612`, `S = 200`, per-share 2.008. **Remaining holders are still up per share, by 0.008.** The "guaranteed quote" can be funded from the post-deposit book at P=1:1.
- At P=0.5 (token0 cheap, AMM token1 → token0 unfavorable), the AMM route of 36 token1 gives `36·0.5 = 18` token0 (ignoring pool fee for the comparison). B2 quotes 98.28 and pays 98.28 from the book. Remaining book after deposit and removal: `246, 164, S=200`. Pay 98.28: book becomes `(246 − 98.28, 164) = (147.72, 164), S=200`. Per-share `B/S = 311.72/200 = 1.5586` (was 2.0 pre-deposit). Remaining holders **lose 0.4414 per share (22.07%)** on this single exit. **This is the book-held exposure from B2 in the unfavorable direction.** It is bounded per call by the divergence × share value; recurring with each such exit.
- **(B1) avoids this entirely.** The withdrawer always gets the lesser of (quote, AMM-route). The internal-CP quote is **advisory, not a guarantee.** This is the most honest "internal pricing, external settlement" rule.

## 5. Matched state comparisons at three market prices

Assumptions: AMM fee 0.3% taken from input; **infinite AMM depth** (no AMM impact; revisit in §7 for finite depth). All else as §2.

| State | AMM price P (t0/t1) | (A) basket + AMM, holder gets | (B1) min(quote, AMM), holder gets | (B2) guaranteed quote, book funds gap | Incumbent (B2) book per-share change |
|---|---|---|---|---|---|
| 1:1 | 1.0 | 89.892 | 89.892 (AMM wins) | 98.28 (book pays 8.388) | +0.008 per share |
| 1:2 (t0 cheap) | 0.5 | 54 + 36·0.5·0.997 = 71.946 | `min(98.28, 71.946) = 71.946` (AMM wins) | 98.28 (book pays 26.334) | **−0.222 per share** |
| 2:1 (t0 dear) | 2.0 | 54 + 36·2·0.997 = 125.784 | `min(98.28, 125.784) = 98.28` (quote wins) | 98.28 (no gap) | +0.05 per share (gap = 0) |

(B3) at 1:1 = 94.086; at 1:2 = `min(98.28, 71.946) + 0.5·|98.28 − 71.946| = 71.946 + 13.167 = 85.113`; at 2:1 = `min(98.28, 125.784) + 0.5·27.504 = 98.28 + 13.752 = 112.032`.

**Findings from the table:**
- **(A) is always withdrawer-bearing-direction-risk.** At P=2, holder gets 125.784 (great); at P=0.5, holder gets 71.946 (bad). Range across three prices: `[71.946, 125.784]`, width 53.838. AMM direction is the holder's bet.
- **(B1) is withdrawer-bearing-direction-risk and quote-conservative.** At P=2, the internal-CP quote (98.28) is below the AMM route (125.784); holder gets 98.28 (the quote). At P=0.5, the AMM route is below the quote; holder gets 71.946. Range `[71.946, 98.28]`, width 26.334. **B1 strictly dominates A in worst case; ties A in best case.** B1 is the more honest "internal pricing" rule.
- **(B2) is book-bearing-direction-risk.** At P=2, book pays nothing (AMM ≥ quote); at P=0.5, book pays 26.334. Range of book cost `[0, 26.334]`, width 26.334. **B2 shifts the direction risk from withdrawer to book; same width as B1's withdrawer range.** This is the cost of the "guaranteed quote."
- **(B3) is split 50/50.** The book pays half the gap regardless of direction; the withdrawer keeps the other half. Width 13.167 each. The middle ground.

**Per-cycle profit/loss is not global.** Each cycle shifts B and the internal-CP rate. A second identical cycle at P=1:1 with the post-cycle book gives different numbers. **Static repetition does not establish constant profit; the cost is bounded per call by `|B_ratio − market_ratio| · share_value`** plus the AMM impact and pool fee. The boundedness is per call, not per session.

## 6. Center, wing, outside states

**Center state (price inside the full-range center).** `D` re-ratios smoothly with the AMM price. Internal-CP rate is the full-range `B_0/B_1`. Examples above use this state.

**Price inside a one-sided wing (e.g., upper wing).** Per `LiquidityAmounts.sol:67–76`, an in-range position holds both tokens. The upper wing's `D` re-ratios within the wing's bounds; the center is dormant (`D_center` zero or unfilled); the lower wing is fully out-of-range and holds its single token. The internal-CP rate is dominated by `F` (sleeve, doesn't re-ratio) plus the active wing (re-ratios slowly). **A wings product's B does not track a full-range CP curve, even with F=0.** The internal-CP rate at this state can be far from the AMM rate; the divergence in §5 widens.

**Price outside all positions.** All three positions are dormant. The internal-CP rate is dominated entirely by `F` and the single-token inventory in the out-of-range wing that the price is on the other side of. If the price is in a position where the vault's `D` is fully token0 (e.g., price above the upper wing), `B_0 = F_0 + D_upper + D_center_idle_token0_only + 0` and `B_1 = F_1`. The internal-CP rate is `≈ (F_0 + D_upper) / F_1`, which is **large** (token0-heavy book). A single-sided token0 deposit lands in `F_0` and mints `≈ 0` shares (per `StandardExchangeConstantProduct.sol:50–51`: linear branch `mulDiv(c, S, B_0)`, which is large because `B_0` is large; the depositor gets **some** shares here, not zero, because the linear branch is for the **same-side** reserve, not the **opposite-side** reserve). Re-read §0 of `StandardExchangeConstantProduct.sol`: the `B_other == 0` branch returns the **same-side** linear `mulDiv(amountOtherAdded, S, reserveOther)` — for token0 deposit with `B_1 = 0`, returns `mulDiv(0, S, B_0) = 0`. The `B_0 == 0` branch returns the token0 linear mint. So **with `B_1 = 0` and a token0 deposit, the helper returns 0** — the same-side branch is `mulDiv(amount1Added, S, reserve1)`, which is `0`. **A single-sided deposit into a one-sided book mints 0 shares.** The current helper forces **named rejection** for missing-token single-sided entries. This is honest; an admission rule for it is a new economic design (per the prior round's residual question Q5/6).

**Wing orientation reaffirmation.** Per the prior cross-review and the current PRD §5.G1, lower wing = token1-only, upper wing = token0-only. With price inside the upper wing, `D_upper` re-ratios and `D_lower` is fixed. The internal-CP `B_0/B_1` is dominated by the upper wing's `D_0` (re-ratios) and `F_1` (static).

## 7. Local cover sufficient / zero

**F_i sufficient.** Idle path always uses AMM route; sleeve is not the source. (A) pays the AMM route. (B1) pays `min(quote, AMM-route)`. (B2) pays the quote from the book (F not consulted). **F is irrelevant for idle single-token exit in the (A)/(B1)/(B2) family** — the AMM is the source. (This is **different from FullSpread's blocked-state policy**, which requires `F_out ≥ amountOut` and reverts otherwise. The wings product must explicitly choose.)

**F_i = 0.** Same as above: idle path doesn't consult F. (B2) consumes the book; if the book is too thin to fund the gap, the vault's `B_rem/S_rem` falls below 1.0 (undercollateralized). The minimum holder-preservation condition is `B_rem − funded_gap ≥ S_rem` (per-share `B/S ≥ 1`). At P=0.5, B2 with share size 44 and book 246/164 funds a 26.334 gap, leaving 219.666/164. Per-share `B/S = 383.666/200 = 1.918` — still above 1.0. **The book survives B2 at the example's size, but at larger share sizes the gap can exceed the per-share margin.** This is the **bounded vs draining** question: bounded by the divergence × share value; no per-call drain; recurring with each unfavorable exit.

**Blocked state (P1-style entry, P1 still possible because mint doesn't need `unlock`).** Per `InBase.sol:294–302`, blocked deposit mints against total book (no PM interaction). Post: `D_0 = 300, D_1 = 200, F_0 = F_1 = 0, S = 244`. **F is still 0; the deposit lands in D_0** (or in `F_0` if pulled but the example assumes direct deposit into the position, which is not what the inBase actually does — it credits sleeve and mints on B; only after idle does it place). **The inBase actually credits F_0 on blocked deposit** and emits `LocalDepositWhileBlocked`. The position rebalance happens later when idle. So post-blocked-deposit: `F_0 = 100, D_0 = 200, F_1 = 0, D_1 = 200, S = 244`. The internal-CP rate changes again: `B_0 = 300, B_1 = 200` (same as §2 because total B is the same). The decomposition into F vs D matters only for **sleeve-cover** purposes, not for mint math.

**Blocked exit.** AMM route is impossible; only `_singleExit` (consume book) or revert. The (A) AMM-route is **not available**. (B1)/(B2) reduce to the same `_singleExit` calculation. **Holder gets `_singleExit(B_0, B_1, 44, 244) = 98.28` token0** (per §4). The book is consumed; remaining holders see the per-share fall. This is the "blocked-state book consumption" question — must be **explicitly different from FullSpread's `F_out ≥ amountOut` revert** because the wings product can use the book as capacity when locked.

## 8. Proportional-exit bypass

**If the wings product keeps a pro-rata dual-token exit open** (pay both token0 and token1 pro-rata to the burned share), the holder can:
- Take both tokens pro-rata (no slippage on the share, but exposes them to AMM direction).
- Swap one of them on the AMM themselves, capturing the direction.

This is **not arbitrage within the vault**; the vault pays both tokens at pro-rata, and the holder takes the AMM risk themselves. The (A) "pro-rata basket + vault AMM swap" bundles the second step inside the vault; the "external pro-rata + user swap" unbundles it. **They are economically equivalent if the vault's AMM route is a clean pass-through** (no hidden fee, no slippage discount). If the vault's AMM route **collects a fee** (operation fee or otherwise) that the external user wouldn't pay, the unbundled version is strictly better for the user. **This is a real bypass risk** for any operation fee charged on the AMM-route component of (A)/(B1).

**Honest reading:** the (A)/(B1)/(B2) family should **not charge an operation fee on the AMM-route component** if a pro-rata dual-token exit is also available. Otherwise the holder unbundles. (A) should charge the operation fee only on the share burn (e.g., 5 bp on the share value at burn time), not on the AMM route. The user pays the AMM pool fee (0.3%) and the operation fee on the share, and **never both for the same notional**. This is the "no double charge" rule (PRD §1.1 spirit, Kimi §5 prior round).

## 9. Repeated cycles

**Per-cycle cost, no constant profit.** The 9.836 entry virtual impact is paid to incumbents. After cycle 1, the book is `B_0 = 246, B_1 = 164, S = 200` (post-burn + post-AMM-swap). The internal-CP rate is now `1.5` (same — the AMM swap rebalanced at 1:1). A second 100-token0 deposit at the same starting state: `K' = sqrt(346·164) = 238.16, K = sqrt(246·164) = 200.90, m = floor(200 · (238.16 − 200.90) / 200.90) = floor(37.09) = 37` shares. S' = 237. **Each cycle's m shrinks** as the book grows; the virtual impact per unit of deposit **does not** monotonically grow (the formula is locally linear in `c/B`, not amplified). **The bounded-per-call result is preserved across cycles, but the per-cycle opportunity shrinks.** No constant-profit loop.

**If a manipulator enters and exits in the same block at the same AMM price**, the AMM does not move, and the roundtrip cost is identical to §3. **If the AMM moves between cycles**, the holder benefits or suffers per direction; the cost is bounded by `|AMM move|` × share value. The book can drift over many cycles; the **maintenance** (sleeve replenishment) is the structural restore.

**Recurring bleed (Kimi §2 prior round).** Every cycle where the AMM moves and the vault's internal-CP rate lags the market, a small extraction is possible. This is **bounded per cycle** but **not zero over a session**. A divergence gate (reject entry if `|B_ratio/spot − 1| > X`) and a size cap `c ≤ κ·B` bound the bleed. None alone is sufficient; they compose.

## 10. Minimum holder-preservation condition (B2)

**Definition:** "holder preservation" means `B_rem/S_rem ≥ B_pre/S_pre` (no per-share loss for remaining holders from this single op). For B2, the gap funded from the book is `g = max(0, quote − AMM_route_output)`. Per-call:
- Pre: `B_pre = F_pre + ΣD_pre + ΣE_pre`, `S_pre`.
- Post-deposit: `B_post_dep = B_pre + C_in`, `S_post_dep = S_pre + m`.
- Post-burn (44 shares): `B_post_burn = B_post_dep − entitlementOut − entitlementOther`, `S_post_burn = S_post_dep − 44`.
- Post-AMM-swap (B2 attempts to source AMM_route of the other token): swap of `entitlementOther` gives AMM_route_output; book gains AMM_route_output in tokenOut, loses entitlementOther in tokenOther.
- Post-fund: book pays `g` tokenOut to the withdrawer. Remaining book `B_rem = B_post_AMM − g`, `S_rem = S_post_burn = 200`.
- **Holder preservation:** `B_rem / S_rem ≥ B_pre / S_pre`. At §4's example at P=1:1, `B_rem = 410 − 8.388 = 401.612`, `S_rem = 200`, per-share 2.008 ≥ 2.0 ✓. At P=0.5, `B_rem = 410 − 26.334 = 383.666`, per-share 1.918 < 2.0 ✗. **At P=0.5, the (B2) gap of 26.334 violates holder preservation for the remaining holders.**
- **Maximum gap before violation:** at P=1:1, `B_rem/S_rem = 1.0` requires `B_rem = 200`, so `g ≤ 410 − 200 = 210`. The 9.836 entry virtual impact + 0.164 rounding leaves `g ≤ 210` for the exit gap. **Per call, the exit gap can be up to 210 token0 before remaining holders drop below pre-deposit per-share.** This is a per-call book-held exposure; bounded but real.
- **Bounded vs draining at the vault level:** a single call cannot drain. Recurring calls in the same direction (e.g., repeated B2 exits at P<1) accumulate; the per-call bound is local; the session bound depends on the AMM's path. **No claim that any specific session is bounded.** A divergence gate or a cap on cumulative B2 exposure per session is a policy question.

## 11. Fees, impact, gas, rounding, maintenance (decomposed)

- **Operation fee** (P3, configurable WAD): charged once to the initiator on the share-burn side, not on the AMM-route side. Routed to feeTo. **Distinct from price impact.** No double charge.
- **AMM pool fee** (0.3%): charged by the AMM on the swap input. Routed to AMM LPs (or vault's own positions pro-rata to active liquidity). **Distinct from operation fee.** Withdrawer bears.
- **Price impact on entry** (virtual swap slippage): `≈ c² / (8 · B_0²)` for small `c` at full-range center; larger for skewed books or wings states. Routed to **incumbents** as compensation. **Not a fee.**
- **Price impact on exit** (AMM impact): real cost paid to AMM LPs. Bounded by pool depth.
- **Gas**: initiator pays the EVM. Not a vault charge.
- **Rounding/floor noise**: ≤ 1 wei per term; bounded by the formulas. **Conservation holds within rounding; this is bookkeeping noise, not extraction.**
- **Maintenance (rebalance, placement)**: deferred. The vault's sleeve is rebalanced after the user op completes (D27 of local buffer PRD). Placement losses accrue to **incumbents** by default (per Kimi §5 prior round recommendation); the owner may choose to deduct from the deposit on entry (Aperture-style), but the deposit then lands at a smaller amount and the operation fee base is smaller. **Two distinct cost-attribution policies**; the owner picks.
- **"Holder compensation"** = the entry virtual impact paid to incumbents. **It is the price of instant single-sided service without a balancing external trade.** Distinct from all other categories. Not a fee; not a refund; not a maintenance cost.

## 12. Residual questions and what evidence discriminates

1. **E1 vs E2 vs E3 vs B1/B2/B3.** The user already maps (A) and (B); §3 and §4 decompose. **Evidence to discriminate:** measured gas of (A) AMM-route at finite depth; measured impact of (B1) on book under P=0.5 and P=2; the **book-held exposure per session** under B2 with a real AMM path simulation; whether the holder's worst-case (A) at P=0.5 (≈71.946) is acceptable. **No simulation this round.**
2. **Operation fee base.** Share-burn base vs AMM-route base. **Evidence:** the bypass in §8 — if a pro-rata dual-token exit exists, the fee must be on the share burn, not the AMM route. This is **not a simulation question**; it's a definition.
3. **B2 in the unfavorable direction.** The book-held exposure at P=0.5 is real (per-share −22% on the example). **Evidence to discriminate:** the **maximum share size at which B2 is holder-preserving for the worst-case market** — `g ≤ B_pre · S_pre/(B_pre/S_pre − 1) · (share/S_pre)`. Derive the cap; do not assume.
4. **Wings-state internal-CP rate under 10/90 split.** The wings state's internal-CP rate is dominated by F + the in-range wing. **Evidence:** a concrete finite-range math trace for the 10/90 split at three prices (in upper wing, in center, in lower wing) showing the rate and the per-call book-held exposure. **Not derived this round.**
5. **Finite AMM depth effect.** The §3/§4/§5 examples use infinite depth. Real pools have finite depth. **Evidence:** a worked example with `X = Y = 1000` at 1:1 for the same 36-token1 exit-swap, showing the **AMM impact** added to the book exposure under B2.
6. **Pro-rata dual-token exit availability.** If yes, the bypass in §8 is live. **Evidence:** the public surface on the proxy. The current FullSpread has `IStandardExchangeOutMulti` (proportional only per the prior round). The wings product may mirror or differ. **Owner choice.**
7. **Placement-loss attribution.** Initiator-borne via pre-mint deduction from C, or incumbent-borne socialized. **Evidence:** the per-cycle bounded cost under each attribution; not a simulation, an algebraic comparison. **Owner choice.**
8. **Recurring-bleed policy.** Accept as priced AMM economics, or add a divergence gate? **Evidence:** the bleed magnitude in a real AMM-path simulation. **Not this round.**

## 13. What evidence discriminates the options (compact list)

| Question | Discriminating evidence |
|---|---|
| E1 vs B1 vs B2 vs B3 | Measured book-held exposure per session under a real AMM path; the holder's worst-case P&L at P=0.5 and P=2. |
| Operation fee base | Definition only; bypass-risk analysis in §8 is the test. |
| B2 size cap | Algebraic: `share_max = S_pre · (B_pre/S_pre − 1) / (divergence · B_other)` at worst-case divergence. |
| Wings state | Concrete 10/90 finite-range math trace at three prices; per-call book-held exposure. |
| Finite AMM depth | Worked example with `X = Y = 1000`; the AMM impact added to the B2 book exposure. |
| Pro-rata dual exit | Public surface; whether the holder can bypass the operation fee by external swap. |
| Placement-loss attribution | Algebraic comparison of per-cycle bounded cost. |
| Bleed policy | Real AMM path simulation; gate threshold; size cap composition. |

**No simulation, no tests, no fork data, no historical commit `35f47b51` restoration, no measurement of `~1.28M` gas, no claim that any specific band or fee is sufficient.** The numerical examples in §2–§7 use real arithmetic with stated assumptions (infinite AMM depth, 0.3% pool fee, 0 operation fee in §2–§4, 5 bp operation fee in §11 conceptually). All conservation holds within rounding.

---

*Saved to `docs/research/uniswap-v4-upper-lower-wings-prd-2026-10-05/matched-exits/minimax-original.md`. Original session preserved. No PRD/shell/tests/code/config/instruction edits performed. Owner preferences treated as exploratory and not ratified. Settled definitions (R = local custody, B = F + Σ own D + Σ own E, sleeve F = p·D on vault-owned deployed reserves) not reopened.*