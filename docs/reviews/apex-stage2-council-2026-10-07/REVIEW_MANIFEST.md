# Stage 2 review manifest — review-council execution

Report state: `PARTIAL_REPORT`

Date: 2026-10-07

This file is the review-council coordinator record for the owner request to execute `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md`. It does not overwrite historical run roots.

## Authorization

Owner Stage-1 satisfaction and Stage-2 launch authorization are already recorded in the controlling plan, PRD, and `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md`. This session does not re-ask. The continuation manifest at `docs/research/apex-stage2-review/recurrence-20261007/REVIEW_MANIFEST.md` says the owner also required a repository-wide recurrence review and authorized local builds, tests, and evidence generation for that continuation. Production remediation and deployment remain outside scope.

## Runtime compatibility — this session

Coordinator role: Grok 4.7 review-council coordinator (`xai/grok-4.7`). Delegation is limited to `review-council-astra`, `review-council-grok`, `review-council-minimax`, and `review-council-kimi`. Every task call must use `run_in_background: false`. `docs/agent/REVIEW_COUNCIL.md` denies background tools and shell.

Consequences, not workarounds:

- Genuine background parallelism is not available. Four first passes may be requested in one coordinator turn. Overlap is not claimed unless the returned sessions show it. S2-AC-02 is not pre-satisfied.
- This session cannot run Git, hash, Forge, builds, tests, forks, or RPC. The continuation's execution authorization does not override that runtime bound. Supplied evidence is inspected, not rerun.
- Native collaboration sessions from `docs/research/apex-stage2-review/accepted-20261007/` are not review-council sessions. They are not resumed and are not impersonated. This wave is a new roster, labeled as such, not continuity of `/root/vaults`, `/root/credit_lending`, or `/root/hooks_matrix`.

## Write-root substitution

Plan default root is `docs/research/apex-stage2-review/<label>/`. This coordinator's permitted Markdown root is `docs/reviews/` and `reviews/`. Authorized substitution for this wave: `docs/reviews/apex-stage2-council-2026-10-07/`. Historical research artifacts are read-only inputs.

## Source identity

Not recomputed in this session. Last supplied identity, from `docs/research/apex-stage2-review/recurrence-20261007/evidence/source-before-build.json`:

- Captured: 2026-10-07T20:54:31.547025+00:00
- IndexedEx revision: `5709cb3507a9df72b11ec476d27b79ef88696c3a`
- Crane revision: `b35609951b4951a3c107e267e22844a50c4dc043`
- Content hash: `82e1f83932a7149cacb7269cdcf90001541cc31306f54407e8037a6597eb5c32`

`evidence/full-build.log` contains only `Compiling 1862 files with Solc 0.8.35`. That is not a completed build. `evidence/forge-version.txt` reports forge 1.5.1-stable, commit `b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`. Neither is a passing test result.

Recurrence test files such as `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol` exist. They are source drift relative to the accepted inspection snapshot and were not executed by this session.

Accepted first-wave identity remains separately labeled: content hash `379d2c49ead26ad701503c419ca486ddcd0ae9158e2d879f9f0720129c721439` over 15,552 files, report state `PARTIAL_REPORT`.

## Assignments

| Assignment | Reviewer | Primary coverage | Original path | Cross path |
| --- | --- | --- | --- | --- |
| A-vaults | review-council-astra | C02–C05; four vault identities | `reviewers/astra-vaults-original.md` | `reviewers/astra-vaults-cross.md` |
| B-credit | review-council-grok | C06–C08 | `reviewers/grok-credit-original.md` | `reviewers/grok-credit-cross.md` |
| C-hooks | review-council-minimax | C09–C11 | `reviewers/minimax-hooks-original.md` | `reviewers/minimax-hooks-cross.md` |
| D-detf-release | review-council-kimi | C01, C12, C13; Stage-1 REQ-01–08 continuity | `reviewers/kimi-detf-release-original.md` | `reviewers/kimi-detf-release-cross.md` |

Paths are relative to this directory. First passes must not read these reviewer outputs. Historical research reports are untrusted prior-wave claims.

## Concurrency events

First four task calls were issued together in one coordinator turn, each with `run_in_background: false`. All four poll-timed out at 1,800,000 ms. That is not scheduler proof of overlapping substantive review. S2-AC-02 is unmet.

| Assignment | Session | Result |
| --- | --- | --- |
| A-vaults / Astra | `ses_ee7c3c41effeYQYXPCEIvWJJVS` | Original file written. Return timed out. Not censorship. No resubmission. |
| B-credit / Grok | `ses_ee7c39bfdffe3UuuuiBqYNZZ7f` | Original collected after one resume. |
| C-hooks / MiniMax | `ses_ee7c378ebffeUmQNGUktYmxqXU` | Initial call and one resume both timed out. No file. Not replaced. |
| D-detf-release / Kimi | `ses_ee7c34ec4ffeOABWPSUENRQSF2` | Original collected after one resume. |

## Original freeze index

Preserved originals: `reviewers/astra-vaults-original.md`, `reviewers/grok-credit-original.md`, `reviewers/kimi-detf-release-original.md`. No cross-review packet was sent. MiniMax has no original. Report state is `PARTIAL_REPORT`.

## Incidents

| Event | Evidence | Required action |
| --- | --- | --- |
| Background concurrency denied | Review-council protocol; `run_in_background: false` required | Record actual call pattern; do not call serial work parallel |
| Builds/tests denied | Coordinator hard rule; incomplete `full-build.log` | Do not rerun; keep execution evidence `MISSING` or historical |
| New roster | Prior native sessions are not this protocol's sessions | Label this wave separately; no impersonation |
| MiniMax failure | Two poll timeouts; no original file | Stop the round. Do not impersonate. Leave C09–C11 uninspected |
| Plan versus role deliverable | Plan forbids automatic remediation PRD; review-council role requires a DRAFT handoff | Write `REMEDIATION_PRD.md` as a non-authorizing handoff and say so |
