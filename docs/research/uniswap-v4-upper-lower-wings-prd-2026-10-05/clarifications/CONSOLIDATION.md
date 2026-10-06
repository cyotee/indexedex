# Wings requirements clarification — council consolidation

Date: 2026-10-05. Research only. PRD unchanged. Four independent originals and four combined cross-reviews completed in the retained researcher sessions; each review received all three other complete originals, never cross-review answers.

## Sessions and attributed evidence

| Member | Session | Original | Review |
|---|---|---|---|
| Astra | `ses_ef7c68835ffey58T5UT2G8JDZo` | [Original](astra-original.md) | [Review](astra-cross-review.md) |
| Grok | `ses_ef7c1c50fffe87e6QGupvs3xke` | [Original](grok-original.md) | [Review](grok-cross-review.md) |
| MiniMax M3 | `ses_ef7bc045effeTc96xsW5R2MidY` | [Original](minimax-original.md) | [Review](minimax-cross-review.md) |
| Kimi K3 | `ses_ef7b7b72fffe3JJ0CVG6FmBRGL` | [Original](kimi-original.md) | [Review](kimi-cross-review.md) |

One empty task invocation was aborted before a researcher was targeted; it produced no participant result. No researcher was replaced. The eight substantive researcher turns completed.

## Settled by the owner, not a council vote

1. Reserve tracking is local custody only, never deployed inventory or total pool reserves.
2. Sleeve denominator is the vault's own deployed principal across its positions.
3. Ordinary single-token admission should not require the typical external balancing zap. This does not prohibit virtual/internal pricing or determine exit behavior.

Maintain distinct terms: `R_i` is the durable booked local snapshot; `F_i` is actual spendable incumbent local inventory after excluding current credit and liabilities; `D_i` is vault-owned deployed principal; `E_i` is own uncollected fees. Ownership backing is `B_i=F_i+D_i+E_i`. R need not equal the current token balance between synchronizations. Available valid inbound credit can be above R; refunds must not consume R as caller credit.

Per token, desired post-placement `F_i=pD_i` implies `targetFree_i=floor((F_i+D_i)*pWad/(1e18+pWad))` in lossless arithmetic. For example, with F=40,D=100,p=20%, deploy 16⅔, leaving F=23⅓,D=116⅔. Placement rounding/losses and capacity must be reconciled. E is backing but not spendable sleeve until collected. The definition does not approve the proposed 20% default or deadband parameters.

## What value preservation can mean

Positive fungible issuance for a token0-only deposit necessarily lowers token1 units per existing share when token1 backing is positive. Thus preservation of every individual token quantity is impossible, but preservation of a selected scalar value is not.

**Fixed-mark pricing:** for reliable fixed positive price marks, V=P0*B0+P1*B1 and v=P0*C0+P1*C1. Continuous mint m=S*v/V preserves incumbent marked value because S/(S+m)*(V+v)=V. No external swap is mathematically required. It changes exposure and requires a trustworthy valuation policy, complete backing and correct rounding, fees and loss attribution.

**Invariant pricing:** with I=sqrt(B0*B1), m=S*(I_after/I_before-1) preserves I per share in continuous arithmetic. It does not generally preserve external market value. Integer implementation evidence exists in `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:37–64`; its existence is not a wings security proof.

Counterexample: B=(100,100), S=100, fixed prices P=(2,1), deposit125 token1. I grows100→150; m=50. Final marked value425; old holders own100/150 worth283⅓, versus300 before. Entrant owns141⅔ despite paying125. No manipulation or rounding is needed to demonstrate the distinction. This is analytical, not an executed exploit.

The same candidate invariant mint paired with matching scalar CP exit can return the exact deposit in continuous fixed-state, fee-free same-token round trips with sufficient local cover. That identity does not prove opposite-token/proportional exits, price-changing or idle/blocked cycles safe. Current `_singleExit` is at the same file:98–110. Zero-reserve branches at49–51 return linear same-side credit or zero for missing-side input; they do not enter the alleged square-root division-by-zero branch.

## Attributed positions and corrections

- **Astra:** distinguished the value metrics, supplied fixed-mark neutrality proof and unequal-mark counterexample, and emphasized paired exit rules. Cross-review independently rejected sleeve-only manipulation bounds and checked peer arithmetic.
- **Grok:** initially extended the valid token-quantity impossibility into an invalid general no-swap impossibility. Cross-review retracted the virtual-pricing prohibition and accepted fixed-mark issuance. It continues to invert wing orientation; this is rejected against local `LiquidityAmounts.sol:67–76` (upper initially token0, lower token1).
- **MiniMax:** initially claimed no fair no-swap issuance, equated snapshot with live custody and supplied incorrect valuation examples. It corrected the omission of token1 from one example, but its review still asserts an always-entrant-to-incumbent transfer and a sleeve-only bound, contradicting the unequal-mark counterexample. These claims are not adopted. Nor are its claims that finite-range balances jump discontinuously or become zero simply on entering range; principal amounts change continuously with price, with piecewise regimes.
- **Kimi:** initially favored geometric preservation and proposed a sleeve-based risk bound. Cross-review accepted fixed-mark versus invariant distinctions and retracted the claim that zero-sleeve concentrated backing necessarily tracks pool price, and its interpretation of integer round-trip loss as two inevitable price impacts. Its additional external-swap comparison is not adopted as a matched scenario: venue depth and owned-liquidity effects were not fully specified.

### Why the supposed sleeve-only bound is insufficient

Even one concentrated position with F=E=0 need not have inventory ratio equal to market price. For sqrt endpoints1 and4, current sqrt price3, liquidity12: D0=12*(1/3-1/4)=1 and D1=12*(3-1)=24, while token1-per-token0 market price is9. Wings make the backing/price relationship state-dependent even without a local sleeve. Do not price ownership over D alone and ignore F/E, or promise a bound proportional only to sleeve size.

## Questions for the owner

1. Is the intended promise neutrality for both parties at an approved price mark, or AMM-style invariant pricing with disclosed inventory-price impact? Both can avoid an external entry swap.
2. What exits must pair with it: proportional basket, locally funded scalar conversion, external conversion while idle, or a specified combination? No-zap entry does not settle this.
3. What fee, placement-loss and edge-state policy accompanies the selection, especially deposits into a missing backing side and dust that would mint zero?

These questions should be answered before numeric oracle bands or a final mint formula are ratified. Geometry, sleeve percentages and work budgets remain in the existing PRD register, but local-only custody and vault-owned sleeve denominator are settled.

## Confidence, evidence and handoff

High confidence in custody separation, sleeve algebra and the conditional value proofs; no confidence claim about production security or gas. Moderator directly read the PRD:104–203 and `StandardExchangeConstantProduct.sol:1–130`. Local liquidity orientation was directly read in the preceding bounded round. No tests, simulations or chain measurements were run; no new runtime/version result exists. Incidental LSP diagnostics do not establish pre-existing failures.

Saved findings preserve errors and corrections with attribution; agreement is not proof. After owner selection, a separate authorized document revision should mark the reserve definitions settled, remove mandatory external composition from ordinary entry, and specify the chosen mint/exit economics. Only after PRD satisfaction should implementation planning begin. No code or implementation plan was authored here.
