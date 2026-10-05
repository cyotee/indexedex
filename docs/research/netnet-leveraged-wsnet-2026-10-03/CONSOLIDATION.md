# Leveraged wsNET / USDG Morpho reserve — council consolidation

Research date: 2026-10-03. Discussion only. PRD v0.36 and implementation plan v0.10 remain unchanged. No implementation, shell, tests, RPC execution, deployment or transactions performed. This report records evidence and proposals, not selected product law or a profitability/security certification.

## 1. Question and conclusion

The human proposes a pooled leveraged wsNET reserve with USDG debt, accumulating rebase exposure. One vault would support two alternative bound-provider valuations: collateral withdrawable to a configured LTV, or additional USDG borrowing capacity. Token routes would act as management instructions. The question includes whether Morpho permits full USDG liquidation and whether widespread collateral encumbrance could sustain emissions and a price floor.

**Conclusion:** the pooled borrower and both provider metrics are technically coherent. They are not ordinary shareholder equity NAVs and are not additive reserves. One ownership/accounting layer can coexist with two alternative management-price/capacity adapters. Using headroom intentionally as a hook trading coordinate is a possible custom economic design, not a source-level impossibility, but requires explicit share-value conservation, coupled transitions, zero-headroom behavior and loss/exit policy. It is not a drop-in rate-provider substitution for the existing Weighted reference.

Full debt-free USDG exit is possible with collateral conversion. NetNet's TurboRouter already demonstrates an atomic repay-callback unwind without an external flash loan. Borrowing USDG without conversion is also possible within capacity, but it is a debt-financed payout, not a close.

The positive-carry premise is conditional. Encumbering most wsNET is not a price-floor guarantee; it can amplify correlated liquidation, lender-utilization and exit-liquidity risks.

## 2. Council record

Four independent first passes and four same-session combined cross-reviews completed. Each reviewed the other three complete originals together, not earlier cross-reviews. All original and review files below remain frozen untrusted evidence; incorrect claims are adjudicated here rather than silently rewritten.

| Member | Continuing session | Original | Cross-review | Attributed position |
|---|---|---|---|---|
| Astra | `ses_f06e61b1fffexSrbwgXFtFY26F` | `astra-original.md` | `astra-cross-review.md` | Pooled equity vault feasible; separate capacities; custom headroom trading remains a possible larger design. |
| Grok | `ses_f06de10ebffeZgF04yzNBuA3TA` | `grok-original.md` | `grok-cross-review.md` | Initially recommends excluding from current family; review accepts alternative providers and treats current exclusion as scope, not impossibility. |
| MiniMax M3 | `ses_f06cce143ffelEu8hYz2HGc2Kb` | `minimax-original.md` | `minimax-cross-review.md` | Initially asserts pooled impossibility/per-user necessity; retracts that in review. Numerous residual arithmetic/accounting claims remain rejected below. |
| Kimi K3 | `ses_f06c2b8ceffexgZb3dM3nVZ1tF` | `kimi-original.md` | `kimi-cross-review.md` | Prefers standalone leveraged component first; supports selectable capacities; custom pricing and eventual family integration remain design options. |

Reported pins remain openai/gpt-6-astra, xai/grok-4.7, minimax/MiniMax-M3 and kimi-code-plan-global/k3. Metadata supplies attribution, not independent provider verification. No full-council agreement on a final architecture, pricing policy, LTV or crisis policy is claimed.

## 3. Observed protocol mechanics

Path abbreviations: B=`lib/crane/contracts/external/morpho/blue/`; N=`lib/crane/contracts/protocols/pol/net/src/`; H=`contracts/hooks/uniswap/v4/standardExchange/weighted/`; R=`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`.

### Pooled position and authorization

`B/interfaces/IMorpho.sol:16–20` stores supplyShares, borrowShares and collateral in one record per market/address. A contract can own posted wsNET and USDG borrow shares and issue its own fungible equity receipt. No per-shareholder Morpho position or per-user authorization is required when the vault manages its own position. It need not be a lender too; same-address supply and borrowing are technically possible but constitute additional economic scope.

`B/Morpho.sol:235–263,323–341` authenticates borrowing and collateral withdrawal. Repayment and collateral funding (`:269–319`) can be funded by third parties without borrower authorization; the contributing caller must still provide the tokens. This is not free money or a guarantee someone rescues the position. A direct third-party gift should not mint equity to the next depositor.

### Debt and wrapper units

Accrue debt for writes and project accrual for views with `B/libraries/periphery/MorphoBalancesLib.sol:33–60,109–118`. Debt for b borrow shares is:

```text
D_raw = ceil(b * (accruedTotalBorrowAssets + 1)
               / (accruedTotalBorrowShares + 1e6))
```

The offsets and rounding follow `B/libraries/SharesMathLib.sol:20–43`. Borrow-assets creates shares rounded up; repay-assets retires shares rounded down; repay-shares requires assets rounded up (`B/Morpho.sol:251–252,283–295`). Full close uses the actual outstanding borrow-share count. Interest accrual changes debt per share, not the borrower's outstanding share count. TurboRouter's simplified LTV view is not a substitute for the accrued canonical calculator.

wsNET balance is static; its redeemable sNET grows with the processed index. `N/perp/WrappedStakedNET.sol:28–85` uses wsNET18 and sNET9: wsRaw=floor(sRaw*1e18/index), sRaw=floor(wsRaw*index/1e18). Passive rebase does not mint additional raw wsNET collateral units. Accumulating raw wsNET through leverage and increasing NET-equivalent exposure through index growth are distinct metrics.

### Actual Loopback oracle

`N/lending/LoopbackOracle.sol:52–75` credits NET at clamp(90% of canonical-pair TWAP, treasury backing, 5× backing), then scales by the nine-decimal sNET index. For the inspected wsNET18/USDG6 configuration:

```text
P = floor(creditedNET_WAD * index / 1e9) * 1e6
collateralValue_USDGraw = floor(collateral_wsNETraw * P / 1e36)
```

It reverts on invalid TWAP or spot below85% of TWAP. The source's oracle floor is credit policy, not an executable sale guarantee. It is neither pure backing nor market spot nor the InverseBond bid. `N/lending/LendingConstants.sol:24–39` records LLTV62.5% and Turbo target53.125%; those are protocol/router precedents, not chosen parameters for a new vault. Use a separately enforced management target below LLTV with an explicitly justified risk margin.

## 4. Correct meaning of the two valuations

Continuous whole-token notation: C posted wsNET; p oracle USDG/wsNET; D accrued USDG debt; tau target LTV in (0,LLTV). Ignore idle assets and rounding for these identities:

```text
V = p*C
W = max(C - D/(tau*p), 0)         // wsNET withdrawable without repayment
Hcredit = max(tau*p*C - D, 0)     // additional USDG debt allowed to target
Hcredit = tau*p*W
```

Executable H additionally depends on free market loan liquidity and transferable cash, as well as exact post-borrow share rounding and successful dependencies. `B/Morpho.sol:258–263` checks both collateral health and market liquidity. Collateral withdrawal has no USDG free-liquidity check, but remains health/authorization/transfer constrained.

For simultaneous actions x wsNET withdrawn and y USDG additionally borrowed, at an initially within-target state:

```text
tau*p*x + y <= tau*p*C - D
```

The two full maxima cannot both be consumed. Smaller combinations can coexist. Kimi's initial sum identity using both maxima on the left is incorrect, as is Grok's review sentence accepting it. Cash-capped H is not generally tau*p*W. The proposed metrics are correlated measures of the same collateral/debt slack, not independent earning forecasts; liquidity-capped H adds information about actual lender capital availability.

Even W requires p because USDG debt must be translated into required wsNET collateral. It avoids treating the entire position as immediately liquidatable at a firm market price, but it is not price-independent. H is a capitalization-capacity signal, not earnings or cash already owned.

### Exact fixed-state collateral inverse

For raw c,D,P and WAD target t>0, coherent accrued state:

```text
Vraw = floor(c*P/1e36)
requiredValue = ceil(D*1e18/t)
requiredCollateral = ceil(requiredValue*1e36/P)
Wraw = max(c-requiredCollateral,0)
Hbudget = max(floor(Vraw*t/1e18)-D,0)
```

Use positive-price/domain checks and full-precision arithmetic. W inverts the nested-floor target inequality; Hbudget must still replay post-borrow debt-share rounding. D=0 gives W=c; t=0 requires an explicit unlevered policy, not division by zero. Oracle-unavailable is not the same as measured zero capacity. Target, LLTV-health, oracle-marked solvency and realizable solvency must be separately reported.

## 5. Equity and ownership cannot be inferred from headroom alone

Choose an accounting price pA explicitly, separately from Morpho's credit oracle and executable liquidation proceeds. Recommended ordinary ownership accounting:

```text
E = marked posted/idle collateral + owned USDG/other assets
    - accrued debt - other liabilities
```

Book each asset once. A borrowed dollar retained as cash increases assets and debt equally, not profit. Borrowing then buying/posting more collateral increases gross exposure, not necessarily equity after costs.

Example, same illustrative accounting/credit price: C=100wsNET,p=10USDG/wsNET,D=400USDG,tau=.5 gives E=600USDG,W=20wsNET,Hcredit=100USDG. Withdrawing all W pays200USDG of marked value and leaves400USDG equity encumbered at target. Borrowing all H and paying it out removes100USDG equity and leaves500USDG equity at target. At D=500, both headrooms are zero while E=500. Thus a zero headroom rate cannot mean the equity receipt is worthless or fully redeemed.

For positive E and existing supply S, fair issuance conceptually uses S*netNewEquity/E, with costs, fees, rounding and actual receipts mapped explicitly. Adding collateral worth100USDG and contributing100USDG to repay debt each add100USDG equity, but W responds differently. Minting ordinary equity shares from delta-W would subsidize one contribution route. A USDG contribution may repay debt **and mint fairly priced vault equity**; repayment retires Morpho debt shares, not vault equity shares. A gift mints none.

Above-target positive equity need not block risk-reducing funding. Do not require every partial rescue to restore target immediately; define non-worsening risk-reduction separately from risk-increasing operations. At nonpositive equity, ordinary proportional minting is undefined; recapitalization/loss handling needs its own specification. Full equity redemption must extinguish/allocate all liabilities and residual assets, not merely drain W/H and burn the last receipt.

Headroom-priced **trading**, distinct from equity issuance, remains possible. It intentionally assigns a management-dependent price rather than guaranteeing pro-rata liquidation value. The custom design must specify resulting transfers of value, who retains encumbered equity, cross-token round trips, donation effects, and zero-headroom entry/exit behavior. Labeling it a rate provider does not resolve those economics.

## 6. Token routes as management instructions

These are proposals for one new pooled borrower, not changes to the existing family:

| Route | Candidate instruction | Accounting/risk consequence |
|---|---|---|
| wsNET in | Post collateral | Increases actual collateral/equity; generally lowers LTV at fixed debt/price. |
| sNET in | Wrap then post | Same, with exact wrapper/index accounting. |
| NET in | Stake, wrap, post | Same, subject to live staking enablement/warmup and processed-rebase ordering. |
| USDG in | Repay debt | Deleverages and increases equity; excess after debt reaches zero needs selected idle/conversion policy. |
| wsNET out | Withdraw collateral within target, or deleverage allocated exposure first | Leaving debt unchanged raises remaining LTV; share debit must account for value actually paid. |
| sNET/NET out | Above, then unwrap/unstake | Same plus conversion/index/tax effects; no sale needed merely to receive NET. |
| USDG out, management mode | Pay owned cash or increase debt within executable H | Debt-financed payout reduces equity; the vault, not recipient wallet, retains protocol debt. |
| USDG out, unwind mode | Repay attributed debt and sell released collateral | Reduces leveraged exposure; net proceeds and availability govern exit. |
| Leverage-up | Borrow USDG, buy NET, stake/wrap, post | Increases gross collateral and debt; charge costs, enforce post-state risk. |

Token identity alone may not settle every choice: a USDG output could mean borrow-out or close-out; a USDG input above debt cannot keep repaying. Choose a deterministic policy or explicit intent without conflating those operations. Remaining shareholders bear the pool's remaining liabilities economically, not personal Morpho debt transfers.

Route-induced management can create incentives but does not guarantee maintenance. Risk-reducing deleverage must have an executable, bounded route that does not rely on future deposits or gifts; keeper authority/incentives and outage behavior remain design choices.

## 7. Full unwind and all-USDG settlement

Morpho itself does not swap collateral. With external USDG one can repay and withdraw only wsNET. With conversion one can close into wsNET, mixed wsNET/USDG, or **only USDG**. Merely borrowing USDG leaves an open position and is not liquidation of equity.

`B/Morpho.sol:281–295` accrues, reduces borrow shares/debt, invokes `onMorphoRepay`, then pulls USDG. `N/lending/TurboRouter.sol:226–294` uses precisely this to repay caller debt by withdrawing wsNET in the callback, unwrapping to sNET, unstaking to NET, selling via the pool, retaining required repayment and returning surplus USDG. This user-owned router is a composition reference, not the proposed pooled vault.

For full repayment, zero borrow shares make `_isHealthy` return true **before** the oracle call (`B/Morpho.sol:515–538`). Full collateral withdrawal can therefore survive a reverting Loopback credit oracle after full-share repayment, if the conversion route itself works. Partial exits with remaining debt still require health checks. Do not confuse zero debt with zero equity or unnecessarily require a functioning valuation oracle before every possible risk-reducing close.

Callback-funded close does not require idle USDG lending liquidity or an external flash loan: repayment funds arrive after the conversion. Optional flash-loan routes have their own cash/cost requirements. None bypasses solvency: conversion must cover repayment and user limits, otherwise atomic rollback. Protect callback caller, phase, market, amount, recipient and allowances; do not copy TurboRouter's while-unstaking loop as a proven gas bound.

Alternative realization: wsNET→sNET→NET→InverseBond→USDG, or an approved pool/buyback split. InverseBond is discounted from backing, oracle-gated and public-capacity-limited; it cannot be assumed to fund a majority-supply unwind. The credit oracle's NAV floor does not reserve liquidation cash.

## 8. Carry premise and supply concentration

At fixed collateral units, LTV=D/V. Over a period it scales as `(1+debtGrowth)/(1+creditedCollateralValueGrowth)`. LTV falls only when the latter growth exceeds the former. This credited growth includes index, NET mark/backing and oracle policy effects—not just nominal rebase.

Positive equity carry is a different condition: before costs, delta-E≈V*gV−D*gD. It can be positive while LTV rises. Neither condition guarantees a profitable finite-size exit after acquisition/realization tax, swap impact, fees and losses.

`N/Distributor.sol:56–69,85–98` gates new rewards on premium, valid oracle and RFV capacity. `N/Staking.sol:134–150` processes one due epoch, pays the previous queue, then requests new rewards. Hence below-NAV/stale conditions stop new rewards, but a previously funded queue may still produce a rebase. Holder index growth depends on profit versus circulating staked participation (`N/StakedNET.sol:83–98`); Distributor's percentage of total NET supply is not itself the vault's annual return. No current APR, expected spread or break-even premium is established.

Encumbering wsNET may reduce voluntary float and leverage purchases may support demand, but neither imposes a price floor:

- Marginal sales can move an AMM price without selling most supply; thinner float/liquidity can increase impact.
- Collateral can be unwound or seized by liquidators and sold; encumbrance can defer rather than eliminate selling.
- The buyback bid is below backing and finite/gated, not an unlimited peg.
- More borrowing may raise utilization and debt cost; less profitable carry can trigger a coordinated unwind.
- Credit-oracle failure can pause new borrowing, debt-bearing collateral exits and liquidation while interest keeps accruing. Repay/add-collateral remain available subject to other dependencies; a pause is not removal of risk.
- Oracle floors/caps, treasury backing, NET price and emission policy are correlated. A regime transition can hurt credit and realizable value differently.

If the same larger family holds both a lender SE and this borrower, account for both exposures without treating recirculated credit or internally transferred interest as newly created wealth. This extra composition is not needed for the proposed borrower itself.

## 9. Provider and architecture options

**One vault, two alternative providers is allowed conceptually.** Each provider should bind the same vault, target policy, denomination, share scaling and coherent state semantics. W/S and H/S may be exposed as management-capacity rates. Do not add them as independently spendable backing or attach the same entire receipt balance to two legs without explicit partition.

At a fixed snapshot they are related through the same credit constraint; after either route they must both update. A USDG-denominated leg cannot consume a wsNET-denominated rate without an explicit conversion/model change. A scalar rate should not silently stand in for nonlinear finite-size execution.

**Observed reference incompatibility:** `H/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:88–100` rejects zero configured rates; `:45` rejects zero rated swap legs; `:125–128` reads full SE balances per binding. Target headroom can legitimately be zero while equity remains positive. No epsilon rate should hide this. `R/StandardExchangeRateProviderFacet.sol:90–94,147–165` attempts an initial rate at zero supply; zero return at `:110–111` is a failed/empty probe result, not its unconditional empty-supply rule. It samples/extrapolates execution previews (`:97–144,172–185`), so it is not automatically a correct headroom or leveraged-equity provider.

| Architecture | Viability / tradeoff |
|---|---|
| Standalone leveraged SE with one equity share plus two capacity providers | Recommended first component boundary. Pooled borrower and token-directed management; ordinary equity accounting distinct from W/H. Establish independent exits, maintenance and loss behavior before composition. |
| Later qualify that SE as a USDG-leg alternative | Possible after explicit scope amendment and proof of USDG/share, rate, exact-output, projected-state and liquidity contracts. Selecting PkgArgs SE alone does not prove compatibility. Keep existing NET/sNET Keep-YT routes unchanged. |
| Purpose-built headroom-priced DETF/hook using the same leveraged SE | Closest to intentionally making W or H a trading valuation. Needs new zero-headroom behavior, economic pricing/share-accounting separation, coupled route transitions and full-close rules. Could be one selected coordinate per deployment; two simultaneous coordinates require explicit shared-budget treatment. |

There is no protocol requirement to use per-user vaults, reopen the supplier component's internal D6, or append a fifth leg. A new borrower package can leave the supply-only component unchanged. The current family explicitly excludes borrowing: that is a permission/product boundary, not a reason the research idea cannot work.

## 10. Corrections, dissent, confidence and decision checkpoint

Rejected original/review claims include: pooled vault impossibility; W infinity at zero debt; W sign reversal; H using LLTV when target was requested; sum identity treating both maxima as separate budgets; missing debt virtual offsets; equity-share burning on funded repayment; borrowing without cash constraints; unconditional provider zero at empty supply; zero-equity rather than zero-debt oracle bypass; guaranteed low-premium profitability; or a mandatory fifth leg/new fee/insurance scheme. Liquidation changes assets and debt, not automatically the vault's ERC20 supply or all equity. Donation risks require actual accounting analysis, not an unsupported assertion of infinite shares.

MiniMax corrected its 100× arithmetic error, but then incorrectly promoted the corrected toy figure to a current/typical profitability result. `0.0045*(.04/.75)*1095=.2628` is a simple fraction, not .26%; neither that arithmetic nor assumed typical rates proves holder yield or carry. Kimi/Grok retain isolated errors accepting the wrong maxima sum or stale provider behavior; source/math above controls. Permissionless third-party rescue requires funded contributions, not zero-cost maintenance.

High confidence: pooled feasibility, debt/callback semantics, headroom identities and nonadditivity, observed oracle and hook behavior. Medium: architectural fit and the proposed ownership/management separation. Unverified: deployed source equivalence, actual market terms/decimals/warmup, live free liquidity/utilization/APR, finite-size close feasibility, stress survival, gas/resource bounds and economic soundness.

**Human checkpoint:** should W/H be (A) alternative capacity/management outputs while equity determines ownership and ordinary share issuance, or (B) intentional trading-price coordinates for a new custom hook/DETF while equity ownership remains separately specified? The same leveraged-vault core can support either, but they are different economic specifications. Then decide target/bands, USDG-out borrow versus unwind priority, excess USDG input, accounting mark, loss/full-close behavior and maintenance policy. None is selected by this report.

## 11. Evidence provenance and implementation handoff

Direct moderator reads covered current CLAUDE, PRD v0.36 §4.1, plan v0.10, canonical morpho-blue-operations skill, Morpho core/interface/debt math, NetNet oracle/router/wrapper/distributor/staking, current Weighted claim lib and SE provider. The skill's blanket authorization summary is less precise than core code; repay/supplyCollateral do not require borrower authorization.

Morpho local pin: v1.0.0, commit `55d2d99304fb3fb930c688462ae2ccabb1d533ad`; VENDOR notes upstream pragma0.8.19 adapted to ^0.8.35, not bytecode-identical local compilation. NetNet source provenance: 2026-08-28 verified-source dump, not a fresh runtime observation.

Context7 consulted first (`/llmstxt/morpho_llms_txt`). Primary sources accessed 2026-10-03:

- https://docs.morpho.org/developers/borrow/tutorials/assets-flow — Context7, full-share repayment/assets-flow documentation.
- https://docs.netnet.capital/lending — fetched directly; describes Loopback/Turbo/terms, but publication safety language is not adopted as proof.
- https://docs.netnet.capital/risks — primary search evidence on oracle/market/liquidity risks.
- https://docs.netnet.capital/credit — primary search evidence distinguishing the lender vault from Loopback borrowers; not a new selected vault binding.
- https://raw.githubusercontent.com/morpho-org/morpho-blue/main/src/Morpho.sol — researcher primary fetch; unpinned main does not replace local/deployed version checks.

**Saved artifacts:** this consolidation and four originals/four cross-reviews in this directory. **Implementation handoff: none.** PRD and plan untouched. No new component PRD, tests, simulation, deployment or transaction authorization. Stop for the human decision.
