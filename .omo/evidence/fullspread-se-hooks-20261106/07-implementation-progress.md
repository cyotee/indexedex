# CP-single implementation checkpoint

## Refund callback coherence correction (2026-11-07)

The new real-token callback regression in `SwapReentrancy.t.sol`,
`test_joinRefundCallback_observesCompletedLpSupply`, reproduced a partial
ownership snapshot: accepted component books were committed before the raw
refund, but LP supply was still 194935886896179278136 at the callback versus
195911541010094655422 after return. `07-callback-red.log` records that failure.
The callback was reached through an ordinary, positive proportional join with
excess raw input; it does not depend on the unresolved single-input semantics.

`ClaimLib._commitBasket` now completes locked-floor, protocol, and recipient
LP minting before transferring refunds. ERC20Repo minting only updates storage
and emits Transfer; it invokes no receiver callback. The same operation lock
continues to reject the callback's nested exchange. Fresh LSP reported no
errors for the changed library and regression file.

Full-family validation after this production change completed successfully:
`07-callback-family.log` records exit code 0, 56 suites, 563 passing cases,
zero failures and zero skips. This includes the new callback regression and
the 256-run, 16,384-call invariant campaign with zero reverts.
Single-input semantics and remaining integration/release gates are still open.

Task 7 remains in progress. Core runtime paths are verified; the complete family
gate is not yet green.

## Implemented so far

- Append booked raw, booked SE shares and trusted registry to the existing repo;
  reuse localPairReserve as the separate native pair book, without moving slots.
- Initialize registry from the package deployment authority, reject unknown
  registrations, and use effective address/package disable during buffering.
- ClaimLib now assembles caller-only baskets, checks actual two-word receipts,
  accepts ceil quantities, returns excess and splits backed gross LP. Genesis
  supplies shares and redeems exactly floor(A/20), then uses normalized retained
  shares and raw input in the existing geometric seed shape, with floor once.
- Ordinary/share joins and previews use that kernel. Proportional pair/share
  exits allocate independent floor claims. Requested shares convert only the
  allocated local claim; disabled or incomplete conversion reverts atomically.
- External swaps include local+rated shares, pay local first, book refunds and
  disabled input, and deduct native books from pretransfer credit.
- Single-input joins and single-token exits use CP-priced internal trades of
  actual component baskets, followed by native component acceptance/allocation.
  The trade is separate from LP ownership: its working book stays in memory
  until the operation commits. Raw-input joins need no SE round trip; pair/share
  input joins perform only their caller-owned conversion after the internal trade.
  Exact-net execution caps accepted gross via the shared minimal fee inverse.
- Removed live split-facet growth-fee entry calls, withdrawal growth minting,
  ambient dust reinvestment and projected dust-growth supply.
- Updated native SY/SE execution and ordinary previews, raw-input post-join claim
  projection, and sequential share-input component projections.
- Default and decimal `_depositBoth` test setup now acquires caller shares before
  first Hook LP funding. Added a registry genesis smoke assertion; started
  replacing superseded local-dust expectations.

## Validation so far

`07-claim-size-check.log`: `forge build --use solar <ClaimLib.sol> --sizes`
exited 0. ClaimLib runtime was 20,678 bytes (3,898 bytes below EIP-170).
This compiled the helper closure only: no dependent-facet or runtime pass is
claimed. Subsequent edits to other CP files still require the artifact helper.

Specific ClaimLib, InExecutionBase, DepositPreviewTarget, WithdrawalLib and
DFPkg diagnostics were clean. Several DepositCommon diagnostic requests timed
out while other family workers were editing; those are not clean receipts.

`07-smoke-build-plan.log` revealed CP's affected runtime closure also includes
dual-family roots. Parent requested a coherent frozen dual production frontier
from task st_01a1b32c before the smoke build. Do not compile that selected closure
while the dual worker is editing it.

The dual frontier subsequently froze. `07-genesis-smoke.log` records exit 0
and the executed default-ERC4626 registry/genesis test passing.
`06-08-components.log` records exit 0: H1 9/9, CP 18/18 and dual 18/18 shared
component cases passed against current dependent artifacts.

The first complete CP run (`07-cp-single.log`) executed 548 cases: 359 passed,
189 failed, zero skipped. Most failures were old pair-funded seeds, dust-only
custody assumptions, growth fees and ignored treasury LP. The parent migrated
the shared matrix/native reserve oracles; a scoped worker migrated nine legacy
suites. The parent then migrated the shared decimal suite and real invariant
genesis funding. Positive single-input decimal tests no longer hide failed
execution behind try/catch or broad ratio early returns.

`07-matrix-components.log` executed 370 cases: 366 passed and four failed.
The four were traced to two stale "no prepayment stranded" zero-balance
assertions, an under-consumption fixture that changed the hook's SE without
changing its TestBase funding/provider binding, and the removed identity-wrapper
membership exception. Their corrections preserve booked local balances, fund
the actual bound SE, retain the credit attack on a valid member leg, and add
an explicit rejected identity-binding control.

`07-cp-single-r2.log`: 562 tests in 56 suites, 561 passed and one failed,
zero skipped. The invariant completed 256 runs / 16,384 calls / zero reverts;
the deterministic lifecycle also passed.

`07-identity-trace.log` reproduced the sole remaining negative-test failure:
`processArgs` correctly reverted `TokenNotInVaultTokens`, but `expectRevert`
consumed it inside the deployment helper, which then called `calcSalt(0x)` and
reverted while decoding empty arguments. This distinguishes that test-harness
failure from wrong validator errors or accepted invalid membership. The test
now targets `hookPkg.processArgs` directly. `07-identity-green.log` records
that same negative test passing, exit 0. No production change was made for it.
The complete current CP family therefore has 562 passing unique tests.

## Pending requirement clarification

The parent asked the owner whether single-input joins may perform paid internal
trades and apply the component mint against the post-trade book. The alternative
is strict original-book funding and rejection when caller-only conversions
cannot supply every positive component. The question is pending; no owner
approval is inferred from test results or worker messages.

The implementation currently uses the first interpretation. FS-HOOK-07's
prohibition on using incumbent local balances to assemble contributions makes
that interpretation an explicit acceptance question, despite the plan's
positive single-input routes. Until answered, task 7 is not closed and these
runtime receipts prove implementation behavior, not resolution of that wording.

## Still open

- Complete runtime validation of the migrated fees, genesis, refunds, decimal
  and alias cases, including the new independent post-trade backing assertions.
- Verify every active secondary/composed projection and all owner/PM/SE/SY/
  Permit2 paths. Do not accept dead reference methods as proof of coverage.
- The older aggregate Target is explicitly uninstalled/reference-only; installed
  targets are the split facets. Its behavior must not be mistaken for runtime.
- Confirm all final component/preview semantics through actual receipts, full
  suite and code-size gates. Do not suppress failures or claim release readiness.
- Investigate callback coherence before release: `_commitBasket` publishes
  native fields before refund transfers and mints LP afterward. Add a real
  refund-callback observer to determine whether public supply/book views can
  expose a partial operation, then fix any demonstrated inconsistency. This is
  an open engineering verification concern, not yet a confirmed runtime finding.

Other family source handoffs currently exist in 06, 09, 10 and 12 implementation
notes. H1's independent custody suite passed three tests in `06-custody.log`;
its FullSpread component suite and complete family validation remain pending.
