# Member feedback

## Identity

- Run ID: v3-fullspread-v4-se-parity-20261117
- Member label: grok
- Phase: advisory review
- Owned path: /Users/cyotee/Projects/indexedex/docs/research/v3-fullspread-v4-se-parity-20261117/members/grok/feedback.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/research/v3-fullspread-v4-se-parity-20261117/members/grok/response.md
- Initial response preserved: yes

This file does not replace that response.

## Draft under review

- Draft ID: draft-v3-fullspread-v4-se-parity-20261117-r1
- Path: /Users/cyotee/Projects/indexedex/docs/research/v3-fullspread-v4-se-parity-20261117/coordinator/draft.md
- Fingerprint supplied by the coordinator: not computed
- Fingerprint independently computed: not computed
- Draft bytes opened: yes

The opened file's own identity lines match this draft ID, path, and run ID.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The requested change is a locator and scope correction in Proposed text. It does not change the draft's Q2, and it does not change the wings verdict. I support the rest: the question is not confirmed; Q2 is not confirmed; the plan asks a different question; the wings and full-spread readings are preserved rather than voted; my Q1 comparator remains `upperLowerWings`; and the V3-follows-the-plan statement is labeled as observation, not as the requested confirmation.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| C1 | Proposed text, zero-output pass-through paragraph | The paragraph says plan line 95 does not say what a zero-output quote does, and it cites V3 `Planner.sol` lines 281-284 and `InBase.sol` lines 37-38 and 45 for the failed pass-through revert. Those V3 lines do not contain that revert. Line 95 is only the refund sentence. The next requirement, plan line 96, already says a zero first word is a failed or unsupported plan, not a successful pass-through. V3 sets `failed` at `Planner.sol` lines 286-288. The `ExchangeInNotAvailable` revert for that failed pass-through is `InBase.sol` line 39. Lines 37-38 are the failed-check opening and the withdrawal revert. Line 45 is the one-sided mint branch. The V4 claim that a zero-output pass-through can settle as a refund is true only for a zero minimum, and the cited planner lines 120-130 do not show the payment. | Cite plan line 96 and do not call the plan silent. Cite V3 `Planner.sol` lines 286-288 and `InBase.sol` line 39. For the V4 settlement, cite `Execution.sol` lines 68 and 78-80: `_pass` does not set `failed`, so line 68 does not revert, and the pass-through branch pays the recorded output and refund. Narrow the sentence to a zero `minOut`. When `minOut` is greater than 0, V4 reverts `AmountOutNotMet` at `Execution.sol` lines 69-70. Keep the difference, but do not ground it on the current locators. |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

I did not read peer responses before `response.md`, and I did not read them on this pass. Claims in the draft about astra, minimax, and kimi are the coordinator's report. I do not treat those unread members as support, and I do not dispute the draft's account of my own response.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority and does not replace the draft.
- Inherited parent permissions are not evidence of confinement.
- Static reading only. No tests, installs, Git, or project-code edits. No fingerprint was computed.
- I did not re-open the gas-citation path ambiguity. The draft reports it as MiniMax's reason for choosing the full-spread comparator. It does not adopt that citation as its own proof of which file "the V4 implementation plan, section 2" names.
- The wings comparisons I re-checked, including plan lines 24, 32-33, 36, 43, 65, and 92, PRD line 195, and the appointment functions at V4 `MoneyTarget.sol` lines 122-130, match the draft. Those checks are not a second concern.
