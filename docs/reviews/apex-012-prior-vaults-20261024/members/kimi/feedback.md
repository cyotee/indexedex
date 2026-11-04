# Council member feedback — kimi

## Identity

- Run ID: apex-012-prior-vaults-20261024
- Member label: kimi
- Profile: research
- Phase: advisory feedback on coordinator draft
- Owned path: `docs/reviews/apex-012-prior-vaults-20261024/members/kimi/feedback.md`
- Requested role: council-member
- Requested model and reasoning: kimi-coding/k3:high
- Other identity fields: not exposed
- Peer files read before this feedback: no (the draft's own characterization of peer positions is the only source)

## Draft reviewed

- Draft ID: draft-apex-012-prior-vaults-20261024-r1
- Path: `docs/reviews/apex-012-prior-vaults-20261024/coordinator/draft.md`

## Disposition

Support with reservations. The draft does not misstate my reading, and it does not drop any cost I stated. It carries all three designs I identified (two-token pro-rata from Arrakis V2 / Charm, Panoptic stored accounting, Maker cached mark) with the same costs I recorded: the one-token exit and Arrakis deprecation, discrete fee recognition and the accounted-balance payout bound, and staleness plus the two-oracle dependency. Its "What must not be taken" section matches my Target 4, including the point that a spot-free getRate alone does not fix a deposit or redeem priced off live depth. Its treatment of the pro-rata design as an inference from recorded formulas, not a synthesis finding, matches the caveat I attached to it.

## Concerns

Two reservations, neither blocking:

1. The one-line characterization "MiniMax and Kimi group the slot0 readers with designs that do not stop the claim" is literally accurate but drops the reason I gave. My response explicitly made the same mechanism distinction the draft now draws: only Wings simulates a sale into remaining depth, so only Wings is moved by a pure permitted depth addition. I grouped the slot0 readers under "do not stop the claim" because the claim report is broader than the depth channel — it also states the spot-move sequence — and a live slot0 mark remains open to that sequence. The draft's narrower reading (only the simulated sale is the liquidity claim) is a defensible bounding of the question, and I do not dispute it, but as written the draft could be read as my position being wrong about depth mechanics rather than being about the claim's full breadth. One clarifying clause in the final report would resolve this.
2. The draft's survey-support section does not mention Steer (S15) or Revert V3Oracle (S17), both of which my response listed among live-read designs: Steer pushes the price choice to the caller, so any caller-supplied live price re-imports the live read, and Revert with `twapSeconds == 0` reads slot0 directly. Neither changes any conclusion — neither is a candidate to take — so this is completeness, not substance.

No cost I stated is missing. The draft's phrasing that the survey "does not show how that counter funds an immediate one-token exit of a live position" covers my recorded point that the payout is confined to accounted target tokens until a conversion credits the counter.

## Limits

Advisory only. I read the draft and my own prior response; no peer response files, no URLs, no Forge, no code execution. This feedback does not redesign the vault, does not choose among the three designs, and does not authorize anything. Silence from other members is not represented here.
