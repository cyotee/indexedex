# Independent research response: hook failure diagnosis

## Identity

- Run ID: `hook-failure-diagnosis-20261105`
- Member label: `minimax`
- Profile: `research`
- Phase: `initial independent response`
- Requested role: `council-member`
- Requested model and reasoning: `minimax/MiniMax-M3`, admitted adaptive thinking
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Owned path: `docs/research/hook-failure-diagnosis-20261105/members/minimax/response.md`

## Question and targets

What shared code paths cause the supplied Foundry failures, and what is the smallest fix direction that restores them without changing the live 49% one-sided fraction and without making `asset()` a bind requirement?

I read the required failure list, the shared hook-leg library, the bind checks in the dual, single constant-product, orbital, weighted, Balancer quad, and Curve quad packages, the full-spread planner's `_size`, and the full-spread math's `sizeOneSided` and `_liquidityFittingOut`. I also read the named failing tests and the hook/vault functions they call. I did not run the reviewed project's tests.

## Source observations

### 1. The bind failures have one shared predicate, but that predicate lost the wrapper-share exception

- The approved wrapper binding discriminator is narrow: `pairToken == standardExchange` and the wrapper's `asset()` is a different non-zero address. It explicitly leaves ordinary `pair != se` bindings on `vaultTokens()` membership (`contracts/hooks/uniswap/v4/standardExchange/REBASING_WRAPPER_SHARE_INVENTORY_AMENDMENT.md:18-28`).
- A rebasing wrapper's `vaultTokens()` returns its underlying asset, not its own share token (`contracts/protocols/staking/rebasingVault/RebasingAwareVaultMetadataTarget.sol:28-32`). Thus a legitimate identity-wrapper leg is not a `vaultTokens()` membership hit.
- The shared library has one predicate used by both package validation and runtime binding. The current tree's `pairInVaultTokens` accepts the narrow wrapper exception and treats a missing or reverting `vaultTokens()` as a non-membership result (`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:171-184`); `isWrapperShareInventory` implements only the `pair == se` wrapper discriminator (`.../UniswapV4SeBufferHookLegLib.sol:186-195`); and `addPairSe` delegates the self-overlap decision to that predicate (`.../UniswapV4SeBufferHookLegLib.sol:201-207`).
- All six named packages call this one predicate: single constant-product (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:390-415`), dual (`contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:374-393`), orbital (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol:391-411`), weighted (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:400-452`), Balancer quad (`contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol:373-414`), and Curve quad (`contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol:379-424`).
- Runtime initialization reaches the same predicate through `addPairSe`: single constant-product (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol:61-87`), dual (`contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol:67-93`), orbital (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol:123-134`), weighted (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol:100-113`), and Curve quad (`contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol:95-106`).
- The failure-snapshot locator says the pre-fix predicate returned true only for `vaultTokens()` membership, the wrapper helper was documented as not a bind gate, and `addPairSe` rejected `pair == se` unless membership was true (`docs/research/hook-failure-diagnosis-20261105/brief.md:112-120`). The current source now has the narrow wrapper exception and a fail-closed surface probe at the lines cited above. This is a source snapshot difference, not a claim that the already-running failures were rerun.

### 2. The full-spread failures are not all failures of the same production function

- The live one-sided sizer quotes exactly 49% of the input, calls `Math.sizeOneSided`, and converts any zero-liquidity/zero-swap result into a whole-input refund (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:178-227`).
- `sizeOneSided` computes `remaining_ = amount_ - swapIn_`, derives liquidity from the quoted output, computes the two rounded add payments, and currently rejects the candidate unless the rounded output payment equals the quote exactly and the input payment fits `remaining_` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:47-78`). `_liquidityFittingOut` returns zero if its raw liquidity is zero or exceeds `uint128` (`.../UniswapV4FullSpreadStandardExchangeVaultMath.sol:80-99`).
- The single-row assertion is a scale-sensitive test assumption, not the 49% calculation: it repeatedly subtracts the quoted refund from the amount and then required the refund to be below one percent of the remaining amount (failure supplied at `docs/research/hook-failure-diagnosis-20261105/brief.md:109`). The current row now requires a positive, strictly partial refund and checks refund ownership instead (`test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:76-88`).
- The Balancer 5-leg, Curve quad, and weighted N3 supply failures are stale expectations about an accepted ordinary sibling bind. The full-spread sibling vault initializes its `vaultTokens()` from its two face tokens (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:175-192`), so `pairRecord.p0()` is an ordinary valid pair for the sibling share vault. The seed performs a real join and can therefore increase the sibling's share supply. The current Curve and Balancer rows now assert unchanged supply only when the identity bind was actually rejected (`test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:128-168`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:165-205`). The weighted N3 seed now has the same rejection conditional (`test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:124-162`).
- The dual and orbital index-one `assertLe` values are much larger than the supplied partial-refund values and occur on index reconfiguration paths. Dual index one restores the pre-pair snapshot and reconfigures the side (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:307-312`); orbital index one does the equivalent (`test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:161-168`). Their shared full-spread helper then exercises a real one-sided conversion and exact refund parity (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:148-175`). The supplied operands are not present in the admitted test source, so I do not infer a new production defect from those two numbers alone.

## Inferences and fix directions

### Bind cluster

1. Restore one shared binding predicate with exactly two branches:
   - ordinary binds: `pair` must be in `se.vaultTokens()`;
   - identity wrapper binds: `pair == se` and the existing narrow wrapper discriminator holds.
   A missing or reverting `vaultTokens()` surface must return false rather than leak an empty external revert. The current shared implementation at `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:171-195` is the smallest shape that does this. Because all six packages and the runtime repositories already call the shared helper, no package-specific `asset()` membership rule should be added.
2. Keep `asset()` out of ordinary membership. It may participate only in the already-approved `pair == se` wrapper discriminator. This preserves the amendment's ordinary-bind rule (`contracts/hooks/uniswap/v4/standardExchange/REBASING_WRAPPER_SHARE_INVENTORY_AMENDMENT.md:20-28`) while restoring the wrapper rows.
3. Preserve package-specific errors. CP and dual should continue to surface `TokenNotInVaultTokens` (`.../constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:399-400`; `.../dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:391-392`), while orbital, weighted, Balancer, and Curve should continue to surface `InvalidSE` at their cited `_requireSeOwnsToken` sites. A bare non-wrapper vault must be rejected at bind time; the current control expects exactly `TokenNotInVaultTokens` (`test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_SimpleYieldERC4626Control.t.sol:31-46`).

### Full-spread cluster

4. Do not change the live `49 / 100` quote in `Planner._size` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:199-203`). The smallest restoration is test/expectation alignment for the cases whose old assertions assumed either a dust-only refund or a rejected ordinary sibling:
   - for single, assert a positive partial consumption, exact preview/execution refund parity, and refund to the hook rather than booking it; and
   - for sibling rows, assert unchanged sibling supply only on the rejected-identity branch. On an accepted ordinary bind, assert the expected sibling issuance or conservation instead of an unconditional unchanged supply.
   Those are the current row shapes cited above.
5. Keep the production fit conservative. If `sizeOneSided` cannot form a rounded add that fits the remaining input, it should continue to collapse to zero liquidity and refund the whole input rather than mint with an unfunded add. The implementation already exposes that collapse at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:216-227`. Do not reintroduce a search or alter 49%.
6. The dual/orbital index-one `assertLe` failures need a trace from the assertion site (or a one-time bounded trace) before changing production sizing. Their values are not the single row's refund/amount pair, and the admitted source does not identify a bare `assertLe` that emits that exact pair. The smallest safe direction is therefore to reproduce those two rows with traces after the bind correction, identify the actual operands, and only then adjust the row or the shared helper. A blind fraction change would conflate two distinct problems.

## Coverage

- Covered Cluster A: shared helper, all six named package `processArgs` bind checks, the runtime `addPairSe` paths for the five families using that helper, the wrapper amendment, the bare-vault control, and the named wrapper/identity/invariant consumer tests.
- Covered Cluster B: `Planner._size`, `Math.sizeOneSided`, `_liquidityFittingOut`, the single partial-consumption row, the accepted/rejected sibling bind mechanics, and the Balancer, Curve, weighted, dual, and orbital row sources.
- Not covered: a fresh Foundry execution, traces for the two index-one `assertLe` failures, or a proof that every downstream consumer is restored. The assignment forbids running the reviewed tests, so these are source-level conclusions only.

## Limits

- The brief is the supplied runtime authority; I did not reproduce its failures.
- The shared workspace changed while this analysis was in progress: the current leg library and several row/control files contain the narrow bind correction and the expectation changes described above, while the brief's coordinator locator records the earlier predicate. My diagnosis distinguishes those source snapshots explicitly.
- The two index-one `assertLe` operands are not source-identifiable from the admitted files. I therefore stop short of asserting a production cause for those two failures and recommend a bounded trace rather than inventing one.
- This response states a fix direction only. It does not authorize implementation, does not claim tests pass, and does not alter the live 49% fraction.
