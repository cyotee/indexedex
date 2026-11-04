# Member feedback

## Identity

- Run ID: v4-single-token-fee-vault-20261026-01a177b3
- Member label: grok
- Phase: advisory review
- Owned path: docs/research/v4-single-token-fee-vault-20261026-01a177b3/members/grok/feedback.md
- Requested role: council-member
- Actual role: council-member
- Actual model and reasoning: PI_MODEL=grok-4.7, PI_REASONING_LEVEL=xhigh. The provider prefix in the requested route was not exposed.
- Task ID: not exposed
- Session ID: PI_SESSION_ID=01a178e8-a0af-7704-a1d6-8aea78e63dfa
- Fresh or continued: continued. Same conversation as the initial response. Continuity was not lost.
- Initial response path: docs/research/v4-single-token-fee-vault-20261026-01a177b3/members/grok/response.md
- Initial response preserved: yes. This pass did not overwrite it.

## Draft under review

- Draft ID: draft-v4-single-token-fee-vault-20261026-01a177b3-r1
- Path: docs/research/v4-single-token-fee-vault-20261026-01a177b3/coordinator/draft.md
- Fingerprint supplied by the coordinator: d1bcd932e72dd88db3f3a4cc5c33b726d57a7838514d1529502a828fd9e92251
- Fingerprint independently computed: d1bcd932e72dd88db3f3a4cc5c33b726d57a7838514d1529502a828fd9e92251
- Draft bytes opened: yes. The full file was read after the computed digest matched the supplied digest. The draft's own identity line matches this draft ID and path. The draft says its fingerprint is not stored in the file.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The settled-target claim in the proposed text is the design in my initial response. I am not asking for a different design. I am asking the proposed text to carry the required answer elements it dropped, and to keep two sentences from being read more strongly than the evidence.

This disposition is advisory. It is not a veto, not a vote, and not implementation authority.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| C1 | Proposed text, entire recommendation | The proposed text never names quote manipulation, executed-price allocation, or vault self-fill. The question required that mapping. Silence can be read as those mechanisms having been ignored, or as the design having been proved clear of them. | Carry the mapping from my response, labeled as inference from the prior report's stated causes, not as a re-execution. Quote manipulation does not remain on mint, exit, or getRate. Executed-price allocation does not remain on deposit or exit, and returns if a later change sells the other token or issues against a book that excludes the new credit. Vault self-fill does not remain on exit. It remains as external swaps filling the separate fee-earning position, and that fill is not an input to mint, exit, or getRate. |
| C2 | Proposed text, the getRate paragraph; "What another hook can hold" | The draft correctly refuses to call the preview a sale or a NAV mark. It does not say what getRate returns, when it reverts, or whether one transaction can move it. "Must not read the pool" does not answer the movement question. A same-transaction target-fee credit, or rounding on deposit or withdrawal, can move `A / S`. A tick change cannot. | State that getRate returns `A * 1e18 / S` and reverts when supply is zero or idle target cannot pay that amount, so the preview matches an exit that reverts rather than paying a partial. State the same-transaction movement in the previous sentence. Do not let "must not read the pool" stand in for that. |
| C3 | Proposed text, fee paragraph | "A separate position ... can earn the pool's swap fees" is true and incomplete. My response said that without a non-share position that already contains both tokens, the fee credit is zero, and that opposing-capital availability is unsolved. A reader can take "can" as the design's fee path working from the deposit alone. | Say the credit is zero unless that non-share position already exists, that this design does not create it by swapping shareholder target, and that where the other token comes from is not solved. |
| C4 | "What another hook can hold" | Raw balance and a rate are both lawful. They are not the same answer to "valued as one token." An identity leg values the share as itself. A buffered leg needs the provider. The hook's own liquidity issuance and proportional exits still use the raw share balance. The rate is the swap invariant, not a second quote of this book. | Split those three sentences. Do not leave raw-balance holding as if it satisfied the rate-provider reading. |
| C5 | Preserved disagreements, "Who holds the pool principal" | The proposed text says no settled response established the stronger same-capital design. The table says the in-share design "cannot" be valued through a rate another hook can trust without a same-pool price or a live sale. That "cannot" is stronger than the proposed text and stronger than my evidence. I did not prove no such design exists. | Keep the table at the proposed text's level: not established in the settled responses, not adopted. Do not upgrade it to an impossibility. |
| C6 | What was not adopted, ICHI paragraph | "The prior report is the reason not to adapt it" can be read as the prior report having reviewed ICHI. It reviewed priced mints. ICHI's vault-build page is a priced mint. That is the link. | Say the prior report is the reason not to adapt a pool-ratio mint. Do not imply it named ICHI. |

The mint equation, the exit-or-revert rule, the refusal to sell, the two named breaks, and the refusal to redefine getRate as a sale are the parts I support. I am not withdrawing them.

My initial response accepted the brief's reading: the share should be holdable by another consumer and valued through a rate provider, and a holder should be able to leave in one token. The draft's conditional, that the design does not make the deposited target itself the pool principal, matches what I said that design does not do. It should stay a conditional. It should not replace the reading the design claims to meet.

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

I do not confirm or dispute the draft's accounts of Astra, MiniMax, or Kimi. Those files were not opened. The decision not to adopt a pool-ratio mint, and not to adopt a live one-share sale as the rate another hook would read, matches my response. It is not a finding about those members' text.

The Savers, Bancor, Bunni-repository, and Bunni post-mortem citations staying as my observations is correct. I am not asking the coordinator to re-fetch them or to promote them to coordinator fact. The draft's refusal to borrow the Savers exit swap matches my response.

Nothing in this file is council consensus. Agreement with the draft's design choice is not approval of the omitted sentences, and it is not approval on behalf of any unread member.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
- The digest check confirms these bytes were opened. It does not confirm RUN.md, and RUN.md was not read.
- Peer files were not read. A misstatement of another member would not be visible here.
- No ledger was re-executed for this review. C1 asks the final to preserve that limit, not to close it.
