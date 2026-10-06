# Astra — independent requirements clarification

2026-10-05. Read current PRD v0.1, CLAUDE, relevant canonical liquidity/testing/adversarial skills and current source directly. No peer artifacts, shell, git, tests or PRD edits. Mathematical examples below are hand-derived, not executed security tests.

## Answer

**Yes: single-token issuance without an external balancing swap is possible. But “preserves value” must specify the value metric and redemption rule.** Placement into a one-sided wing solves deployment, not the ownership exchange with incumbents. Positive fungible shares necessarily give the entrant exposure to existing other-token inventory.

The owner has settled local-only reserve tracking, the deployed-owned sleeve denominator, and no-typical-zap entry intent. These are not open votes. PRD §7.3 (`docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:141–150`) should no longer present external balancing composition as an equally pending entry choice. Its §8.1 convention (`:162–171`) is now confirmed in principle; percentage/default/deadband values remain separate parameters.

## 1. Exact reserve meanings

* `R_i`: last booked local custody snapshot used for delivery accounting. Not deployed assets, not total economic backing; not necessarily the current balance between calls.
* `F_i`: current spendable local incumbent holdings after excluding current-call credit, payouts/refunds and other liabilities. A local balance increase is not automatically caller principal. R and F are related but not interchangeable.
* `D_i=Σ_j D_ij`: this vault's actual owned principal across center/upper/lower, at the relevant state. Never total underlying-pool reserves or total pool liquidity.
* `E_i=Σ_j E_ij`: earned, uncollected own-position fees; backing but not local payout capacity.
* `B_i=F_i+D_i+E_i`: complete incumbent economic inventory, with call credit excluded. Collection moves E→F once.

Current FullSpread precedent: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:312–330,514–550` separates local balances, deployed amounts, custody snapshots and fee-inclusive totals. New wings must aggregate three positions rather than copy one-position assumptions.

With p expressed as a fraction, desired **post-placement** `F_i=pD_i`. For fixed lossless placeable `T_i=F_i+D_i`, solve `F_i=T_i*p/(1+p)`; WAD implementation is `floor(T_i*pWad/(1e18+pWad))`. Example: current F=40,D=100,p=20%; deploy 16⅔, ending F=23⅓,D=116⅔. Keeping 20 free against the old D is not the solved target. Integer rounding, placement loss, coupled token requirements and blocked operations prevent exact equality in every state. E enters T only when collected. Recompute/reconcile losses; never force the formula by inventing assets.

## 2. What cannot be preserved simultaneously

For B0,B1>0, contribution `(a,0)` makes proportional min-ratio mint `min(S*a/B0,0)=0` (PRD:133–148). If instead m>0 shares are minted, unchanged other-token backing per share falls from `B1/S` to `B1/(S+m)`. Therefore no no-swap positive fungible issuance can preserve **each underlying quantity per existing share**. This is an elementary impossibility, not a reason to ban scalar entry.

It can preserve a chosen scalar valuation, or an invariant, while exchanging exposure between participants.

## 3. Invariant growth: precise guarantee and counterexample

Candidate `I=sqrt(B0*B1)` gives continuous mint:

`m=S*(sqrt((B0+a)*B1)/sqrt(B0*B1)-1)`.

Then `I_after/(S+m)=I_before/S`: **geometric invariant per share is preserved**. This is not an external market-value guarantee. Current `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:58–64` uses ceil-before-root, floor-after-root and floor issuance. Those favor incumbents in this invariant metric, not necessarily in market value.

**Exact-root counterexample:** before deposit B0=B1=100, S=100. External prices are fixed P0=2, P1=1; no fees, price movement or placement loss. Deposit 125 token1. New invariant is sqrt(100*225)=150; mint 50 shares. Invariant/share remains 1. But incumbent market value changes from 300 to `(100/150)*(200+225)=283⅓`. Entrant's pro-rata claim is worth 141⅔ despite contributing 125. Incumbents lose 16⅔ in that market metric. Scale amounts/share units to make fractional payouts representable; the effect is not one-wei dust.

Frozen concentrated inventory can have a ratio unlike external price. No conclusion here asserts this exact state is an executed wings exploit; it disproves the general market-value-preservation claim.

## 4. Market-value issuance is possible, but needs a trusted valuation

Given fixed reliable positive prices, let `V=P0*B0+P1*B1`, net contribution value `v=P0*C0+P1*C1`, and mint `m=S*v/V`. Then incumbents retain `S/(S+m)*(V+v)=V`, and entrant receives value v before rounding. No balancing swap is required. In the counterexample this m is 41⅔, not 50.

This preserves mark-to-market value **at those prices**, not each token quantity, future value or executable scalar liquidity. Decimals, contribution costs and share floors must be explicit. A manipulable/stale price can instead overmint shares. A TWAP is a chosen risk model, not automatically truthful fair value. This would select a valuation-admission design currently unselected by PRD:150, not merely optimize code.

## 5. Redemption and cross-mode consistency are inseparable

For the continuous invariant model, after token0 deposit a, let `q=m/(S+m)=1-sqrt(B0/(B0+a))`. The local CP scalar payout in the deposited token is `(B0+a)*(2q-q²)=a`. Thus a same-token immediate round trip is neutral **under fixed state, zero fees/losses, exact arithmetic and sufficient local cover**.

This corresponds to the entitlement-plus-internal-conversion shape at `StandardExchangeConstantProduct.sol:98–110`. It does not prove safety for opposite-token exits, proportional exits, external swaps, changed wing prices, or idle↔blocked cycles. The numerical counterexample already shows proportional redemption differs economically. Pair admission and every redemption mode in one specification; no hidden switch from invariant minting to fair-value scalar redemption.

Integer execution must prove its own no-positive-roundtrip property using actual root/entitlement/fee floors. Generic ≤1-wei error is unjustified. Entry/exit fees and external placement loss are distinct; specify payer and whether fees remain backing or leave it. A no-swap deposit still has gas, rounding, inventory-risk and possibly usage costs.

If one backing side is zero, sqrt-product is zero and cannot price general issuance. Same-side linear mint is defined; adding the missing asset requires explicit valuation or a separately selected rule. Current helper `:49–51` ignores an addition solely to a zero-backed side; do not adopt that as useful acceptance. Empty supply/bootstrap and nonzero supply with zero total backing require separate treatment. An output owed economically still requires local F when blocked; otherwise atomic revert, not burning shares for partial payment.

## Few actionable owner questions

1. **Which guarantee should “preserve value” mean?** Market-value-neutral issuance using an approved valuation source, or invariant-growth issuance with implicit inventory-price impact? I recommend the former if preservation of both parties' external value is literal; the latter if accepting AMM-style exchange economics is intended. Neither is approved or proven safe here.
2. **Does “no typical zap” apply to redemption too?** May idle single-token exits perform an underlying swap, while blocked exits use a separately specified local conversion, or must both use the same no-swap economic rule? Proportional exit availability must be stated alongside this choice.
3. **What fee/loss and edge-state policy should accompany that choice?** Select entry/exit charges, who bears placement rounding, and whether missing-side deposits are valued and accepted; retain dual activation unless separately changed. These determine exact formulas, not just UX.

Geometry parameters and chain/work budgets remain in the existing register, but neither settled reserve definition should be reopened. Proposed next PRD correction: distinguish custody safety, invariant/share, marked value/share, per-token ownership and payout capacity as separate acceptance properties; include the counterexample and complete deposit/redemption cycles. No economic formula becomes safe through consensus or historical reuse.
