# Matrix ledger

Documentary denominator is **not resolved** in this skeleton. Do not adopt 195/1/7 or 165/3/7. `COMPATIBLE` is not an executed pass. Slipstream rows, if still present, are `DEPRECATED` by `CLAUDE.md:19` and original-plan D57, not a passing integration.

Provisional hook families found on disk, not a count of combinations:

| hook family | package path | behavior test |
| --- | --- | --- |
| orbital | `contracts/hooks/uniswap/v4/standardExchange/orbital/` | `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol` |
| weighted | `contracts/hooks/uniswap/v4/standardExchange/weighted/` | `.../weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol` |
| curve quad | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/` | `.../curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol` |
| balancer quad | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/` | `.../balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol` |
| single-CP | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` | `.../constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol` |
| dual-CP | `contracts/hooks/uniswap/v4/standardExchange/dual/` | `.../dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol` |
| non-CP single | `contracts/hooks/uniswap/v4/standardExchange/single/` | `.../single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol` |

Host fixtures seen, not a completed Cartesian product: V3 FullSpread, V4 hookless, V4 Pons, RebasingAware, ERC4626, Stata, Aave loop. Wings is a vault, not one of these seven hook families. C10 must list actual test instantiations and missing combinations. Until that list exists, the denominator is `UNRESOLVED`.

| row key | design disposition | inspection support | runtime evidence | owner |
| --- | --- | --- | --- | --- |
| unresolved until C10 inventory | UNDETERMINED | NOT_ASSESSED | MISSING / UNKNOWN | C10 |
