// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";
import {UniswapV4Detf_Alignment_CloseD25OpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25OpenBase.sol";

/// @notice Actual Quad binding of the shared funded D25 assertions.
contract UniswapV4Detf_Quad_Alignment_CloseD25 is
    TestBase_UniswapV4Detf_Quad,
    UniswapV4Detf_Alignment_CloseD25OpenBase
{
    function setUp() public override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf) {
        TestBase_UniswapV4Detf_Quad.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Quad._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf)
    {
        TestBase_UniswapV4Detf_Quad._assertNoJoinableDust();
    }

    function _bondAs(address bonder_, uint256 pairAmount_)
        internal
        override
        returns (uint256 tokenId_, uint256 shares_)
    {
        pair0.mint(bonder_, pairAmount_);
        pair1.mint(bonder_, pairAmount_);
        pair2.mint(bonder_, pairAmount_);
        vm.startPrank(bonder_);
        pair0.approve(detf, type(uint256).max);
        pair1.approve(detf, type(uint256).max);
        pair2.approve(detf, type(uint256).max);
        IERC20(se0).approve(detf, type(uint256).max);
        IERC20(se1).approve(detf, type(uint256).max);
        IERC20(se2).approve(detf, type(uint256).max);
        (tokenId_, shares_) = detfInfo.bond(
            IERC20(address(pairToken)),
            pairAmount_,
            DEFAULT_MIN_LOCK,
            bonder_,
            false,
            _deadline()
        );
        vm.stopPrank();
    }

}
