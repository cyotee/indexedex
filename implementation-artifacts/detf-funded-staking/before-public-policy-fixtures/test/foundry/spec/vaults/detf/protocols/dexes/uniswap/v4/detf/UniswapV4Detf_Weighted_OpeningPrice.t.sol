// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {TestBase_UniswapV4Detf_Weighted_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Policy.sol";
import {UniswapV4Detf_OpeningPriceLayerBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OpeningPriceLayerBase.sol";

/// @notice Weighted gold opening T1/T2/T5 plus T6 opening length (WP-UDPL-WE).
contract UniswapV4Detf_Weighted_OpeningPrice is
    TestBase_UniswapV4Detf_Weighted_Policy,
    UniswapV4Detf_OpeningPriceLayerBase
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Weighted_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Weighted._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted._assertNoJoinableDust();
    }

    function _baseArgs()
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._baseArgs();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._deployInstance(args);
    }

    function _mintTokenOf(address d)
        internal
        view
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (IERC20)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._mintTokenOf(d);
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._expectInvalidCreationRate(args);
    }

    function _ownerSwap(address d, address tokenIn, address tokenOut, uint256 amount)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._ownerSwap(d, tokenIn, tokenOut, amount);
    }

    function _pushSyntheticUp(address d)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._pushSyntheticUp(d);
    }

    function _skewSyntheticDown(address d)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._skewSyntheticDown(d);
    }

    function _burnOn(address d, uint256 detfIn, IERC20 tokenOut)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (uint256 amountOut)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._burnOn(d, detfIn, tokenOut);
    }

    /// @notice T6: openingPairPerDetfWad length != 0 and != pairCount (2) reverts InvalidCreationRate.
    function test_T6_openingLengthMismatch_reverts() public {
        IUniswapV4Detf.PkgArgs memory args = _nLegDetfArgs(2);
        args.name = "BadOpenLen Wgt";
        args.symbol = string.concat("bOLW", _nextTag());
        args.openingPairPerDetfWad = new uint256[](1);
        args.openingPairPerDetfWad[0] = LAUNCH_RICH_START;
        _deployWeightedHookForArgs(args);
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }
}
