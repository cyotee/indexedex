# Grok cross-review — leveraged wsNET vault

Originals frozen. Peers are untrusted. PRD v0.36’s supply-only rule is a permission boundary, not proof that a pooled borrower vault is impossible. The user asked for one pooled borrower with two **alternative** bound valuations and route signals, not a lender-plus-borrower product and not two claims that must be added.

## Agreement

Blue debt for health and share-repay is `toAssetsUp` with virtual offsets `+1` assets and `+1e6` shares (`SharesMathLib.sol:20–43`; `Morpho.sol:283–284,532–536`). TurboRouter’s LTV view omits those offsets and does not accrue (`TurboRouter.sol:312–323`). Do not copy it. `W` and `H` are one slack. Equity `E = V - D` is not headroom. At the configured target both headrooms can be zero while `E` is positive (Astra’s `C=100,p=1,D=50,τ=0.5`). Zero debt: withdrawable collateral is `C`, not infinity, and borrow headroom is `τV` capped by cash. Encumbering supply does not set the NET price or force emissions. Distributor rate is zero at or below NAV or on a stale TWAP (`Distributor.sol:85–98`). Processed rebase, not the clock, moves `index()` (`Staking.sol:134–150`; `StakedNET.sol:67–69`).

## Position, authorization, cash

**Correction to MiniMax.** `Position` is one record: `supplyShares`, `borrowShares`, and `collateral` (`IMorpho.sol:16–20`). One address can lend and borrow the same market. That does not make the user’s product a lender. A pooled vault should be the **borrower** (`onBehalf = vault`) and should not also supply the loan token on that market unless a later decision accepts the reflexivity. MiniMax’s “two Position records / diamond cannot borrow” claim is false.

Own-position calls need no `setAuthorization`: sender equals `onBehalf` (`Morpho.sol:467–468`). Borrow and `withdrawCollateral` require that check (`:247,331`). `repay` and `supplyCollateral` do **not**; a third party can repay or post collateral on behalf of the vault (`:269–319`). That gift raises equity for existing shares. It is not yield of funded participation and must not mint new shares. TurboRouter’s user-owned position plus authorization is a different product from a vault-owned pool.

**Cash.** New borrow reverts unless `totalBorrowAssets <= totalSupplyAssets` (`:259`). Collateral withdrawal has no liquidity check; it only requires health (`:335–337`). Borrow-out and collateral-exit are different constraints. Astra is right.

## Headroom identity

Continuous, same target `τ`, price `p` in USDG per wsNET:

```text
W = max(C - D/(τp), 0)          // collateral units
H = max(τpC - D, 0) = τp W      // USDG
τp x + y <= H                   // joint budget, not x<=W and y<=H
```

Astra’s integer forms match Morpho’s nested floors better than a raw `ceil(D/τ)`. Kimi’s `H + λ p W/1e36 = λV - D` is the same identity. Both use **target**, not LLTV. LLTV remains the liquidation line, not the management quote.

**Correction to MiniMax §4.** `W = D/targetLTV - V` is a **value shortfall**, negative when the position is inside target, and the text then says zero-debt `W = ∞`. Those cannot both be withdrawable collateral. At `D=0` the formula is `-V`, not infinity. `H` there uses LLTV, so it is not `τpW`. The later identity `H + targetLTV*W*price = 0` does not hold for that pair of definitions. Use Astra/Kimi `W` (wsNET raw, floored at 0). “How far V can fall” is a different, signed risk metric and must not be labeled withdrawable collateral.

Above target (`LTV > τ` but `V > D`) is positive equity, not insolvency. Liquidation can still happen while `V > D` because LLTV is 0.625, not 1 (`LendingConstants.sol:26`; health is `maxBorrow >= borrowed`, `Morpho.sol:535–538`). Kimi’s “underwater (`V<D`)” sentence mixes insolvency with a state Morpho may already liquidate at `D > τ_LLTV V`. Report three states: inside target, positive-equity above target, oracle-insolvent or LLTV-unhealthy.

## Shares, repay, unwind

Mint and burn against **pre-operation equity per existing share**, after accrual and actual receipts. Do not mint on `ΔW`. Astra’s repayment counterexample stands: a collateral deposit and an equal USDG repayment can change `W` differently while changing `E` the same. Headroom-priced issuance subsidizes one route.

Asset repay burns shares **down** (`toSharesDown`, `Morpho.sol:283`). It can leave borrow shares. That is not a full close and must not burn the vault’s last equity share. Share repay pulls assets **up** (`:284`) and can exceed `totalBorrowAssets` by 1 (`:290`). Full close passes outstanding **shares**, then debt is zero. No phantom “repay burned the debt” if shares remain.

`repay` reduces debt **before** `onMorphoRepay`, then pulls USDG (`:286–295`). After a full share repay, `borrowShares == 0`, so `withdrawCollateral` is healthy **without reading the oracle** (`:515–516`). A complete USDG close can sell that freed wsNET inside the callback and fund the pull. No external flash loan is required. Flash loan remains optional (`:422` area per Astra; not re-read this turn). Conversion can still fail on tax, impact, buyback cap, or divergence. Collateral-only exit needs repayment cash already in hand, or a sale of part of the collateral. “Never only USDG without conversion” is right for a debt-reducing USDG exit. Borrowing `H` pays USDG without conversion but **increases** debt; it is not a close.

Loopback price is `floor(creditedWad * index / 1e9) * 1e6` (`LoopbackOracle.sol:66–75`), with `index` a 9-decimal accumulator from `1e9`. MiniMax’s `clamp(...) × index × 1e6` drops the `/1e9` and mis-scales. Credited NAV is not the executable bid. InverseBond pays 98.5% of backing, capacity-capped, and can be gated off.

Rebase yield is index growth in oracle credit, not NET paid to the vault. `distributor.distribute()` fills the **next** queue (`Staking.sol:140–150`). New deposits must not be credited with donations or third-party `supplyCollateral`/`repay` that accrued to shares already outstanding.

## APR correction

MiniMax’s `0.0045 * (0.04/0.75) * 1095 ≈ 0.26%` is a decimal-place error. The product is **0.2628**, a simple fraction (about 26% of principal per year at a hypothetical 1.04× premium, 1,095 epochs), not 0.26%, and not a live APR. The “only above 1.4× does rebase exceed 12%” line uses the same mis-scale. Do not treat it as evidence the loop is a trap or a carry. Interest, utilization, tax, and the RFV cap are still unmeasured. No current APR is known.

## Providers and hook — current code

Empty SE supply does **not** publish 0. Current `StandardExchangeRateProviderFacet` returns `_initialRate` when `totalShares == 0` (`:90–94`). Kimi’s cite of an older PRD §8.3 is stale. A failed preview can still return 0 (`:110–111`).

Current Weighted hook: empty buffered balance rates as 0 without calling the provider (`UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:88–89`). A configured provider that **returns** 0 **reverts** (`:94–100`). Binding the same share token twice reads the whole balance twice (`:88,125–127`). So two providers are selectable only if the consumer uses **one** coordinate per decision. Summing `W` and `H`, or listing the same shares on two legs, double-counts. They are not separate claims unless collateral and debt are explicitly partitioned, which this position does not do.

## Design, not a forced identity

All three alternatives remain open:

1. **Equity-share vault** plus `W` and `H` as non-additive capacity views. Matches the user’s two valuations if each route binds one. My earlier “do not expose two providers” was too strong if they are alternative quotes rather than summed assets.
2. **Custom headroom-priced hook** only with a proof that each trade consumes the joint budget `τpx+y<=slack` and that share price stays on `E`. Not a plug-in of the current Weighted hook.
3. **Separate leverage package or DETF** if the owner wants a new share identity. Not required to make the pooled borrower viable, and not a usurpation of the current family’s Keep-YT or supply-only SE.

Do not reject (1) because v0.36 forbids leverage. Do not implement it inside that family without an owner amendment.

## Falsifiable conditions

- Summing both quotes prices shares above `E` at zero debt (`W=C`, `H=τpC`).
- MiniMax-signed `W` withdraws collateral when the position is already tighter than target.
- Asset-only repay leaves `borrowShares > 0` while the vault has burned its last share.
- Oracle `Diverged` blocks a debt-bearing collateral exit and still allows withdrawal after full share repay.
- A majority-collateral vault’s unwind or liquidation sells more NET than one InverseBond epoch can absorb. That is a size risk, not a floor.

**Unresolved:** target versus LLTV for the borrow quote (I side with target for both management views); whether USDG-in is repay-only; haircut of `E` versus oracle `V`; whether a custom hook is wanted at all. **Confidence:** high on Position fields, repay order, zero-debt health bypass, hook zero-rate revert, and the APR scale error. Medium on joint-budget rounding. Low on live liquidity. No RPC.
