# Member feedback

## Identity

- Run ID: se-fullspread-remediation-readiness-20261105-r2
- Member label: minimax
- Phase: advisory review
- Owned path: docs/research/se-fullspread-remediation-readiness-20261105-r2/members/minimax/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: role council-member as assigned; actual model not exposed; reasoning not exposed; task ID not exposed; session ID not exposed
- Fresh or continued: continued. This is the same conversation that produced members/minimax/response.md; no continuity was lost.
- Initial response path: docs/research/se-fullspread-remediation-readiness-20261105-r2/members/minimax/response.md
- Initial response preserved: yes. Not overwritten by this file.

## Draft under review

- Draft ID: draft-se-fullspread-remediation-readiness-20261105-r2-r1
- Path: docs/research/se-fullspread-remediation-readiness-20261105-r2/coordinator/draft.md
- Fingerprint supplied by the coordinator: not computed
- Fingerprint independently computed: not computed
- Draft bytes opened: yes. The file opened at that path and its own identity lines name draft ID draft-se-fullspread-remediation-readiness-20261105-r2-r1.

## Disposition

- Disposition: support-with-reservations
- This file replaces a missing initial response: no

The proposed verdict, ready, is the verdict I filed in my initial response, and I re-read the two sentences the draft builds on. In docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md, line 32 states the route outcome when the price is not strictly inside the position, and line 58 names the standalone gas routes, excludes the two operator appointment calls, keeps the three ceilings and gives each plan section 12 row its own composed measurement. The draft states both accurately. The reservations below are wording and completeness items for the final report. They do not change the verdict, and I do not withdraw it.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| C1 | Proposed text, the paragraph beginning "The coordinator re-read the current owner lock." | The draft asserts that line 32 closes the prior report's out-of-range choice but does not state the qualifier that makes it close. The lock's scope sentence at REMEDIATION_PRD.md:26 scopes the lock to "A one-sided share mint, and a one-token `donate` or `compound`. Not a bundle deposit. Not a one-token exit." Two readers could diverge: one reads "Line 32 states the outcome when the price is not strictly inside the position" as a general route rule and carries it into the one-token exit, where the draft supplies no sizing rule and the base plan's exit mechanic at UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:180 is written for a different flow; the other reads it as scoped and leaves the exit to the base plan. The draft's Evidence gaps records the unread base plan residual but not this qualifier, and my initial response disclosed it as an assumption the verdict rests on. | State in the draft that the closure holds for the one-sided add flow because the lock's scope excludes the one-token exit (REMEDIATION_PRD.md:26), and that the one-token exit keeps base plan section 9 (plan line 180). Advice to the coordinator's wording; no edit to the required target. |
| C2 | Proposed text, the same paragraph, on the sentence "Those are the two choices the prior report left open. The current text closes both." | The prior report asked for "the execution or preview outcome" when the starting price is not strictly inside the range (docs/research/se-fullspread-remediation-readiness-20261105/REPORT.md:54). The draft says only "the outcome" and does not say why the preview surface is covered. Two readers could diverge on whether a preview at a price outside the position has a stated outcome or only the execution route does. The answer is in the base plan: preview and execution both call the same Planner function (plan line 192), and `previewExchangeIn` returns the refund (plan line 96). The draft's own Coverage table records the implementation plan as not fully re-read by the coordinator, so the preview half of the prior question is asserted rather than shown. | Name the preview parity with its citation, or state the closure as covering the route outcome that both surfaces share. Advice; no edit to the required target. |
| C3 | Proposed text, the paragraph beginning "Grok disclosed two readings that are not open choices." | The sentence "a collapsed candidate returns the input and does not keep a selected swap. That is the outcome to copy" keeps the candidate as its subject, but "that is the outcome" can be read as the deposit outcome. Two readers could diverge: one implements a zero-liquidity deposit as a refund of the input, the other as the written rejection. The lock sentence at REMEDIATION_PRD.md:32 is about the sizing candidate; the deposit outcome is written elsewhere: FS-A05 rejects added liquidity at or below 1_000 (UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:558), F1 records that the current code maps a failed plan to `MinLiquidityNotMet` (REMEDIATION_PRD.md:83), and F3's fix direction calls it a "rejected sizing candidate" (REMEDIATION_PRD.md:102). | Keep the candidate as the subject of "returns the input", and where a deposit outcome is mentioned, cite the written rejection instead of leaving a reader to infer a refund. Advice; no edit to the required target. |
| C4 | Preserved disagreements, and Proposed text, where the other copied rules are listed as closed. | The prior report's Recommendations told the reader not to ask the owner to choose between the quadratic root and the pool-applied amount, because the target already settles it (REPORT.md:100). The draft's disagreements row reads "none" and the proposed text does not carry the item, so a reader comparing the two reports sees an item that disappeared with no recorded reason. Two readers could diverge on whether it was decided or overlooked. | Add one line recording that the planned-amount rule stays closed on the page: REMEDIATION_PRD.md:28 rounds the gross swap input down, and line 30 caps the planned `n` at the amount the pool will apply with the fee rounded up. Advice; no edit to the required target. |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

The draft's attribution of two readings to grok is the coordinator's statement about a peer response this member did not open. It is not adopted or rejected here. The lock sentences the draft relies on were re-read by this member in the required target.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority. It does not write the plan file and it does not replace the draft.
- Inherited parent permissions are not evidence of confinement.
- The concern rows are advice about the draft's wording and completeness. No finding is asserted against the required target, the implementation plan, or the family PRD, and none of those files was edited.
- Static reading only. No test, compile, gas measurement, install, deployment, or Git action was run in this pass, and no fingerprint was computed.
