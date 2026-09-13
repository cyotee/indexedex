// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookMath
 * @notice ConstProdUtils wrappers + wad normalize for single SE CP hook.
 */
library UniswapV4SingleStandardExchangeBufferConstantProductHookMath {
    using ConstProdUtils for uint256;
    error MathDomain();

    function toWad(uint256 amount, uint8 decimals) external pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals < 18) return amount * (10 ** (18 - decimals));
        return amount / (10 ** (decimals - 18));
    }

    function fromWadFloor(uint256 amountWad, uint8 decimals) external pure returns (uint256) {
        if (decimals == 18) return amountWad;
        if (decimals < 18) return amountWad / (10 ** (18 - decimals));
        return amountWad * (10 ** (decimals - 18));
    }

    function fromWadCeil(uint256 amountWad, uint8 decimals) external pure returns (uint256) {
        if (decimals == 18) return amountWad;
        if (decimals < 18) {
            uint256 scale = 10 ** (18 - decimals);
            return (amountWad + scale - 1) / scale;
        }
        return amountWad * (10 ** (decimals - 18));
    }

    function saleQuote(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256)
    {
        return ConstProdUtils._saleQuote(
            amountIn, reserveIn, reserveOut, Repo.TRADING_FEE_PERCENT, Repo.TRADING_FEE_DENOMINATOR
        );
    }

    function purchaseQuote(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256)
    {
        return ConstProdUtils._purchaseQuote(
            amountOut, reserveIn, reserveOut, Repo.TRADING_FEE_PERCENT, Repo.TRADING_FEE_DENOMINATOR
        );
    }

    function swapDepositSaleAmt(uint256 amountIn, uint256 saleReserve)
        external
        pure
        returns (uint256)
    {
        if (amountIn <= 1e32 && saleReserve <= 1e32) {
            return ConstProdUtils._swapDepositSaleAmt(
                amountIn, saleReserve, Repo.TRADING_FEE_PERCENT, Repo.TRADING_FEE_DENOMINATOR
            );
        }
        if (saleReserve == 0) return amountIn / 2;
        uint256 denominator = Repo.TRADING_FEE_DENOMINATOR;
        if (amountIn > type(uint256).max / (4 * denominator)
            || saleReserve > type(uint256).max / (4 * denominator)) revert MathDomain();
        uint256 net = denominator - Repo.TRADING_FEE_PERCENT;
        uint256 linear = (denominator + net) * saleReserve;
        uint256 scaledReserve = denominator * saleReserve;
        uint256 lo;
        uint256 hi = amountIn;
        // Solve net*x*x + (denominator+net)*reserve*x <= denominator*reserve*amount.
        // Division with a 512-bit numerator avoids squaring a large reserve.
        while (lo < hi) {
            uint256 mid = lo + (hi - lo + 1) / 2;
            if (mid <= FixedPointMathLib.fullMulDiv(amountIn, scaledReserve, linear + net * mid)) lo = mid;
            else hi = mid - 1;
        }
        return lo;
    }

    function calculateProtocolFee(
        uint256 lpTotalSupply,
        uint256 newK,
        uint256 kLast_,
        uint256 ownerFeeShare
    ) external pure returns (uint256) {
        return ConstProdUtils._calculateProtocolFee(lpTotalSupply, newK, kLast_, ownerFeeShare);
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function mintSharesFirst(uint256 xWad, uint256 yWad) external pure returns (uint256) {
        return sqrt(xWad * yWad);
    }

    function mintSharesLater(
        uint256 dxWad,
        uint256 dyWad,
        uint256 xWad,
        uint256 yWad,
        uint256 totalSupply
    ) external pure returns (uint256) {
        uint256 s0 = (dxWad * totalSupply) / xWad;
        uint256 s1 = (dyWad * totalSupply) / yWad;
        return s0 < s1 ? s0 : s1;
    }
}
