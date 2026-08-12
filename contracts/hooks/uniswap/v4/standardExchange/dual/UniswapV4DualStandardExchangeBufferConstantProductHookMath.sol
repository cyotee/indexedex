// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookMath
 * @notice Normalize + ConstProdUtils wrappers for dual SE buffer CP hook (D29 / O1a / D57).
 */
library UniswapV4DualStandardExchangeBufferConstantProductHookMath {
    using ConstProdUtils for uint256;

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
            amountIn,
            reserveIn,
            reserveOut,
            Repo.TRADING_FEE_PERCENT,
            Repo.TRADING_FEE_DENOMINATOR
        );
    }

    function purchaseQuote(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256)
    {
        return ConstProdUtils._purchaseQuote(
            amountOut,
            reserveIn,
            reserveOut,
            Repo.TRADING_FEE_PERCENT,
            Repo.TRADING_FEE_DENOMINATOR
        );
    }

    function swapDepositSaleAmt(uint256 amountIn, uint256 saleReserve)
        external
        pure
        returns (uint256)
    {
        return ConstProdUtils._swapDepositSaleAmt(
            amountIn,
            saleReserve,
            Repo.TRADING_FEE_PERCENT,
            Repo.TRADING_FEE_DENOMINATOR
        );
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

    function mintSharesFirst(uint256 claim0Wad, uint256 claim1Wad) external pure returns (uint256) {
        return sqrt(claim0Wad * claim1Wad);
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
