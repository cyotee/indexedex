# Foundation validation source frontier

Date: 2026-11-06. Working source contents, not HEAD alone, identify this run.
Forge 1.9.1-nightly 430523103f3e2f9ba432ffdd2031a9f966153d0d; Solar 0.3.0-dev e7a91fc7.

```sh
export PATH="$HOME/.foundry/bin:$PATH"
python3 scripts/forge-artifacts.py test 'contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol' 'contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol' 'contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol' 'contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol' 'contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol' 'contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol' 'contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol' 'contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol' 'contracts/utils/ExchangeInAmount.sol' --test-root 'test/foundry/spec/hooks/uniswap/v4/interfaces' --test-root 'test/foundry/spec/hooks/uniswap/v4/libs/UniswapV4HookComponentAccounting.t.sol' --test-root 'test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_Deploy.t.sol' --test-root 'test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy.t.sol' --test-root 'test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_Core.t.sol' --test-root 'test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Binding.t.sol' --test-root 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Deploy.t.sol' --test-root 'test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_Deploy.t.sol' --test-root 'test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Deploy.t.sol' -- --isolate -vv
```

Output: `02-03-foundations.log`. Exit code 0. Nine suites executed 152 tests:
152 passed, 0 failed, 0 skipped. This includes 15 shared membership tests,
19 component arithmetic/refund tests and all seven family binding/deployment suites.
Each family executed the new real-vault member-pair/implicit-own-share round trip.
Build completed successfully with existing warnings; Solidity error diagnostics
were clean. These receipts close tasks 2 and 3, not family component accounting,
fees or genesis: legacy family economics are still present until tasks 6-12.

| Source | SHA-256 (UTF-8 source bytes) |
| --- | --- |
| `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol` | `dee01f31ad8930c9dc43435e7614a45deba18f39e273fd57ceae9ca1f8cf3f8c` |
| `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol` | `ebe2b0dd3fea12f97950317f63a243d26a81da60c77070fd7e2b5105266d10b8` |
| `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol` | `3337721e7f00162f18ad308a72d5fdf22c101c167f9e99539f622fb64b487720` |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol` | `fcdf46dec3b6e50c9e7a9c35bd87f24277f320fd0c44eb92617a32c2e44b30e0` |
| `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol` | `42086e689d64ce3f79db41721886579b649f65f406f7dc6380e8c684061d98ee` |
| `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol` | `78d1b790b56cba1558473a9bca5673462f52ddd3a74dcdeacf52264358839288` |
| `contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol` | `50a2b4c6d3847f6c0ed1846c12f04e3ce5585ab1ce00c6679346878d135024ae` |
| `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol` | `ec0b2cf110980e9be1e3d6f5005336f4bb893f74c9cb612fb27016ff770891ad` |
| `contracts/utils/ExchangeInAmount.sol` | `040507e9c50e107045c36361aee80de5ede6fb594c69df1a9d598099cae408e5` |

Membership red-before: `02-binding-red.log`, exit 1, 15 executed tests,
14 passed and one expected regression failure: `test_addPairSe_assetAnswerDoesNotWaiveMembership`.
The old asset-answering wrapper bypass did not revert. No production source was changed
during that run. The green run removes that bypass and all five package decimal exceptions.

