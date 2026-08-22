// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from
    "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/// @dev Owner that can hold an open PoolManager unlock and call hook owner paths from unlockCallback.
contract CpOwnerDuringLockHarness is IUnlockCallback {
    IPoolManager public immutable pm;

    constructor(IPoolManager pm_) {
        pm = pm_;
    }

    function run(address target, bytes calldata data) external returns (bytes memory) {
        return pm.unlock(abi.encode(target, data));
    }

    function unlockCallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sender == address(pm), "not pm");
        (address target, bytes memory data) = abi.decode(raw, (address, bytes));
        (bool ok, bytes memory ret) = target.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        return ret;
    }
}

/// @notice D30 / D89: owner swap + MIN depositSingle while PoolManager is unlocked.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock_Test is TestBase {
    WrapperExactOutRouter internal swapRouter;

    function _pkgOwnerOnlyLiquidity() internal view virtual override returns (bool) {
        return true;
    }

    function setUp() public override {
        TestBase.setUp();
        swapRouter = new WrapperExactOutRouter(pm);
        rawToken.mint(owner, 1_000_000 ether);
        pairToken.mint(owner, 1_000_000 ether);
        rawToken.mint(user, 1_000_000 ether);
        pairToken.mint(user, 1_000_000 ether);
        vm.startPrank(owner);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        rawToken.approve(address(swapRouter), type(uint256).max);
        pairToken.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(user);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        rawToken.approve(address(swapRouter), type(uint256).max);
        pairToken.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function test_D30_ownerSwapExactIn_matchesPreview_sameFeeAsPublic() public {
        _ownerSeedBook();
        address tokenIn = single.currency0();
        address tokenOut = single.currency1();
        uint256 amountIn = 1 ether;
        bool zfo = true;
        uint256 pred = single.previewSwapExactIn(zfo, amountIn);
        assertGt(pred, 0, "preview out");

        uint256 outBefore = IERC20(tokenOut).balanceOf(owner);
        vm.prank(owner);
        uint256 amountOut = single.ownerSwapExactIn(tokenIn, tokenOut, amountIn, 0, block.timestamp + 1 hours);
        assertEq(amountOut, pred, "owner exact-in == preview (same 0.3% book)");
        assertEq(IERC20(tokenOut).balanceOf(owner) - outBefore, amountOut, "owner received out");
    }

    function test_D30_ownerSwapExactOut_matchesPreview() public {
        _ownerSeedBook();
        address tokenIn = single.currency0();
        address tokenOut = single.currency1();
        uint256 wantOut = 0.4 ether;
        uint256 predIn = single.previewSwapExactOut(true, wantOut);
        assertGt(predIn, 0, "preview in");
        vm.prank(owner);
        uint256 amountIn = single.ownerSwapExactOut(
            tokenIn, tokenOut, wantOut, predIn, block.timestamp + 1 hours
        );
        assertEq(amountIn, predIn, "owner exact-out == preview");
    }

    function test_D30_thirdPartyCannotOwnerSwap() public {
        _ownerSeedBook();
        address attacker = makeAddr("d30attacker");
        assertTrue(attacker != IMultiStepOwnable(hook).owner(), "attacker is not owner");
        rawToken.mint(attacker, 10 ether);
        pairToken.mint(attacker, 10 ether);
        address tokenIn = single.currency0();
        address tokenOut = single.currency1();
        vm.startPrank(attacker);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        single.ownerSwapExactIn(tokenIn, tokenOut, 1 ether, 0, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_D30_publicSwapStillFills() public {
        _ownerSeedBook();
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
        assertGt(IERC20(c1).balanceOf(user), before1, "public swap filled");
    }

    function test_D89_ownerSwap_whilePoolManagerUnlocked() public {
        _ownerSeedBook();
        CpOwnerDuringLockHarness harness = new CpOwnerDuringLockHarness(pm);
        _transferHookOwner(address(harness));

        address tokenIn = single.currency0();
        address tokenOut = single.currency1();
        uint256 amountIn = 1 ether;
        if (tokenIn == address(rawToken)) rawToken.mint(address(harness), 10 ether);
        else pairToken.mint(address(harness), 10 ether);
        vm.prank(address(harness));
        IERC20(tokenIn).approve(hook, type(uint256).max);

        uint256 pred = single.previewSwapExactIn(true, amountIn);
        bytes memory ret = harness.run(
            hook,
            abi.encodeWithSelector(
                IHook.ownerSwapExactIn.selector,
                tokenIn,
                tokenOut,
                amountIn,
                0,
                block.timestamp + 1 hours
            )
        );
        uint256 amountOut = abi.decode(ret, (uint256));
        assertEq(amountOut, pred, "owner swap during unlock == preview");
        assertEq(IERC20(tokenOut).balanceOf(address(harness)), amountOut, "harness received out");
    }

    function test_D89_ownerDepositSingle_atMin_lpOutGt0() public {
        _ownerSeedBook();
        uint256 lp = IERC20(hook).balanceOf(owner);
        assertGt(lp, 0, "owner LP");
        vm.prank(owner);
        single.withdraw(lp, owner, 0, 0, block.timestamp + 1 hours);
        assertEq(IERC20(hook).totalSupply(), 1000, "MIN remains");
        assertFalse(single.isZapEligible(), "public zap closed at MIN");

        vm.prank(user);
        vm.expectRevert();
        single.depositSingle(address(pairToken), 20 ether, user, 0, block.timestamp + 1 hours);

        vm.prank(owner);
        uint256 lpOut = single.depositSingle(address(pairToken), 50 ether, owner, 0, block.timestamp + 1 hours);
        assertGt(lpOut, 0, "owner MIN depositSingle lpOut > 0");
        assertGt(IERC20(hook).balanceOf(owner), 0, "owner received LP");
    }

    function test_D89_ownerDepositSingle_atMin_whileUnlocked() public {
        _ownerSeedBook();
        uint256 lp = IERC20(hook).balanceOf(owner);
        vm.prank(owner);
        single.withdraw(lp, owner, 0, 0, block.timestamp + 1 hours);
        assertEq(IERC20(hook).totalSupply(), 1000, "MIN remains");

        CpOwnerDuringLockHarness harness = new CpOwnerDuringLockHarness(pm);
        _transferHookOwner(address(harness));
        pairToken.mint(address(harness), 100 ether);
        vm.prank(address(harness));
        pairToken.approve(hook, type(uint256).max);

        bytes memory ret = harness.run(
            hook,
            abi.encodeWithSelector(
                IHook.depositSingle.selector,
                address(pairToken),
                50 ether,
                address(harness),
                uint256(0),
                block.timestamp + 1 hours
            )
        );
        uint256 lpOut = abi.decode(ret, (uint256));
        assertGt(lpOut, 0, "owner MIN depositSingle during unlock lpOut > 0");
    }

    function _ownerSeedBook() internal {
        uint256 a0 = _amountForCurrency(single.currency0(), 200 ether, 200 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 200 ether, 200 ether);
        vm.prank(owner);
        (uint256 lp,,) = single.deposit(a0, a1, owner, 0, block.timestamp + 1 hours);
        assertGt(lp, 0, "seed LP");
    }

    function _transferHookOwner(address newOwner_) internal {
        IMultiStepOwnable ownable_ = IMultiStepOwnable(hook);
        vm.prank(owner);
        ownable_.initiateOwnershipTransfer(newOwner_);
        vm.warp(block.timestamp + ownable_.getOwnershipTransferBuffer() + 1);
        vm.prank(owner);
        ownable_.confirmOwnershipTransfer(newOwner_);
        vm.prank(newOwner_);
        ownable_.acceptOwnershipTransfer();
        assertEq(ownable_.owner(), newOwner_, "hook owner is harness");
    }
}
