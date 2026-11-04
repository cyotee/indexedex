# Council resolution - PairToken requirements

## Reviewed and final identities

- Reviewed: pairtoken-requirements-draft-r1, coordinator/draft.md.
- Reviewed SHA-256: 763dd6ad786ac84e61f968af77a627a2c0103a6fc6c67c8152127115083f229b. Draft remains unchanged.
- Final requirements: pairtoken-requirements-final-r2, handoff/REQUIREMENTS.md.
- Four substantive independent originals and four substantive advisory reviews settled. Same four Native reviewer contexts continued; identities in analyst/native-identity.md.
- The final is a coordinator revision after the single advisory pass, not newly member-approved wording. No second substantive advisory round occurred.

## Advisory dispositions

| Member | Position | Resolution |
| --- | --- | --- |
| Astra | SUPPORT WITH CORRECTIONS | C1-C4 accepted; optional N1 accepted. |
| Grok | SUPPORT, no changes requested | Full feedback preserved; no source changes requested. |
| MiniMax | SUPPORT WITH CORRECTIONS | MINI-01 through MINI-05 accepted as scoped below. |
| Kimi | SUPPORT, no changes requested | Source-checked support preserved; no corrections requested. |

No member disputes completeness for a separate implementation-planning agent, subject to the bounded corrections and dependency limits. Agreement is not runtime or legal proof.

## Every substantive concern

| Concern | Disposition and final requirement change | Source/authority checked |
| --- | --- | --- |
| Astra C1: wrapper reason is not only revert data | Accepted. PT-BAL-05 says complete raw returndata from reverted or successful-but-rejected calls; PT-AC-52 covers one-byte data and false return; PT-ERROR-03 distinguishes error failure from unchanged bubbling. | Currency.transfer and CustomRevert.bubbleUpAndRevertWith reread; returndata is copied regardless of call-success bit. |
| Astra C2: one-zero-reserve scenario needs S>0 | Accepted. PT-AC-11 now says positive supply and exactly one basket reserve zero. Normative PT-QUOTE-01 unchanged. | _quoteShares original 500-511 reread; zero supply has earlier branch precedence. |
| Astra C3: paired-add read order | Accepted. PT-DEP-03 explicitly samples idle0, idle1, then fresh manager price; Deploy retains its own checkpoint order. | _addAll original 295-302 reread. |
| Astra C4: native pull is nominal, not funding proof | Accepted. PT-BAL-02 distinguishes nominal no-transfer helper result from ordinary currency0 entrypoint value checks. No key-sort or balance check added. | _pull original 661-668 and native admission/initializer behavior rechecked. |
| Astra N1: preserve front matter | Accepted. PT-HANDOFF-01 includes complete Scope/Conformance front matter plus Parts I-III. | Explicit user planning handoff and complete draft assignment. |
| MINI-01: ordinary paired entry may compound-swap | Accepted as explicit clarification. PT-DEP-02 names possible pool-moving balancing swap without compound tick guard; existing PT-COMP math and route behavior unchanged. | deposit leading _compound and ratio/deploy call sites rechecked; user-zap guard is separate. |
| MINI-02: payout target and raw acceptance | Accepted. PT-BAL-05 names native recipient versus ERC20 token as wrapped target and states raw-word rather than Boolean-decoder acceptance. Combined with Astra C1 reason-byte correction. | Currency.transfer and wrapper reread in full. |
| MINI-03: two distinct liquidity reads | Accepted. PT-VIEW-01 explicitly says position first word versus active pool word and low128 of each respective word. | StateLibrary getPositionLiquidity, getLiquidity and slot formulas checked. |
| MINI-04: idle affects zap cap | Accepted with qualification. PT-ZAP-02 states unsolicited idle can affect the actual post-compound reference. It does not promise every prior donation strictly raises the final cap: rate, floors and intervening compound matter. | basket idle addition, zap snapshot/cap and compound checkpoint checked. |
| MINI-05: reconfirmation attribution | Accepted. Scope attributes source identity reconfirmation to council evidence retrieval. | Coordinator's HTTP 200 re-fetch and exact body comparison. |
| Grok and Kimi: no concerns | No additional change requested. Their topic dispositions and source/hand-off qualifications remain preserved in feedback files. | Complete feedback bodies and reviewed draft identity. |

## Reconciliation of independent originals

Astra's detailed organization and stable IDs form the synthesis base after all four originals were read. All members cover system/property, interfaces, initialization/genesis, basket issuance, both entry and exit routes, collective fees/protocol compounding, callbacks/settlement, token/native boundaries, previews, events/errors, acceptance and dependency limits.

- MiniMax's full topic inventory is retained, but its reversed full-range inequalities, broad arithmetic/safety claims, unconditional refund/fill/native-funding implications, wrong payout error identity and some scenario/error assertions are not adopted. These are independently recorded in analyst/candidate-qualification-notes.md. Member feedback explicitly supersedes several original overstatements.
- Grok's originals' incorrect checked-burn-supply wording, conditional zero-output transfer, universal invalid-tag error, missing internal reference IDs and overly broad approval-failure descriptions are not adopted. Final states checked/modular updates, unconditional selected payout, enum/ABI distinctions and self-contained helper contracts.
- Kimi's full interface/operation inventory and delta distinction are retained. Its broad checked narrowing for redemption liquidity/swap-size conversions is corrected to explicit source width behavior, which Kimi endorsed in advisory feedback.
- Astra's source-exact math, widths, interfaces, 58 scenarios and dependency map are retained with its own C1-C4 corrections. No candidate is treated as infallible because it is a member original.

The earlier IndexedEx alternative-vault report is not a baseline. No virtual liquidity offsets, personal fee escrow, fixed target, getRate, new initialized guard, armed callback, or silently repaired slippage/casts/fills are imported. Future IndexedEx/Crane adaptations must be identified separately rather than called source equivalence.

## Artifact delivery and preservation

Astra authored its artifacts using apply_patch. MiniMax and Kimi returned substantive originals/feedback where apply_patch was unavailable; coordinator archived the exact returned Markdown via apply_patch. Grok's original needed one format repair because the requirements commentary exceeded the supported transcript cap; complete final artifact was recovered and preserved.

For Grok advisory, the coordinator initially misread the transcript's truncated-history flag as feedback-body truncation and requested an unnecessary delivery repair. Inspection established that the supported transcript contained the full 11071-character advisory body without elision; it was extracted from the assistant message and archived exactly. The repair repeated no substantive analysis. All delivery turns settled. No raw private transcript, tool state or credentials were exported into the council artifacts.

Original files, immutable draft and all feedback remain preserved. This resolution annotates superseded statements rather than silently editing member originals.

## Handoff and limits

The sole planner-facing artifact is handoff/REQUIREMENTS.md. Analyst traceability/evidence/identity files, member materials and this council resolution stay outside handoff/. Requirements contain original prose, tables and mathematical output definitions, not implementation listings or instructions to inspect target code.

The baseline suffices for planning PairToken's local behavior against its specified interfaces. Concrete factory, fee-manager, manager engine, hook/token behavior, deployed creation transaction, live parameters and legal/license-compliance determinations remain outside the established evidence. These are explicit integration/provenance limits, not deferred local requirements. No tests/builds, implementation, deployment, settings edits or Git operations were performed.

