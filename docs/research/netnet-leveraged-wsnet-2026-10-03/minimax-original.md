# MiniMax M3 — Leveraged wsNET/USDG Morpho Leg (independent first pass)

Independent, no peer artifacts read. Sources cited at path:line. PRD v0.36 selected USDG leg is **PkgArgs.standardExchangeVault** (whole-PkgArgs salt, hook fixed by package); current lending option is **supply-only** (`MorphoBlueStandardExchange_PRD.md:42–50`, D6); leverage is not in scope and Morpho borrowing is explicitly out of scope (PRD §2.3:172). The user's proposal is a *new* shape that crosses the existing v0.36 supply-only SE with leverage; this round maps the source-backed math, identifies which parts of the proposal can be done on top of the v0.36 surface, and surfaces the parts that the PRD/SE PRD forbid or that would silently re-authorize the family.

## 1. Source-traced facts (no live state)

- **Morpho Blue market for wsNET collateral / USDG debt (Loopback):** `marketId = 0xaa586d26a6fe62d9c0f0948fede6e2130500ac7a655587447e2d4a37e6330589` (per `docs/detf/NET_MORPHO_USDG_LENDING_STRATEGY_PRD.md:49` and `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`). `loanToken=USDG`, `collateralToken=wsNET`, `oracle=LoopbackOracle`, `LLTV=0.625e18` (`LendingConstants.sol:26`), `IRM=AdaptiveCurveIRM`. **G1 unverified live**; same posture as PRD §2.1.
- **LoopbackOracle price quote** (`LoopbackOracle.sol:51–76`):
  ```text
  price() = clamp(TWAP × (1 − h), floor, C × floor) × index × 1e6
        with h = 10% (HAIRCUT_BPS=1000), C = 5 (PREMIUM_CAP=5),
        floor = treasury.backingPerToken(), index = sNet.index(),
        result scaled 1e36 (USDG-loan-units per wsNET-collateral, 1e24 effective)
  ```
  Fail-closed on TWAP-window invalid (`:53–54`) and on `spot < TWAP × (1 − DIVERGENCE_BPS)` with `DIVERGENCE_BPS=1500` (`:60–64`, `LendingConstants.sol:22`).
- **wsNET wrapper** (`WrappedStakedNET.sol:79–86`): non-rebasing, 18-dec. `sNetToWs(s)=s×1e18/index`; `wsToSNet(w)=w×index/1e18`. Rebase is purely an `index` read; the wrapper's own balance is fixed in wsNET units.
- **Staking** (`Staking.sol:1–161`): 8h epochs, `rebase()` distributes prior-epoch profit and pulls the next epoch's Distributor mint (`:129–151`). `STAKING_WARMUP_EPOCHS=0` is the deployed config (`Constants.sol:29`). sNET rebases linearly while total supply stays constant; `index` starts at `1e9`.
- **TurboRouter loop/unwind** (`TurboRouter.sol:163–294`): stateless, immutable. `turbo(wsIn, borrowAssets, minWsFromLoop)`: supplyCollateral → borrow → swapExactTokensForTokensSupportingFeeOnTransferTokens USDG→NET (5% tax by design, `:207`) → `zap.zap(net.balanceOf)` → wsNET back to morpho collateral. `unwind(repayShares, wsCollateralOut, minUsdgFromSale)`: repay → withdrawCollateral → unwrap → rebase-bounded loop `staking.unstake` → swap NET→USDG (5% tax) → repay from proceeds + surplus to caller. **Each is one transaction, no flash loan.** Refuses `_currentLtvWad > TARGET_LTV_WAD = 0.53125e18` after `turbo` (`:180–182`).
- **Morpho Blue position** (`IMorpho.sol:6–33`, `:146–239`): each `(user, marketId)` has `(supplyShares, borrowShares, collateral)`. `borrow()`/`repay()` operate on borrow shares (interest-accruing); `supplyCollateral()`/`withdrawCollateral()` operate on collateral. `borrowAssets = ceil(borrowShares × totalBorrowAssets / totalBorrowShares)` (Morpho docs, attested in TurboRouter `:319`). **`setAuthorization` is per-user-per-router** (`IMorpho.sol:278`); a router cannot borrow on a user's behalf without prior one-time authorization.
- **Distributor** (`Distributor.sol:43–69`): `nextReward` mints NET from treasury gated by TWAP and capped by `treasury.rfv() − supply × NET_UNIT`. **A stale TWAP mints 0** (`:88–92`), not reverts.
- **MorphoBlueStandardExchange** (`MorphoBlueStandardExchange_PRD.md:1–385`): **D6 supply-only**; no `supplyCollateral`, no `borrow`, no `repay`, no `liquidate`, no `setAuthorization`. The PRD explicitly rejects mixing borrow/supply in v1 (`:50`, `:367`). Its DFPkg binds **one Morpho market per vault at deploy** (D4), validated as an existing market (D28). Its NAV is `idle loanToken + expectedSupplyAssets(morpho, marketParams, this)` (D13), with `maxWithdraw = idle + free liquidity = expectedTotalSupplyAssets − expectedTotalBorrowAssets` (D18). **No rate provider treats the supplied amount as the borrower's collateral**, because the SE has no borrow position to value.

## 2. Borrow vs lender: why "ONE vault with two rate providers" is incoherent

The proposal collapses **lender** and **borrower** roles into one vault. Morpho Blue enforces a per-user-per-market position model; **the lender's position and the borrower's position are separate `Position` records** keyed by `(Id, user)`. The v0.36 SE is the **lender** (no collateral, supplies USDG). The user's proposal would have the SE also be a **borrower** (deposits wsNET, borrows USDG). These are not "two bound Rate Provider valuations of the same thing" — they are two *opposite* balance-sheet positions with different risk vectors and different P&L signs.

A single IndexedEx diamond cannot simultaneously be the supply position holder (no collateral) and the borrow position holder (wsNET collateral + USDG debt) on the same market, because:

1. **Morpho is singleton per market.** The SE is the lender *address*. If the SE also tries to be a borrower, it would need to call `borrow()` against its own lender position — the borrowed USDG would be delivered to the SE, then redeposited on top of its own supply, which mixes lender- and borrower- cash flows in the same balance.
2. **A diamond address is a single `Position` per market.** There is no Morpho primitive to maintain both a "supply book" and a "borrow book" with independent valuations in the same Id. The two are necessarily tracked under the same `position(id, address(this))` slot.
3. **Rate provider semantics differ.** The lender's rate is `totalAssets` over time (Morpho supply APY). The borrower's rate is `borrowShares × totalBorrowAssets / totalBorrowShares` growing over time (Morpho borrow APR), and the borrower's health is `LTV = debt / (collateral × oraclePrice / 1e36)`. These are not "two valuations of the same cash-flow"; they are valuations of opposite cash-flows with opposite sensitivities to `index`, TWAP, USDG pool liquidity, and rebase pace.
4. **Authorization model.** `setAuthorization` is per `(authorizer, authorized)`. If the SE is to be a borrower, the SE itself must hold the authorization against the user (or vice versa) — there is no Morpho API for a third party to manage another's borrow position without explicit per-user authorization. A "vault manages the borrow" abstraction requires the *user* to authorize the SE (or a router the SE owns) for every position.
5. **Liquidations.** If the SE is the borrower, the *SE*'s position gets liquidated, and a Morpho liquidator seizes wsNET collateral (the SE's). The lender path (supply-only) has no liquidation. Mixing them means the lender's USDG can be lost to a borrow-side liquidation event — capital that the lender's share-price calculation did not include as a risk.

**Conclusion (Section 2):** the v0.36 SE cannot be both lender and borrower on the same market. The user's "ONE vault" framing conflates the two. A bounded first version must separate the products.

## 3. Two bounded alternatives that fit the family

### 3.1. Option A — Leverage as a **separate family/separate DETF** (recommended for first version)

The borrow side is a **NetNet-user-facing loop vault** (analogous to TurboRouter) that uses Morpho Blue directly, with the user's prior `setAuthorization` (or via a per-user `MorphoBlueBorrowerProxy` if delegation is needed). It is **not** a Standard Exchange; it does not sit on the family HLP USDG leg. The v0.36 supply-only SE remains unchanged. The two products (lender SE + borrower vault) are independent markets and balance sheets.

### 3.2. Option B — Add a **Morpho Borrow Standard Exchange** (per-market, one-borrower-per-vault)

A second `MorphoBlueStandardExchange_PRD` sibling for the **borrow side** with a different `MarketParams` binding (loan=USDG, collateral=wsNET, oracle=LoopbackOracle, lltv=0.625e18). D6 must be re-opened for the borrow PRD: include `supplyCollateral` (deposit wsNET), `borrow` (draw USDG), `repay` (return USDG), `withdrawCollateral` (return wsNET), and Morpho `setAuthorization` *to the SE* for each participating user. The SE holds *one* position per (user) at a time, on the *one* bound market. The rate provider exposes a "borrow LTV" view (collateral × oracle price / 1e36 vs debt) distinct from the supply-side rate.

**Both alternatives require the v0.36 SE to NOT be the borrow position.** Mixing the two in one diamond violates the v0.36 D6 supply-only contract and the per-position Morpho accounting model. A custom hybrid would require writing a fundamentally new package (e.g., `MorphoBlueDualStandardExchange`) that explicitly re-opens D6 and the rate-provider interfaces — a non-trivial PRD extension, not a Round-3 amendment.

## 4. Per-leg unit analysis (where the proposal *can* plug in)

For Option A (recommended):

| Leg | Token | Decimal | Provider view | Source |
|---|---|---|---|---|
| Collateral | wsNET | 18 | `value = collateral × oracle.price() / 1e36` USDG-loan-units | `LoopbackOracle.sol:51–76` |
| Debt | USDG | 6 (constant comment; live `decimals()` unverified) | `value = borrowShares × totalBorrowAssets / totalBorrowShares` | `IMorpho.sol:319`; `MorphoBalancesLib.sol:94–109` |
| Equity | none | n/a | `equity = collateralValue − debt` | n/a |
| Rebase source | sNET index | 9 | `sNet.index() / 1e9` | `IsNET.sol:22`; `WrappedStakedNET.sol:80` |
| Oracle floor | `treasury.backingPerToken()` | 18 | WAD USDG/NET | `Treasury.sol:114–118` |
| Oracle TWAP | `pairOracle.twapNetUsdg()` | 18 | WAD USDG/NET, fail-closed window 30min–4h | `InverseBond.sol:73`; `Constants.sol:27–28` |

**Headroom math (recommended for the borrow vault).** Let `V = oracle.price() × collateral / 1e36` (USDG loan units). Let `D = borrowShares × totalBorrowAssets / totalBorrowShares` (USDG owed). Then:

- `LTV = D / V` (must stay ≤ `LLTV = 0.625`).
- `targetLTV = 0.53125` (per `LendingConstants.sol:32`, the UX ceiling).
- **Collateral headroom** `W = (D / targetLTV) − V` = how much more `V` could fall before the user's tx would push the position above the target. Equivalently `W = (D / targetLTV − V) × 1e36 / oracle.price()` wsNET.
- **Borrowing headroom** `H = (V × LLTV) − D` = how much more USDG could be borrowed before reaching the LLTV. Equivalently `H = (V × LLTV − D)` raw USDG.
- **Equity NAV** `E = V − D`.

`W` and `H` are **not additive**: `W` measures slack on the *collateral value* axis, `H` measures slack on the *debt* axis. They satisfy `H + targetLTV × W × oracle.price() / 1e36 = 0` only at a single LTV point. Adding `W` and `H` as a "total headroom" is meaningless for vault share accounting; each axis has its own constraint (collateral-sufficient-for-debt vs debt-within-collateral). A user query like "how much USDG can I take out?" uses `H`; "how much wsNET can I withdraw safely?" uses `W` (after a `H → 0` recompute to account for any debt-paid-down).

## 5. Share accounting with headroom-as-NAV (per the user's framing)

The user proposes to use headroom as NAV for share valuation. **This fails for at least three reasons** in the Morpho model:

1. **Headroom is a per-position scalar, not a fungible asset.** Two users with the same `V` and `D` have the same `H` and `W`; users with different `V, D` have incommensurable headrooms. There is no "headroom token" to be a reserve backing; there is a per-user `Position` with a borrowed `borrowShares` and supplied `collateral`.
2. **Headroom is not a yield.** `H` is a slack, not a future return. Treating it as NAV means issuing more shares for the same collateral because there is "headroom," which is a free option for the new depositor at the expense of the existing borrower's safety buffer. This is the classic inflation attack (catalog A0).
3. **Donations would print infinite shares.** If `collateral` is donated to the position and `H` is the NAV, every new depositor mints at `0` total assets, capturing the entire donation. `MorphoBlueStandardExchange_PRD.md:71` D22 already rejects this for the *lender* side: "donations must not mint free shares to the next depositor (I1/A0)." The same rule must apply to the borrow side.

**A borrow-side vault that does NAV=headroom would be a hostile A0 vector** for the existing borrowers. The v0.36 PRD's existing donate-credit-with-reserve-delta rule (Plan §6.3, `LocalCreditLib`) is the correct pattern: incoming wsNET collateral must be accounted as a *deposit* that mints shares against the **pre-credit NAV** (D22 of the SE PRD), and incoming USDG debt repayment must *burn* shares for the user repaying, or be passed through without share minting if it is just a repay-without-deposit.

## 6. Fair share issuance/redemption with `collateral × price` as the asset

The borrow-side share should be **one share per unit of equity NAV**, where equity NAV is computed per-user against the borrower's position. For a multi-user borrow vault, equity is fungible only if positions are fungible; otherwise the vault cannot price its shares without an internal ledger.

**Cleanest design:** the borrow vault holds *one* position (one `borrowShares`, one `collateral`) per `Position.owner`, and shares are **non-transferable** (or transferred only alongside the underlying position). A multi-user aggregate would need either (a) a pro-rata accounting layer on top of the position, or (b) a separate vault per user (deployed at user-authorization time). Option (b) is the simplest and mirrors the way the v0.36 SE is per-market-not-per-user.

**Deposit into underwater state** (when `D > V × LLTV`): a new deposit must be either rejected or used to bring `D/V` below the new LTV. The current `setAuthorization` model does not give the SE power to "fix" a borrower's underwater position unilaterally; the user must call `supplyCollateral` themselves, or accept liquidation. The vault cannot "deposit into underwater state" on a third party's behalf.

**Zero-debt state**: `D = 0` means `LTV = 0` (in fact `type(uint256).max` in TurboRouter's view, but that is a degenerate edge case). At zero debt, `W = ∞` and `H = V × LLTV`. The vault holds wsNET collateral only; equity = `V`; shares can be redeemed for the proportional wsNET × `1e36 / oracle.price()`. This is the closest the model gets to "share NAV = collateral value," and it is the trivial unwind target.

**Dynamic LTV**: as `index` grows (rebase), `V` grows without `D` changing, so `LTV` decreases. As TWAP drops (oracle haircut widens the floor), `V` decreases (or the oracle fails closed). As interest accrues, `D` grows. As USDG rebase (which USDG does not have, but the canonical pair revalues USDG), `D` is unit-stable. **The LTV is not user-controllable; it is a function of the rebase pace vs the borrow rate.**

**Anti-dilution** for the *lender* side is already covered by the existing `MorphoBlueStandardExchange` A0/K1 tests (`:297`). For the *borrow* side, anti-dilution requires: new depositor mints at pre-credit equity NAV; donations do not mint; any pre-existing inflation from first-depositor manipulation is bounded by the same `MINIMUM_SHARES`/`MINIMUM_ASSETS` rule the lender uses.

## 7. Route-by-route token flows (for Option A, the separate borrower vault)

The user's question lists four token routes: NET, sNET, wsNET, USDG. The borrow vault's inbound surface is the **same one** that TurboRouter already uses: user calls `morpho.setAuthorization(vault, true)` once, then any of the following (each atomic, no flash loan):

| User intent | Token in | Token out | Mechanism | Source |
|---|---|---|---|---|
| Add collateral | wsNET | wsNET-collateralized-debt | `vault.supplyCollateral(caller, wsIn)`; `vault` measures delta; `morpho.supplyCollateral` | `IMorpho.sol:228` |
| Borrow more | (none) | USDG | `morpho.borrow(market, d, 0, caller, caller)` after collateral sufficiency; SE receives USDG; SE routes USDG to caller (or holds for loop) | `IMorpho.sol:190` |
| Repay | USDG | (burns borrowShares) | User `approve(vault, amount); vault.repayFromUser(amount)`; pull USDG, call `morpho.repay` | `IMorpho.sol:212` |
| Withdraw collateral | (none) | wsNET | `vault.withdrawCollateral(toCaller, wsOut)` after health check | `IMorpho.sol:238` |
| Loop (auto-supply after borrow) | wsNET+USDG | wsNET | `vault.turbo(wsIn, borrowAssets, minWsLooped)` → supplyCollateral → borrow → swap USDG→NET (5% tax) → `zap.zap` → wsNET as more collateral | `TurboRouter.sol:163–222` |
| Unwind (auto-repay from collateral) | wsNET-collateral+debt | wsNET or USDG | `vault.unwind(repayShares, wsCollateralOut, minUsdgFromSale)` → repay → withdrawCollateral → unwrap → rebase-bounded `unstake` loop → swap NET→USDG (5% tax) → USDG to caller (surplus) | `TurboRouter.sol:235–294` |
| sNET in | sNET | wsNET (collateral) | User wraps first via `wsNet.wrap(sNetAmount)`; then supplyCollateral | `WrappedStakedNET.sol:48–58` |
| NET in | NET | wsNET (collateral) | User swaps NET→USDG (5% tax) then USDG→... — no, NET→wsNET direct is via `zap.zap` which goes NET→sNET→wsNET. Then supplyCollateral | `Zap.sol:41–48` |

**Who owns the debt:** the **user's address** holds the `borrowShares` on Morpho. The vault has `setAuthorization(vault, true)` for that user, so the vault can call `borrow` and `repay` on the user's behalf, but the position (and any liquidation) is on the user's account. **The vault is a manager, not an owner.** This is critical: if the vault is "the borrower" instead of the user, the vault's address holds the position, and a liquidation seizes the *vault's* wsNET — which then becomes insolvent, and all users of the vault lose their collateral.

**Partial vs full unwind:** partial is supported (`:235–250`); full close uses `repayShares = full borrowShares` and `wsCollateralOut = full collateral`. The user must pre-compute `borrowShares` from the on-chain `position()` (a rebase or interest accrual between snapshot and tx can cause under-flow revert, per Morpho `IMorpho.sol:204`).

**Only-USDG attainable with conversion:** yes, via `unwind` — user gets USDG (surplus) and reduces wsNET. The `unwind` path always pays USDG because the NET leg is sold for USDG (5% tax fires). The user never gets NET back from `unwind`; they get USDG.

## 8. Oracle meaning: backing, market, wrapper index, decimals

`LoopbackOracle.price()` (`:52–76`) is a **derived** value, not a market spot. It is a 1e36-scaled USDG loan units per wsNET collateral, where:

- **TWAP (`pairOracle.twapNetUsdg()`)** is a time-weighted average of the canonical pair's USDG/NET price over 30min–4h.
- **`backingPerToken()`** is `treasury.rfv() / net.totalSupply()` where `rfv = liquidUsdg + morphoAssets × 0.98 + polRfv` (`Treasury.sol:106–118`). Backing is *intrinsic* NAV at the 1 USDG floor, not market price.
- **`PREMIUM_CAP = 5`** means above 5× premium, the oracle **pins to backing** (not market). This is the "euphoria governor": market pricing below ~5.6×, backing-anchored credit above.
- **`HAIRCUT_BPS = 1000`** applies a 10% haircut to TWAP, then clamps to the floor.
- **`sNet.index() × 1e6`** is the final scaling: `index` is the cumulative sNET growth (starts at 1e9), and the ×1e6 converts WAD → Morpho's 1e24-effective scale (per `LendingConstants.sol:36–39`).

**Wrapper index vs NET/USDG TWAP:** the oracle uses **sNet index** to scale TWAP-from-NET into TWAP-for-wsNET (`:75`). The sNET index grows as the staking program distributes NET emissions. The TWAP, in contrast, is the market price. **The oracle is `market_price(NET) × haircut, clamped to backing, scaled by rebase growth` — three different inputs combined.**

**Decimals:** wsNET 18, USDG 6 (constant comment, unverified live), sNET 9, NET 9. The oracle handles the cross-decimal scaling internally. **The rate provider exposed to the family** must perform the same scaling to surface a consistent value to the DETF/hook.

## 9. Processed vs scheduled rebases, premium emissions, IRM, liquidation, reflexivity

- **Processed rebase:** when `block.timestamp >= epoch.end`, anyone may call `staking.rebase()` (`Staking.sol:129–151`). `index` advances to the next epoch's distribution. **At most one rebase per call**, so a back-to-back loop catches up but each is one rebase.
- **Scheduled rebase:** every 8h (`EPOCH_LENGTH = 8 hours` per `Constants.sol:17`).
- **Premium emissions:** `Distributor._rateWad()` (`:86–99`) is `R_MAX × clamp((P−1)/(K−1), 0, 1)` where `R_MAX = 0.0045e18` (0.45% per epoch), `K = 1.75e18` (1.75× premium for full emissions). Above `P = 1` (par), emissions begin; at `P = 1.75` emissions are at `R_MAX`. **Stale TWAP mints 0** (`:88–92`).
- **IRM (Morpho):** `AdaptiveCurveIRM`, utilization-dependent borrow rate. As utilization rises, borrow rate rises; the 1.04× premium + 5% sell tax = ~10% per-loop cost; `LIF ≈ 12.7%` clears the 5% sell tax (`LendingConstants.sol:25–26` comment). **The user needs the rebase APY ≥ borrow APY + tax cost to avoid LTV decay.** A back-of-envelope check: rebase APY at premium `P` is roughly `R_MAX × ((P−1)/(K−1)) × 3 per day × 365`. At `P = 1.04` this is `0.0045 × (0.04/0.75) × 1095 = ~0.26%` annual, far below Morpho borrow APY in any normal regime. **At low premium, the loop is a value-extracting trap for the borrower.** Only at `P > 1.4` does rebase APY exceed 12% annualized. This is a hard economic constraint, not a parameter to tune.
- **Liquidation:** Morpho's `liquidate` (`:255`) seizes `collateral × liquidationIncentive` against `repaidShares × debt`. Anyone can call. If `D > V × LLTV`, the position is liquidatable. **The borrower's wsNET is sold at a discount to the oracle price** — typically a 5–10% slippage on top of the haircut. The user's proposed "encumber majority supply to sustain rebase and prevent market NET below buyback NAV" does **not** prevent liquidation; it makes the *protocol* a larger counterparty, but each individual position is still subject to the same `LTV > LLTV` check.
- **Reflexivity:** if Morpho borrow APY > rebase APY, every epoch the borrower's LTV creeps up; a single bad TWAP failure (oracle fail-closed) reduces `V` (oracle price drops to backing floor); a market dump triggers `spot < TWAP × (1 − DIVERGENCE_BPS)` and **the oracle reverts, pausing borrows and liquidations simultaneously** (per `LoopbackOracle.sol:21–27`). The "concentration" risk is: if one vault holds the majority of the wsNET supply as collateral and a single rebase epoch underperforms, all positions see the same LTV increase at the same time. There is no diversification; the user's "encumber majority" is a *systemic* risk concentration.
- **Why encumbered supply is NOT a price floor:** a high LTV means the borrower is *motivated* to add collateral (to avoid liquidation), not to *sell* wsNET. Encumbered supply reduces circulating supply, which *can* support price if demand is stable, but it does not (a) force a price floor (no `convert-and-burn` mechanism), (b) prevent liquidations, (c) prevent the oracle from failing closed, or (d) guarantee the rebase pace outruns borrow APY. The user's framing is plausible as a *secondary* effect but is not a price floor.

## 10. Same vault + 2 providers vs two independent claims (double-counting)

The user's proposed "ONE vault and two bound Rate Provider valuations" must be evaluated for double-counting. The two valuations the user names are:
1. **wsNET safely withdrawable to a configured target LTV** — this is a *collateral* view: how much wsNET can the user remove without breaching the target LTV?
2. **USDG additionally borrowable** — this is a *debt* view: how much more USDG can the user borrow without breaching the LLTV?

If the same vault emits two rates, the *numerators* (wsNET units; USDG units) are different assets. The *denominators* (shares) are the same. **The vault's totalAssets would be the sum of two values in different units, which is meaningless without a conversion factor.** Either:

- The vault is a *single*-asset vault, with one rate (e.g., `totalAssets = V − D` in equity USDG terms); then the user's two queries are derived views from the same rate provider, and "two providers" is misleading — there is one.
- The vault is a *multi*-asset vault with two rate providers (one for wsNET, one for USDG); then totalAssets is a *basket*, and share pricing requires a single composite NAV. The composite NAV must be well-defined at zero-debt and full-debt, and the rate providers must use the same oracle and the same index scaling.

The cleanest implementation: **one rate provider** that reports the equity NAV in USDG-loan-units (e.g., `(V − D) / supply`), and the "wsNET-withdrawable" and "USDG-borrowable" are **derived queries** computed at query time from the same `Position` data, not separate rate providers. This avoids the double-counting entirely.

## 11. Current hook zero-rate and capability compatibility

The v0.36 PRD explicitly states the current lending option is **supply-only** and not selected for leverage (§2.3:172). The current hook has **zero rate** in the borrow sense — it supplies USDG and earns Morpho supply APY, but does not borrow. Adding a borrow-side component to the *same* DETF coordinator would require:

1. Re-opening D6 of `MorphoBlueStandardExchange_PRD.md:50` to include `borrow/repay/supplyCollateral/withdrawCollateral/setAuthorization`.
2. Re-opening the v0.36 PRD's "current lending option is supply-only" to permit a borrow vault.
3. Resolving the position-ownership model: who is the Morpho borrower? (User? DETF? Hook? An EOA? The hook cannot `setAuthorization` on behalf of a user.)
4. Updating the HLP four-leg matrix: is wsNET a fifth leg? (PRD §4.4 lists four legs.) Is the borrow position itself an HLP custody leg? (No, because it is per-user not pooled.)
5. Verifying oracle scope: the current SE rate provider does not include a "wsNET collateral" view; a new rate provider is required.

**A first version should not attempt to integrate leverage into the existing v0.36 DETF/hook.** The compatibility surface is too small, and re-opening the PRD for a new vault (the borrow side) is a multi-week, multi-PRD effort.

## 12. Bounded architecture recommendations

**Recommended first version (Option A, separate DETF/family):**

1. **NetNet WsNET/USDG Leverage Vault** — a new Standard Exchange Diamond, per-user position model:
   - One position per user (deployed per user or single-instance with `setAuthorization` flow).
   - Bound `MarketParams` = `(USDG, wsNET, LoopbackOracle, AdaptiveCurveIRM, 0.625e18)`.
   - Owner-gated by the user (`setAuthorization`).
   - Surfaces: `supplyCollateral(wsIn)`, `borrow(usdgOut, maxBorrow)`, `repay(usdgIn)`, `withdrawCollateral(wsOut, minWsOut)`, `turbo(wsIn, borrowAssets, minWsFromLoop)`, `unwind(repayShares, wsCollateralOut, minUsdgFromSale)`, `currentLtvWad()`, `headroomW()`, `headroomH()`, `equityNavWad()`.
   - No HLP integration; no DETF integration; no rate provider used by family.
   - Does **not** change the v0.36 DETF, the SE PRD, or the family PRD.

2. **Explicit product decisions the owner must answer:**
   - **A.** Permit leverage as a *separate family*, not an extension of the v0.36 DETF.
   - **B.** Per-user single-position vault vs single-instance-with-many-positions.
   - **C.** Whether to enforce `LTV ≤ TARGET_LTV_WAD = 0.53125` on every operation (the TurboRouter UX guardrail) or only on `turbo` (current behavior).
   - **D.** Whether the new vault can be added as a fifth HLP leg, or whether the borrow is fully off-book.
   - **E.** Treasury / owner bypass: a) the family DETF holds the borrow position itself (concentrated risk); b) users hold their own positions (the family DETF is not exposed); c) a MixTEE/Multi-MEV-protected router mediates.
   - **F.** Whether to add an **insurance leg** — a separate reserve of USDG set aside to top up collateral in case of imminent liquidation, funded by a usage fee on successful loops.
   - **G.** Whether the new vault ever uses the InverseBond standing bid (the new vault borrows USDG, not NET; InverseBond is not on the borrow path).

3. **Explicit non-decisions** (carry forward from PRD v0.36):
   - v0.36 PRD's R25–R27 below-peg buyback is DETF-level, not Morpho-level. The new vault does not auto-buyback DETF or use InverseBond.
   - v0.36 PRD's R34 full feature parity is for the V2 SE. The new vault is a new package; it is not subject to R34.

## 13. Why encumbered supply is NOT a guaranteed price floor (explicit)

The user states the goal is to "encumber majority supply to sustain rebase and prevent market NET below buyback NAV." Each step is questionable:

- **Encumber majority supply:** if the new vault holds >50% of wsNET supply as collateral, *circulating* supply is reduced. Demand-side effects can support a price, but this is a market-structure argument, not a protocol guarantee. Other users can still sell their (non-encumbered) wsNET freely.
- **Sustain rebase:** the rebase pace is set by `R_MAX`, `K_WAD`, and the current premium `P` (per `Distributor._rateWad`). It is *not* a function of how much wsNET is encumbered. Encumbering supply does not change `P`; it only reduces circulating supply.
- **Prevent market NET below buyback NAV:** the buyback (`InverseBond`) is a USDG-for-NET standing bid at `backing × 0.985`. The market price of NET is set by the canonical V2 pool. Encumbering *wsNET* supply (which is a derivative of sNET, which is a derivative of NET) does not directly affect the NET/USDC pool's depth. wsNET encumbrance is correlated with NET encumbrance only via the wrap/unwrap rate, which is not automatic. **The buyback NAV is `backingPerToken()`; if backing rises (because the new vault deposits USDG to the treasury? — the new vault *borrows* USDG, it does not supply), the NAV rises and the buyback price rises. But the new vault's borrow is not a treasury supply; it is a Morpho-market loan against the user's wsNET collateral. The treasury's USDG balance is unchanged. The buyback NAV is unchanged by the borrow.**

**The proposal's economic argument is not supported by the source mechanics.** It would require (a) the new vault to *supply* USDG to the treasury (separate from its Morpho borrow) and (b) the borrow APY ≤ the rebase APY (a market-state-dependent condition). The first is a product decision; the second is a hard economic constraint.

## 14. Confidence, gaps, evidence

- **High confidence:** borrow side is per-user on Morpho; supply side is per-market on Morpho; v0.36 SE is supply-only (D6); v0.36 PRD explicitly defers leverage (PRD §2.3:172); `setAuthorization` is per-user; `targetLTV` guardrail is `0.53125e18`; LLTV is `0.625e18`; oracle is fail-closed on TWAP-band and divergence; `price()` clamps to `5 × floor` premium cap with 10% haircut; sNET index is the rebase accumulator; wsNET 18-dec, sNET 9-dec, NET 9-dec, USDG 6-dec (constant comment, unverified live).
- **Medium confidence:** the family PRD's "current lending option is supply-only" can be re-opened for a *separate* product (Option A); the v0.36 DETF/hook does not need to change for Option A; a per-user single-position vault scales linearly with users.
- **Low confidence:** deployed Morpho code-identity match (G1 pending per `MorphoBlueStandardExchange_PRD.md`); live `decimals()` for USDG; live state of the `0xaa586d26…` market (free liquidity, IRM parameters, oracle, current index, premium); live `setAuthorization` permissioning for TurboRouter-style flows.
- **Counterexample / dissent to be aware of in cross-review:** peers may argue that a single SE with two rate providers *can* be made coherent. It cannot, because the lender and borrower positions are different `Position` records on Morpho, and a single IndexedEx diamond is one address = one position per market. The v0.36 SE PRD's D6 is non-coincidental; it reflects the source-level constraint, not an arbitrary choice.

## 15. Saved path

Written to `docs/research/netnet-leveraged-wsnet-2026-10-03/minimax-original.md`. No other writes. No shell, no tests, no config, no implementation. No peer artifacts read this round. Originals frozen for cross-review.

## Sources cited (path:line, version)

- PRD v0.36 `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md:7,22–32,127,165–168,172,210,233–240,242,289–325,338,353,453–471`
- Plan v0.10 `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md:7–13,20`
- `lib/crane/contracts/protocols/pol/net/src/perp/WrappedStakedNET.sol:7–122`
- `lib/crane/contracts/protocols/pol/net/src/perp/Zap.sol:1–49`
- `lib/crane/contracts/protocols/pol/net/src/lending/LoopbackOracle.sol:11–88`
- `lib/crane/contracts/protocols/pol/net/src/lending/TurboRouter.sol:1–330`
- `lib/crane/contracts/protocols/pol/net/src/lending/LendingConstants.sol:9–40`
- `lib/crane/contracts/protocols/pol/net/src/Staking.sol:1–161`
- `lib/crane/contracts/protocols/pol/net/src/Distributor.sol:1–108`
- `lib/crane/contracts/protocols/pol/net/src/Treasury.sol:84–118`
- `lib/crane/contracts/protocols/pol/net/src/Constants.sol:11–79`
- `lib/crane/contracts/protocols/pol/net/src/interfaces/IsNET.sol:1–29`
- `lib/crane/contracts/external/morpho/blue/interfaces/IMorpho.sol:6–353`
- `lib/crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol:94–109`
- `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_PRD.md:1–385` (D6:50, D13:61, D18:66, D22:71, D28:81, D36:99, D37:100, A0/K1:297, supply-only:367, per-market:42–50)
- `docs/detf/NET_MORPHO_USDG_LENDING_STRATEGY_PRD.md:1–80` (S01 sleeve)
- `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`
- Peers: not read this round (originals frozen).
