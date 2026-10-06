# Astra — internal-pricing options, independent original

2026-10-05. Research only. Owner preferences are **not ratified requirements**. Read current wings PRD, CLAUDE, canonical testing/adversarial skills and current source directly; no peer artifacts, tests, shell, git or PRD edits. Numerical examples are analytical, not executed V4 traces.

## Finding

AMM-style internal minting, externally swapping withdrawals, and caller-paid operation fees can coexist mechanically. They do **not automatically form one consistent economic pricing rule**. Invariant-growth entry plus ordinary pro-rata external exit creates an inventory arbitrage venue whose price can differ materially from the underlying pool. Fees may reduce that opportunity without eliminating it. We must choose whether that inventory trade is intended, and specify all exit modes together.

Settled: R is local custody only; incumbent `B=F+ΣD+ΣE`; local cover is not economic valuation. `F=pD` targets this vault's deployed principal, with post-placement target `T*p/(1+p)`. No D-only pricing or balance-credit shortcut is proposed. Current source confirms these separations: Hookless `InventoryMath.sol:44–66` (`_free`, `_target`, `_totals`, `_collect`).

## 1. Formulas and the point of mismatch

Let pre-entry backing `(x,y)`, supply S, and net single-token1 contribution c after externally paid entry charges. Candidate continuous entry:

`m = S*(sqrt((y+c)/y)-1)`, `q = m/(S+m)`.

This preserves `sqrt(x*y)/S` absent fees retained in backing, placement loss, repricing or rounding. Current `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:58–64` implements the ceil/floor-root version; its comments are mechanism evidence, not safety proof.

Ordinary pro-rata external exit gives `q*x` token0 plus `q*(y+c)` token1, then sells the former through the pool. At approximately fixed external price P token1/token0 and deep liquidity, output before charges is `q*(P*x+y+c)`. For tiny c, this is approximately `c*(1+P*x/y)/2`. It exceeds c when `P*x>y`: the entry rule overvalues incoming token1 relative to an external mark. Concentrated D, sleeve F and earned E need not satisfy `y=P*x`.

## 2. Concrete round trip including fees and external depth

**Assumptions:** equal decimals; continuous token/share arithmetic; before entry B=(100,100), S=100; external pool price P=2. Vault's finite lower/upper positions are out of range throughout this small trade; center currently has zero liquidity (zero-liquidity slots are allowed by proposed PRD §5.3). Active liquidity is supplied by other LPs. Therefore vault-owned active LP fraction is exactly zero, earned E=0, and its remaining principal does not reprice during this particular swap. This is a specific supported-state candidate, not an all-states model.

Choose p=20% merely to illustrate the settled denominator: initially each token has F=100/6, D=500/6. No initial sleeve deficit. Entry and proportional removal can allocate/remove outside active price without changing active pool liquidity. Ignore placement integer losses in this continuous example; execution must later measure them.

1. Entrant pays **126 token1**: a hypothetical **1-token1 entry operation fee goes outside the vault**; credited contribution c=125. B becomes (100,225). There is no entry swap.
2. `sqrt(100*225)=150`; mint50 shares. Supply150, ownership q=1/3. Idle placement may restore sleeve to F=(100/6,225/6) without changing B or active depth.
3. Burn the50 shares. Realize proportional local plus wing inventory: **100/3 token0 and75 token1**. Remaining holder backing is (200/3,150), supply100.
4. Swap 100/3 token0 through the underlying active segment. Let active **virtual** reserves be X=10,000, Y=20,000, with no tick crossing; these parameterize the segment, not vault D or custody. Charge 0.3% total input swap fee, all to external LPs and zero protocol take for this example. Effective input is `997/30`; fee is0.1 token0.
5. Continuous output is `Y*a/(X+a) = 19,940,000/300,997 ≈66.2465 token1`. Pool price falls from2 to `2/(1+997/300000)^2 ≈1.98677`; it is not falsely held constant. Bounds can be selected so no owned-position boundary crosses.
6. After another hypothetical **1-token1 exit operation fee**, entrant receives `75+66.2465−1=140.2465 token1`. Against126 paid, profit is **14.2465 token1 before gas/financing**, despite both operation charges and the underlying trading fee.

The entrant has no residual token exposure. Own LP fee recovery is **exactly zero under the explicit active-liquidity assumption**, not silently credited to the withdrawer. Incumbents retain market value `2*(200/3)+150=283⅓` at the original external mark versus300 initially. If external arbitrage restores price2 afterward, these out-of-range holdings remain unchanged. That restoration is a separate trade, not part of the entrant's required cycle.

This demonstrates funded **extractive holder value transfer at the stated mark**, not an unfunded-credit exploit or proof of whole-vault drain. It may be intentionally accepted AMM inventory arbitrage, but must not be mislabeled dilution-free. Static-price repetition changes the book and therefore opportunity; no constant-profit repetition or loss bound is established. Adversarial pool moves, fee manipulation, multiple exits and replenished sleeves may create further cycles. The economic result is not bounded by sleeve fraction: idle redemption realizes D too.

## 3. Options compatible with the preferences

**A — Ordinary pro-rata external exit.** Keep each exiting holder's basket entitlement, swap only that basket, and return measured proceeds less explicit costs. This is simple ownership/settlement accounting. Accept and quantify internal-versus-external inventory arbitrage as a product risk, or constrain entry when the mismatch is unacceptable. Do not claim any fixed small fee defeats all inventory skews.

**B — Paired internal economic exit, external settlement when needed.** For the same invariant, internal scalar token1 entitlement is `(y+c)*(2q−q²)`. In the example this equals125 before exit fee; a locally funded payout gives124 after fee, a2-token1 roundtrip cost. This is the continuous inverse-shaped result reflected in `StandardExchangeConstantProduct.sol:98–110`, unlike ordinary basket liquidation.

An external swap may source payout currency, but must not silently change the pricing rule to “all external proceeds.” Specify removal budget, who retains favorable execution surplus, who pays shortfall/price impact, and a terminal holder-backing certificate. If execution cannot fund the obligation within approved user budgets/protection, revert. Paying a fixed internal amount while socializing arbitrary external slippage is not caller-paid cost. Paired pricing can also be bypassed economically if unrestricted proportional exits remain; analyze the complete advertised route set, not just the preferred scalar route. This option is a proposal, not automatically safer.

**C — Inventory-aware/virtual-reserve entry.** Retain an AMM curve but set its marginal pricing/depth using a defined reference or adjusted inventory coordinates rather than assuming physical B has market-ratio geometry. This is not necessarily oracle NAV issuance. However virtual reserves are not backing or payout assets; offsets, weights, anchor updates and zero-sided domains require explicit accounting. An anchor update must not manufacture mintable “growth.” Price-reference gates and size limits can bound a specified domain only after a proof/measurement of their relationship to adverse execution. Spot-only reference can itself be manipulated. No numeric threshold is recommended as sufficient here.

## 4. Fee and budget contract

Separate: explicit SE operation fees; underlying LP/protocol/hook fees; AMM price impact; liquidity-placement rounding/loss; transaction gas; later optional maintenance. They are not interchangeable charges.

* Entry credit must be measured first, incumbent B exclude it, and fees leaving the vault reduce contribution. Retained fees need separately specified beneficiary/timing; do not reuse the paid-out-fee example unchanged.
* Withdrawal realizes entitlements before conversion. Charge actual execution fees once—fee-inclusive swap output already reflects them. Do not subtract the same LP fee again as an “operation fee.”
* Prior E belongs to pre-exit holders pro rata. Fees from the subsequent swap earned by **remaining** owned positions accrue to remaining holders, with own principal repricing also accounted separately. Positive own active liquidity requires per-step source-exact projections; no universal flat fee rebate. Hookless `TransitionPlanner.sol:133–140` already separates price, deployed principal and earned growth for one position; wings need all three.
* Required caller-triggered placement/removal costs need attribution and user bounds. Later discretionary holder maintenance is not automatically chargeable to an earlier depositor after their transaction. If delayed costs are intended to be prepaid, define the reserve/charge explicitly. Gas normally belongs to the outer transaction payer; do not invent vault reimbursement.

## 5. Edge states and few choices

For y=0 or x=0 the geometric rule degenerates. Same-side positive-backing linear issuance is possible; missing-side-only input requires an expressly selected rule (current helper:49–51 returns zero). Do not erase F/E when D becomes one-sided. First mint stays a separate decision. Dust mint must fail before retained donation unless explicitly offered as donation.

Blocked routes cannot externally swap or realize D/E; local capacity must cover the selected economic payout or revert. Choosing internal exit when blocked and ordinary external exit when idle is choosing two prices; analyze blocked-entry→idle-exit and the reverse. An F=pD target does not guarantee cover after a large deposit/withdrawal.

**Actionable choices for owner, not ratification:**
1. Is exit entitlement ordinary pro-rata basket proceeds, or paired internal scalar pricing with separately budgeted external settlement? Which alternative exits remain available?
2. Is internal inventory arbitrage accepted within a specifically bounded useful domain, or should entry pricing/gates track an approved reference? This does not force NAV issuance.
3. Specify operation-fee recipients/timing and who retains favorable execution versus bears adverse execution/placement costs; distinguish later maintenance.

Confidence: high in continuous algebra and cited source behavior, medium in mapping the illustrative state to a fully deployed wings fixture; no integer implementation trace or security/gas result established. Context7 `/uniswap/v4-core` followed by primary https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/SwapMath.sol (access2026-10-05, mutable main, pragma ^0.8.0) confirms fee-inclusive step semantics; numerical example deliberately does not claim Q96/wei exactness. Required validation would use real SUT/PoolManager and complete outer routes, not canned prices or mocked wings.
