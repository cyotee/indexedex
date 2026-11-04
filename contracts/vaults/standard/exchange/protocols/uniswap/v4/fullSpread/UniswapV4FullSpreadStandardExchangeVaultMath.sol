// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {FixedPoint96} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint96.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {UniswapV4FullSpreadStandardExchangeVaultTypes as Types} from "./UniswapV4FullSpreadStandardExchangeVaultTypes.sol";

/// @notice Liquidity amounts and the FS-OWN-33 selection given a quoted swap.
library UniswapV4FullSpreadStandardExchangeVaultMath {
    struct Sized {
        uint256 swapIn;
        uint256 swapOut;
        uint256 unswapped;
        uint256 remainder;
        uint128 liquidity;
    }

    function amountsForLiquidity(uint160 sqrtPriceX96_, uint160 sqrtA_, uint160 sqrtB_, uint128 liquidity_)
        internal
        pure
        returns (uint256 amount0_, uint256 amount1_)
    {
        if (sqrtA_ > sqrtB_) (sqrtA_, sqrtB_) = (sqrtB_, sqrtA_);
        if (sqrtPriceX96_ <= sqrtA_) {
            amount0_ = _amount0(sqrtA_, sqrtB_, liquidity_);
        } else if (sqrtPriceX96_ < sqrtB_) {
            amount0_ = _amount0(sqrtPriceX96_, sqrtB_, liquidity_);
            amount1_ = _amount1(sqrtA_, sqrtPriceX96_, liquidity_);
        } else {
            amount1_ = _amount1(sqrtA_, sqrtB_, liquidity_);
        }
    }

    function liquidityForAmounts(
        uint160 sqrtPriceX96_,
        uint160 sqrtA_,
        uint160 sqrtB_,
        uint256 amount0_,
        uint256 amount1_
    ) internal pure returns (uint128) {
        return LiquidityAmounts.getLiquidityForAmounts(sqrtPriceX96_, sqrtA_, sqrtB_, amount0_, amount1_);
    }

    /// @dev Greatest liquidity whose add consumes the quoted swap output and leaves rounding in the input token.
    function sizeOneSided(
        uint256 amount_,
        bool zeroForOne_,
        uint256 swapIn_,
        uint256 swapOut_,
        uint160 sqrtAfter_,
        uint160 sqrtA_,
        uint160 sqrtB_
    ) internal pure returns (Sized memory sized_) {
        if (swapIn_ > amount_) swapIn_ = amount_;
        uint256 remaining_ = amount_ - swapIn_;
        uint128 liquidity_ = zeroForOne_
            ? LiquidityAmounts.getLiquidityForAmount1(sqrtA_, sqrtAfter_, swapOut_)
            : LiquidityAmounts.getLiquidityForAmount0(sqrtAfter_, sqrtB_, swapOut_);
        uint256 need0_;
        uint256 need1_;
        while (liquidity_ != 0) {
            (need0_, need1_) = amountsToPay(sqrtAfter_, sqrtA_, sqrtB_, liquidity_);
            uint256 needIn_ = zeroForOne_ ? need0_ : need1_;
            uint256 needOut_ = zeroForOne_ ? need1_ : need0_;
            if (needIn_ <= remaining_ && needOut_ <= swapOut_) break;
            uint256 cap_ = needOut_ > swapOut_ ? swapOut_ : remaining_;
            uint256 need_ = needOut_ > swapOut_ ? needOut_ : needIn_;
            if (need_ == 0) {
                liquidity_ = 0;
                break;
            }
            uint128 next_ = uint128(uint256(liquidity_) * cap_ / need_);
            liquidity_ = next_ >= liquidity_ ? liquidity_ - 1 : next_;
        }
        uint256 needIn_ = zeroForOne_ ? need0_ : need1_;
        uint256 usedOut_ = zeroForOne_ ? need1_ : need0_;
        sized_.swapIn = swapIn_;
        sized_.swapOut = usedOut_;
        sized_.unswapped = needIn_;
        sized_.remainder = amount_ - swapIn_ - needIn_;
        sized_.liquidity = liquidity_;
    }

    function proportional(uint160 sqrtPriceX96_, uint160 sqrtA_, uint160 sqrtB_, uint256 amount0_, uint256 amount1_)
        internal
        pure
        returns (uint128 liquidity_, uint256 used0_, uint256 used1_)
    {
        liquidity_ = liquidityForAmounts(sqrtPriceX96_, sqrtA_, sqrtB_, amount0_, amount1_);
        while (liquidity_ != 0) {
            (used0_, used1_) = amountsToPay(sqrtPriceX96_, sqrtA_, sqrtB_, liquidity_);
            if (used0_ <= amount0_ && used1_ <= amount1_) return (liquidity_, used0_, used1_);
            uint256 cap_ = used0_ > amount0_ ? amount0_ : amount1_;
            uint256 need_ = used0_ > amount0_ ? used0_ : used1_;
            if (need_ == 0) return (0, 0, 0);
            uint128 next_ = uint128(uint256(liquidity_) * cap_ / need_);
            liquidity_ = next_ >= liquidity_ ? liquidity_ - 1 : next_;
        }
    }

    /// @dev Round up. This is what `modifyLiquidity` charges the caller.
    function amountsToPay(uint160 sqrtPriceX96_, uint160 sqrtA_, uint160 sqrtB_, uint128 liquidity_)
        internal
        pure
        returns (uint256 amount0_, uint256 amount1_)
    {
        if (sqrtA_ > sqrtB_) (sqrtA_, sqrtB_) = (sqrtB_, sqrtA_);
        if (liquidity_ == 0) return (0, 0);
        if (sqrtPriceX96_ <= sqrtA_) {
            amount0_ = SqrtPriceMath.getAmount0Delta(sqrtA_, sqrtB_, liquidity_, true);
        } else if (sqrtPriceX96_ < sqrtB_) {
            amount0_ = SqrtPriceMath.getAmount0Delta(sqrtPriceX96_, sqrtB_, liquidity_, true);
            amount1_ = SqrtPriceMath.getAmount1Delta(sqrtA_, sqrtPriceX96_, liquidity_, true);
        } else {
            amount1_ = SqrtPriceMath.getAmount1Delta(sqrtA_, sqrtB_, liquidity_, true);
        }
    }

    function netShares(uint256 gross_, uint256 clampedFee_, address feeTo_) internal pure returns (uint256 fee_, uint256 net_) {
        if (feeTo_ != address(0) && gross_ != 0 && clampedFee_ != 0) {
            fee_ = FullMath.mulDiv(gross_, clampedFee_, Types.WAD);
            if (fee_ > gross_) fee_ = gross_;
        }
        net_ = gross_ - fee_;
    }

    function claim(uint256 balance_, uint256 shares_, uint256 supply_) internal pure returns (uint256) {
        if (supply_ == 0 || balance_ == 0 || shares_ == 0) return 0;
        return FullMath.mulDiv(balance_, shares_, supply_);
    }

    function _amount0(uint160 sqrtA_, uint160 sqrtB_, uint128 liquidity_) private pure returns (uint256) {
        if (sqrtA_ > sqrtB_) (sqrtA_, sqrtB_) = (sqrtB_, sqrtA_);
        return FullMath.mulDiv(uint256(liquidity_) << FixedPoint96.RESOLUTION, sqrtB_ - sqrtA_, sqrtB_) / sqrtA_;
    }

    function _amount1(uint160 sqrtA_, uint160 sqrtB_, uint128 liquidity_) private pure returns (uint256) {
        if (sqrtA_ > sqrtB_) (sqrtA_, sqrtB_) = (sqrtB_, sqrtA_);
        return FullMath.mulDiv(liquidity_, sqrtB_ - sqrtA_, FixedPoint96.Q96);
    }
}
