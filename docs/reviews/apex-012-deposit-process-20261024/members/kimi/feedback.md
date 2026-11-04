# Member feedback

## Identity

- Run ID: apex-012-deposit-process-20261024
- Member label: kimi
- Profile: review
- Phase: advisory feedback
- Owned path: docs/reviews/apex-012-deposit-process-20261024/members/kimi/feedback.md
- Peers read before submission: no

## Draft reviewed

- Draft ID: draft-apex-012-deposit-process-20261024-r1
- Path: `docs/reviews/apex-012-deposit-process-20261024/coordinator/draft.md`

## Disposition

support-with-reservations

The draft does not misstate my conclusion. Its kimi bullet is accurate: the only preserved-ruling violation I found is `_place()` opening a new range for an empty slot while supply is positive; the fix is to place only into slots with existing liquidity and leave the rest idle; the mint is `supply == 0 ? assets : supply * assets / settledTarget` with the gross deposit credited to the counter; no entry swap; and I hold that the no-gift sentence is not in either preserved-ruling list, so the dilution concern belongs to open question 2. The "Agreed" section also matches my answer to question 1: the sale premise came from the PRD Entry sentence, and the existing deposit never swaps.

## Concerns

1. The three owner options are framed entirely on the gift/swap axis, but my finding is orthogonal to that axis. Option 1 as written — "keep the existing target-only deposit, minus the quote" — still violates the preserved ruling "a later deposit does not open a new range" whenever a slot is empty, because the violation lives in `_place()`, not in the mint and not in the absence of a swap. Whichever option the owner picks, the placement fix (skip empty slots, add only to existing ranges, residual stays idle) must ride with it. The draft should say so explicitly; as written, an owner choosing option 1 could read it as keeping `_place()` unchanged.
2. Wording only: the header "All four agree on the first two answers" sits over a section whose two items are both halves of question 1 (why the prior review assumed a sale; whether the existing deposit sells target). Question 2 is exactly what the "Not agreed" section covers. A reader skimming headers could misread question 2 as settled.
3. I do not pick an owner option, per the instruction. I note only that options 2 and 3 each concede something no preserved ruling concedes: option 2 disables mixed-book entry without a ruling requiring it, and option 3 reinstates the sale the owner rejected. Option 1 is the only one consistent with the preserved rulings as I read them — but stating that is my reading of the rulings, not a recommendation of an option.

## Limits

- Static reading only; no Forge run.
- I reviewed only the draft and my own initial response. Peer response files were not read, per the instruction; my knowledge of their positions comes solely from the draft's summaries.
- This feedback is advisory. It does not edit the draft, the PRD, or any response file.
