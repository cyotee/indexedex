# Member feedback

Coordinator archive of the inline advisory return. The member was instructed not to write this file. This archive does not replace the initial response.

## Identity

- Run ID: pairtoken-prd-sourcify-accuracy-20261027
- Member label: astra
- Phase: advisory review
- Owned path: members/astra/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: council-member; chatgpt-subscription/gpt-6-astra:high; task st_01a17e7a; session 01a17e7a-70bc-78fc-842a-9d14253e4444 from the initial pass
- Fresh or continued: continued
- Initial response path: members/astra/response.md
- Initial response preserved: yes
- Archive source: exact inline return on task completion, not a member-written file

## Draft under review

- Draft ID: draft-pairtoken-prd-sourcify-accuracy-20261027-r1
- Path: /Users/cyotee/Projects/indexedex/docs/reviews/pairtoken-prd-sourcify-accuracy-20261027/coordinator/draft.md
- Fingerprint supplied by the coordinator: 8ff51c4b6f4dc7c2f853645858ec3ff3dca777017b98ae35cfe2e033eb215fb4
- Fingerprint independently computed: 8ff51c4b6f4dc7c2f853645858ec3ff3dca777017b98ae35cfe2e033eb215fb4, by the member's authorized shasum
- Draft bytes opened: the pinned draft only

## Disposition

- Disposition: support-with-reservations
- This file replaces a missing initial response: no

The member said the draft preserves the original verdict, the low retention-order clarification, and the distinction between source-fidelity analysis and runtime proof. Reservations concern the justification for classifying two other findings as non-material, not newly verified source defects. The original conclusion is not withdrawn.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| A1 | L6 | "Value call" does not itself establish the gas policy. An empty-calldata value call can also specify a fixed gas limit. Preserving the failure wrapper does not independently establish how much gas is forwarded. | Retain the clarification. Remove the categorical claim that "value call" already excludes a fixed stipend. If the low classification rests on an existing normative requirement for unrestricted gas forwarding, identify it. Otherwise acknowledge that the draft has not established why the omission is merely wording. Describe forwarding as subject to EVM call-gas rules, rather than promising literally all remaining gas. |
| A2 | L7 | Dependency nonconformance does not eliminate caller-side behavior. A non-static call can behave differently even when the dependency is outside its declared view ABI, because a static execution context is caller behavior. "The PRD does not require the implementer to drop view" is weaker than requiring preservation of the observable behavior. | Retain the explicit static-call wording. Support the low classification with an existing normative requirement that already entails static calls, or qualify the classification as unresolved. The member did not reopen the PRD to decide whether such a requirement exists. |

## What was not adopted from others

- Peer responses read: no
- L2 through L7 were available only through the draft. No additional objection to L2-L5 as presented. That is not fresh source verification. An item absent from the original is not hidden dissent.

## Limits

- This review used only the hash-verified draft and the member's existing response context. No source rereading, research, arithmetic, edits, tests, builds, Git, installs, or file creation by the member.
- Participation and peer-evidence statements remain coordinator-reported for this pass.
- Static review is not runtime proof.
- No further review round was requested.
- This disposition does not replace the initial response and authorizes no implementation.
