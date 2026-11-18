// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {FixedPoint96} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint96.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/SqrtPriceMath.sol";

/// @notice Exact raw-liquidity sizing for the V3 full-spread planner.
/// @dev Inputs are canonical, ordered position bounds. No swap split is selected here.
library UniswapV3FullSpreadStandardExchangeVaultMath {
    uint256 internal constant MIN_SHARES = 1_000;
    uint256 internal constant FEE_CAP = 3e17;

    struct Sized {
        uint256 swapIn;
        uint256 swapOut;
        uint256 used0;
        uint256 used1;
        uint256 remainder;
        uint128 liquidity;
    }

    /// @notice Principal returned by pool.burn, rounded down separately for each token.
    function amountsForLiquidity(uint160 price_, uint160 sqrtA_, uint160 sqrtB_, uint128 liquidity_)
        internal
        pure
        returns (uint256 amount0_, uint256 amount1_)
    {
        return _amounts(price_, sqrtA_, sqrtB_, liquidity_, false);
    }

    /// @notice Exact mint callback debts, rounded up separately for each token.
    function amountsToPay(uint160 price_, uint160 sqrtA_, uint160 sqrtB_, uint128 liquidity_)
        internal
        pure
        returns (uint256 amount0_, uint256 amount1_)
    {
        return _amounts(price_, sqrtA_, sqrtB_, liquidity_, true);
    }

    /// @notice Greatest liquidity funded by both budgets, bounded by pool endpoint capacity.
    /// @dev The inverse is exact: L fits iff ceil(L * token-per-liquidity) <= budget.
    /// There is no search or iterative rounding correction.
    function proportional(
        uint160 price_,
        uint160 sqrtA_,
        uint160 sqrtB_,
        uint256 amount0_,
        uint256 amount1_,
        uint128 capacity_
    ) internal pure returns (uint128 liquidity_, uint256 used0_, uint256 used1_) {
        if (capacity_ == 0 || price_ == 0) return (0, 0, 0);
        if (price_ <= sqrtA_) {
            liquidity_ = _liquidity0(sqrtA_, sqrtB_, amount0_, capacity_);
        } else if (price_ >= sqrtB_) {
            liquidity_ = _liquidity1(sqrtA_, sqrtB_, amount1_, capacity_);
        } else {
            liquidity_ = _liquidity0(price_, sqrtB_, amount0_, capacity_);
            liquidity_ = _liquidity1(sqrtA_, price_, amount1_, liquidity_);
        }
        (used0_, used1_) = amountsToPay(price_, sqrtA_, sqrtB_, liquidity_);
    }

    /// @notice Size the mint following one already-quoted, fully-spent 49% swap.
    /// @dev Success requires consuming every unit of the received token. Only original
    /// input can remain. A zero-liquidity result means execute no swap and refund all.
    function sizeOneSided(
        uint256 amount_,
        bool zeroForOne_,
        uint256 swapIn_,
        uint256 swapOut_,
        uint160 priceAfter_,
        uint160 sqrtA_,
        uint160 sqrtB_,
        uint128 capacity_
    ) internal pure returns (Sized memory sized_) {
        sized_.remainder = amount_;
        if (swapIn_ == 0 || swapOut_ == 0 || swapIn_ > amount_ || capacity_ == 0) return sized_;
        (uint128 liquidity_, uint256 used0_, uint256 used1_) = proportional(
            priceAfter_,
            sqrtA_,
            sqrtB_,
            zeroForOne_ ? amount_ - swapIn_ : swapOut_,
            zeroForOne_ ? swapOut_ : amount_ - swapIn_,
            capacity_
        );
        if (liquidity_ == 0) return sized_;
        uint256 needIn_ = zeroForOne_ ? used0_ : used1_;
        uint256 needOut_ = zeroForOne_ ? used1_ : used0_;
        if (needOut_ != swapOut_ || needIn_ > amount_ - swapIn_) return sized_;
        sized_.swapIn = swapIn_;
        sized_.swapOut = swapOut_;
        sized_.used0 = used0_;
        sized_.used1 = used1_;
        sized_.liquidity = liquidity_;
        sized_.remainder = amount_ - swapIn_ - needIn_;
    }

    /// @notice Wanted-token boundary add; the other token is never swapped.
    function singleTokenAdd(
        uint256 amount_,
        bool token0_,
        uint160 price_,
        uint160 sqrtA_,
        uint160 sqrtB_,
        uint128 capacity_
    ) internal pure returns (Sized memory sized_) {
        (sized_.liquidity, sized_.used0, sized_.used1) = proportional(
            price_, sqrtA_, sqrtB_, token0_ ? amount_ : 0, token0_ ? 0 : amount_, capacity_
        );
        sized_.remainder = amount_ - (token0_ ? sized_.used0 : sized_.used1);
    }

    /// @notice Gross issuance from raw liquidity, including the first-add floor.
    function grossShares(uint128 added_, uint256 supply_, uint128 existing_)
        internal
        pure
        returns (uint256 gross_, bool failed_)
    {
        if (supply_ == 0) {
            if (added_ <= MIN_SHARES) return (0, true);
            return (uint256(added_) - MIN_SHARES, false);
        }
        if (added_ == 0) return (0, false);
        if (existing_ == 0) return (0, true);
        return (FullMath.mulDiv(added_, supply_, existing_), false);
    }

    /// @notice Usage fee is deducted from gross shares and capped without an oracle write.
    function netShares(uint256 gross_, uint256 feeRate_, address feeTo_)
        internal
        pure
        returns (uint256 fee_, uint256 net_)
    {
        if (feeRate_ > FEE_CAP) feeRate_ = FEE_CAP;
        if (feeTo_ != address(0) && feeRate_ != 0) fee_ = FullMath.mulDiv(gross_, feeRate_, 1e18);
        net_ = gross_ - fee_;
    }

    /// @notice Floored pro-rata claim; callers validate shares against supply.
    function claim(uint256 amount_, uint256 shares_, uint256 supply_) internal pure returns (uint256) {
        if (supply_ == 0 || shares_ == 0 || amount_ == 0) return 0;
        return FullMath.mulDiv(amount_, shares_, supply_);
    }

    function _amounts(uint160 price_, uint160 sqrtA_, uint160 sqrtB_, uint128 liquidity_, bool roundUp_)
        private
        pure
        returns (uint256 amount0_, uint256 amount1_)
    {
        if (liquidity_ == 0) return (0, 0);
        if (price_ <= sqrtA_) {
            amount0_ = SqrtPriceMath.getAmount0Delta(sqrtA_, sqrtB_, liquidity_, roundUp_);
        } else if (price_ < sqrtB_) {
            amount0_ = SqrtPriceMath.getAmount0Delta(price_, sqrtB_, liquidity_, roundUp_);
            amount1_ = SqrtPriceMath.getAmount1Delta(sqrtA_, price_, liquidity_, roundUp_);
        } else {
            amount1_ = SqrtPriceMath.getAmount1Delta(sqrtA_, sqrtB_, liquidity_, roundUp_);
        }
    }

    /// @dev Exact floor(amount * a * b / ((b-a) * Q96)).
    /// LiquidityAmounts first floors a*b/Q96, which can understate the greatest L.
    /// Divide amount*a by span into quotient/remainder instead. Once the cap does
    /// not fit, amount*a*b/span < capacity*Q96 < 2**224, so q*b and its sum fit.
    function _liquidity0(uint160 sqrtA_, uint160 sqrtB_, uint256 amount_, uint128 capacity_)
        private
        pure
        returns (uint128)
    {
        if (amount_ == 0 || capacity_ == 0) return 0;
        if (amount_ >= SqrtPriceMath.getAmount0Delta(sqrtA_, sqrtB_, capacity_, true)) return capacity_;
        uint256 span_ = uint256(sqrtB_) - sqrtA_;
        uint256 quotient_ = FullMath.mulDiv(amount_, sqrtA_, span_);
        uint256 remainder_ = mulmod(amount_, sqrtA_, span_);
        uint256 numerator_ = quotient_ * sqrtB_ + FullMath.mulDiv(remainder_, sqrtB_, span_);
        return uint128(numerator_ / FixedPoint96.Q96);
    }

    function _liquidity1(uint160 sqrtA_, uint160 sqrtB_, uint256 amount_, uint128 capacity_)
        private
        pure
        returns (uint128)
    {
        if (amount_ == 0 || capacity_ == 0) return 0;
        if (amount_ >= SqrtPriceMath.getAmount1Delta(sqrtA_, sqrtB_, capacity_, true)) return capacity_;
        return uint128(FullMath.mulDiv(amount_, FixedPoint96.Q96, uint256(sqrtB_) - sqrtA_));
    }
}
