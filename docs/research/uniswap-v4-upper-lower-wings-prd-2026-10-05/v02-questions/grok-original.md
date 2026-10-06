# Grok — questions on wings PRD v0.2 (2026-10-05)

Read `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` only as the current proposal. No PRD edit. Settled items in §15.1 are not reopened.

v0.2 wing orientation matches `LiquidityAmounts.sol:67-75`. Price below an upper range is token0. Price above a lower range is token1. That is not a question.

## Blockers — owner should answer

**1. What happens when whole-vault `V` cannot be completed?**  
§7.V2 (`:154-156`) forbids inventing proceeds for unsold opposing inventory, and also forbids freezing ordinary routes by default. Those two sentences conflict.  
Recommendation: any mint or redemption that needs `V` reverts with a typed incomplete-liquidation error. No stale price, no basket exit, no haircut. Proving the domain is engineering, not an owner proof.

**2. Ratify the share-growth formula already written at V4 (`:172`).**  
`m = floor(S * (V_after - V_before) / V_before)`. The PRD still calls this unratified (`:178`). The basis, whole-vault liquidation value, is settled.  
Recommendation: ratify this formula. `floor(S * credit / V_before)` is an optimization the implementer must prove equivalent, not a second policy. Do not ask the owner to supply the proof.

**3. Who pays the one operation fee and entry placement loss?**  
V5 (`:186`) says the initiator bears specified fees and that costs already inside `V` are not charged again. It does not say whether the fee is deducted from the user’s gross target or taken from the book on top. V4 (`:174`) also leaves the placement-loss payer open.  
Recommendation: `net = gross - one operation fee` to `feeTo`. Entry placement loss reduces credited `C` once, before `V_after`. Withdrawal overshoot stays in the book (already settled). Holders’ `V/S` is the pre-withdrawal benchmark (`:196`), not a second fee.

**4. Must an ordinary idle user call harvest a converted wing?**  
G3 (`:114`) leaves this open. Settled rule: the balancing zap stays on separate rebalance (`:33`, `:238`).  
Recommendation: deposits only observe eligibility. A withdrawal removes a wing only if the payout priority needs it. Rebalance performs harvest. That keeps the expensive zap off user routes without a new strategy.

## Parameters — not strategy blockers

Confirm or defer to plan sign-off. Do not treat the written proposals as already approved.

- Sleeve number and deadband (`:232`): proposal is 20% and 5% of target free. Denominator `F = p·D` on owned deployed target is settled.
- Target-only minimum and share decimals (`:164`, RV-6). Recommendation: scale shares to target decimals; lock a small sink minimum; pre-existing residual value goes to the sink. Do not reuse the two-token square-root bootstrap.
- Exact-output (`:268`, RV-8): not settled. Recommendation: exact-in only until an integer inverse is proved. That proof is engineering.
- Native ETH (`:277`): do not advertise it in v1.
- 90% of the chain transaction cap (`:348`) and the chain list: release parameters. Verifying EIP-7825 activation is engineering. Prior 1.28M figures are not evidence (`:48`).
- Rebalance loss bound (RV-7): the plan should propose a number. Copying FullSpread 25/50/10/1 bp is not authorized (`:311`).

## Contradictions and assumptions — not new owner votes

- §9 requires native SY (`:269`). RV-8 still lists SY lists as open (`:379`). Follow §9 for target and share only. Opposing token stays off the lists (`:266`). Enumeration is engineering.
- §7A.4 (`:210`) says in-range removal order must be specified. Read it as engineering under the settled rule “core last”: mixed in-range wings before core. Do not reopen opposing-wing-before-core.
- `V` is manipulable by external liquidity around the hypothetical removal (`SEC-08`, `:301`). The PRD does not assume it is safe. Proving no unbacked overmint is an implementer obligation.
- Incomplete `V` is not solved by a stale price. Assumption to reject: that a quote may return a partial fill labeled complete (`:154`).
- Blocked redemption does not haircut (`:249`). It reverts with requested and available. A `B`-based quote is not local cover.

## Not questions

Target-only flows, full-range core, wings from the nearest outside tick to the usable limit, target sleeve on owned deployed principal, harvest eligibility at nonzero opposing principal, rebalance may zap, opposing wing before core, retained overage, and the blocked requested/available error. Tick math, consumer matrices, gas measurement, and the non-dilution proof are implementer work. The owner should not be asked for those proofs.
