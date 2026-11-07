# Sequential-projection gate finding and repair

Final disposition: closed. Receipt 54 passes all 28,411 default cases,
zero failures/skips. The fresh final delta review returns APPROVE with
no remaining blocker in `55-final-delta-gate-review.md`. The chronology
below retains the rejected intermediate states and their exact repairs.

## Independent gate result

The first gate reviewer returned REJECT for one Task 13 / IS-5 issue,
despite the clean default run in receipt 50 (28,402 cases, zero failures
or skips). This was a source-backed finding, not a claimed numerical
reproduction by that read-only reviewer.

Balancer UnitsCore simulated a conversion without a transition snapshot,
then paid preparation read the unchanged live provider. Orbital ExitQuoteLib
refreshed a rate after a similarly unprojected simulated redemption.
Dual DepositQuoteLib reused live SE state after simulated share redemption
when sizing subsequent swaps/conversions.

The reviewer accepted the product-size classification in
`49-size-classification.md` as a reported scope boundary, not a green
global size gate. The historical F1-F4 reports were not the rejection
reason.

## Implemented correction

Transient quote structs now track a consumed conversion whose resulting
state could not be projected. Subsequent dependent rate or conversion
queries revert `InvalidQuoteState`. Ordinary one-conversion component
quotes remain available; actual transaction execution still uses actual
SE state and receipts. No projection interface or provider behavior was
added to FullSpread.

The new real-FullSpread controls preserve positive execution after the
capability rejection. They cover:

- Dual share-input sequential join and cross-leg exit views.
- Dual complete share-basket one-conversion-per-leg preview parity.
- Balancer pair/share buffered unbalanced views and actual joins.
- Balancer complete proportional share-basket preview parity.
- Orbital sequential exit capability rejection while the existing
  positive payout, caller LP burn, other-holder and fee controls remain.

`51-sequential-projection-controls.log` passes all 265 cases across five
suites. All six touched source/test files have clean Solidity LSP
diagnostics. Broader validation and the fresh delta gate review remain
required before final signoff.

## Exit-side propagation follow-up

The fresh delta gate found one missed Balancer caller: `_previewSingleExit`
aliased `allocation.states` into `remaining`, but not the new unknown-state
flags. The reviewer returned REJECT; its full report is
`../fullspread-se-hooks-20261106-delta-gate-review.md`.

The caller now aliases both arrays before simulated output conversion.
A new real-FullSpread raw-output test checks exact-BPT-in, exact-token-out
and SY preview aliases reject the unsupported sequence, while the
ordinary proportional view remains positive and actual exact-BPT-in
execution pays the requested raw token and burns only the caller's LP.
The inherited five-leg adapter runs the same control.

LSP references and a literal copy-site search confirm both Balancer
state-array alias sites propagate `unprojected`; both edited files have
clean diagnostics. Runtime validation of this additional fix is pending.
Receipt 52 was started before this follow-up and does not validate it.

`53-balancer-exit-projection-control.log` now passes all 123 cases across
three suites, including both the base and inherited five-leg raw-exit
controls and the ordinary proportional preview positives. Receipt 52
finished with 28,409 passes, zero failures/skips before this final copy
fix. Receipt 54 is the fresh full build/size/default run for the corrected
source. No source change beyond the missing alias and its control was
made after the second review.

## Receipt counting

The Foundry default footer and sum of suite header counts both report
28,402 cases for receipt 50. Some invariant campaigns print several
passing invariant names for one counted campaign. Their 89 additional
PASS lines are assertions within counted campaigns, not additional test
cases. Matrix and original-failure reconciliations use exact suite/method
identities; whole-run totals use the runner's reconciled case counts.
