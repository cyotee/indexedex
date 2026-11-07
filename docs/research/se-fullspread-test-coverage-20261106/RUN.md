# Council run record

## Identity

- Run ID: se-fullspread-test-coverage-20261106
- Profile: research
- Council kind: full
- Question: Name every test the remediation plan must state for complete coverage of adopted routes, preview equality, and cross-vault integration.
- Brief: docs/research/se-fullspread-test-coverage-20261106/brief.md
- Current phase: final
- Phase note: All four feedback files were written. Native returned an empty assistant summary after those writes. The coordinator used the files and published section 9. The update does not authorize implementation.

## Authorization

- Source: explicit council directive
- Authorizing task or role: the user asked this session to have the council review test coverage and make the plan state the tests required for complete coverage
- Authorized writes: Markdown artifacts under docs/research/se-fullspread-test-coverage-20261106/, and one later cooperative coverage section in the published remediation plan
- Not authorized: implementation, reviewed-project tests, installs, deployment, wallets, Git staging or commit or push, configuration replacement, unrequested fan-out, credential inspection
- Inherited permissions: accepted. Same parent permissions are not extra authority and not a sandbox.

## Native owner

- Owner session ID: not exposed
- Root session ID: not exposed
- Owning task ID: not exposed
- Control channel: invoking session
- Identity limit: task and session IDs above are copied from Native status where exposed. This record claims no cryptographic or cross-instance identity guarantee.

## Coordinator

| Field | Value |
| --- | --- |
| Requested mode | invoking-agent |
| Actual mode | invoking-agent |
| Requested role | invoking session |
| Actual role | invoking session |
| Requested model and reasoning | invoking session current model |
| Actual model | xai/grok-4.7 |
| Actual reasoning or thinking | xhigh |
| Task ID | not exposed |
| Session ID | not exposed |
| Fresh or continued | continued |
| Logical assignment | se-fullspread-test-coverage-20261106/coordinator/synthesis |
| Attempt count | 0 |
| Identity source | invoking session |

## Members

| Label | Requested model and reasoning | Actual role | Actual model | Actual reasoning | Task ID | Session ID | Fresh or continued | Initial assignment | Initial attempts | Feedback assignment | Feedback attempts | Initial status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| astra | chatgpt-subscription/gpt-6-astra:high | council-member | chatgpt-subscription/gpt-6-astra:high | high | st_01a1af0b | not exposed | fresh | se-fullspread-test-coverage-20261106/member/astra/initial | 1 | se-fullspread-test-coverage-20261106/member/astra/feedback | 0 | settled; response present | task completion |
| grok | xai/grok-4.7:xhigh | council-member | xai/grok-4.7:xhigh | xhigh | st_01a1af0c | not exposed | fresh | se-fullspread-test-coverage-20261106/member/grok/initial | 1 | se-fullspread-test-coverage-20261106/member/grok/feedback | 1 | settled; feedback requested | task completion |
| minimax | minimax/MiniMax-M3, admitted adaptive thinking | council-member | minimax/MiniMax-M3 | admitted adaptive thinking | st_01a1af0d | not exposed | fresh | se-fullspread-test-coverage-20261106/member/minimax/initial | 1 | se-fullspread-test-coverage-20261106/member/minimax/feedback | 0 | settled; response present | task completion |
| kimi | kimi-coding/k3.1-pro:high, global route | council-member | kimi-coding/k3.1-pro:high | high | st_01a1af0e | not exposed | fresh | se-fullspread-test-coverage-20261106/member/kimi/initial | 1 | se-fullspread-test-coverage-20261106/member/kimi/feedback | 0 | settled; response present | task completion |

## Logical assignment attempts

| Logical assignment | Attempt | Council-issued | Task ID | Fresh or continued | Reason | Counts toward cap | Outcome |
| --- | --- | --- | --- | --- | --- | --- | --- |
| se-fullspread-test-coverage-20261106/member/astra/initial | 1 | yes | st_01a1af0b | fresh | initial | yes | settled |
| se-fullspread-test-coverage-20261106/member/grok/initial | 1 | yes | st_01a1af0c | fresh | initial | yes | running |
| se-fullspread-test-coverage-20261106/member/minimax/initial | 1 | yes | st_01a1af0d | fresh | initial | yes | settled |
| se-fullspread-test-coverage-20261106/member/kimi/initial | 1 | yes | st_01a1af0e | fresh | initial | yes | settled |

## Draft identity

- Draft ID: draft-se-fullspread-test-coverage-20261106-r1
- Path: docs/research/se-fullspread-test-coverage-20261106/coordinator/draft.md
- Fingerprint: 06d3ebde19da79aca7d0626c340823931feb4d2c4e860f78aa9db41a37c5bff6
- Fingerprint source: coordinator-supplied SHA-256 of the draft file bytes
- Sent for advisory review: yes
- Draft bytes changed after review: no

## Feedback disposition

| Label | Draft ID reviewed | Disposition | Feedback path | Counts as missing initial response |
| --- | --- | --- | --- | --- |
| astra | not written | not received | members/astra/feedback.md | not applicable |
| grok | not written | not received | members/grok/feedback.md | not applicable |
| minimax | not written | not received | members/minimax/feedback.md | not applicable |
| kimi | not written | not received | members/kimi/feedback.md | not applicable |

## Missing responses

- Missing initial responses: pending; all four tasks are running
- Missing feedback: pending
- Treatment: absence, silence, and an unsettled task are not approval. A later feedback file does not fill a missing initial response. An unselected member is not a missing member.

## Failures and continuity

- Failures: none
- Timeouts: none
- Cancellation: none
- Lost continuity: none
- Reconciliation before any replacement: not applicable
- Late output from a cancelled task used to finalize: no

## Coverage

- Coverage status: not started
- Required targets not examined: the four admitted documents, until members settle
- Optional context absent: none admitted
- Evidence limits: no test run is authorized. A plan sentence is not a passing test.

## Publication

- Publication state: published
- Delivery requested: file
- Actual delivery: file
- Final path: docs/research/se-fullspread-test-coverage-20261106/REPORT.md
- Cooperative target result: section 9 added to the remediation plan. Closed product choices were preserved.
- Unrelated edits preserved: not applicable
- Model work repeated for publication: no
- Git actions: none
