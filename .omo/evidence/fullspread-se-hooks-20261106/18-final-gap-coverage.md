# Final acceptance-gap coverage

Date: 2026-11-07.

## FS-A03: actual double initialization

`InitializationReplay.t.sol::test_doubleInitializationAbortsRealProxyConstruction`
passed in `18-initialization-replay-r2.log` and in the integrated gate.
It reaches the real package's `AlreadyInitialized()` revert on the second
initialization. Failed construction leaves no proxy code, no retained
callback registration/arguments, and no initialized storage. Registry
membership is unchanged.

The same address, package arguments and production proxy creation code then
succeed with replay disabled. The control is registered through the real
owner-only vault registry and performs a real bundle deposit, including the
1,000-share floor and actual recipient LP.

The test uses a controlled non-SUT callback driver because the production
factory deliberately never initializes twice. It verifies the production
proxy creation-code hash and delegates normal initialization/finalization to
the real factory implementation. The package is deployed through the real
manager registry with a distinct binding salt; production facets, package,
proxy, manager and registry are unchanged. There is no SUT subclass,
replacement bytecode, storage injection or impersonation. This is the
documented failure-mode dependency exception in
`docs/agent/INDEXEDEX_AGENT_LAW.md` testing ladder item 5, not a claim that
the ordinary factory has a public replay operation.

The first attempted fixture used the canonical package service's fixed salt
and correctly hit `PackageBindingMismatch`; it was not bypassed. The retry
uses the existing binding-test pattern of a distinct registry package salt
and independently verifies its binding hash.

## FS-A34: both own backing deltas

`AlreadyUnlocked.t.sol::test_borrowedNonzeroOwnDeltaBareReverts` now covers
both backing currencies with one native unit and one whole-token unit.
The non-SUT caller actually transfers funds and calls the real manager's
`settleFor(vault)`, then verifies the exact positive own delta before vault
dispatch. Each vault entry rejects with the required bare revert; complete
vault/pool state, caller balances and allowances restore, and both deltas
are zero after the outer rollback.

The case passed in the integrated gate. Existing inner-return observations
also prove both vault deltas close while foreign outer debt remains.

No negative idle-vault debt was fabricated. The production
`ExecutionPreparation.ownDeltasZero()` predicate compares both signed deltas
to zero, with no positive-only branch. Runtime evidence covers both real
own-credit branches and foreign debt; this source observation establishes
the sign-neutral guard without claiming an unexecuted negative-debt trace.
FS-A34 requires nonzero rejection, not a separate artificial signed-state
construction.

## Remaining capability boundaries are explicit

The missing FullSpread projected-state interface is not added. Unsupported
weighted sequential views fail closed; actual exits remain positive.
Share-only payouts whose actual conversion refunds input roll back;
fully consuming positive controls remain. These are documented in
`17-capabilities.md`, not counted as invented interface support.
