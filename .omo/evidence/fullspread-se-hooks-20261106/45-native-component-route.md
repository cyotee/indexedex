# Native-component residual route

## Baseline

Receipt `44-current-default-regression.log` records a successful full
Solar build followed by 28,319 passes and four failures across 2,659
suites (28,323 cases). All four failures are the existing 30,000,000-gas
burn/close calls for Orbital, Weighted and Curve with UniV3 SE backing.
No other default-suite failure is waived or deferred.

The complete Curve diagnostic in receipt 42 used 63,623,259 gas, with
61,394,934 spent in residual cleanup. A mixed caller basket was repeatedly
converted into one funding asset per leg, converted back inside the hook,
then mostly refunded because another native component limited issuance.
Scheduling changes did not remove those external conversions. Receipts
41 and 43 are rejected experiments; their production changes were removed.
The temporary uncapped diagnostic test was also removed.

## Implementation choice

Add an explicit optional hook interface,
`IUniswapV4SeBufferHookNativeLiquidity`, on the three affected families.
This is an implementation choice, not a new user product decision or a
change to the existing DETF public API. Existing address-listed joins
continue to reject pair/share duplication and retain their prior
proportional or sparse-input preparation behavior.

The new live-only route accepts ordered local/pair and SE-share maxima.
It performs caller-funded in-kind preparation on that native inventory,
retains both output components, and assembles only missing components.
It then applies the existing common native mint bound, ceil acceptance,
gross/net fee split and exact refunds against post-paid-trade books.
Rates price trades, not LP issuance. Genesis stays on its existing
pair-or-share-per-leg route.

Each family must install the preview and execution selectors and advertise
the interface through its actual package/facet metadata. Existing
authorization, deadlines, minima, locks, family curve limits and
disabled-vault restrictions remain applicable.

DETF detects the advertised capability once per sweep and offers held
native components before any consolidation. Supporting hooks retain
mixed refunds across retries. Existing single-route and all pair/share
basket-choice fallbacks remain: a zero native quote alone is not proof
that no capital is joinable.

The independent `DetfResidualAssertions` oracle retains every prior
assertion and additionally requires a zero quote for the complete native
basket. Final held balances remain booked exactly.

## Verification status

The shared interface, DETF dispatch, three family implementations and
stronger oracle are implemented. Receipts 46-48 validate their real-proxy
accounting, fees, refunds, authorization and metadata controls after
correcting test-oracle expectations. All four previously failing bounded
burn/close calls pass with their existing 30,000,000-gas limits.

Receipt 50 completes the full default suite with 28,402 passes and zero
failures/skips. A subsequent source-review correction concerns sequential
previews, not native-basket ownership; its evidence is in
`51-review-remediation.md`. Receipt 52 passes 28,409 cases, and receipt 54
passes all 28,411 cases after the last exit-side state propagation fix.
The final delta review approves the repair; see `55-final-delta-gate-review.md`.
