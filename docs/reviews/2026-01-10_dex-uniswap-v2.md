# 2026-01-10 — DEX Review: Uniswap V2 (StandardExchange)

- Index: ./2026-01-10_area-dex-vaults_parallel-review.md
- Scope: Implemented Uniswap V2 StandardExchange DFPkg + targets + tests present on `main`.

## Key files

- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol`

## Key tests

- `contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol`
- `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_DeployWithPool.t.sol`

## Findings / checkpoints (mostly structural)

- DFPkg `deployVault`: verify expected behavior in each step: createPair-if-missing → mint initial LP → deploy vault → `exchangeIn` LP→vault-shares.
- Route-matrix risk: the 7-branch route logic in `previewExchangeIn/out` and `exchangeIn/out` is easy to drift. Add/expand specs that assert preview/execution parity for each route.
- Coverage gap: existing spec coverage looks strongest around `deployVault` + `previewDeployVault`; `exchangeOut` route correctness appears less directly exercised.

## Suggested minimal test additions

- Route-matrix spec(s) that cover at least one representative `exchangeOut` path and assert `previewExchangeOut` matches the required input (or is conservative by design, if that’s the intended invariant).
