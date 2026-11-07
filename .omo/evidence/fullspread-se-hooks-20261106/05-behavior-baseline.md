# Shared behavior red-before gate

Date: 2026-11-06. Task 5 establishes executable behavior and a red-before
baseline; it does not claim implemented family economics.

`HookComponentAccountingBehavior.sol` separates custody-only behavior from LP
behavior and its optional supported-exact-net extension. Every family has a
concrete `*_ComponentAccounting.t.sol` adapter using its actual registry proxy
and a real FullSpread vault. H1 has four custody cases and no LP cases. Each
LP family has eighteen cases. Dual and orbital exercise their deliberate
exact-net rejection; no success is faked by an early return. The other four
families exercise the supported forward-budget exact-net execution.

## Executed evidence

- `05-behavior-red.log`: initial CP-only iteration, exit 1, thirteen cases,
  four passed and nine failed. Its exact-net test was then corrected to use
  the existing forward-budget route instead of demanding a new exact-out view.
- `05-all-families-red.log`: Solar compile succeeded, process exit 1;
  seven suites, 112 cases, 34 passed, 78 failed, zero skipped.
- One H1 failure was an incorrect new test expectation: underlying FullSpread
  minting charges its own fee. The test now verifies the exact clamped fee,
  treasury receipt and gross/net supply conservation instead of equating user
  output with total underlying issuance. `05-h1-custody-correction.log`:
  Solar compile succeeded, exit 0, that one case passed.

The resulting unique-case baseline is 35 passing and 77 red product
requirements. Those 77 cases must become green in tasks 7-12. None is waived.
H1's four passing custody cases do not replace task 6's explicit retained
books, registry provenance and receipt reconciliation work.

## Covered shared oracles

The tests use direct bounded integer products, not SUT previews, for ceil
contributions, floor exits, component dilution, backed gross/fee/net splitting,
minimal fee gross-up and the 5% share burn. They measure actual token custody,
caller debits/receipts, SE supply, LP balances, locked floor and allowance
rollback. They cover pair-funded and preowned-share joins, two-holder exits,
ambient transfers before and after genesis, changed underlying markets,
different redemption proceeds, local-only and deficit output, address/package
disable, permitted exits, disabled preowned-share joins and re-enable.

## Family completion obligations

The common baseline is not the entire release scenario matrix. Each family
task must wire its other ordinary/flexible/Permit2/SE/SY aliases to these same
semantics and extend its concrete cases for exact local equality, zero/partial/
all refunds, zero/mixed components, inactive and zero-recipient fee settings,
rounding boundaries, share-requested and cross-leg exits, short/staged funding,
deadlines, reentry and outer-manager rollback. Retain existing family negative
suites and update only explicitly superseded economics/setup.

Task 10 covers weighted n=2/3/8 and partial books, task 11 covers fixed four,
and task 12 covers Balancer n=2/5 and interior validation. Task 16 extends the
existing invariant handler rather than creating a separate ledger. Task 13
checks all facade routes; tasks 15-20 and F1-F4 reconcile executed evidence.
No abstract method, source occurrence or green custody-only case closes an
unexecuted ownership assertion.
