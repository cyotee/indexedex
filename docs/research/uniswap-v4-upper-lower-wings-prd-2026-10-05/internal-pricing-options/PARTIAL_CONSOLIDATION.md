# Internal pricing with external withdrawals — partial council round

Date: 2026-10-05. Research only. Owner preferences remain exploratory, not ratified. PRD unchanged.

## Round status

Four originals completed; Astra and Grok cross-reviews completed. MiniMax's cross-review returned `[RC_POLICY] tool policy validation failed` for its assigned Markdown write and returned no substantive review. No retry, bypass, replacement or restart was attempted. Kimi cross-review was not requested following that failure. This is NOT a completed council round or full-council consensus.

| Member | Retained session | Evidence |
|---|---|---|
| Astra | `ses_ef7c68835ffey58T5UT2G8JDZo` | [Original](astra-original.md), [cross-review](astra-cross-review.md) |
| Grok | `ses_ef7c1c50fffe87e6QGupvs3xke` | [Original](grok-original.md), [cross-review](grok-cross-review.md) |
| MiniMax M3 | `ses_ef7bc045effeTc96xsW5R2MidY` | [Original](minimax-original.md); cross-review failed, no saved review reported |
| Kimi K3 | `ses_ef7b7b72fffe3JJ0CVG6FmBRGL` | [Original](kimi-original.md); cross-review not requested |

Completed reviews received all three other complete original artifacts together and no earlier cross-reviews. All model findings are evidence, not authority.

## Preferences under examination

1. AMM-style internal pricing for single-token entry without an external balancing swap.
2. Withdrawals may convert through the underlying pool.
3. The initiating user bears operation fees.

Settled definitions remain local-only custody, whole-book ownership `B=F+sum D+sum E`, and sleeve `F=pD` against vault-owned deployed principal. None of these definitions chooses the economic pricing curve or exit entitlement.

## Partial findings

The combination is mechanically possible, but internal invariant entry plus proportional external exit prices the operation through two potentially different markets. Paid arbitrage can transfer existing holders' marked value; payment of fees does not itself eliminate that opportunity. This is different from minting with unfunded credit.

Astra's continuous-arithmetic example, checked by Grok, assumes backing100/100, supply100, external price2 token1 per token0, own positions out of range and zero center liquidity during the external swap. A gross126 token1 deposit pays a hypothetical1-token entry fee and contributes125. Geometric issuance mints50 shares. Pro-rata exit realizes100/3 token0 plus75 token1. Selling100/3 through finite external virtual reserves10000/20000 at0.3% fee returns approximately66.2465 token1. After a separate1-token exit fee, the user receives140.2465 versus126 paid: approximately14.2465 profit before gas/financing and integer effects. Own LP fee recovery is zero by assumption.

Remaining incumbent backing is200/3 token0 plus150 token1, worth283⅓ at the original mark versus300 initially. The example is not an executed V4 witness, a proof of repeatable drain or a general loss bound. It does demonstrate why charging fees alone is insufficient as a claim of fair pricing.

At matched internal/external prices, Grok and Kimi instead demonstrate losing entry→external-exit round trips. Those examples do not contradict the skewed-price result. Concentrated owned principal can differ from market-price proportions even with no sleeve. Idle withdrawals can access deployed assets, so exposure is not generally capped by sleeve size.

## Options worth comparing, not selecting yet

- **Basket-realization exit:** burn proportional ownership, remove its assets, swap only its opposing token and pay measured proceeds after disclosed costs. Straightforward funding attribution; accepts inventory-price mismatch unless constrained.
- **Paired internal economic exit:** calculate a scalar entitlement on the internal curve; external trading is only a funding mechanism. Requires explicit funding budgets, favorable-execution recipient, shortfall treatment and holder-backing protection. Not automatically free of cross-mode arbitrage, especially with proportional exits still available.
- **Reference-constrained/virtual-reserve AMM:** preserve AMM-style pricing while specifying marginal price/depth and mismatch controls. Not necessarily oracle-NAV issuance; introduces additional manipulation and update analysis. Virtual reserves are not spendable backing.

Compare them on identical physical states, including all exit routes, both manager states, finite external depth, positive owned active liquidity, fees, price changes, zero-sided backing and repeated cycles. Do not ask the owner to ratify numerical fees or gates before that comparison.

## Corrections and dissent retained

- Astra and Grok verified the skewed-price example and rejected a blanket no-arbitrage conclusion for paired exits.
- Grok continues to claim reversed wing orientation. Moderator rejects this against previously read local `LiquidityAmounts.sol:67–76`: with price inside center, upper holds token0 and lower token1. No PRD orientation change is warranted.
- MiniMax's original numerical ledger uses0.5 on100 as5bp (it is50bp), mixes coarse whole-unit root rounding with18-decimal claims, assumes a no-swap full-range position takes unilateral inventory at unchanged price, and describes a blocked payout with F=0. Those examples and its bounded/not-draining claims are not adopted.
- Kimi's original useful matched-price example does not prove its claimed global bounds or no-mode-switch property. Its per-token proportional admission inequality cannot be imposed universally on the non-proportional scalar pricing under exploration: that would force zero mint on a missing contribution leg.
- Price impact is not simply an explicit fee payment to LPs. Gas, explicit fees, execution impact, liquidity rounding and later maintenance are distinct. Fees paid to feeTo do not necessarily compensate incumbents.
- Existing source helpers are mechanism evidence, not safety certification: `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:37–64,98–110`. Researchers used Context7 `/uniswap/v4-core` and primary SwapMath source for fee semantics (access2026-10-05): https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/SwapMath.sol . Mutable upstream main is not a measured local dependency revision.

## Checkpoint

No design ratified; no PRD or implementation plan changed. No code, tests, shell, configuration or deployments performed. Confidence is high in the conditional continuous algebra, not in implementation reachability, economic safety or gas feasibility. Resume the missing review only after the session/policy failure is resolved and continuation is authorized; preserve all four IDs. Suggested subsequent research is a matched-state comparison of exit entitlements and fee/impact attribution, not immediate implementation.
