# Member feedback

## Identity

- Run ID: v4-own-vault-spec-20261027-01a177b3
- Member label: grok
- Phase: advisory review
- Owned path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/grok/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: task ID st_01a17cf7; actual model, reasoning, and session ID not exposed
- Fresh or continued: continued
- Initial response path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/grok/response.md
- Initial response preserved: yes

This file does not replace the initial response. `response.md` was not overwritten.

## Draft under review

- Draft ID: draft-v4-own-vault-spec-20261027-01a177b3-r1
- Path: docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/draft.md
- Fingerprint supplied by the coordinator: 2e2c595866b5475ba8802496f7606df9dbc5fc7cfef2b46a65175581f6750ea8
- Fingerprint independently computed: not computed
- Draft bytes opened: yes, at the assigned path

The draft's own identity lines match this Draft ID and path. Those lines also record a pre-insertion sha256, `c015e6977c4cc64b54c5377fd99d6f16ab384ed4e02a52faa35ef235fe71404b`, and say the review identity is the frozen-file hash. I did not compute either hash and did not open `RUN.md`. The supplied fingerprint is recorded as given. It is not independent proof that the bytes I opened are the frozen file.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

Advisory only. Not a veto, not consensus, and not approval for any unread member.

The draft fairly records the core of my position. It adopts one liquidity-unit receipt for one position, the re-read mint `floor(uReceived * (S + 10^d) / (U_before + 1))` with received units in the numerator, rejection of the OutTarget comment and of the V2 fee-share mint, no vault swap on entry, a slice-only exit sale with atomic revert, the diamond as the unlock callback address, and fee value in token units outside `U` and `S`. The preserved-disagreements table states my receipt, fee-unit, and entry positions correctly. I did not check its statements about Astra, MiniMax, or Kimi.

It does not fairly record my refusal to claim a profitless round trip. Decision 8 item 12 asserts that claim. It also leaves `getRate`'s one-share fee claim too vague to implement as the actual withdrawal preview I specified, and it adds an in-kind exit I placed out of scope without a disagreement row.

A later agent can implement Decisions 1 through 6, and the slice sale, from this draft plus the IndexedEx paths it cites, without excluded third-party source. Decision 7 cannot be implemented unambiguously from the sentence "take one whole share's fee claim." Invariant 12 cannot be implemented from the specified exit without adding a guarantee the draft's own "What this does not deliver" section refuses.

`getRate` was not redefined as NAV. The draft says it is not a NAV mark, not `liquidateAll(book) / S`, and not an issuance input. That matches the constraint. The gaps below are an incomplete preview, not a NAV substitution.

No requirement I read reconstructs excluded source. The draft tells the implementer not to open that source. The gaps are places an implementer could be tempted to go looking. Closing them in the final removes that temptation. This file grants no implementation authority.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G-1 | Decision 8, item 12 | "A one-share round trip is not profitable. Mint floors. Redeem floors." contradicts my invariant 15 and the draft's own sentence that the exit sale is not a fix for quote manipulation. Floor on mint and redeem favors the vault on the liquidity conversion. It does not determine target profit after the slice sale. A later agent who treats item 12 as a requirement may add protection logic this specification does not contain. | Delete item 12. Replace it with the narrower statement: mint and redeem both floor; that is not a profitless target round-trip theorem; no invariant claims post-sale immunity, unchanged incumbent token principal, or that a deposit swap plus this exit closes the prior result. |
| G-2 | Decision 7, `getRate` | "Take one whole share's fee claim from that preview" does not say which claim. A named holder's checkpoint, `floor(oneShare * feePerShare / Q)` from the index origin, and pro-rata of the aggregate pot are different numbers. The revert set omits `S < oneShare`, `uOut > U`, and a quoted sale output of zero while opposing input is nonzero. A zero quote is not the same as an unquoted sale. Returning a rate in those cases is not an actual one-whole-share withdrawal. "Against the redeemer" does not state Floor. The draft also drops my statement that a multi-share exit must not be corrected to `shares * getRate / 10^18`. | Restore `fee_i(oneShare) = floor(oneShare * F_i / S)`, with `F_i` the aggregate holder entitlement after the virtual sync, excluding dust. State that this is not one holder's `unclaimed` and not the gross index from the origin. Revert when `S < oneShare`, when `uOut > U`, and when opposing input is nonzero and the quoted sale output is zero. Name Floor. State that Decision 5 pays the actual slice, not `shares * getRate / 10^18`. |
| G-3 | Decision 5, in-kind sentence | "A separate in-kind route may pay both currencies and skip the sale" adds a second exit I specified as out of scope. It is not in the disagreements table. "May" does not define the share burn, the fee payment, or the `U` update. An unspecified optional route is a gap, not a requirement. | Delete that sentence, or replace it with: an in-kind two-currency withdrawal is not part of this specification and must not be used to complete a failed target exit. Do not leave a "may" route unspecified. |
| G-4 | Normative deposit sequence step 8; normative exit sequence step 8 | "Set `U` to the position's liquidity. If they differ, revert" cannot be followed literally: after the assignment, they do not differ. Read as an unconditional assignment, it absorbs any unsolicited liquidity change into `U` and conflicts with invariant 5, which allows `U` to change only by `uReceived` or `uOut`. | Deposit sets `U` to `U_before + uReceived` and reverts if position liquidity is not that value. Exit sets `U` to `U_before - uOut` and reverts on the same mismatch. Do not assign `U` from whatever liquidity the position happens to hold. |
| G-5 | Terms table, `Q`; normative deposit sequence | My response fixed `Q = 2^128` and required a revert when minted shares are zero or below the caller's minimum. The draft says `Q` is fixed at initialization and does not name the integer. The deposit sequence can mint a zero share result. Neither omission is in the disagreements table. An implementer can pick a `Q` without excluded source, but a missing integer is how a later reader goes looking for one. | Name the stored `Q`. I specified `2^128`. If that integer is not adopted, record the omission and still name the integer the final uses. Require the deposit to revert when the formula mints zero shares, and record a caller `minShares` bound or record that the bound was not adopted. |

G-1 and G-2 are the reasons for `requested-changes`. G-3, G-4, and G-5 should be resolved in the same final pass. None of them is a vote against the receipt, the mint equation, or the slice sale.

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

The draft's attributions of other members are the coordinator's statements. I do not adopt them as my observations, and I do not treat silence or an unread response as support.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
- I compared the draft with my preserved `response.md`. I did not re-open PoolManager, excluded third-party source, or peer files for this pass.
- Byte identity with the frozen file was not checked. No hash command was run.
