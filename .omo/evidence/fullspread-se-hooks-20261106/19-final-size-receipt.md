# Renewed complete build and size gate

Date: 2026-11-07. `19-post-consumer-sizes.log`: Solar compiler successful with
warnings; `forge build --use solar --sizes` exited 1 because contracts
exceed EIP-170. This gate is not green. No limit was raised or warning
suppressed.

All **71 affected product artifacts** below fit runtime 24576 and initcode
49152 bytes. The largest runtime is 19419 bytes. The whole-repository
oversized artifacts remain listed separately; no before-change baseline
exists here, so they are not classified as pre-existing.

## Affected products

| Artifact | Runtime bytes | Initcode bytes |
|---|---:|---:|
| UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib | 6400 | 6418 |
| UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg | 12191 | 13073 |
| UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet | 9037 | 9055 |
| UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib | 5831 | 5849 |
| UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet | 8830 | 8848 |
| UniswapV4DualStandardExchangeBufferConstantProductHookMath | 1378 | 1396 |
| UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet | 11663 | 11681 |
| UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet | 8814 | 8832 |
| UniswapV4FullSpreadMathHarness | 2606 | 2624 |
| UniswapV4FullSpreadStandardExchangeVaultCallbackFacet | 1044 | 1062 |
| UniswapV4FullSpreadStandardExchangeVaultCallbackTarget | 640 | 658 |
| UniswapV4FullSpreadStandardExchangeVaultDFPkg | 7244 | 11191 |
| UniswapV4FullSpreadStandardExchangeVaultMoneyFacet | 17184 | 17202 |
| UniswapV4FullSpreadStandardExchangeVaultMoneyTarget | 16608 | 16626 |
| UniswapV4FullSpreadStandardExchangeVaultOutFacet | 1020 | 1038 |
| UniswapV4FullSpreadStandardExchangeVaultOutTarget | 543 | 561 |
| UniswapV4FullSpreadStandardExchangeVaultQueryFacet | 3492 | 3510 |
| UniswapV4FullSpreadStandardExchangeVaultQueryTarget | 3041 | 3059 |
| UniswapV4FullSpreadStandardExchangeVaultQuoteFacet | 10934 | 10952 |
| UniswapV4FullSpreadStandardExchangeVaultQuoteTarget | 10446 | 10464 |
| UniswapV4FullSpreadSwapProjectionHarness | 2282 | 2300 |
| UniswapV4SeBufferHookContextQuoteLib | 3368 | 3386 |
| UniswapV4SeBufferHookLegLib | 2956 | 2974 |
| UniswapV4SeBufferHookLegLibHarness | 1099 | 1117 |
| UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib | 19419 | 19464 |
| UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg | 12467 | 13510 |
| UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet | 7185 | 7203 |
| UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet | 3462 | 3480 |
| UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleFacet | 6028 | 6046 |
| UniswapV4SingleStandardExchangeBufferConstantProductHookMath | 2177 | 2195 |
| UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet | 9246 | 9264 |
| UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet | 6328 | 6346 |
| UniswapV4SingleStandardExchangeBufferHookDFPkg | 7935 | 8374 |
| UniswapV4SingleStandardExchangeBufferHookFacet | 6331 | 6349 |
| UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib | 10919 | 10964 |
| UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg | 14335 | 15189 |
| UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet | 11788 | 11833 |
| UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksFacet | 10246 | 10264 |
| UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet | 10516 | 10534 |
| UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryFacet | 14689 | 14707 |
| UniswapV4StandardExchangeBalancerQuadStableBufferHookSeFacet | 11582 | 11600 |
| UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib | 16827 | 16872 |
| UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg | 12680 | 13575 |
| UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet | 5947 | 5992 |
| UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet | 10067 | 10085 |
| UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet | 7774 | 7792 |
| UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacetExt | 9281 | 9299 |
| UniswapV4StandardExchangeCurveQuadStableBufferHookMath | 4967 | 4985 |
| UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet | 11419 | 11437 |
| UniswapV4StandardExchangeOrbitalBufferHookClaimLib | 9990 | 10008 |
| UniswapV4StandardExchangeOrbitalBufferHookDFPkg | 12799 | 13749 |
| UniswapV4StandardExchangeOrbitalBufferHookDepositFacet | 10127 | 10145 |
| UniswapV4StandardExchangeOrbitalBufferHookDepositFlexibleFacet | 7191 | 7209 |
| UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet | 8800 | 8818 |
| UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet | 9379 | 9397 |
| UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib | 7015 | 7033 |
| UniswapV4StandardExchangeOrbitalBufferHookHooksFacet | 12443 | 12461 |
| UniswapV4StandardExchangeOrbitalBufferHookMath | 3701 | 3719 |
| UniswapV4StandardExchangeOrbitalBufferHookSeFacet | 10132 | 10150 |
| UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet | 8119 | 8164 |
| UniswapV4StandardExchangeWeightedBufferHookClaimLib | 11606 | 11651 |
| UniswapV4StandardExchangeWeightedBufferHookDFPkg | 15804 | 16845 |
| UniswapV4StandardExchangeWeightedBufferHookExitFacet | 7942 | 7960 |
| UniswapV4StandardExchangeWeightedBufferHookExitQueryFacet | 8931 | 8949 |
| UniswapV4StandardExchangeWeightedBufferHookHooksFacet | 10757 | 10775 |
| UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet | 4916 | 4934 |
| UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet | 5541 | 5559 |
| UniswapV4StandardExchangeWeightedBufferHookLiquidityFacetExt | 8115 | 8133 |
| UniswapV4StandardExchangeWeightedBufferHookLiquidityLib | 13599 | 13644 |
| UniswapV4StandardExchangeWeightedBufferHookMath | 6481 | 6499 |
| UniswapV4StandardExchangeWeightedBufferHookSeFacet | 7518 | 7536 |

## Negative size margins in the complete build

| Artifact | Runtime bytes | Initcode bytes |
|---|---:|---:|
| FullSpreadSameManagerAmmFixture | 40333 | 40378 |
| Handler_UniswapV4PairTokenStandardExchangeVault | 25425 | 28530 |
| NonfungiblePositionManager | 26787 | 27517 |
| SeMatrix_AaveLoopFixture | 2444 | 806423 |
| SeMatrix_AerodromeFixture | 1690 | 57765 |
| SeMatrix_BufferPoolFixture | 1871 | 316680 |
| SeMatrix_CbmvFixture | 1883 | 319333 |
| SeMatrix_CbmvsFixture | 1872 | 318840 |
| SeMatrix_MbmvsFixture | 1874 | 319261 |
| SeMatrix_MixedLegFixture | 1871 | 320066 |
| SeMatrix_MultiPairFixture | 1884 | 319335 |
| SeMatrix_StataFixture | 2837 | 781084 |
| VaultMock | 31736 | 42937 |

These names are the build table identities, not unique source-path claims
for names duplicated across vendor trees. They were not modified merely
to make this unrelated whole-repository size gate green. Existing test-only
large constructors are not evidence that deployable product code fits;
the separate 71-row product measurements provide that evidence.

## DETF bootstrap adapter artifacts

The post-consumer table also confirms these DETF runtime/initcode sizes.
None exceeds either limit.

| Artifact | Runtime bytes | Initcode bytes |
|---|---:|---:|
| UniswapV4DetfBondFacet | 8150 | 8168 |
| UniswapV4DetfBondNFTVaultDFPkg | 4104 | 4427 |
| UniswapV4DetfBondNFTVaultFacet | 8766 | 8784 |
| UniswapV4DetfClaimFacet | 2662 | 2680 |
| UniswapV4DetfDFPkg | 16274 | 17104 |
| UniswapV4DetfExchangeFacet | 7712 | 7730 |
| UniswapV4DetfMaintenanceFacet | 6784 | 6802 |
| UniswapV4DetfQueryFacet | 10437 | 10455 |
