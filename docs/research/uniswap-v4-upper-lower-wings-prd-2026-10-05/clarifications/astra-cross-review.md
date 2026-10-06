# Astra — clarification combined cross-review

2026-10-05. Read all three other clarification originals completely together. No cross-review reads, shell, tests, implementation or PRD edits. Original preserved. Arithmetic below is independently hand-checked; not execution evidence.

## Conclusion retained

**No-swap scalar issuance is possible.** What requires selection is its ownership pricing—not whether to abandon useful scalar service. Fixed-mark value neutrality, invariant/share preservation, per-token quantities and local payout capacity are different properties. The owner has not prohibited virtual pricing or no-swap exits.

Custody remains local-only. Sleeve target remains per-token `F=pD` for **vault-owned** deployed principal, solved after placement as `F=T*p/(1+p)` in fractional units. No reopening either definition.

## 1. Correct the impossibility and virtual-execution claims

Grok's per-token dilution proof is correct for a positive two-sided book: minting m>0 after `(c,0)` reduces token1 per share. His conclusion that only balanced deposits or nonfungible claims can be useful is false. At fixed reliable prices, with complete pre-deposit `V=P·B`, net contribution `v=P·C`, mint `m=S*v/V`; then incumbent marked value remains `S(V+v)/(S+m)=V`. This needs no AMM swap. It changes quantities and risk exposure, not marked value at that snapshot.

This is a candidate economic design, not oracle endorsement. B must include **F+D+E**, excluding current credit/liabilities. Neither the sleeve denominator nor manipulation concerns justify pricing ownership over D alone.

Virtual internal conversion reallocates claims and may pay from existing custody. It is an economic exchange, but does not execute an underlying AMM swap or incur that swap's gas/fees/tick movement. Grok cannot exclude it by interpreting “no typical zap.” MiniMax likewise cannot assume the owner has prohibited external exit conversion. Ask about exit policy rather than infer it.

## 2. Numerical audit

**Grok:** the coarse-share examples are numerically sound: m=9 on a 120/100 post-book gives approximately 9.908+8.257=18.165 at equal marks. But an external swap is not mandatory to deliver scalar value: sufficient local inventory and an approved conversion rule can do so. Paying 20 for these rounded nine shares is not the exact existing CP rule, but that does not establish universal impossibility.

**MiniMax's zap example double-counts contribution.** With an independent zero-impact, fee-free 1:1 swap, caller basket becomes 50/50; incumbent backing remains 100/100. Mint 50 shares, final backing 150/150 and supply150. Entrant value100; incumbents retain200. Using final150/150 as pre-contribution denominators incorrectly produces33 shares. Own-position repricing, if present, must be separately modeled; it cannot justify that double count.

**MiniMax's CP example ignores token1 value.** With B=(100,100), S=100 and deposit100 token0, m=41 gives pro-rata value `300*41/141=87.234…`, not58.16. Loss versus deposit is12.766… at equal marks before payout flooring. Integer pro-rata payouts (58,29) sum87: loss13 already includes payout floors; do not add another0.84. Continuous mint41.421… gives value87.868…, not a neutral deposit. Fair marked-value issuance would mint50 shares, representing one-third—not one-half—of the final300-value book.

Min-ratio m=0 does not leave K or incumbent value unchanged if input is retained: backing increases as a donation. Zero-share successful money paths should not be silently accepted. MiniMax's claim that every single-sided deposit subsidizes incumbents is false generally: my original unequal-mark counterexample remains valid (B=100/100, P=2/1, deposit125 token1, mint50: incumbent value300→283⅓).

**Kimi:** the coarse-unit result m=4, scalar payout8030 on the 10,000 deposit is correct for the cited helper. It is not evidence of unavoidable double impact. In continuous fixed-state fee-free arithmetic, invariant issuance followed by matching same-token CP redemption returns exactly the deposit. Root/share/entitlement floors explain this particular loss. Also `c²/(8r²)` is a term in the normalized mint expansion, not a general relative value-loss bound: at matched initial CP marks, pro-rata marked-value loss has leading order `P*c²/(4r)`, relative to contribution `c/(4r)`.

Source checked directly: `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:37–64,98–110`. Its zero-reserve branches at49–51 return zero for missing-side-only input; they do **not** reach the square-root division-by-zero claimed by Kimi. Same-side linear issuance is well-defined.

## 3. Reject the purported sleeve-only manipulation bound

Kimi's attack example switches from a proposed sleeve-adjusted B to bare pool reserves when calculating mint, then assumes a post-reversion vault book without deriving position transitions. It is not a coherent execution trace or extraction bound. Profiting by deposit normally involves the admission rule **overvaluing**, not undervaluing, the supplied token relative to an external benchmark.

More fundamentally, concentrated D need not track spot through `D1/D0` even when F=E=0. For a finite range with square-root endpoints1 and4, current square-root price3 and L=12, principal is `D0=12*(1/3−1/4)=1`, `D1=12*(3−1)=24`. Market token1-per-token0 price is9, but inventory ratio is24. No sleeve creates this discrepancy. Out-of-range positions strengthen the counterexample. Thus “sleeve × price move × deposit” is not a proven bound for wings, and pricing over D alone is neither a fix nor complete ownership accounting.

## 4. Direct orientation and accounting corrections

Grok's claimed PRD orientation bug is reversed. `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol:67–75` uses token0 when price is below a range and token1 above it. With price inside center, it is below **upper** and above **lower**: upper token0, lower token1. PRD is correct.

MiniMax's `R=F=balanceOf` and Kimi's “funding/refunds come from R only” are inaccurate. R is a durable custody snapshot; actual balance may differ. F is live spendable incumbent custody after exclusions. Valid new credit may be unbooked balance **above R**; refunds consume this-call unused credit, not booked R. Quotes must distinguish ownership entitlement from sufficient local output cover; cover-or-revert is not a valuation formula.

## Three human questions

1. **Which value promise do you want?** Neutrality for both parties at an approved price mark, or an invariant-priced internal exchange with disclosed inventory impact? Either can avoid AMM entry swaps; neither is automatically safe.
2. **Which redemption promise accompanies it?** Approved local no-swap scalar pricing whenever funded, external conversion on idle exits, and/or proportional basket exit? All allowed cross-mode cycles must be analyzed together.
3. **Which valuation/fee/edge rules should we specify?** For the selected model: price source or invariant parameters, explicit entry/exit charges and placement-loss payer, plus missing-side deposit behavior. Do not introduce queues, new subsidy commitments or arbitrary numeric safety bands by inference.

I retain my original fixed-mark proof, quantity impossibility and invariant counterexample. No full security proof or numerical manipulation bound has been established. Tests must use real SUT routes, include fees/rounding/capacity and all permitted exit modes, and separate paid arbitrage from unauthorized value transfer.
