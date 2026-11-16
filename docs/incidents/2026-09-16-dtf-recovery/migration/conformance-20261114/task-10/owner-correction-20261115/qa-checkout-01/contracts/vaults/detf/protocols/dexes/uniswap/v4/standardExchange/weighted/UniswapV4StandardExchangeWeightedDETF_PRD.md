# SUPERSEDED

> **Funded-design supersession (2026-09-07):** This document records earlier requirements or implementation evidence. For the authorized funded DETF refactor, [alignment PRD D32–D55 / §24](../../../../../../DETF_ALIGNMENT_PRD.md) and the [funded implementation plan](../../../../../../DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md) take precedence over conflicting Open-mode, LP-claim, rebasing, reward, epoch, decimal, cap and public-route instructions below. Unrelated host behavior remains applicable. Historical completion marks do not certify the funded refactor.


Family Uni V4 Weighted DETF diamond is **deleted**. Do not restore this package.

Uni V4 v1 DETF product law:

- Package: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` (`UniswapV4DetfDFPkg` / `IUniswapV4Detf`)
- [`DETF_INSTANCE_IO_ROUTING_PRD.md`](../../../../../DETF_INSTANCE_IO_ROUTING_PRD.md) §16
- [`UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md`](../../../../../UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md)

Weighted buffer **hook** remains under `contracts/hooks/uniswap/v4/standardExchange/weighted/`.
