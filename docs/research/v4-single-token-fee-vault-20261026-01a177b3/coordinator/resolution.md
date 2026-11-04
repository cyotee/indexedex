# Coordinator resolution

## Reviewed draft

- Draft ID: draft-v4-single-token-fee-vault-20261026-01a177b3-r1
- Path: docs/research/v4-single-token-fee-vault-20261026-01a177b3/coordinator/draft.md
- Fingerprint at review: sha256 d1bcd932e72dd88db3f3a4cc5c33b726d57a7838514d1529502a828fd9e92251
- Draft bytes changed after review: no
- Members asked to review: astra, grok, minimax, kimi
- This resolution supersedes stale status lines in the draft: yes

## Participation and identity

- Run ID: v4-single-token-fee-vault-20261026-01a177b3
- Council kind and result label: full council, full
- Coordinator mode: invoking-agent
- Requested coordinator role and model: invoking session, not a vote
- Actual coordinator role, model, reasoning, task ID, and session ID: invoking session 01a177b3-f4ed-7770-9633-b5735573eb05. Not a child task. Restored model label grok-4.7. Not a vote.
- Coordinator fresh or continued: continued
- Coordinator logical assignment and attempt count: synthesis, attempt 1
- Owner or root session ID: 01a177b3-f4ed-7770-9633-b5735573eb05
- Identity source: Native session record from this thread. Model prose is not the identity source.

## Feedback disposition

| Label | Feedback path | Draft ID named by member | Disposition | Initial response present |
| --- | --- | --- | --- | --- |
| astra | members/astra/feedback.md | draft-v4-single-token-fee-vault-20261026-01a177b3-r1 | requested-changes | yes |
| grok | members/grok/feedback.md | draft-v4-single-token-fee-vault-20261026-01a177b3-r1 | requested-changes | yes |
| minimax | members/minimax/feedback.md | draft-v4-single-token-fee-vault-20261026-01a177b3-r1 | support-with-reservations | yes |
| kimi | members/kimi/feedback.md | draft-v4-single-token-fee-vault-20261026-01a177b3-r1 | support-with-reservations | yes |

## Concern map

| Concern ID | Source | Concern | Disposition | Reason |
| --- | --- | --- | --- | --- |
| A1 | members/astra/feedback.md | Mint uses virtual offsets and exit uses `A/S`, so a round trip profits. | accepted | Rechecked: deposit 1001 against `S=100`, `A=1000`, `s0=a0=1` mints 101 and exits 1005. The final uses one ratio for both. |
| A2 | members/astra/feedback.md | Crediting old fees after a deposit lets the entrant take them. | accepted | Rechecked: 100 uncredited fees, deposit 100, entrant exits 150. The final includes collectible target fees before a supply change. |
| A3 | members/astra/feedback.md | A position that can earn fees is not an assignment. | accepted | The final requires a named assignment. No sponsor was found. |
| A4 | members/astra/feedback.md | The two named breaks are not Astra's reading of the brief. | accepted | Partial fees are a disclosed limit. The zero-sale preview label stays disagreed, not attributed to Astra. |
| A5 | members/astra/feedback.md | The adopted rate's formula and movement were missing. | accepted | The final states the one-share redemption and what can move it. |
| A6 | members/astra/feedback.md | Raw balance and a target rate are not interchangeable, and a movable rate is not by itself unusable. | accepted | Buffered leg needs a provider. Identity leg is not a target valuation. Kimi's rate movement is disclosed, not a locked-law breach. |
| A7 | members/astra/feedback.md | Map the three prior mechanisms, and do not attribute the Bunni warning only to Grok. | accepted | The mapping is inference. Astra also opened the Bunni repository warning. |
| C1 | members/grok/feedback.md | The three mechanisms were not named on the adopted path. | accepted | Same mapping as A7. Not a re-execution. |
| C2 | members/grok/feedback.md | Say what getRate returns and whether one transaction moves it. | accepted | Returns the redemption amount scaled to WAD. A tick does not move it. A fee credit or rounding can. |
| C3 | members/grok/feedback.md | Fee credit is zero without an existing two-token position. | accepted | The design does not create that position by swapping shareholder target. |
| C4 | members/grok/feedback.md | Split raw balance from the rate-provider reading. | accepted | Same as A6. |
| C5 | members/grok/feedback.md | Do not upgrade a missing design to an impossibility. | accepted | Not established in the settled responses. Not proved impossible. |
| C6 | members/grok/feedback.md | The prior report did not name ICHI. | accepted | It is a reason not to adapt a pool-ratio mint. |
| M1 | members/minimax/feedback.md | State the three mechanisms for the adopted path. | accepted | Same mapping. Moving principal outside the share does not solve pool manipulation generally. |
| M2 | members/minimax/feedback.md | Answer one-transaction movement for the adopted rate. | accepted | Same as C2. |
| M3 | members/minimax/feedback.md | A buffered leg holding this share requires a provider. | accepted | Raw balance is the identity-leg case only. |
| M4 | members/minimax/feedback.md | Do not treat MiniMax's design as impossible. | accepted | It remains a different design, with a live sale preview and the prior mechanisms retained. |
| M5 | members/minimax/feedback.md | The deposit does not deploy fee-earning liquidity. | accepted | Depositor target stays idle backing. |
| M6 | members/minimax/feedback.md | Distinguish fee credits from donations. | accepted | `A` rises only on an authorized path that recognizes an actual target fee delta. |
| M7 | members/minimax/feedback.md | Keep the two breaks visible. | accepted in part | Both limits stay. The fee limit is not labeled as Astra's violation of the brief. |
| K1 | members/kimi/feedback.md | Incomplete fees are the worse break. | accepted as dissent | The final keeps the settled-target pick and records Kimi's weighing. |
| K2 | members/kimi/feedback.md | A no-sale preview is not a violated sale constraint. | accepted as dissent | Carried with Astra's reading. Not used to redefine getRate. |
| K3 | members/kimi/feedback.md | A movable live-sale rate is not a locked-law violation. | accepted | The final does not say that. It does not adopt that rate as the one another hook should trust. |

## Coordinator revisions

| Change | Where applied | Reviewed by members | Label |
| --- | --- | --- | --- |
| Consistent mint and exit ratio, fee synchronization, mandatory assignment, rate formula, mechanism map, and carried dissent | REPORT.md | no | coordinator revision |

The reviewed draft bytes were not edited. Members did not review this final text.

## Missing responses

- Missing initial responses: none
- Missing feedback: none
- Treatment: not approval. Not consensus. Not filled by a later advisory file.

## Unresolved dissent

- Kimi still recommends a price-free in-share join with a slice sale, and weighs a matched deposit as the cheaper break.
- MiniMax still recommends a conservative same-pool mark and an actual withdrawal-and-sale preview. That equation was not re-executed.
- Astra does not accept that a zero-quantity sale breaks the getRate sentence. Grok's stricter label is carried, not attributed to Astra.
- No response established a sponsor or an enforceable fee assignment. That feasibility gap stays open.

## Synthesis attempts

| Logical assignment | Attempt | Task ID | Fresh or continued | Reason | Outcome |
| --- | --- | --- | --- | --- | --- |
| synthesis | 1 | invoking session, not a child task | continued | All four feedback files settled | resolution and REPORT written |

## Limits

- Original responses and feedback files remain unchanged.
- No implementation, reviewed-project tests, installs, or Git actions.
- Agreement among respondents is not a correctness guarantee.
- Inherited permissions are not confinement evidence.
