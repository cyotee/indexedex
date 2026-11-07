# Integrated regression frontier

Date: 2026-11-07. `19-integrated-regressions.log` completed with exit 1:
470 suites, 5,092 cases, 4,933 passed, 159 failed, zero skipped.

The failed frontier includes widespread H1 exact-output
`ExchangeOutNotAvailable`, an H1 EtherFi `InvalidQuoteState`, the shared
projected-consumption unit fixture, two Balancer inactive-fee tests, and the
four previously recorded weighted/Balancer FullSpread exit positives.
No failure is suppressed or labelled pre-existing without a baseline.

The shared unit quote dependency implemented `quoteState` and
`quoteTransition` but advertised only the unlock-projection extension.
It now advertises the base transition interface as well, preserving the
existing enabled/disabled capability control and exact refund assertions.

Balancer's existing inactive-fee policy was restored after the parent
mistakenly removed its activation threshold; see `16-parent-validation.md`.

`19-h1-inverse-diagnosis.log` is the pending focused H1 trace plus shared
dependency and Balancer fee revalidation. H1 was previously green in the
recorded task-6 frontier; the integrated failure must be explained rather
than assuming its positive exact-output cases are intentionally unsupported.

The focused trace identified the H1 inverse regression in
`ContextQuote.inputForShares`/`withdraw`, not the SE inverse implementation.
After general snapshot support was widened to the base transition
interface, these two helpers required a quantity interface even when the
unavailable-unlock projection did not change the state. They now reuse the
existing exact-output projection gate while preserving the requested
holder: unchanged or unsupported projection retains the ordinary inverse;
a changed projection still requires the quantity interface and propagates
failure without a live fallback.

The controlled unit dependency gained an ordinary inverse and an exact
regression proving both absent and unchanged projection retain that
inverse without quantity support. `19-h1-context-repair.log` is the pending
full H1 family and shared-primitive run. The focused prior run also passed
both restored Balancer inactive-policy cases and both corrected stateful
fee-change cases.

`19-h1-context-repair.log` cleared the inverse failures but still had nine
direct-preview failures (503 passed, nine failed). H1 public exact-input
previews had also begun using generic transition snapshots for SEs without
the optional unavailable-unlock projection interface. H1 has no sequential
LP projection to perform on those routes. Its public wrap/unwrap views now
retain their ordinary SE preview when that extension is absent; explicitly
supported unlock projections still execute and propagate failures.

`19-h1-optional-projection.log` completed with exit 0: 512 tests passed,
zero failed/skipped across 56 suites, including the complete H1 family,
shared primitive suite, and H1 invariant (256 runs, 16,384 calls, zero
reverts). No failing H1 positive was converted to a rejection or tolerance.

`19-integrated-after-context.log` is the pending full seven-family/vault
regression gate after both context corrections and restored Balancer fee
policy. The four previously recorded weighted/Balancer requested-output
positives remain unresolved until this run and subsequent diagnosis.

`19-integrated-after-context.log` completed with exit 1: 470 suites,
5,093 tests, 5,089 passed, four failed, zero skipped. Only the two weighted
cross-leg preview mismatches and two Balancer requested-share positives
remain. All H1, shared primitive, inactive-fee and invariant regressions
passed in this integrated run.

`19-final-sizes.log` compiled successfully with warnings but exited 1 at
the size gate. All 71 affected product artifacts fit both limits; 13 other
artifact rows have a negative runtime or initcode margin. Exact values and
the unsuppressed gate disposition are in `19-final-size-receipt.md`.
