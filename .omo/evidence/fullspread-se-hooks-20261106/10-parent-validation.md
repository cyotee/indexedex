# Weighted parent validation - 2026-11-07

`10-weighted.log` records the serialized Solar build and first full-family
run on the current shared transition helper: 74 suites, 863 cases,
806 passed, 57 failed, zero skipped; exit code 1.

Failures include caller-conversion `UnwrapFailed`, sequential preview/receipt
differences, dust behavior, stale native/retained-share fixture expectations,
three parameterized genesis-error assertions, two uninitialized PoolManager
rollback fixtures, a partial-book funding failure, owner-at-floor protocol LP,
and the invariant/deterministic lifecycle. No failure is waived.

Source inspection identified a likely shared cause of several conversion
failures: `_assemblePreview` and `_assemble` first convert pair input to shares,
then select another share-to-pair conversion from the just-minted shares.
Rounding can select a one-share redemption with zero output. The existing
positive fee/join test is being traced in `10-pair-assembly-trace.log`.

That trace confirmed a redundant one-share redemption returning `(0, 0)`
after the pair-funded conversion. Both assembly paths now select conversion
direction from the caller's original basket: pair inputs are not redeemed
again merely because their conversion just minted shares. Component limits
still determine accepted amounts and refunds. No failing test assertion was
changed for this correction. Fresh LSP reported no errors; full-family
validation is running into `10-weighted-r2.log`.

## Subsequent receipts and current frontier

- `10-weighted-r2.log`: 826 passed, 37 failed. The redundant-conversion
  correction cleared the positive fee/join, hostile-token setup, and ordinary
  receipt failures without assertion changes.
- `10-weighted-r3.log`: 839 passed, 24 failed. The quote Book now carries
  optional opaque SE states through proportional allocation, share redemption,
  subsequent swaps and final conversion in a single-token exit. Rate and
  conversion queries use the state produced by preceding operations when
  supported; unsupported SEs retain ordinary preview behavior. Thirteen
  sequential protocol-matrix mismatches cleared without changing their tests.
  FullSpread cross-leg parity is still failing and remains open.
- `10-weighted-r4.log`: validation is pending after fixture corrections.
  Genesis assertions now distinguish retained SE shares from raw coordinates,
  including address-sorted decimal layouts. Custody rate assertions include
  the local component. The positive redemption test requests a real local
  deficit. Parameterized genesis errors pin both addresses. The outer-manager
  rollback fixture uses the initialized dynamic-fee product key and asserts
  it is live before the failing settlement. Owner-at-floor funding includes
  protocol-owned LP transferred by its holder.

The persisted invariant counterexample now reaches accounting successfully
but is only one call long. Its campaign coverage assertion previously assumed
every replay had at least 24 calls. `afterInvariant` now first checks the
replayed accounting, then completes any missing deterministic actor/action
prefix and retains every campaign assertion. A one-call replay regression was
added. No persisted failure or cache was deleted.

The refund callback concern also exists in weighted `_accept`: it updates and
refunds one component at a time, and `join` mints LP only after `_accept`
returns. This is a source finding awaiting a real callback regression.

Single-input paid-swap semantics remain pending owner interpretation. These
runtime results do not establish compliance with that unresolved requirement.

## Latest receipts and refund correction

`10-weighted-r4.log` completed with 857 passing cases and seven failures
(864 total). The deterministic replay regression and invariant campaign
passed. Remaining failures are two FullSpread cross-leg preview mismatches,
one partial-book funding case, one full-debit expectation, one retained-local
expectation, and two Aave loop PoolManager cases.

`10-callback-red.log` proves the refund observer saw old LP supply
97467943448087689543 instead of final supply 98443597562003047314 during a
real excess raw-token refund. The new test also checks all public native
components when their query is usable during the callback.

Weighted acceptance now commits every component without external refunds,
then completes the floor/protocol/user LP mints, then transfers the unused
caller basket. Fee-recipient lookup occurs before that commit. Fresh LSP
reported no errors. `10-callback-and-traces.log` is the pending validation
receipt, also collecting the partial-book and Aave loop failure traces.

`10-callback-and-traces.log` passed the real refund observer. Its other traces
showed an unfunded post-join test swap and a local-only Aave output unnecessarily
redeeming a sub-native-unit share amount, which reverted `ZeroLoopAmount`.
Weighted output planning now tests the native-unit budget against local
inventory before selecting any SE redemption, including internal liquidity
swaps. The Aave F6/F9 positives remain unchanged.

The partial-book fixture now funds its separate final swap. The single-input
debit test checks actual full pull and exact refund Transfer receipts instead
of assuming its entire declared budget is spent. The retained-local negative
uses real booked genesis inventory. A separate positive asserts the explicit
`docs/vaults/PRETRANSFER_DIRECTIVE.md` contract: staged unbooked input may be
used up to the declaration, while the unrequested remainder stays unbooked.

`10-weighted-r5.log` completed with 864 passing cases and two failures,
866 total across 75 suites. This includes the callback fix, both Aave loop
positives and the invariant campaign. The only failures are
`test_HB44_crossLegExitAliasesPayActualCallerBasket` in the two- and three-leg
FullSpread component adapters. Observed output versus preview:

- Two legs: 9491899938408568528 versus 9491891288930034384.
- Three legs: 17857215545322608174 versus 17857191995198863774.

These are unresolved failures, not tolerance-based passes. FullSpread does
not advertise the optional transition interface used by sequential quotes.
FS-HOOK-04 and task 13 forbid inventing that interface or substituting live
state for a projected post-conversion state. Further integration work must
resolve the actual route without silently changing this requirement.
