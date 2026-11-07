# Remaining compatibility repairs

This is a chronological repair record, not a list of current failures.
Final receipt 54 passes 28,411 cases with zero failures/skips. The final
delta gate approves the Balancer state-copy correction with no remaining
blocker. Earlier failures and rejected experiments below are preserved as
history. See `51-review-remediation.md` and `56-final-summary.md`.

The broad restored gate (`25-restored-hooks-and-detf.log`) has 14,548
passes and 464 failures across 15,012 cases. Its complete failure footer is
retained; `25-other-failures.md` records the non-residual triage group.
Later focused counts below are not comparable whole-suite totals.

## Executable R19 checks and real fixes

`DetfResidualAssertions` replaces fixed zero/ten-unit tolerances with
successful zero quotes in the actual DETF caller context, zero one-token
unbalanced quotes, and exact reserve booking. It also checks every
supported pair/share choice for the complete residual basket. A real
five-token donation is the negative control: the oracle must reject it as
joinable before the public sweep, then pass afterward.

Those checks exposed individually unjoinable but collectively joinable
residuals. Production cleanup now tries complete held-capital baskets.
The eight outer rounds and existing 24-attempt individual bounds were not
increased. The 29-case focused R19/wrapper receipt
`25-r19-basket-sweep-and-wrapper-r4.log` passed after the first batch repair.

Further traces showed two defects in the batching implementation:

- A first-positive pair preference could ignore a much larger held-share
  alternative. The selector now consolidates convertible pair/share
  mixtures and tries shares first, then the remaining supported choices.
- Address-listed Curve joins reject zero-valued entries. The production
  batch and independent oracle now omit empty legs rather than passing
  zero entries or changing the hook's input-validation contract.

The attempted first-positive-basket-only optimization left real joinable
capital and was rejected by the oracle. It was not accepted as a pass.
The later share-preferred selector preserves the individual cleanup
fallback. It did not resolve the remaining gas failures.

Some old lifecycle helpers silently called a second sweep before asserting
R19. They now assert the original transaction's result without repairing
it. Close checks reconcile actual local cash plus SE-share claims instead
of requiring valid local LP backing to be rebuffered away.

## Projection and receipt repairs

- CP's contextual claim-in used actual held SE shares while the ordinary
  route used booked shares. It now excludes ambient inventory consistently.
- Weighted custom-deposit join quotes now retain the external projected
  state. Its matching DETF quantity uses the same native reserve ratio as
  execution, without an intermediate LP rounding step.
- Orbital incorrectly required the separate PoolManager-unlock extension
  before using an ordinary external-deposit projection. It now uses the
  actual base projection capability; missing projection is not replaced by
  a live-state guess. Already-owned share inputs need no global-state
  projection. Bond pricing uses the ordinary uncapped swap calculation.
- Custom-bond tests compare projected pair value, purchase quantity and
  liquidity quantity with a real wrapped-state snapshot.
- LP-gift checks distinguish the unchanged whole-position transfer from
  separate mints caused by sweeping newly joinable protocol capital.
  Every mint is reconciled; LP burning/unwinding and new DETF issuance
  remain forbidden.

## Lawful wrapper composition

The two wrapper/DETF fixture files now use a non-rebasing wrapper share as
the pair of a distinct registered SE. A six-decimal underlying and the
wrapper's real ten-decimal offset produce an allowed sixteen-decimal pair.
The provider binds to the outer SE. Real positive/negative rebases and
receipt custody remain tested. The invariant includes the actual outer-SE
fee recipient rather than treating fee-share minting as escaped custody.
These controls passed in the 29-case focused receipt above.

## Gas and current gate

`26-quad-burn-budget-trace.log` proves OutOfGas inside residual cleanup
under the existing 30,000,000-gas call allowance. No test or repository gas
limit was raised. Subsequent scheduling and basket-selection changes must
pass that same allowance.

`29-share-preferred-residual-gate.log` completed with 476 passes and six
failures across 482 cases. The same six production-SE burn/close calls
still fail under their unchanged gas allowance. Projection parity,
receipt checks and wrapper cases in this focused gate pass.

`30-basket-first-residual-gate.log` completed with 477 passes and five
failures. This version consumes
executable residual baskets before single-token cleanup, rather than
immediately trading basket refunds back across legs. Basket attempts are
bounded at 24, matching the existing per-token cleanup bound; the outer
eight-round bound and test gas allowances are unchanged. The independent
same-transaction residual oracle remains the correctness gate. Earlier
compile failures and failed optimization receipts remain failures.

`31-basket-first-burn-trace.log` confirms the remaining Curve/UniV3
failure is still out of gas inside residual cleanup, including repeated
single-token joins costing about 1.2 million gas each. The outer call
exhausts its existing allowance; `RateProviderFailed` is the propagated
symptom of the nested quote running out of gas.

`32-interleaved-residual-gate.log` completed with 478 passes and four
failures. Successful single-token consumption now yields to the next
outer pass so cross-leg refunds can be recombined rather than repeatedly
traded in isolation. No ownership assertion or gas allowance changed.

`33-residual-subset-gate.log` completed with the same 478 passes and four
failures. The attempted one-leg-omission fallback did not resolve the gas
failure and was removed, restoring the interleaved scheduling tested in
receipt 32. No subset heuristic is retained. A read-only independent
analysis is checking the remaining cleanup cost against the trace.

The independent analysis found that yielding after one successful token
join still advanced through other tokens before recombining its refunds.
The next source revision re-enters consolidation and basket cleanup
immediately, including after the last token. Re-entries share one
24-success basket budget per outer round; the eight-round limit remains.
Final pair/share balances are explicitly booked after the last basket.
Solidity LSP reports no errors; compilation and runtime validation of this
revision are pending.

`34-restored-hooks-detf-regression.log` was started before that scheduling
revision and tests the receipt-32 implementation, not the new source.
Its artifact writer must finish before the next build starts.

Receipt 34 completed: 1,065 suites, 14,825 passed, 189 failed, zero
skipped (15,014 cases). No hook-family suite failed. The remaining
failures are 164 weighted `InvalidQuoteState` cases, 18 old fixed-ten-unit
residual assertions, two legacy-V3 tests requiring a particular nonzero
residual, one burn-boundary error-selector mismatch, and four bounded-gas
burn/close failures. These failures are not waived as pre-existing.

`35-immediate-recombination-gate.log` completed with 478 passes and the
same four failures. Immediate re-entry alone has not solved the gas
problem. `36-weighted-state-trace.log` is tracing one of the independent
weighted failures. Four remaining fixed-residual helpers are being
migrated to the existing executable ownership oracle in a separate
test-only track; its edits have not yet been validated.

`37-live-weighted-quotes-and-residual-oracles.log` completed with 2,226
passes and seven failures across 129 suites (2,233 cases). All 164
weighted failures and all 18 fixed-residual assertion failures are
resolved in their failing suites. Live weighted joins now use ordinary
forward quotes for their single conversion per leg; genesis and external
projected-state paths retain projection. A selected pair conversion that
cannot mint a native share is not executed. Projected controls and the
weighted invariant suite pass in this gate.

`39-funded-residual-and-burn-boundary.log` completed with 68 passes and
zero failures. Legacy residual tests now explicitly transfer real
zero-share capital, then derive a top-up that can mint hook LP, rather
than assuming cleanup must naturally leave a particular remainder. The
primary burn rejects a quoted zero recipient payout at the DETF boundary
before a nested native redemption can fail with a different error.

Four gas failures remain. Their trace also exposes an earlier isolated
self-token rejoin in the burn path, before the residual sweep sees the
other unpaid exit legs. The next revision sends those legs together
through the existing residual join instead of first buying components
already held. `40-unified-burn-residual-basket.log` is pending under the
unchanged allowances and same-transaction ownership assertions.

Receipt 40 completed with 546 passes and the same four gas failures.
Receipt 41 tested a Curve native-preparation refinement: 764 passed and
four failed, including two newly failing component-accounting controls.
That refinement was rejected and removed; those tests were not weakened.

Receipt 42 is a temporary diagnostic measuring the complete Curve/UniV3
burn with no inner-call gas cap, followed by the unchanged ownership
oracle. It is not a release gate and cannot satisfy the existing
30,000,000-gas acceptance tests. Its source will be removed after the
trace is collected. The separate bounded tests remain unchanged.

The complete diagnostic burn used 63,623,259 gas and passed the ownership
oracle. Of that, the residual sweep used 61,394,934 gas. The trace shows
repeated complete baskets converting a large share input while a tiny
other leg limits acceptance to one native DETF unit. Immediate basket
re-entry made that work recur rather than eliminating it.

Receipt 43 tests the opposite schedule: converge individual paid routes
first, and only combine the terminal individually unjoinable remainders.
It retains the original eight outer rounds and 24 individual attempts.
The diagnostic is included only to measure cost; the unchanged bounded
tests and ownership assertions still decide acceptance.

Receipt 43 regressed to six bounded-gas failures; its diagnostic cost was
84,401,785 gas. The terminal-first schedule was removed, restoring the
receipt-40 scheduling. The temporary diagnostic source was deleted; its
receipts remain evidence only. A read-only algorithm analysis is examining
conversion sizing and repeated native acceptance, not proposing a gas
limit change.

`44-current-default-regression.log` is the current full Solar build and
default-suite run on that restored source. It is separate from the
focused receipts and includes consumers outside the 15,014-case gate.
