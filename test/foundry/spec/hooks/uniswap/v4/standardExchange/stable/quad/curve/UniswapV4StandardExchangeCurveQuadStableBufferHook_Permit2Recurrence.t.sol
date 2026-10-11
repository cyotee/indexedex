// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_RebasingAwareERC4626 as Matrix} from
    "./UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_RebasingAwareERC4626.t.sol";

/// @notice I5: flexible joins must not credit a truncated Permit2 payment of high-decimal SE shares.
/// @dev Other catalog controls remain in the package's existing adversarial and matrix suites.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_Permit2Recurrence is Matrix {
    function test_I5_flexibleJoinRejectsTruncatedSeShareFunding() public {
        uint256[] memory amounts = new uint256[](4);
        bool[] memory asShares = new bool[](4);
        for (uint256 i; i < 4; ++i) {
            address asset = fxs[i].faceToken();
            address se = fxs[i].se();
            vm.startPrank(user);
            IERC20(asset).approve(se, type(uint256).max);
            amounts[i] = IStandardExchangeIn(se).exchangeIn(
                IERC20(asset), _legUnits(i, 100), IERC20(se), 1, user, false, block.timestamp
            );
            IERC20(se).approve(hook, type(uint256).max);
            vm.stopPrank();
            asShares[i] = true;
        }
        vm.startPrank(user);
        IERC20(seUT).approve(hook, 0);
        IERC20(seUT).approve(PERMIT2_ADDR, type(uint256).max);
        IAllowanceTransfer(PERMIT2_ADDR).approve(seUT, hook, type(uint160).max, type(uint48).max);
        vm.stopPrank();

        uint256 snapshot = vm.snapshotState();
        (uint256 controlQuote,) = quad.previewJoinProportionalFlexible(amounts, asShares);
        assertGt(controlQuote, 0);
        vm.prank(user);
        (uint256 control,) = quad.joinProportionalFlexible(amounts, asShares, user, controlQuote, block.timestamp);
        assertEq(control, controlQuote);
        assertEq(IERC20(seUT).balanceOf(hook), amounts[0], "ordinary Permit2 payment delivered");
        assertTrue(vm.revertToState(snapshot));

        amounts[0] += uint256(1) << 160;
        (uint256 inflatedQuote,) = quad.previewJoinProportionalFlexible(amounts, asShares);
        assertGt(inflatedQuote, controlQuote, "the public quote admits the oversized native share input");
        uint256 payerBefore = IERC20(seUT).balanceOf(user);
        vm.expectRevert(bytes4(keccak256("InvalidTransferAmount()")));
        vm.prank(user);
        quad.joinProportionalFlexible(amounts, asShares, user, 0, block.timestamp);
        assertEq(IERC20(seUT).balanceOf(user), payerBefore, "rejection preserves payer shares");
        assertEq(IERC20(hook).totalSupply(), 0, "rejection cannot issue LP");
        for (uint256 i; i < 4; ++i) {
            assertEq(IERC20(fxs[i].se()).balanceOf(hook), 0, "all leg transfers roll back");
            assertEq(quad.nativeReserve(i), 0, "no phantom inventory is booked");
        }
    }
}
