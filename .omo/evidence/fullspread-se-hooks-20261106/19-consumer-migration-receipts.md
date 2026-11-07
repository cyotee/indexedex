# Downstream consumer migration receipts

Updated 2026-11-07. These are scoped results, not whole-repository clearance.

## Wings: passed

`19-wings-consumer-migration.log`: artifact-first Solar runner, exit 0,
three suites, 13 passed, zero failed/skipped.

The two five-case suites are
`WingsApexRecurrenceConsumerConservationTest` and
`UniswapV4UpperLowerWingsStandardExchangeVaultFamilyConsumersTest`.
Both execute positive Single CP, Dual, Orbital, Curve and Balancer
share-funded joins and share-output exits.

The shared fixture now binds Dual's second pair to its actual SE member,
with a real provider, while preserving implicit share input/output.
Exit assertions independently allocate each native component using actual
LP supply, then reconcile transfer logs, actual newly minted shares,
recipient payout, remaining components and total SE supply. Opposing
currency leakage assertions remain.

`UniswapV4UpperLowerWingsStandardExchangeVaultWeightedConsumerTest` passes
all three cases, covering all two-leg buffered masks under both manager
relations, arities three through seven, and homogeneous eight-leg Wings
under both manager relations. Shares are acquired before genesis, then
positive pair-funded later joins and exits retain exact preview/receipt
assertions.

Logged consumer join subcall gas includes neither a cold outer transaction
receipt nor the FullSpread gas-gate method. It is not substituted into the
nine-configuration FullSpread gas ledger.

Parent inspected all four edited files before execution; child LSP
diagnostics reported no errors. No production Wings code was changed.

## DETF bootstrap: passed; complete lifecycle: failed

`19-detf-bootstrap-matrix-r2.log`: 355 passed across 351 suites, exit 0.
`19-detf-lifecycle-after-bootstrap.log`: 5,485 passed, 4,072 failed across
559 suites, exit 1. Exact scope, opening-price correction and remaining
diagnostic categories are in `19-failures.md`.

## Staking migration: passed

`19-staking-migration-after-bootstrap.log`: artifact-first Solar runner,
exit 0, all ten `TokenStakingMigrationScript` tests passed, zero failures
or skips. This includes the eight previously blocked tests, real funded
chunked migration, principal/reward conservation, claims, and owner,
minimum-output and deadline checks. No staking source or test expectations
were changed.

## Native SY: passed

Parent inspected all five migrated native SY files. Initial runs passed
44 of 45 tests; the remaining Balancer case expected `Slippage()` where the
standard exact-output facade first executes an unavailable forward quote.
The underlying single-join method and standard facade expose different
preflight errors. Parent corrected preview and execution expectations to
`ExchangeOutNotAvailable()` from the inspected dispatch path, retaining
exact rollback and positive exact-output redemption assertions.

`19-native-sy-migration-r3.log`: compiler successful, eight suites,
45 passed, zero failed/skipped, exit 0. The earlier r1/r2 receipts remain
failures, not green results. Weighted LSP fresh diagnostics timed out;
compiler results, not that timeout, establish compilation. Balancer LSP
diagnostics after the correction reported no errors.

## Wrapper bindings: passed

Parent inspected all seven migrated files and their relevant production
exit paths. All seven LSP checks reported no errors.

The wrapper rebase subject is now separate from the hook's valid,
non-rebasing member-token control. Share-address identity binding still
rejects; no rebasing underlying is substituted into the hook configuration.
Standalone wrapper tests retain positive/negative rebase, own-share
processing, donation accounting, transfer-rebase rejection/recovery and
disabled redemption. These do not claim rebasing-underlying hook support.

Parent corrected two source-level expectation mistakes before execution:
CP share-output exits convert the allocated local component rather than
returning a mixed share/pair payout; CP and Orbital disabled share-output
conversions reject without burning LP, while ordinary pair-output exits
remain positive.

`19-wrapper-binding-migration.log`: 36 passed, three failed, exit 1.
All three failures share Balancer's seed setup. The actual trace in
`19-wrapper-balancer-trace.log` reaches `MaxImbalanceRatioExceeded()`:
the wrapper's ten-decimal share offset produces native inventory 1e10
larger than the other legs under the family's existing rate-free seed
normalization.

The attempted zero-offset control did not change that configuration:
the real wrapper package clamps offsets below its minimum to ten.
`19-wrapper-binding-migration-r2.log` therefore still failed those three
cases (37 passed, three failed).

The corrected positive control uses four real wrappers with the same
ten-decimal offset, preserving comparable native seed units and rated
reserve units. A separate one-buffered/three-raw high-offset control retains
the exact imbalance rejection. The standalone rebasing wrapper remains
separate. Neither native seed normalization, the stable curve's imbalance
bound nor production code was changed. This is a configuration boundary,
not a claim that arbitrary wrapper offsets seed the stable family equally.

`19-wrapper-balancer-balanced-seed.log`: all seven Balancer cases passed,
zero failures/skips, compiler successful, exit 0. The other six suites
retain 33 passing cases from r2. Together these receipts cover all
40 current cases across seven suites. Foundry counts the invariant campaign
as one grouped test plus the deterministic sub-quantum regression. Its
expanded report asserts all four properties: zero fee type, separate hook
custody, valid member binding/independent rebase subject, and backing equal
to held assets. The campaign ran 16 sequences and 128 calls, zero reverts,
with every handler selector reached.
