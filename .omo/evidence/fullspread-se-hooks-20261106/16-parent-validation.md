# Stateful ownership parent validation

Date: 2026-11-07.

`16-stateful-first.log` compiled successfully and executed 72 deterministic
FullSpread cases across nine LP configurations: 63 passed and nine failed.
Every failure was the zero-fee stage of
`test_HB16_feeChangesAndProtocolExitUseIndependentBooks`.

The new test requested zero through the existing per-vault setter. The
production fee-manager contract explicitly treats zero as clearing an
override, so these fixtures instead resolved to their nonzero global
default: five percent for constant-product single and 0.1 percent for the
usage-fee families. The independent expected fee remained zero.

The six component adapters now clear the appropriate global default when
requesting zero, then set the per-vault override and assert the actual
resolved oracle rate equals the requested rate. No ownership equation,
expected fee, or failing assertion was weakened. Fresh native LSP checks
reported no errors on all six adapters.

`16-stateful-fee-corrected.log` is the running validation receipt, not yet a
passing claim. The separate stateful invariant/mixed-decimal command has not
yet run. Task 16 remains open.

`16-stateful-fee-corrected.log` executed 72 cases: 69 passed and three failed.
The separate weighted N8 adapter had its own fee setter and required the
same genuine-zero setup; its independent resolved-rate assertion is now
installed too.

The remaining two failures were a production Balancer defect. Its legacy
`_feeOnAndShare` gate required a nonzero fee after conversion to the old
`FEE_DENOMINATOR` precision. A positive one-unit WAD fee therefore became
inactive even when `floor(gross * fee / 1e18)` was one LP unit. The gate now
uses the actual WAD percentage and recipient without that obsolete
precision threshold. The exact fee-split assertions remain unchanged.

Fresh LSP found no errors in the changed Balancer target or weighted
adapter. `16-stateful-fee-threshold.log` is the running Solar runtime-artifact
rebuild and deterministic suite. Broader Balancer regressions and sizes
need renewal after this production change.

`16-stateful-fee-threshold.log` completed successfully: 72 passed, zero
failed, zero skipped across nine real FullSpread LP configurations. All
eight new shared scenarios now have runtime receipts in every configuration.
This includes the exact tiny-fee split that exposed the Balancer defect.

`16-invariants-first.log` is the next serialized run, covering six independent
ownership campaigns, deterministic lifecycles, the weighted short-replay
control, and mixed-decimal/reentry tests. It is pending; the 72-case result
does not stand in for these campaigns.

`16-invariants-first.log` exited 0 but discovered only the two mixed-decimal
and reentry controls; both passed. The handoff's anchored alternatives
excluded the bare invariant/lifecycle names when matching Forge function
signatures. This is not a passing six-family campaign receipt.

`16-invariants-campaigns.log` reruns only the missing invariant, deterministic
lifecycle and short-replay names with the terminal anchor removed. The two
already-passing mixed-decimal controls are not repeated. The campaign is
pending.

`16-invariants-campaigns.log` completed with nine passing tests and three
failures. Dual, Orbital, Curve and weighted passed their independent
campaigns and deterministic lifecycles; weighted also passed its short-replay
control. The dual campaign recorded 256 runs, 16,384 calls and zero reverts.

Balancer setup called an unavailable generic `standardExchangeOf(address)`
selector. Its installed API is indexed `standardExchange(uint256)`. The
six fixture configurations now supply explicit SE-leg arrays using each
family's real query API; the handler uses those same native bindings for
genesis. No production interface or fallback was added. All seven changed
files passed native LSP error checks.

Constant-product single failed both its campaign and deterministic lifecycle
on an independent gross-mint mismatch. This remains an unresolved failure,
not a rounding tolerance. Failure-only native-book diagnostics were added
without weakening the assertions. `16-invariant-diagnostics.log` runs the
constant-product and Balancer deterministic cases after the fixture correction.

`16-invariant-diagnostics.log` passed the corrected Balancer deterministic
lifecycle and reproduced the constant-product mismatch. The independent
raw book was `15249980030009268061`; the actual mint implied a raw book
approximately one preceding exact-output payout larger.

Source inspection confirmed `_swapExchangeOut` transferred raw output
without decrementing `bookedRaw` and accepted raw input without incrementing
it. The owner exact-input raw leg and both `_payOwnerSwap` directions had
the same missing mutations. These installed facade paths now book the
actual raw input/output before payment. The original failing independent
ledger assertions remain unchanged.

The existing owner-during-lock suite gained
`test_ownerSwapsBookRawInputsAndOutputs`, exercising both token directions
for exact-input and exact-output owner swaps, with exact native book,
physical custody and unchanged LP supply assertions. Fresh LSP found no
errors in the production target or this regression test.

`16-cp-book-regressions.log` is the pending runtime-artifact rebuild, complete
constant-product-single family run, and Balancer invariant run. This
production correction also requires renewed final size/build receipts.

`16-cp-book-regressions.log` completed with 573 passes and one failure across
57 suites. The constant-product deterministic lifecycle and owner book
regression passed; Balancer passed its 256-run, 16,384-call invariant with
zero reverts and its deterministic lifecycle.

The sole failure was the constant-product campaign-coverage assertion after
replaying a persisted one-call counterexample: accounting now passed, but
one call cannot cover all eight actions. The existing weighted pattern is
now used here: assert replayed accounting first, complete the missing
deterministic 24-call prefix, then retain the strict campaign assertions.
The persisted replay was not deleted or skipped. An explicit one-call
replay regression was added. LSP reported no errors.

`16-cp-invariant-replay.log` is the pending short-replay, deterministic and
full-campaign receipt. All other cases in the preceding full-family run
already passed and are not repeated for this test-only correction.

`16-cp-invariant-replay.log` completed successfully: the invariant passed
256 runs and 16,384 calls with zero reverts; the deterministic lifecycle and
explicit short-replay control also passed. All six families now have passing
independent native-book campaigns, alongside the 72 FullSpread lifecycle
cases and the two mixed-decimal/reentry controls.

Task 16's stateful implementation and runtime work is complete. This does
not resolve the single-input snapshot interpretation, the four remaining
requested-output/preview positives, same-backing-pool composition, or the
separate acceptance and release gates. Genesis denomination is observed
by the shared ledger and separately tested by family tests; the failed
bootstrap control proves atomic rejection, not an injected partial
external-redemption fault.

## Integrated-gate correction: preserve Balancer activation

The later integrated run exposed the existing
`test_component_existingInactiveFeePolicyMintsNoProtocolLp` contract in both
Balancer configurations. The parent incorrectly removed its activation
threshold to satisfy the new generic oracle. That production change has
been reversed: `ownerFeeShare != 0` again controls activation. No existing
test was edited or waived.

The independent stateful oracle now has an explicit family effective-fee
adapter. Balancer maps configured percentages below `1e13` or at/above
`1e18` to inactive, matching its existing 100,000-unit threshold and cap;
other families retain their configured percentage. All native-component,
gross/net/supply and protocol-exit assertions remain exact. Task 16 is
reopened pending this correction's validation. The preceding completion
statement is superseded.

`19-h1-inverse-diagnosis.log` passed both corrected Balancer stateful fee
cases and both unchanged inactive-fee-policy regressions. The shared unit
projected-consumption case also passed. The only failure was the independent
H1 inverse trace. The stateful gate is closed again with the existing family
activation policy preserved; the other recorded stateful checks have
unchanged behavior.
