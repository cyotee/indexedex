# Implementation/testing plan council run

## Admission

- Run: `pairtoken-se-stage-one-plan-20261028-01a1810f`.
- Profile: research/document authoring, full four-member Native council.
- Phase: final.
- Authorization: explicit user request for a council-written implementation
  and testing plan next to the PRD.
- Final path:
  `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_IMPLEMENTATION_AND_TEST_PLAN.md`.
- Target path was absent at admission. No existing document will be overwritten.
- Source PRD hash:
  `574ce6c03c0bc62f79a816e5a7775c831cb932082e0dd4bfe414fc1945ed7a7f`.
- Snapshot: `inputs/PRD.md`; source has 70 acceptance rows and 83,511 UTF-8 bytes.
- Current source matched the revision already read/validated by the coordinator.
- Source PRD, production code, tests, configuration, and Git remain read-only.

## Native ownership and preflight

- Owner: invoking session `01a1810f-e36d-7ba5-9795-d239a4d3e645`.
- Coordinator model exposed: `gpt-6.1-sol`; reasoning not separately exposed.
- Mode: invoking-agent coordination, no independent coordinator vote.
- Ordinary `council-member` role exposed; configured max_depth 2. Direct-child
  shape requires one level; no nested delegation requested.
- MiniMax forceAdaptiveThinking true observed in existing model override;
  this is configuration evidence, not payload/billing attestation.
- Shared workspace requested (`isolated: false`), no merge or configuration edits.
- All members deliver inline, coordinator archives exact text. No member writes
  or alternate writer probes are authorized.
- Prior council sessions are not reused: these are fresh planning assignments.
- Completion monitoring: `mon_7TWYV188BJ8SA2VG`, persistent children RPC watch,
  registered before launch.
- Snapshot raw hash verified equal to the admitted source hash before launch.

## Participants

| Member | Requested route | Task | Initial status/attempt | Advisory status/attempt |
| --- | --- | --- | --- | --- |
| Astra | chatgpt-subscription/gpt-6-astra:high | st_01a18421 | completed, substantive original archived / 1 | completed, support with corrections / 1 |
| Grok | xai/grok-4.7:xhigh | st_01a18422 | incomplete archival original; recovery ended HTTP 403 / 2 | unavailable after provider error / 0 |
| MiniMax | minimax/MiniMax-M3 | st_01a18423 | completed, substantive original archived / 1 | completed, support with corrections / 1 |
| Kimi | kimi-coding/k3.1-pro:high | st_01a18424 | completed, substantive original archived / 1 | completed, support with corrections / 1 |

Actual resolved identities/ancestry are recorded when Native exposes them.
No substitutes or retries have occurred.

## Initial receipt notes

- MiniMax's complete 88,829-character original is preserved in
  `coordinator/received/minimax-original.md`. Required sections and A01-A70
  mapping were read in bounded output chunks.
- Native snapshot: process mode, explicit minimax/MiniMax-M3, child
  `01a18421-73fb-7c9c-9ccc-900667227958`, parent/root
  `01a1810f-e36d-7ba5-9795-d239a4d3e645`.
- MiniMax reported read-only shasum/cmp commands although command execution
  was not requested. No implementation, test/build, or file write is reported.
- Its alleged baseline principal-sign defect is not adopted: the source's
  signed addition principal is negative, so fees minus callerDelta is a
  positive cost. Other proposals remain subject to source verification.
- Grok's initial task settled but its final summary displaced the complete
  inline contribution from final_response. The supported transcript reader
  elides 29,081 middle characters. A same-task, no-tool recovery requests
  verbatim retransmission only (epoch 1); no re-review or new research.
- Grok's delivery-only recovery ended with provider HTTP 403 and a refusal
  message. No retry or substitution follows an auth/policy failure.
  A supported tail read also retained the same output cap; no private runtime
  file was opened to bypass it. Available original text is preserved in
  `coordinator/received/grok-original-partial.md`, with its elision marker.
- Grok's actual initial route was xai/grok-4.7:xhigh, reasoning xhigh, process
  mode. Full-original coverage and advisory participation are unavailable.
- Kimi's complete 46,260-character original is preserved in
  `coordinator/received/kimi-original.md` and has been read through its final
  gates. Native resolved kimi-coding/k3.1-pro:high, process mode, child
  `01a18421-73d6-792f-9ac5-d620c73c86dd`.
- Astra's complete 69,083-character original is preserved in
  `coordinator/received/astra-original.md` and was read through its final
  release limits. Native resolved chatgpt-subscription/gpt-6-astra:high,
  process mode, child `01a18421-72df-7b0f-bbd2-283a4221c9c0`.
- Every initial task and Grok's delivery recovery has settled. Three complete
  substantive originals plus the disclosed partial Grok text support a
  labeled partial full-council synthesis. No missing Grok content is inferred.

## Draft and publication

- Draft: `coordinator/draft.md`, frozen identity
  `pairtoken-se-stage-one-plan-20261028-01a1810f-r1`.
- Raw SHA-256:
  `e586652849499d117b97c01882e66651777a3cbf3a50a5cd2750ea4c01660737`.
- Draft validation: 44,714 UTF-8 bytes, 70 unique A01-A70 matrix rows, no missing IDs.
- Advisory feedback: requested from Astra, MiniMax, and Kimi on the same r1.
  Grok is unavailable after provider policy/auth failure; no retry/substitute.
- MiniMax's exact feedback is archived in
  `coordinator/received/minimax-feedback.md`. It withdraws the baseline
  principal-sign finding and requests sequencing/mechanism precision and
  corrections to contribution attribution. Astra and Kimi also settled with
  support with corrections; their exact feedback is archived alongside it.
- Missing inputs: no required input missing; runtime implementation evidence is
  not available and not claimed.
- Publication: published at the explicitly authorized co-located final path.
- Published SHA-256:
  `ff2f9cc750aa5136d1d8db97352c0c9f925a65754a6a6714aa00bd00c0d6107c`.
- PRD changes, implementation, tests/builds, installs, deployments, Git: none.
- Final document identifies the pinned PRD, actual partial-council
  participation, adoption choices, advisory outcome, and limits. It claims no
  implementation, gas feasibility, or passing tests.
- Verification complete: published bytes match the expected hash, 70 unique
  acceptance rows are present, all 13 run artifacts plus the co-located plan
  are nonempty, and every available advisory concern has a resolution.
- The source PRD and frozen draft hashes matched admission immediately before
  publication. The final path was absent and no existing file was overwritten.
- Source checks resolved factory APIs, exact artifact CLI argument handling,
  canonical position-key helpers, numeric compiler/test settings, size-helper
  report semantics, and the canonical NatSpec/central-values workflow.
- A70 retains an explicit release input: deployment network and practical
  transaction/RPC-read gas budgets. This does not block delivery of the plan,
  but prevents an unmeasured production-feasibility claim.
- No further review round, member substitution, or post-403 provider retry.
