# Coordinator resolution

## Reviewed draft

- Draft ID: draft-v4-own-vault-spec-20261027-01a177b3-r1
- Path: docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/draft.md
- Fingerprint at review: frozen-file sha256 2e2c595866b5475ba8802496f7606df9dbc5fc7cfef2b46a65175581f6750ea8
- Draft bytes changed after review: no
- Members asked to review: astra, grok, minimax, kimi
- This resolution supersedes stale status lines in the draft: yes

## Participation and identity

- Run ID: v4-own-vault-spec-20261027-01a177b3
- Council kind and result label: full
- Coordinator mode: invoking-agent
- Requested coordinator role and model: invoking session, not a vote
- Actual coordinator role, model, reasoning, task ID, and session ID: invoking session; model not exposed; task ID none; session 01a177b3-f4ed-7770-9633-b5735573eb05
- Coordinator fresh or continued: continued
- Coordinator logical assignment and attempt count: v4-own-vault-spec-20261027-01a177b3/coordinator/synthesis, attempt 1
- Owner or root session ID: 01a177b3-f4ed-7770-9633-b5735573eb05
- Identity source: PI_SESSION_ID and task host completion notices

Grok `st_01a17cf7` and MiniMax `st_01a17cf8` returned a transport error, "child turn produced no assistant output," after writing complete feedback files. Those files are the feedback. No retry was issued, because a retry could overwrite a complete file. The error is not a missing review.

## Feedback disposition

| Label | Feedback path | Draft ID named by member | Disposition | Initial response present |
| --- | --- | --- | --- | --- |
| astra | members/astra/feedback.md | draft-v4-own-vault-spec-20261027-01a177b3-r1 | requested-changes | yes |
| grok | members/grok/feedback.md | draft-v4-own-vault-spec-20261027-01a177b3-r1 | requested-changes | yes |
| minimax | members/minimax/feedback.md | draft-v4-own-vault-spec-20261027-01a177b3-r1 | support-with-reservations | yes |
| kimi | members/kimi/feedback.md | draft-v4-own-vault-spec-20261027-01a177b3-r1 | support-with-reservations | yes |

## Concern map

| Concern ID | Source | Concern | Disposition | Reason |
| --- | --- | --- | --- | --- |
| C1 | members/astra/feedback.md | The rejected basket is fee funding and attached fees, not a different mint equation | accepted | The final says so. The mint equation stays the re-read V2 form. |
| C2 | members/astra/feedback.md | Account-specific fees cannot be one anonymous getRate | accepted | Historical fees are detached. getRate matches the shares-only exit and includes no average fee claim. |
| C3 | members/astra/feedback.md | Per-collection dust overlaps later index liability | accepted | The final drops the permanent dust ledger. Remainder is collected minus current liability. |
| C4 | members/astra/feedback.md | Transfer can orphan unclaimed, and custody was mixed with principal | accepted | Sync-before-transfer, unclaimed stays with the sender, claimFees pays escrow in kind, debt updates after burn. |
| C5 | members/astra/feedback.md | Offset can leave liquidity after the last burn | accepted | Residual stays in U. It is not swept. The exit equation is not changed. Later deposits use that U as the denominator. |
| C6 | members/astra/feedback.md | Sale preview must follow removal; hook domain and revert set were incomplete | accepted | Sequential preview, named reverts, hookless or non-altering hook only. |
| C7 | members/astra/feedback.md | Profitless round trip was too strong | accepted | Replaced by the fixed-state liquidity inequality. |
| C8 | members/astra/feedback.md | Callback and deposit bounds were incomplete | accepted | Armed callback binds the operation. minShares is required. Unexpected liquidity delta reverts. |
| G-1 | members/grok/feedback.md | Item 12 claimed a profitless target round trip | accepted | Deleted. Same replacement as C7. |
| G-2 | members/grok/feedback.md | getRate fee claim was undefined; asked for aggregate F/S | rejected in part | Revert set, Floor, and the ban on shares times getRate are accepted. Aggregate F/S inside getRate is rejected because it invents the average Astra's counterexample forbids. |
| G-3 | members/grok/feedback.md | Unspecified in-kind exit | accepted | Deleted. A failed target exit must not fall back to in-kind. |
| G-4 | members/grok/feedback.md | Assigning U from observed liquidity absorbs strangers | accepted | U moves only by uReceived or uOut, then the position is checked. |
| G-5 | members/grok/feedback.md | Q and zero-mint were unnamed | accepted | Q is 2^128. Zero mint and a caller minShares bound revert. |
| A1 | members/minimax/feedback.md | Partial exit can strand unclaimed | accepted | Share exit does not pay unclaimed. claimFees pays it. Transfer crystallizes to the sender first. |
| A2 | members/minimax/feedback.md | Name the collection operation | accepted | Zero-liquidity modifyLiquidity, feesAccrued separate from principal, deltas settled before return. |
| A3 | members/minimax/feedback.md | Callback owner should be a source observation | accepted | Coordinator re-read PoolManager.unlock and modifyLiquidity. |
| A4 | members/minimax/feedback.md | Add delta settlement and incumbent non-dilution tests | accepted | Added as test requirements, not as a proved identity. |
| K1 | members/kimi/feedback.md | Removal proceeds must not fund the fee claim | accepted | Escrow pays fees. Removal principal is separate. The exit does not sell fee escrow. |
| K2 | members/kimi/feedback.md | Say what an external zap in front of the vault is | accepted | One sentence. It is outside the vault and must not become a vault swap. |
| K3 | members/kimi/feedback.md | Verify fee collection against admitted V4 sources | accepted | The final cites the re-read PoolManager lines and forbids filling the gap from excluded source. |

## Coordinator revisions

| Change | Where applied | Reviewed by members | Label |
| --- | --- | --- | --- |
| Detached fee escrow, shares-only getRate, claimFees, remainder conservation, residual lifecycle, sequential quote, Q, U update rule, collection operation, hook domain | REPORT.md Conclusions | no | coordinator revision |

The reviewed draft bytes were not changed. Members did not review this final text.

## Missing responses

- Missing initial responses: none
- Missing feedback: none. Grok and MiniMax files are present. Their task status error is recorded above and is not absence.
- Treatment: not approval. Not consensus. Not filled by a later advisory file.

## Unresolved dissent

- Astra still prefers attached fungible fees funded in kind at admission. The final does not adopt that join. Her consistency objection is accepted by detaching fees instead.
- Kimi still prefers compounding fees into liquidity units. Not adopted.
- Kimi and MiniMax still prefer a separate single-token zap route inside the vault. Not adopted. Their non-claim is kept as a condition on any later addition.
- Grok's aggregate `floor(oneShare * F_i / S)` inside getRate is not adopted. The revert and Floor parts of G-2 are.

## Synthesis attempts

| Logical assignment | Attempt | Task ID | Fresh or continued | Reason | Outcome |
| --- | --- | --- | --- | --- | --- |
| v4-own-vault-spec-20261027-01a177b3/coordinator/synthesis | 1 | none | continued | synthesis | draft frozen, then this resolution and the final |

## Limits

- Original responses and feedback files remain unchanged.
- No implementation, reviewed-project tests, installs, or Git actions.
- Agreement among respondents is not a correctness guarantee.
- This resolution does not authorize implementation.
