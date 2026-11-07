# Orbital parent validation - 2026-11-07

`09-orbital.log` records the serialized Solar artifact build and full orbital
family run. Compilation succeeded. Runtime: 69 suites, 690 cases, 646 passed,
44 failed, zero skipped. This is a failing validation receipt, not task sign-off.

The failures group into:

- Single-input preview/execution mismatches across the protocol/decimal matrix,
  the direct zap suite, and the native SY alias.
- A projected quote-rate failure that does not fail closed.
- Dust rejection selectors in nine matrix cases.
- Five unavailable-output preview assertions expecting the underlying
  `ExchangeOutNotAvailable` instead of the observed hook `InsufficientTokenOut`.
  The local-only positive operations preceding those assertions completed.
- Initial pair-input rejection expecting only a four-byte selector although
  the observed `InvalidRoute(address,address)` carries arguments.
- A twenty/twenty-one-share genesis boundary returning `InvalidExchangeReceipt`.
- An owner-at-floor fixture retaining fee-recipient LP after withdrawing
  only the owner's LP.

No failing assertion was relaxed. Root-cause work remains pending.
Single-input paid-swap interpretation also remains unresolved; this run does
not approve it.

The separate acceptance source audit is
`18-acceptance-source-audit.md`. Its 48-row inventory identifies additional
coverage gaps and expressly makes no runtime claims.

## Genesis boundary correction

`09-genesis-trace.log` identifies the twenty-share failure before hook funding:
the real ERC4626 SE's dilution mint fee makes one SE share redeem to zero
receipt units. The positive twenty/twenty-one-share test now disables the real
SE fixture's usage fee before acquisition and independently verifies that one
share returns one paired unit. A separate negative preserves the original
fee-bearing zero-receipt setup and verifies atomic rejection.

`09-genesis-boundaries.log` records exit code 0 and all nine boundary cases
passing. This closes one original failure and adds one explicit negative;
43 original orbital failures remain unresolved.

## Transition capability correction in validation

The D41 projected-rate failure exposed a capability mismatch. ERC4626 SE
advertises `IStandardExchangeTransitionQuote`, but not the distinct optional
unavailable-unlock projection interface. Orbital's external-exchange projection
and shared snapshot helper were testing the latter before using ordinary
transition quotes, so they silently fell back to current-state quotes.

The shared helper now probes transition support separately for snapshots;
unavailable-unlock projection still requires its own interface. Orbital's
external-exchange path uses the transition probe. Fresh LSP reported no errors.
`09-transition-capability.log` records exit code 0 and 23 passing cases across
the D41 projected-rate suite, ERC4626 matrix and direct zap suite. The original
rate-failure test now fails closed correctly; exact preview/execution tests
also pass without changing their assertions.
`09-orbital-r2.log` is the pending complete-family validation receipt.
This shared source change requires downstream revalidation; earlier family
passes remain historical evidence, not validation of the new shared frontier.
It neither resolves nor approves the single-input funding interpretation.

## Complete-family follow-up

`09-orbital-r2.log` completed with 675 passing cases and 16 failures out of
691. All original sequential quote mismatches and the projected-rate failure
cleared. Remaining failures were nine dust cases, five exact-output preview
error assertions, one parameterized genesis error assertion, and one
owner-at-floor fixture.

The next frontier makes these changes:

- A three-coordinate single-input plan returns zero for input below three
  native units, before consulting conversion dependencies. Execution rejects
  that same impossible split with `ZeroAmount`. The existing positive quote
  and atomic dust-rejection tests remain unchanged.
- The shared behavior accepts an exact revert payload hook, defaulting to its
  existing no-argument selector. Orbital supplies both expected InvalidRoute
  addresses; it does not accept arbitrary parameter values.
- FullSpread exact-output inverse previews return zero. Orbital's existing
  inverse sizing code translates that to `InsufficientTokenOut`; its tests
  now pin that exact hook error instead of expecting an underlying execution
  error from a view. Positive local-only payment and unchanged share-book
  assertions remain.
- The owner-at-floor fixture transfers protocol-owned LP from its holder to
  the owner before withdrawing all circulating shares. It retains the exact
  1,000 floor and positive owner-only join assertions.

Fresh LSP reported no errors in the five changed files. The serialized
complete-family receipt for this frontier is `09-orbital-r3.log`: exit code 0,
69 suites, 691 passing cases, zero failures and zero skips. The invariant
campaign passed 256 runs and 16,384 calls with zero reverts.
Task 9 remains pending the single-input interpretation and final integration,
size, gas and acceptance gates.
