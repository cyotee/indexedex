# Release-gate history and final disposition

Final 2026-11-07 disposition: `54-final-default.log` passes all 28,411
counted cases with zero failures/skips. Source-review blockers are closed;
the final delta is approved. The global size command's 13 test/vendor
exceptions remain explicitly classified in `49-size-classification.md`.
No in-scope test failure is waived. See `56-final-summary.md`.

Everything below records superseded investigations. In particular, the
earlier funding-model timeout is not a current unresolved user decision.

## Historical consumer gate

After consumer migrations, `19-post-consumer-release.log` records successful
plain Solar compilation followed by size exit 1 and default-suite exit 1.
`19-post-consumer-default.log`: 2,659 suites, 24,143 passed,
4,144 failed, zero skipped. All 327 failing suite identities are DETF
suites or direct DETF consumers; no remaining non-DETF hook, native SY,
Wings or standalone-wrapper suite appears in the failure footer.

The 4,144 failures comprise the 4,072 from the narrower DETF run plus
72 tests outside that run's roots: three wrapper/DETF compositions,
three funded-binding tests, 65 common reserve-liquidity tests and one
leftover-preview test. Exact counts were reconciled across the complete
failure footer, not a sampled prefix.

The refreshed size table has the same 71 hook/FullSpread measurements,
and every listed DETF adapter artifact fits. Thirteen other identities
still exceed a size limit. The test-only Wings fixture grew from 39,874
to 40,333 runtime bytes; it was already over the limit in this session's
earlier receipt, but is not described as untouched or baseline-clean.
Exact current values are in `19-final-size-receipt.md`.

Task 19 remains open. The parent requested a scope decision before
redesigning ongoing single-payment DETF funding into an explicit
conversion-and-complete-basket route. No response or authorization has
been inferred. The existing hook pre-intake rule is not being reopened.

## Earlier complete gate

`19-full-default-hermetic.log` records the completed command
`FOUNDRY_PROFILE=default forge test --use solar --isolate`, exit 1:
19,200 tests passed and 9,065 failed. The 5,111-pass targeted integrated
gate remains valid for its selected suites, but does not establish consumer
compatibility or release readiness.

The complete artifact refresh and plain Solar build exited 0 in
`19-all-artifacts-build.log`. The size command exited 1 in
`19-release-sizes.log`. All 71 affected artifact identities fit runtime and
initcode limits; maximum affected runtime is 19,419 bytes. Thirteen other
artifact identities exceed at least one limit; exact values are in
`19-final-size-receipt.md`. No before-change baseline establishes these as
pre-existing, and no limit was raised.

## Reproduced consumer failure

`19-detf-first-bond-trace-r2.log` executes
`UniswapV4Detf_Quad_Adversarial_A0Crops.test_A0_donateBeforeFirstBond_cannotFreeMint`
with verbose traces: zero passes, one failure, exit 1. First-bond execution
calls `requiredFirstBondTokens()` and then fails
`FirstBondBelowMinimumLiquidity()` before reaching the hook join.

The failing DETF `_joinFirstBondFullBook` interpreted required token identities
as pair keys for `_firstBondOtherPayment`; CP, dual, Orbital and Curve hook
discovery now uses SE shares for buffered genesis legs. Weighted still returns
pair identities. This is not a claim that all getters changed identically.

The adapter now resolves each required leg to its canonical pair, keeps
opening-price and payment previews pair-denominated, and acquires shares
before hook intake. Actual conversion output and refund are reconciled
against custody; the caller receives its conversion refund. The lead payment
is pulled once. The hook still performs its own five-percent redemption.

`19-detf-bootstrap-adapter.log`: affected-artifact compilation passed;
the real Quad suite ran five tests, four passed and one failed. The original
donation-before-first-bond test, existing partial-credit test, and new
`test_firstBondMapsShareRequirementsToPairPayments` all pass. The latter
asserts pair-denominated discovery/previews, positive real LP and liveness,
one lead pull, each leg's actual retained shares/local redemption, and no
stranded caller capital. The CROPS lifecycle still fails `ZeroAmount()`.
This is a verified bootstrap correction, not a complete lifecycle repair.

The first wider bootstrap run exposed 84 opening-price assertion failures:
converting the pair payment into shares and then valuing those shares by a
redemption quote incorrectly reduced the opening-price basis by conversion
costs. The adapter now retains the actual consumed pair payment as that
basis, excluding any returned input; it does not apply a second liquidation
quote. Share-funded callers retain their existing share valuation path.
Payment previews use the same consumed-input basis.

After this correction, `19-detf-bootstrap-matrix-r2.log` passed all
355 tests across 351 suites, zero failures/skips, exit 0. Coverage includes
all four DETF hook families, production SE fixtures, decimal permutations,
opening-price policy, first-bond liveness, and donation-before-first-bond
controls selected by `[Ff]irstBond|acceptedBondTokens`.
`19-detf-bootstrap-matrix.log` remains the prior failed receipt, not a pass.
The complete DETF lifecycle gate then finished in
`19-detf-lifecycle-after-bootstrap.log`: 559 suites, 5,485 passed,
4,072 failed, zero skipped, exit 1. This is a narrower suite than the
original whole-repository run; do not subtract their totals as if their
test inventories were identical.

The complete failure footer (lines 21237-25940) contains exactly 4,072
failure identities. The largest diagnostic groups are 2,408 `ZeroAmount()`,
976 `MinAmountNotMet(1, 0)`, five donation-preview groups of 125 each,
and nine zero-LP-preview assertions. Other failures include old dust
expectations, retained-share/pair balances, expected-error mismatches,
two funded-callback positive controls, and one persisted invariant
counterexample. These diagnostic counts do not establish one root cause
for all cases; the invariant and residual conservation failures remain
open, not waived as stale assertions.

`19-detf-first-bond-trace.log` is NOT a passing regression: its exact
end-anchored method filter matched no tests. The corrected r2 filter above
actually executed the test. No source or test expectation was changed to
obtain either result.

## Other unresolved consumers

Read-only classification found 50 non-DETF failures: 28 invalid wrapper
identity bindings, three pair-funded Weighted Wings bootstraps, four old
Wings share-exit conservation assertions, eleven infeasible native SY
single-input join assertions, three old informational-rate expectations,
and one dual exit assertion conflating booked cash with ambient donations.
Eight token-staking migration failures also originate at DETF first bond;
9,007 failures are in DETF-named suites. This classification does not prove
masked downstream assertions will pass.

Separate source-only migrations cover native SY tests, Wings consumers,
and wrapper fixtures; their runtime validation remains pending. No existing
DETF positive lifecycle assertion has been replaced by an expected revert.

Live DETF single-payment mint/donation and multi-leg later bonds still lack
components required by the new complete-book acceptance rule. Acquiring
genesis shares does not solve that problem. Incumbent-funded assembly,
unbounded extra pulls, invented DETF issuance, and an unconditional switch
to the price-gate swap fallback are not adopted as fixes.

Task 13 is reopened. Tasks 19 and final release verification remain open.
The literal pre-intake/caller-only accounting decision is not reopened by
this report; downstream compatibility must preserve it and share-funded
genesis rather than restoring incumbent-funded basket assembly.
