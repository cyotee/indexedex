# Approved Stage 2-only surrender: complete W-L and align NFT paths

## Owner decision and superseded gate

The owner answered **Yes, Stage 2 only** to correcting requirements and
implementation so legacy-asset surrender is rejected in Stage 1 and opens
only in the same atomic activation that removes entitlement configuration
and enables ordinary deposits.

Read current main plan r4 section1.4 and PRD r21 MIG-D06/R06/R07/R27/R29.
These supersede the phase13 brief's pre/postactivation success wording,
phase12 preactivation-surrender tests and the prior unresolved
partial_entitlement_correction question. Neither proposed correction formula
nor post-use amendment mechanism is needed. Configuration and migration
consumption are mutually exclusive stages.

## Worktree, retained evidence and scope

Use the existing phase13 worktree/branch based on verified2c2b3370:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-13-weighted-liquid`.
Preserve the sealed `migration/weighted-liquid/implementation/` incomplete
report, bindings and source snapshots, and the needs-fix `verification/`
report. Do not overwrite historical evidence or call it a former pass.
New reports belong in `weighted-liquid/stage2-correction/` and
`weighted-liquid/stage2-verification/`.

Read the complete original phase13 brief, incomplete report, independent
needs-fix finding V1 and actual current code. Use unchanged verified source
primitives and the original-wallet requirement. No held phase09 candidate
inspection/import/test or provider-refusal bypass; this is the new approved
lifecycle and W-L implementation, not gas correction.

Allowed edits remain Migration-specific production/schema/repo/targets/
facets/package wiring/TestBase, neighboring specs/forks, phase13 operator
scripts/Foundry stages and runbook. Updating all existing NFT surrender
guards, lifecycle fixtures and operator ordering is explicitly in scope.
No ordinary/common/Crane production, dependency/config changes, public
transactions, commits, push or merge.

## Complete the missing configuration setter

Implement the actual `configureWeightedLiquidEntitlements` route rather than
merely publishing its selector. Current proxy owner only, Stage 1 only,
complete nonzero-wallet/source/origin/Q0/original-component input, existing
funded snapshot frozen C0, canonical economic-origin overlap protection.
Identical repeated loading is idempotent; corrected full replacement before
activation sets the final Q/C baseline without issuing anything.

No migration surrender can have consumed a record while this setter is
callable. Do not implement `newTotal-oldPaid`, remaining-fraction correction,
retained old remainder or a policy knob. Do not clear historical execution
records on overwrite; stage invariants and existing used-origin protection
must reject impossible/corrupt consumed-state input rather than reopen it.
Independent compensation can be issued in Stage 1, so preserve its existing
issued-fact/cross-path protection separately.

After activation, setter selectors and interface authority are removed and
unrestorable. Ordinary deposits, all surrender-triggered routes and reward
payouts use the same finalized activation state; no new switch.

## Atomic stage boundary

All existing legacy NFT surrender and new W-L surrender entrypoints must
reject in Stage 1 before external custody, allowance use, callback, consumed
state, minted supply or bond funding. Keep the required original-wallet and
matching-record guards; Stage 2 is necessary, not sufficient, for eligibility.
Read-only quotes need not be redefined as operations or silently disabled.

Activation is one protected transaction: current-owner authorization,
ordinary-deposit/surrender/reward opening and complete actual selector cut
must all succeed or all revert. Inspect actual order and common lock so no
callback can exploit a temporarily open state while a loader remains usable.
Do not rely on a public Boolean while a restorable setter is still callable.

Stage 1 funding/donations and separate independent-compensation issuance
retain their existing rules. Its bond clock starts at actual issuance.
Migration surrender clocks start only when a Stage 2 surrender actually
creates a new funded bond; activation resets neither kind.

## Required tests and real rehearsal

1. Missing setter V1 closes with actual successful Stage1 loading, idempotent
   replay and full corrected replacement before any surrender.
2. Both real NFT generations and W-L reject Stage1 surrender without any
   balance/custody/credit/supply/bond change. Wrong-wallet and missing-record
   rejection remains proved after activation too.
3. Successful activation removes every actual configuration/amendment/
   discretionary-issuance selector, including the new W-L setter; ordinary
   deposits and eligible surrender open together. Failure rolls back both.
4. After activation, NFT surrender and W-L partial/final exact-delta custody,
   frozen credit rounding, fresh funded90-day bonds, owner selected booked
   conversion/donation and rollback work; loader calls reject after the first
   partial surrender and cannot change remaining Q/C.
5. Current-owner permissions, independent compensation, overlap protection,
   NFT transfer-back, registry checks and restoration negatives remain tested.

Update only stage assumptions made stale by the explicit owner decision.
No skipped/relaxed assertions, fake subject, prose tests or source-grep tests.
Run artifact-first Solar and current relevant Migration specs/forks,
final-source operator tests/types. Preserve existing independent ordinary/
common evidence unless input impact actually calls for a new run.

Use the already fixed phase13 CLI at port18563 and its checkpoint/evidence
domain. Reorder its actual scenario: configure/correct in Stage1, prove
preactivation rejection, execute independent issuance as before, activate,
then perform legacy surrender and related recovery. Retain both real
mined-before-checkpoint donation/issuance resumes, meaningful outstanding-row
reordering, missing-wallet records, unclaimed zero issuance and source domains.
Do not update a configuration after partially surrendering in rehearsal.

Do not claim target-gas feasibility from the baseline permissive local node.
Keep real operational original quantities/allocations distinct from synthetic
fixtures, and keep every other unsupported source category explicit.

## Independent acceptance and handoff

Implementation finishes its new complete report, final source/artifact and
receipt bindings, relevant results and owned runtime cleanup before handing
off. Temporary idle or a workflow-complete flag alone is not readiness.

Independent verifier executes actual Stage1 rejections, atomic activation,
postactivation configuration rejection and positive original-wallet
NFT/W-L surrender/recovery; checks final operator order and preserved resume
semantics; independently reconciles all required checks with final bytes.
Return AdversarialVerify confirmed/needs-fix for this bounded lifecycle/W-L
increment only. No full-category or held gas acceptance.
