# Execution ledger

The user has since clarified per-leg initialization and ongoing single-leg
support, and work has resumed. The blocked disposition and completion
counts below describe the earlier source frontier, not the resumed work.
Tasks 7-12 and 13 are reopened. Current progress and new runtime receipts
are in `23-clarified-liquidity-progress.md`.

Updated 2026-11-07. This is an interim evidence ledger, not completion,
release approval, or deployment authorization.

Authority: the requested
`docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`
and its sole authoritative FullSpread PRD. No commits, deployments,
migrations, or destructive Git operations were performed by this execution.

## All 24 requested tasks

| Task | Disposition | Evidence or remaining condition |
|---|---|---|
| 1. Freeze requirements and enumerate routes | Done | `01-surface-map.md`, `01-acceptance-ledger.md`; 48 acceptance rows retained. |
| 2. Correct SE membership and own-share classification | Done | Shared validator changes and real matrix binding/own-share positives; original failure outcomes in `15-original-outcomes.md`. |
| 3. Shared component/refund primitives | Done | Native component kernel and two-word receipt accounting; primitive regression in `19-h1-optional-projection.log`. |
| 4. Real FullSpread sibling fixtures | Done | Real disjoint backing positions; nine matrix configurations and their inherited vault suites execute. |
| 5. Shared component behavior matrix | Done | Native ceil/floor, gross/fee/net, caller inventory and rollback assertions; stateful extension in task 16. |
| 6. Single wrap/unwrap accounting | Done | `06-implementation.md`; renewed complete H1 and primitive gate: 512 passed in `19-h1-optional-projection.log`. |
| 7. Constant-product single | Done | Complete CP gate and final integrated receipt pass; native raw-book and strict pre-intake fixes included. |
| 8. Dual constant product | Done | Complete dual gate passes; false incomplete reserve-interface advertisement removed while installed selectors are preserved. |
| 9. Orbital | Done | Complete Orbital gate passes, including real refund-callback observation after final state commitment. |
| 10. Weighted | Done | 905-pass family gate and integrated receipt pass; unavailable sequential exit views fail closed while actual exit aliases remain positive. |
| 11. Curve quad | Done | Curve gate and integrated receipt pass; exact installed-interface metadata updated. |
| 12. Balancer stable | Done | 730-pass family gate and integrated receipt pass; full-consuming share payout positive and partial-conversion rollback distinguished. |
| 13. Facades and previews | Done | Hook-family aliases pass; all 45 migrated native SY cases pass with caller-only acceptance, exact rollback and real redemption. Broader DETF compatibility remains task 19. |
| 14. Package linkage and proxy surfaces | Done | Real package/loupe controls and complete artifact refresh pass; 71 affected artifacts fit. Global size overages are task19 findings. |
| 15. Original failures | Done | All 36 original identities have actual passing receipts; `15-original-outcomes.md`, `15-original-negatives.md`, `15-original-failures.log`. |
| 16. Stateful ownership and market change | Done | Six native-book campaigns, 72 FullSpread scenarios, mixed-decimal/reentry controls, and preserved Balancer inactive-fee policy. `16-parent-validation.md`. |
| 17. Gas and capability limits | Done | Both targets and actual mint/redemption in all nine configurations; canonical preview measured directly. `17-gas-final-receipts.md`, `17-capabilities.md`. |
| 18. Complete acceptance inventory | Done | All 48 dispositions reconciled: 42 executed-control rows, five withdrawn, one reporting boundary. Actual repeat initialization and both own-credit guards are evidenced; global compatibility is not inferred. |
| 19. Integrated regressions and size gates | Open | Targeted integrated: 5111 passed. Refreshed plain build passed. Latest full default: 24143 passed, 4144 failed, exit1; remaining failing suites are DETF or direct DETF consumers. Global size exit1; affected hook and DETF artifacts fit. |
| 20. Publish execution/matrix evidence | Done | `20-evidence-reconciliation.md` records current counts, all 48/36 dispositions, gas, capabilities and failed global gates. R10.3 has the final gate update; all 107 unrelated acceptance items remain unchanged. |
| Final 1. PRD/failure-ledger audit | Open | `F1-compliance.md` records the scoped audit; final signoff awaits task 19. |
| Final 2. Accounting/guard/package review | Open | `F2-review.md` and `22-review-disposition.md` record completed review work and unresolved compatibility findings; final signoff is withheld. |
| Final 3. Proxy execution and release gates | Open | `F3-runtime.md` records not ready: actual proxy positives pass, but default and global size gates fail. |
| Final 4. Ideal-state and scope fidelity | Open | `F4-fidelity.md` reconciles IS-1 through IS-6 and the gated DETF extension; final signoff is withheld. |

Completed: **19/24**. Partial implementation, a passing subset, or a source-only
handoff does not close any open row.

## Current release frontier

The post-consumer plain build passed; size and default gates exited 1.
A new wildcard-import collision in the dual SY test was fixed by an
explicit math-library alias before this successful compilation.
Current consumer receipts: 45 native SY, 13 Wings, 10 staking migration,
40 wrapper cases and 355 DETF bootstrap controls pass. The complete DETF
lifecycle gate has 5485 passes and 4072 failures; the complete default
gate has 24143 passes and 4144 failures. Every remaining failing suite
is a DETF suite or direct DETF consumer.
See `19-consumer-migration-receipts.md` and `19-failures.md`.

The following complete-repository receipts predate those consumer repairs:

`19-final-integrated-green.log`: 473 suites, 5111 passed, zero failed/skipped.
`19-all-artifacts-build.log`: complete artifact refresh and plain Solar build passed.
`19-full-default-hermetic.log`: 19200 passed, 9065 failed, exit1.
`19-release-sizes.log`: affected71 fit, but global gate exit1; maximum affected
runtime 19419 bytes. `19-failures.md` records unresolved consumers.

The earlier receipts below remain history, not the current release verdict.

## Important executed receipts

- `15-original-failures.log`: 315 passing cases, including the exact 36
  original failure identities recorded separately.
- `15-vault-validation.md`: all 291 unique vault cases have passing receipts
  after the documented assertion-fixture corrections.
- `16-parent-validation.md`: independent native books and caller inventory
  through joins, swaps, exits, ambient transfers, fee changes, real market
  movement, unwind and rollback. No SUT storage injection or fake vault.
- `17-gas-final-receipts.md`: largest measured preview 556,371 gas; largest
  measured whole router transaction 1,449,022 gas in the final integrated receipt (`20-matrix-publication-handoff.md`). Setup is excluded.
- `19-integrated-regressions.log`: first integrated gate had 4,933 passes and
  159 failures. It is not a pass. Subsequent H1/context/unit and Balancer fee
  corrections are described in `19-integrated-progress.md`.
- `19-h1-optional-projection.log`: 512 passing cases, zero failures/skips;
  H1 invariant 256 runs, 16,384 calls, zero reverts.
- `19-integrated-after-context.log`: 5,089 passing cases, four failing
  weighted/Balancer FullSpread exit positives, zero skips, 470 suites.
- `19-final-size-receipt.md`: renewed complete Solar compilation succeeded
  with warnings; all 71 affected product artifacts fit. The overall size
  command exited 1 and remains an explicitly failed gate.

## Boundaries that remain in force

Single-input joins now follow the literal pre-intake/caller-only rule under
the user's best-judgment continuation; no approval of paid incumbent swaps
was inferred. The weighted sequential-view capability limitation is explicit; actual exit aliases pass.
The Balancer requested-share assertion is preserved as a positive on a real
fully consuming SE; actual FullSpread partial conversion now requires exact
whole-exit rollback under FS-HOOK-08, as documented in the parent progress.
Missing projected-state interfaces are not fabricated. Disjoint backing
pools do not establish same-backing-pool safety.

The renewed whole-repository size command failed on oversized other
artifacts, while the 71 measured affected product artifacts fit the limits.
Without a before-change baseline those other failures are not called
pre-existing. Exact renewed measurements are in `19-final-size-receipt.md`.
