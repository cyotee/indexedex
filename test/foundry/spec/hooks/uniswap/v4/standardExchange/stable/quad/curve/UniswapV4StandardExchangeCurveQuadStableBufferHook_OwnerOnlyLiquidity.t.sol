// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

/// @notice D9: ownerOnlyLiquidity=true — third-party LP reverts; owner LP succeeds; swaps stay public.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_OwnerOnlyLiquidity_Test is
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook
{
    function _pkgOwnerOnlyLiquidity() internal view virtual override returns (bool) {
        return true;
    }

    function setUp() public override {
        super.setUp();
        token0.mint(owner, FUND);
        token1.mint(owner, FUND);
        token2.mint(owner, FUND);
        token3.mint(owner, FUND);
        vm.startPrank(owner);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        token3.approve(hook, type(uint256).max);
        IERC20(se0).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function test_ownerOnlyLiquidity_ownerIsPkgOwner() public view {
        assertEq(IMultiStepOwnable(hook).owner(), owner);
    }

    function test_ownerOnlyLiquidity_thirdPartyAddReverts() public {
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 10 ether;
        amounts[1] = 10 ether;
        amounts[2] = 10 ether;
        amounts[3] = 10 ether;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, user));
        quad.joinProportional(amounts, user, 0, block.timestamp + 1 days);
    }

    function test_ownerOnlyLiquidity_ownerAddSucceeds() public {
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;
        amounts[2] = 100 ether;
        amounts[3] = 100 ether;
        vm.prank(owner);
        (uint256 shares,) = quad.joinProportional(amounts, owner, 0, block.timestamp + 1 days);
        assertGt(shares, 0);
        assertGt(IERC20(hook).balanceOf(owner), 0);
    }

    function test_ownerOnlyLiquidity_publicSwapStillWorks() public {
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 500 ether;
        amounts[1] = 500 ether;
        amounts[2] = 500 ether;
        amounts[3] = 500 ether;
        vm.prank(owner);
        quad.joinProportional(amounts, owner, 0, block.timestamp + 1 days);
        uint256 preview = quad.previewSwapExactIn(address(token1), address(token2), 1 ether);
        assertGt(preview, 0);
        uint256 before = token2.balanceOf(user);
        _swapExactIn(address(token1), address(token2), 1 ether);
        assertEq(token2.balanceOf(user) - before, preview);
    }
}
