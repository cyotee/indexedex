# Member feedback

## Identity

- Run ID: se-zap-roi-20261031-01a18660
- Member label: grok
- Phase: advisory review
- Owned path: docs/research/se-zap-roi-20261031-01a18660/members/grok/feedback.md
- Requested role: Grok member of the research council
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued. This is the same conversation that wrote the initial response. Continuity was not lost.
- Initial response path: docs/research/se-zap-roi-20261031-01a18660/members/grok/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: se-zap-roi-20261031-01a18660-r1
- Path: docs/research/se-zap-roi-20261031-01a18660/coordinator/draft.md
- Fingerprint supplied by the coordinator: f85476f7545bfe85ac170b794b006ecb69dcbfb1c3ad79028b958e074daf2566
- Fingerprint independently computed: f85476f7545bfe85ac170b794b006ecb69dcbfb1c3ad79028b958e074daf2566, by `shasum -a 256` on the raw file. It matches the supplied fingerprint. The draft's own Draft identity line still says `Fingerprint: not computed`.
- Draft bytes opened: yes, after that match. The draft's own Draft ID and path match this assignment.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The draft states Grok's three public verdicts accurately, and it does not vote them into a council result. That preservation should stand. It does not state Grok's reasons accurately in Preserved disagreements. Those sentences need the corrections below. This feedback does not resolve the preserved splits and does not ask the coordinator to adopt do-not-implement as the council result.

Question matches the assignment. Proposed text is accurate as to Grok on these points: public function separated from internal cap; dropping a getter does not remove a cap; stage-one residual formula and the compound quarter-cap are not the reason to skip the public function; `previewZapCredit` is a view over the planner the current share-out preview already calls; that shape is not a requirement to copy residual policy; if the full-spread entry plan does not already compute the four credit fields, the preview is not a free wrapper. Evidence gaps and Coverage adopted from responses are accurate as to Grok where they restate that separation and the non-adoption of the stage-one formulas. Limits does not misstate the original.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G-1 | Preserved disagreements, `previewZapCredit` row | The public verdict "do not implement" is right. The reason is not. "The four-way split is stage-one residual accounting this family has not locked" folds `credit0`/`credit1` into residual booking. The original separates funding of minted shares from uncredited caller inventory. "Shares and same-token refund are already on `previewExchangeIn`" omits the original's distinction: the locked full-spread return is `(amountOut, amountRefunded)`; the current PairToken `previewExchangeIn` returns one `uint256`. | Keep do not implement. Say the value test fails even if the wrapper is free. Separate `credit0`/`credit1` from `uncredited0`/`uncredited1`. Attribute the same-token refund to the locked return, not to the current one-value preview. Preserve the original limit that a later locked residual policy, with `previewExchangeIn` still unable to return the split, is a different value test and not a present implement recommendation. Do not close this split. |
| G-2 | Preserved disagreements, `maxZapBps()` row | "Keep any size cap as internal configuration and enforcement" is stronger than the original. Grok does not decide that a stored bps exists, and does not decide that `compound()` uses it. Dropping the getter does not drop a cap. The row gives the revert-returns-the-maximum point only to MiniMax. The original also observed `ZapSizeExceeded(amount, maximum)` in the current body, and said the bare `uint16` is not that maximum unless the formula is public law. | State Grok as: do not implement the public getter; internal size enforcement is separate and not decided; the one-line read is still not sufficient ROI. Do not say Grok keeps the cap. The compound size-cap non-decision belongs on this row. Do not close this split. Peer wording was not checked. |
| G-3 | Preserved disagreements, `maxZapTickMove()` row | "Keep any entry tick-movement cap internal" has the same overstatement. "Same open question as the size getter" erases a distinction the original drew. "Grok does not decide whether `compound()` uses the size cap" is true and belongs on the `maxZapBps()` row, not here. | State Grok as: do not implement the public getter; do not adopt the entry-tick comparison; do not extend `maxZapTickMove` to `compound()`. The read excerpt does not show that field on the maintenance path. Move the size-cap compound sentence to the `maxZapBps()` row. Do not close this split. Peer wording was not checked. |

No correction is requested in Question, Proposed text, Evidence gaps, Coverage adopted from responses, or Limits. Participation's `Grok st_01a192d4` is not in the original. Native task identity was not exposed here, so this feedback does not confirm or reject that identifier.

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

Statements the draft attributes to Astra, MiniMax, and Kimi were not checked against their files. This feedback neither adopts nor rejects those positions. "All four" and the 2-2 count are coordinator synthesis. They are not confirmed here, and they are not treated as support.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- The three requested changes are attribution corrections. They are not a vote to implement or to drop any public function, and they are not a vote on any internal cap.
- Inherited parent permissions are not evidence of confinement.
- The reviewed bytes are the file whose raw SHA-256 matched the supplied fingerprint. No other draft was reviewed.
