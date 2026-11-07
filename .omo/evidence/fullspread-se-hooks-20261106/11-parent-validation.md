# Curve parent validation - 2026-11-07

`11-curve.log` records a successful Solar compile followed by 59 suites:
673 cases passed, 50 failed, zero skipped (723 total), exit code 1.
The failures include obsolete share-funded genesis/retained-share fixtures,
capacity/local-book expectations, dust rejection, refunded-input expectations,
owner-at-floor fee LP, and two genuine decimal exit arithmetic panics.
No failure is waived.

## Full-width Newton correction

`11-decimal-underflow-trace.log` reproduces the P6/R18 exit panic in
`Math.quoteExactInRated`, reached through the installed withdrawal preview.
The ordered rated reserves are
`[499482250145296174215000000000000, 499999999999961962030,
499999999999961962030, 499999999999961962030]`, input index 1, output index 0,
net input 36136072, and amplification 10000.

Independent arbitrary-precision integer evaluation found the invariant
316847265070611102519523408. The first Newton update overshoots to
785422700653663832280832075876925965743; its square exceeds uint256 even
though the eventual root and output fit. The original `y*y+c` therefore
panics before convergence.

The solver now computes the quotient of the full-width square and the
coefficient separately, including the exact remainder carry. This preserves
floor((y*y+c)/denominator), rather than changing convergence or rounding.
The independent vector expects output 18049320843520141448 and also checks
the post-swap invariant. Both originally failing real decimal routes remain
in the targeted validation.

Fresh LSP reported no errors. `11-fullwidth-math.log` records exit code 0
and six passing cases: the independent vector, existing invariant arithmetic
and fuzz checks, and both originally panicking real decimal exits.
Single-input interpretation remains provisional as recorded in
`11-implementation.md`.

## Fixture and dust follow-up

The decimal seed helper and direct flexible genesis test now acquire shares
for every funded buffered leg, not only leg zero. Permit2 custody assertions
subtract the required bootstrap burn. Exact-net and flexible single-input
tests account for actual payer refunds while retaining exact LP issuance
and fee conservation checks. Protocol LP is transferred by its holder before
the owner-at-floor withdrawal. The unfunded pretransfer negative now exercises
positive booked local backing rather than assuming zero physical custody.
Capacity tests include input retained in the hook's local book as well as
the underlying SE book.

Single-input execution rejects a forward-quoted zero gross before pulling
assets or attempting an unusable conversion; actual receipts still determine
accepted gross after funding. The existing one-unit ZeroAmount assertions
remain unchanged. Fresh LSP reported no errors in the eight changed files.
`11-curve-r2.log` is the pending complete-family receipt.

Source inspection also found that `ClaimLib.acceptBasket` refunds each leg
before LP minting completes in JoinCore. A real callback regression and
correction remain required; the current runtime receipts do not close that
accounting-visibility concern.

## Refund regression and complete-family receipt

`11-curve-r2.log` passed all 724 cases before adding the callback regression.
The first observer attempt (`11-callback-red.log`) failed its package's
ascending-token prerequisite; the fixture now sorts complete token records.
`11-callback-sorted-red.log` then reached the actual refund and reproduced
old supply 98725854490143380611 versus final supply 99713113035044814417.

JoinCore now finishes backed LP minting before the refund phase, and
ClaimLib commits all four components before transferring any refund.
`11-curve-r3.log` records exit code 0, 60 suites and 725 passing cases,
zero failures/skips. The observer checks final LP supply and all native
reserve getters at the refund callback. The invariant campaign passed
256 runs and 16,384 calls with zero reverts.

This closes the reproduced native-book/supply callback defect, not every
public metadata/quote observation during all callbacks. Cross-family facade,
metadata, size, gas and final acceptance checks remain open, as does the
single-input owner interpretation.
