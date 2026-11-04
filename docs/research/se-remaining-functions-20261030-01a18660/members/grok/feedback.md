# Grok member feedback

## Identity

- Run ID: se-remaining-functions-20261030-01a18660
- Member label: grok
- Phase: advisory review
- Owned path: docs/research/se-remaining-functions-20261030-01a18660/members/grok/feedback.md
- Requested role: Grok member of the research council
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/research/se-remaining-functions-20261030-01a18660/members/grok/response.md
- Initial response preserved: yes

This file continues the conversation that wrote the initial response. Native did not expose role, model, reasoning, task ID, or session ID. That self-description is not proof of the runtime model. This file does not replace the initial response.

## Draft under review

- Draft ID: se-remaining-functions-20261030-01a18660-r1
- Path: docs/research/se-remaining-functions-20261030-01a18660/coordinator/draft.md
- Fingerprint supplied by the coordinator: 694cdf6054d69b261f498825808e9a8c2f6dd1108b2a9ec0d732a3aa17520e15
- Fingerprint independently computed: 694cdf6054d69b261f498825808e9a8c2f6dd1108b2a9ec0d732a3aa17520e15
- Draft bytes opened: yes, 4749 bytes, after the raw hash matched

The draft's own identity lines match this ID, path, and run. Its own fingerprint line says `not computed`. That is not a hash mismatch. The independent fingerprint is `shasum -a 256` of the raw file, not a repeat of the supplied value typed in as proof. The hash matched, so this is not `unable-to-review`.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The draft states the Grok original accurately on the refund-versus-split distinction, the `previewZapCredit` map, the cap-getter drop, and the `wrappedNative` not-kept outcome. It leaves the two preserved splits unresolved. This feedback does not vote those splits.

It does not state the Grok original accurately where Proposed text says dropping `previewWithdrawalMode` leaves the internal maintenance choice in place, or where Coverage calls that map-versus-drop difference wording. The cap row over-compresses Grok's bound recommendation. Those are statement corrections, not a vote.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G1 | Proposed text | The paragraph that starts "All four originals agree that `previewWithdrawalMode` is not kept as a selector" includes "Dropping the selector does not remove the internal maintenance choice." Grok did not write that. Grok wrote that dropping the query does not drop `compound()` and does not specify an internal fallback, and that naming the branch would publish a fallback this family has not locked. The same paragraph's paired-exit quote, and the statement that neither accepted preview returns the mode or reason, do match Grok. The single-token exit quote as `previewExchangeIn` is a fair reading of Grok's route-identity assumption. It is not a sentence Grok wrote in that section. | Take the survival sentence out of text attributed to Grok, including out of an all-four paragraph. If another original said the choice remains, attribute that sentence only to that original. Do not resolve the difference by vote. |
| G2 | Coverage adopted from responses, `previewWithdrawalMode` row | "Map versus drop is wording" misstates Grok. The original says "Recommendation: drop. Do not map it" and "This is not a map onto `previewExchangeBundleOut`, because that function does not answer the question this selector asks." | Record Grok as drop, not as a wording variant of map. If other originals mapped it, leave that label split unresolved. Do not vote it. |
| G3 | Preserved disagreements, `maxZapBps` and `maxZapTickMove` getters | "MiniMax and Grok: drop both getters. Keep both caps as configuration and enforcement" is right that Grok drops both getters and does not remove the caps. It overstates Grok if that phrase adopts the stage-one formulas or the compound quarter-cap. Grok recommended that a size bound and an entry-tick bound remain internal enforcement, did not adopt those formulas, and left `compound()`'s use of the cap as a separate choice. "No original says the caps themselves are removed" is accurate for Grok. The row correctly leaves the getter split unresolved. | Qualify the Grok cell so the bounds remain without adopting those formulas. Leave the getter split unresolved. Do not vote it. |
| G4 | Preserved disagreements, "Where the native face is named"; Coverage adopted from responses, `wrappedNative` row | The disagreement row correctly says Grok drops the getter and refuses the Position Repo, and that the other three do not answer that refusal. "The wording is map versus drop" is not how Grok described the difference. Grok wrote that this is not a map onto `vaultTokens()`, because `vaultTokens()` does not return one identified wrapper address and does not name the native index. "Position Repo placement is open" is not Grok's recommendation. Grok recommended do not move it. | State Grok's drop, the not-a-map reason, and the Position Repo refusal as a recommendation the others have not answered. Do not call the label difference mere wording. Do not vote map versus drop. |

What the draft states accurately, and which this feedback does not ask to reopen:

- Proposed text: `amountRefunded` does not replace the per-currency credit split, and it is not `credit0`, `credit1`, `uncredited0`, or `uncredited1`. That matches Grok. This feedback does not attest the other three originals.
- Proposed text: `wrappedNative()` is not kept as a family getter, and the accepted routes use the face `vaultTokens()` already exposes, with `address(0)` rejected. That matches Grok's outcome. It does not put the getter on the Position Repo.
- Preserved disagreements, `previewZapCredit`: Grok maps it onto `previewExchangeIn` and does not keep the selector, because the missing split is stage-one residual accounting this family has not locked, and a second quote can disagree. The unresolved cell, whether the diagnostic split is required before a residual policy exists, preserves Grok's reversal condition. Leave it unresolved.
- Evidence gaps: Grok ran no functions. Sleeve rules and raw ETH are not restored by these five functions. Grok did not cite the label FS-OWN-09; the paired-money report Grok read uses that label for the owner lock. This feedback does not check the MiniMax implementation claim.
- Limits: the coordinator did not vote the two open splits. That should stay true.

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

Claims in the draft about Astra, Kimi, and MiniMax were not checked. This feedback neither adopts nor disputes those claims. It does not treat unread members as support, and it does not vote their positions against Grok's.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority. It does not edit the original, the draft, the PRD, or the review file.
- Inherited parent permissions are not evidence of confinement.
- The raw-file hash was compared before the draft was opened. The draft's own fingerprint line was not used as the independent computation.
- Participation names Grok as `st_01a192bf`. The original records task ID as not exposed. This assignment still does not expose it. That line was not checked, and it is not a recommendation correction.
- This feedback does not resolve the preserved `previewZapCredit` split or the preserved cap-getter split.
