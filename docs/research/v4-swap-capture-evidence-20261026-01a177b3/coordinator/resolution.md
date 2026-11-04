# Coordinator resolution

## Reviewed draft

- Draft ID: draft-v4-swap-capture-evidence-20261026-01a177b3-r1
- Path: docs/research/v4-swap-capture-evidence-20261026-01a177b3/coordinator/draft.md
- Fingerprint at review: sha256 1813119f975b657c0214503b252bd9760f6d815f5305747c473f6baeaa078efe
- Draft bytes changed after review: no
- Members asked to review: astra, grok, minimax, kimi
- This resolution supersedes stale status lines in the draft: yes

## Participation and identity

- Run ID: v4-swap-capture-evidence-20261026-01a177b3
- Council kind and result label: full council, full
- Coordinator mode: invoking-agent
- Requested coordinator role and model: invoking session, not a vote; no separate coordinator model
- Actual coordinator role, model, reasoning, task ID, and session ID: invoking session 01a177b3-f4ed-7770-9633-b5735573eb05. Not a child task. Exposed labels during the run were PI_MODEL=gpt-6.1-sol in one eval kernel and a session persona naming Grok 4.7. After compaction the restored model label was grok-4.7. Those labels are not two votes.
- Coordinator fresh or continued: continued
- Coordinator logical assignment and attempt count: synthesis, attempt 1
- Owner or root session ID: 01a177b3-f4ed-7770-9633-b5735573eb05
- Identity source: Native session and task records in RUN.md. Model prose is not the identity source.

## Feedback disposition

| Label | Feedback path | Draft ID named by member | Disposition | Initial response present |
| --- | --- | --- | --- | --- |
| astra | members/astra/feedback.md | draft-v4-swap-capture-evidence-20261026-01a177b3-r1 | requested-changes | yes |
| grok | members/grok/feedback.md | draft-v4-swap-capture-evidence-20261026-01a177b3-r1 | requested-changes | yes |
| minimax | members/minimax/feedback.md | draft-v4-swap-capture-evidence-20261026-01a177b3-r1 | support-with-reservations | yes |
| kimi | members/kimi/feedback.md | draft-v4-swap-capture-evidence-20261026-01a177b3-r1 | support-with-reservations | yes |

## Concern map

| Concern ID | Source | Concern | Disposition | Reason |
| --- | --- | --- | --- | --- |
| G1 | members/grok/feedback.md | Quote-retained payout and slice-sale payout were blended. | accepted | The final splits them. A slice sale is not `floor(shares * V / supply)`. |
| G2 | members/grok/feedback.md | The fee-aware collapse was used as if it defined vault-as-LP self-fill. | accepted | Rechecked `fee_aware_residual()`: mark `1631805416248746237`, liquidation quote `1434680630207761058`, gap `197124786040985179`. The identity is kept only for a vault-initiated swap that retains its output. |
| G3 | members/grok/feedback.md | `+1179070738173910` was called production-shaped without its domain. | accepted | The final attaches sleeve-sufficient idle book, one range, not a Wings lifecycle. |
| G4 | members/grok/feedback.md | The draft said conservation failed because of 2 wei dust. | accepted | The final says 2 wei of pool-versus-claim dust. Token totals were conserved. The row is still not an exact witness. |
| G5 | members/grok/feedback.md | `2.488187224469637` was printed as if it were the exact power. | accepted | The final labels it as Kimi's program print. The rate-limit claim does not depend on the tail. |
| C1 | members/minimax/feedback.md | Fee and inventory cutoffs were missing for every rule. | accepted in part | The final states a cutoff for each rule. MiniMax's numerical roots stay instance-specific. They are not a general safety threshold. |
| C2 | members/minimax/feedback.md | The `+25.472084e18` and `+30.508645e18` rows are not printed by the shipped `model.py`. | accepted | Those rows stay member-reported transcript arithmetic. They are not in the rechecked table. |
| C3 | members/minimax/feedback.md | Rechecked rows mixed mechanisms without labels. | accepted | The final labels quote manipulation, mint/exit price mismatch with no prior manipulation, and vault self-fill. MiniMax's idle row is the second. It is not a rerun of the audited finding. |
| C4 | members/minimax/feedback.md | Rule 3 did not define `A_T` and `A_O`. | accepted | Those symbols mean booked idle, removable principal, and uncollected fees unless a row says idle-only. |
| C5 | members/minimax/feedback.md | `psi = 1` was attributed to MiniMax. | accepted | MiniMax reported 0, 0.25, 0.50, and 0.75. The full-ownership call is coordinator execution of their function, and external depth is then zero. |
| C6 | members/minimax/feedback.md | The collapse omitted an LP-dependent fee term. | accepted as a limit | The collapse is not general. `A_T + p_exec*A_O - f*s` is not adopted as a rechecked identity. |
| C7 | members/minimax/feedback.md | The idle-opposing row lacked a closed attacker ledger. | accepted in part | The rechecked closure is both tokens closed, opposing 0, profit the exact fraction. The `2.379517` incumbent split stays member-reported. |
| C8 | members/minimax/feedback.md | A scalar minimum over incommensurable components is not well defined. | accepted | The proportional rule in the final is a per-component vector with in-kind refunds. |
| ASTRA-A1 | members/astra/feedback.md | Untraded-inventory extrapolation was stated as the necessary cause of every row. | accepted | Astra's zero-old-opposing witness has denominator 100 target regardless of `p_exec`. The final keeps that counterexample and separates the mechanisms. |
| ASTRA-A2 | members/astra/feedback.md | Mint and payout equations, gross versus net price, and TWAP gates were underspecified. | accepted | The final states the split equations and limits the collapse. Gate timing beyond the source read remains unresolved. |
| ASTRA-A3 | members/astra/feedback.md | The report must contain one complete ledger, not only the word closed. | accepted in part | The final includes the rechecked 100-target ledger. Other retained rows cite an artifact. A rounded profit alone is not treated as a closed ledger. |
| ASTRA-A4 | members/astra/feedback.md | The per-component invariant was left as an unresolved post-sale disagreement. | accepted | The invariant is at acceptance, before the sale. Remaining liquidity can fill the sale. Kimi's stronger post-sale claim stays dissent. |
| ASTRA-A5 | members/astra/feedback.md | Some numbers lacked units. The fee fraction is a final wallet, not profit. | accepted | Net profit on that row is `482040473/99880180`. The 60.44 and 22.18 figures are net target profit on a 200 deposit. |
| ASTRA-A6 | members/astra/feedback.md | The vector-rule sentence could be read as an exclusivity theorem. | accepted | The final says this rule supplies the demonstrated invariant. It does not say it is the only safe rule. |
| ASTRA-A7 | members/astra/feedback.md | In-kind repayment was treated as if it settled funding availability. | accepted | Repayment route and initial opposing capital stay separate. |
| KF-1 | members/kimi/feedback.md | The rounding remark about `3,128,200,000` is stale. | accepted | The current response says `+3,128,158,354.82`. The model print rechecked earlier was `3128158354.8193827`. The defect claim is withdrawn. |
| KF-2 | members/kimi/feedback.md | Zero-valuation of unsold opposing is sufficient but not necessary. | accepted in part | The mechanism wording is widened. `+15068798773.084002` is member-reported advisory arithmetic, not a coordinator re-execution. |
| KF-3 | members/kimi/feedback.md | The collapse omitted retained deposit `D`. | accepted in part | `(A_T + D - alpha*D) + p_exec*(A_O + delta_O) = A_T + D + p_exec*A_O` is the combined retained book. It includes `D`. It is not the issuance denominator that excludes the new credit. |

## Coordinator revisions

| Change | Where applied | Reviewed by members | Label |
| --- | --- | --- | --- |
| Split quote payout from slice-sale payout; attach domains; label mechanisms; correct units; qualify the fee-aware identity; carry dissent | REPORT.md | no | coordinator revision |

The reviewed draft bytes were not edited. Members did not review this final text.

## Missing responses

- Missing initial responses: none
- Missing feedback: none
- Treatment: not approval. Not consensus. Not filled by a later advisory file.

## Unresolved dissent

- MiniMax's single-range reduction is negative when the vault is the LP. The coordinator interval ledger is positive at half and full ownership under its own rule. Both rows stay. Neither is averaged into the other.
- Kimi maintains that the price-free vector rule eliminates the extraction channel inside the stated domain, and that a slice sale does not change other holders' per-component claims. The final adopts the narrower claim: the rule removes the pool-price conversion and the acceptance-time ownership distortion. It does not adopt post-sale immunity. Astra's pre-sale invariant is the adopted statement.
- Kimi's first-order boundary `alpha = omega`, MiniMax's instance root, and the coordinator 49/50/51 grid are different machines. A fixed 49/50/51 split is not a threshold. No row is used to rebut another row from a different machine.
- MiniMax does not adopt Kimi's rule-4 elimination claim, Grok's dusted self-fill row, or the coordinator sign as a resolution of the LP-share disagreement. Those non-adoptions are preserved.

## Synthesis attempts

| Logical assignment | Attempt | Task ID | Fresh or continued | Reason | Outcome |
| --- | --- | --- | --- | --- | --- |
| synthesis | 1 | invoking session, not a child task | continued | All four feedback files settled | resolution and REPORT written |

## Limits

- Original responses and feedback files remain unchanged.
- No implementation, reviewed-project tests, installs, or Git actions.
- Agreement among respondents is not a correctness guarantee.
- Inherited permissions are not confinement evidence.
