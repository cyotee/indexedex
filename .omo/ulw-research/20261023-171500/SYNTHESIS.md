# ULW-Research Synthesis: fee-earning single-token Uniswap vaults

STATUS: complete for the three loop criteria. Unresolved hosts remain listed and do not enter the recommendation set.

## Executive summary

No inspected production Uniswap vault both earns swap fees and exposes a view one-token rate that ignores the same pool's spot price. Wings, Gamma V4 withdraw math, and the Visor 2021 mint read pool spot. Arrakis V2 and Charm return two token amounts whose in-range split still depends on slot0. Steer tells the integrator to apply a market price.

The pattern that can implement IRateProvider.getRate() without reading spot is stored single-token accounting. Panoptic CollateralTracker.convertToAssets reads s_poolAssets + s_inAMM. That contract is options collateral, not an LP vault. The rate shape is what IndexedEx can call.

## Recommendation

One formula for deposit, redeem, and getRate:

getRate = accounted target tokens * 1e18 / supply

Fee source: the Uniswap position still earns swap fees while price is inside the range. Those fees enter the rate only when target tokens actually move into the accounted balance: a settled swap, a harvest, a deposit, or a redemption. The rate does not read slot0, a quoter, or a hypothetical sale of the other token.

Storage the rate reads: an accounted target-token counter, not balanceOf and not pool state. The other token stays out of the rate until a separate conversion credits target. That conversion is outside getRate and does not use slot0.

Excluded: Wings spot liquidation, Gamma/Visor spot share mint, Bunni v2, and deprecated Arrakis V1/V2.

## Quote functions in the recommendation set

| Protocol | Quote function | Primary URL | Enters recommendation |
| --- | --- | --- | --- |
| Wings | EconomicTarget.getRate -> Quote.quote, which reads getSlot0 | contracts/.../UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol | No. This is the bug. |
| Arrakis V2 | Underlying.underlying reads pool.slot0 and returns two amounts | https://github.com/ArrakisFinance/v2-core/blob/21e662bce6aa206534f4f909cb86a45854428911/contracts/libraries/Underlying.sol | No. Deprecated 15 Jun 2026. |
| Charm | AlphaProVault.getTotalAmounts / _amountsForLiquidity reads slot0 | https://github.com/charmfinance/alpha-vaults-v2-contracts/blob/0174095f918b5a883c3726cbe4556aaa58f12c82/contracts/AlphaProVault.sol | No. Two-token pro-rata. |
| Gamma V4 | WithdrawLogic share value uses poolManager.getSlot0 | GammaStrategies/GammaV2 WithdrawLogic.sol | No. Spot mark. |
| Steer | getTotalAmounts plus an unspecified market price | https://docs.steer.finance/flagship-apps/smart-pools/developing-with-smart-pools/contract-side/ | No. Pushes the price choice to the caller. |
| ICHI legacy | deposit compares spot and TWAP; no getRate in the page | https://docs.ichi.org/ichi-docs-v3/ichi-vaults/technical-concepts/vault-build | No. Guard, not a rate. |
| Panoptic | CollateralTracker.convertToAssets reads stored s_poolAssets + s_inAMM | https://github.com/panoptic-labs/panoptic-v1-core/blob/main/contracts/CollateralTracker.sol | Shape only. Not an LP vault. |
| Recommended pattern | getRate reads accounted target / supply | this file | Yes. |

## Exclusions from primary postmortems

Visor, 25 Nov 2021: "the minting quantity of our vault's ERC-20 receipt tokens is determined via consultation of Uniswap v3 pool's current price" and the code line `TickMath.getSqrtRatioAtTick(currentTick())`. https://github.com/GammaStrategies/uniswapv3-risk-mitigation/blob/main/Notes%20on%20Uniswap%20v3%20Risk%20Mitigation.md

Gamma, 23 Jan 2024: "The root cause of the attack was due to a dangerous exception in the ratio checker function. It erroneously allowed for deposits in any ratio so long as the contents within the vault were single-sided." The same page says the attacker manipulated the pool price. https://web.archive.org/web/20240525174620/https://medium.com/gamma-strategies/security-review-and-opening-of-deposits-7dcd4e35a494

Both are the spot-quote class. They are excluded. A getRate that does not read same-pool spot does not emit that quote. It does not by itself fix a deposit function that still prices off the pool.

Bunni v2 is excluded because the repository README says it was exploited and the issues are not fixed. The postmortem body was not independently read.

## Alternative precedent, not the recommendation

Maker's GUniLPOracle at commit 0d25676e0956fc3a5359431c708106547c4fef26 derives sqrtPriceX96 from two independent USD oracles, calls getUnderlyingBalancesAtPrice, and divides by supply. peek() and read() return the last poke(), and poke() is limited by hop (default 1 hour). That cached value is a view a rate provider can call without reading the pool in the caller's transaction. seek() itself still calls the vault, and Arrakis V2 underlying() still reads pool.slot0() for the fee tick even when a price is supplied. So this precedent supports a cached external mark. It does not make a live AtPrice call safe, and it is not the recommended pattern.

## Gaps

DefiEdge, Teahouse, Orange, and Maverick doc hosts did not resolve on the first pass. A later sweep found Teahouse and Algebra docs. Neither publishes a view getRate that ignores same-pool spot. ICHI current Solidity was not opened. Arrakis Pro docs do not publish a V4 share formula. A third-party reproduction of an August 2026 Arrakis V1 mint/burn was not executed and is not treated as an Arrakis postmortem. Those gaps stay outside the recommendation set.
