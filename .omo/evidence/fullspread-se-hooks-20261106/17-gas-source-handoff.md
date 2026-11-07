# Task 17 source handoff

Date: 2026-11-07. Source additions only; task 17 remains open.
No build, test, install, Git, deployment, delegation, artifact writer, or runtime
measurement was run by this worker. The parent owns runtime validation and receipts.
The earlier `17-gas-preview-receipt.md` still proves only primary-target mint
for its recorded source; it is not a receipt for these additions.

## Exact source scope

All nine concrete roots below were edited, under
`test/foundry/spec/hooks/uniswap/v4/standardExchange/`:

- `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol`
- `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol`

The only other worker-written file is this handoff. Production, shared fixtures,
shared behaviors, plans, receipts, and artifact/evidence writers were not edited.

## Exact test names

The existing `test_composedRouteGasFitsCeiling` remains intact in every root:
primary member/currency0 target, mint direction.

Three additional test instances per configuration complete the source matrix:

- `test_composedRouteGasFitsCeiling_currency0_redeem`
- `test_composedRouteGasFitsCeiling_currency1_mint`
- `test_composedRouteGasFitsCeiling_currency1_redeem`

These are declared in eight roots. Balancer n=5 inherits the three from the
runtime-length Balancer base row, with its own `setUp` selecting five records.
That gives 27 additional gas cases, 36 total across the nine concrete roots.
Each new test has `forge-config: default.isolate = true`; the helper also
requires `vm.isIsolateMode()`.

`test_row_rateTarget_currency1` in Balancer n=5 now calls the parent's genuine
second-target test, retaining five records and exercising both product-index
placements, then asserts the second provider and matching face on the proxy.
Weighted n=3 now also declares `test_row_rateTarget_currency1`.

## Genuine route and measurement assertions

The existing five-argument `FullSpreadV4MatrixChecks.coldSwap` still requires a
mint. It delegates to a new six-argument overload whose final `bool mint_`
selects a strict increase or decrease in the primary FullSpread SE total supply.
Every newly measured redemption requires a strict primary supply decrease;
a local-only payment cannot pass.

Each new case executes `WrapperExactOutRouter.swapExactIn` through the actual
PoolManager and production hook proxy. The LP-bearing cases mint with 1 ether
of the selected member face, or redeem with 30 ether of the counter leg.
The counter is raw in CP single, orbital, weighted n=2/n=3, Curve, and Balancer
n=2/n=5; it is the genuine sibling member in dual. Before an LP-bearing
redemption the positive proxy quote must exceed the hook's entire physical
primary face balance, forcing an SE deficit rather than claiming local output
as redemption. The supply assertion independently checks the resulting burn.

H1 is conversion-only: its mint input is the member face; its redemption input
is an actual share quantity acquired using the real vault's public route.
`_swapParams(false, ...)` and `buffer.previewUnwrap` consume the SE share token.
H1's production package has no rate-provider field. Its second-target cases bind
the second member face to a separate hook/product pool and verify that it matches
`currency1Provider().rateTarget()`; they do not claim H1 reads a provider.
Every LP-bearing second-target case installs `currency1Provider` on the matching
primary face and checks the proxy provider getter.

Bootstrap/share acquisition, package deployment/mining, token funding,
approvals, and all probes are outside the measured router frame. The preview
is the actual proxy preview, immediately followed by
`vm.lastFrameGas().gasTotalUsed`, required positive and at most 5,000,000 gas.
The router runs as a separate isolated transaction; its measured frame plus
21,000 intrinsic gas and actual calldata byte cost must be at most 12,000,000.
Any mint fee processing invoked by that route remains inside its frame.
Each new case compares the user's actual output-token balance increase with
the positive preview exactly. No expected revert, ceiling relaxation, or budget
tolerance was added. The emitted gas labels remain `G03.coldPreviewGas` and
`G03.coldWholeTransactionGas`, distinguished by the exact test names above.

Weighted n=3 now rebuilds all sorted SE/provider/weight records in
`_bindThree(provider_)`. `_bindSecondTarget` replaces the primary face, re-sorts,
and verifies all three proxy SE/provider bindings and 50%/25%/25% weights.
The sibling provider stays attached to its sibling member; the raw record stays
unbuffered. Its public share-funded bootstrap remains unchanged.

## Static verification and limits

Solidity LSP diagnostics reported no diagnostics in all nine roots. Static
comparison preserved 133 existing test function bodies byte-for-byte; the sole
changed existing test body is the explicitly requested Balancer n=5
`test_row_rateTarget_currency1` repair. No compiler or runtime result is claimed.
The 30 ether redemption amounts are source-selected, guarded by actual positive
quote/deficit/burn assertions, and still need execution by the parent.

The fixtures use disjoint FullSpread backing pools. These cases do not prove
same-backing-pool sequential safety, unavailable SE exact-output support, or
completion of task 17. A runtime failure is a failure to diagnose, not permission
to weaken an assertion or relabel local-only settlement.

## One serialized parent command

After the parent's currently active CP test and Balancer invariant run finish,
and after the parent refreshes the required runtime artifacts/roots, run this
single command from `/Users/cyotee/Projects/indexedex`. Do not run it concurrently
with another artifact-writing Forge process. This command was not run here.

```bash
forge test --use solar --isolate --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/**/*_SeMatrix_UniswapV4FullSpreadStandardExchangeVault*.t.sol' --match-test '^(test_composedRouteGasFitsCeiling(_currency[01]_(mint|redeem))?|test_row_rateTarget_currency1)$' -vv
```

Expected selection from these concrete roots: 36 gas cases plus eight
`test_row_rateTarget_currency1` cases, 44 total. Treat missing/zero selected
cases as an unresolved selection issue, not a pass. The parent must record actual
preview/transaction gas and route outcomes and retain task 17 as open until its
runtime and remaining capability/evidence requirements are satisfied.
