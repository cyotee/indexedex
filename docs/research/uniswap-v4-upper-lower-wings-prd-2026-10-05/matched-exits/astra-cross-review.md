# Astra — matched exits combined cross-review

2026-10-05. All three other originals read completely together; no cross-review artifacts. Original preserved. No execution or PRD edits. Conclusions are conditional analytical comparisons, not ratification.

## Arithmetic and reference-state corrections

**Grok:** Cases1–2 correctly use the pre-withdrawal remaining-holder claim. I agree with the main distinction: preserving that claim on basket liquidation does not reverse earlier entry mispricing. However capped B with retained favorable surplus is genuinely distinct from A; it is not always “A or revert.” His case1 title should distinguish initially balanced entry from the post-entry book ratio144/100, which is no longer the external1:1 price. Inactive positions and infinite depth are substantive assumptions.

**Kimi's skew case is wrong numerically.** For pre-entry B=(1400,700), S=1000, deposit140 token0, market2 token0/token1:

* `m=1000*(sqrt(1.1)-1)=48.808848…`, not48.21.
* Fraction `f=1-1/sqrt(1.1)=0.046537411…`.
* Basket `e0=71.667613…`, `e1=32.576188…`.
* Continuous internal payout is **exactly140**, since `(B0+c)*(2f-f²)=c`; not138.39.
* Deep external payout with0.3% input fee is `e0+2*0.997*e1=136.624530…`.
* Internal/external gap is3.375470…, comprising3.180012… marked basket difference and0.195457… external fee.

This is a scaled initially price-matched example, not evidence of concentrated book/market divergence. Kimi's claim that internal entitlement systematically exceeds external proceeds is false for genuinely mismatched book prices; my original125-token1 example has external proceeds above internal entitlement.

**MiniMax mixes integer and continuous rules.** With coarse-unit m44 and basket floors54/36, current `_singleExit` floors `246*36/200` to44, so code returns **98**, not98.28. Keeping continuous entitlements at that same fraction instead produces `366300/3721≈98.4413`. A continuous entry would itself mint44.948974… shares. Choose one arithmetic convention throughout.

Taking his illustrative98.28 payout at face value does not preserve holders: final marked value401.612 is below the **matched pre-withdrawal claim409.836…**, regardless of exceeding the earlier400 investment. A `B/S≥1` threshold is meaningless without specifying asset units and share scaling. His210 gap allowance is not a holder-preservation bound. At unequal prices, never add token0 and token1 quantities without conversion. If his P is token0 per token1, P=0.5 makes token0 more—not less—valuable. His table's “B1 dominates A” also reverses the withdrawer's ordering: `min(T,Z)≤Z` pointwise.

MiniMax's ledger must not subtract placement from economic B: deployment transfers F↔D, with only explicit losses leaving backing. Fees, pool transfers and repricing require separate terms. “Value = value + minted shares” is dimensionally invalid. A mismatched single-token deposit cannot turn full-range deployed200/200 into300/200 at fixed1:1 price without retaining local tokens or changing the proposed position state.

## Preservation means more than one thing

A is a clean **allocation benchmark**: proportional removal leaves `(1-f)` of each pre-withdrawal component, subject to source rounding. It does not universally preserve final token quantities or marked value after the exit swap reprices remaining active positions. New own fees accrue to remaining holders; they can arise within the same transaction, not only through elapsed time. My original active-range case explicitly accounts for both. Kimi's exact-preservation statements require the inactive/no-repricing assumptions or this decomposition.

B paid directly from local custody exchanges assets between exiting and remaining holders. Externally settled B can do the same if it guarantees T using assets beyond the basket. A fixed internal quote alone proves neither absence of extraction nor mode neutrality. Gas for A/B is not automatically identical merely because removal/swap actions match; validation and quote work differ.

A complete B specification must select shortfall haircut, revert or caller funding; surplus recipient; and allowed incumbent budgets. Its scalar marked-value guarantee is not vector preservation. Unrestricted proportional exit still lets users synthesize A when B withholds favorable execution. That is an economic bypass, not solely fee avoidance; separate disclosed conversion-service fees are possible but require an availability/UX decision, not a blanket double-charge prohibition.

## Regions, zero reserves and capacity

Price above all ranges leaves deployed **token1**, not token0. A dormant position need not have zero principal. Outside-range D can be one-sided while F/E keep B two-sided. `StandardExchangeConstantProduct.sol:49–51` returns same-side linear issuance before the root branch; with B1=0, token0 input gives `amount0*S/B0`. Missing-side-only input returns zero, not the claimed root-division revert. Zero shares must not silently become a waiting receipt.

Blocked execution cannot realize D or E. Positive total backing is never local cover. MiniMax's proposed use of “book capacity” contradicts settled funding constraints. His eventual corrected blocked-deposit decomposition F0=100,D0=200 can fund an output below100; an otherwise identical **F0=0** state cannot. Requiring live funded execution does not select the payout formula.

## Unsupported risk conclusions and next comparison

Reject “no extraction possible,” “recurring but not draining,” and dimensionally unspecified divergence bounds. A same-token continuous inverse identity covers a narrow fixed-state cycle, not opposite outputs, basket exits, forced blocked mode, changed prices or own-fee interactions. Entry impact is a valuation transfer, not automatically compensation for maintenance or a protocol fee. Round-trip gas cannot serve as a universal security margin.

The useful conclusion is now sharper: **A preserves the exiting basket allocation; B additionally selects who receives the difference between internal entitlement and executable basket value.** Compare three explicitly budgeted B policies against A, keeping state/fees/geometry identical: haircut, rejection/top-up, and authorized holder-funded shortfall. Include favorable-surplus disposition, proportional bypass, and every blocked/idle path. Do not reject useful scalar service or select arbitrary gates to hide a mismatch.

Owner-facing questions should concern those distributions and availability tradeoffs—not custody definitions or premature formula ratification. No measured gas, global loss bound, simulation or security proof exists in this round.
