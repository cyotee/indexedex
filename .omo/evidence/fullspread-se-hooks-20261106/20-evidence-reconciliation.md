# Execution evidence reconciliation

Final reconciliation supersedes this historical snapshot:
`56-final-summary.md` and `54-final-default.log` record 28,411 passing
cases, zero failures/skips, and the closed review findings. Current audit
JSON preserves all 196 non-V4 rows and 107 unrelated acceptance items.

Date: 2026-11-07. Historical pre-clarification publication receipt; release
gates remain failed. Counts and gas measurements below describe the named
earlier receipts, not the current restored single-input implementation.
See `26-remaining-repair-ledger.md` for ongoing validation.

## Published scope

The current matrix JSON parses and contains 205 rows. Recomputed states
match its summary: 197 COMPATIBLE, seven DEPRECATED, one INCOMPATIBLE,
zero BLOCKED. Nine current V4 FullSpread rows account for 178 passing
standalone cases and zero failures; all reference the actual
`19-final-integrated-green.log` receipt. Nine inherited suites add 193
passing cases, for 371 cases within that 5,111-pass targeted gate.
These counts are subsets, not additional tests to add to the gate total.

`20-matrix-publication-handoff.md` records exact suite/method identities,
all 36 original failure migrations, all 48 acceptance dispositions and
the 45-ID audit taxonomy. The 48 dispositions are 42 executed-control rows,
five withdrawn rows and one reporting boundary. `01-acceptance-ledger.md`
also records the later actual double-initialization and own-delta evidence.
Withdrawn rows do not have invented passing tests.

Only affected current V4 audit entries were updated. The bounded publication
receipt establishes preservation of 196 non-V4 rows, including seven V3
rows, and 107 non-R10.3 acceptance items. The parent subsequently appended
one gate-result string to R10.3; it did not rewrite historical evidence or
the historical independent-review object. Four audit JSON documents parsed.
Biome LSP is unavailable; no installation or clean-LSP claim is made.

## Current execution outcomes

| Receipt | Result |
|---|---|
| `19-final-integrated-green.log` | 473 suites, 5,111 passed, zero failed/skipped |
| `19-detf-bootstrap-matrix-r2.log` | 351 suites, 355 passed, zero failed/skipped |
| `19-native-sy-migration-r3.log` | Eight suites, 45 passed, zero failed/skipped |
| `19-wings-consumer-migration.log` | Three suites, 13 passed, zero failed/skipped |
| `19-staking-migration-after-bootstrap.log` | Ten passed, zero failed/skipped |
| Wrapper receipts in `19-consumer-migration-receipts.md` | 40 current cases across seven suites pass |
| `19-post-consumer-release.log` | Plain Solar build passed; size and default gates exited 1 |
| `19-post-consumer-default.log` | 2,659 suites, 24,143 passed, 4,144 failed, zero skipped |

All remaining failing suites are DETF suites or direct DETF consumers.
The complete failure footer was reconciled, including 72 cases outside the
narrower DETF run's roots. They are not waived as pre-existing failures.
`19-failures.md` records the repaired bootstrap, remaining single-payment
funding incompatibility, residual assertions and invariant failure.

The 71 measured hook/FullSpread artifacts and listed DETF adapter artifacts
fit runtime/initcode limits. Thirteen other artifact identities exceed a
limit; exact measurements and the changed test-only Wings fixture size are
in `19-final-size-receipt.md`. The global size gate is not green.

## Gas and capability boundaries

The nine configurations execute 36 measured composed routes. Current maxima
are 556,371 preview gas and 1,449,022 transaction gas, below the unchanged
5,000,000/12,000,000 limits. Setup is excluded. H1 remains conversion-only.

Direct FullSpread inverse quoting/execution remains unavailable. Weighted
sequential exit views fail closed when valid projected state is unavailable,
while actual exit aliases remain positive. Requested share-only exits whose
conversion refunds input reject atomically; fully consuming controls remain
positive. No projected-state interface, vault rate provider, mixed payout or
same-backing-pool safety claim was invented.

## Provenance and superseding clarification

`00-execution-baseline.md` records the already-dirty starting checkout,
historical HEAD, Foundry nightly and Solar versions. It is not a fingerprint
of current source. No commit, deployment, live migration or destructive Git
operation was performed.

The user subsequently clarified that initialization requires every leg,
funded with either pair tokens or SE shares, and that ongoing single-leg
deposits must remain supported. The earlier strict ban on paid cross-leg
preparation was an incorrect interpretation, not an unresolved product
decision. Restoration proceeds within that clarification: caller-funded
trades precede component-proportional issuance against the resulting books.
No new DETF API or funding-model approval is pending. Publication completion
does not complete the outstanding regression gates or authorize release or
deployment.
