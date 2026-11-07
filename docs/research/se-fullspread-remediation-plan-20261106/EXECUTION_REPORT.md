# Remediation execution evidence

Status: blocked on hook product choices. The scoped production fixes and test
additions are implemented, but the plan is not complete.

The active execution ledger is closed with 51 completed items and 11 dropped
from this execution because they are blocked, have documented coverage limits,
or are explicitly excluded. Dropped does not mean passed or removed from the
requirements; the acceptance ledger below preserves each outstanding item.

## Scope

The owner requested execution of `IMPLEMENTATION_AND_TEST_PLAN.md` on 2026-11-06.
The current remediation locks govern the changes. Existing dirty work is
preserved; no commit, deployment, hook product redesign, or preview-index
certification is authorized by this execution report.

The preview-consumer index has not been walked. R01 remains open under the
explicit migration exclusion. The individually named R02/R03 consumers were
inspected without extending that inspection to the index.

## Production

- `UniswapV4FullSpreadStandardExchangeVaultPlanner._size` now rejects a quote
  that spends less than the entire fixed 49% input.
- `Planner._shares` applies the first-deposit floor to a zero-liquidity add.
- `Execution.exchangeIn` checks that floor before the pretransfer-overmaximum
  refund branch when supply is zero.
- The existing actual-balance exit receipt calculation and six infrastructure
  code checks were inspected and retained.
- `FundedThresholdAssertions` decodes both return words and checks `amountOut`.

## Verification

Commands use `PATH="$HOME/.foundry/bin:$PATH"` because the default Homebrew
Forge cannot select Solar. No compiler fallback was used.

| Check | Result |
| --- | --- |
| Solar production artifact refresh | Passed |
| `QuotesAndRate.t.sol` after parity and dust-tick additions | 20 passed, 0 failed |
| `Package.t.sol` after package coverage additions | 21 passed, 0 failed |
| Package missing/code-empty constructor trace run | 2 passed, 0 failed |
| `SingleSEFundedStakingTest.test_inertPrimaryRouteRequiresFirstBond` | 1 passed, 0 failed |
| Standalone suites, including money, native, callbacks, borrowed unlock, package, previews, and existing fuzz/characterization tests | 119 passed, 0 failed |
| Final direct run of all nine named hook rows | 124 passed, 17 failed |
| Final hook rows plus separate buffer integration suites | 261 passed, 36 failed; all failures are the identity-bind or disabled-withdrawal blockers below |
| Patch whitespace | `git diff --check` passed |

The five quadratic helper characterization tests in the preview file are
retained existing tests, not acceptance evidence for the production sizing
method. The dust-tick acceptance test uses a normal 1% input and 80 adjacent
one-liquidity ranges. A 10% input in its initial fixture collapsed under the
fixed fraction, so it was not a valid normal-deposit fixture.

## Coverage limitations to resolve or report

- The production CREATE3 wrapper exposes `ErrorCreatingContract` when the
  package constructor rejects an invalid component. Tests retain that real
  registry path rather than constructing a package with `new`.
- The installed diamond exposes no package initialization selector. Repeated
  deployment is idempotent, and post-deployment initialization attempts reject
  without changing the diamond. These do not independently exercise the
  package's internal `AlreadyInitialized` branch.
- Borrowed entry states with an idle guard but nonempty callback hash or
  reservations cannot be manufactured through the tested public routes.
  No SUT storage injection was added.
- Genuine PairToken identity bindings are tested. An `asset()`-dependent
  package rejection remains an FS-HOOK-04 blocker, never a compatibility pass.
- Gas measurements require cold execution. Composed measurements include
  router execution and calldata/base transaction gas; standalone measurements
  use isolated cold call frames. All seven standalone gas tests passed.

## First full-run triage

All money, native, callback, borrowed-unlock, package, preview, and existing
one-sided fuzz suites passed in the first compiling full run. Composed tests
exposed:

- Genuine PairToken and this-vault identity rejects, retained as red acceptance
  tests rather than converting rejects into passes.
- Repeated zero-call expectation registration in mixed rows. Replaced with
  bounded call-recording windows that inspect every PairToken call selector,
  retaining the no-money-call assertion.
- The weighted gas test constructed a different PoolKey instead of using its
  canonical initialized key. Corrected.
- A staged-transfer test ignored newly booked swap fees in its custody
  comparison. It now compares against the same-state control plus the staged
  amount.
- A disabled buffered withdrawal reverts `VaultDisabled`. The trace first
  executes the permitted share-to-face redemption, then calls
  `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.bufferQuotedResidual`
  with 21,226,552,334,332 face-token units. That face-to-share mint correctly
  hits the vault's disable gate.
- Orbital and Curve currency1 tests originally exhausted the fixture budget
  by constructing both index cases inside one test. They now retain both
  assertions in separate tests; both pass. Production gas ceilings are unchanged.

The final direct run covers all nine named row files. Its exact command,
per-suite passing tests, failing tests, failure reasons, and gas values are in
`EXECUTION_RESULTS.json`. No test was skipped or weakened to turn a required
identity rejection into a pass.

## Decisions blocking completion

### Identity binding

`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:174-194`
accepts `token == se` only when `asset()` returns a different nonzero address,
or when the token appears in `vaultTokens()`. The genuine PairToken share has
neither property. The canonical dual row fails, as do the PairToken identity
variants of orbital, weighted three-leg, Curve, and Balancer five-leg.
The independent face/raw controls pass; they do not close FS-A26.

The row fixtures emit `FS_HOOK_04` with the consumer, `processArgs(bytes)`
selector, encoded arguments, and revert bytes. No `asset()` selector or hook
binding-rule change was added. FS-A24 and FS-A26 remain open.

### Disabled buffered withdrawal

`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol:126-135`
reinvests leftover face tokens after withdrawal. Its call to
`UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:389-393`
is a new mint, not a withdrawal, and therefore reverts while this vault is
disabled. Making the entire buffered withdrawal succeed needs a hook
residual-handling decision. Removing the vault's non-withdrawal disable gate
would contradict the plan.

## Acceptance ledger

| Rows | Result |
| --- | --- |
| M01-M17 | Passing tests in `Money.t.sol`, including both faces, exact bounds/outside, combined maintenance inputs, four-part receipts, operators, events, fee clamp, funding, and cold route gas |
| M18-M19 | Native accounting and callback/guard/replay suites pass |
| M20 | 13 borrowed-path tests pass; idle guard with nonempty hash/reservations is not independently forced, as described above |
| P01-P08 | Passing same-state output comparisons, economic views while disabled/unlocked, exact-out negatives, and dust-tick execution |
| P09 | Passing on supported converting rows and independent raw controls; canonical dual and rejected identity variants remain blocked |
| K01 | 21 package tests pass collectively; exact inner constructor error and unreachable `AlreadyInitialized` branch limitations remain as described above |
| K02-K05 and aware components | Selector/permit/component tests pass; fixture returns zero from `seBooked`, keeps empty capacity overrides, and preserves weighted setup |
| H01, H02, H05, H08 | Named single, constant-product single, weighted two-leg, and Balancer two-leg rows pass |
| H03 | Canonical dual proof blocked on identity acceptance |
| H04, H06, H07, H09 | Independent raw directions pass; PairToken identity variants remain blocked |
| H10 | Successful unwrap checks pass except the blocked dual; disabled CP buffered withdrawal fails for the traced reason |
| G01, G02, G04 | All seven cold standalone routes, six preview routes, and dedicated composed measurement pass |
| G03 | Eight executable row measurements pass; dual cannot execute. Measurements on independent raw controls do not certify rejected PairToken variants |
| R01 | Excluded from this pass; consumer index not walked and migration not certified |
| R02-R03 | Six named gates and three bindings already use two words; threshold helper fixed and exercised through a real DETF; named production examples read `amountOut` |

### Cold composed gas

| Row | Whole-transaction gas |
| --- | ---: |
| Single | 609,320 |
| Constant-product single | 825,112 |
| Dual | Blocked before execution |
| Orbital raw control | 2,446,999 |
| Weighted two-leg | 796,307 |
| Weighted three-leg raw control | 1,259,254 |
| Curve raw control | 1,263,731 |
| Balancer two-leg | 799,058 |
| Balancer five-leg raw control | 1,323,427 |
| Dedicated buffer integration | 825,112 |

## Evidence preservation and limits

The five named audit evidence destinations are updated only for current V4
FullSpread results and aggregate state counts. V3 rows and unrelated historical
records are preserved. R10.3 is blocked, not evidenced complete.

Solar artifacts were built before test execution. Solidity diagnostics were
checked on changed production code and test entry points; some worker
diagnostic requests timed out, and directory-level Solidity diagnostics were
unsupported. JSON LSP checking was unavailable because Biome is not installed;
JSON syntax and non-V4 record preservation are checked directly. The full
repository runtime suite and the excluded preview-consumer migration were not
certified. No commits or deployments were made.
