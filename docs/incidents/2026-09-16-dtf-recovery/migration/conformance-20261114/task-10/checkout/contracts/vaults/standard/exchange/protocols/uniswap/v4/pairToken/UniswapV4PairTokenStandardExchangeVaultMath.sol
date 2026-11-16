// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FixedPointMathLib} from "@crane/contracts/external/solady/utils/FixedPointMathLib.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultMath[]
/// @notice Pure arithmetic for the stage-one, single-supply PairToken exchange.
/// @dev Prices are Q64.96; assets and shares are raw units. No shared family
/// storage/types, fee checkpoint policy, or manager capacity state lives here.
library UniswapV4PairTokenStandardExchangeVaultMath {
    // tag::DirectCallNotAllowed-3921c703[]
    /// @custom:signature DirectCallNotAllowed()
    /// @custom:selector 0x3921c703
    error DirectCallNotAllowed();
    // end::DirectCallNotAllowed-3921c703[]
    // tag::InvalidPrice-00bfc921[]
    /// @custom:signature InvalidPrice()
    /// @custom:selector 0x00bfc921
    error InvalidPrice();
    // end::InvalidPrice-00bfc921[]
    // tag::InvalidAccountingState-997ede0a[]
    /// @custom:signature InvalidAccountingState()
    /// @custom:selector 0x997ede0a
    error InvalidAccountingState();
    // end::InvalidAccountingState-997ede0a[]
    // tag::ZeroShares-9811e0c7[]
    /// @custom:signature ZeroShares()
    /// @custom:selector 0x9811e0c7
    error ZeroShares();
    // end::ZeroShares-9811e0c7[]
    // tag::InvalidAllocation-0baf7432[]
    /// @custom:signature InvalidAllocation()
    /// @custom:selector 0x0baf7432
    error InvalidAllocation();
    // end::InvalidAllocation-0baf7432[]
    // tag::LiquidityOverflow-b03425ae[]
    /// @custom:signature LiquidityOverflow()
    /// @custom:selector 0xb03425ae
    error LiquidityOverflow();
    // end::LiquidityOverflow-b03425ae[]
    // tag::ArithmeticOverflow-e47ec074[]
    /// @custom:signature ArithmeticOverflow()
    /// @custom:selector 0xe47ec074
    error ArithmeticOverflow();
    // end::ArithmeticOverflow-e47ec074[]

    uint256 internal constant Q96 = 1 << 96;
    uint256 internal constant DUST = 1000;

    /// @dev Little-endian base-2^256 limbs; private arithmetic never truncates
    /// a high quotient before the caller's declared result-domain check.
    struct Wide {
        uint256 lo;
        uint256 hi;
    }

    struct CompoundInventory {
        uint256 leftover0;
        uint256 leftover1;
    }

    // tag::principal-6dae28b5[]
    /// @notice Removable principal, with canonical round-down and endpoint clamping.
    /// @custom:signature principal(uint160,uint160,uint160,uint128)
    /// @custom:selector 0x6dae28b5
    function principal(uint160 price_, uint160 lower_, uint160 upper_, uint128 liquidity_)
        public view
        returns (uint256 amount0, uint256 amount1)
    {
        _requireDelegateCall();
        return _amounts(price_, lower_, upper_, liquidity_, false);
    }
    // end::principal-6dae28b5[]

    // tag::costs-f1db97db[]
    /// @notice Required addition costs, with canonical round-up and endpoint clamping.
    /// @custom:signature costs(uint160,uint160,uint160,uint128)
    /// @custom:selector 0xf1db97db
    function costs(uint160 price_, uint160 lower_, uint160 upper_, uint128 liquidity_)
        public view
        returns (uint256 amount0, uint256 amount1)
    {
        _requireDelegateCall();
        return _amounts(price_, lower_, upper_, liquidity_, true);
    }
    // end::costs-f1db97db[]

    // tag::liquidityForAmounts-c12baa75[]
    /// @notice Canonical conservative affordable liquidity, without capacity clamping.
    /// @dev Retains LiquidityAmounts' floor(lower*upper/Q96) in the token0
    /// formula. Unlike its eager per-leg uint128 casts, only the limiting
    /// quotient is narrowed. The planner must separately check signed addition,
    /// position, active liquidity, tick gross/net, and principal-delta capacities.
    /// @custom:signature liquidityForAmounts(uint160,uint160,uint160,uint256,uint256)
    /// @custom:selector 0xc12baa75
    function liquidityForAmounts(
        uint160 price_,
        uint160 lower_,
        uint160 upper_,
        uint256 amount0_,
        uint256 amount1_
    ) public view returns (uint128 liquidity) {
        _requireDelegateCall();
        bool fits;
        (fits, liquidity) = tryLiquidityForAmounts(price_, lower_, upper_, amount0_, amount1_);
        if (!fits) revert LiquidityOverflow();
    }
    // end::liquidityForAmounts-c12baa75[]

    // tag::tryLiquidityForAmounts-f4ab04d0[]
    /// @notice Inspect liquidity representability without reverting on a capacity failure.
    /// @dev False means the exact limiting quotient exceeds uint128, never a clamp.
    /// Ordered positive bounds remain a configuration precondition. Other manager
    /// capacities require pool state and are checked by the planner separately.
    /// @custom:signature tryLiquidityForAmounts(uint160,uint160,uint160,uint256,uint256)
    /// @custom:selector 0xf4ab04d0
    function tryLiquidityForAmounts(
        uint160 price_,
        uint160 lower_,
        uint160 upper_,
        uint256 amount0_,
        uint256 amount1_
    ) public view returns (bool fits, uint128 liquidity) {
        _requireDelegateCall();
        _bounds(lower_, upper_);
        Wide memory result;
        if (price_ <= lower_) {
            result = _liquidity0(lower_, upper_, amount0_);
        } else if (price_ >= upper_) {
            result = _mulDivWide(amount1_, Q96, upper_ - lower_);
        } else {
            Wide memory from0 = _liquidity0(price_, upper_, amount0_);
            Wide memory from1 = _mulDivWide(amount1_, Q96, price_ - lower_);
            result = _less(from0, from1) ? from0 : from1;
        }
        if (result.hi != 0 || result.lo > type(uint128).max) return (false, 0);
        return (true, uint128(result.lo));
    }
    // end::tryLiquidityForAmounts-f4ab04d0[]

    // tag::pairedQuote-d1bd57b3[]
    /// @notice Candidate paired shares and accepted input, before actual growth credit.
    /// @dev Genesis product is deliberately checked. A positive-supply one-sided
    /// book accepts the full live-leg maximum, not a recomputed ceiling amount.
    /// Final supply capacity is checked by the caller after the actual credit cap.
    /// @custom:signature pairedQuote(uint256,uint256,uint256,uint256,uint256)
    /// @custom:selector 0xd1bd57b3
    function pairedQuote(uint256 supply_, uint256 reserve0_, uint256 reserve1_, uint256 max0_, uint256 max1_)
        public view
        returns (uint256 shares, uint256 used0, uint256 used1)
    {
        _requireDelegateCall();
        if (supply_ == 0) {
            shares = FixedPointMathLib.sqrt(max0_ * max1_);
            used0 = max0_;
            used1 = max1_;
        } else {
            shares = _uncappedCredit(supply_, reserve0_, reserve1_, max0_, max1_);
            if (reserve0_ == 0) {
                used1 = max1_;
            } else if (reserve1_ == 0) {
                used0 = max0_;
            } else {
                used0 = FullMath.mulDivRoundingUp(shares, reserve0_, supply_);
                used1 = FullMath.mulDivRoundingUp(shares, reserve1_, supply_);
            }
        }
        if (shares == 0) revert ZeroShares();
    }
    // end::pairedQuote-d1bd57b3[]

    // tag::credit-0be88eff[]
    /// @notice Paired credit: min(cap, each positive-reserve contribution ratio).
    /// @dev Check cap inequalities before dividing. Even two overflowing ratio
    /// quotients are valid when the final capped result is representable.
    /// Every cap, including uint256.max, is a real cap; use zapCredit for no cap.
    /// @custom:signature credit(uint256,uint256,uint256,uint256,uint256,uint256)
    /// @custom:selector 0x0be88eff
    function credit(uint256 supply_, uint256 r0_, uint256 r1_, uint256 c0_, uint256 c1_, uint256 cap_)
        public view
        returns (uint256 shares)
    {
        _requireDelegateCall();
        if (supply_ == 0 || (r0_ == 0 && r1_ == 0)) revert InvalidAccountingState();
        if (
            (r0_ == 0 || !_less(_product(supply_, c0_), _product(cap_, r0_)))
                && (r1_ == 0 || !_less(_product(supply_, c1_), _product(cap_, r1_)))
        ) {
            shares = cap_;
        } else {
            shares = _uncappedCredit(supply_, r0_, r1_, c0_, c1_);
        }
        if (shares == 0) revert ZeroShares();
    }
    // end::credit-0be88eff[]

    // tag::zapCredit-68b3eb2d[]
    /// @notice Uncapped zap credit; a non-limiting overflow is irrelevant.
    /// @dev A genuinely overflowing minimum reverts rather than saturating.
    /// @custom:signature zapCredit(uint256,uint256,uint256,uint256,uint256)
    /// @custom:selector 0x68b3eb2d
    function zapCredit(uint256 supply_, uint256 r0_, uint256 r1_, uint256 c0_, uint256 c1_)
        public view
        returns (uint256 shares)
    {
        _requireDelegateCall();
        shares = _uncappedCredit(supply_, r0_, r1_, c0_, c1_);
        if (shares == 0) revert ZeroShares();
    }
    // end::zapCredit-68b3eb2d[]

    // tag::allocation-09eb2862[]
    /// @notice Exact proportional liquidity and idle allocation, including final exit.
    /// @custom:signature allocation(uint256,uint256,uint128,uint256,uint256)
    /// @custom:selector 0x09eb2862
    function allocation(uint256 supply_, uint256 shares_, uint128 liquidity_, uint256 idle0_, uint256 idle1_)
        public view
        returns (uint128 removed, uint256 amount0, uint256 amount1)
    {
        _requireDelegateCall();
        if (shares_ == 0 || shares_ > supply_) revert InvalidAllocation();
        removed = uint128(FullMath.mulDiv(liquidity_, shares_, supply_));
        amount0 = FullMath.mulDiv(idle0_, shares_, supply_);
        amount1 = FullMath.mulDiv(idle1_, shares_, supply_);
    }
    // end::allocation-09eb2862[]

    // tag::compoundSwap-7d0bcdae[]
    /// @notice Baseline compound sale direction, half leftover and quarter reserve cap.
    /// @dev The token0 comparison deliberately floors after EACH Q96 conversion.
    /// Wide comparison prevents overflow of a non-limiting valuation. This is
    /// not the single-floor accountingRate conversion.
    /// @custom:signature compoundSwap(uint160,uint160,uint160,uint256,uint256,uint128,uint16)
    /// @custom:selector 0x7d0bcdae
    function compoundSwap(
        uint160 price_,
        uint160 lower_,
        uint160 upper_,
        uint256 idle0_,
        uint256 idle1_,
        uint128 activeLiquidity_,
        uint16 maxZapBps_
    ) public view returns (bool zeroForOne, uint256 amount) {
        _requireDelegateCall();
        bool fits;
        (fits, zeroForOne, amount) =
            tryCompoundSwap(price_, lower_, upper_, idle0_, idle1_, activeLiquidity_, maxZapBps_);
        if (!fits) revert LiquidityOverflow();
    }
    // end::compoundSwap-7d0bcdae[]

    // tag::tryCompoundSwap-81a5d1ff[]
    /// @notice Plan compound sizing without throwing on affordable-liquidity overflow.
    /// @dev False identifies only uint128 liquidity overflow, for typed planner
    /// classification. Valid configuration is assumed. The returned amount is
    /// <=idle/2<=int256.max; price interval and signed settlement limits require
    /// the projected manager state and are not hidden behind this result flag.
    /// @custom:signature tryCompoundSwap(uint160,uint160,uint160,uint256,uint256,uint128,uint16)
    /// @custom:selector 0x81a5d1ff
    function tryCompoundSwap(
        uint160 price_,
        uint160 lower_,
        uint160 upper_,
        uint256 idle0_,
        uint256 idle1_,
        uint128 activeLiquidity_,
        uint16 maxZapBps_
    ) public view returns (bool fits, bool zeroForOne, uint256 amount) {
        _requireDelegateCall();
        if (idle0_ <= DUST && idle1_ <= DUST) return (true, false, 0);
        CompoundInventory memory inventory;
        {
            uint128 fit;
            (fits, fit) = tryLiquidityForAmounts(price_, lower_, upper_, idle0_, idle1_);
            if (!fits) return (false, false, 0);
            (uint256 need0, uint256 need1) = costs(price_, lower_, upper_, fit);
            inventory.leftover0 = idle0_ - need0;
            inventory.leftover1 = idle1_ - need1;
        }
        {
            Wide memory first = _mulDivWide(inventory.leftover0, price_, Q96);
            zeroForOne = !_less(_shift96(_times(first, price_)), Wide(inventory.leftover1, 0));
        }
        uint256 leftover = zeroForOne ? inventory.leftover0 : inventory.leftover1;
        if (leftover <= DUST || activeLiquidity_ == 0) return (true, zeroForOne, 0);
        (uint256 reserve0, uint256 reserve1) = principal(price_, lower_, upper_, activeLiquidity_);
        uint256 cap = FullMath.mulDiv(zeroForOne ? reserve0 : reserve1, maxZapBps_, 10000) / 4;
        amount = leftover / 2;
        if (amount > cap) amount = cap;
    }
    // end::tryCompoundSwap-81a5d1ff[]

    // tag::accountingRate-1755f7e8[]
    /// @notice Raw rate-asset units per 1e18 raw shares; zero before bootstrap.
    /// @dev Currency conversion floors once, then rate scaling floors once.
    /// For price >= 1, token0 conversion is <2^448; token1 conversion <2^384.
    /// Adding the other uint256 leg gives <2^449; scaling by 1e18 (<2^60)
    /// stays below 2^509. Two limbs suffice AFTER conversion, including scaling.
    /// Only the final rate must fit uint256, not the converted basket value.
    /// @custom:signature accountingRate(uint160,uint256,uint256,uint256,bool)
    /// @custom:selector 0x1755f7e8
    function accountingRate(uint160 price_, uint256 a0_, uint256 a1_, uint256 supply_, bool token0_)
        public view
        returns (uint256)
    {
        _requireDelegateCall();
        if (supply_ == 0) return 0;
        if (price_ == 0) revert InvalidPrice();
        Wide memory value;
        if (token0_) {
            value = _divide(Wide(a1_ << 192, a1_ >> 64), _product(price_, price_));
            value = _add(value, a0_);
        } else {
            value = _add(_token1Value(price_, a0_), a1_);
        }
        return _narrow(_divide(_times(value, 1e18), Wide(supply_, 0)));
    }
    // end::accountingRate-1755f7e8[]

    /// @dev Reject direct calls without adding a self-referential library link.
    function _requireDelegateCall() private view {
        bytes32 executingHash_;
        assembly ("memory-safe") {
            let scratch_ := mload(0x40)
            codecopy(scratch_, 0, codesize())
            executingHash_ := keccak256(scratch_, codesize())
        }
        if (address(this).codehash == executingHash_) revert DirectCallNotAllowed();
    }

    function _amounts(uint160 price_, uint160 lower_, uint160 upper_, uint128 liquidity_, bool up_)
        private
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        _bounds(lower_, upper_);
        if (price_ <= lower_) {
            amount0 = SqrtPriceMath.getAmount0Delta(lower_, upper_, liquidity_, up_);
        } else if (price_ >= upper_) {
            amount1 = SqrtPriceMath.getAmount1Delta(lower_, upper_, liquidity_, up_);
        } else {
            amount0 = SqrtPriceMath.getAmount0Delta(price_, upper_, liquidity_, up_);
            amount1 = SqrtPriceMath.getAmount1Delta(lower_, price_, liquidity_, up_);
        }
    }

    function _bounds(uint160 lower_, uint160 upper_) private pure {
        if (lower_ == 0 || lower_ >= upper_) revert InvalidPrice();
    }

    function _liquidity0(uint160 lower_, uint160 upper_, uint256 amount_) private pure returns (Wide memory) {
        uint256 intermediate = FullMath.mulDiv(lower_, upper_, Q96);
        return _mulDivWide(amount_, intermediate, upper_ - lower_);
    }

    function _uncappedCredit(uint256 supply_, uint256 r0_, uint256 r1_, uint256 c0_, uint256 c1_)
        private
        pure
        returns (uint256)
    {
        if (supply_ == 0 || (r0_ == 0 && r1_ == 0)) revert InvalidAccountingState();
        // Compare c0/r0 with c1/r1 before division; the common supply cancels.
        bool use0 = r1_ == 0 || (r0_ != 0 && !_less(_product(c1_, r0_), _product(c0_, r1_)));
        return _narrow(_mulDivWide(supply_, use0 ? c0_ : c1_, use0 ? r0_ : r1_));
    }

    function _product(uint256 a_, uint256 b_) private pure returns (Wide memory product) {
        assembly ("memory-safe") {
            let low := mul(a_, b_)
            let residue := mulmod(a_, b_, not(0))
            mstore(product, low)
            mstore(add(product, 32), sub(sub(residue, low), lt(residue, low)))
        }
    }

    function _less(Wide memory a_, Wide memory b_) private pure returns (bool) {
        return a_.hi < b_.hi || (a_.hi == b_.hi && a_.lo < b_.lo);
    }

    function _add(Wide memory a_, uint256 b_) private pure returns (Wide memory result) {
        unchecked {
            result.lo = a_.lo + b_;
        }
        result.hi = a_.hi + (result.lo < a_.lo ? 1 : 0);
    }

    function _times(Wide memory a_, uint256 b_) private pure returns (Wide memory result) {
        Wide memory low = _product(a_.lo, b_);
        Wide memory high = _product(a_.hi, b_);
        // Used only where the mathematical product has the proven <=512-bit bound.
        if (high.hi != 0) revert ArithmeticOverflow();
        result = Wide(low.lo, low.hi + high.lo);
    }

    function _shift96(Wide memory a_) private pure returns (Wide memory) {
        return Wide((a_.lo >> 96) | (a_.hi << 160), a_.hi >> 96);
    }

    function _token1Value(uint160 price_, uint256 amount_) private pure returns (Wide memory result) {
        // price^2 * amount has at most 576 bits: retain all THREE product limbs.
        Wide memory square = _product(price_, price_);
        Wide memory low = _product(square.lo, amount_);
        Wide memory high = _product(square.hi, amount_);
        uint256 middle;
        unchecked {
            middle = low.hi + high.lo;
        }
        uint256 top = high.hi + (middle < low.hi ? 1 : 0);
        // top < 2^64, so its shift cannot discard a bit.
        result = Wide((low.lo >> 192) | (middle << 64), (middle >> 192) | (top << 64));
    }

    function _mulDivWide(uint256 a_, uint256 b_, uint256 denominator_) private pure returns (Wide memory) {
        Wide memory product = _product(a_, b_);
        if (product.hi < denominator_) return Wide(FullMath.mulDiv(a_, b_, denominator_), 0);
        return _divide(product, Wide(denominator_, 0));
    }

    /// @dev Restoring division, at most 512 numerator bits. All callers have a
    /// nonzero denominator <2^320. The invariant remainder < denominator means
    /// the shifted remainder is <2^321: no 512-bit shift overflow is possible.
    /// Subtraction uses an explicit low-word borrow; the comparison proves the
    /// complete subtraction nonnegative. Both quotient limbs are retained.
    function _divide(Wide memory numerator_, Wide memory denominator_) private pure returns (Wide memory quotient) {
        if (denominator_.hi == 0 && numerator_.hi == 0) {
            return Wide(numerator_.lo / denominator_.lo, 0);
        }
        if (_less(numerator_, denominator_)) return quotient;
        Wide memory remainder;
        for (uint256 bit = 512; bit != 0;) {
            unchecked {
                --bit;
                remainder.hi = (remainder.hi << 1) | (remainder.lo >> 255);
                uint256 incoming = bit >= 256 ? (numerator_.hi >> (bit - 256)) & 1 : (numerator_.lo >> bit) & 1;
                remainder.lo = (remainder.lo << 1) | incoming;
                if (!_less(remainder, denominator_)) {
                    uint256 borrow = remainder.lo < denominator_.lo ? 1 : 0;
                    remainder.lo -= denominator_.lo;
                    remainder.hi = remainder.hi - denominator_.hi - borrow;
                    if (bit >= 256) quotient.hi |= uint256(1) << (bit - 256);
                    else quotient.lo |= uint256(1) << bit;
                }
            }
        }
    }

    function _narrow(Wide memory value_) private pure returns (uint256) {
        if (value_.hi != 0) revert ArithmeticOverflow();
        return value_.lo;
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultMath[]
