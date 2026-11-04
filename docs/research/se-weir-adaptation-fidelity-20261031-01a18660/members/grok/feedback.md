# Member feedback

## Identity

- Run ID: se-weir-adaptation-fidelity-20261031-01a18660
- Member label: grok
- Phase: advisory review
- Owned path: docs/research/se-weir-adaptation-fidelity-20261031-01a18660/members/grok/feedback.md
- Requested role: grok council member
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/research/se-weir-adaptation-fidelity-20261031-01a18660/members/grok/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: se-weir-adaptation-fidelity-20261031-01a18660-r1
- Path: docs/research/se-weir-adaptation-fidelity-20261031-01a18660/coordinator/draft.md
- Fingerprint supplied by the coordinator: eafad1d94fdf7fd8cc4d291262d98698bce2767ee9a8b16410dac8b37858a0b8
- Fingerprint independently computed: eafad1d94fdf7fd8cc4d291262d98698bce2767ee9a8b16410dac8b37858a0b8, by `shasum -a 256` on the raw file, before the draft was opened. The digest matched the supplied fingerprint. The draft's own identity line says `Fingerprint: not computed`.
- Draft bytes opened: yes, the assigned path, after the hash matched. The draft's own Draft ID and path match this assignment.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The draft states the conclusion of my original accurately. The PRD is not a Weir adaptation. The sibling sentence and inherit-by-ID are why the package inputs were copied. Deleting that label without replacing the inherited economics would leave the same design. The shape that can stay without a new case is the locked tokenized shape. No cap number is chosen. This draft does not authorize implementation.

On my original, these named rows are accurate: `maxZapBps` removed with no replacement case; `previewZapCredit` removed; booked no-share remainder removed as an entrant donation, with unused input refunded; `donate` left as the FS-OWN-09 lock, contradicting Weir, and not voted away; `compound` keeps harvest-and-reinvest and removes the PairToken swap, quarter-cap, and no-fee rule. The entry-size split states my side accurately. I do not vote it, the tick split, or the donate split.

It does not state my original accurately in the Tick bound row, the `IncompleteConversion` row, or the silence around cases I made that are not in the named table. Those are the requested changes. They are corrections of attribution and scope. They are not votes to close a preserved split.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G1 | Proposed text, `IncompleteConversion` row | The Remove is right for that entry error. Weir accounts actual deltas and forbids a consumption-equality check on entry. My original also kept a different rule: the accepted one-token exit pays the selected token or reverts, because the locked return is one `amountOut` and one `amountRefunded`, not two currencies. That exit rule is already authorized by the route. It is not `IncompleteConversion`, and it is not a vote to add a consumption check to Weir's two-currency zap. | Say the Remove is the entry error only. Do not extend it to the accepted one-token exit. Leave every preserved split open. |
| G2 | Preserved disagreements, Tick bound | The withdrawal condition is accurate: I withdraw the case if borrowed `exchangeIn` is rejected. The rest of the Grok attribution is not. I did not recommend a local entry tick bound or a price bound. I recommended a tick-displacement bound on every swap this vault sends to its own pool, including a single-token exit sale, with no number, and not the PairToken field or its entry-only scope. Pairing that with "price bound" merges it with a different proposal. | Correct the Grok sentence. Leave the split open. Do not treat the correction as a vote that any guard should be authorized. |
| G3 | Proposed text, Booked no-share remainder row | The Remove is accurate. "Idle dust from fees" is narrower than my original. Weir idle is rounding and reinvestment residue, including the two-unit cushion, shared pro rata. It is not only harvested-fee dust, and it is not the booked entrant remainder. | Say idle residue, not fee dust only. No other change to that row. |
| G4 | Evidence gaps | The draft asks advisory to say if a load-bearing case was omitted. It names Astra's additional cases and not mine. I did not read Astra, so I do not confirm or deny that sentence. My original has three cases this draft neither adopts nor labels as omitted. Silence can be read as rejection. They are not council recommendations, and I am not voting them in. Native sync before this vault's native value settle, only while an outer unlock can hold the sync slot, is load-bearing for borrowed native settlement and is withdrawn if borrowed `exchangeIn` is rejected. If `donate` stays, registry disable must also reject `donate`, or a no-mint booking bypasses issuance disable. That does not remove `donate` and does not close the donate split. Borrowed `exchangeIn` is not a PairToken aspect. I recommended it only so this share can serve helpers the PRD says already call that selector while unlocked. I did not read those helpers. The tick case and the native-sync case fall if that sentence is wrong or the path is rejected. | Record those three as Grok cases not adopted, on the same terms as other omitted cases. Do not add them to the recommendation table as settled. Do not vote the donate split. |
| G5 | Proposed text, opening money-rules sentence, recommendation table, and `compound` row | The sentence that inherited economics must be replaced is accurate. The four examples are not my whole inventory. The named table is the brief's named set. It is not a finding that I left the other carry-overs in. Still Remove in my original, and still stated as requirements in the PRD: the no-dead-share prohibition, geometric-mean and S1-ACC-02 issuance, the S1-EXIT-01 collection-only fallback, and the inherited 12,000,000 / 5,000,000 and quote-budget numbers. The `compound` row is right to remove the no-fee rule. Existence of `compound` is the FS-OWN-09 lock, as with `donate`, not an inference from Weir merely having the function. The behavior under that lock is Weir's harvest, fee cut on harvested fees only, and idle reinvest. | Say the named table is not Grok's complete Remove inventory, and name those four omitted Remove items. Cite FS-OWN-09 for `compound`'s existence. Do not paste the whole inventory unless the coordinator wants that. Do not vote a split. |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

I do not adopt or reject the draft's account of Astra, Kimi, or MiniMax. Where it attributes a position to them, I did not check it.

From my own original, the draft correctly did not adopt the tick case as a council recommendation. It preserved that split. It did not adopt native sync, the disable-covers-donate interaction, or borrowed `exchangeIn`. Those should be labeled omitted, not rejected, and not promoted into the recommendation table. It did not reproduce the full Remove inventory. The umbrella sentence covers that class only if G5 is corrected. None of that is a vote on the preserved splits.

## Limits

- Advisory only. This file does not replace `members/grok/response.md`. The coordinator decides acceptance, rejection, or deferral. No further round is demanded.
- This file grants no implementation authority.
- The preserved splits stay open. This feedback does not vote them.
- I do not attest the Participation task ID `st_01a19301`. It was not exposed when the original was written.
- Hook-helper source was not read on either pass. The borrowed-path case still rests on the PRD's FS-UNLOCK-01 sentence.
- Inherited parent permissions are not evidence of confinement.
