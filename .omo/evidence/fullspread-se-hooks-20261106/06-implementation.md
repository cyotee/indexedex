# Task 6 - H1 single conversion custody

Date: 2026-11-06. Source-ready frontier for parent-owned serialized validation.
No build or runtime test was run. No runtime pass, gas pass, or release gate is
claimed. No out/cache writes, commits, installs, deployment, or delegation.

Authority: task 6 of
`docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`,
FullSpread PRD FS-OWN-34..37 and FS-HOOK-05..10, and gate notes 01, 03, 05.

## Owned production changes

All paths below begin with
`contracts/hooks/uniswap/v4/standardExchange/single/`:

- `UniswapV4SingleStandardExchangeBufferHookRepo.sol`: append trusted
  `vaultRegistry`, native `retainedPair`, and native `retainedShares`. Existing
  bindings and packed flags keep their slots. Ambient balances are not books.
- `UniswapV4SingleStandardExchangeBufferHookDFPkg.sol`: initialize registry from
  the immutable package deployment registry, independently of the zero feeOracle.
  Reject an SE absent from that registry. Preserve the existing shared membership
  correction, package arguments, salt, metadata, staged initialization, and cuts.
- `UniswapV4SingleStandardExchangeBufferHookCommon.sol`: reconcile both words of
  exact-input receipts against funded input/output balance deltas. For exact-out,
  reconcile returned consumption and actual output; retain unconsumed quoted
  input and output above the requested delivery in their respective native books.
  Verify actual manager take and settle amounts. Check effective address/package
  disable on wraps using the trusted registry; unknown entries and query failures
  never become enabled.
- `UniswapV4SingleStandardExchangeBufferHookTarget.sol`: wire all four modes to
  receipt accounting, clear both pair/share approvals, and use refund-preserving
  exact-input quote primitives. Exact-input delivers actual output; exact-output
  settles exactly the requested output, avoiding an orphan manager credit.

H1 has no LP supply, genesis, fee split, rated swap curve, local-first LP reserve,
join/exit facade, or seed helper to migrate. Retained conversion residuals are
not used to subsidize a subsequent caller. Pending manager input is measured
separately; an ambient transfer is neither credited nor swept.

The installed product remains the same 24-selector facet inheriting Target;
there is no alternate installed money implementation to patch. The package
still installs the existing basic/standard metadata facets and swaps init cuts
for the product facet at finalization. No selector, interface ID, component
binding list, public package field, or new linked library was added.
FactoryService continues resolving concrete artifact creation code.

Public previews retain their existing SE quote contract, including indicative
quotes while disabled. Actual wrap execution rejects disabled conversion before
taking input. FullSpread exact-output remains unavailable even with retained
custody; no synthetic exact-output or share-delivery route was invented.

## Tests authored

Under `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/`:

- Extend `UniswapV4SingleSEBufferHook_ComponentAccounting.t.sol`, preserving its
  original four custody positives. Add five tests for registry provenance and
  empty books, actual FullSpread refunds across two callers with ambient pair
  and share custody, unsupported exact-output with ample retained/ambient funds,
  real outer-manager rollback, and unknown registry entry rejection at both
  execution and package validation. Rollback snapshots now include native books.
- Add `UniswapV4SingleSEBufferHook_Custody.t.sol` with three tests: zero-refund
  accounting through all four installed modes with ambient balances; address
  disable; package disable. Each disable test rejects both wraps, executes both
  supported withdrawals, re-enables, and executes both wraps.

Storage inspection is read-only `vm.load`; no SUT storage injection, mockCall,
etching, subclass replacement, or SE double. The deliberately unsettled router
is test-owned and calls the real manager and installed hook.

Existing family suites remain independent: Routes covers zero amounts and four
modes; adversarial Accounting covers short exact-output credit and successful
fully funded control; Reentrancy covers hostile token callbacks; Donation covers
staged pair/share transfers; SeMatrix supplies real-SE conversion and receipt
cases, including exact-output-capable AMM dependencies. No deadline parameter
or LP alias exists on H1. No positive test was changed into an expected revert.
No LP fee/genesis expectation or seed helper applies to this family.

Existing shared primitive tests own malformed, over-refunded, all-refunded and
short receipt arithmetic. The new H1 real-FullSpread cases exercise partial pair
refund and fully consumed share withdrawal; the real ERC4626 cases exercise
zero refunds. These are source coverage statements, not execution receipts.

## Verification performed

Parent checkpoint: `06-custody-plan.log` confirmed a source closure independent
of the still-editing dual/CP families. `06-custody.log` then rebuilt current H1
artifacts with Solar and executed three custody tests: 3 passed, 0 failed,
0 skipped, exit 0. They cover all four modes with ambient balances and both
disable axes. FullSpread component tests and the complete H1 suite remain open;
this checkpoint does not close task 6.

Parent full-family validation:

- `06-08-components.log`: all nine H1 FullSpread component/custody cases passed.
- `06-single.log`: 55 suites, 426 passed, six setup failures, zero skipped.
  The failures were the six real Balancer pool fixture families whose protocol
  TestBases deploy outside the outer manager.
- The shared Balancer fixture now adopts each actual pool and actual package
  through the outer manager's owner-only `registerVault` API, using the pool's
  real `vaultConfig`. No mock, storage injection, disable bypass or fee-oracle
  fallback was added. Unknown/foreign negative cases still fail closed.
- `06-registry-fixtures.log`: all six previously failing suites executed their
  full ten-case rows: 60 passed, zero failed/skipped, exit 0.

Thus the complete H1 family has 486 passing unique tests across the unchanged
426 cases and the corrected 60-case fixtures. Invariant, adversarial and decimal
suites ran in the full-family command. This closes task 6's family gate;
composed-family release evidence and final size/gas gates remain later tasks.

- LSP: `No diagnostics found`, severity all, for the four production files and
  both test files listed above.
- Owned-directory `git diff --check`: exit 0.
- Source review: append-only layout; native-unit receipt conservation;
  exact-output surplus settlement; no prior-custody spend; no LP invention.

The initial workspace had pre-existing modifications to H1 DFPkg membership,
Deploy, SimpleYield matrix, FullSpread matrix, and the untracked component
adapter, as well as extensive other-family/shared work. They were preserved.
Only the four production files, the component adapter, the new custody test, and
this note were edited by task 6.

## Frozen source frontier

Raw-file SHA-256 from a completed exit-0 `shasum -a 256` command:

```text
09da3122989e6d8f07f7c42e7f4a5af525a54a7882eee7b6db8cb5bcd542bb0c  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookRepo.sol
59922b757515bd7e9902be8a861d3e9332b41966b63fa5796e916b58434f9fe1  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookCommon.sol
5c7115a18834c9853d89fa6915b40b0eee7233d7bcf3733cbbe09c93134e23c4  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol
da5ebd4979dc68a67f941f140d23b90f998469573210e648e4ed1ee90ae2c936  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookDFPkg.sol
90c9a48f4e512e0b055485d485784ab80d7ffd04527526d748de5cea324ef9ab  test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_ComponentAccounting.t.sol
e342c9a3791486bf1ba31140640189b6461484d347eba15b462de8b448ada0f5  test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_Custody.t.sol
```

These six files are frozen at this handoff; parent-owned shared dependencies
are not frozen by this note. Coordinate any failure-driven changes before
starting serialized validation.

## Parent validation commands

The artifact helper builds changed concrete dependents before executing tests.
Do not run concurrently with another family's build or alter Foundry paths.

```sh
python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookRepo.sol \
  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookCommon.sol \
  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookDFPkg.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_ComponentAccounting.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_Custody.t.sol \
  -- --isolate -vv

python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookCommon.sol \
  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookDFPkg.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/single \
  -- --isolate -vv
```

Capture task-6 happy/negative evidence in `06-single.log` and
`06-single-negative.log`; neither exists as a task-6 execution receipt yet.

## Risks and integration limits

- Compile, runtime/initcode size, package linkage, gas, and every runtime
  assertion remain unverified until the parent supplies serialized receipts.
  LSP does not prove any of these.
- Foreign or unregistered SEs are explicitly unsupported by this package's
  evidenced authority resolution. No arbitrary oracle fallback was introduced.
  Already registered SEs use the same registry as the hook package.
- H1 residuals remain retained custody, not permissionlessly claimable funds.
  No migration/backfill for old immutable proxies is supplied or authorized.
- Exact-output-capable SEs may produce surplus or consume less than the quoted
  funding: native receipt deltas must remain consistent across the full existing
  SE matrix. The caller's reported input remains the quoted manager take; only
  unused outer-router max-input credit is returned by that router.
- The pre-existing inherited matrix and gas suites depend on parent-owned
  shared/FullSpread changes. This task neither modified nor waived them.
