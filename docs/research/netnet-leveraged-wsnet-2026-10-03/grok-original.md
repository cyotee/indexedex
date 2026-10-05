# Grok — leveraged wsNET / USDG Morpho leg

Independent first pass, 2026-10-03. No peer reports, RPC, or live balances. No APR is claimed. PRD **v0.36** and plan **v0.10** were read; neither selects this leverage.

## Recommendation

Do **not** add this as a leg of the current NetNet–Pendle family. v0.36’s Morpho option is a **supply-only USDG lending SE**, chosen once in `PkgArgs.standardExchangeVault`. Borrowing and leverage are outside scope (PRD lines 172, 127, 334–338). The hook holds raw SE shares and must not manage a Blue borrower position.

If the owner still wants the sleeve, make it a **separate one-position strategy vault**, not a second DETF share and not two additive rate-provider assets. One Morpho Blue position, one share token, one equity definition. Two views may quote withdrawable collateral and borrowable USDG as **mutually exclusive** management headroom. They must not both enter NAV.

## What is actually on the table

Morpho Blue is an isolated market, not a vault wrapper. A position is `(collateral, borrowShares)` for one `MarketParams` id. Supply shares and borrow shares are different ledgers. `MorphoBlueStandardExchange_PRD.md:24–50` lends the **loan token only** and forbids `supplyCollateral`, borrow, repay, and flash loans. Steakhouse USDG is Vault V2, also not this position. Loopback is a third product: wsNET collateral, USDG loan, `TurboRouter` acting **on behalf of the user** and holding no funds after the call (`TurboRouter.sol:31–50,163–175`).

Vendored Blue math (package comments: v1.0.0):

- Debt assets = `toAssetsUp(borrowShares, totalBorrowAssets, totalBorrowShares)` (`SharesMathLib.sol:41–43`). Rounds **against** the borrower. Virtual shares `1e6` and virtual assets `1` make a zero-share market well-defined and leave a dust entitlement that is not redeemable (`:19–24`).
- Health uses that upward debt against collateral value rounded **down**: `collateral.mulDivDown(price, 1e36).wMulDown(lltv)` (Context7 `/llmstxt/morpho_llms_txt`, accessed 2026-10-03; `ConstantsLib.sol:8`).
- `price()` is loan raw per collateral raw, scaled `1e36`.
- Liquidation incentive is capped at `1.15e18` (`ConstantsLib.sol:14`). Liquidate and flash loan are separate entrypoints. TurboRouter does **not** flash-loan; it uses `onMorphoSupplyCollateral` / `onMorphoRepay` (`TurboRouter.sol:185–293`).

Loopback constants, dump not live-verified: LLTV `0.625e18`, router target `0.53125e18` (`LendingConstants.sol:24–32`). The target is a router revert after `turbo`, not a Morpho cap. A manual borrower can sit between target and LLTV.

## Oracle, wrapper, rebase

wsNET is a non-rebasing 18-decimal wrapper. `sNetOut = ws * index / 1e18` (`WrappedStakedNET.sol:7–16,79–86`). `index()` starts at `1e9` and rises only when `rebase` is processed (`StakedNET.sol:43–48,67–69,82–99`). A scheduled epoch that nobody has processed does not increase collateral value.

`LoopbackOracle.price` (`LoopbackOracle.sol:51–75`):

```text
credited = clamp(TWAP * 0.90, backingPerToken, 5 * backingPerToken)
price    = credited * index / 1e9 * 1e6
```

TWAP is WAD USDG per whole NET. Spot is only a divergence guard: if spot is more than 15% below TWAP, `price()` **reverts** (`:56–63`). That pauses borrows and liquidations that read the oracle. It does not lower credit.

So the oracle is neither spot, nor InverseBond’s `0.985 * backing`, nor a settlement quote. Below backing it **floors credit at NAV**, which can exceed both the pool and the buyback. Above about 5× backing it caps credit. A processed rebase raises `index` and therefore oracle value while the wsNET balance posted to Morpho stays fixed. Debt does not rebase. Interest accrues with the market IRM and utilization whether or not a rebase happened.

Distributor rate is `0` when premium `<= 1` or the TWAP reverts (`Distributor.sol:85–98`). Encumbering sNET does not create a premium, a rebase, or a bid.

## Headroom is not additive

Let `C` be posted wsNET raw, `B` upward debt in USDG raw, `P` the oracle price, `t` a configured target in WAD with `t < LLTV`.

Toy, ignoring Morpho floors:

```text
V = C * P / 1e36                         // USDG-raw oracle value
E = V - B                                // equity at oracle, not exit value
H = max(0, V * t / 1e18 - B)             // extra borrow to reach target
W = max(0, C - B * 1e36 / (P * t / 1e18)) // wsNET removable while staying at target
```

Executable `H` must re-read `toAssetsUp` after `accrueInterest`, then cap by **available loan liquidity**. A value headroom the market cannot fund is not borrowable. Executable `W` is the largest `w` such that the post-withdraw position still satisfies the target under Morpho’s down-rounded collateral and up-rounded debt. Binary search plus the same rounding is the algorithm. A closed `W` is not proved.

`W` and `H` spend the **same** slack:

- Borrow `H` and `W` becomes 0.
- Withdraw `W` and `H` becomes 0.
- At target, both are 0 while `E` can still be large.
- At zero debt, `W` is essentially all collateral and `H` is the target borrow. Adding oracle(W) to `H` double-counts.
- Between target and LLTV, target-headroom is 0 but the position may still be healthy. Above LLTV, `E` can be positive on a loose price and still be liquidatable, or the oracle can revert so health cannot be read.

Do not publish `W` and `H` as two rate-provider assets of one share token. A Weighted host that prices both will treat alternatives as a portfolio. The existing SE rate provider returns **0** when its preview fails (`StandardExchangeRateProviderFacet.sol:110–111`). A zero rate is not a safe “ignore this leg” signal and must not be the liability quote.

Fair shares, if any, should track **settlement-haircut equity**, not headroom:

- Zero-debt deposit of collateral increases `E` by the haircut value of what was actually posted. Mint on that increase.
- Deposit into a position already at target adds collateral and socializes the existing debt. That is acceptable only if shares are equity-pro-rata, not collateral-pro-rata.
- Deposit into an underwater position must not mint against vanished headroom. Specify: pause, or mint only if post-deposit equity is positive after haircut.
- Full withdrawal of `W` removes slack, not the residual encumbered equity. Burning shares by wsNET amount alone leaves the same debt on fewer shares.
- A target-LTV change reprices quotes. It must not rewrite historical share balances.
- Wallet donations are not Morpho collateral until `supplyCollateral(..., onBehalf)`. Unsolicited loan-token donations are not debt relief.

## Routes and who owns the debt

One vault position means **every shareholder owns the debt pro-rata**. A route does not open a private Morpho position.

| Route | Management, not a free swap | Debt |
| --- | --- | --- |
| NET in | Stake, wrap, `supplyCollateral` | Unchanged debt; LTV falls if the add is real |
| sNET in | Wrap, supply | Same |
| wsNET in | Supply | Same |
| USDG in | Repay borrow shares, not a lend-vault deposit | Debt falls; `W` rises |
| wsNET / sNET / NET out | Withdraw only executable `W`, then unwrap/unstake as requested | Debt stays with remaining shares |
| USDG out via borrow | `borrow` up to executable `H` | Debt rises; remaining holders keep that debt |
| USDG out via unwind | Free collateral only after debt is reduced, then convert | Debt falls only to the extent repaid |

Current family NET/sNET input is Keep-YT (PRD R03). Reinterpreting it as “loop wsNET” would silently replace that rule. USDG input today enters the selected SE. A repay directive is a different product.

**Only-USDG without conversion is not a close.** Borrowed USDG is an asset matched by new debt; paying it out does not reduce LTV. Idle USDG is not the position. TurboRouter’s unwind repays **shares** first, so Morpho has already reduced debt, then withdraws wsNET, unwraps, unstakes (looping because one staking touch can rebase), sells NET on the taxed V2 path, and reverts if proceeds `<` repay assets (`TurboRouter.sol:224–293`). That is conversion. A wsNET-only exit requires USDG from somewhere else to repay, or the same callback sale. A mixed exit can return some freed wsNET and some USDG only after the repay leg is funded. Buyback can replace the pool sale only under InverseBond’s own gates: one-way, capacity-capped, oracle-live, and priced at backing not at this oracle. It is not a reliable full-close venue.

Callback availability is not a flash-loan guarantee. `price()` can revert on divergence mid-unwind. Pool depth, 5% NET tax, buyback cap, and Morpho liquidity are limits. A full close that cannot buy enough USDG must revert, not leave a half-repaid position unless the product explicitly allows a partial repay that stays healthy.

## Why encumbrance is not a floor

Locking a majority of sNET in one borrower position removes float. It does not bid. The standing bid is InverseBond, below NAV, capped, and unavailable when the TWAP gate fails. Locked collateral cannot hit that bid until someone unwinds it. The unwind sells into the same pool the thesis was trying to protect.

Reflexivity: interest raises `B` with no rebase; a processed rebase raises oracle value only if Distributor actually mints, which it will not at or below NAV. A market dump can make `price()` revert, freezing liquidations, or later lower TWAP credit and make the concentrated position liquidatable. The liquidator seizes wsNET and sells NET, adding supply the lock had removed. One position is one liquidation. That is concentration risk, not a mechanism that “prevents market NET below buyback NAV.”

## Architecture choices the owner must make

1. **Reject for this family** (recommended). Keep v0.36’s supply-only lending SE distinct from Loopback and from Blue supply-only SE.
2. **Separate sleeve vault** if researched further: borrower is the diamond; shares claim haircut equity; `W` and `H` are views; target LTV is vault-enforced and below LLTV by more than one interest interval with zero rebase. Do not inherit TurboRouter’s user-owned position.
3. **Do not** use two rate providers as two assets, two DETF legs, or a hook pair. The current four-leg hook has no borrower liability and must not learn one through a zero rate.

Unresolved before any spec: which market id, whether Loopback’s oracle is accepted despite NAV-floor credit, the settlement haircut versus oracle `E`, socialized debt on deposit, underwater redemption, and whether USDG-out means borrow or convert. None of those is selected. No safety or yield is promised.

**Confidence:** high on Blue share rounding, non-additivity of `W` and `H`, rebase-versus-interest, and the family exclusion. Medium on Loopback decimal composition as written in the dump. Low on live market liquidity, utilization, and oracle divergence. Sources: PRD v0.36 lines cited; `SharesMathLib.sol`; `ConstantsLib.sol`; `LoopbackOracle.sol`; `LendingConstants.sol`; `TurboRouter.sol`; `WrappedStakedNET.sol`; `StakedNET.sol`; `Distributor.sol`; `MorphoBlueStandardExchange_PRD.md:24–50`; Context7 Morpho docs, 2026-10-03.
