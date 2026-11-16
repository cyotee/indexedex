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
        if (swapIn_ == 0 || swapOut_ == 0 || swapIn_ > amount_) {
            sized_.remainder = amount_;
            return sized_;
        }
        uint256 remaining_ = amount_ - swapIn_;
        uint128 liquidity_ = _liquidityFittingOut(zeroForOne_, sqrtAfter_, sqrtA_, sqrtB_, swapOut_);
        if (liquidity_ == 0) {
            sized_.remainder = amount_;
            return sized_;
        }
        (uint256 need0_, uint256 need1_) = amountsToPay(sqrtAfter_, sqrtA_, sqrtB_, liquidity_);
        uint256 needIn_ = zeroForOne_ ? need0_ : need1_;
        uint256 needOut_ = zeroForOne_ ? need1_ : need0_;
        if (needOut_ != swapOut_ || needIn_ > remaining_) {
            sized_.remainder = amount_;
            return sized_;
        }
        sized_.swapIn = swapIn_;
        sized_.swapOut = needOut_;
        sized_.unswapped = needIn_;
        sized_.remainder = remaining_ - needIn_;
        sized_.liquidity = liquidity_;
    }

    /// @dev Same liquidity as `LiquidityAmounts`, or zero when the result does not fit `uint128`.
    function _liquidityFittingOut(
        bool zeroForOne_,
        uint160 sqrtAfter_,
        uint160 sqrtA_,
        uint160 sqrtB_,
        uint256 amountOut_
    ) private pure returns (uint128) {
        if (amountOut_ == 0) return 0;
        uint160 lo_ = zeroForOne_ ? sqrtA_ : sqrtAfter_;
        uint160 hi_ = zeroForOne_ ? sqrtAfter_ : sqrtB_;
        if (lo_ > hi_) (lo_, hi_) = (hi_, lo_);
        if (lo_ == hi_) return 0;
        uint256 span_ = uint256(hi_) - uint256(lo_);
        uint256 raw_ = zeroForOne_
            ? FullMath.mulDiv(amountOut_, FixedPoint96.Q96, span_)
            : FullMath.mulDiv(amountOut_, FullMath.mulDiv(lo_, hi_, FixedPoint96.Q96), span_);
        if (raw_ == 0 || raw_ > type(uint128).max) return 0;
        return uint128(raw_);
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

    /// @dev Fee-excluded input for the locked one-swap size. Zero means swap nothing.
    function quadraticInput(
        uint256 amount_,
        bool zeroForOne_,
        uint160 sqrtPrice_,
        uint160 sqrtLower_,
        uint160 sqrtUpper_,
        uint128 active_,
        uint24 feePips_
    ) internal pure returns (uint256 n_) {
        if (amount_ == 0 || active_ == 0 || feePips_ >= 1_000_000 || sqrtPrice_ <= sqrtLower_ || sqrtPrice_ >= sqrtUpper_) {
            return 0;
        }
        (uint256 am_, int256 ae_, bool negA_, uint256 bm_, int256 be_, uint256 cm_, int256 ce_) = zeroForOne_
            ? _coeff0(amount_, sqrtPrice_, sqrtLower_, sqrtUpper_, active_, feePips_)
            : _coeff1(amount_, sqrtPrice_, sqrtLower_, sqrtUpper_, active_, feePips_);
        if (bm_ == 0 || cm_ == 0) return 0;
        uint256 nRaw_ = _positiveRoot(am_, ae_, negA_, bm_, be_, cm_, ce_);
        if (nRaw_ == 0 || nRaw_ > amount_) return 0;
        n_ = nRaw_;
    }

    function boundaryInput(bool zeroForOne_, uint160 sqrtPrice_, uint160 sqrtBound_, uint128 active_) internal pure returns (uint256) {
        if (active_ == 0 || sqrtPrice_ == 0 || sqrtBound_ == 0) return 0;
        if (zeroForOne_) {
            if (sqrtBound_ >= sqrtPrice_) return 0;
            return FullMath.mulDiv(FullMath.mulDiv(active_, FixedPoint96.Q96, sqrtPrice_), sqrtPrice_ - sqrtBound_, sqrtBound_);
        }
        if (sqrtBound_ <= sqrtPrice_) return 0;
        return FullMath.mulDiv(active_, sqrtBound_ - sqrtPrice_, FixedPoint96.Q96);
    }

    /// @dev Gross exact-input. `n / g`, rounded down. Zero means swap nothing.
    function grossFromNet(uint256 n_, uint24 feePips_) internal pure returns (uint256) {
        if (n_ == 0 || feePips_ >= 1_000_000) return 0;
        return FullMath.mulDiv(n_, 1_000_000, 1_000_000 - feePips_);
    }

    /// @dev Outside the position the wanted token is added with no swap.
    function singleTokenAdd(uint256 amount_, bool zeroForOne_, uint160 sqrtPrice_, uint160 sqrtA_, uint160 sqrtB_)
        internal
        pure
        returns (Sized memory sized_)
    {
        if (amount_ == 0) return sized_;
        uint128 liquidity_ = zeroForOne_
            ? LiquidityAmounts.getLiquidityForAmount0(sqrtA_, sqrtB_, amount_)
            : LiquidityAmounts.getLiquidityForAmount1(sqrtA_, sqrtB_, amount_);
        uint256 used_;
        while (liquidity_ != 0) {
            (uint256 need0_, uint256 need1_) = amountsToPay(sqrtPrice_, sqrtA_, sqrtB_, liquidity_);
            uint256 other_ = zeroForOne_ ? need1_ : need0_;
            used_ = zeroForOne_ ? need0_ : need1_;
            if (other_ != 0 || used_ == 0) {
                liquidity_ = 0;
                break;
            }
            if (used_ <= amount_) break;
            uint128 next_ = uint128(uint256(liquidity_) * amount_ / used_);
            liquidity_ = next_ >= liquidity_ ? liquidity_ - 1 : next_;
        }
        if (liquidity_ == 0) {
            sized_.remainder = amount_;
            return sized_;
        }
        sized_.liquidity = liquidity_;
        sized_.unswapped = used_;
        sized_.remainder = amount_ - used_;
    }

    function _positiveRoot(
        uint256 am_,
        int256 ae_,
        bool negA_,
        uint256 bm_,
        int256 be_,
        uint256 cm_,
        int256 ce_
    ) private pure returns (uint256) {
        if (am_ == 0) return _divUint(cm_, ce_, bm_, be_);
        (uint256 b2m_, int256 b2e_) = _mul(bm_, be_, bm_, be_);
        (uint256 acm_, int256 ace_) = _mul(am_, ae_, cm_, ce_);
        ace_ += 2;
        uint256 dm_;
        int256 de_;
        bool ok_ = true;
        if (negA_) (dm_, de_) = _add(b2m_, b2e_, acm_, ace_);
        else (dm_, de_, ok_) = _sub(b2m_, b2e_, acm_, ace_);
        if (!ok_ || dm_ == 0) return 0;
        (uint256 rm_, int256 re_) = _sqrtW(dm_, de_);
        (uint256 denM_, int256 denE_) = _add(bm_, be_, rm_, re_);
        if (denM_ == 0) return 0;
        return _divUint(cm_, ce_ + 1, denM_, denE_);
    }

    function _coeff0(
        uint256 amount_,
        uint160 sqrtPrice_,
        uint160 sqrtLower_,
        uint160 sqrtUpper_,
        uint128 active_,
        uint24 feePips_
    ) private pure returns (uint256 am_, int256 ae_, bool negA_, uint256 bm_, int256 be_, uint256 cm_, int256 ce_) {
        uint256 gNum_ = 1_000_000 - feePips_;
        uint256 gapL_ = sqrtPrice_ - sqrtLower_;
        uint256 gapU_ = sqrtUpper_ - sqrtPrice_;
        (uint256 lM_, int256 lE_) = _m2(sqrtLower_, 1_000_000);
        (uint256 rM_, int256 rE_) = _m2(sqrtPrice_, gNum_);
        (uint256 dM_, int256 dE_, bool neg_) = _absDiff(lM_, lE_, rM_, rE_);
        if (dM_ != 0) {
            (uint256 pM_, int256 pE_) = _m2(sqrtPrice_, sqrtUpper_);
            (am_, ae_) = _mul(pM_, pE_, dM_, dE_);
            negA_ = neg_;
        }
        (uint256 b1m_, int256 b1e_) = _m5(sqrtUpper_, amount_, sqrtPrice_, sqrtLower_, gNum_);
        (uint256 b2m_, int256 b2e_) = _m5(sqrtUpper_, active_, gapL_, 1_000_000, FixedPoint96.Q96);
        (uint256 b3m_, int256 b3e_) = _m5(sqrtPrice_, active_, gapU_, FixedPoint96.Q96, gNum_);
        (bm_, be_) = _add3(b1m_, b1e_, b2m_, b2e_, b3m_, b3e_);
        (cm_, ce_) = _m6(sqrtUpper_, amount_, active_, gapL_, FixedPoint96.Q96, gNum_);
    }

    function _coeff1(
        uint256 amount_,
        uint160 sqrtPrice_,
        uint160 sqrtLower_,
        uint160 sqrtUpper_,
        uint128 active_,
        uint24 feePips_
    ) private pure returns (uint256 am_, int256 ae_, bool negA_, uint256 bm_, int256 be_, uint256 cm_, int256 ce_) {
        uint256 gNum_ = 1_000_000 - feePips_;
        uint256 gapL_ = sqrtPrice_ - sqrtLower_;
        uint256 gapU_ = sqrtUpper_ - sqrtPrice_;
        (uint256 lM_, int256 lE_) = _m2(sqrtPrice_, 1_000_000);
        (uint256 rM_, int256 rE_) = _m2(sqrtUpper_, gNum_);
        (uint256 dM_, int256 dE_, bool neg_) = _absDiff(lM_, lE_, rM_, rE_);
        if (dM_ != 0) {
            (uint256 qM_, int256 qE_) = _w(FixedPoint96.Q96);
            (am_, ae_) = _mul(dM_, dE_, qM_, qE_);
            negA_ = neg_;
        }
        (uint256 b1m_, int256 b1e_) = _m4(sqrtPrice_, amount_, FixedPoint96.Q96, gNum_);
        (uint256 b2m_, int256 b2e_) = _m4(sqrtPrice_, active_, gapU_, 1_000_000);
        (uint256 b3m_, int256 b3e_) = _m4(sqrtUpper_, active_, gapL_, gNum_);
        (bm_, be_) = _add3(b1m_, b1e_, b2m_, b2e_, b3m_, b3e_);
        (cm_, ce_) = _m5(sqrtPrice_, amount_, active_, gapU_, gNum_);
    }

    function _w(uint256 x_) private pure returns (uint256 m_, int256 e_) {
        if (x_ == 0) return (0, 0);
        uint256 bits_ = _bitLength(x_);
        m_ = x_ << (256 - bits_);
        e_ = int256(bits_) - 256;
    }

    function _m2(uint256 a_, uint256 b_) private pure returns (uint256 m_, int256 e_) {
        (uint256 am_, int256 ae_) = _w(a_);
        (uint256 bm_, int256 be_) = _w(b_);
        return _mul(am_, ae_, bm_, be_);
    }

    function _m3(uint256 a_, uint256 b_, uint256 c_) private pure returns (uint256 m_, int256 e_) {
        (uint256 am_, int256 ae_) = _m2(a_, b_);
        (uint256 cm_, int256 ce_) = _w(c_);
        return _mul(am_, ae_, cm_, ce_);
    }

    function _m4(uint256 a_, uint256 b_, uint256 c_, uint256 d_) private pure returns (uint256 m_, int256 e_) {
        (uint256 am_, int256 ae_) = _m3(a_, b_, c_);
        (uint256 dm_, int256 de_) = _w(d_);
        return _mul(am_, ae_, dm_, de_);
    }

    function _m5(uint256 a_, uint256 b_, uint256 c_, uint256 d_, uint256 eIn_)
        private
        pure
        returns (uint256 m_, int256 e_)
    {
        (uint256 am_, int256 ae_) = _m4(a_, b_, c_, d_);
        (uint256 em_, int256 ee_) = _w(eIn_);
        return _mul(am_, ae_, em_, ee_);
    }

    function _m6(uint256 a_, uint256 b_, uint256 c_, uint256 d_, uint256 eIn_, uint256 f_)
        private
        pure
        returns (uint256 m_, int256 e_)
    {
        (uint256 am_, int256 ae_) = _m5(a_, b_, c_, d_, eIn_);
        (uint256 fm_, int256 fe_) = _w(f_);
        return _mul(am_, ae_, fm_, fe_);
    }

    function _mul(uint256 am_, int256 ae_, uint256 bm_, int256 be_) private pure returns (uint256 m_, int256 e_) {
        if (am_ == 0 || bm_ == 0) return (0, 0);
        uint256 hi_;
        uint256 lo_;
        assembly ("memory-safe") {
            let mm := mulmod(am_, bm_, not(0))
            lo_ := mul(am_, bm_)
            hi_ := sub(sub(mm, lo_), lt(mm, lo_))
        }
        if (hi_ == 0) {
            (m_, e_) = _w(lo_);
            e_ += ae_ + be_;
            return (m_, e_);
        }
        m_ = hi_;
        e_ = ae_ + be_ + 256;
        if (m_ < (uint256(1) << 255)) {
            uint256 up_ = 256 - _bitLength(m_);
            m_ = (m_ << up_) | (lo_ >> (256 - up_));
            e_ -= int256(up_);
        }
    }

    function _add(uint256 am_, int256 ae_, uint256 bm_, int256 be_) private pure returns (uint256 m_, int256 e_) {
        if (am_ == 0) return (bm_, be_);
        if (bm_ == 0) return (am_, ae_);
        if (ae_ < be_) return _add(bm_, be_, am_, ae_);
        uint256 diff_ = uint256(ae_ - be_);
        uint256 bs_ = diff_ >= 256 ? 0 : bm_ >> diff_;
        unchecked {
            uint256 sum_ = am_ + bs_;
            if (sum_ < am_) {
                m_ = (am_ >> 1) + (bs_ >> 1) + ((am_ & 1) & (bs_ & 1));
                e_ = ae_ + 1;
            } else {
                m_ = sum_;
                e_ = ae_;
            }
        }
        return _norm(m_, e_);
    }

    function _add3(
        uint256 a0_,
        int256 e0_,
        uint256 a1_,
        int256 e1_,
        uint256 a2_,
        int256 e2_
    ) private pure returns (uint256 m_, int256 e_) {
        (m_, e_) = _add(a0_, e0_, a1_, e1_);
        return _add(m_, e_, a2_, e2_);
    }

    function _sub(uint256 am_, int256 ae_, uint256 bm_, int256 be_) private pure returns (uint256 m_, int256 e_, bool ok_) {
        if (_cmp(am_, ae_, bm_, be_) < 0) return (0, 0, false);
        if (bm_ == 0) return (am_, ae_, true);
        if (ae_ >= be_) {
            uint256 diff_ = uint256(ae_ - be_);
            m_ = am_ - (diff_ >= 256 ? 0 : bm_ >> diff_);
            e_ = ae_;
        } else {
            uint256 diff_ = uint256(be_ - ae_);
            if (diff_ >= 256 || (bm_ << diff_) >> diff_ != bm_ || (bm_ << diff_) > am_) return (0, 0, false);
            m_ = am_ - (bm_ << diff_);
            e_ = ae_;
        }
        (m_, e_) = _norm(m_, e_);
        ok_ = true;
    }

    function _absDiff(uint256 am_, int256 ae_, uint256 bm_, int256 be_)
        private
        pure
        returns (uint256 m_, int256 e_, bool neg_)
    {
        int256 cmp_ = _cmp(am_, ae_, bm_, be_);
        if (cmp_ == 0) return (0, 0, false);
        if (cmp_ > 0) {
            (m_, e_,) = _sub(am_, ae_, bm_, be_);
            return (m_, e_, false);
        }
        (m_, e_,) = _sub(bm_, be_, am_, ae_);
        neg_ = true;
    }

    function _cmp(uint256 am_, int256 ae_, uint256 bm_, int256 be_) private pure returns (int256) {
        if (am_ == 0 && bm_ == 0) return 0;
        if (am_ == 0) return -1;
        if (bm_ == 0) return 1;
        if (ae_ != be_) return ae_ > be_ ? int256(1) : int256(-1);
        if (am_ == bm_) return 0;
        return am_ > bm_ ? int256(1) : int256(-1);
    }

    function _norm(uint256 m_, int256 e_) private pure returns (uint256, int256) {
        if (m_ == 0 || m_ >= (uint256(1) << 255)) return (m_, e_);
        uint256 up_ = 256 - _bitLength(m_);
        return (m_ << up_, e_ - int256(up_));
    }

    function _sqrtW(uint256 m_, int256 e_) private pure returns (uint256 sm_, int256 se_) {
        if (m_ == 0) return (0, 0);
        if ((e_ & 1) != 0) {
            m_ >>= 1;
            e_ += 1;
        }
        (sm_, se_) = _w(_sqrt(m_));
        se_ += e_ / 2;
    }

    function _divUint(uint256 nm_, int256 ne_, uint256 dm_, int256 de_) private pure returns (uint256) {
        if (nm_ == 0 || dm_ == 0) return 0;
        uint256 q_ = FullMath.mulDiv(nm_, uint256(1) << 128, dm_);
        int256 exp_ = ne_ - de_ - 128;
        if (exp_ >= 0) {
            if (exp_ >= 256 || q_ > type(uint256).max >> uint256(exp_)) return 0;
            return q_ << uint256(exp_);
        }
        uint256 sh_ = uint256(-exp_);
        if (sh_ >= 256) return 0;
        return q_ >> sh_;
    }

    function _sqrt(uint256 x_) private pure returns (uint256 z_) {
        if (x_ == 0) return 0;
        z_ = x_;
        uint256 y_ = (x_ + 1) / 2;
        while (y_ < z_) {
            z_ = y_;
            y_ = (x_ / y_ + y_) / 2;
        }
    }

    function _bitLength(uint256 x_) private pure returns (uint256 n_) {
        if (x_ == 0) return 0;
        if (x_ >= 1 << 128) {
            x_ >>= 128;
            n_ += 128;
        }
        if (x_ >= 1 << 64) {
            x_ >>= 64;
            n_ += 64;
        }
        if (x_ >= 1 << 32) {
            x_ >>= 32;
            n_ += 32;
        }
        if (x_ >= 1 << 16) {
            x_ >>= 16;
            n_ += 16;
        }
        if (x_ >= 1 << 8) {
            x_ >>= 8;
            n_ += 8;
        }
        if (x_ >= 1 << 4) {
            x_ >>= 4;
            n_ += 4;
        }
        if (x_ >= 1 << 2) {
            x_ >>= 2;
            n_ += 2;
        }
        if (x_ >= 1 << 1) n_ += 1;
        n_ += 1;
    }
}

/// @dev Exposes the internal sizing math to the lock tests. Not a vault facet.
contract UniswapV4FullSpreadMathHarness {
    function quadraticInput(
        uint256 amount_,
        bool zeroForOne_,
        uint160 sqrtPrice_,
        uint160 sqrtLower_,
        uint160 sqrtUpper_,
        uint128 active_,
        uint24 feePips_
    ) external pure returns (uint256) {
        return UniswapV4FullSpreadStandardExchangeVaultMath.quadraticInput(
            amount_, zeroForOne_, sqrtPrice_, sqrtLower_, sqrtUpper_, active_, feePips_
        );
    }

    function boundaryInput(bool zeroForOne_, uint160 sqrtPrice_, uint160 sqrtBound_, uint128 active_)
        external
        pure
        returns (uint256)
    {
        return UniswapV4FullSpreadStandardExchangeVaultMath.boundaryInput(zeroForOne_, sqrtPrice_, sqrtBound_, active_);
    }

    function grossFromNet(uint256 n_, uint24 feePips_) external pure returns (uint256) {
        return UniswapV4FullSpreadStandardExchangeVaultMath.grossFromNet(n_, feePips_);
    }
}
