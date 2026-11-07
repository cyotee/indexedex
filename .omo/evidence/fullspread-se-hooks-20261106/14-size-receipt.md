# Full repository size-build receipt

Date: 2026-11-07. Command: `forge build --use solar --sizes` with the session Foundry toolchain. `14-size-build.log` records 3,053 compiled files, successful Solar compilation in 395.69 seconds, and exit code 1 from the runtime-size gate. This is not a green whole-repository size build.

All 1,059 numeric size rows were parsed from bounded reads. The 71 rows beginning with `UniswapV4` and containing `Buffer` or `FullSpread` have nonnegative runtime and initcode margins. The largest of these is CP-single ClaimLib: 20,898 runtime bytes and 20,943 creation bytes. These are measured compiled artifact sizes, not estimates.

## Whole-repository runtime overages

| Artifact name | Runtime bytes | Context |
| --- | ---: | --- |
| FullSpreadSameManagerAmmFixture | 39874 | Test fixture library at `test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadSameManagerAmmFixture.sol`; used by Wings test consumers. |
| Handler_UniswapV4PairTokenStandardExchangeVault | 25425 | PairToken test handler under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/harness/`. |
| NonfungiblePositionManager | 26787 | Uniswap V3 periphery name, present in both ported and vendored `lib/crane` sources; the size table does not disambiguate the name. |
| VaultMock | 31736 | Mock name present in several `lib/crane` test trees; the size table does not disambiguate the name. |

These source files were not edited by this execution. No baseline size comparison was performed, so this note does not label the overages pre-existing. Several SeMatrix constructors also exceed the initcode limit; they are test fixture deployment bundles rather than the production packages below. No compiler/profile/code-size setting was changed and no oversized source was suppressed.

## Measured product-family rows

| Artifact | Runtime bytes | Creation bytes | Runtime margin | Initcode margin |
| --- | ---: | ---: | ---: | ---: |
| `UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib` | 6400 | 6418 | 18176 | 42734 |
| `UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg` | 12205 | 13087 | 12371 | 36065 |
| `UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet` | 11290 | 11308 | 13286 | 37844 |
| `UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib` | 6042 | 6060 | 18534 | 43092 |
| `UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet` | 8843 | 8861 | 15733 | 40291 |
| `UniswapV4DualStandardExchangeBufferConstantProductHookMath` | 1378 | 1396 | 23198 | 47756 |
| `UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet` | 11778 | 11796 | 12798 | 37356 |
| `UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet` | 8809 | 8827 | 15767 | 40325 |
| `UniswapV4FullSpreadMathHarness` | 2606 | 2624 | 21970 | 46528 |
| `UniswapV4FullSpreadStandardExchangeVaultCallbackFacet` | 1044 | 1062 | 23532 | 48090 |
| `UniswapV4FullSpreadStandardExchangeVaultCallbackTarget` | 640 | 658 | 23936 | 48494 |
| `UniswapV4FullSpreadStandardExchangeVaultDFPkg` | 7244 | 11191 | 17332 | 37961 |
| `UniswapV4FullSpreadStandardExchangeVaultMoneyFacet` | 17184 | 17202 | 7392 | 31950 |
| `UniswapV4FullSpreadStandardExchangeVaultMoneyTarget` | 16608 | 16626 | 7968 | 32526 |
| `UniswapV4FullSpreadStandardExchangeVaultOutFacet` | 1020 | 1038 | 23556 | 48114 |
| `UniswapV4FullSpreadStandardExchangeVaultOutTarget` | 543 | 561 | 24033 | 48591 |
| `UniswapV4FullSpreadStandardExchangeVaultQueryFacet` | 3492 | 3510 | 21084 | 45642 |
| `UniswapV4FullSpreadStandardExchangeVaultQueryTarget` | 3041 | 3059 | 21535 | 46093 |
| `UniswapV4FullSpreadStandardExchangeVaultQuoteFacet` | 10934 | 10952 | 13642 | 38200 |
| `UniswapV4FullSpreadStandardExchangeVaultQuoteTarget` | 10446 | 10464 | 14130 | 38688 |
| `UniswapV4FullSpreadSwapProjectionHarness` | 2282 | 2300 | 22294 | 46852 |
| `UniswapV4SeBufferHookContextQuoteLib` | 3428 | 3446 | 21148 | 45706 |
| `UniswapV4SeBufferHookLegLib` | 2956 | 2974 | 21620 | 46178 |
| `UniswapV4SeBufferHookLegLibHarness` | 1099 | 1117 | 23477 | 48035 |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib` | 20898 | 20943 | 3678 | 28209 |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg` | 12467 | 13510 | 12109 | 35642 |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet` | 7150 | 7168 | 17426 | 41984 |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet` | 3624 | 3642 | 20952 | 45510 |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleFacet` | 6066 | 6084 | 18510 | 43068 |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookMath` | 2177 | 2195 | 22399 | 46957 |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet` | 9127 | 9145 | 15449 | 40007 |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet` | 6328 | 6346 | 18248 | 42806 |
| `UniswapV4SingleStandardExchangeBufferHookDFPkg` | 7935 | 8374 | 16641 | 40778 |
| `UniswapV4SingleStandardExchangeBufferHookFacet` | 6275 | 6293 | 18301 | 42859 |
| `UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib` | 10919 | 10964 | 13657 | 38188 |
| `UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg` | 14335 | 15189 | 10241 | 33963 |
| `UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet` | 11788 | 11833 | 12788 | 37319 |
| `UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksFacet` | 10246 | 10264 | 14330 | 38888 |
| `UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet` | 13734 | 13752 | 10842 | 35400 |
| `UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryFacet` | 15440 | 15458 | 9136 | 33694 |
| `UniswapV4StandardExchangeBalancerQuadStableBufferHookSeFacet` | 12084 | 12102 | 12492 | 37050 |
| `UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib` | 18845 | 18890 | 5731 | 30262 |
| `UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg` | 12649 | 13544 | 11927 | 35608 |
| `UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet` | 5947 | 5992 | 18629 | 43160 |
| `UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet` | 10067 | 10085 | 14509 | 39067 |
| `UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet` | 9303 | 9321 | 15273 | 39831 |
| `UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacetExt` | 10489 | 10507 | 14087 | 38645 |
| `UniswapV4StandardExchangeCurveQuadStableBufferHookMath` | 4967 | 4985 | 19609 | 44167 |
| `UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet` | 12684 | 12702 | 11892 | 36450 |
| `UniswapV4StandardExchangeOrbitalBufferHookClaimLib` | 9990 | 10008 | 14586 | 39144 |
| `UniswapV4StandardExchangeOrbitalBufferHookDFPkg` | 12799 | 13749 | 11777 | 35403 |
| `UniswapV4StandardExchangeOrbitalBufferHookDepositFacet` | 11263 | 11281 | 13313 | 37871 |
| `UniswapV4StandardExchangeOrbitalBufferHookDepositFlexibleFacet` | 8643 | 8661 | 15933 | 40491 |
| `UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet` | 9447 | 9465 | 15129 | 39687 |
| `UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet` | 10375 | 10393 | 14201 | 38759 |
| `UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib` | 10647 | 10665 | 13929 | 38487 |
| `UniswapV4StandardExchangeOrbitalBufferHookHooksFacet` | 12443 | 12461 | 12133 | 36691 |
| `UniswapV4StandardExchangeOrbitalBufferHookMath` | 3701 | 3719 | 20875 | 45433 |
| `UniswapV4StandardExchangeOrbitalBufferHookSeFacet` | 10726 | 10744 | 13850 | 38408 |
| `UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet` | 8119 | 8164 | 16457 | 40988 |
| `UniswapV4StandardExchangeWeightedBufferHookClaimLib` | 11606 | 11651 | 12970 | 37501 |
| `UniswapV4StandardExchangeWeightedBufferHookDFPkg` | 15804 | 16845 | 8772 | 32307 |
| `UniswapV4StandardExchangeWeightedBufferHookExitFacet` | 7942 | 7960 | 16634 | 41192 |
| `UniswapV4StandardExchangeWeightedBufferHookExitQueryFacet` | 8931 | 8949 | 15645 | 40203 |
| `UniswapV4StandardExchangeWeightedBufferHookHooksFacet` | 10757 | 10775 | 13819 | 38377 |
| `UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet` | 4916 | 4934 | 19660 | 44218 |
| `UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet` | 5541 | 5559 | 19035 | 43593 |
| `UniswapV4StandardExchangeWeightedBufferHookLiquidityFacetExt` | 8115 | 8133 | 16461 | 41019 |
| `UniswapV4StandardExchangeWeightedBufferHookLiquidityLib` | 14418 | 14463 | 10158 | 34689 |
| `UniswapV4StandardExchangeWeightedBufferHookMath` | 6481 | 6499 | 18095 | 42653 |
| `UniswapV4StandardExchangeWeightedBufferHookSeFacet` | 7518 | 7536 | 17058 | 41616 |

This receipt does not close selector/linkage correctness, unresolved quote integrations, gas ceilings, or the final release gate.
