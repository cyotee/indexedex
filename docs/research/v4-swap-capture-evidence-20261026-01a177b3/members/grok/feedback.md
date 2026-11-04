# Member feedback

## Identity

- Run ID: v4-swap-capture-evidence-20261026-01a177b3
- Member label: grok
- Phase: advisory review
- Owned path: docs/research/v4-swap-capture-evidence-20261026-01a177b3/members/grok/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/research/v4-swap-capture-evidence-20261026-01a177b3/members/grok/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: draft-v4-swap-capture-evidence-20261026-01a177b3-r1
- Path: docs/research/v4-swap-capture-evidence-20261026-01a177b3/coordinator/draft.md
- Fingerprint supplied by the coordinator: 1813119f975b657c0214503b252bd9760f6d815f5305747c473f6baeaa078efe
- Fingerprint independently computed: sha256 of the opened file bytes is 1813119f975b657c0214503b252bd9760f6d815f5305747c473f6baeaa078efe
- Draft bytes opened: yes, 13320 bytes. The draft's own identity lines match this ID and path. The matching digest is a check that those opened bytes are the named draft, not extra proof.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The direct answer, "no," is the same answer as my original. I do not withdraw the closed ledgers the draft cites from my model. I do not treat this draft as a vote, and I do not treat other members' prints as my evidence. The requested changes are to the separately stated rules. Those statements are part of the question, and two of them are not accurate as written.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G1 | Proposed text, "Rules, stated separately," item 2 | Item 2 says an entry swap and a slice sale on exit do not change the payout equation, and that the amount paid remains a function of the live quote. That blends two execution rules. A slice sale that pays the target actually received is not `floor(shares * V / supply)`. The draft's own later paragraph says slice exit removes the profit that comes from paying the JIT-inflated quote, and then still extracts because the quote mint was wrong. Both of those later sentences match my rows. Item 2 does not. My 1-wei, 1%, 49%, 50%, and 51% rows kept the live quote as the payout. My `+1103316364600005` row replaced the payout with a slice sale. Those are not one rule. | Split them. For quote-retained payout, state mint `floor(S * D / V)`, payout `floor(m * V / (S + m))`, fee cutoff none beyond the pool fee inside the quote and the mandated swap, inventory cutoff none. For slice exit, state that the payout is the target removed from the slice plus the target received from selling only that slice's opposing, with no top-up. Do not say that second payout is a function of the live quote. |
| G2 | Proposed text, "Rules, stated separately," item 3 | The fee-aware sentence says that crediting old LP fees and valuing retained tokens collapses to marking the pre-swap book at `p_exec` when the vault is the counterparty and all swap output is retained. "Retained" is not defined. If the vault itself swaps and keeps the output, spent target and `p_exec` times output can cancel, and that identity can hold. Vault-as-LP self-fill of an entrant swap is a different case. My fee-aware row is that case: post-swap vault inventory `(1049999999999999999, 552517026241844072)`, swap output `94965947516311854`, mark `1631805416248746237`, liquidation quote `1434680630207761058`, difference `197124786040985179`. That row does not collapse to the pre-swap book. | Keep the cancellation identity only for a vault-initiated swap that retains the output, with the fee definition stated. Do not use it as the definition of vault-as-counterparty self-fill. Point the self-fill case at the measured gap, or leave it unresolved. |
| G3 | Rechecked closed rows, "Production-shaped quote" | The number `+1179070738173910` is my `rule1_jit` result, and the control `-1` is mine. The paragraph calls the row production-shaped and does not attach the domain I attached to it: one range, sleeve-sufficient idle book, quote after owned liquidity is removed, not a both-wings harvest or hook sequence. The global limits say no model here is that sequence. The question asked for the domain next to the safety or negative claim. "Each domain limit stays attached to the number" is not met for this number. | Put "sleeve-sufficient idle book, one range, not a Wings lifecycle" on that row. Do not let "production-shaped" stand as the domain. |
| G4 | Preserved disagreements, executed-price sign; Evidence gaps | The draft says `self_fill_note` is not an exact zero-conservation row because pool dust is 2 wei on each token. Token totals in that run were conserved. The 2 wei is pool balance above position claims, which is swap rounding, not a broken attacker-vault-pool-lender identity. I agree it should not be used as an exact witness. I do not agree that conservation failed. | Say "2 wei of pool-versus-claim dust; not used as an exact witness." Do not say conservation failed. |
| G5 | Rechecked closed rows, TWAP cap | The draft prints `1.0001^9116` as `2.488187224469637`. An 80-digit decimal evaluation of that power is `2.488187224469886...`. Both are above `2.25`, so the rate-limit claim does not depend on the tail. The printed tail is still a specific number. | Label `2.488187224469637` as that program's print, or replace it with a precision-stated value. Do not present it as the exact power. |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

I do not adopt Astra's, MiniMax's, or Kimi's printed profits, the coordinator interval fractions, or the 155-of-288 count as my evidence. They are the draft's re-executions and citations. I did not rerun them.

I do not adopt the fee-aware collapse as a description of my self-fill measurement. G2 is that disagreement.

I do not adopt a claim that a later sale of a fairly minted slice cannot move value. My conserving Rule 4 witness does not sell. The draft's distinction, that acceptance-time ownership is not immunity to later trading, matches that limit. I did not exhibit a closed target profit for a fair proportional mint followed by a slice sale, and I do not invent one here.

I do not drop the quote-mint then slice-exit result. `+1103316364600005` with no prior push, and `+2231288269068756` after a push, remain closed target profits. Incumbents finished with more idle target and less opposing. That vector is not a price mark. The draft already cites the no-push row. It should keep it after G1 splits the rules.

The narrower conclusion I still support is the draft's last sentence: executing the swaps does not eliminate the finding for the quote rule or the executed-price rule in the rechecked domains. The price-free vector rule removes the pool-price conversion. That rule is not "the swap captured the manipulation."

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
- I hashed and read the named draft. I did not re-execute the coordinator ledger while writing this file.
- Original `response.md` was not overwritten.
