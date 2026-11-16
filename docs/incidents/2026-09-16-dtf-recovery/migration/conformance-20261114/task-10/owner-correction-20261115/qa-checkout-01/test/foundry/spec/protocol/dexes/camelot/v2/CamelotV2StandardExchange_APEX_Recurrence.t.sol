// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {CamelotV2StandardExchange_InOutInvariant} from "./CamelotV2StandardExchange_InOutInvariant.t.sol";

/// @notice Recurrence verification of exact-output share authorization on the real Camelot package.
contract CamelotV2StandardExchange_APEX_Recurrence is CamelotV2StandardExchange_InOutInvariant {
    /// @notice A successful funded share-to-token control must respect the same caller maximum.
    function test_RECURRENCE_B01_exactOutZapBurnHonorsZeroMaximum() public {
        IERC20 shares = IERC20(address(vault));
        IERC20 output = IERC20(address(tokenA));
        uint256 wanted = 1 ether;
        uint256 quoted = vault.previewExchangeOut(shares, output, wanted);
        assertGt(quoted, 0, "nonzero shares needed");
        uint256 snapshot = vm.snapshotState();
        uint256 sharesBefore = shares.balanceOf(user);
        uint256 outputBefore = output.balanceOf(user);
        vm.prank(user);
        uint256 used = vault.exchangeOut(shares, quoted, output, wanted, user, false, block.timestamp);
        assertEq(sharesBefore - shares.balanceOf(user), used, "positive control burns reported input");
        assertGe(output.balanceOf(user) - outputBefore, wanted, "positive control pays requested output");
        assertTrue(vm.revertToState(snapshot), "restore identical prepared state");
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MaxAmountExceeded.selector, 0, quoted));
        vault.exchangeOut(shares, 0, output, wanted, user, false, block.timestamp);
        assertEq(shares.balanceOf(user), sharesBefore, "maximum rejection preserves caller shares");
        assertEq(output.balanceOf(user), outputBefore, "maximum rejection transfers no output");
    }
}
