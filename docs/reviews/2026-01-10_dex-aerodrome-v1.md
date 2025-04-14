# 2026-01-10 — DEX Review: Aerodrome V1 (StandardExchange)

- Index: ./2026-01-10_area-dex-vaults_parallel-review.md
- Scope: Aerodrome integration under `contracts/protocols/dexes/aerodrome/v1/`.

## Reality check

User asked for “Aerodrome V2”, but the implementation present on `main` is Aerodrome V1.

## Key files

- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol`
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol`
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeInTarget.sol`
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol`

## Key tests

- `contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange.sol`
- `test/foundry/spec/protocol/dexes/aerodrome/v1/*`
- `test/foundry/fork/base_main/aerodrome/*`

## Confirmed bug (high priority)

- In `AerodromeStandardExchangeOutTarget.previewExchangeOut`, the “Underlying Pool Vault Deposit” branch computes assets required for output vault shares, but calls `BetterMath._convertToAssetsUp(amountIn, ...)`.
- That branch should be using `amountOut` (the desired shares) rather than `amountIn`.

This makes `previewExchangeOut` incorrect for that route (and downstream router/UI quoting wrong).

## Additional review checkpoints

- Fee lookup and stable/volatile selection: validate `factory.getFee(pool, isStable)` is aligned with how pools are selected/validated.
- Reserve sorting: ensure reserves are consistently associated with `tokenIn` / `tokenOut` and not accidentally compared to the pool address.
