# Research report - PairToken behavioral requirements

## Question

- Run ID: pairtoken-behavioral-requirements-20261027-01a17d57.
- Question: review the verified StonkBroker PairToken code and write an accurate detailed functional requirements document that a different agent can use to author an implementation plan.
- Profile: research; council kind: full; result label: full.

## Conclusions and deliverable

**The detailed source-faithful requirements are published at handoff/REQUIREMENTS.md. Give that complete file, by itself, to the separate planning agent.** It includes Scope and Conformance front matter, Parts I-III, all 17 named public/external methods, receiver, 17 generated getters, exact integer math, source quirks, events/errors and 58 acceptance scenarios. There are 172 distinct numbered requirement/acceptance IDs, with no undefined references or duplicate definitions.

All four council members support using the baseline for a separate agent's implementation plan. Astra and MiniMax requested bounded corrections, which were source-checked and resolved. Grok and Kimi requested none. The final is coordinator revision pairtoken-requirements-final-r2; the exact reviewed draft remains pairtoken-requirements-draft-r1. The final wording was not separately re-reviewed or retroactively member-approved.

The document describes PairToken rather than the earlier independent IndexedEx vault design. It preserves basket issuance, genesis dead shares and gross-minShares behavior, single-leg entry after bootstrap and its caps, two exit routes and retention, fee-exposed collective reserves, protocol routing, idle/donation property, previews and failures. It does not silently add a price-free liquidity ledger, personal fee escrow, a normalized getRate, or Crane deployment architecture. Any such later adaptation is a separate explicit deviation.

The baseline supports planning the contract's local behavior against the described dependency interfaces. It does not certify a future implementation, deployed whole-system equivalence, runtime safety or license compliance.

## Authorization and scope

- Authorization: explicit current user request for council source review and detailed requirements authorship.
- Owner/invoking coordinator: 01a17d57-ab12-74e2-b0aa-283ffbf92a1e; coordinator is not an independent vote.
- Admitted evidence: unchanged Sourcify source bundle, prior factual fidelity audit and corrected resolution, members' own prior context, and this run's independent originals/one advisory round.
- The previous alternative-vault report is not a normative source.
- Inherited parent-equivalent permissions were accepted; owned paths are workflow boundaries, not a claimed sandbox.
- Implementation authority: none. No implementation plan, production code, tests/builds, installs, wallet/deploy, live configuration or Git changes performed.
- Separate planner-facing file: handoff/REQUIREMENTS.md. Analyst source evidence, traceability, member transcripts and this council report are outside handoff/. No raw source is copied into the handoff.

## Participation

| Participant | Role | Requested / Native resolved route | Reasoning exposed | Task | Continuity | Result |
| --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking-agent, not a vote | Current invoking model not exposed through task metadata | Not exposed | none | continued invoking session | synthesis, resolution and final |
| Astra | council-member | chatgpt-subscription/gpt-6-astra:high | high | st_01a17d68 | prior audit context continued | initial + advisory settled |
| Grok | council-member | xai/grok-4.7:xhigh | xhigh | st_01a17d69 | prior audit context continued | initial + advisory + delivery turns settled |
| MiniMax | council-member | minimax/MiniMax-M3 | no depth exposed; adaptive override observed in configuration | st_01a17d6a | prior audit context continued | initial + advisory settled |
| Kimi | council-member | kimi-coding/k3.1-pro:high | high | st_01a17d6b | prior audit context continued | initial + advisory settled |

Native terminal snapshots expose process execution for all four, parent/root equal to the invoking owner, and resolved/effective provider/model identities. Details are in analyst/native-identity.md. No route, account, role or depth substitution occurred. MiniMax request payload, credential type and billing were not independently inspected. These are four independent current-run originals with admitted prior shared audit context, not four fresh blinded source reviews. No current-run peer-original reading was assigned.

- Coordinator mode: invoking-agent; actual equals requested.
- Missing originals: none. Missing substantive feedback: none.
- Originals: members/<member>/response.md. Advisory feedback: members/<member>/feedback.md.

## Evidence

| Item | Source / identity | Class | Use |
| --- | --- | --- | --- |
| Verified source retrieval | Sourcify chain 4663, 0x56C8c249d4c021e93635b120aC68A9a36eb01753, matchId 55980642; HTTP 200 re-fetch October 27, 2026 | source observation / coordinator-supplied to members | Subject identity and unchanged 28-source body |
| Match metadata | creation/runtime exact_match, verifiedAt 2026-10-12T10:33:37Z | source observation of server metadata, not repeated bytecode proof | Provenance only |
| Body identity | HTTP-body SHA-256 ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98; exact equality to prior audited body | source observation | No source drift across the two council tasks |
| Raw/readable archives | Preserved under prior audit evidence; exact paths and original/archive newline hashes in analyst/evidence-manifest.md | source observation | Source analyst evidence, not planner input |
| 28 readable bodies | 28/28 byte-identical to JSON, no missing/extra paths | source observation | Readable-rendering integrity, not library proof |
| Main contract/helpers | PairToken complete; key math, token, callback and manager-read dependencies | static source analysis | Functional requirements and algebra |
| Council originals and feedback | This run's eight substantive artifacts | source observation | Independent coverage and single advisory pass |
| Acceptance cases | 58 observable criteria in requirements | static derivation, not executed tests | Future conformance planning |

Only the already public source URL was fetched; no private source excerpt was sent as a public query. Source locators and detailed coverage reside in analyst/traceability.md and analyst/source-coverage-register.md rather than in the planner-facing file.

## Coverage

| Target | Requirement | Status | Evidence / limit |
| --- | --- | --- | --- |
| PairToken main contract | Required | examined | Full source read; every named function/getter/event/error accounted for |
| Economic and lifecycle branches | Required | examined | Basket quote branches, genesis/dead supply, receipt checkpoint, both entries/exits, retention and compounding |
| Integer/helper contracts | Required | examined at relevant functions | Full-precision/checked/modular operations, signed widths, fixed tick map, amount/liquidity equations and errors |
| Native/token/callback boundary | Required | examined | Actual read/call order, amount/result encoding, catches, wrapper bytes and conditional outputs |
| All 28 source files | Supplied dependency context | collectively examined; member scopes differentiated | Astra/Kimi full admitted bundle reads; focused helper examination by others; no proof of all library algorithms |
| Factory/fee manager concrete code | Not supplied | absent | Known call contracts and reporting behavior only; no invented defaults/governance/pull guarantees |
| Concrete deployed manager/Pool, hooks/tokens | Not supplied | absent | Interface, required storage-read compatibility and returned-delta handling known; engine execution unverified |
| Live state/clone transaction/bytecode | Not supplied | absent | No current values or deployment-trace claims |
| Prior alternative report | Context only | not a baseline | Its incompatible choices not inherited |
| Standalone planner artifact | Required | examined | No raw source paths/listings, code fences or member inputs; complete math and requirements references |
| License/legal compliance | Not adjudicated | not examined as a legal question | Source-informed provenance and separation recorded; no compliance certification |

## Disagreement and missing responses

No substantive disagreement remains about the corrected document's suitability for implementation planning. The independent originals contained several errors or overstatements; they were not voted into the final. Exact correction/rejection dispositions appear in coordinator/resolution.md and analyst/candidate-qualification-notes.md. Any source-equivalent behavior that a later product owner wishes to change remains a separate decision, not a hidden repair.

No missing response was treated as approval. Feedback did not substitute for a missing original. Source agreement is static evidence and not execution proof.

## Advisory review

- Draft: pairtoken-requirements-draft-r1, coordinator/draft.md.
- Draft SHA-256: 763dd6ad786ac84e61f968af77a627a2c0103a6fc6c67c8152127115083f229b.
- Astra: SUPPORT WITH CORRECTIONS, C1-C4 and optional N1.
- MiniMax: SUPPORT WITH CORRECTIONS, MINI-01 through MINI-05.
- Grok: SUPPORT, no changes. Kimi: SUPPORT, no changes.
- Resolution: coordinator/resolution.md, every substantive concern disposed.
- Final changes: raw return/revert bytes and payout target; one-zero-reserve scenario supply condition; paired-add read order; nominal native-pull qualification; explicit ordinary-entry compound swap, cap/idle and liquidity-read clarifications; retrieval attribution; complete front-matter handoff.
- Final donation/cap wording does not adopt an unconditional donation-monotonicity guarantee.
- Post-advisory wording is coordinator-owned, not newly member-approved text. Only one substantive advisory round.

## Recommendations for the separate planning stage

Use the complete handoff/REQUIREMENTS.md, including its front matter and dependency table. Map the numbered requirements and acceptance criteria into the future plan. Identify a compatible manager/dependency environment rather than inventing current settings. Keep any requested IndexedEx/Crane/getRate/policy adaptations explicitly separate from this source baseline. This report does not itself supply an implementation plan or authorize execution.

## Limitations and delivery record

- Static source documentation only; no project test/build, transaction, deployed-state, bytecode, safety or legal certification.
- Missing concrete external implementations limit whole-system/live-output claims, not the documented local behavior.
- Source analysts are source-exposed. Separated documents and a different agent do not alone establish a compliant or unexposed workflow.
- Some child bridges lacked usable apply_patch; members returned content and coordinator archived it with apply_patch. No unapproved child write/edit fallback was used in this run.
- Grok original delivery required one format repair for a commentary exceeding transcript capacity. A later advisory delivery repair was unnecessary: the coordinator determined its truncation flag concerned omitted history, recovered the intact substantive body, and preserved it. No additional substantive review occurred.
- Original member artifacts remain verbatim; superseded claims are annotated in the resolution, not silently overwritten.

## Publication

- Publication state: published.
- Planner-facing final: handoff/REQUIREMENTS.md, identity pairtoken-requirements-final-r2.
- Council final: REPORT.md.
- Analyst traceability: analyst/traceability.md; resolution: coordinator/resolution.md.
- Cooperative update: none; previous reports/source/production code left unchanged.
- Model work repeated for publication: no. Delivery-only repairs are separately recorded.
- Git actions: none. Artifacts retained until explicit deletion.

