// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath as Analytic} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";

/// @notice Coefficient expectations come from this file's expansion, not from `_candidate`.
contract UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMathTest is Test {
    uint256 internal constant Q96 = 1 << 96;
    uint256 internal constant FEE = 1_000_000;

    function test_floorDivisionSingleAndWide() public pure {
        Analytic.Candidate memory small = Analytic._solve(_signed(0, false), _signed(3, false), _signed(100, true), 100);
        assertEq(uint256(small.failure), uint256(Analytic.Failure.None));
        assertEq(small.swapIn, 33);
        Analytic.Signed2048 memory wideB;
        wideB.magnitude.limb[1] = uint256(1) << 44;
        Analytic.Signed2048 memory wideC;
        wideC.negative = true;
        wideC.magnitude.limb[1] = 5 * (uint256(1) << 44);
        Analytic.Candidate memory wide = Analytic._solve(_signed(0, false), wideB, wideC, 10);
        assertEq(uint256(wide.failure), uint256(Analytic.Failure.None), "wide div");
        assertEq(wide.swapIn, 5);
        Analytic.Candidate memory root = Analytic._solve(_signed(1000, false), _signed(105000, false), _signed(10_000_000, true), 100);
        assertEq(uint256(root.failure), uint256(Analytic.Failure.None), "unscaled");
        assertEq(root.swapIn, 60);
    }

    function test_floorSqrtKnownValues() public pure {
        assertEq(_sqrt(0), 0);
        assertEq(_sqrt(1), 1);
        assertEq(_sqrt(10), 3);
        assertEq(_sqrt(10_000), 100);
        Types.Uint2048 memory wide;
        wide.limb[1] = uint256(1) << 144;
        (Types.Uint2048 memory root, bool ok) = Analytic._floorSqrt2048(wide);
        assertTrue(ok);
        assertEq(root.limb[0], uint256(1) << 200);
        assertEq(root.limb[1], 0);
    }

    function test_bothDirectionsFloorTheSmallerInDomainRoot() public pure {
        Analytic.SegmentInput memory input = _base();
        Analytic.Candidate memory forward = Analytic._candidate(input);
        assertEq(uint256(forward.failure), uint256(Analytic.Failure.None), "forward failure");
        assertEq(forward.swapIn, 60);
        input.zeroForOne = false;
        Analytic.Candidate memory backward = Analytic._candidate(input);
        assertEq(uint256(backward.failure), uint256(Analytic.Failure.None), "backward failure");
        assertEq(backward.swapIn, 60);
    }

    function test_rhoEndpointsAndInterior() public pure {
        Analytic.SegmentInput memory none = _base();
        none.ownedLiquidity = 0;
        assertEq(uint256(Analytic._candidate(none).failure), uint256(Analytic.Failure.None));
        assertEq(Analytic._candidate(none).swapIn, 61);
        Analytic.SegmentInput memory full = _base();
        full.ownedLiquidity = full.poolLiquidity;
        assertEq(uint256(Analytic._candidate(full).failure), uint256(Analytic.Failure.None));
        assertEq(Analytic._candidate(full).swapIn, 59);
        assertEq(Analytic._candidate(_base()).swapIn, 60);
    }

    function test_zeroAndNonzeroProtocolFee() public pure {
        Analytic.SegmentInput memory zero = _base();
        zero.protocolFeePips = 0;
        assertEq(uint256(Analytic._candidate(zero).failure), uint256(Analytic.Failure.None));
        Analytic.SegmentInput memory nonzero = _base();
        nonzero.protocolFeePips = 1000;
        assertEq(uint256(Analytic._candidate(nonzero).failure), uint256(Analytic.Failure.None));
        assertEq(Analytic._candidate(nonzero).swapIn, 60);
    }

    function test_linearDegeneracyFloorsTheQuotient() public pure {
        Analytic.SegmentInput memory input = _base();
        input.poolLiquidity = 20_000;
        input.ownedLiquidity = 20_000;
        input.protocolFeePips = 100;
        input.lpFeePips = 0;
        input.incumbentIn = 1;
        input.incumbentOut = 2;
        input.callerInRemaining = 5;
        input.callerOutAccumulated = 0;
        Analytic.Candidate memory candidate = Analytic._candidate(input);
        assertEq(uint256(candidate.failure), uint256(Analytic.Failure.None));
        assertEq(candidate.swapIn, 1);
    }

    function test_outOfDomainRootIsNotClamped() public pure {
        Analytic.SegmentInput memory input = _base();
        input.poolLiquidity = 20_000;
        input.ownedLiquidity = 20_000;
        input.protocolFeePips = 100;
        input.lpFeePips = 0;
        input.incumbentIn = 100;
        input.incumbentOut = 2;
        input.callerInRemaining = 4;
        input.callerOutAccumulated = 0;
        assertEq(uint256(Analytic._candidate(input).failure), uint256(Analytic.Failure.OutOfDomain));
        assertEq(Analytic._candidate(input).swapIn, 0);
    }

    function test_negativeDiscriminantReturnsFailure() public pure {
        Analytic.Signed2048 memory a = _signed(1, false);
        Analytic.Signed2048 memory b = _signed(0, false);
        Analytic.Signed2048 memory c = _signed(1, false);
        Analytic.Candidate memory candidate = Analytic._solve(a, b, c, 10);
        assertEq(uint256(candidate.failure), uint256(Analytic.Failure.NegativeDiscriminant));
        assertEq(candidate.swapIn, 0);
    }

    function test_limbOverflowIsUnrepresentable() public pure {
        Analytic.Signed2048 memory wide;
        wide.magnitude.limb[4] = 1;
        (, bool ok) = Analytic._square(wide);
        assertFalse(ok);
        Analytic.Candidate memory candidate = Analytic._solve(_signed(1, false), wide, _signed(1, false), type(uint256).max);
        assertEq(uint256(candidate.failure), uint256(Analytic.Failure.Unrepresentable));
    }

    function test_zeroLiquidityAndDegenerateFee() public pure {
        Analytic.SegmentInput memory input = _base();
        input.poolLiquidity = 0;
        assertEq(uint256(Analytic._candidate(input).failure), uint256(Analytic.Failure.ZeroLiquidity));
        input = _base();
        input.lpFeePips = 1_000_000;
        assertEq(uint256(Analytic._candidate(input).failure), uint256(Analytic.Failure.Degenerate));
    }

    function _base() private pure returns (Analytic.SegmentInput memory input_) {
        input_.sqrtPriceX96 = uint160(Q96);
        input_.poolLiquidity = 100;
        input_.ownedLiquidity = 50;
        input_.lpFeePips = 0;
        input_.protocolFeePips = 0;
        input_.incumbentIn = 1000;
        input_.incumbentOut = 1000;
        input_.callerInRemaining = 100;
        input_.callerOutAccumulated = 0;
        input_.zeroForOne = true;
    }

    /// @dev P/Q/alpha/beta/gamma expansion at unit sqrt price, cleared by fee^2 * liquidity.
    ///      This is not the library's Q96 clearing order.
    function _independentFloor(Analytic.SegmentInput memory input_) private pure returns (uint256) {
        require(input_.sqrtPriceX96 == uint160(Q96), "unit price fixture");
        uint256 swapFee = uint256(input_.protocolFeePips) + input_.lpFeePips
            - (uint256(input_.protocolFeePips) * input_.lpFeePips) / FEE;
        int256 den = int256(FEE);
        int256 g = den - int256(swapFee);
        int256 pool = int256(uint256(input_.poolLiquidity));
        int256 owned = int256(uint256(input_.ownedLiquidity));
        int256 oneMinusPhi = den - int256(uint256(input_.protocolFeePips));
        int256 capitalA = _independentA(input_, g, den, pool, owned, oneMinusPhi);
        int256 capitalB = _independentB(input_, g, den, pool, owned, oneMinusPhi);
        int256 capitalC = _independentC(input_, den, pool);
        return _selectFloor(capitalA, capitalB, capitalC, input_.callerInRemaining);
    }

    function _independentA(
        Analytic.SegmentInput memory input_, int256 g_, int256 den_, int256 pool_, int256 owned_, int256 oneMinusPhi_
    ) private pure returns (int256) {
        int256 b = int256(input_.incumbentOut);
        int256 e = int256(input_.callerOutAccumulated);
        return g_ * (b - owned_) * den_ * pool_ + owned_ * oneMinusPhi_ * g_ * pool_ + e * owned_ * oneMinusPhi_ * g_;
    }

    function _independentB(
        Analytic.SegmentInput memory input_, int256 g_, int256 den_, int256 pool_, int256 owned_, int256 oneMinusPhi_
    ) private pure returns (int256) {
        int256 a = int256(input_.incumbentIn);
        int256 b = int256(input_.incumbentOut);
        int256 d = int256(input_.callerInRemaining);
        int256 e = int256(input_.callerOutAccumulated);
        int256 first = a * g_ * pool_ * den_ * pool_;
        int256 second = d * g_ * (b - owned_) * den_ * pool_;
        int256 third = b * pool_ * den_ * den_ * pool_;
        int256 fourth = e * a * g_ * den_ * pool_;
        int256 fifth = e * owned_ * oneMinusPhi_ * den_ * pool_;
        return first - second + third + fourth + fifth;
    }

    function _independentC(Analytic.SegmentInput memory input_, int256 den_, int256 pool_) private pure returns (int256) {
        int256 net = int256(input_.callerOutAccumulated) * int256(input_.incumbentIn)
            - int256(input_.callerInRemaining) * int256(input_.incumbentOut);
        return net * pool_ * den_ * den_ * pool_;
    }

    function _selectFloor(int256 capitalA_, int256 capitalB_, int256 capitalC_, uint256 limit_)
        private pure returns (uint256)
    {
        if (capitalA_ == 0 && capitalB_ == 0) return 0;
        if (capitalA_ == 0) {
            if (capitalB_ == 0 || (capitalC_ > 0) == (capitalB_ > 0)) return 0;
            return uint256((-capitalC_) / capitalB_);
        }
        int256 disc = capitalB_ * capitalB_ - 4 * capitalA_ * capitalC_;
        require(disc >= 0, "independent disc");
        int256 sqrtDisc = int256(_isqrt(uint256(disc)));
        int256 first = (-capitalB_ + sqrtDisc) / (2 * capitalA_);
        int256 second = (-capitalB_ - sqrtDisc) / (2 * capitalA_);
        uint256 selected;
        bool found;
        if (first > 0 && uint256(first) <= limit_) {
            selected = uint256(first);
            found = true;
        }
        if (second > 0 && uint256(second) <= limit_ && (!found || uint256(second) < selected)) {
            selected = uint256(second);
        }
        return selected;
    }

    function _signed(uint256 value_, bool negative_) private pure returns (Analytic.Signed2048 memory result_) {
        result_.negative = negative_ && value_ != 0;
        result_.magnitude.limb[0] = value_;
    }

    function _sqrt(uint256 value_) private pure returns (uint256) {
        Types.Uint2048 memory wide;
        wide.limb[0] = value_;
        (Types.Uint2048 memory root, bool ok) = Analytic._floorSqrt2048(wide);
        require(ok && root.limb[1] == 0, "sqrt");
        return root.limb[0];
    }

    function _isqrt(uint256 value_) private pure returns (uint256 result_) {
        if (value_ == 0) return 0;
        uint256 x = value_;
        result_ = 1;
        if (x >> 128 > 0) { x >>= 128; result_ <<= 64; }
        if (x >> 64 > 0) { x >>= 64; result_ <<= 32; }
        if (x >> 32 > 0) { x >>= 32; result_ <<= 16; }
        if (x >> 16 > 0) { x >>= 16; result_ <<= 8; }
        if (x >> 8 > 0) { x >>= 8; result_ <<= 4; }
        if (x >> 4 > 0) { x >>= 4; result_ <<= 2; }
        if (x >> 2 > 0) result_ <<= 1;
        result_ = (result_ + value_ / result_) >> 1;
        result_ = (result_ + value_ / result_) >> 1;
        result_ = (result_ + value_ / result_) >> 1;
        result_ = (result_ + value_ / result_) >> 1;
        result_ = (result_ + value_ / result_) >> 1;
        result_ = (result_ + value_ / result_) >> 1;
        result_ = (result_ + value_ / result_) >> 1;
        while (result_ * result_ > value_) --result_;
    }
}
