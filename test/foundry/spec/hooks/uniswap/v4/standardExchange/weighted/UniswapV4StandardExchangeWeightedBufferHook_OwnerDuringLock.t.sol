// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {HookOwnerDuringLockHarness} from "contracts/test/stubs/HookOwnerDuringLockHarness.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";

/// @notice D30 / D89: owner swap + MIN depositSingle while PoolManager is unlocked.
contract UniswapV4StandardExchangeWeightedBufferHook_OwnerDuringLock_Test is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function _pkgOwnerOnlyLiquidity() internal view virtual override returns (bool) {
        return true;
    }

    function setUp() public override {
        super.setUp();
        token0.mint(owner, FUND);
        token1.mint(owner, FUND);
        vm.startPrank(owner);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        IERC20(se0).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function test_D30_ownerSwapExactIn_matchesPreview() public {
        _ownerSeedBook();
        uint256 pred = weighted.previewSwapExactIn(address(token0), address(token1), 1 ether);
        assertGt(pred, 0);
        uint256 before = token1.balanceOf(owner);
        vm.prank(owner);
        uint256 out_ = weighted.ownerSwapExactIn(
            address(token0), address(token1), 1 ether, 0, block.timestamp + 1 days
        );
        assertEq(out_, pred, "owner exact-in == preview");
        assertEq(token1.balanceOf(owner) - before, out_);
    }

    function test_D30_ownerSwapExactOut_matchesPreview() public {
        _ownerSeedBook();
        uint256 want = 0.4 ether;
        uint256 predIn = weighted.previewSwapExactOut(address(token0), address(token1), want);
        vm.prank(owner);
        uint256 in_ = weighted.ownerSwapExactOut(
            address(token0), address(token1), want, predIn, block.timestamp + 1 days
        );
        assertEq(in_, predIn);
    }

    function test_D30_thirdPartyCannotOwnerSwap() public {
        _ownerSeedBook();
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, user));
        vm.prank(user);
        weighted.ownerSwapExactIn(address(token0), address(token1), 1 ether, 0, block.timestamp + 1 days);
    }

    function test_D30_publicSwapStillFills() public {
        _ownerSeedBook();
        uint256 pred = weighted.previewSwapExactIn(address(token0), address(token1), 1 ether);
        uint256 before = token1.balanceOf(user);
        _swapExactIn(address(token0), address(token1), 1 ether);
        assertEq(token1.balanceOf(user) - before, pred);
    }

    function test_D89_ownerSwap_whilePoolManagerUnlocked() public {
        _ownerSeedBook();
        HookOwnerDuringLockHarness harness = new HookOwnerDuringLockHarness(pm);
        _transferHookOwner(address(harness));
        token0.mint(address(harness), 10 ether);
        vm.prank(address(harness));
        token0.approve(hook, type(uint256).max);
        uint256 pred = weighted.previewSwapExactIn(address(token0), address(token1), 1 ether);
        bytes memory ret = harness.run(
            hook,
            abi.encodeWithSelector(
                IHook.ownerSwapExactIn.selector,
                address(token0),
                address(token1),
                uint256(1 ether),
                uint256(0),
                block.timestamp + 1 days
            )
        );
        assertEq(abi.decode(ret, (uint256)), pred);
    }

    function test_D89_ownerDepositSingle_atMin_lpOutGt0() public {
        _ownerSeedBook();
        uint256 lp = IERC20(hook).balanceOf(owner);
        uint256[] memory mins = new uint256[](2);
        vm.prank(owner);
        weighted.exitProportional(lp, owner, mins, block.timestamp + 1 days);
        assertEq(IERC20(hook).totalSupply(), 1000, "MIN remains");

        // token1 is the raw (unbuffered) leg; size join to remaining MIN inventory.
        uint256 joinAmt = token1.balanceOf(hook) / 4;
        if (joinAmt == 0) joinAmt = 1;
        vm.expectRevert();
        vm.prank(user);
        weighted.depositSingle(address(token1), joinAmt, user, 0, block.timestamp + 1 days);

        vm.prank(owner);
        uint256 lpOut = weighted.depositSingle(address(token1), joinAmt, owner, 0, block.timestamp + 1 days);
        assertGt(lpOut, 0, "owner MIN depositSingle lpOut > 0");
    }

    function _ownerSeedBook() internal {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 500 ether;
        amounts[1] = 500 ether;
        vm.prank(owner);
        (uint256 shares,) = weighted.joinProportional(amounts, owner, 0, block.timestamp + 1 days);
        assertGt(shares, 0);
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
        assertEq(ownable_.owner(), newOwner_);
    }
}