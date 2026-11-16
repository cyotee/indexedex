# Migration deployment gas correction

## Objective and evidence

Correct the measured deployment gas excess without dropping any accepted
Migration behavior, authority boundary or required source category.
Original plan tasks 3/10 and E5 require a deployable real registry package,
not merely a successful unlimited local transaction.

The phase08 dedicated rehearsal at historical Robinhood chain 4663,
block 108944663, records parent deployment gas 42,985,843 versus the
recorded `getMaxTxGasLimit()` of 32,000,000. Read the complete report,
actual receipt and traces; do not substitute block gas for transaction gas.
This is measured local evidence and a historical limit, not a live-network
claim. No public transaction is authorized.

Read-only evidence:

- `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-08-operator/docs/incidents/2026-09-16-dtf-recovery/migration/operator/rehearsal/report.md`,
  its `gas.json`, `transactions.json`, source bindings and referenced final run.
- The same operator worktree's actual stage scripts and execution report.
- `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery/docs/incidents/2026-09-16-dtf-recovery/migration/nft-recovery/implementation/chain-gas-limits.log`
  and complete independent runtime/commit reports.
- The original implementation plan in the main checkout and repository rules.

## Worktree and ownership

Work only in
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas`,
branch `work/dtf-migration-phase-09-deployment-gas`, base
`421072a7630a0d3d47a6f36e1062d9eae98c93e2`.
Root must confirm warm seeding and exact clean branch/HEAD before dispatch.
Do not edit or compile in another lane's worktree.

Evidence belongs under the worktree's
`docs/incidents/2026-09-16-dtf-recovery/migration/deployment-gas/`.
Diagnostic and design-verification nodes write only evidence and owned
reproduction witnesses. They may inspect production code but not change it.

After independent design admission, implementation may change only the
Migration-specific production package/deployment code under
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`,
its neighboring Migration specs/forks and dedicated local gas witness scripts
under `scripts/foundry/recovery/dtf-migration/`.
Shared ordinary/common/Crane production, configuration, dependencies and
existing operator TypeScript are excluded. If a required fix crosses those
boundaries, report the exact necessary contract change before editing.

## Dependency-ordered deliverables

1. Diagnose the exact deployment call tree and gas contributors. Reproduce
   against the accepted code, verify the historically available transaction
   limit, distinguish one-time preparation from per-instance costs, and
   identify one minimal correction with an explicit owned-path list.
   Save actual trace/receipt evidence. Do not assume an arbitrary initializer,
   generic executor, new authority or skipped child is acceptable.
2. Independently review the proposed construction against all invariants and
   evidence. Return admitted, needs-fix or needs-owner-decision with precise
   requirements, not implementation authority for a product-policy change.
3. Implement only the admitted construction and its regression proof.
   Existing behavior remains the record. Retain a fail-before reproduction
   and successful target-bounded execution.
4. Independently execute the real target-bounded construction and inspect
   current production/package/registry behavior, source bindings and cleanup.
   Return AdversarialVerify confirmed or needs-fix for this bounded fix.

## Non-negotiable correctness and verification

Use real CREATE3/FactoryService and manager registry deployment. Any preparatory
transactions must be bounded individually and bound to the correct instance,
owner, package and immutable arguments. Final publication/activation must not
expose an incompletely initialized or hijackable Migration or child. Preserve
per-instance isolation, fresh bonds, exact funding, snapshot and custody
invariants, current-owner boundaries and irreversible removed selectors.
Never repair a deployment by disabling code-size checks, raising the target
transaction limit, suppressing simulation, replacing historical code or
removing facets/children/features.

Prove every required preparation and final transaction fits the evidenced
target limit using actual successful receipts with execution constrained to
that limit. Report gas for one instance and a second distinct instance;
cached global factories alone must not disguise per-instance failure.
An owner decision is needed only for a genuinely new product choice; ordinary
packaging optimization remains within the execution request.

Run artifact-first Solar build and relevant Migration specs/forks after the
production edit. Broaden ordinary/common tests if shared dependencies are
actually affected; do not rerun unrelated accepted suites without cause.
No viaIR, profile-path change, cache deletion, test weakening or fake SUT.
Capture commands, exits, exact artifacts and runtime receipts. Use an owned
local port distinct from operator port 18560, such as 18561, and stop owned
processes/impersonations/listeners with cleanup receipts. No public signer.

Do not commit, merge or modify historical reports in these four nodes.
Scoped verified source delivery is a later same-phase step. E2 attribution,
unsupported categories and all original full-plan gates remain open.
