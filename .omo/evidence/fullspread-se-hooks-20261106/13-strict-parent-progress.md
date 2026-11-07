# Weighted/Balancer pre-intake correction

Date: 2026-11-07. Interpretation is recorded in
`13-preintake-decision.md`; no owner approval of incumbent-funded joins
was inferred.

Weighted join execution and previews no longer call the incumbent-trading
rebalance helpers or replace their original component snapshot after a
trade. Caller-only SE conversion and the common gross/ceil acceptance
remain. Actual swap and exit engines are unchanged.

Balancer unbalanced/single-input assembly now uses the same original-book
basket path as proportional/flexible joins. It no longer divides caller
input into internal trades against missing incumbent legs. Valid
multi-input and zero-component cases retain the existing component engine.

The shared exact-net full-book test now verifies that a lone input cannot
buy missing incumbent components and that the whole failed operation
restores caller and incumbent state. Pure exact-net fee-rounding tests
remain. A shared alias assertion records complete state before each call
and requires an actual rejection with unchanged state afterward.

Weighted tests retain the positive case where a caller explicitly completes
separate public swaps, owns the resulting basket, and then begins a
proportional join. Bundling those incumbent trades inside the join is no
longer treated as an equivalent ownership snapshot. Proportional,
all-leg unbalanced-share, Permit2 share-funded and partial-book positives
remain independently asserted.

`13-strict-parent-aliases.log` compiled and passed 43 tests across weighted
n=2/n=3/n=8 and Balancer n=2/n=5: zero failed/skipped. This is a focused
alias receipt, not a complete-family gate or validation of other tracks.

## Requested-share exit contract under inspection

The prior FullSpread requested-share positive assumed that depositing its
allocated local claim would consume all of that claim. The actual SE
preview returns both positive shares and a positive input refund, so a
share-only requested payout cannot be completed. FS-HOOK-08 requires
whole-exit rollback when its requested conversion fails.

The test now independently proves that partial-consumption condition and
checks exact preview/execution rejection plus complete state restoration.
A separate production-first ERC4626 SE control retains the positive
local-claim-plus-allocated-shares payout, exact preview parity, and
remaining-holder share assertion. No partial input is donated to incumbent
holders or silently paid as a different output asset.

`12-share-exit-conversion-contract.log` is pending for both the real
FullSpread negative configurations and the fully consuming positive control.
The two weighted sequential preview mismatches remain separate unresolved
work; they were not modified by this correction.

`12-share-exit-conversion-contract.log` passed all three cases: the real
fully consuming requested-share positive and both FullSpread partial-
conversion rollback configurations. This corrects an invalid test premise;
it does not claim FullSpread can produce a share-only payout from an
incompletely consumed local claim.

The four other source tracks have handed off in
`07-preintake-handoff.md`, `08-preintake-handoff.md`,
`09-preintake-handoff.md`, and `11-preintake-handoff.md`. The parent also
updated the three Orbital shared expectations left outside that worker's
scope: complete-basket one-unit positive, impossible single-input preview/
rollback, and partial-book decimal funding with unchanged zero coordinates.
The exact missing-basket error is `ZeroAmount()`. Fresh diagnostics for the
Orbital shared matrix file timed out; its compiler result is required.

`13-strict-six-families.log` is the running serialized artifact rebuild and
complete six-family plus shared primitive/interface test run. No family
task is closed from these source-only handoffs.
