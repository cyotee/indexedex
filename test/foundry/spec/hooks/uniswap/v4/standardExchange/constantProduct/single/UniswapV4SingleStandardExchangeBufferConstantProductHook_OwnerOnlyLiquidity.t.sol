// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/// @notice D9: ownerOnlyLiquidity=true — third-party LP reverts; owner LP succeeds; swaps stay public.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerOnlyLiquidity_Test is TestBase {
    WrapperExactOutRouter internal swapRouter;

    function _pkgOwnerOnlyLiquidity() internal view virtual override returns (bool) {
        return true;
    }

    function setUp() public override {
        TestBase.setUp();
        swapRouter = new WrapperExactOutRouter(pm);
        rawToken.mint(owner, 1_000_000 ether);
        pairToken.mint(owner, 1_000_000 ether);
        vm.startPrank(owner);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        rawToken.approve(address(swapRouter), type(uint256).max);
        pairToken.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(user);
        rawToken.approve(address(swapRouter), type(uint256).max);
        pairToken.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function test_ownerOnlyLiquidity_ownerIsPkgOwner() public view {
        assertEq(IMultiStepOwnable(hook).owner(), owner);
    }

    function test_ownerOnlyLiquidity_thirdPartyAddReverts() public {
        uint256 a0 = _amountForCurrency(single.currency0(), 10 ether, 10 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 10 ether, 10 ether);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, user));
        single.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
    }

    function test_ownerOnlyLiquidity_ownerAddSucceeds() public {
        uint256 lp = _ownerSeed(100 ether);
        assertGt(lp, 0);
        assertGt(IERC20(hook).balanceOf(owner), 0);
    }

    function test_ownerOnlyLiquidity_publicSwapStillWorks() public {
        _ownerSeed(200 ether);

        uint256 amountIn = 1 ether;
        uint256 pred = single.previewSwapExactIn(true, amountIn);
        assertGt(pred, 0);
        address c1 = single.currency1();
        uint256 before1 = IERC20(c1).balanceOf(user);
        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            ""
        );
        assertGt(IERC20(c1).balanceOf(user), before1);
    }

    function _ownerSeed(uint256 amount_) internal returns (uint256 lp_) {
        vm.startPrank(owner);
        pairToken.approve(se, amount_);
        (uint256 shares_,) = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)), amount_, IERC20(se), 1, owner, false, block.timestamp
        );
        IERC20(se).approve(hook, shares_);
        (lp_,,) = single.depositWithSeShares(amount_, shares_, owner, 1, block.timestamp + 1 hours);
        vm.stopPrank();
    }
}
