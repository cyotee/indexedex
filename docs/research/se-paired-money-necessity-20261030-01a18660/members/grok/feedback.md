# Member feedback

## Identity

- Run ID: se-paired-money-necessity-20261030-01a18660
- Member label: grok
- Phase: advisory review
- Owned path: docs/research/se-paired-money-necessity-20261030-01a18660/members/grok/feedback.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/research/se-paired-money-necessity-20261030-01a18660/members/grok/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: se-paired-money-necessity-20261030-01a18660-r1
- Path: docs/research/se-paired-money-necessity-20261030-01a18660/coordinator/draft.md
- Fingerprint supplied by the coordinator: 45ade63e616ad59fb2a61ec0efb22ede5eba1f0ea850334d672349993af90e5e
- Fingerprint independently computed: 45ade63e616ad59fb2a61ec0efb22ede5eba1f0ea850334d672349993af90e5e
- Draft bytes opened: yes

The draft's own identity lines match the assigned ID and path. The supplied fingerprint was checked with `shasum -a 256` on that path. The computed digest matched. It is not a copy of the supplied value presented as a computation. The complete draft was opened. No other draft was reviewed.

## Disposition

- Disposition: support with corrections
- This file replaces a missing initial response: no

The six dispositions are supported: map `depositPair` and `previewDepositPair` onto the bundle-in functions with `tokenOut` as the share; map `redeemPair` and `previewRedeemPair` onto the bundle-out functions with `tokenIn` as the share; keep `donate`; keep `compound`. The corrections below do not change that table of decisions. They stop the proposed wording from overstating equivalence or from pointing `tokensOut` at raw pool currencies.

Support of those six rows is not approval of the unqualified opening sentence, of "made whole either way," or of the unresolved-column wording. This is not a veto and not consensus. Unread members are not treated as support.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G1 | Proposed text, `redeemPair` row | "`tokensOut` are the two currencies" can be read as the actual pool currencies. On a native pool that includes raw ETH at `address(0)`. The accepted bundle functions reject `address(0)` and pay the wrapped face. The same draft says raw ETH is not covered. The decision row should not reintroduce it. | Replace "two currencies" with the two wrapped underlying faces in `vaultTokens()` order. State that `address(0)` is not a `tokensOut` entry. Keep `tokenIn` as the share. |
| G2 | Proposed text, opening sentence | "The redefinition fills the paired deposit and paired redeem need" is unqualified. The raw-ETH paragraph later denies that coverage. A reader of the opening alone can treat the maps as complete. | Say the redefinition fills those two needs on wrapped faces. Leave the following sentence that it does not fill `donate` or `compound`. |
| G3 | Proposed text, maxima paragraph | "The caller is made whole either way" is too broad for the conclusion it supports. After success, net tokens taken can match. Before and during the call they do not. Bundle-in requires balance and allowance for the full declaration and pulls that declaration before refunding. `depositPair` pulls only the accepted ERC-20 and leaves the unused maximum with the caller. Native `depositPair` also requires `msg.value == amount0Max`. | Keep the conclusion that this difference is not enough to keep `depositPair`, and that keeping both entries would let them disagree. Delete "made whole either way." State the narrower claim: net tokens can match if the route refunds the unkept declaration; the caller must still hold and approve the full declaration, which is the accepted rule. |
| G4 | Proposed text, raw ETH paragraph | The paragraph says raw ETH is not a reason to keep `redeemPair`, then discusses paying raw ETH. `depositPair` is payable and takes the native side as `msg.value`. That input gap is the same class of uncovered behavior. The deposit row does not state it. | State that the accepted functions also do not accept raw ETH input on the mapped deposit. Say that is not a reason to keep `depositPair`. Do not invent an extension. Do not add a product function in this draft. |
| G5 | Preserved disagreements, raw-ETH row | The Grok cell is narrowed to payout: "extend the standard later, do not invent it here, do not keep `redeemPair`." The initial response applied that same recommendation to raw ETH input on `depositPair`. The "Not resolved" cell also mixes resolved recommendations ("No extension and no retained `redeemPair`") with the open product question. A reader can think the `redeemPair` map itself is unresolved. | Record that Grok's position covers redeem payout and deposit input: extend later, do not invent it here, do not keep either paired mutator for that gap. In the unresolved cell, leave only the open product question of whether this family must still accept or pay raw ETH. Do not list "no retained `redeemPair`" as unresolved. The proposed table already resolves that. |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

No peer proposal was adopted in this feedback. The draft's summaries of Astra and MiniMax were not checked against their originals. This feedback neither adopts nor rebuts those summaries. It does not adopt a narrow retained product function for raw ETH. It does not demand that the final adopt "extend the standard" as settled council text. Preserving that as an open product decision is acceptable once G1, G4, and G5 are corrected. Absence of the other members' full uncovered-behavior lists from this draft is not, by itself, a requested change.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file does not replace the initial response or the draft. It does not authorize implementation, tests, installs, Git, or edits outside this path. It does not lock the PRD.
- This advisory does not demand a further round.
- Inherited parent permissions are not evidence of confinement.
- Actual Native role, model, reasoning, task ID, and session ID were not exposed. The requested model is not proof of the runtime model.
- The hash check used `shasum -a 256` on the assigned path only. No other file was hashed. No project code was read for this pass.
