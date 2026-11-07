# Balancer stable parent validation - 2026-11-07

`12-balancer.log` failed before runtime discovery: the standard family
TestBase used `IStandardExchangeIn` in its share-funded seed helper without
importing that symbol. The missing interface import is restored; fresh LSP
reported no errors. The serialized retry is `12-balancer-r2.log`, pending.

The parent added a real excess-input refund observer using the existing
four-leg production package, complete sorted token records and share-funded
genesis. It checks LP supply and public native component reserves during the
refund callback. Source inspection found `_commitBasket` refunding one leg
at a time before `_mintBacked`; the observer's runtime result is pending.
No callback defect is claimed reproduced until that test reaches its callback.

The paid internal-swap interpretation remains unapproved, as corrected in
`12-implementation.md`. No family or release gate is closed here.

## First runtime receipt and corrections

`12-balancer-r2.log` compiled successfully and executed 701 cases across
60 suites: 655 passed, 46 failed, zero skipped, exit code 1.
The observer reached a real refund and saw old LP supply
98749760792222375754 versus final supply 99737258400144599511.

The next frontier corrects three production issues:

- Pair-funded basket assembly no longer performs a second share redemption
  merely because the first conversion minted shares. Share-input paths retain
  their selected redemption and native component limits.
- Backed LP and every component book are completed before refunds. The
  observer remains unchanged.
- A requested-share single exit now adds the final cross-leg conversion to
  its already allocated share payout instead of overwriting that claim.

The unfunded-pretransfer fixture now tests real positive booked local
inventory. Capacity assertions count hook-local input plus the underlying
SE's booked remainder. Fresh LSP reported no errors in all four changed
files. `12-balancer-r3.log` is the pending complete-family receipt.

Remaining observed failures also include sequential preview state, exact-output
liquidity sizing/payout, all-refund input, share-requested conversion, and
token-count round-trip assumptions. In particular, the exact-token exit
adapter currently pays output surplus to the caller rather than retaining it
as backing; its output contract still needs correction and validation.

`12-balancer-r3.log` completed with 671 passes and 30 failures out of 701.
The real callback observer passed. Redundant-conversion join mismatches and
the migrated capacity/local-book assertions cleared. The preserved share
payout now exposes its smaller remaining sequential-quote mismatch.

The current quote frontier carries optional opaque SE state through the
allocated payout, each internal trade, provider valuation, and final
requested-share conversion. It distinguishes local-only native output from
a fractional rated remainder. Standard previews remain the fallback when
transition support is absent. Fresh LSP reported no errors in UnitsCore and
LiquidityCore. `12-balancer-r4.log` is the pending complete-family receipt.

`12-balancer-r4.log` completed with 687 passes and 14 failures. Sequential
exit mismatches cleared except the EtherFi fixture, whose trace exposed a
missing `treasury()` dependency getter rather than a fabricated quote state.

`12-exact-output-and-traces.log` then recorded 13 passing targeted cases and
seven failures. Both exact-token exit aliases now retain output surplus in
the correct local/share book and pay only the requested amount, including
when caller and recipient are the same address. Native SY callers retain
their uncapped exact-LP-input contract. The four mixed-decimal exact-output
cases passed. Round-trip tests now actually unwind all intermediate raw
refunds before applying their unchanged no-profit and restored-balance
assertions; all four token counts passed.

The current frontier additionally:

- supplies the hermetic redemption manager's real fee-holding address through
  `treasury()`, allowing its advertised transition quote to read that dependency;
- makes exact-net funding refinement progress multiplicatively across integer
  plateaus, while returning only a forward-verified budget;
- gives the real all-input-refund positive an imbalanced, caller-funded seed
  so its tiny input can buy nonzero output after trading fees and rounding.

Fresh LSP reported no errors. `12-balancer-r5.log` is the pending full-family
receipt. The real FullSpread requested-share positive still fails on an
incomplete local conversion; it has not been relabelled as a passing rejection.

`12-balancer-r5.log` completed with 694 passes and seven failures. EtherFi
and the exact-output sizing calls now execute. Four round-trip assertions
were still requesting half the conservative funding budget rather than half
the actual debit; they now use `used / 2` and retain exact recipient payment
and fewer-than-minted LP burn assertions. The five-leg all-refund fixture has
a second buffered leg, so its imbalanced seed now acquires real shares for
every buffered leg before reducing the primary leg's contribution.
`12-funding-budgets.log` is the pending targeted receipt for those corrections.

`12-funding-budgets.log` passed both all-refund topologies and three
token-count round trips. The five-leg round trip still exposed a test
valuation mistake: even half the original-token debit can exceed the claim
backing its newly minted LP when other purchased components are refunded.
The requested output now comes from the executable half-position withdrawal
quote. Exact recipient payment, actual input debit, and the strict
fewer-than-minted burn assertion remain. The new targeted receipt is
`12-exact-output-position.log`, pending. Fresh LSP on this final test revision
timed out; its compiler receipt is required.

`12-exact-output-position.log` subsequently compiled and passed all four
token-count exact-output round trips. Together with the preceding targeted
run, this clears five of the seven failures in the last full-family run.
The two FullSpread requested-share positives remain unresolved; no complete
family pass is claimed.
