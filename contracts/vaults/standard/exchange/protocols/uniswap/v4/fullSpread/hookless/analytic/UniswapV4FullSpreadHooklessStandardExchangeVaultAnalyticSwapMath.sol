// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
import {ProtocolFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "../UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath as Protection} from "../UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol";

// tag::UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath[]
/// @notice Independent integer sizing for one fixed-liquidity segment.
/// @dev Coefficients are the PRD expansion after clearing pool liquidity, the
///      1_000_000 fee denominator, and the Q96 price denominator. This file does
///      not copy Aperture or uni-v3-lib source. Limb 7 overflow is Unrepresentable.
library UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath {
    uint256 internal constant FEE = 1_000_000;
    uint256 internal constant Q96 = 1 << 96;
    uint256 internal constant DIGIT_BASE = 1 << 16;
    uint256 internal constant PAIR_BITS = 32;
    uint256 internal constant PAIR_COUNT = 64;

    enum Failure {
        None,
        Degenerate,
        NegativeDiscriminant,
        OutOfDomain,
        Unrepresentable,
        ZeroLiquidity,
        EmptyBook
    }

    struct Signed2048 {
        bool negative;
        Types.Uint2048 magnitude;
    }

    struct SegmentInput {
        uint160 sqrtPriceX96;
        uint128 poolLiquidity;
        uint128 ownedLiquidity;
        uint24 lpFeePips;
        uint16 protocolFeePips;
        uint256 incumbentIn;
        uint256 incumbentOut;
        uint256 callerInRemaining;
        uint256 callerOutAccumulated;
        bool zeroForOne;
    }

    struct Candidate {
        uint256 swapIn;
        Failure failure;
    }

    struct Coefficients {
        Signed2048 a;
        Signed2048 b;
        Signed2048 c;
        bool ok;
    }

    /// @notice One floored in-domain root. No +1 correction and no neighbor trial.
    function _candidate(SegmentInput memory input_) public pure returns (Candidate memory candidate_) {
        if (input_.poolLiquidity == 0) return _fail(Failure.ZeroLiquidity);
        if (input_.sqrtPriceX96 == 0 || input_.protocolFeePips > FEE) return _fail(Failure.Degenerate);
        if (input_.ownedLiquidity > input_.poolLiquidity) return _fail(Failure.OutOfDomain);
        if (input_.incumbentIn == 0 || input_.incumbentOut == 0) return _fail(Failure.Degenerate);
        if (input_.callerInRemaining == 0) return _fail(Failure.EmptyBook);
        uint24 swapFee = ProtocolFeeLibrary.calculateSwapFee(input_.protocolFeePips, input_.lpFeePips);
        if (swapFee >= FEE) return _fail(Failure.Degenerate);
        Coefficients memory coefficients = _coefficients(input_, FEE - swapFee, FEE - input_.protocolFeePips);
        if (!coefficients.ok) return _fail(Failure.Unrepresentable);
        return _solve(coefficients.a, coefficients.b, coefficients.c, input_.callerInRemaining);
    }

    /// @dev Same root conversion `_candidate` uses after the cleared expansion.
    function _solve(Signed2048 memory a_, Signed2048 memory b_, Signed2048 memory c_, uint256 limit_)
        internal pure returns (Candidate memory candidate_)
    {
        if (_isZero(a_) && _isZero(b_)) return _fail(Failure.Degenerate);
        if (_isZero(a_)) return _linear(b_, c_, limit_);
        return _quadratic(a_, b_, c_, limit_);
    }

    function _quadratic(Signed2048 memory a_, Signed2048 memory b_, Signed2048 memory c_, uint256 limit_)
        private pure returns (Candidate memory candidate_)
    {
        (Signed2048 memory disc, bool discOk, bool negative) = _discriminant(a_, b_, c_);
        if (!discOk) return _fail(Failure.Unrepresentable);
        if (negative) return _fail(Failure.NegativeDiscriminant);
        (candidate_.swapIn, candidate_.failure) = _smallerRoot(a_, b_, disc, limit_);
    }

    function _smallerRoot(Signed2048 memory a_, Signed2048 memory b_, Signed2048 memory disc_, uint256 limit_)
        private pure returns (uint256 swapIn_, Failure failure_)
    {
        (Types.Uint2048 memory root, bool sqrtOk) = _floorSqrt2048(disc_.magnitude);
        if (!sqrtOk) return (0, Failure.Unrepresentable);
        (Signed2048 memory twoA, bool twoOk) = _add(a_, a_);
        if (!twoOk || _isZero(twoA)) return (0, Failure.Unrepresentable);
        (uint256 plus, bool plusOk) = _offsetRoot(b_, root, twoA, limit_, true);
        (uint256 minus, bool minusOk) = _offsetRoot(b_, root, twoA, limit_, false);
        if (!plusOk && !minusOk) return (0, Failure.OutOfDomain);
        if (plusOk && minusOk) return (plus < minus ? plus : minus, Failure.None);
        return (plusOk ? plus : minus, Failure.None);
    }

    function _offsetRoot(
        Signed2048 memory b_, Types.Uint2048 memory sqrtDisc_, Signed2048 memory twoA_, uint256 limit_, bool plus_
    ) private pure returns (uint256 value_, bool ok_) {
        Signed2048 memory sqrtDisc = Signed2048({negative: false, magnitude: sqrtDisc_});
        (Signed2048 memory negB, bool negOk) = _neg(b_);
        if (!negOk) return (0, false);
        (Signed2048 memory numerator, bool addOk) = plus_ ? _add(negB, sqrtDisc) : _sub(negB, sqrtDisc);
        if (!addOk) return (0, false);
        return _flooredInDomain(numerator, twoA_, limit_);
    }

    function _coefficients(SegmentInput memory input_, uint256 gNum_, uint256 oneMinusPhi_)
        private pure returns (Coefficients memory built_)
    {
        built_.ok = true;
        (Signed2048 memory gap, bool gapOk) = _priceGap(input_);
        if (!gapOk) return _bad(built_);
        uint256 priceSpan = input_.zeroForOne ? Q96 : input_.sqrtPriceX96;
        uint256 priceSquare = input_.zeroForOne ? Q96 : input_.sqrtPriceX96;
        (built_.a, built_.ok) = _capitalA(input_, gNum_, oneMinusPhi_, gap, priceSpan);
        if (!built_.ok) return built_;
        (built_.b, built_.ok) = _capitalB(input_, gNum_, oneMinusPhi_, gap, priceSpan, priceSquare);
        if (!built_.ok) return built_;
        (built_.c, built_.ok) = _capitalC(input_, priceSquare);
    }

    function _priceGap(SegmentInput memory input_) private pure returns (Signed2048 memory gap_, bool ok_) {
        if (input_.zeroForOne) {
            (Signed2048 memory left, bool leftOk) = _mulUint(_from(input_.incumbentOut), Q96);
            (Signed2048 memory right, bool rightOk) = _mulUint(_from(input_.ownedLiquidity), input_.sqrtPriceX96);
            if (!leftOk || !rightOk) return (gap_, false);
            return _sub(left, right);
        }
        (Signed2048 memory leftOne, bool leftOneOk) = _mulUint(_from(input_.incumbentOut), input_.sqrtPriceX96);
        (Signed2048 memory rightOne, bool rightOneOk) = _mulUint(_from(input_.ownedLiquidity), Q96);
        if (!leftOneOk || !rightOneOk) return (gap_, false);
        return _sub(leftOne, rightOne);
    }

    function _capitalA(
        SegmentInput memory input_, uint256 gNum_, uint256 oneMinusPhi_, Signed2048 memory gap_, uint256 priceSpan_
    ) private pure returns (Signed2048 memory result_, bool ok_) {
        uint256[6] memory lead;
        lead[0] = gNum_;
        lead[1] = input_.zeroForOne ? input_.sqrtPriceX96 : Q96;
        lead[2] = input_.poolLiquidity;
        lead[3] = FEE;
        (result_, ok_) = _mulSignedFactors(gap_, lead, 4);
        if (!ok_) return (result_, false);
        (Signed2048 memory second, bool secondOk) = _positiveProduct(_ownedFeeSquare(input_, gNum_, oneMinusPhi_, true));
        (Signed2048 memory third, bool thirdOk) = _positiveProduct(_callerFeeSpan(input_, gNum_, oneMinusPhi_, priceSpan_));
        if (!secondOk || !thirdOk) return (result_, false);
        (result_, ok_) = _add(result_, second);
        if (!ok_) return (result_, false);
        return _add(result_, third);
    }

    function _capitalB(
        SegmentInput memory input_,
        uint256 gNum_,
        uint256 oneMinusPhi_,
        Signed2048 memory gap_,
        uint256 priceSpan_,
        uint256 priceSquare_
    ) private pure returns (Signed2048 memory result_, bool ok_) {
        (result_, ok_) = _positiveProduct(_inputGrowth(input_, gNum_, priceSquare_));
        if (!ok_) return (result_, false);
        (result_, ok_) = _addGap(result_, input_, gNum_, gap_);
        if (!ok_) return (result_, false);
        (result_, ok_) = _addProduct(result_, _principalScale(input_, priceSquare_));
        if (!ok_) return (result_, false);
        (result_, ok_) = _addProduct(result_, _earnedGrowth(input_, gNum_, priceSpan_));
        if (!ok_) return (result_, false);
        return _addProduct(result_, _earnedOwned(input_, oneMinusPhi_, priceSquare_));
    }

    function _addGap(Signed2048 memory total_, SegmentInput memory input_, uint256 gNum_, Signed2048 memory gap_)
        private pure returns (Signed2048 memory result_, bool ok_)
    {
        (Signed2048 memory debit, bool debitOk) = _gapDebit(input_, gNum_, gap_);
        if (!debitOk) return (result_, false);
        return _add(total_, debit);
    }

    function _addProduct(Signed2048 memory total_, uint256[8] memory factors_)
        private pure returns (Signed2048 memory result_, bool ok_)
    {
        (Signed2048 memory term, bool termOk) = _positiveProduct(factors_);
        if (!termOk) return (result_, false);
        return _add(total_, term);
    }

    function _capitalC(SegmentInput memory input_, uint256 priceSquare_)
        private pure returns (Signed2048 memory result_, bool ok_)
    {
        (Signed2048 memory earned, bool earnedOk) = _mulUint(_from(input_.callerOutAccumulated), input_.incumbentIn);
        (Signed2048 memory spent, bool spentOk) = _mulUint(_from(input_.callerInRemaining), input_.incumbentOut);
        if (!earnedOk || !spentOk) return (result_, false);
        (Signed2048 memory net, bool netOk) = _sub(earned, spent);
        if (!netOk) return (result_, false);
        uint256[6] memory factors;
        factors[0] = input_.poolLiquidity;
        factors[1] = input_.poolLiquidity;
        factors[2] = FEE;
        factors[3] = FEE;
        factors[4] = priceSquare_;
        factors[5] = priceSquare_;
        return _mulSignedFactors(net, factors, 6);
    }

    function _inputGrowth(SegmentInput memory input_, uint256 gNum_, uint256 priceSquare_)
        private pure returns (uint256[8] memory factors_)
    {
        factors_[0] = input_.incumbentIn;
        factors_[1] = input_.poolLiquidity;
        factors_[2] = input_.poolLiquidity;
        factors_[3] = gNum_;
        factors_[4] = input_.zeroForOne ? input_.sqrtPriceX96 : Q96;
        factors_[5] = input_.zeroForOne ? input_.sqrtPriceX96 : Q96;
        factors_[6] = FEE;
        factors_[7] = input_.zeroForOne ? 1 : priceSquare_ == 0 ? 0 : 1;
        if (!input_.zeroForOne) {
            factors_[4] = Q96;
            factors_[5] = Q96;
        }
    }

    function _principalScale(SegmentInput memory input_, uint256 priceSquare_)
        private pure returns (uint256[8] memory factors_)
    {
        factors_[0] = input_.incumbentOut;
        factors_[1] = input_.poolLiquidity;
        factors_[2] = input_.poolLiquidity;
        factors_[3] = FEE;
        factors_[4] = FEE;
        factors_[5] = priceSquare_;
        factors_[6] = priceSquare_;
        factors_[7] = 1;
    }

    function _earnedGrowth(SegmentInput memory input_, uint256 gNum_, uint256 priceSpan_)
        private pure returns (uint256[8] memory factors_)
    {
        factors_[0] = input_.callerOutAccumulated;
        factors_[1] = input_.incumbentIn;
        factors_[2] = gNum_;
        factors_[3] = input_.zeroForOne ? input_.sqrtPriceX96 : Q96;
        factors_[4] = input_.poolLiquidity;
        factors_[5] = FEE;
        factors_[6] = priceSpan_;
        factors_[7] = 1;
    }

    function _earnedOwned(SegmentInput memory input_, uint256 oneMinusPhi_, uint256 priceSquare_)
        private pure returns (uint256[8] memory factors_)
    {
        factors_[0] = input_.callerOutAccumulated;
        factors_[1] = input_.ownedLiquidity;
        factors_[2] = oneMinusPhi_;
        factors_[3] = input_.poolLiquidity;
        factors_[4] = FEE;
        factors_[5] = priceSquare_;
        factors_[6] = priceSquare_;
        factors_[7] = 1;
    }

    function _ownedFeeSquare(SegmentInput memory input_, uint256 gNum_, uint256 oneMinusPhi_, bool squarePrice_)
        private pure returns (uint256[8] memory factors_)
    {
        factors_[0] = input_.poolLiquidity;
        factors_[1] = input_.ownedLiquidity;
        factors_[2] = oneMinusPhi_;
        factors_[3] = gNum_;
        if (input_.zeroForOne) {
            factors_[4] = input_.sqrtPriceX96;
            factors_[5] = input_.sqrtPriceX96;
            factors_[6] = 1;
        } else {
            factors_[4] = Q96;
            factors_[5] = Q96;
            factors_[6] = 1;
        }
        factors_[7] = squarePrice_ ? 1 : 1;
    }

    function _callerFeeSpan(SegmentInput memory input_, uint256 gNum_, uint256 oneMinusPhi_, uint256 priceSpan_)
        private pure returns (uint256[8] memory factors_)
    {
        factors_[0] = input_.callerOutAccumulated;
        factors_[1] = input_.ownedLiquidity;
        factors_[2] = oneMinusPhi_;
        factors_[3] = gNum_;
        factors_[4] = input_.zeroForOne ? input_.sqrtPriceX96 : Q96;
        factors_[5] = priceSpan_;
        factors_[6] = 1;
        factors_[7] = 1;
    }

    function _gapDebit(SegmentInput memory input_, uint256 gNum_, Signed2048 memory gap_)
        private pure returns (Signed2048 memory result_, bool ok_)
    {
        uint256[6] memory factors;
        factors[0] = input_.callerInRemaining;
        factors[1] = gNum_;
        factors[2] = input_.zeroForOne ? input_.sqrtPriceX96 : Q96;
        factors[3] = input_.poolLiquidity;
        factors[4] = FEE;
        (result_, ok_) = _mulSignedFactors(gap_, factors, 5);
        if (!ok_) return (result_, false);
        return _neg(result_);
    }

    function _positiveProduct(uint256[8] memory factors_) private pure returns (Signed2048 memory result_, bool ok_) {
        Types.Uint2048 memory magnitude;
        magnitude.limb[0] = 1;
        for (uint256 i; i < 8; ++i) {
            if (factors_[i] == 0) return (result_, true);
            if (factors_[i] == 1) continue;
            (magnitude, ok_) = _mulMagUint(magnitude, factors_[i]);
            if (!ok_) return (result_, false);
        }
        result_.magnitude = magnitude;
        ok_ = true;
    }

    function _mulSignedFactors(Signed2048 memory value_, uint256[6] memory factors_, uint256 count_)
        private pure returns (Signed2048 memory result_, bool ok_)
    {
        result_ = _copySigned(value_);
        ok_ = true;
        for (uint256 i; i < count_; ++i) {
            if (factors_[i] == 0) return (_from(0), true);
            if (factors_[i] == 1) continue;
            (result_.magnitude, ok_) = _mulMagUint(result_.magnitude, factors_[i]);
            if (!ok_) return (result_, false);
        }
    }

    function _linear(Signed2048 memory b_, Signed2048 memory c_, uint256 limit_)
        private pure returns (Candidate memory candidate_)
    {
        (Signed2048 memory negC, bool negOk) = _neg(c_);
        if (!negOk) return _fail(Failure.Unrepresentable);
        (uint256 value, bool ok) = _flooredInDomain(negC, b_, limit_);
        if (!ok) return _fail(Failure.OutOfDomain);
        candidate_.swapIn = value;
    }

    function _flooredInDomain(Signed2048 memory numerator_, Signed2048 memory denominator_, uint256 limit_)
        private pure returns (uint256 value_, bool ok_)
    {
        if (_isZero(denominator_)) return (0, false);
        (Signed2048 memory quotient, bool divOk) = _floorDiv(numerator_, denominator_);
        if (!divOk || quotient.negative || _isZero(quotient)) return (0, false);
        if (!_fitsUint(quotient.magnitude)) return (0, false);
        value_ = quotient.magnitude.limb[0];
        ok_ = value_ > 0 && value_ <= limit_;
        if (!ok_) value_ = 0;
    }

    function _discriminant(Signed2048 memory a_, Signed2048 memory b_, Signed2048 memory c_)
        private pure returns (Signed2048 memory disc_, bool ok_, bool negative_)
    {
        (Signed2048 memory square, bool squareOk) = _square(b_);
        (Signed2048 memory product, bool productOk) = _mul(a_, c_);
        if (!squareOk || !productOk) return (disc_, false, false);
        (product, productOk) = _add(product, product);
        if (!productOk) return (disc_, false, false);
        (product, productOk) = _add(product, product);
        if (!productOk) return (disc_, false, false);
        (disc_, ok_) = _sub(square, product);
        negative_ = ok_ && disc_.negative;
        if (negative_) disc_.negative = false;
    }

    function _square(Signed2048 memory value_) internal pure returns (Signed2048 memory result_, bool ok_) {
        (result_.magnitude, ok_) = _mulMag(value_.magnitude, value_.magnitude);
    }

    function _floorSqrt2048(Types.Uint2048 memory value_) internal pure returns (Types.Uint2048 memory root_, bool ok_) {
        if (_isZeroMag(value_)) return (root_, true);
        uint256[8] memory value;
        uint256[8] memory remainder;
        uint256[8] memory root;
        uint256[8] memory shifted;
        uint256[8] memory product;
        for (uint256 i; i < 8; ++i) value[i] = value_.limb[i];
        ok_ = true;
        for (uint256 pair; pair < PAIR_COUNT; ++pair) {
            if (!_shlBits(remainder, PAIR_BITS) || !_addWordRaw(remainder, _digit32Raw(value, pair))) return (root_, false);
            uint256 digit = _largestDigitRaw(root, remainder, shifted, product);
            if (!_digitProductRaw(root, digit, shifted, product) || _cmp8(product, remainder) > 0) return (root_, false);
            _sub8(remainder, product);
            if (!_shlBits(root, 16) || !_addWordRaw(root, digit)) return (root_, false);
        }
        for (uint256 i; i < 8; ++i) root_.limb[i] = root[i];
    }

    function _largestDigitRaw(
        uint256[8] memory root_,
        uint256[8] memory remainder_,
        uint256[8] memory shifted_,
        uint256[8] memory product_
    ) private pure returns (uint256 best_) {
        uint256 guess = _estimateDigit(root_, remainder_);
        if (_fitsDigit(root_, guess, remainder_, shifted_, product_)) {
            best_ = guess;
            for (uint256 n; n < 4 && best_ < DIGIT_BASE - 1; ++n) {
                if (!_fitsDigit(root_, best_ + 1, remainder_, shifted_, product_)) return best_;
                ++best_;
            }
            return _searchDigit(root_, remainder_, shifted_, product_, best_, DIGIT_BASE - 1);
        }
        if (guess > 4) return _searchDigit(root_, remainder_, shifted_, product_, 0, guess);
        while (guess > 0 && !_fitsDigit(root_, guess, remainder_, shifted_, product_)) --guess;
        return guess;
    }

    function _searchDigit(
        uint256[8] memory root_,
        uint256[8] memory remainder_,
        uint256[8] memory shifted_,
        uint256[8] memory product_,
        uint256 low_,
        uint256 high_
    ) private pure returns (uint256 best_) {
        uint256 low = low_;
        uint256 high = high_;
        while (low <= high) {
            uint256 mid = low + (high - low) / 2;
            if (!_fitsDigit(root_, mid, remainder_, shifted_, product_)) {
                if (mid == 0) break;
                high = mid - 1;
            } else {
                best_ = mid;
                if (mid == high) break;
                low = mid + 1;
            }
        }
    }

    function _estimateDigit(uint256[8] memory root_, uint256[8] memory remainder_) private pure returns (uint256) {
        uint256 rootAt = _topIndex(root_);
        if (rootAt == 0 && root_[0] == 0) {
            uint256 low = remainder_[0];
            if (remainder_[1] != 0) return DIGIT_BASE - 1;
            uint256 z = _smallSqrt(low);
            return z >= DIGIT_BASE ? DIGIT_BASE - 1 : z;
        }
        uint256 remAt = _topIndex(remainder_);
        uint256 rootTop = root_[rootAt];
        if (rootTop == 0) return 0;
        if (remAt > rootAt) return DIGIT_BASE - 1;
        if (remAt + 1 < rootAt) return 0;
        uint256 guess = remainder_[remAt] / rootTop;
        guess >>= 17;
        return guess >= DIGIT_BASE ? DIGIT_BASE - 1 : guess;
    }

    function _topIndex(uint256[8] memory value_) private pure returns (uint256) {
        for (uint256 i = 8; i > 0; --i) if (value_[i - 1] != 0) return i - 1;
        return 0;
    }

    function _smallSqrt(uint256 value_) private pure returns (uint256 z_) {
        if (value_ == 0) return 0;
        z_ = value_;
        uint256 y = (z_ + 1) / 2;
        while (y < z_) {
            z_ = y;
            y = (value_ / y + y) / 2;
        }
    }

    function _fitsDigit(
        uint256[8] memory root_,
        uint256 digit_,
        uint256[8] memory remainder_,
        uint256[8] memory shifted_,
        uint256[8] memory product_
    ) private pure returns (bool) {
        return _digitProductRaw(root_, digit_, shifted_, product_) && _cmp8(product_, remainder_) <= 0;
    }

    function _digitProductRaw(
        uint256[8] memory root_,
        uint256 digit_,
        uint256[8] memory shifted_,
        uint256[8] memory product_
    ) private pure returns (bool) {
        for (uint256 i; i < 8; ++i) product_[i] = 0;
        if (digit_ == 0) return true;
        for (uint256 i; i < 8; ++i) shifted_[i] = root_[i];
        if (!_shlBits(shifted_, 17) || !_addWordRaw(shifted_, digit_)) return false;
        return _mulRawUintInto(shifted_, digit_, product_);
    }

    function _shlBits(uint256[8] memory value_, uint256 bits_) private pure returns (bool) {
        if (bits_ == 0) return true;
        if (bits_ >= 2048) {
            bool zero = true;
            for (uint256 i; i < 8; ++i) if (value_[i] != 0) zero = false;
            for (uint256 i; i < 8; ++i) value_[i] = 0;
            return zero;
        }
        uint256 limbShift = bits_ / 256;
        uint256 bitShift = bits_ % 256;
        for (uint256 i = 8; i > 0; --i) {
            uint256 idx = i - 1;
            if (value_[idx] == 0) continue;
            if (idx + limbShift >= 8) return false;
            if (bitShift != 0 && value_[idx] >> (256 - bitShift) != 0 && idx + limbShift + 1 >= 8) return false;
        }
        if (bitShift == 0) {
            for (uint256 i = 8; i > limbShift; --i) value_[i - 1] = value_[i - 1 - limbShift];
            for (uint256 i; i < limbShift; ++i) value_[i] = 0;
            return true;
        }
        for (uint256 i = 8; i > 0; --i) {
            uint256 idx = i - 1;
            uint256 src = idx >= limbShift ? value_[idx - limbShift] : 0;
            uint256 lower = idx > limbShift ? value_[idx - limbShift - 1] : 0;
            value_[idx] = (src << bitShift) | (lower >> (256 - bitShift));
        }
        return true;
    }

    function _addWordRaw(uint256[8] memory result_, uint256 value_) private pure returns (bool) {
        uint256 index;
        while (value_ != 0) {
            if (index >= 8) return false;
            uint256 old = result_[index];
            unchecked { result_[index] = old + value_; }
            value_ = result_[index] < old ? 1 : 0;
            ++index;
        }
        return true;
    }

    function _digit32Raw(uint256[8] memory value_, uint256 pair_) private pure returns (uint256) {
        uint256 bit = 2048 - (pair_ + 1) * PAIR_BITS;
        return (value_[bit / 256] >> (bit % 256)) & 0xffffffff;
    }

    function _cmp8(uint256[8] memory left_, uint256[8] memory right_) private pure returns (int256) {
        for (uint256 i = 8; i > 0; --i) {
            uint256 left = left_[i - 1];
            uint256 right = right_[i - 1];
            if (left < right) return -1;
            if (left > right) return 1;
        }
        return 0;
    }

    function _mulRawUintInto(uint256[8] memory value_, uint256 factor_, uint256[8] memory result_) private pure returns (bool) {
        for (uint256 i; i < 8; ++i) {
            if (value_[i] == 0) continue;
            (uint256 high, uint256 low) = Math.mul512(value_[i], factor_);
            if (!_addWordAt(result_, i, low)) return false;
            if (high != 0 && !_addWordAt(result_, i + 1, high)) return false;
        }
        return true;
    }

    function _addWordAt(uint256[8] memory result_, uint256 index_, uint256 value_) private pure returns (bool) {
        while (value_ != 0) {
            if (index_ >= 8) return false;
            uint256 old = result_[index_];
            unchecked { result_[index_] = old + value_; }
            value_ = result_[index_] < old ? 1 : 0;
            ++index_;
        }
        return true;
    }

    function _digit32(Types.Uint2048 memory value_, uint256 pair_) private pure returns (uint256) {
        uint256 bit = 2048 - (pair_ + 1) * PAIR_BITS;
        return (value_.limb[bit / 256] >> (bit % 256)) & 0xffffffff;
    }

    function _floorDiv(Signed2048 memory numerator_, Signed2048 memory denominator_)
        private pure returns (Signed2048 memory quotient_, bool ok_)
    {
        if (_isZero(denominator_)) return (quotient_, false);
        (Types.Uint2048 memory magnitude, Types.Uint2048 memory remainder, bool divOk) =
            _divMag(numerator_.magnitude, denominator_.magnitude);
        if (!divOk) return (quotient_, false);
        bool negative = numerator_.negative != denominator_.negative && !_isZeroMag(numerator_.magnitude);
        quotient_.magnitude = magnitude;
        quotient_.negative = negative && !_isZeroMag(magnitude);
        if (negative && !_isZeroMag(remainder)) {
            (quotient_, ok_) = _sub(quotient_, _from(1));
            return (quotient_, ok_);
        }
        ok_ = true;
    }

    function _divMag(Types.Uint2048 memory numerator_, Types.Uint2048 memory denominator_)
        private pure returns (Types.Uint2048 memory quotient_, Types.Uint2048 memory remainder_, bool ok_)
    {
        if (_isZeroMag(denominator_)) return (quotient_, remainder_, false);
        uint256[8] memory num;
        uint256[8] memory den;
        uint256[8] memory rem;
        uint256[8] memory quot;
        for (uint256 i; i < 8; ++i) {
            num[i] = numerator_.limb[i];
            den[i] = denominator_.limb[i];
        }
        uint256 top = 2048;
        while (top > 0 && !_bitRaw(num, top - 1)) --top;
        ok_ = true;
        if (top != 0) {
            uint256 chunks = (top + 31) / 32;
            uint256 firstWidth = ((top - 1) % 32) + 1;
            uint256[8] memory scratch;
            for (uint256 step; step < chunks; ++step) {
                uint256 width = step == 0 ? firstWidth : 32;
                uint256 start = step == 0 ? top - width : top - firstWidth - step * 32;
                if (!_shlBits(rem, width) || !_shlBits(quot, width)) return (quotient_, remainder_, false);
                if (!_addWordRaw(rem, _extract(num, start, width))) return (quotient_, remainder_, false);
                uint256 digit = _quotDigit(rem, den, scratch, width);
                if (digit != 0) {
                    for (uint256 i; i < 8; ++i) scratch[i] = 0;
                    if (!_mulRawUintInto(den, digit, scratch)) return (quotient_, remainder_, false);
                    _sub8(rem, scratch);
                    if (!_addWordRaw(quot, digit)) return (quotient_, remainder_, false);
                }
            }
        }
        for (uint256 i; i < 8; ++i) {
            quotient_.limb[i] = quot[i];
            remainder_.limb[i] = rem[i];
        }
    }

    function _extract(uint256[8] memory value_, uint256 start_, uint256 width_) private pure returns (uint256 chunk_) {
        if (width_ == 0) return 0;
        uint256 limb = start_ / 256;
        uint256 offset = start_ % 256;
        chunk_ = value_[limb] >> offset;
        if (offset + width_ > 256 && limb + 1 < 8) chunk_ |= value_[limb + 1] << (256 - offset);
        if (width_ < 256) chunk_ &= (uint256(1) << width_) - 1;
    }

    function _quotDigit(uint256[8] memory rem_, uint256[8] memory den_, uint256[8] memory scratch_, uint256 width_)
        private pure returns (uint256 best_)
    {
        uint256 cap = width_ == 32 ? 0xffffffff : (uint256(1) << width_) - 1;
        if (!_ge8(rem_, den_)) return 0;
        uint256 guess = _divGuess(rem_, den_, cap);
        for (uint256 n; n < 6; ++n) {
            for (uint256 i; i < 8; ++i) scratch_[i] = 0;
            bool fits = _mulRawUintInto(den_, guess, scratch_) && _cmp8(scratch_, rem_) <= 0;
            if (fits) {
                if (guess == cap) return guess;
                for (uint256 i; i < 8; ++i) scratch_[i] = 0;
                if (!_mulRawUintInto(den_, guess + 1, scratch_) || _cmp8(scratch_, rem_) > 0) return guess;
                ++guess;
            } else if (guess == 0) return 0;
            else --guess;
        }
        uint256 low = guess;
        uint256 high = cap;
        while (low <= high) {
            uint256 mid = low + (high - low) / 2;
            for (uint256 i; i < 8; ++i) scratch_[i] = 0;
            if (!_mulRawUintInto(den_, mid, scratch_) || _cmp8(scratch_, rem_) > 0) {
                if (mid == 0) break;
                high = mid - 1;
            } else {
                best_ = mid;
                if (mid == high) break;
                low = mid + 1;
            }
        }
    }

    function _divGuess(uint256[8] memory rem_, uint256[8] memory den_, uint256 cap_) private pure returns (uint256) {
        uint256 denAt = _topIndex(den_);
        uint256 remAt = _topIndex(rem_);
        uint256 denTop = den_[denAt];
        if (denTop == 0 || remAt < denAt) return 0;
        uint256 guess = remAt == denAt ? rem_[remAt] / denTop : cap_;
        return guess > cap_ ? cap_ : guess;
    }

    function _bitRaw(uint256[8] memory value_, uint256 index_) private pure returns (bool) {
        return (value_[index_ / 256] >> (index_ % 256)) & 1 == 1;
    }

    function _shl1(uint256[8] memory value_) private pure returns (bool) {
        uint256 carry;
        for (uint256 i; i < 8; ++i) {
            uint256 next = value_[i] >> 255;
            unchecked { value_[i] = (value_[i] << 1) | carry; }
            carry = next;
        }
        return carry == 0;
    }

    function _add1(uint256[8] memory value_) private pure {
        uint256 carry = 1;
        for (uint256 i; i < 8 && carry != 0; ++i) {
            unchecked { value_[i] += carry; }
            carry = value_[i] == 0 ? 1 : 0;
        }
    }

    function _ge8(uint256[8] memory left_, uint256[8] memory right_) private pure returns (bool) {
        for (uint256 i = 8; i > 0; --i) {
            uint256 left = left_[i - 1];
            uint256 right = right_[i - 1];
            if (left < right) return false;
            if (left > right) return true;
        }
        return true;
    }

    function _sub8(uint256[8] memory left_, uint256[8] memory right_) private pure {
        uint256 borrow;
        for (uint256 i; i < 8; ++i) {
            uint256 left = left_[i];
            unchecked {
                uint256 difference = left - right_[i];
                left_[i] = difference - borrow;
                borrow = (left < right_[i] || difference < borrow) ? 1 : 0;
            }
        }
    }

    function _bit(Types.Uint2048 memory value_, uint256 index_) private pure returns (bool) {
        return (value_.limb[index_ / 256] >> (index_ % 256)) & 1 == 1;
    }

    function _setBit(Types.Uint2048 memory value_, uint256 index_) private pure returns (bool) {
        uint256 limb = index_ / 256;
        if (limb >= 8) return false;
        value_.limb[limb] |= uint256(1) << (index_ % 256);
        return true;
    }

    function _from(uint256 value_) private pure returns (Signed2048 memory result_) {
        result_.magnitude.limb[0] = value_;
    }

    function _isZero(Signed2048 memory value_) private pure returns (bool) {
        return _isZeroMag(value_.magnitude);
    }

    function _isZeroMag(Types.Uint2048 memory value_) private pure returns (bool zero_) {
        zero_ = true;
        for (uint256 i; i < 8; ++i) if (value_.limb[i] != 0) return false;
    }

    function _cmpMag(Types.Uint2048 memory left_, Types.Uint2048 memory right_) private pure returns (int256) {
        for (uint256 i = 8; i > 0; --i) {
            uint256 left = left_.limb[i - 1];
            uint256 right = right_.limb[i - 1];
            if (left < right) return -1;
            if (left > right) return 1;
        }
        return 0;
    }

    function _fitsUint(Types.Uint2048 memory value_) private pure returns (bool) {
        for (uint256 i = 1; i < 8; ++i) if (value_.limb[i] != 0) return false;
        return true;
    }

    function _copySigned(Signed2048 memory value_) private pure returns (Signed2048 memory result_) {
        result_.negative = value_.negative;
        for (uint256 i; i < 8; ++i) result_.magnitude.limb[i] = value_.magnitude.limb[i];
    }

    function _neg(Signed2048 memory value_) private pure returns (Signed2048 memory result_, bool ok_) {
        result_ = _copySigned(value_);
        result_.negative = !_isZero(value_) && !value_.negative;
        ok_ = true;
    }

    function _add(Signed2048 memory left_, Signed2048 memory right_)
        private pure returns (Signed2048 memory result_, bool ok_)
    {
        if (left_.negative == right_.negative) {
            (result_.magnitude, ok_) = _addMag(left_.magnitude, right_.magnitude);
            result_.negative = ok_ && left_.negative && !_isZeroMag(result_.magnitude);
            return (result_, ok_);
        }
        int256 comparison = _cmpMag(left_.magnitude, right_.magnitude);
        if (comparison == 0) return (result_, true);
        if (comparison > 0) {
            (result_.magnitude, ok_) = _subMag(left_.magnitude, right_.magnitude);
            result_.negative = left_.negative;
        } else {
            (result_.magnitude, ok_) = _subMag(right_.magnitude, left_.magnitude);
            result_.negative = right_.negative;
        }
    }

    function _sub(Signed2048 memory left_, Signed2048 memory right_)
        private pure returns (Signed2048 memory result_, bool ok_)
    {
        (Signed2048 memory negated, bool negOk) = _neg(right_);
        if (!negOk) return (result_, false);
        return _add(left_, negated);
    }

    function _mul(Signed2048 memory left_, Signed2048 memory right_)
        private pure returns (Signed2048 memory result_, bool ok_)
    {
        (result_.magnitude, ok_) = _mulMag(left_.magnitude, right_.magnitude);
        result_.negative = ok_ && left_.negative != right_.negative && !_isZeroMag(result_.magnitude);
    }

    function _mulUint(Signed2048 memory value_, uint256 factor_)
        private pure returns (Signed2048 memory result_, bool ok_)
    {
        (result_.magnitude, ok_) = _mulMagUint(value_.magnitude, factor_);
        result_.negative = ok_ && value_.negative && factor_ != 0 && !_isZeroMag(result_.magnitude);
    }

    function _addMag(Types.Uint2048 memory left_, Types.Uint2048 memory right_)
        private pure returns (Types.Uint2048 memory result_, bool ok_)
    {
        uint256 carry;
        for (uint256 i; i < 8; ++i) {
            unchecked {
                uint256 sum = left_.limb[i] + right_.limb[i];
                uint256 first = sum < left_.limb[i] ? 1 : 0;
                uint256 withCarry = sum + carry;
                result_.limb[i] = withCarry;
                carry = first + (withCarry < sum ? 1 : 0);
            }
        }
        ok_ = carry == 0;
    }

    function _subMag(Types.Uint2048 memory left_, Types.Uint2048 memory right_)
        private pure returns (Types.Uint2048 memory result_, bool ok_)
    {
        uint256 borrow;
        for (uint256 i; i < 8; ++i) {
            uint256 left = left_.limb[i];
            uint256 right = right_.limb[i];
            unchecked {
                uint256 difference = left - right;
                result_.limb[i] = difference - borrow;
                borrow = (left < right || difference < borrow) ? 1 : 0;
            }
        }
        ok_ = borrow == 0;
    }

    function _mulMag(Types.Uint2048 memory left_, Types.Uint2048 memory right_)
        private pure returns (Types.Uint2048 memory result_, bool ok_)
    {
        ok_ = true;
        for (uint256 i; i < 8; ++i) {
            if (left_.limb[i] == 0) continue;
            for (uint256 j; j < 8; ++j) {
                if (right_.limb[j] == 0) continue;
                if (i + j >= 8) return (result_, false);
                (uint256 high, uint256 low) = Math.mul512(left_.limb[i], right_.limb[j]);
                if (!_addWord(result_, i + j, low)) return (result_, false);
                if (high != 0 && !_addWord(result_, i + j + 1, high)) return (result_, false);
            }
        }
    }

    function _mulMagUint(Types.Uint2048 memory value_, uint256 factor_)
        private pure returns (Types.Uint2048 memory result_, bool ok_)
    {
        if (factor_ == 0 || _isZeroMag(value_)) return (result_, true);
        Types.Uint2048 memory factor;
        factor.limb[0] = factor_;
        return _mulMag(value_, factor);
    }

    function _shlMag(Types.Uint2048 memory value_, uint256 bits_)
        private pure returns (Types.Uint2048 memory result_, bool ok_)
    {
        if (bits_ == 0) return (value_, true);
        if (bits_ >= 2048) return (result_, _isZeroMag(value_));
        uint256 limbShift = bits_ / 256;
        uint256 bitShift = bits_ % 256;
        ok_ = true;
        for (uint256 i; i < 8; ++i) {
            if (value_.limb[i] == 0) continue;
            uint256 dest = i + limbShift;
            if (dest >= 8) return (result_, false);
            if (bitShift == 0) {
                result_.limb[dest] |= value_.limb[i];
                continue;
            }
            result_.limb[dest] |= value_.limb[i] << bitShift;
            uint256 high = value_.limb[i] >> (256 - bitShift);
            if (high == 0) continue;
            if (dest + 1 >= 8) return (result_, false);
            result_.limb[dest + 1] |= high;
        }
    }

    function _addWord(Types.Uint2048 memory result_, uint256 index_, uint256 value_) private pure returns (bool) {
        while (value_ != 0) {
            if (index_ >= 8) return false;
            uint256 old = result_.limb[index_];
            unchecked { result_.limb[index_] = old + value_; }
            value_ = result_.limb[index_] < old ? 1 : 0;
            ++index_;
        }
        return true;
    }

    function _fail(Failure failure_) private pure returns (Candidate memory candidate_) {
        candidate_.failure = failure_;
    }

    function _bad(Coefficients memory built_) private pure returns (Coefficients memory) {
        built_.ok = false;
        return built_;
    }
}
// end::UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath[]
