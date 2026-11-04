# Coordinator resolution

## Reviewed draft

- Draft ID: draft-v4-wings-complete-design-20261025-01a171a0-r1.
- Path: coordinator/draft.md.
- Fingerprint: not computed.
- Draft bytes changed after review: no.
- All four independent originals and all four advisory turns settled. No second debate/review round was launched.
- This resolution supersedes the draft's pending-review status, not its preserved text.
- Final: ../REPORT.md, coordinator revision after advisory feedback, not newly member-approved wording.

## Participation and identity

- Full research council, invoking-agent coordination; the coordinator is not an independent vote.
- Owner/root: 01a171a0-0d64-7a6c-b2a0-834fc1e0e7f7.
- Native routes, task/session IDs and reasoning metadata: ../RUN.md. Same task IDs were continued at epoch 1 for feedback.
- Actual coordinator model exposed in session environment: gpt-6.1-sol; reasoning/provider route not exposed there.
- Synthesis assignment: this run's coordinator/synthesis, attempt 1. No replacement or provider fallback.

## Feedback disposition

| Member | Feedback artifact | Disposition on r1 | Initial present |
| --- | --- | --- | --- |
| Astra | ../members/astra/feedback.md | requested-changes | yes |
| Grok | received-feedback/grok.md | requested-changes | yes |
| MiniMax | received-feedback/minimax.md | support-with-reservations | yes |
| Kimi | received-feedback/kimi.md | support-with-reservations | yes |

Three feedback artifacts are coordinator-preserved inline receipts because those members lacked project-scoped apply_patch. Their originals and feedback content are preserved without rewriting. Initial creation-method deviations are disclosed in RUN.md.

## Concern map

Each original concern is covered below; suffixes split a useful request from an incorrect mathematical or source premise. Accepted corrections appear in REPORT.md. Rejected claims remain visible in the original receipts.

| Concern | Disposition | Resolution / final location |
| --- | --- | --- |
| ASTRA-AF-01 | accepted | Use net-owned equity locals; define entrant available=funding+retained idle+refund. Contribution contains retained idle, with NO second refund/liability subtraction. Sections 2-4 and validation. |
| ASTRA-AF-02 | accepted | Distinguish whole-token normalized rate from raw-unit SY conversion. Give exact formulas, 18-share/6-target example, correct assetInfo, stale/empty behavior and integration gate. Section 8. |
| ASTRA-AF-03 | accepted | Every communal placement, including plain compounding into an unchanged range, uses a fresh fixed reference and cumulative loss policy. Budget shrinks with withdrawals and has a current-equity action cap. Section 7. |
| ASTRA-AF-04 | accepted | Explicit initialized/not-busy/manager-locked public-view guard, including projected queries with a live baseline. Internal authenticated accounting is not a public-view bypass. Sections 4, 8 and 11. |
| ASTRA-AF-05 | accepted | Reject all-zero ordinary payout and positive-supply/nonpositive-reference-equity issuance. Terminal extraction uses actual full equity. No silent abandonment branch. Sections 5-6. |
| G-1 | accepted | Funded increments explicitly mean deltaL at fixed bounds valued at frozen reference; live principal is token funding/custody math. No gross-tray credit followed by communal allocation loss. Sections 3-4. |
| G-2 | accepted | Final old-fee checkpoint after entrant swap; principal funding charged in full to entrant; returned fees belong to old equity and never rebate entrant principal. Growth/delta/custody reconciliation added. Sections 3-4. |
| G-3 | accepted | Same explicit public economic-view guard as ASTRA-AF-04; no foreign-unlock projection exception. Sections 8 and 11. |
| G-4a | accepted | Correct normalization and final credited bootstrap C>=one-target accounting unit ensures supply>=one whole 18-decimal share. Later sub-one-share states remain unavailable. Sections 5 and 8. |
| G-4b | rejected | The requested normalized NAV formula is NOT the raw-unit SY exchangeRate formula in local SYUtils. Adopt Astra's source-verified raw SY contract instead; give both separately. Section 8. |
| G-5 | accepted | Terminal pays shareholder equity only. Simplify zero-supply surplus: clean it to a fixed recipient BEFORE bootstrap, so it never becomes a senior live-vault claim. Pin donation observation/cut and reject unexplained in-flight deltas. Sections 2, 5-6. |
| G-6 | accepted | All actual additions/removals use live math. Only reference/epoch policy defines wing bounds; bootstrap is an explicit first-creation phase, later entry does not invent live-spot ranges. Section 7. |
| K1 | accepted | Choose explicit ineligibility, not synthetic getRate. Current D60 fresh-buffer convention is NOT preserved for canonical execution rates. Supply>=one-share is necessary but not sufficient; quote availability and safe pricing must also be proved. Sections 8, 10 and change table. |
| K2 | accepted | Add consolidated expectation-change table including liveness, empty rate, decimals/SY, exact-output, foreign unlock, sleeve/floor, surplus and reference eligibility. Section 12. |
| K3 | accepted | Explicit owner-acceptance tradeoff: in-kind is the quote-independent exit, target conversion/getRate may fail. No APEX-026 closure claim. Sections 1, 6, 9 and 12. |
| K4 | accepted | Reference outage stops issuance and every placement/re-range; existing wings remain, fees can be collected idle, in-kind remains. No unrotated-wing auto-sale. Sections 7 and 10. |
| K5 | accepted | Name entry-cap griefing and the exposure-versus-entry-liveness parameter choice. Section 10. |
| K6 | accepted | Explicit reference/live boundary-straddling tests, both directions, deviation edges and both target orientations. Section 13. |
| C-MIN-01a | accepted | State C is final reference mark increment, NOT outlay value. Show available/funding/idle/refund and outlay-versus-credit separately in preview/conservation. Sections 3-4. |
| C-MIN-01b | rejected | The asserted full-range gap and claim that final-increment credit necessarily charges existing holders are incorrect. Keeping C at final mark preserves old reference equity; adding an outlay shortfall back into C would subsidize the entrant. Correct derivation in section 3. |
| C-MIN-02a | accepted | Fee-growth checkpoints, separate manager principal/fee deltas and real settlement/custody must reconcile; fee-like numbers are never independent proof of input. Sections 3-4. |
| C-MIN-02b | rejected | Recomputing fee growth does not remove donated fee growth. In this hookless manager, actual backed donated fees are valid old equity; neither the informational return nor recomputation may mint caller credit. PoolManager code explicitly adds principal+fees. Reject blanket exclusion of actual fees from A. |
| C-MIN-03a | accepted | Give exact clamped per-range composition gap, conditional band bound and explicit distinction from executable liquidation value. Add both reference-mark and actual-token conservation identities. Section 3. |
| C-MIN-03b | rejected | Claimed gap 2L(1/sqrt(P)-1/sqrt(q)) and a generic whole-value jump at a tiny boundary crossing are not correct. For an unclipped interior range the token1 gap is L(sqrt(q)-sqrt(P))^2/sqrt(q). Outside the gate no small-gap guarantee is made. |
| C-MIN-04 | accepted | Parameterized fee/depth/position/reference matrices and publication of profitable dilution cases are required. Profitable vault-accounting extraction beyond the declared quantum blocks deployment; publication is not permission to accept it. Section 13. |
| C-MIN-05 | accepted | Direct raw-getRate parity/buffer registration is ineligible without a separately validated failure/valuation contract. Zero/sub-one-share and quote failure can freeze consumers. Sections 8, 10 and 12. |
| C-MIN-06a | accepted | Explicit canonical whole-target/whole-share WAD units; distinguish normalized NAV, SY raw conversion and legacy vault raw expression. Section 8. |
| C-MIN-06b | rejected | Existing StandardExchangeRateProviderFacet._normalise ALREADY implements the same whole-token normalized scale: out*10^(18+dS-dT)/shares. Its quote size/source and ceil rounding differ, not a claimed 10^12 unit factor. Source and exact arithmetic checked. |
| C-MIN-07a | accepted | Internal held-share consumption must be operation-bound and authenticated; public pretransfer/internalBalance=true shortcuts are not preserved. Exact-output push-budget/refund helpers are not a supported first-release route. Sections 4 and 8. |
| C-MIN-07b | rejected | Existing LocalCreditLib proves only that caller has bytecode, not a self-call or payer identity. NativeStandardYieldTarget.redeem calls the internal hook with original msg.sender; do not describe current behavior as already self-authenticated. Source-checked; no new audit finding claimed. |
| C-MIN-08 | accepted | Remove ongoing senior surplus payable by mandatory empty-state cleanup; name O1/O3/O5/O7 changes. Define W=10^36 target accounting units and relative epsilon plus Q_W, not a raw-token tolerance. Sections 2, 5 and 12. |
| C-MIN-09 | accepted | Reference-derived empty wing records/first funding at bootstrap; epoch-gated later creation/replacement. Define absolute target-accounting epoch budget, no gain replenishment, withdrawal reduction and current-equity cap. Section 7. |
| C-MIN-10 | accepted | Separate preview work exhaustion, actual execution gas and insufficient market depth. Default specified swap executes without first running the quote walker. Tick-spacing/finite-limit worst-case feasibility and full gas gates are deployment prerequisites. Section 9. |
| C-MIN-11a | accepted | Explicit public-view behavior and first-release integration eligibility. Same-manager nested redemption is not supported. Sections 8 and 11. |
| C-MIN-11b | rejected | Redemption outside an outer unlock need not mean two transactions. A router may complete one vault-owned manager session, then open another session sequentially in the SAME atomic transaction. Such a route is still unimplemented/unvalidated here. |
| C-MIN-12a | accepted | Explicit N_after=A+C and token custody/tray conservation, with integer error intervals. Sections 3-4 and 13. |
| C-MIN-12b | rejected | The proposed actual-token identity omits old positions' composition gap. Correct identities are M_after=M_old_at_cut+M(E;q,P) and M=N+sum(G_j), within the stated integer quantum; actual funding outlay also carries addition/removal rounding. Use the same cut, price and ownership with fees counted once. Section 3. |

## Independent checks supporting disputed resolutions

These are coordinator exact arithmetic/derivations, NOT project tests or a pool simulation.

1. With L=1, sqrt bounds [1/2,2], reference P=1 and live q=9/4: reference range value is 1 target1, actual tokens marked at P are 7/6, so gap is 1/6. The feedback's proposed formula gives 2/3. The exact clamped formula gives 1/6.
2. With share decimals 18, target decimals 6, q=10^18 and output=10^6 target atoms: canonical normalized rate and existing generic adapter normalization both equal 10^18. Raw-unit SY rate equals 10^6 and converts 10^18 raw shares to 10^6 target atoms.
3. Local SYUtils actually uses syRaw*rate/10^18. NativeStandardYieldTarget's held-share branch calls an internal function after a contract-bytecode check, not a proved self-caller check. LSP references timed out; the actual source files were then read directly.
4. The conditional range-gap bound is derived from the LP curve's dY=-price*dX and checked clamped formulas, not from a provider claim. The final states its domain and integer-error caveat.

## Coordinator revisions

All final clarifications and corrections are coordinator revisions after the one reviewed r1 draft. They were not submitted to a second member pass and must not be labeled member-approved final text.

- Net accounting partitions and exact refund treatment.
- Reference/outlay/composition-gap definitions, corrected arithmetic and bounded-state meaning.
- Raw SY versus whole-token normalized rates and mixed-decimal examples.
- Stronger all-placement maintenance policy, bootstrap wings and shrinking budgets.
- Explicit empty/dust/zero-equity/foreign-unlock/SY/pretransfer contracts.
- Explicit donation cleanup, requirement changes, entry-cap griefing and integration limitations.
- Expanded pass/fail and boundary/consumer validation gates.

## Missing responses and dissent

- Missing initial responses: none.
- Missing advisory feedback: none.
- Requested-changes dispositions are preserved, not relabeled approvals.
- All four feedback responses support the broad architecture with corrections; that is not a security proof or endorsement of final wording.
- Remaining tradeoff dissent: arbitrary-pair coverage versus independent-reference trust; refund/proportional or separate-claim alternatives for unsupported pairs. Original decimal/maintenance preferences remain documented even where not selected.
- No test, build, PoC, oracle availability or live deployment check was run. No finding is closed.
- No further round is required or authorized by this resolution. Implementation requires a separate request.
