# Member feedback

## Identity

- Run ID: apex-012-design-recommendation-20261024
- Member label: kimi
- Profile: research
- Phase: advisory feedback on coordinator draft
- Owned path: docs/reviews/apex-012-design-recommendation-20261024/members/kimi/feedback.md
- Peers read before submission: no peer response files read; the coordinator draft's own summaries of other members are the only account of them used here

## Draft reviewed

- Draft ID: draft-apex-012-design-recommendation-20261024-r1
- Path: `docs/reviews/apex-012-design-recommendation-20261024/coordinator/draft.md`

## Disposition

Support with reservations.

The draft does not misstate my design. Family B as described — a share is a fraction of the live ranges, exit removes that fraction and sells only that slice's other token, the published rate is `settledTarget * 1e18 / supply`, and that number is not the exit proceeds — is what I submitted, including that the difference runs in both directions and that the entry conversion on a two-sided book is a new process justified from the goals, not a reading of today's `_deposit`. The shared refusal list is accurate.

The reservation is one dropped distinction, stated in my response and not engaged by the draft, which is the entire basis of the draft's ruling against Family B.

## Concerns

1. **The draft flattens "executed settlement" into "a different exit price" without addressing the distinction my one-rule claim rested on.** My response stated that the rejected split is a *previewed or quoted* zap price that differs from the rate — a second number computed from live pool state. An exit that executes a real slice sale and writes the actual delivered target back into the same settled counter uses one number: the counter. The burn debits what the settlement credited; the rate then reads that counter. The draft's sentence "That is a rate and a different exit price. The brief rejected that split" equates execution actuals with a zap-out quote by conclusion, not by argument. If the owner reads "no zap-out" as banning any redemption whose paid amount is not knowable from the rate in advance, Family B fails; if the owner reads it as banning a *second quoted price*, Family B stands. The draft should name which reading it applied, because the two readings select different families.

2. **The draft's Family A summary inherits a cost my response flagged for any design that deals only in settled target: it declines goal 1 in the states where goal 1 pays.** The draft states this cost fairly ("you do not earn fees and take new money in the same state"), so this is not a dropped fact; I note it only to confirm the trade-off is the coordinator's accurate framing and not a misreading of my position. My design's contrary choice — entry and exit run while the reserve is earning — was deliberate and is represented correctly.

3. **No constraint I stated is otherwise dropped.** The entry-conversion justification, the refusal list, the V3/V4 single-mechanism point, the zero-counter deposit halt, and the both-directions rate lag all appear in the draft or in its family characterization at the fidelity a synthesis requires.

I do not pick a family for the owner. The reservation in concern 1 is about the draft's stated reason for setting Family B aside, not a demand that the owner choose it.

## Limits

Static reading of the draft and my own prior response only. No peer files, no Forge run, no implementation. This feedback is advisory; the coordinator's revision decides what the final report says.
