// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

/// @notice D9: ownerOnlyLiquidity=true — third-party LP reverts; owner LP succeeds; swaps stay public.
contract UniswapV4StandardExchangeOrbitalBufferHook_OwnerOnlyLiquidity_Test is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function _pkgOwnerOnlyLiquidity() internal view virtual override returns (bool) {
        return true;
    }

    function setUp() public override {
        super.setUp();
        token0.mint(owner, FUND);
        token1.mint(owner, FUND);
        token2.mint(owner, FUND);
        vm.startPrank(owner);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        IERC20(se0).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function test_ownerOnlyLiquidity_ownerIsPkgOwner() public view {
        assertEq(IMultiStepOwnable(hook).owner(), owner);
    }

    function test_ownerOnlyLiquidity_thirdPartyAddReverts() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, user));
        orbital.addLiquidity(100 ether, 100 ether, 100 ether, user, 0, block.timestamp + 1 hours, "");
    }

    function test_ownerOnlyLiquidity_ownerAddSucceeds() public {
        vm.prank(owner);
        (uint256 shares,,,) =
            orbital.addLiquidity(100 ether, 100 ether, 100 ether, owner, 0, block.timestamp + 1 hours, "");
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(owner), shares);
    }

    function test_ownerOnlyLiquidity_publicSwapStillWorks() public {
        vm.prank(owner);
        orbital.addLiquidity(500 ether, 500 ether, 500 ether, owner, 0, block.timestamp + 1 hours, "");
        uint256 preview = orbital.previewSwapExactIn(address(token1), address(token2), 1 ether);
        assertGt(preview, 0);
        uint256 before = token2.balanceOf(user);
        _swapExactIn(address(token1), address(token2), 1 ether);
        assertEq(token2.balanceOf(user) - before, preview);
    }
}
