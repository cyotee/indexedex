# Task 16 - stateful source/test handoff

Date: 2026-11-07. This is a source handoff, not an execution receipt, plan
completion, or owner approval. No Forge command, build, test, installation,
deployment, Git operation, delegation, or artifact/cache writer was run.
The parent owns all subsequent compilation, execution, verification, and fixes.

## Changed files

All source paths below are relative to
`test/foundry/spec/hooks/uniswap/v4/standardExchange/`.

1. `HookComponentAccountingBehavior.sol`
   - Adds the shared `HookComponentLedger`, eight deterministic FullSpread
     scenarios, and the non-SUT outer-settlement caller.
   - Leaves the existing HB40-HB48 assertion bodies and traded-alias discussion
     unchanged.
2. `HookLiquidityInvariantHandler.sol`
   - Uses the independent native ledger for every successful join, exit and swap.
   - Separates ambient shares/pairs from backing and tracks LP transfers.
   - Replaces the ineffective raw donation to `SimpleYieldERC4626` with a funded
     `simulateYield` call and an asserted `convertToAssets(1 ether)` increase.
   - Replaces the sum of unlike native exit quantities with a positive-component
     check while retaining each individual exact payout assertion.
3. `constantProduct/single/invariant/UniswapV4SingleStandardExchangeBufferConstantProductHook_Invariant.t.sol`
4. `dual/invariant/UniswapV4DualSEBCPHook_Invariant.t.sol`
5. `orbital/invariant/UniswapV4StandardExchangeOrbitalBufferHook_Invariant.t.sol`
6. `weighted/invariant/UniswapV4StandardExchangeWeightedBufferHook_Invariant.t.sol`
7. `stable/quad/curve/invariant/UniswapV4StandardExchangeCurveQuadStableBufferHook_Invariant.t.sol`
8. `stable/quad/balancer/invariant/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Invariant.t.sol`

The six invariant configurations now supply their real fee oracle. Dual,
Orbital and Balancer no longer seed outside the ledger: the handler witnesses
genesis instead. Orbital retains its former 100-token seed size inside the
first handler join, preserving the intended radius headroom.

The weighted file additionally contains
`UniswapV4StandardExchangeWeightedBufferHook_MixedDecimalsOwnership`.
It uses a six-decimal pair token, a production ERC4626 SE proxy with
eighteen-decimal shares, and an eighteen-decimal raw callback token. It reuses
the existing `HostileReentrantERC20` non-SUT dependency. The existing weighted
`afterInvariant` first-24 replay completion, accounting check, campaign check,
and short-replay test are preserved.

The only evidence write is this file. No concrete ComponentAccounting adapter,
production contract, shared TestBase/fixture, config, PRD, plan, other evidence,
weighted cross-leg preview case, or Balancer requested-share case was edited.

## Independent oracle

`HookComponentLedger` starts with zero LP supply and zero expected backing.
It maintains separate native `shares`, `local`, and `raw` fields, plus separate
ambient pair/share quantities. It never assigns the next expected book from a
hook book getter or its post-operation custody.

For each operation, the ledger records the caller's starting inventory and
observes actual external conversion transfers and SE mint/burn events. A
protocol vault may pay its underlying directly, so the receipt reader excludes
the caller and the explicitly supplied settlement boundary rather than assuming
every payout originates at the SE diamond.

For each leg's assembled caller basket:

```text
availablePair   = declaredPair + externalPairReceived - externalPairSpent
availableShares = declaredShares + actualSharesMinted - actualSharesBurned
```

For later proportional joins, with independent pre-intake supply `T` and
component books `B_j`, the oracle computes:

```text
g          = min_j floor(available_j * T / B_j), for positive B_j only
accepted_j = ceil(g * B_j / T)
returned_j = available_j - accepted_j
feeLP      = floor(g * configuredFee / 1e18)
netLP      = g - feeLP
```

Full-width `Math.mulDiv` and `mulmod` implement the oracle arithmetic without
calling the production component-acceptance library. The minimum of all native
component limits independently determines the maximal supported gross mint.
Caller final pair/share balances must equal starting balances minus declared
input plus the corresponding unused/returned inventory. Only accepted
components increment the expected backing. No unlike native quantities are
added.

For exits, the oracle independently decrements each book by
`floor(burn * book / preBurnSupply)`. The actual SE burn must equal the allocated
share claim; pair payment must equal allocated local/raw tokens plus the
observed external redemption receipt. SE minting and pair redeposit on that
exit are rejected. Protocol LP exits use exactly the same allocation and keep
the locked floor in the denominator.

Genesis asserts actual SE burn `A / 20`, positive actual local receipt, no
internal SE mint, no redeposit, retained shares, complete raw acceptance, the
single 1,000-LP floor, and the exact gross/net/fee split. The **family-specific
genesis LP denomination itself remains an observed first supply minus 1,000**;
this ledger is not an independent reimplementation of all six geometric,
weighted, or stable seed functions. Subsequent gross issuance is independently
computed, not observed.

Swap book updates use the declared/actually used input and delivered output
alongside the external conversion receipts. Local-only output must burn no SE
shares. Swaps, external yield, market movement, and transfers cannot alter the
expected Hook LP supply or protocol LP balance.

Physical hook custody is checked against independent backing plus separately
tracked ambient custody after each transition. This is not a claim that every
family has a public getter for every stored native book. Subsequent formula
checks exercise those internal books through real proportional money routes.

## Exact test names and destinations

These eight new shared tests are inherited by the six existing LP
`*_ComponentAccounting.t.sol` adapters, including their existing weighted
N3/N8 and Balancer N5 subclasses:

- `test_HB16_joinMarketExitUnderlyingUnwind`
- `test_HB16_feeChangesAndProtocolExitUseIndependentBooks`
- `test_HB16_addressDisableReenableAmbientAndRefundInventory`
- `test_HB16_packageDisableReenableAmbientAndRefundInventory`
- `test_HB16_unbalancedBudgetsReturnCallerInventory`
- `test_HB16_failedFundingPreservesIndependentBooks`
- `test_HB16_failedBootstrapRedemptionRestoresAllLegs`
- `test_HB16_failedOuterSettlementRestoresIndependentBooks`

The market sequence has Bob join the hook, acquire a separate actual position
in its primary FullSpread backing vault, observe a real rate and position
liquidity change, exit his entire Hook LP position by component fractions,
then redeem only the separately acquired market shares. It asserts the exact
underlying position reduction `floor(shares * liquidity / supply)`, actual share
burn and pair receipt. External position cost, recovered pair tokens, and their
signed PnL are emitted separately in that one pair token's native units.

Fee changes use zero, one WAD-precision unit, two percent, and zero again, with
both share-funded and pair-funded later joins. The protocol then exits its own
funded LP, followed by both users, leaving only the locked floor.

Disable sequences cover both address and package switches, preowned-share
joins, locally booked disabled input, exits, ambient pair/share custody, and a
new incoming join after re-enable. Unequal proportional budgets force a
limiting leg and actual unused/returned caller inventory.

The failed-funding case first proves the identical funded amounts work from a
snapshot, restores that state, then removes the final input token from Bob.
The failed call must leave hook/caller balances, allowances, SE supplies,
underlying positions and relevant SE/PoolManager custody unchanged.

The failed-bootstrap case gives the last SE leg 19 native share units, whose
required five-percent burn is zero. It checks whole-state restoration and a
subsequent valid bootstrap. **It does not claim an external partial redemption
was reached:** a family can reject during forward sizing before executing
earlier conversions. Integrated partial-receipt fault injection remains outside
this evidence; the fixed real FullSpread fixture is not replaced by a fake SE.
The existing max-minimum bootstrap rollback test remains intact.

The outer-settlement case completes a real hook swap inside `unlock`, then
creates actual unsettled manager debt with `take`. It expects the exact
`IPoolManager.CurrencyNotSettled` selector and complete restoration. The same
funded operation without that debt then succeeds and updates the ledger.

Two new tests in
`UniswapV4StandardExchangeWeightedBufferHook_MixedDecimalsOwnership`:

- `test_HB16_mixedNativeDecimalsJoinYieldExit`
- `test_HB16_reentryCannotSpendPendingCallerComponents`

The latter deterministically triggers one raw-token transfer callback during
a proportional join, requires the nested proportional join to fail with
`Reentrancy()`, and checks the successful outer join and exit against the
independent ledger. This mixed-decimal/reentry control uses a real ERC4626 SE,
not a FullSpread backing-pool decimal matrix.

Existing tests strengthened by handler integration:

- `invariant_liquidityAccounting` in all six LP invariant contracts.
- `test_deterministicLifecycle` in all six, with the existing 24-call
  actor/action prefix and strict campaign counters.
- `test_shortReplayCompletesActorActionCoverage` in weighted.

These are source identities, not discovered or passing runtime test counts.

## Static validation

Native LSP diagnostics returned `No diagnostics found` for both changed shared
files and all six changed invariant roots, including the final weighted
mixed-decimal/reentry addition.

Diagnostics were also requested on all six unchanged concrete component
adapters after the shared additions. Five returned `No diagnostics found`.
The unchanged Curve adapter reported:

```text
warning[solar] (2018) at 296:4: function state mutability can be restricted to view
```

The referenced existing `_assertTradedJoin` helper was inspected and not
modified. A separate LSP references request on the handler timed out; no
reference-completeness claim is based on that request.

No compiler exit code, runtime assertion result, fuzz campaign, gas receipt,
or artifact identity is available from this track. LSP is not a substitute.

## Serialized parent commands

Run from the shared checkout only after the parent's active artifact writer
has finished. The following are instructions for the parent, **not commands
run by this child**. Stop on the first failure and inspect it; do not run these
in parallel. The existing helper builds required runtime artifacts before
tests and inserts `--use solar` into its Forge commands.

```bash
cd /Users/cyotee/Projects/indexedex
set -e

python3 scripts/forge-artifacts.py test \
  test/foundry/spec/hooks/uniswap/v4/standardExchange/HookComponentAccountingBehavior.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ComponentAccounting.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_ComponentAccounting.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_ComponentAccounting.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_ComponentAccounting.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting.t.sol \
  -- --match-test '^test_HB16_' -vvv

python3 scripts/forge-artifacts.py test \
  test/foundry/spec/hooks/uniswap/v4/standardExchange/HookLiquidityInvariantHandler.sol \
  test/foundry/spec/hooks/uniswap/v4/standardExchange/HookComponentAccountingBehavior.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/invariant \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/invariant \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/invariant \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/invariant \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/invariant \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/invariant \
  -- --match-test '^(invariant_liquidityAccounting|test_deterministicLifecycle|test_shortReplayCompletesActorActionCoverage|test_HB16_.*)$' -vvv
```

## Boundaries retained

- Paid internal single-input swaps versus the pre-intake component snapshot
  remain an unresolved owner interpretation. New successful ownership joins
  here are proportional multi-leg routes; no answer is inferred from the
  existing traded-alias tests.
- Same-backing-pool sequential composition remains explicitly unverified.
  The FullSpread fixtures use disjoint backing pools.
- The new ledger does not establish universal swap-manipulation resistance,
  every facade's correctness, every zero-component topology, or a six-family
  mixed-decimal/reentry matrix.
- Parent compilation/runtime verification is the remaining handoff gate.
  Existing failing weighted FullSpread cross-leg preview and Balancer
  FullSpread requested-share cases were neither edited nor relabelled.
