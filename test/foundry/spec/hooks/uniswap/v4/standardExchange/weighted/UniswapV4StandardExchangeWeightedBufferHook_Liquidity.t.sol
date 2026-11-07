// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Vm} from "forge-std/Vm.sol";

/**
 * @notice H5–H6 full-book LP: prop / unbalanced / single / aliases / D42a.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Liquidity is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function test_firstMint_fullBook_inventoryBook() public {
        uint256 amount = 100 ether;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        bool[] memory flags = _prepareShareSeed(user, amounts);
        (uint256 previewShares, uint256[] memory previewUsed) = weighted.previewJoinProportionalFlexible(amounts, flags);

        vm.prank(user);
        (uint256 shares, uint256[] memory used) =
            weighted.joinProportionalFlexible(amounts, flags, user, 0, block.timestamp + 1 hours);

        assertEq(shares, previewShares, "preview==exec shares");
        assertEq(used[0], previewUsed[0], "preview used0");
        assertEq(used[1], previewUsed[1], "preview used1");
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(user), shares);
        uint256 gross = IERC20(hook).totalSupply() - 1000;
        uint256 fee = weighted.feeTo() == address(0) ? 0 : gross * weighted.usageFee() / 1e18;
        assertEq(gross, shares + fee);
        assertGt(weighted.nativeReserve(0), 0, "SE book");
        assertEq(weighted.nativeReserve(0), weighted.seBalance(0), "live SE shares");
        assertEq(weighted.nativeReserve(1), amount, "raw face book");
        assertTrue(weighted.isFullBook());
    }

    function test_D36_restingFace_notPaidToJoiner() public {
        _firstMintEqual(100 ether);
        address donor = address(0xD0D0);
        token0.mint(donor, 500 ether);
        vm.prank(donor);
        token0.transfer(hook, 500 ether);
        uint256 user0 = token0.balanceOf(user);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 1 ether;
        vm.prank(user);
        weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertLt(token0.balanceOf(user), user0, "D36: joiner does not collect resting face");
    }

    function test_joinUnbalanced_previewEqualsExec() public {
        _firstMintEqual(200 ether);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 30 ether;
        uint256 preview = weighted.previewJoinUnbalanced(amounts);
        assertGt(preview, 0);

        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 shares = weighted.joinUnbalanced(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(shares, preview, "unbalanced preview==exec");
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, shares);
    }

    function test_singleAliasesPreparePaidBasket_andCompleteBasketRefunds() public {
        _firstMintEqual(100 ether);
        uint256 amountIn = 10 ether;
        uint256 singlePreview = weighted.previewJoinSingleAssetExactIn(address(token1), amountIn);
        assertGt(singlePreview, 0);
        assertEq(weighted.previewDepositSingle(address(token1), amountIn), singlePreview);
        uint256 checkpoint = vm.snapshotState();
        uint256 lpBeforeSingle = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 single = weighted.joinSingleAssetExactIn(address(token1), amountIn, user, 1, block.timestamp + 1 hours);
        assertEq(single, singlePreview);
        assertEq(IERC20(hook).balanceOf(user) - lpBeforeSingle, single);
        bytes32 afterSingle = _componentOwnershipState(user);
        assertTrue(vm.revertToState(checkpoint));
        vm.prank(user);
        assertEq(weighted.depositSingle(address(token1), amountIn, user, 1, block.timestamp + 1 hours), single);
        assertEq(_componentOwnershipState(user), afterSingle);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether; amounts[1] = amountIn;
        (uint256 preview,) = weighted.previewJoinProportional(amounts);
        assertGt(preview, 0);
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 tBefore = token1.balanceOf(user);
        vm.recordLogs();
        vm.prank(user);
        (uint256 depShares,) = weighted.joinProportional(amounts, user, 1, block.timestamp + 1 hours);
        assertEq(depShares, preview);
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, depShares);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint256 pulled;
        uint256 refunded;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].emitter != address(token1) || entries[i].topics.length != 3
                || entries[i].topics[0] != keccak256("Transfer(address,address,uint256)")) continue;
            address from = address(uint160(uint256(entries[i].topics[1])));
            address to = address(uint160(uint256(entries[i].topics[2])));
            if (from == user && to == hook) pulled += abi.decode(entries[i].data, (uint256));
            if (from == hook && to == user) refunded += abi.decode(entries[i].data, (uint256));
        }
        assertEq(pulled, amountIn, "full declared budget is funded");
        assertGt(refunded, 0, "unused component input is returned");
        assertEq(tBefore - token1.balanceOf(user), pulled - refunded, "actual debit excludes the exact refund");
    }

    function test_joinSingleAssetExactOut_preparesCallerComponents() public {
        _firstMintEqual(100 ether);
        uint256 desired = 1 ether;
        uint256 maximum = weighted.previewJoinSingleAssetExactOut(address(token1), desired);
        assertGt(maximum, 0);
        assertGe(weighted.previewJoinSingleAssetExactIn(address(token1), maximum), desired);
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 tokenBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 used = weighted.joinSingleAssetExactOut(address(token1), desired, user, maximum, block.timestamp + 1 hours);
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, desired);
        assertEq(tokenBefore - token1.balanceOf(user), used);
        assertLe(used, maximum);
    }

    function test_exitProportional_previewEqualsExec() public {
        uint256 mintShares = _firstMintEqual(100 ether);
        uint256 burn = mintShares / 4;
        uint256[] memory preview = weighted.previewExitProportional(burn);
        uint256[] memory mins = new uint256[](2);

        uint256 bal0 = token0.balanceOf(user);
        uint256 bal1 = token1.balanceOf(user);
        vm.prank(user);
        uint256[] memory got =
            weighted.exitProportional(burn, user, mins, block.timestamp + 1 hours);
        assertEq(got[0], preview[0]);
        assertEq(got[1], preview[1]);
        assertEq(token0.balanceOf(user) - bal0, got[0]);
        assertEq(token1.balanceOf(user) - bal1, got[1]);
    }

    function test_exitProportional_doesNotDumpDustOnCaller() public {
        uint256 mintShares = _firstMintEqual(100 ether);
        uint256 localBefore = token0.balanceOf(hook);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        assertGt(localBefore, 0, "actual local genesis component");
        uint256[] memory mins = new uint256[](2);
        uint256 userBefore = token0.balanceOf(user);
        vm.prank(user);
        uint256[] memory got =
            weighted.exitProportional(mintShares / 4, user, mins, block.timestamp + 1 hours);
        assertEq(token0.balanceOf(user) - userBefore, got[0], "caller not inflated by dust dump");
        assertEq(token0.balanceOf(hook), localBefore - (mintShares / 4) * localBefore / supplyBefore, "remaining holders retain their local fraction");
    }

    function test_exitSingleAssetExactTokenOut_d42a() public {
        _firstMintEqual(200 ether);
        uint256 amountOut = 5 ether;
        uint256 previewShares = weighted.previewExitSingleAssetExactTokenOut(address(token1), amountOut);
        assertGt(previewShares, 0);

        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 tBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 burned = weighted.exitSingleAssetExactTokenOut(
            address(token1), amountOut, user, type(uint256).max, block.timestamp + 1 hours
        );
        assertEq(burned, previewShares, "D42a preview==exec");
        assertEq(lpBefore - IERC20(hook).balanceOf(user), burned);
        assertEq(token1.balanceOf(user) - tBefore, amountOut);
    }

    function test_withdrawSingle_alias() public {
        uint256 mintShares = _firstMintEqual(100 ether);
        uint256 burn = mintShares / 10;
        uint256 preview = weighted.previewWithdrawSingle(address(token1), burn);
        vm.prank(user);
        uint256 out =
            weighted.withdrawSingle(address(token1), burn, user, 0, block.timestamp + 1 hours);
        assertEq(out, preview);
    }
}
