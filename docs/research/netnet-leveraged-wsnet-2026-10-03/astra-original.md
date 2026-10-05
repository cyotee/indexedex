# Astra — leveraged wsNET/Morpho independent original

Research date: 2026-10-03. Same researcher/session; no peer artifacts read. Only this report written; no execution or product-document changes.

## Recommendation and current authority

**A pooled wsNET-collateral/USDG-debt vault is feasible in principle. Its two headrooms are useful management limits, not two additive assets or suitable ordinary share NAVs.** Recommend one equity share, one accounting NAV, token-directed execution, and separately exposed collateral-withdrawal/borrowing capacities. Treat dual-headroom Weighted pricing as a separate custom design requiring economic proofs, not a plug-in rate-provider change.

Current coordinating PRD **v0.36:22–26,170–172,289–340** selects deployment-time `PkgArgs.standardExchangeVault`, whole-PkgArgs identity and package-defined hook. Its Morpho alternative is **supply-only**, with concrete lending-vault binding still unresolved; it is neither automatically the older direct-Blue supplier nor this borrower. Plan **v0.10** intentionally lags. `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_PRD.md:24–34,44–49,115–122` explicitly separates Blue lending, Vault V2 wrapping and borrowing. `docs/detf/NET_MORPHO_USDG_LENDING_STRATEGY_PRD.md:84–112` likewise requires supply-only NAV and separate liquidity limits. Leverage is research here, not selected implementation.

Notation: **B/** = `lib/crane/contracts/external/morpho/blue/`; **N/** = `lib/crane/contracts/protocols/pol/net/src/`; **H/** = `contracts/hooks/uniswap/v4/standardExchange/weighted/`.

## 1. Actual collateral, oracle and debt

**Observed:** Morpho holds the vault's `position[marketId][vault]`: collateral assets and borrow shares, not a transferable borrower ERC20. The vault issues its own equity token. Lending-vault receipts do not represent this position.

Accrue before economic accounting; views use `B/libraries/periphery/MorphoBalancesLib.sol:33–60,109–118`. For borrower shares b and accrued market borrow totals A,T:

`D = ceil(b*(A+1)/(T+1e6))` raw USDG.

Virtual offsets and rounding are mandatory (`B/libraries/SharesMathLib.sol:20–43`). Borrow-assets rounds new shares up; repay-assets burns shares down; full repay uses actual outstanding shares with assets rounded up (`B/Morpho.sol:235–297`). Replay resulting totals for exact-output/headroom bounds. **Do not copy TurboRouter's simpler debt ratio**: `N/lending/TurboRouter.sol:313–323` omits virtual offsets and its public view does not accrue. The canonical helpers are stronger reuse sources.

wsNET has 18 decimals and a fixed token balance; sNET/NET have nine. Actual conversions are `ws=floor(sRaw*1e18/I)` and `sRaw=floor(wsRaw*I/1e18)`, where index I is nine-decimal (`N/perp/WrappedStakedNET.sol:29,48–85`). Raw wsNET collateral does not itself rebase; redemption value changes.

**Loopback oracle is not pure backing, spot, or buyback value.** `N/lending/LoopbackOracle.sol:52–86` computes:

`creditedNET = clamp(0.90*TWAP, treasuryNAV, 5*treasuryNAV)`

then `P = floor(creditedNET_WAD*I/1e9)*1e6` for wsNET18/USDG6. Morpho values c raw collateral as `floor(c*P/1e36)` raw loan units. Invalid TWAP or spot below 85% of TWAP reverts. `LendingConstants.sol:10–39` sets LLTV=.625 and Turbo target=.53125; these are inspected constants, not recommended new-vault parameters. Verify configured market/oracle/decimals. Target τ is an internal management threshold strictly below LLTV, not a liquidation guarantee.

## 2. Unit-explicit headrooms versus equity

At one coherent accrued snapshot let c=posted wsNET raw, D=debt raw USDG, P=oracle scale above, t=target LTV WAD, and V=`floor(cP/1e36)` USDG raw. Exclude idle assets initially. For positive P,t:

```
requiredValue = ceil(D*1e18/t)
requiredCollateral = ceil(requiredValue*1e36/P)
W = max(c-requiredCollateral,0)                    // wsNET raw
Hbudget = max(floor(V*t/1e18)-D,0)                // USDG raw
```

W is maximal collateral release without repayment under the nested-floor target check. If already above target, W=Hbudget=0 and report the shortfall. If debt is zero, all c is withdrawable; t=0 requires a separate zero-debt-only policy. Hbudget needs a **post-borrow share-rounding replay**, then caps for market free liquidity and actual transferable cash. Collateral withdrawal is not capped by USDG lending utilization; new borrowing is (`B/Morpho.sol:258–259,323–341,527–538`).

Clean continuous model: price p in USDG/wsNET, τ fractional, posted C in whole wsNET:

`W=max(C-D/(τp),0); H=max(τpC-D,0)=τpW`.

They describe the **same slack**. Combined withdrawals x wsNET and additional borrowed payout y USDG obey `τpx+y≤H`, not x≤W and y≤H independently.

Equity, with chosen accounting price pA and owned cash K, is `E=pA*C+K−D−otherLiabilities`, also including idle collateral/other owned assets once. Neither unused borrowing capacity nor loan proceeds without their matching debt are profit. pA must be explicitly distinguished from liquidation-oracle marks and finite-size liquidation proceeds.

**Counterexample:** C=100,p=1,D=50,τ=.5 yields E=50 but W=H=0. A 10-collateral deposit increases equity by 10 and W by 10; a 10-USDG repayment increases equity by 10 but W by 20. Pricing shares from ΔW subsidizes one route. Changing τ changes W/H without changing E. At D=0, W=C and H=τpC; adding their values manufactures a second claim.

## 3. Fair shares and management directives

Use fee-adjusted pre-operation equity per share. For positive E and share supply S, fair issuance conceptually satisfies `ΔS/S=netNewEquity/E`; redemption debits actual equity paid plus operation-attributable costs. Apply directed integer rounding, actual delta receipts and existing fee conventions—not this continuous equation verbatim.

Above-target is not necessarily insolvent: risk-reducing deposits/repayments can be accepted at full equity value. At E≤0, ordinary proportional minting is undefined: reject or specify a separate recapitalization/wind-down mechanism. Zero supply requires clean ownership of residual collateral/debt/cash; no first depositor captures legacy equity. Recognize donations or third-party `supplyCollateral/repay(onBehalf=vault)` once for existing holders, apart from explicitly claimed public pretransfer credit. Preserve pretransfer credit-before-sync rules and do not mint against unrelated balances.

Suggested route semantics, subject to selection:

| Route | Implicit directive and settlement |
|---|---|
| wsNET → shares | Post measured collateral; optional bounded leveraging only under explicit policy. |
| sNET → shares | Wrap at settled index, then post. |
| NET → shares | Stake, wrap, post; verify zero warmup or reject synchronous route. |
| USDG → shares | Repay debt first; define excess as idle reserve or buy/stake/wrap collateral. Never over-repay by assets. |
| shares → wsNET | Withdraw within W, or repay attributed debt and withdraw allocated collateral; charge realized costs. |
| shares → sNET / NET | Above plus unwrap / unstake, protecting index-change residuals. |
| shares → USDG | Use owned cash, borrow within remaining capacity, or deleverage/sell allocated collateral. Burning shares must cover equity removed; debt remains with vault. |

No remaining borrower personally inherits Morpho debt: the vault remains debtor and remaining shares bear its liabilities. Capacity-only withdrawals can raise remaining leverage even when equity pricing is fair; disclose and constrain this. For proportional unwind, repay approximately qD and withdraw qC for redeemed fraction q, with rounding and residual costs allocated explicitly. Full redemption must extinguish all debt or reject—not burn the last share while leaving an ownerless obligation.

Borrow-to-buy-to-post increases collateral and debt, consuming fees; it is not share yield at execution. Deterministic risk-reducing maintenance must remain possible without fresh user inflows. Reliance solely on token-route arbitrage provides no guarantee someone deleverages before liquidation.

## 4. Unwind endpoints and funding

**Only-USDG is attainable.** Without conversion, Morpho can pay loan-token borrow proceeds and collateral withdrawals, but it does not exchange collateral into USDG. A full debt-free close funded by selling collateral can leave entirely USDG. `N/lending/TurboRouter.sol:235–294` already demonstrates repay callback → withdraw wsNET → unwrap → unstake → taxed canonical sale → repay, returning surplus USDG.

Morpho decreases debt **before** `onMorphoRepay`, then pulls loan tokens afterward (`B/Morpho.sol:281–295`). Thus a tightly authenticated repay callback can fund repayment from released collateral **without an external flash loan**. Partial withdrawal still passes post-repay health; full share repayment allows full collateral withdrawal even when the collateral oracle fails, because zero-debt health bypasses its read (`:515–538`). Conversion can independently fail.

Alternative: flash-borrow USDG, repay, withdraw, convert enough collateral, repay flash principal, return residual wsNET/USDG as requested. Blue's inspected `flashLoan` charges no explicit fee but requires actual singleton token balance (`:422–431`); outside providers may charge. Neither callback nor flash funding creates solvency. Enforce callback sender/phase/market/amount/recipient, bounded approvals, minimum proceeds, maximum collateral sale/debt repayment and atomic rollback.

Do not copy TurboRouter's residual loop indiscriminately: it can iterate staking touches during epoch backlog (`:264–275`), while its entry settlement caps eight calls (`:302–307`). Establish bounded processing and preview parity. For wsNET-only exit with no external repayment cash, sell some allocated collateral and return the remainder; mixed payout and all-USDG are conversion choices, not Morpho primitive restrictions.

Buyback route is wsNET→sNET→NET→InverseBond→USDG. `N/InverseBond.sol:68–88,108–139` pays 98.5% of live backing, has public epoch capacity, and requires valid PairOracle. Compare complete net realization against canonical swap, including NET tax, DEX fee, impact, floors and earlier state changes. The **Loopback oracle's NAV floor is not an executable floor**: bid discount, depleted capacity, divergence/stale oracle and market depth can defeat repayment. Reliable accounting must not book H or hypothetical unlimited buyback proceeds as cash.

## 5. Two providers and hook compatibility

One vault may expose both capacities for observability, or two bound adapters can encode W/S and H/S with correct target decimals. But those are alternative limits, not fixed conversion rates. At target both are zero despite positive equity. Repeated withdrawals consume the shared slack; per-share multiplication does not grant independent execution rights.

Existing Weighted reference `H/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:78–100` multiplies held SE shares by rate and **rejects zero rates**. Its `_nativeAt:125–128` reads the entire SE token balance per buffered leg: binding the same SE twice can count the same actual shares twice without partitioning. Weighted math expects meaningful positive rated balances and enforces ratio/domain guards (`…HookMath.sol:70–82,186–227`). Do not bypass these with epsilon rates.

The standard provider samples/extrapolates execution previews (`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:97–144,172–185`), unsuitable for extrapolating nonlinear headroom. Use one equity valuation in a chosen numeraire plus separately queried route capacity and projected state. Two independently spendable tokens require explicit claim partition, seniority and debt/loss waterfall; providers alone create none. A custom dual-coordinate hook must update both capacities after every action and prove cross-route conservation.

## 6. Carry, concentration and architecture choices

Staking processes **one** due epoch per call, distributes previously queued NET, then queues new emissions (`N/Staking.sol:88–125,134–150`). Distributor returns zero at/below NAV premium or stale oracle and caps issuance by RFV (`Distributor.sol:56–98`). More encumbered supply does not force positive emissions. Debt accrues with time; AdaptiveCurve utilization and adaptive target rates respond to borrowing (`lib/crane/contracts/external/morpho/blue-irm/AdaptiveCurveIrm.sol:76–148`). LTV falls only if credited collateral value grows faster than debt; market-credit changes can overwhelm index growth.

Oracle failure blocks new borrows, debt-bearing collateral exits and liquidations, **not** all repay/supply operations or future debt interest. Concentration magnifies correlated liquidation sales, utilization shocks and exit impact. Encumbering most supply cannot guarantee market≥buyback NAV: marginal sellers set price, collateral can be liquidated/unwrapped, buyback is discounted/capped, and emissions dilute supply/backing. Supply accumulation is a risk-bearing objective, not proof of economic return or a price floor.

**Preferred bounded alternative:** separate immutable, single-market leveraged SE with equity shares, explicit target/bands, collateral acquisition/deleveraging routes and debt-free full-close path. Later qualify it as a new USDG-leg option only after demonstrating current family's USDG/share exact-side, rate, projection and liquidity requirements. Do not silently replace Keep-YT or the selected supply-only option. Alternative: a separate leveraged DETF/custom hook for deliberate dual-headroom pricing; substantially larger economic specification. Lowest-risk baseline remains unlevered wsNET or supply-only USDG, not assumed equivalent returns.

**Decisions:** equity mark and cost attribution; target/bands and changes; reinvest versus borrow-out; emergency deleveraging authority/incentives; residuals/full-close/insolvency; permitted callback/conversion routes; concentration limits; one equity coordinate versus explicit coupled claims.

## Evidence and confidence

Context7 Morpho consulted first. Primary URLs accessed 2026-10-03: https://docs.netnet.capital/lending ; https://raw.githubusercontent.com/morpho-org/morpho-blue/main/src/Morpho.sol ; https://docs.morpho.org/build/borrow/tutorials/assets-flow (via Context7). Public descriptions are not runtime guarantees. Local Blue pin v1.0.0 `55d2d99304fb3fb930c688462ae2ccabb1d533ad` (`B/VENDOR.md:5–25`); local recompilation is not bytecode-identical. NetNet source provenance remains 2026-08-28 dump; live bindings/decimals/warmup/liquidity unverified.

Confidence **high** on inspected mechanics and headroom/nonadditivity derivation; **medium** on proposed architecture; profitability, stress survival and deployable compatibility **unproven**. File-pattern tool failed because rg was unavailable; known-path reads supplied the cited evidence. No tests, RPC, shell or live-rate assertions.
