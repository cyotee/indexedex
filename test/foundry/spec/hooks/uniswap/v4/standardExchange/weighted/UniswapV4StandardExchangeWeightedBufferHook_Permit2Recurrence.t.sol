// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4StandardExchangeWeightedBufferHook} from
    "./TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {UniswapV4StandardExchangeWeightedBufferHookPullLib} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPullLib.sol";

/// @notice Production-proxy diagnostic: Permit2 narrowing must not inflate raw-leg accounting.
contract UniswapV4StandardExchangeWeightedBufferHook_Permit2Recurrence is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function test_recurrence_SeWeightedPermit2BooksOnlyDeliveredRawAmounts() public {
        vm.startPrank(user);
        token1.approve(hook, 0);
        token1.approve(PERMIT2_ADDR, type(uint256).max);
        IAllowanceTransfer(PERMIT2_ADDR).approve(address(token1), hook, type(uint160).max, type(uint48).max);
        vm.stopPrank();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;
        uint256 snapshot = vm.snapshotState();
        vm.prank(user);
        (uint256 control,) = weighted.joinProportional(amounts, user, 0, block.timestamp);
        assertGt(control, 0, "ordinary Permit2 raw-leg funding is live");
        assertEq(weighted.nativeReserves()[1], token1.balanceOf(hook));
        assertTrue(vm.revertToState(snapshot));
        amounts[1] += uint256(1) << 160;
        (uint256 quoted,) = weighted.previewJoinProportional(amounts);
        assertGt(quoted, 0, "large request reaches an admitted mint quote");
        uint256 payerBefore = token1.balanceOf(user);
        uint256 hookBefore = token1.balanceOf(hook);
        vm.expectRevert(UniswapV4StandardExchangeWeightedBufferHookPullLib.InvalidTransferAmount.selector);
        vm.prank(user);
        weighted.joinProportional(amounts, user, 0, block.timestamp);
        assertEq(token1.balanceOf(user), payerBefore, "failed funding preserves payer balance");
        assertEq(token1.balanceOf(hook), hookBefore, "failed funding preserves hook custody");
        assertEq(weighted.nativeReserves()[1], token1.balanceOf(hook), "raw reserve must equal actual delivery");
    }
}
