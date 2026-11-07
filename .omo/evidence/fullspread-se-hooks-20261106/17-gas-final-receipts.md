# Both-target composed gas receipts

Date: 2026-11-07. Task 17 measurement work is complete.

`17-cp-inherited-gas.log` passed 40 cases, zero failures/skips;
`17-canonical-preview-gas.log` independently passed the canonical primary
preview/transaction case. Earlier standalone matrix receipts are in
`17-all-targets-gas.log`; its only failure was repaired caller funding.

Maximum preview: **556371** gas (ceiling 5000000). Maximum cold router
transaction including intrinsic calldata: **1448998** gas (ceiling 12000000).
Setup and bootstrap are excluded. Every row executes the real router and
asserts a primary SE mint or burn; new cases assert exact preview/output parity.

Names below are exact runtime contracts. The source is
`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol`,
except the standalone CP contract, whose source is its identically named
`.t.sol` under `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/`.
`primary mint` is `test_composedRouteGasFitsCeiling`; other route labels are
the exact suffix following `test_composedRouteGasFitsCeiling_`.
The canonical primary preview value comes from `17-canonical-preview-gas.log`.

| Runtime contract | Route | Preview gas | Transaction gas |
|---|---|---:|---:|
| UniswapV4FullSpreadStandardExchangeVault_SingleUnwrap_Test | primary mint | 125999 | 647206 |
| UniswapV4FullSpreadStandardExchangeVault_SingleUnwrap_Test | currency0_redeem | 104090 | 545555 |
| UniswapV4FullSpreadStandardExchangeVault_SingleUnwrap_Test | currency1_mint | 125398 | 696445 |
| UniswapV4FullSpreadStandardExchangeVault_SingleUnwrap_Test | currency1_redeem | 104982 | 516798 |
| UniswapV4FullSpreadStandardExchangeVault_BalancerUnwrap_Test | primary mint | 321657 | 873097 |
| UniswapV4FullSpreadStandardExchangeVault_BalancerUnwrap_Test | currency0_redeem | 283217 | 777818 |
| UniswapV4FullSpreadStandardExchangeVault_BalancerUnwrap_Test | currency1_mint | 331180 | 886220 |
| UniswapV4FullSpreadStandardExchangeVault_BalancerUnwrap_Test | currency1_redeem | 296062 | 797249 |
| UniswapV4FullSpreadStandardExchangeVault_BalancerFiveUnwrap_Test | primary mint | 468685 | 1070128 |
| UniswapV4FullSpreadStandardExchangeVault_BalancerFiveUnwrap_Test | currency0_redeem | 430245 | 974850 |
| UniswapV4FullSpreadStandardExchangeVault_BalancerFiveUnwrap_Test | currency1_mint | 478208 | 1083251 |
| UniswapV4FullSpreadStandardExchangeVault_BalancerFiveUnwrap_Test | currency1_redeem | 443090 | 994281 |
| UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault | primary mint | 290583 | 821142 |
| UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault | currency0_redeem | 242255 | 711492 |
| UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault | currency1_mint | 300108 | 833890 |
| UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault | currency1_redeem | 255102 | 731256 |
| UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test | primary mint | 290583 | 821142 |
| UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test | currency0_redeem | 242255 | 711492 |
| UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test | currency1_mint | 300108 | 833890 |
| UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test | currency1_redeem | 255102 | 731256 |
| UniswapV4FullSpreadStandardExchangeVault_CurveUnwrap_Test | primary mint | 444973 | 939092 |
| UniswapV4FullSpreadStandardExchangeVault_CurveUnwrap_Test | currency0_redeem | 404396 | 843917 |
| UniswapV4FullSpreadStandardExchangeVault_CurveUnwrap_Test | currency1_mint | 454496 | 947153 |
| UniswapV4FullSpreadStandardExchangeVault_CurveUnwrap_Test | currency1_redeem | 417241 | 858286 |
| UniswapV4FullSpreadStandardExchangeVault_OrbitalUnwrap_Test | primary mint | 470804 | 1202138 |
| UniswapV4FullSpreadStandardExchangeVault_OrbitalUnwrap_Test | currency0_redeem | 431021 | 1110041 |
| UniswapV4FullSpreadStandardExchangeVault_OrbitalUnwrap_Test | currency1_mint | 485389 | 1230447 |
| UniswapV4FullSpreadStandardExchangeVault_OrbitalUnwrap_Test | currency1_redeem | 448928 | 1144658 |
| UniswapV4FullSpreadStandardExchangeVault_WeightedUnwrap_Test | primary mint | 327561 | 856230 |
| UniswapV4FullSpreadStandardExchangeVault_WeightedUnwrap_Test | currency0_redeem | 286476 | 768115 |
| UniswapV4FullSpreadStandardExchangeVault_WeightedUnwrap_Test | currency1_mint | 337084 | 863666 |
| UniswapV4FullSpreadStandardExchangeVault_WeightedUnwrap_Test | currency1_redeem | 299321 | 783181 |
| UniswapV4FullSpreadStandardExchangeVault_WeightedThreeUnwrap_Test | primary mint | 452838 | 978049 |
| UniswapV4FullSpreadStandardExchangeVault_WeightedThreeUnwrap_Test | currency0_redeem | 415007 | 893188 |
| UniswapV4FullSpreadStandardExchangeVault_WeightedThreeUnwrap_Test | currency1_mint | 462361 | 985485 |
| UniswapV4FullSpreadStandardExchangeVault_WeightedThreeUnwrap_Test | currency1_redeem | 427852 | 908254 |
| UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test | primary mint | 474313 | 1080835 |
| UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test | currency0_redeem | 543526 | 1424529 |
| UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test | currency1_mint | 488898 | 1104058 |
| UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test | currency1_redeem | 556371 | 1448998 |

See `17-capabilities.md` for unresolved non-gas routes, the intentional
exact-output boundary, and unverified same-backing-pool composition. These
receipts are not release or deployment approval.
