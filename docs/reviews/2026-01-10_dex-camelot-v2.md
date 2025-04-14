# 2026-01-10 — DEX Review: Camelot V2 (StandardExchange)

- Index: ./2026-01-10_area-dex-vaults_parallel-review.md

## Key files

- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeCommon.sol`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeInTarget.sol`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol`
- `contracts/protocols/dexes/camelot/v2/CamelotV2_Component_FactoryService.sol`

## Key tests

- `contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol`
- `test/foundry/spec/protocol/dexes/camelot/v2/*`

## Verified finding: previewDeployVault can revert

In `CamelotV2StandardExchangeDFPkg.previewDeployVault`:
- New-pair path does `sqrt(tokenAAmount * tokenBAmount) - 1000`.
- This can revert due to:
  - multiplication overflow (`tokenAAmount * tokenBAmount`), and/or
  - underflow if `sqrt(product) < 1000`.

This is potentially surprising for a “preview” surface; decide whether “preview may revert” is acceptable or whether it should clamp to 0 / guard inputs.

## Subagent notes (UNVERIFIED — needs manual confirmation)

A parallel subagent flagged additional potential preview/execution mismatches (fee-on-transfer handling, exact-out semantics, fee denominator constants). These were returned without concrete file/line references and should be treated as hypotheses to verify before acting.

## Suggested minimal test additions

- Unit/spec test(s) that lock the intended behavior for `previewDeployVault` on small inputs (underflow) and large inputs (overflow).
- One preview/execution parity test on a representative swap route (plain ERC20s) to catch drift.
