# Member feedback

## Identity

- Run ID: se-fullspread-prd-rewrite-20261103
- Member label: grok
- Profile: research
- Phase: advisory review
- Owned path: members/grok/feedback.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: members/grok/response.md
- Initial response preserved: yes
- Peers read before this feedback: no

This self-description is not proof of the runtime model.

## Draft under review

- Draft ID: revision `fullspread-se-prd-rewrite-20261103`, as named in the draft's opening identity sentence
- Path: `docs/research/se-fullspread-prd-rewrite-20261103/coordinator/draft.md`
- Fingerprint supplied by the coordinator: not supplied
- Fingerprint independently computed: not computed
- Draft bytes opened: yes. The assigned file was read in this pass, 639 lines.

The assignment did not allow a hash. A repeated value is not independent proof, and none was computed.

## Disposition

- Disposition: support-with-reservations
- This file replaces a missing initial response: no

The draft copies the locks I read in the initial pass. It does not add a fee, an event field, a selector, or a swap-size formula. It does not leave the sleeve, the extra fee mint, principal-only payment, the view revert, or the about-half swap in force. Two shorter quantity sentences can still be read beside the 2026-11-03 exit lock. That is the reservation. This feedback does not authorize implementation and does not replace the draft.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| C1 | Section 1.4, FS-OWN-15 | "May swap only that holder's withdrawn net" can be read as an optional swap. The same paragraph calls it a quantity rule, and FS-OWN-30 requires conversion of the whole unwanted side or `AmountOutNotMet` with no burn. The optional reading is a contradicted sentence beside that lock. It is not a new economic. | Replace "may swap only" with "swaps only", and point that swap at the FS-OWN-30 rule: convert all of that unwanted side or revert `AmountOutNotMet` and do not burn. Do not leave the optional reading. |
| C2 | Section 1.4, FS-OWN-13 and FS-OWN-31; section 5, FS-UNLOCK-02 step 5 | These steps say a borrowed one-token exit "swaps only the withdrawn net" and do not say what the net includes. FS-OWN-30 includes the caller's opposing-token fee and opposing booked claim. A reader can treat the net as principal only. That earlier payment sentence was overridden. | In each of those three places, define the withdrawn net as the FS-OWN-30 exiting claim, not principal alone. Do not add a second payment rule. |

No other contradicted operative sentence was found. The sleeve, extra mint, `Compounded(address,uint256)`, `previewExchangeOut` revert, inherited-domain reject, and about-half swap are negated rather than left in force. F14's principal-only sentence is named in section 2 as not accepted. That naming is a refusal, not a second rule.

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

The draft header says Astra, MiniMax, and Kimi were compared and that the base text is the Grok conclusions. The body matches the preserved Grok conclusions except that header sentence. I did not read those other originals, so I cannot name a finding the merge dropped, and I do not treat the match as evidence that they had nothing to add.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority and does not replace the draft.
- The assignment forbade a hash. The opened path and the draft's own revision label are the identity used here.
- Two inferences are stated as rules and are not treated here as added economics: `total shares` is written as `totalSupply()` before the burn, and an overstated-maximum pretransfer is written as spending nothing and minting nothing. Both follow the locks I read. They are not separate fee or swap formulas.
- The removed `PkgInit.wrappedNative` address is still unnamed. The draft does not invent a replacement. That gap is not a new binding.
- `Donation()` with no fields, and the both-token exit that pays both tokens and does not swap, are the stated readings from the initial assignment. The draft copies them. It does not add fields.
- Inherited parent permissions are not evidence of confinement.
