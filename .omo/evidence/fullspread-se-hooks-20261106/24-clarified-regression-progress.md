# Clarified liquidity regression follow-through

The first restored integration run, `23-clarified-family-integration.log`,
ran 479 suites: 5,089 passed, 65 failed, zero skipped. CP, Balancer,
FullSpread and the five native SY consumer files had no failing tests.
CP and Balancer implementation tasks are closed again; the other family
tasks remain open until their corrected runtime gates pass.

The restored DETF-only run, `23-restored-detf-lifecycles.log`, ran the same
9,557-case inventory as the preceding narrow DETF gate: 7,542 passed and
2,015 failed, compared with 5,485 passed and 4,072 failed before restoring
single-leg joins. This is not a fresh whole-repository result.

## Observed causes and current fixes

- The Orbital and Curve FullSpread quote mismatches followed conversions
  with paid trades priced against live, rather than projected, SE state.
  Preparation now completes paid in-kind trades first. Caller-only SE
  conversion then supplies native mint components, so ordinary mint
  entitlement needs no invented post-conversion rate.
- Native dust that cannot buy every required leg now quotes zero before
  attempting unnecessary SE conversions. Genuine rate, disablement and
  dependency failures are not swallowed.
- The exact failing Weighted decimal binding was traced to `UnwrapFailed`
  during a residual join preview: redeeming the full input quoted a native
  pair unit, but the selected fractional redemption rounded to zero.
  The sizing path now forward-checks that selected amount. The initial
  default-binding trace passed and is not misrepresented as the failing
  reproduction; the decimal trace is
  `23-weighted-decimal-residual-trace.log`.
- Stale Orbital and Weighted tests again require positive paid joins,
  owner-at-MIN operations within the curve's bounds, ambient isolation,
  and real FoT rejection after a successful untaxed control.
- Orbital genesis assertions distinguish actual caller-acquired SE shares
  from the SE's separate protocol fee mint. Actual transfer logs verify
  the five-percent burn and reconcile total SE supply.
- The Curve Permit2 width test retains its positive funded control and
  exact oversized-transfer rejection. It no longer requires a positive
  redemption projection for more shares than actually exist.
- The Curve decimal single-join smoke uses a rated/swap-balanced book
  rather than the retired invariant-issuance fixture's deliberately
  10^(18-decimals)-skewed swap book. Deliberate skew tests elsewhere remain.

`24-clarified-quote-dust-regressions.log` is the pending focused validation
of these changes. No fix in this section is declared green merely from
source inspection or diagnostics. No DETF public API or economic issuance
formula was replaced.
