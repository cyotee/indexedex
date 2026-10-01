# Balancer stable-buffer transition quote handoff

## Scope and status

The patch is limited to the Balancer pool SE transition adapter, CommonBuffer/MixedBuffer stable pool quote support, and their regression tests. D60 excludes Balancer-hosted DETF functional changes; none are included here. Consumer libraries and H/P work are outside this patch.

No Forge command, delegation, or commit was performed. LSP reported no errors for the adapter, shared quote helper, regression TestBase, and two test files. **Compilation and runtime assertions are not yet verified.** The parent owns the first artifact-first compile/test run. The parent-provided broad-hook log reference is `tool_0f30a163a001pZ3s5K7tBVzUt7`; this patch does not claim a rerun or inspection of that log.

## Implementation

- `BalancerV3PoolStandardExchangeTransitionQuoteTarget` carries protocol-owned `bytes poolState` and the effective aggregate swap-fee percentage.
- Optional `IBalancerV3PoolLiquidityQuote` supplies three read-only selectors: snapshot, liquidity math, and post-liquidity hook-state projection. The generic adapter does not decode family state.
- Both stable pool targets capture amplification, virtual buffer, signed hook deltas, token indices, rates/scales, and invariant bounds. The shared helper uses the existing `StableMath`, `FixedPoint`, and `Math` primitives. The BasePoolMath liquidity/fee sequence is mirrored locally because its `IBasePool` callbacks cannot receive a projected virtual book. Execution math and hooks are unchanged.
- Every removal scales virtuals with the execution formulas, including signed division toward zero. Physical-token unbalanced deposits leave the virtual book unchanged.
- Pool raw balances exclude aggregate fees on joins and exits. The order matches `Vault._computeAndChargeAggregateSwapFees`: scaled total fee → raw rounded down → aggregate fraction rounded down. Recovery mode captures a zero aggregate percentage.
- New selectors and ERC-165 ID are included in both existing pool facets and package interfaces. Existing package cuts enumerate facet selectors; existing CREATE3 FactoryServices deploy the updated facets. No new deployment mechanism is needed.
- Stable-buffer subjects without the optional quote interface fail instead of falling back to stale live storage. Missing virtual state is rejected. The helper rejects virtual-buffer routes and exact-out joins (not an operation in `IStandardExchangeTransitionQuote`).

## Regression coverage prepared

The two new `*_TransitionQuote.t.sol` files each define an unrated and a real-SE-rate-provider fixture, using the existing registry/CREATE3 production pool TestBases. No canned SUT, mock calls, or direct storage writes were added.

- Two `RedeemExactIn` projections computed **before either execution**.
- Exact output amounts, input debits, holder shares/assets, and issued supply.
- Full encoded projected state equals a fresh execution snapshot after **each** step (all raw balances, rates/scales, fees, and virtual fields).
- Projected production rate-provider value equals its live `getRate`, with a nonzero check.
- Zero and nonzero aggregate-fee controls; nonzero control asserts actual fee collection.
- Deposit → redeem and exact-output withdraw → redeem.
- Positive/negative hook deltas created by real swaps, with signed scaling checks.
- Bounded two-removal fuzz cases.
- Missing virtual book rejection.
- Target-derived facet selector controls, interface controls, package cuts, and live proxy routing.

## Parent artifact-first command

Run once the parent's current compiler/artifact writer has exited:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTransitionQuoteTarget.sol \
  contracts/protocols/dexes/balancer/v3/pools/IBalancerV3PoolLiquidityQuote.sol \
  contracts/protocols/dexes/balancer/v3/pools/stable/BalancerV3StableBufferPoolQuoteTarget.sol \
  contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolTarget.sol \
  contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolFacet.sol \
  contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolStandardVaultPkg.sol \
  contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolTarget.sol \
  contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolFacet.sol \
  contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolStandardVaultPkg.sol \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePool_TransitionQuote.t.sol \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePool_TransitionQuote.t.sol \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool_TransitionQuote.t.sol \
  -- -vv
```

After this focused gate, rerun the parent's two failing FullSpread consumer matrix rows with refreshed artifacts. No claim is made that those failures are resolved until execution confirms it.

## Snapshot compatibility

The public generic transition interface/selectors are unchanged. Opaque `PoolQuoteState` encoding gained fields; discard old snapshots and call `quoteState` again. Existing immutable deployed diamonds do not gain the new pool selectors from a source edit. Updated package artifacts and newly deployed fixture diamonds are required. There is no live migration or DETF architecture decision in this patch.
