# Source-review disposition

Updated 2026-11-07. Independent report:
`../fullspread-se-hooks-20261106-code-review.md`.
The report is source evidence, not a runtime pass.

## Corrected in this execution

- **H-1, dual false reserve-interface advertisement:** removed the incomplete
  `IDetfReserveQuote` ERC-165 registration from package and facet metadata.
  The two installed legacy views remain callable; inherited declarations
  remain documented for source compatibility. No missing projection stub or
  new interface was invented. The real proxy regression checks all five
  selector addresses and the capability bit.
- **H-2, incumbent-funded joins:** all six LP families now use the literal
  pre-intake/caller-only contract in `13-preintake-decision.md`. Impossible
  baskets reject atomically. Complete-basket and legitimate zero-component
  controls remain positive.
- **M-3, Curve under-advertisement:** register both already-implemented
  interfaces. The real proxy test checks registration and all five reserve
  projection selectors.
- **L-4, Orbital refund ordering:** reproduced stale LP supply during a real
  refund, then completed all components, LP issuance, L2 and reserve views
  before refund transfers. The unchanged observer checks final supply,
  depositor LP and all three local component views.

`22-audit-regressions-red.log` reproduced the three runtime defects.
`22-audit-regressions-green.log` passed their unchanged regressions plus the
restored dual zero-input error contract: four passed, zero failed/skipped.

## Preserved scope and existing policy

- **M-1:** the dual family has no owner role or owner package field. Its
  funded `ownerSwap*` aliases have the same permissionless economics as its
  public swaps. Adding ownership and a new ownable facet would be a separate
  family policy change; this FullSpread amendment does not introduce it.
  The naming/authorization observation is retained as an out-of-scope
  finding, not silently described as an owner-gated path.
- **M-2:** the undeployed legacy CP target and uncalled retired helpers are
  source cleanup opportunities. They are not installed entrypoints in the
  reviewed packages. No bonus deletion of reference code or retained math
  was performed to satisfy this execution's runtime goals.
- **L-1:** existing explicitly unavailable inverse views were not replaced
  with invented exact-output support. Direct bounded component execution
  and unavailable inverse quoting remain distinguished.
- **L-2/L-3:** retain family fee-activation and dust-boundary policies; this
  task does not standardize those economic choices. The Balancer activation
  threshold was restored and tested rather than changing its old negative.
- **L-5:** Balancer's absent reserve-projection advertisement is consistent
  with its installed interface set; no new DETF interface was added.

## Corrections to the report's interpretation

The report correctly identifies FullSpread's intentional inverse rejection,
but incorrectly attributes the broad H1 integration failures to that case.
The actual focused trace involved an ERC4626 SE and the shared context
helper's unnecessary quantity-interface requirement. That defect and H1's
ordinary-preview gate were fixed; all 512 H1/primitive tests passed afterward.
No supported H1 positive was converted into an expected rejection.

The old weighted exit-preview discrepancies are now handled by explicit
capability failure, not a live read substituted for a projected state.
Actual allocated-basket exits remain positive through all four aliases and
produce identical receipts and state. See `10-exit-quote-capability.log`.
The optional missing FullSpread projection interface remains a separate
requirement under FS-HOOK-04.

The old Balancer requested-share premise was invalid when the actual local
conversion returns input. Both FullSpread configurations now prove exact
rollback, while a real fully consuming SE retains the positive local-plus-
share payout. See `12-share-exit-conversion-contract.log`.
