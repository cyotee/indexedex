# SE CP Single Buffer Hook — Implementation Plan

## Layout

```text
scripts/foundry/research/uniswapV4/hooks/seConstantProductSingle/
  ResearchFixture_SeCpSingleHook.sol
  Script_H0_Smoke.s.sol
  Script_S0_FirstDeposit.s.sol
  Script_H1_Demand.s.sol
```

## Fixture

Inherit `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook`:

- `bootstrapResearch()`  
- `depositDual(a0, a1)` / `swapViaPool(zeroForOne, amountIn)`  
- Telemetry: `isLive`, `rawReserve`, pair/SE balances, `lpSupply`, preview/exec

## Milestones

M0 H0 → M1 S0 → M2 H1 → M3 H2 + FINDINGS
