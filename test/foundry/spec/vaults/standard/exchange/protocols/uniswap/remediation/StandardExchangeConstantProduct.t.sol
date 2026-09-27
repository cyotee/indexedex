// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {StandardExchangeConstantProduct as CP} from "contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol";

/// @dev Pure reference checks supplement (not replace) the production diamond suites.
contract StandardExchangeConstantProductTest is Test {
    function test_zeroFeeSwapThenProportionalMintReference() public pure {
        // PRD example: (100 X, 10000 Y), supply 100. Swap 1000 Y from
        // the 2100 Y input, then add the resulting X and remaining 1100 Y.
        // Post-swap Y=11000; proportional mint=1100*100/11000=10.
        uint256 referenceShares = 1100 ether * 100 ether / 11000 ether;
        assertEq(CP._sharesForDeposit(0, 2100 ether, 100 ether, 100 ether, 10000 ether), referenceShares);
        assertEq(CP._sharesForDeposit(2100 ether, 0, 100 ether, 10000 ether, 100 ether), referenceShares);
        assertApproxEqAbs(CP._singleExit(12100 ether, 100 ether, referenceShares, 110 ether), 2100 ether, 200);
    }
    function test_proportionalMintAndSurplusDonationPolicy() public pure {
        assertEq(CP._sharesForDeposit(10 ether, 1000 ether, 100 ether, 100 ether, 10000 ether), 10 ether);
        assertEq(CP._sharesForDeposit(20 ether, 1000 ether, 100 ether, 100 ether, 10000 ether), 10 ether);
        assertEq(CP._sharesForDeposit(0, 1000 ether, 0, 0, 0), 0, "two-asset activation");
    }
    function test_mixedDecimalsAndLargeProduct() public pure {
        assertEq(CP._sharesForDeposit(1e6, 1e18, 1e12, 1e6, 1e18), 1e12);
        assertEq(CP._sharesForDeposit(1e40, 1e40, 1e40, 1e40, 1e40), 1e40);
        assertGt(CP._sharesForDeposit(1e40, 0, 1e40, 1e40, 1e40), 0);
    }
    function testFuzz_inverseRoundsUpToSufficientShares(uint96 x, uint96 y, uint96 supply, uint96 requested) public pure {
        uint256 outReserve = bound(uint256(x), 100, 1e27);
        uint256 otherReserve = bound(uint256(y), 100, 1e27);
        uint256 s = bound(uint256(supply), 100, 1e27);
        uint256 out = bound(uint256(requested), 1, outReserve / 2);
        uint256 shares = CP._sharesForSingleExit(outReserve, otherReserve, out, s);
        assertGe(CP._singleExit(outReserve, otherReserve, shares, s), out);
        assertLt(CP._singleExit(outReserve, otherReserve, shares - 1, s), out);
    }

    function test_dustAndZeroSupplyCannotProduceOutput() public pure {
        assertEq(CP._singleExit(1000, 1000, 0, 1000), 0);
        assertEq(CP._singleExit(1000, 1000, 1, 0), 0);
        assertEq(CP._sharesForSingleExit(1000, 1000, 0, 1000), 0);
        assertEq(CP._sharesForDeposit(1, 0, 1000, 1000, 1000), 0);
        assertEq(CP._singleExit(1, 1, 1, 1000), 0);
    }
    function test_fullSupplyAndReserveExhaustionHaveExplicitErrors() public {
        vm.expectRevert(CP.InsufficientBacking.selector); this.singleExit(1000, 1000, 1000, 1000);
        vm.expectRevert(CP.InsufficientBacking.selector); this.singleExit(1000, 0, 1001, 1000);
        vm.expectRevert(CP.InsufficientBacking.selector); this.inverse(1000, 1000, 1001, 1000);
        vm.expectRevert(CP.InsufficientBacking.selector); this.inverse(1000, 1000, 1, 0);
        assertEq(CP._singleExit(1000, 0, 1000, 1000), 1000);
        assertEq(CP._sharesForSingleExit(1000, 0, 1000, 1000), 1000);
    }
    function singleExit(uint256 x, uint256 y, uint256 shares, uint256 supply) external pure returns (uint256) {
        return CP._singleExit(x, y, shares, supply);
    }
    function inverse(uint256 x, uint256 y, uint256 output, uint256 supply) external pure returns (uint256) {
        return CP._sharesForSingleExit(x, y, output, supply);
    }
    function testFuzz_singleExitMatchesIndependentBurnThenSwap(uint96 x_, uint96 y_, uint96 supply_, uint96 burn_) public pure {
        uint256 x = bound(x_, 2, 1e27); uint256 y = bound(y_, 2, 1e27);
        uint256 supply = bound(supply_, 2, 1e27); uint256 burn = bound(burn_, 1, supply - 1);
        uint256 first = x * burn / supply; uint256 second = y * burn / supply;
        uint256 remainingX = x - first; uint256 remainingY = y - second;
        uint256 expected = first + second * remainingX / (remainingY + second);
        assertEq(CP._singleExit(x, y, burn, supply), expected);
        assertLe(expected, x);
    }

    function test_scaledMinimumLiquidity_decimalMatrix() public pure {
        assertEq(CP._minimumLiquidity(uint8(18),uint8(18)),1e15);
        assertEq(CP._minimumLiquidity(uint8(6),uint8(18)),1e9);
        assertEq(CP._minimumLiquidity(uint8(6),uint8(6)),1e3);
        assertEq(CP._minimumLiquidity(uint8(6),uint8(9)),1e4);
        assertEq(CP._minimumLiquidity(uint8(2),uint8(3)),1);
        assertEq(CP._initialShares(1e15+1,1e15+1,1e15),1);
        assertEq(CP._initialShares(1001,1001,1000),1);
        assertEq(CP._initialShares(0,1001,1000),0);
    }
    function test_minimumBoundary_revertsExactly() public {
        vm.expectRevert(abi.encodeWithSelector(CP.InsufficientMinimumLiquidity.selector,1000,1000));
        this.initialShares(1000,1000,1000);
    }
    function initialShares(uint256 a,uint256 b,uint256 minimum) external pure returns(uint256) {
        return CP._initialShares(a,b,minimum);
    }

    /* ------------------- D64 exact-out mint (`_amountInForShares`) ------------------- */

    function amountInForShares(uint256 rIn, uint256 rOther, uint256 sharesOut, uint256 supply)
        external pure returns (uint256)
    {
        return CP._amountInForShares(rIn, rOther, sharesOut, supply);
    }

    /// @dev The single-token deposit forward for a token0-in deposit: amount1Added == 0.
    function _fwdSingle(uint256 amountIn, uint256 rIn, uint256 rOther, uint256 supply)
        internal pure returns (uint256)
    {
        return CP._sharesForDeposit(amountIn, 0, supply, rIn, rOther);
    }

    /// @notice D64: the closed-form inverse returns an input whose forward quote is at least the
    ///         requested shares (no dilution), and it is tight (one wei less falls short) on the
    ///         invariant branch. Reference values plus the two structural branches.
    function test_amountInForShares_referenceAndRoundTrip() public pure {
        // Invariant branch: (100, 10000), supply 100. Ask 5 shares.
        uint256 rIn = 100 ether; uint256 rOther = 10000 ether; uint256 supply = 100 ether;
        uint256 want = 5 ether;
        uint256 need = CP._amountInForShares(rIn, rOther, want, supply);
        assertGt(need, 0, "positive input");
        assertGe(_fwdSingle(need, rIn, rOther, supply), want, "forward of the closed-form input meets the request");

        // Linear branch: the paired reserve is empty, forward is mulDiv(amountIn, supply, rIn).
        assertEq(CP._amountInForShares(1000, 0, 10, 1000), 10, "linear: ceil(10*1000/1000)=10");
        assertEq(CP._amountInForShares(100000, 0, 3, 1000), 300, "linear: ceil(3*100000/1000)=300");
        // Linear ceil: ask needs rounding up so the forward is not short.
        uint256 linNeed = CP._amountInForShares(1000, 0, 7, 999);
        assertGe(_fwdSingle(linNeed, 1000, 0, 999), 7, "linear inverse is sufficient");
    }

    function test_amountInForShares_revertsWhereNoClosedForm() public {
        // First mint (supply 0) has no single-token closed form.
        vm.expectRevert(CP.InsufficientBacking.selector); this.amountInForShares(100, 100, 1, 0);
        // Depositing into an empty same-side reserve yields zero shares for any input.
        vm.expectRevert(CP.InsufficientBacking.selector); this.amountInForShares(0, 100, 1, 100);
        // Zero shares requested is a no-op (zero input), never a revert.
        assertEq(CP._amountInForShares(100, 100, 0, 100), 0, "zero request -> zero input");
    }

    function testFuzz_amountInForSharesIsSufficient(uint96 x, uint96 y, uint96 supply, uint96 requested) public pure {
        uint256 rIn = bound(uint256(x), 1e3, 1e27);
        uint256 rOther = bound(uint256(y), 1e3, 1e27);
        uint256 s = bound(uint256(supply), 1e3, 1e27);
        // Keep the request within a sane fraction of supply so the input stays representable.
        uint256 want = bound(uint256(requested), 1, s);
        uint256 need = CP._amountInForShares(rIn, rOther, want, s);
        assertGt(need, 0, "positive input for a positive request");
        // No dilution: minting exactly `want` against `need` booked is backed by the forward quote.
        assertGe(_fwdSingle(need, rIn, rOther, s), want, "forward of the closed-form input is never short");
    }
}
