# Member feedback

## Identity

- Run ID: apex-012-prior-vaults-20261024
- Member label: grok
- Phase: advisory review
- Owned path: docs/reviews/apex-012-prior-vaults-20261024/members/grok/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/reviews/apex-012-prior-vaults-20261024/members/grok/response.md
- Initial response preserved: yes

## Draft reviewed

- Draft ID: draft-apex-012-prior-vaults-20261024-r1
- Path: docs/reviews/apex-012-prior-vaults-20261024/coordinator/draft.md
- Fingerprint supplied by the coordinator: not supplied
- Fingerprint independently computed: not computed
- Draft bytes opened: 4157

The draft's own identity lines match this assignment. The file was opened in full.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The draft does not misstate the central reading. Wings is the only inspected design recorded as pricing a withdrawal from remaining depth. Reading slot0 is not that failure. Arrakis V2 and Charm are two-token shares of the vault's own position. Panoptic is a stored-counter shape, not an LP vault. Maker is a cached mark. The recommendation is not chosen. Ignoring slot0 is not a fix for a sale that remains on the payment path.

It drops costs stated in the initial response, and two sentences are narrower than that response. Those should be changed. This is not a request to redesign the vault, and it is not a rejection of the narrower split.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G1 | What can be taken, two-token paragraph | Dropped cost. The opened Arrakis and Charm formulas add idle `balanceOf`. The survey's rate rule says the rate must not read `balanceOf`. The draft says they pay a share of the vault's own position and does not state that cost. Charm's TWAP gates rebalance, not the withdrawal; the draft's Charm citation can be read as including that guard. Arrakis's vault withdraw entrypoint was not opened. The opened source is the underlying library. | State the idle `balanceOf` cost. Say Charm's TWAP is not part of the payment. Qualify Arrakis as the surveyed underlying library, not a withdraw entrypoint that was opened. |
| G2 | What can be taken, stored-counter paragraph | The delay sentence is right. The boundary around it is dropped. The counter is accounted storage, not `balanceOf` and not pool state. Fee earning is not given up on the survey's record; recognition waits for a real credit. Accounted target remains a one-token number. What is given up is a hypothetical sale of the other token inside the rate. "Does not show how that counter funds an immediate one-token exit of a live position" is compatible only if it is not read as giving up fee earning or every one-token number. Panoptic `exerciseCost`, the deposit commission, virtual shares, and the open-leg lock are not the shape. | Add those boundaries. Do not widen the cost past them. |
| G3 | What can be taken, Maker paragraph | "A later poke can" continues "rewrite that cached number." That is true of the hop. It can be read as the liquidity sequence working if the attacker waits for the hop. The initial response did not say that. A liquidity add left in place until the next poke was not tested. The Arrakis formula the synthesis ties to this oracle is position amounts at a supplied price, not a simulated sale. That inference is not an oracle-source reading. There is no ledger row. The draft also does not say this piece is alternative precedent rather than the recommendation. | Say a later poke refreshes the cache, and that the survey does not show that refresh is a sale into remaining depth. Keep the same-transaction point. Say this is not the recommendation and not a ledger row. |
| G4 | What must not be taken, auditor bullet | The initial response said the claim report's whole unadopted fix list must not be taken from the survey: unlock revert, TWAP-bounded reference, depth cap, loss check, exit fee, and round-trip test. "The auditor's reference-price list" drops the items that are not a reference price. | Name the list as the claim report states it, or say the survey supports none of those items. |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

The draft's sentences about Astra, MiniMax, and Kimi were not checked against their files. They are not confirmed and not disputed here. The narrower split is supported from the grok response only.

## Limits

- The central reading is not the concern. G1 through G4 are the changes.
- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority and does not redesign the vault.
- `response.md` was not overwritten. The draft and peer files were not edited.
- The participation-table task ID for grok was not exposed to this member and was not verified.
- Inherited parent permissions are not evidence of confinement.
