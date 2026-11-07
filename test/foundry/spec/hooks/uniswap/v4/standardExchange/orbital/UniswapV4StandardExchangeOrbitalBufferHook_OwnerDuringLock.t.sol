// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {HookOwnerDuringLockHarness} from "contracts/test/stubs/HookOwnerDuringLockHarness.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";

/// @notice D30 / D89: owner swap + MIN depositSingle while PoolManager is unlocked.
contract UniswapV4StandardExchangeOrbitalBufferHook_OwnerDuringLock_Test is
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

    function test_D30_ownerSwapExactIn_matchesPreview() public {
        _ownerSeedBook();
        uint256 pred = orbital.previewSwapExactIn(address(token1), address(token2), 1 ether);
        assertGt(pred, 0);
        uint256 before = token2.balanceOf(owner);
        vm.prank(owner);
        uint256 out_ = orbital.ownerSwapExactIn(
            address(token1), address(token2), 1 ether, 0, block.timestamp + 1 hours
        );
        assertEq(out_, pred, "owner exact-in == preview");
        assertEq(token2.balanceOf(owner) - before, out_);
    }

    function test_D30_ownerSwapExactOut_matchesPreview() public {
        _ownerSeedBook();
        uint256 want = 0.4 ether;
        uint256 predIn = orbital.previewSwapExactOut(address(token1), address(token2), want);
        vm.prank(owner);
        uint256 in_ = orbital.ownerSwapExactOut(
            address(token1), address(token2), want, predIn, block.timestamp + 1 hours
        );
        assertEq(in_, predIn);
    }

    function test_D30_thirdPartyCannotOwnerSwap() public {
        _ownerSeedBook();
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, user));
        vm.prank(user);
        orbital.ownerSwapExactIn(address(token1), address(token2), 1 ether, 0, block.timestamp + 1 hours);
    }

    function test_D30_publicSwapStillFills() public {
        _ownerSeedBook();
        uint256 pred = orbital.previewSwapExactIn(address(token1), address(token2), 1 ether);
        uint256 before = token2.balanceOf(user);
        _swapExactIn(address(token1), address(token2), 1 ether);
        assertEq(token2.balanceOf(user) - before, pred, "public swap filled");
    }

    function test_D89_ownerSwap_whilePoolManagerUnlocked() public {
        _ownerSeedBook();
        HookOwnerDuringLockHarness harness = new HookOwnerDuringLockHarness(pm);
        _transferHookOwner(address(harness));
        token1.mint(address(harness), 10 ether);
        vm.prank(address(harness));
        token1.approve(hook, type(uint256).max);
        uint256 pred = orbital.previewSwapExactIn(address(token1), address(token2), 1 ether);
        bytes memory ret = harness.run(
            hook,
            abi.encodeWithSelector(
                IUniswapV4SeBufferHook.ownerSwapExactIn.selector,
                address(token1),
                address(token2),
                uint256(1 ether),
                uint256(0),
                block.timestamp + 1 hours
            )
        );
        assertEq(abi.decode(ret, (uint256)), pred);
    }

    function test_D89_ownerAtMinCanFundSingleLegJoin() public {
        _ownerSeedBook();
        uint256 protocolLp = IERC20(hook).balanceOf(feeRecipient);
        vm.prank(feeRecipient);
        IERC20(hook).transfer(owner, protocolLp);
        uint256 lp = IERC20(hook).balanceOf(owner);
        vm.prank(owner);
        orbital.removeLiquidity(lp, owner, 0, 0, 0, block.timestamp + 1 hours);
        assertEq(IERC20(hook).totalSupply(), 1000, "MIN remains");
        assertFalse(orbital.isZapEligible());

        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, user));
        vm.prank(user);
        orbital.depositSingle(address(token1), 20 ether, user, 0, block.timestamp + 1 hours, "");

        assertEq(IERC20(hook).totalSupply(), 1000, "unauthorized join preserves MIN supply");

        uint256 beforeInput = token1.balanceOf(owner);
        uint256 amount = orbital.rawReserve(1) / 4;
        assertGt(amount, 0, "remaining native book supports a bounded owner trade");
        vm.prank(owner);
        uint256 quote = orbital.previewDepositSingle(address(token1), amount);
        assertGt(quote, 0);
        vm.prank(owner);
        uint256 singleMinted = orbital.depositSingle(address(token1), amount, owner, quote, block.timestamp + 1 hours, "");
        assertEq(singleMinted, quote);
        assertGt(beforeInput - token1.balanceOf(owner), 0);
        assertLe(beforeInput - token1.balanceOf(owner), amount);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000, "locked floor remains");

        uint256 beforeLocal = orbital.rawReserve(0);
        uint256 beforeShares = orbital.seBalance(0);
        uint256 beforeSupply = IERC20(hook).totalSupply();
        vm.prank(owner);
        (uint256 lpOut,,,) = orbital.addLiquidity(1 ether, 1 ether, 1 ether, owner, 1, block.timestamp, "");
        assertGt(lpOut, 0, "caller-funded complete basket still rejoins the locked floor");
        uint256 gross = IERC20(hook).totalSupply() - beforeSupply;
        assertEq(orbital.rawReserve(0) - beforeLocal, (gross * beforeLocal + beforeSupply - 1) / beforeSupply);
        assertEq(orbital.seBalance(0) - beforeShares, (gross * beforeShares + beforeSupply - 1) / beforeSupply);
    }

    function _ownerSeedBook() internal {
        (uint256 shares,,,) = _seedFor(orbital, owner, 500 ether, 500 ether, 500 ether);
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
