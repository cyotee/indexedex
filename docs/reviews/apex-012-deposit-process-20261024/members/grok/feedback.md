# Member feedback

## Identity

- Run ID: apex-012-deposit-process-20261024
- Member label: grok
- Profile: review
- Phase: advisory feedback
- Owned path: docs/reviews/apex-012-deposit-process-20261024/members/grok/feedback.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Peers read before submission: no

## Draft reviewed

- Draft ID: draft-apex-012-deposit-process-20261024-r1
- Path: docs/reviews/apex-012-deposit-process-20261024/coordinator/draft.md

## Disposition

support-with-reservations

The draft does not misstate my conclusion. The Grok bullet is the conclusion I wrote: the gift is arithmetic, no denominator inside the unchanged sequence removes the claim, the process that still completes a deposit is an entry swap when other-token inventory is positive, a swap that does not increase vault-owned other token reverts, and the zero-other case keeps the existing sequence without a swap.

I do not pick an owner option.

## Concerns

The agreed section does not misstate my answers on the first two questions. The prior sale reading is the PRD Entry section, not `_deposit`. The existing deposit does not sell target. `_swapDeficit` is the other direction and is reached only from redeem.

One council-level sentence is not my conclusion. "The gift sentence and the proportional-addition sentence are in the PRD" is true. "Those sentences were written to require" the entry swap is not what I found. I named only the gift outcome: the depositor does not receive a gift of other token already held. Proportional addition to every slot is not the ruling I used, and it is not in the process I described. Astra's bullet is the proportional-addition fix. The final should not attribute that fix to me, and it should not treat the two sentences as one ruling.

Owner option 3 is a fair label for the repair I described. It is not the whole repair. A final that expands option 3 into a process must keep the constraints I actually stated: size the swap so retained target and the increase in vault other-token inventory match the pre-add inventory ratio; mint `supply * Y / O`, not the bought amount itself; credit retained target, not the gross deposit; revert when that inventory does not increase. Sizing by `Quote.quote`, by a simulated sale of the book, or by `slot0` was not authorized. Line 47 can still fail that swap. None of that is a fourth process, and none of it is a vote for option 1, 2, or 3.

## Limits

Advisory only. I compared the draft with my own response. I did not read peer responses, so I do not judge whether the Kimi, MiniMax, or Astra bullets are fair to them. I did not re-open the source files for this pass. No implementation is authorized.
