# Sources ledger

Access date for every row: 2026-10-23.

| id | url | read by | note |
| --- | --- | --- | --- |
| S1 | lib/crane/.../IRateProvider.sol | lead | getRate() view returns uint256, 18-decimal rate |
| S2 | contracts/.../upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol | lead | getRate = Quote.quote().value / supply |
| S3 | contracts/.../UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol | lead | _prepare reads manager.getSlot0; _quote simulates opposing-token sale |
| S4 | https://raw.githubusercontent.com/ArrakisFinance/v2-core/21e662bce6aa206534f4f909cb86a45854428911/contracts/libraries/Underlying.sol | lead | underlying() reads pool.slot0(); amounts via getAmountsForLiquidity |
| S5 | https://docs.arrakis.finance/yield-bearing-asset | lead | Pro strategy, ERC-4626 rate used to rebalance, not a public share rate |
| S6 | https://docs.arrakis.finance/arrakis-pro | lead | issuer-owned vaults, not public depositor shares |
| S7 | https://raw.githubusercontent.com/ArrakisFinance/v2-palm/main/README.md | lead | private vaults on V2 core |
| S8 | https://raw.githubusercontent.com/ArrakisFinance/arrakis-docs/main/src/text/arrakisModular/priceOracles.md | lead | oracle is a rebalance check, Chainlink, RedStone, or Uni V3 TWAP |
| S9 | https://docs.ichi.org/ichi-docs-v3/ichi-vaults/technical-concepts/vault-build | lead | legacy: TWAP vs spot, 1% initial threshold, single-sided default |
| S10 | https://docs.ichi.org/home/how-ichi-works | lead | current marketing: one-token deposit, claims no privileged rebalance |
| S11 | https://docs.ichi.org/home/yieldiq-strategy | lead | inventory rebalance, may sell preferred token when over-inventory |
| S12 | https://docs.gamma.xyz/gamma/lp-vaults/introduction | lead | V3/V4/Algebra vaults, rebalance offchain, no market swaps for some strategies |
| S13 | GammaStrategies/GammaV2 WithdrawLogic.sol | lead, via gh | share value uses poolManager.getSlot0 |
| S14 | https://github.com/charmfinance/alpha-vaults-v2-contracts/blob/0174095f918b5a883c3726cbe4556aaa58f12c82/contracts/AlphaProVault.sol | lead, via gh | _amountsForLiquidity reads slot0; shares are pro-rata of two amounts |
| S15 | https://docs.steer.finance/flagship-apps/smart-pools/developing-with-smart-pools/contract-side/ | lead | getTotalAmounts returns two tokens; integrator applies a market price |
| S16 | https://raw.githubusercontent.com/panoptic-labs/panoptic-v1-core/main/contracts/CollateralTracker.sol | lead, via gh | convertToAssets uses stored s_poolAssets + s_inAMM |
| S17 | revert-finance/lend src/V3Oracle.sol | lead, via gh | twapSeconds == 0 uses slot0, else pool.observe |
| S18 | https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/README.md | lead | exploited, do not use; postmortem URL failed TLS |
| S19 | https://docs.doppler.lol/readme | lead | token-launch auctions, not an LP share vault |
| S20 | https://docs.ekubo.org/ | lead | AMM infrastructure, not a share vault |
| S21 | https://raw.githubusercontent.com/balancer/metastable-rate-providers/bca02e9eb30d76663ba41e0c80693e02706f1ae5/contracts/ERC4626RateProvider.sol | lane web-balancer-rates, not re-read by lead | getRate delegates to convertToAssets |
| S22 | https://github.com/GammaStrategies/uniswapv3-risk-mitigation/blob/main/Notes%20on%20Uniswap%20v3%20Risk%20Mitigation.md | lead | Visor 25 Nov 2021: receipt mint used currentTick. Excluded as a spot-quote design. |
| S23 | https://web.archive.org/web/20240525174620/https://medium.com/gamma-strategies/security-review-and-opening-of-deposits-7dcd4e35a494 | lead | Gamma 23 Jan 2024: single-sided ratio exception plus manipulated pool price. Excluded. |
| S24 | https://arrakis.finance/blog/v1-v2-deprecation | lead | Arrakis V1/V2 deprecated 15 Jun 2026. Not a live pattern. |
| S25 | https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/README.md | lead | Bunni v2 exploited. Excluded. Postmortem body not independently read. |
