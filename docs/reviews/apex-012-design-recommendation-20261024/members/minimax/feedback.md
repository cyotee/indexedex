# Member feedback

## Identity

- Run ID: apex-012-design-recommendation-20261024
- Member label: minimax
- Profile: research
- Phase: advisory feedback on coordinator draft
- Owned path: docs/reviews/apex-012-design-recommendation-20261024/members/minimax/feedback.md
- Requested role: council-member (advisory review of the draft only)
- Requested model and reasoning: minimax/MiniMax-M3
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued (same session as my member response)
- Peers read before submission: no (I read only the brief, the two admitted PRDs, the V4 Wings money library, the ULW synthesis, and the coordinator draft)

## Draft reviewed

`draft-apex-012-design-recommendation-20261024-r1` at `docs/reviews/apex-012-design-recommendation-20261024/coordinator/draft.md`, read in full against my member response at `docs/reviews/apex-012-design-recommendation-20261024/members/minimax/response.md`.

## Disposition

Support with reservations. The draft's family split is a fair reading of the field, and its account of Family A is not mine to contest. Four things need correction or restoration before this becomes the owner-facing report: one factual misstatement of my exit rule, one mischaracterization of my mechanism that conflicts with my own refusal list, one criterion substitution that decides the question by definition, and one dropped constraint plus one dropped cost. I am not picking a family, and nothing below asks the owner to.

## Concerns

**1. The draft drops the target leg from my exit rule.** The draft says of Family B: "Exit removes that fraction and sells only that slice's other token. The holder is paid the target that sale delivered." My exit rule pays "the target removed plus the target the swap delivered, and nothing else." A redeemer receives their pro-rata share of the position's target leg plus the proceeds of selling their own slice of the other token. Omitting the target leg makes the exit look like a bare token swap and understates what the holder receives. This is a factual misstatement of my design, and it changes the economics the owner would be comparing.

**2. "That is a rate and a different exit price" does not describe my mechanism, and it contradicts my refusal list.** My design uses no price in either path. The rate is a stored counter of settled target over supply; the exit is a real market swap whose proceeds are delivered to the holder. There is no mark for the rate and no zap for the redemption, so the PRD's banned split (a reference price for the rate and a zap-out for redemption) is not what my design does. My rejected-alternatives list explicitly rules out marking the other token with a TWAP or a Chainlink price for exactly that reason, so the draft's sentence reads as describing a design I refused. The underlying concern is real and I stated it myself: the published rate is not what a redeemer receives. That should be written as a cost of Family B, not as a violation of the split rule, unless the coordinator means something narrower by "different exit price" than I do.

**3. The draft substitutes "one number" for the brief's "one rule", and that substitution decides the question.** The brief's constraint is "Deposit, redeem, and the rate must use one rule," and the split it prohibits is specifically one price for the rate against a different zap-out for redemption. The draft's criterion is "If deposit, redeem, and the rate must be one number, the council's designs that satisfy that constraint are Family A." My design uses one rule (a share is a fraction of the position; deposit, redeem, and the rate are all expressions of that fraction), but the exit delivers realized amounts rather than a single number. Under the brief's wording, one rule is the test and my design is inside it; under the draft's substituted test, one number is the test and it is outside. I am not claiming the draft's framing is illegitimate, but the owner should be told that the criterion was narrowed, and told which criterion the recommendation is being made under. As written, "This draft does not recommend Family B unless the owner accepts that the published rate is not the exit price" gates Family B behind a condition that Family B as I wrote it cannot satisfy, which functions as a rejection by definition rather than by argument.

**4. The shared-refusal list drops a constraint from the brief.** The brief requires that "Temporary liquidity and an in-transaction price move must not mint shares or move the rate." It is absent from the draft's refusal list. In my design it is satisfied by a specific mechanism: the mint is computed from token amounts (added target measured against the target leg of the existing position), so no external liquidity or price move changes the share count, and the rate moves only when target crosses the vault's boundary in a vault operation. This belongs in the report, because it is the constraint that distinguishes a manipulable design from a safe one and it is what makes the token-amount mint rule worth stating.

**5. Family B's cost is missing, so the two families are not comparable in the draft.** The draft gives a cost paragraph for Family A and none for Family B. The costs I stated are: the rate under-reports the position for as long as the other leg is material, so a rate consumer must haircut it; the rate converges toward true position value only as holders exit and the other leg is converted, so a vault with no exits has a flat rate that does not track its position; every deposit needing an add-side conversion and every exit trades against the vault's own pool, and the remaining holders take the fill, which is a real transfer from the redeemer to the pool; entry conversion adds a manipulation surface bounded by the minimum received and the vault's share of pool depth; and the implementation cost is asymmetric, since the V4 family needs the quote removed from the money path plus a new settled-target counter, while the V3 Upper Lower Wings family does not exist and would have to be built to the same accounting. The owner cannot weigh two families when only one has its cost written down.

**6. Two refusals specific to my design are not carried, and one of them explains the cost.** My design refuses to sell the position's other token outside the acting holder's own entry or exit (no keeper rebalance, no harvest-time liquidation of principal), and it refuses to open a new range on a deposit or treat a donation as inventory. The first is load-bearing: it is the reason the other leg is converted only when a holder exits, which is exactly why the rate converges only as holders exit. Without it the cost paragraph in concern 5 looks unmotivated.

**7. Two small points.** The draft's phrase "a fraction of the live ranges" drops that the fraction is of the whole position, core and both wings together, plus idle balances of both tokens, not of a single slot; the fraction-of-position wording is what carries the one-rule claim. And the draft's Family B description does not record the two owner rulings I asked for: whether the rate may be a conservative settled-target floor rather than an exact mark, and whether the deposit may convert part of the target in-pool to make the add proportional. The draft covers the second in its entry-conversion paragraph; the first appears only in the rephrased form of concern 3.

## Limits

Advisory only. I did not edit the draft, did not read peer responses, and did not verify the coordinator's characterizations of Astra, Grok, or Kimi against their own files. No Forge run, no contract reading beyond what my member response already cited, no implementation. The judgment in concerns 2 and 3 is about wording and criterion, not about which family is correct, and I am deliberately leaving that open for the owner.
