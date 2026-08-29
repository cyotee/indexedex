// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";
import {UniswapV4Detf_OwnerOnlyLiquidityOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OwnerOnlyLiquidityOpenBase.sol";

/// @notice Quad gold owner-only liquidity (PRD §7.7). Quad has no CP `deposit(uint256,uint256,...)`.
contract UniswapV4Detf_Quad_OwnerOnlyLiquidity is
    TestBase_UniswapV4Detf_Quad,
    UniswapV4Detf_OwnerOnlyLiquidityOpenBase
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

    function test_reserveHook_ownerIsDetf() public view override {
        assertEq(IMultiStepOwnable(reserveHook).owner(), detf, "hook.owner()==detf");
        assertEq(IMultiStepOwnable(detfInfo.reservePool()).owner(), detf, "reservePool owner");
    }

    function test_reserveHook_thirdPartyAddReverts() public override {
        vm.prank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, detfUser));
        IUniswapV4SeBufferHook(reserveHook).joinSingleAssetExactIn(
            address(pairToken), 1 ether, detfUser, 0, block.timestamp + 1 hours
        );
    }
}
