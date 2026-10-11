// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {TestBase_RebasingAwareERC4626} from "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {ReentrantERC20Harness} from "contracts/test/stubs/ReentrantERC20Harness.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/// @notice R5.3 callback-added self-shares and consumed-credit controls on the production custody proxy.
contract RebasingAwareERC4626_APEX_Recurrence is TestBase_RebasingAwareERC4626 {
    IERC4626 internal callbackVault;
    ReentrantERC20Harness internal callbackAsset;
    uint256 internal callbackShares;
    uint256 internal callbackCount;

    /// @notice Underlying payout callback adds separately held shares after the operation's credit snapshot.
    function addCallbackShares() external {
        require(msg.sender == address(callbackAsset), "only configured underlying");
        ++callbackCount;
        assertTrue(callbackVault.transfer(address(callbackVault), callbackShares), "callback adds shares");
    }

    function _callbackFixture() internal returns (uint256 totalShares, uint256 credit) {
        callbackAsset = new ReentrantERC20Harness("Callback Asset", "CALL", 18);
        callbackVault = pkg.deployVault(IERC20Metadata(address(callbackAsset)), 10, bytes32("recurrence-callback"));
        callbackAsset.mint(address(this), 10 ether);
        callbackAsset.approve(address(callbackVault), 10 ether);
        totalShares = callbackVault.deposit(10 ether, address(this));
        credit = totalShares / 2;
        callbackShares = totalShares / 10;
        callbackVault.transfer(address(callbackVault), credit);
        callbackAsset.setReenter(address(this), abi.encodeCall(this.addCallbackShares, ()));
        callbackAsset.setCallbackOnTransfer(true);
    }

    /// @notice Exact-output refunds only its opening credit; shares added during payout stay at the vault.
    function test_RECURRENCE_B03_callbackAddedSelfShares_exactOutNotRefunded() public {
        (uint256 supply, uint256 credit) = _callbackFixture();
        uint256 callerBefore = callbackVault.balanceOf(address(this));
        uint256 needed = callbackVault.previewWithdraw(2 ether);
        uint256 burned = IStandardExchangeOut(address(callbackVault)).exchangeOut(
            IERC20(address(callbackVault)), credit, IERC20(address(callbackAsset)), 2 ether, bob, true, block.timestamp
        );
        assertEq(callbackCount, 1, "payout callback executed");
        assertEq(burned, needed, "burn exact quote");
        assertEq(callbackVault.totalSupply(), supply - burned, "only quoted shares burned");
        assertEq(callbackVault.balanceOf(address(callbackVault)), callbackShares, "new callback shares not refunded");
        assertEq(callbackVault.balanceOf(address(this)), callerBefore - callbackShares + credit - burned, "refund bounded by opening credit");
        assertEq(callbackAsset.balanceOf(bob), 2 ether, "recipient paid exact output");
    }

    function _callbackExactIn(bool sy) internal {
        (uint256 supply, uint256 credit) = _callbackFixture();
        uint256 burn = credit / 2;
        uint256 expected = callbackVault.previewRedeem(burn);
        uint256 callerBefore = callbackVault.balanceOf(address(this));
        uint256 paid = sy
            ? IStandardizedYield(address(callbackVault)).redeem(bob, burn, address(callbackAsset), 0, true)
            : IStandardExchangeIn(address(callbackVault)).exchangeIn(IERC20(address(callbackVault)), burn, IERC20(address(callbackAsset)), 0, bob, true, block.timestamp);
        assertEq(callbackCount, 1, "payout callback executed");
        assertEq(paid, expected, "preview payout");
        assertEq(callbackVault.totalSupply(), supply - burn, "requested burn only");
        assertEq(callbackVault.balanceOf(address(callbackVault)), credit - burn + callbackShares, "resting plus callback shares retained");
        assertEq(callbackVault.balanceOf(address(this)), callerBefore - callbackShares, "no exact-input refund");
    }

    /// @notice Exact-input SE withdrawal retains callback shares and refunds nothing.
    function test_RECURRENCE_B03_callbackAddedSelfShares_exactInNotRefunded() public { _callbackExactIn(false); }
    /// @notice The SY internal-balance route preserves the same amount-only burn rule.
    function test_RECURRENCE_B03_callbackAddedSelfShares_syNotRefunded() public { _callbackExactIn(true); }

    /// @notice A consumed custody self-share balance cannot fund the next withdrawal.
    function test_RECURRENCE_B03_secondRedemptionCannotReuseConsumedCredit() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(10 ether, alice);
        vm.prank(alice);
        vault.transfer(address(vault), shares);
        IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(vault)), shares, IERC20(address(asset)), 0, bob, true, block.timestamp);
        uint256 recipientBefore = asset.balanceOf(bob);
        assertEq(vault.balanceOf(address(vault)), 0, "first call consumed all credit");
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, shares, 0));
        IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(vault)), shares, IERC20(address(asset)), 0, bob, true, block.timestamp);
        assertEq(asset.balanceOf(bob), recipientBefore, "retry pays nothing");
        assertEq(vault.totalSupply(), 0, "retry creates no supply");
    }
}
