// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_MorphoBlueStandardExchange} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";

/// @notice Checks the share-cap double-floor recurrence on the production Morpho ERC4626 adapter.
contract MorphoBlueStandardExchange_APEX_Recurrence is TestBase_MorphoBlueStandardExchange {
    /// @notice The advertised liquidity cap includes all shares that round into available cash.
    function test_maxRedeem_cashBoundaryAndNextShare() public {
        _wrapExactIn(user, 100 ether);
        _mintLoan(se, 3);
        _borrowFromMarket(2_000 ether, 90 ether);
        uint256 cap = se4626.maxRedeem(user);
        uint256 cash = se4626.maxWithdraw(user);
        assertLt(cap, IERC20(se).balanceOf(user), "borrowed liquidity constrains the owner");
        assertLe(se4626.previewRedeem(cap), cash, "cap fits actual cash");
        assertGt(se4626.previewRedeem(cap + 1), cash, "next share exceeds cash");
        uint256 quote = se4626.previewRedeem(cap);
        uint256 beforeBalance = loanToken.balanceOf(user);
        vm.prank(user);
        assertEq(se4626.redeem(cap, user, user), quote, "advertised cap executes exactly");
        assertEq(loanToken.balanceOf(user) - beforeBalance, quote, "quoted cash delivered");
    }

    /// @notice A full payable share balance must not be reduced by an assets-to-shares round trip.
    function test_RECURRENCE_morphoMaxRedeem_fullPayableBalance() public {
        _wrapExactIn(user, 100 ether);
        _mintLoan(se, 3);
        uint256 fullBalance = IERC20(se).balanceOf(user);
        uint256 advertised = se4626.maxRedeem(user);
        uint256 expected = se4626.previewRedeem(fullBalance);
        uint256 before = loanToken.balanceOf(user);
        vm.prank(user);
        uint256 paid = se4626.redeem(fullBalance, user, user);
        assertEq(paid, expected, "full balance is actually redeemable");
        assertEq(loanToken.balanceOf(user) - before, paid, "full payout delivered");
        assertEq(advertised, fullBalance, "advertise all shares that can be redeemed");
    }
}
