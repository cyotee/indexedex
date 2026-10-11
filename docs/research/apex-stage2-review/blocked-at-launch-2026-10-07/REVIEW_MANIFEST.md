# Stage 2 review manifest

Report state: `BLOCKED_AT_LAUNCH`

Date: 2026-10-07

This file records a launch attempt that failed Step 0 of `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md`. No reviewer assignments started. No source, test, configuration, or instruction files were edited. No builds, tests, forks, shell commands, Git commands, or hash computations were run.

## Owner Stage-1 satisfaction reference

Not recorded.

The launch message was: "Please execute the plan in /Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md".

That message is a request to execute the plan. It does not unambiguously record satisfaction with Stage-1 results. S2-REQ-01 and plan Step 0 require both decisions to be unambiguous. Satisfaction is not implied by a request to write the plan, and it is not stated in this execute request.

`docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md` is an implementer evidence note. It does not contain an owner acceptance. Its own text says Stage 1 passing is not audit submission and that Stage 2 has not started.

## Separate launch request reference

Present, but incomplete for fan-out.

- Request: the message quoted above, 2026-10-07.
- Named source: absent. The message does not name an IndexedEx revision, a Crane revision, a dirty-tree content identity, or an immutable snapshot.

## Selected snapshot / IndexedEx / Crane / dirty-source identity

Not established. Fan-out is blocked.

The Stage-1 note cites tree `5709cb35` plus uncommitted stage-1 edits and says that note is not a release identity (`STAGE1_EVIDENCE.md:4`). This coordinator did not rerun Git, shell, or hash commands, and did not invent a current hash or infer that the working tree is still that identity.

Required before any assignment:

- IndexedEx revision.
- Crane revision and dependency identity, as supplied by the operator.
- Tracked modifications and relevant untracked source/test files, with supplied content identity or an immutable snapshot reference. HEAD alone is not enough if the tree is dirty.

## Evidence manifest and authority-document versions

Inputs located, not accepted as a cleared gate:

| Input | Path | Launch use |
| --- | --- | --- |
| Controlling PRD | `docs/plans/APEX_STAGE2_REVIEW_PRD.md` | Read. Draft status. Does not itself authorize execution. |
| Controlling plan | `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md` | Read. Step 0 controls this attempt. |
| Stage-1 remediation PRD | `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` | Located. OD-01–OD-08 recorded in that file as of 2026-10-06. Not re-reviewed for code compliance in this blocked launch. |
| Stage-1 plan | `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.plan.md` | Located. Says Stage 2 starts only after owner satisfaction with Stage 1, by a separate request. |
| Stage-1 evidence note | `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md` | Present. Bound to a non-release identity. |
| Selector/size artifact | `docs/reviews/apex-2026-09-17-second-audit-readiness/selector-size-compare-stage1-current.json` | Present in the evidence directory. Not re-executed. Earlier compare files in that directory are labeled stale by the evidence note. |

Authority documents and family PRDs were not inventoried for assignment because fan-out did not start.

## Stage-1 note and four outside-trade test references

The evidence note names these tests. Presence in the note is not a rerun and is not owner acceptance.

| Vault | Test name cited by the note | File cited by the note |
| --- | --- | --- |
| V3 FullSpread | `test_outsidePoolTradeDoesNotRefreshVaultBook` | `UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol` |
| V4 hookless FullSpread | same test name | `hookless/AttributionAndBooking.t.sol` |
| V4 Pons-family FullSpread | same test name | `ponsFamilyV2Hook/AttributionAndBooking.t.sol` |
| Wings | same test name | `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol` |

The note also says `UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol` is a local-reserve supplement, not the outside-trade proof.

## Stage-1 source-map / build / selector / size / regression evidence

Present as supplied narrative and one selector/size artifact. Not rerun.

- Source map: hookless and Pons-family packages listed as not merged (`STAGE1_EVIDENCE.md:7–16`).
- Named regression narrative: custody, receipt-cap, rate-provider, residual-sweep, outside-trade, and rounding tests listed as passed (`STAGE1_EVIDENCE.md:26–37`). No command log, toolchain version, or source-bound transcript was attached beyond that narrative.
- Selector/size: the note says `python3 scripts/r12_selector_size_compare.py` wrote `selector-size-compare-stage1-current.json` and exited 0. This launch did not open that JSON to recompute counts and did not rerun the script.
- Disclosed limitation in the note, not repaired here: `scripts/apex_bare_expectrevert_scan.sh --check` is reported to exit 1 because the wider inventory still has pre-existing bare expectations (`STAGE1_EVIDENCE.md:60`). That is a Stage-1 disclosure for the owner to accept or reject. This review did not complete Stage 1 and did not run the scanner.

No matrix row count is recorded in the Stage-1 note. This launch did not adopt 195/1/7 or 165/3/7.

## Authorized coordinator mechanism / actual limits / write root

- Coordinator: this Sisyphus session, not the research council and not the review council.
- Write root used for this blocker only: `docs/research/apex-stage2-review/blocked-at-launch-2026-10-07/`. The label is a run identifier, not a source hash.
- Delegation mechanism available, not used: the session `task` tool can start independent subagents with background execution so substantive reviews can overlap. Exact concurrency limit, scheduler event schema, and model roster were not invented and were not measured, because no assignment was launched.
- Not used as a substitute: `docs/agent/RESEARCH_COUNCIL.md` describes a synchronous fixed roster. `docs/agent/REVIEW_COUNCIL.md:57–62` permits synchronous sequential calls and `:98–106` denies background tools. Neither profile was treated as this program's executor.
- S2-AC-02 is not satisfied. Capability was not exercised. No concurrent review occurred.

## Assignments

None. Step 0 failure forbids reviewer assignment.

## Concurrency events

None.

## Original freeze index

None. No originals exist for this run.

## Incidents, source drift and owner decisions

| Event | Evidence | Affected rows | Required action | Disposition |
| --- | --- | --- | --- | --- |
| Launch attempted without recorded Stage-1 satisfaction | Execute request quoted above; no satisfaction sentence in that message or in `STAGE1_EVIDENCE.md` | All Stage-2 coverage | Owner records satisfaction, or withholds it | `BLOCKED_AT_LAUNCH` |
| Launch attempted without a named source identity | Execute request names the plan path only. Stage-1 note identity is explicitly not a release identity | All Stage-2 coverage | Operator supplies IndexedEx revision, Crane revision, and dirty-tree or immutable snapshot identity | `BLOCKED_AT_LAUNCH` |
| Current tree identity not computed | Plan and PRD forbid Git/shell/hash commands for this review | Snapshot manifest | Do not infer identity from the 2026-10-07 note | Left unresolved on purpose |

## What this file is not

- Not an inspection of source or tests.
- Not a criterion, audit, or matrix ledger.
- Not a finding that Stage 1 failed or that any contract is defective.
- Not a remediation PRD.
- Not permission to submit an audit.
