# Member feedback

## Identity

- Run ID: se-weir-b02-accounting-20261101
- Member label: grok
- Phase: advisory review
- Owned path: members/grok/feedback.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: members/grok/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: draft-se-weir-b02-accounting-20261101-r1
- Path: docs/research/se-weir-b02-accounting-20261101/coordinator/draft.md
- Fingerprint supplied by the coordinator: 7249b8b39ba5aa4a9a06d2e1afdc3be2d25370a4f4be91f90841b956ce9b2d8a
- Fingerprint independently computed: `shasum -a 256` on that path printed the same digest. The match is the result of that command. It is not a restatement of the supplied value made without running it.
- Draft's own fingerprint line: not computed. This pass did not edit the draft to add a hash.
- Draft bytes opened: 11937
- Draft identity lines match the assigned draft ID and path.

## Disposition

- Disposition: support-with-reservations
- This file replaces a missing initial response: no

The three verdicts are right. Weir does not resolve live-price placement of vault-owned idle or harvested fees. A caller-funded deposit does not put that placement shortfall on the pre-existing holders. The same-call trailing mint is absent, and a later compound of remaining two-sided inventory is not closed. The whole-balance dump is resolved in Weir by the withdrawn-net quantity, not by the absolute price limit. Selecting Weir is not a new rule. No PRD edit is proposed, and B-02 stays open. I do not ask for those conclusions to be reversed.

I accept the locator correction in Preserved disagreements. `WeirVaults.sol:314` and `:318` are the `_swap` calls. `:316` and `:320` only add the swap delta back into the net. `:269` is the existing-supply share assignment. `:272` is a blank line. My initial citations of 316, 320, and 272 were wrong. The operations match. The draft is right to keep the originals and use the coordinator-checked lines.

The reservations below are wording. They do not change which holder bears which loss.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G-1 | Proposed text, opening paragraph | "The full-spread PRD already copies the live-price placement and the absolute swap limit" pairs two copies of different strength. FS-MONEY-01 does state the absolute limit. The current PRD file has no sentence containing `slot0`, `getSlot0`, `live-price`, `pre-operation`, or `TWAP`. The live price is the sizing price of the cited Weir operations, plus the absence of a guard. The later section "What selecting Weir does not change" already states the copy list without that phrase. | Replace that sentence so it does not read as a lock quotation. State that FS-MONEY-01 copies the absolute limit, and that the cited compound and deposit operations size at live `slot0` without an added check. Do not write "copies the live-price placement" as if those words were the lock. |
| G-2 | What the source does; External push; Half-excess balance | "The depositor is credited those shares" and "the depositor bears the shortfall" name the wrong address. `deposit` credits `sharesOf[id][p.recipient]` at line 181. The refund goes to `msg.sender` at lines 182-183. `_deposit`'s `depositor` argument is the settlement address, not the share credit. The deposit-path shortfall follows the new shares. | Where the draft names who receives the new liquidity and who bears that shortfall, say `p.recipient`. Keep the conclusion that pre-existing holders do not bear it. |
| G-3 | What the source does | The compound paragraph states harvest, fee cut, and live sizing as the function's behavior. Line 343 returns before all of that when `v.liquidity == 0`, so idle is not placed on that path. | Add that qualifier at the cited `_compound` description. Do not treat it as a resolution of the positive-liquidity maintenance loss, and do not use it to close B-03. |
| G-4 | Preserved disagreements, trailing-mint row | The cell "Astra and Grok: the same-call trailing mint is absent" can be read as if that were my whole position. My script also left the later-compound shortfall with the remaining holders. The body already says both statements stand. The table should not contradict the body. | Amend the cell so Grok is not recorded as silent on the later path. No change to the adopted conclusion. |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

I do not ask the draft to adopt my zero-fee round-trip extraction as an attacker-profit result, my fixture's trailing-loss wei figure, or a PRD sentence. Those non-adoptions are right. The accounting identity is the result. Profitability is not. The coordinator's account of Astra, Kimi, and MiniMax is coordinator-supplied. I did not open their files, and I do not treat that account as my verification of them.

## Limits

- Advisory only. This file does not replace the draft, does not lock B-02, and does not authorize implementation, a PRD edit, a TWAP, a tick bound, or a fee cap.
- The coordinator decides acceptance, rejection, or deferral. This pass does not demand a further round.
- Inherited parent permissions are not evidence of confinement.
- Initial response preserved. This file does not overwrite `members/grok/response.md`.
