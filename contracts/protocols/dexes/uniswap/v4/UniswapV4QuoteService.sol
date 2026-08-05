// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {UniswapV4Quoter} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol";
import {UniswapV4ZapQuoter} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4ZapQuoter.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";

library UniswapV4QuoteService {
    uint16 internal constant DEFAULT_ZAP_SEARCH_ITERS = 20;
    uint8 internal constant DEFAULT_SHARE_SEARCH_ITERS = 24;

    struct DirectQuoteParams {
        IPoolManager manager;
        PoolKey key;
        bool zeroForOne;
        uint256 amount;
    }

    struct ZapInQuoteParams {
        IPoolManager manager;
        PoolKey key;
        int24 tickLower;
        int24 tickUpper;
        bool zeroForOne;
        uint256 amountIn;
        uint256 totalShares;
        uint256 reserve0;
        uint256 reserve1;
        bool initialDeposit;
    }

    struct ZapOutQuoteParams {
        IPoolManager manager;
        PoolKey key;
        int24 tickLower;
        int24 tickUpper;
        uint128 currentLiquidity;
        uint256 totalShares;
        bool wantCurrency0;
        uint256 amountOut;
    }

    function _quoteDirectExactInput(DirectQuoteParams memory p) internal view returns (uint256 amountOut) {
        if (p.amount == 0) {
            return 0;
        }

        UniswapV4Quoter.SwapQuoteResult memory quote = UniswapV4Quoter.quoteExactInput(
            UniswapV4Quoter.SwapQuoteParams({
                manager: p.manager,
                key: p.key,
                zeroForOne: p.zeroForOne,
                amount: p.amount,
                sqrtPriceLimitX96: _sqrtPriceLimit(p.zeroForOne),
                maxSteps: 0
            })
        );

        return quote.amountOut;
    }

    function _quoteDirectExactOutput(DirectQuoteParams memory p) internal view returns (uint256 amountIn) {
        if (p.amount == 0) {
            return 0;
        }

        UniswapV4Quoter.SwapQuoteResult memory quote = UniswapV4Quoter.quoteExactOutput(
            UniswapV4Quoter.SwapQuoteParams({
                manager: p.manager,
                key: p.key,
                zeroForOne: p.zeroForOne,
                amount: p.amount,
                sqrtPriceLimitX96: _sqrtPriceLimit(p.zeroForOne),
                maxSteps: 0
            })
        );

        if (!quote.fullyFilled) {
            return type(uint256).max;
        }

        return quote.amountIn;
    }

    function _quoteZapInShares(ZapInQuoteParams memory p) internal view returns (uint256 sharesOut) {
        UniswapV4ZapQuoter.ZapInQuote memory quote = _quoteZapInDetail(p);

        if (p.initialDeposit || p.totalShares == 0) {
            return quote.amount0 + quote.amount1;
        }

        return ConstProdUtils._depositQuote(quote.amount0, quote.amount1, p.totalShares, p.reserve0, p.reserve1);
    }

    function _quoteZapInSwapAmount(ZapInQuoteParams memory p) internal view returns (uint256 swapAmountIn) {
        return _quoteZapInDetail(p).swapAmountIn;
    }

    function _quoteZapInDetail(ZapInQuoteParams memory p)
        internal
        view
        returns (UniswapV4ZapQuoter.ZapInQuote memory quote)
    {
        if (p.amountIn == 0) {
            return quote;
        }

        quote = UniswapV4ZapQuoter.quoteZapInSingleCore(
            UniswapV4ZapQuoter.ZapInParams({
                manager: p.manager,
                key: p.key,
                tickLower: p.tickLower,
                tickUpper: p.tickUpper,
                zeroForOne: p.zeroForOne,
                amountIn: p.amountIn,
                sqrtPriceLimitX96: _sqrtPriceLimit(p.zeroForOne),
                maxSwapSteps: 0,
                searchIters: DEFAULT_ZAP_SEARCH_ITERS
            })
        );
    }

    function _quoteZapOutShares(ZapOutQuoteParams memory p) internal view returns (uint256 sharesRequired) {
        if (p.amountOut == 0 || p.totalShares == 0 || p.currentLiquidity == 0) {
            return 0;
        }

        uint256 low = 1;
        uint256 high = p.totalShares;
        uint256 best = type(uint256).max;

        for (uint8 i = 0; i < DEFAULT_SHARE_SEARCH_ITERS && low <= high; i++) {
            uint256 mid = low + ((high - low) / 2);
            uint128 liquidityToBurn = uint128((mid * p.currentLiquidity) / p.totalShares);

            if (liquidityToBurn == 0) {
                low = mid + 1;
                continue;
            }

            UniswapV4ZapQuoter.ZapOutQuote memory quote = UniswapV4ZapQuoter.quoteZapOutSingleCore(
                UniswapV4ZapQuoter.ZapOutParams({
                    manager: p.manager,
                    key: p.key,
                    tickLower: p.tickLower,
                    tickUpper: p.tickUpper,
                    liquidity: liquidityToBurn,
                    wantCurrency0: p.wantCurrency0,
                    sqrtPriceLimitX96: _sqrtPriceLimit(!p.wantCurrency0),
                    maxSwapSteps: 0
                })
            );

            if (quote.amountOut >= p.amountOut) {
                best = mid;
                if (mid == 1) {
                    break;
                }
                high = mid - 1;
            } else {
                low = mid + 1;
            }
        }

        if (best == type(uint256).max) {
            return best;
        }

        if (best < p.totalShares) {
            return best + 1;
        }

        return best;
    }

    function _sqrtPriceLimit(bool zeroForOne) private pure returns (uint160 sqrtPriceLimitX96) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }
}
