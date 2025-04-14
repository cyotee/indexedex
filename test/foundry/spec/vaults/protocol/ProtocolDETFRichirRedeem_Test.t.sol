// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {IBaseProtocolDETFRichirRedeem} from "contracts/interfaces/IBaseProtocolDETFRichirRedeem.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {ProtocolDETFIntegrationBase} from "./ProtocolDETF_IntegrationBase.t.sol";

/**
 * @title ProtocolDETFRichirRedeem_Test
 * @notice Tests for the restricted RICHIR→RICH redemption route.
 * 
 * Exchange flow: User bonds RICH → sells NFT for RICHIR → redeems RICHIR for RICH
 * The protocol accumulates RICH from initial deployment and bonding fees.
 */
contract ProtocolDETFRichirRedeem_Test is ProtocolDETFIntegrationBase {
    /* ---------------------------------------------------------------------- */
    /*                         Exchange Tests                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Tests that RICHIR→RICH exchange works when address is allowed
    function test_richir_to_rich_redeem_when_allowed() public {
        // Alice bonds RICH (not WETH) - protocol accumulates more RICH
        // Use 1_000_000e18 (10% of 10M pool) to avoid BPT rounding issues
        uint256 richBondAmount = 1_000_000e18;
        uint256 lockDuration = 30 days;

        vm.startPrank(detfAlice);
        rich.approve(address(detf), richBondAmount);
        (uint256 tokenId,) = IBaseProtocolDETFBonding(address(detf)).bondWithRich(
            richBondAmount, lockDuration, detfAlice, block.timestamp + 1 hours
        );
        vm.stopPrank();

        // Alice sells NFT to get RICHIR
        vm.startPrank(detfAlice);
        IBaseProtocolDETFBonding(address(detf)).sellNFT(tokenId, detfAlice);
        vm.stopPrank();

        uint256 richirBalance = richir.balanceOf(detfAlice);
        assertGt(richirBalance, 0, "Alice should have RICHIR after selling NFT");

        // Owner whitelists Alice
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);
        assertTrue(IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(detfAlice));

        // Alice redeems RICHIR for RICH
        uint256 richBalanceBefore = rich.balanceOf(detfAlice);
        vm.startPrank(detfAlice);
        richir.approve(address(detf), richirBalance);
        uint256 richOut = IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(richir)), richirBalance, rich, 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(richOut, 0, "should receive RICH");
        assertEq(rich.balanceOf(detfAlice), richBalanceBefore + richOut, "RICH should be sent to Alice");
    }

    /// @notice Tests that exchange reverts when sender is not allowed
    function test_richir_to_rich_redeem_reverts_when_not_allowed() public {
        uint256 richBondAmount = 1_000_000e18;
        uint256 lockDuration = 30 days;

        vm.startPrank(detfAlice);
        rich.approve(address(detf), richBondAmount);
        (uint256 tokenId,) = IBaseProtocolDETFBonding(address(detf)).bondWithRich(
            richBondAmount, lockDuration, detfAlice, block.timestamp + 1 hours
        );
        vm.stopPrank();

        vm.startPrank(detfAlice);
        IBaseProtocolDETFBonding(address(detf)).sellNFT(tokenId, detfAlice);
        vm.stopPrank();

        uint256 richirBalance = richir.balanceOf(detfAlice);

        // Alice is NOT whitelisted - should revert
        vm.startPrank(detfAlice);
        richir.approve(address(detf), richirBalance);
        vm.expectRevert(abi.encodeWithSelector(BaseProtocolDETFRepo.NotAllowedRichirRedeem.selector, detfAlice));
        IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(richir)), richirBalance, rich, 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /// @notice Tests that exchange reverts after address is removed
    function test_richir_to_rich_redeem_reverts_after_removal() public {
        uint256 richBondAmount = 1_000_000e18;
        uint256 lockDuration = 30 days;

        vm.startPrank(detfAlice);
        rich.approve(address(detf), richBondAmount);
        (uint256 tokenId,) = IBaseProtocolDETFBonding(address(detf)).bondWithRich(
            richBondAmount, lockDuration, detfAlice, block.timestamp + 1 hours
        );
        vm.stopPrank();

        vm.startPrank(detfAlice);
        IBaseProtocolDETFBonding(address(detf)).sellNFT(tokenId, detfAlice);
        vm.stopPrank();

        uint256 richirBalance = richir.balanceOf(detfAlice);

        // Owner adds then removes Alice
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).removeAllowedRichirRedeemAddress(detfAlice);

        // Alice is no longer whitelisted - should revert
        vm.startPrank(detfAlice);
        richir.approve(address(detf), richirBalance);
        vm.expectRevert(abi.encodeWithSelector(BaseProtocolDETFRepo.NotAllowedRichirRedeem.selector, detfAlice));
        IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(richir)), richirBalance, rich, 0, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /// @notice Tests that RICH is sent to specified recipient
    function test_richir_redeem_sends_to_recipient() public {
        uint256 richBondAmount = 1_000_000e18;
        uint256 lockDuration = 30 days;

        vm.startPrank(detfAlice);
        rich.approve(address(detf), richBondAmount);
        (uint256 tokenId,) = IBaseProtocolDETFBonding(address(detf)).bondWithRich(
            richBondAmount, lockDuration, detfAlice, block.timestamp + 1 hours
        );
        vm.stopPrank();

        vm.startPrank(detfAlice);
        IBaseProtocolDETFBonding(address(detf)).sellNFT(tokenId, detfAlice);
        vm.stopPrank();

        uint256 richirBalance = richir.balanceOf(detfAlice);

        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);

        uint256 richBobBefore = rich.balanceOf(detfBob);
        uint256 richAliceBefore = rich.balanceOf(detfAlice);
        vm.startPrank(detfAlice);
        richir.approve(address(detf), richirBalance);
        IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(richir)), richirBalance, rich, 0, detfBob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(rich.balanceOf(detfBob), richBobBefore, "detfBob should receive RICH");
        assertEq(rich.balanceOf(detfAlice), richAliceBefore, "detfAlice should NOT receive RICH");
    }

    /// @notice Tests that slippage is respected
    function test_richir_redeem_slippage_respected() public {
        uint256 richBondAmount = 1_000_000e18;
        uint256 lockDuration = 30 days;

        vm.startPrank(detfAlice);
        rich.approve(address(detf), richBondAmount);
        (uint256 tokenId,) = IBaseProtocolDETFBonding(address(detf)).bondWithRich(
            richBondAmount, lockDuration, detfAlice, block.timestamp + 1 hours
        );
        vm.stopPrank();

        vm.startPrank(detfAlice);
        IBaseProtocolDETFBonding(address(detf)).sellNFT(tokenId, detfAlice);
        vm.stopPrank();

        uint256 richirBalance = richir.balanceOf(detfAlice);

        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);

        vm.startPrank(detfAlice);
        richir.approve(address(detf), richirBalance);
        (bool success, bytes memory revertData) = address(detf).call(
            abi.encodeCall(
                IStandardExchangeIn.exchangeIn,
                (IERC20(address(richir)), richirBalance, rich, type(uint256).max, detfAlice, false, block.timestamp + 1 hours)
            )
        );
        vm.stopPrank();

        assertFalse(success, "exchangeIn should revert on excessive minAmountOut");

        bytes4 revertSelector;
        assembly {
            revertSelector := mload(add(revertData, 32))
        }
        assertEq(revertSelector, IProtocolDETFErrors.SlippageExceeded.selector, "should revert with SlippageExceeded");
    }

    /// @notice Tests that deadline is respected
    function test_richir_redeem_deadline_respected() public {
        uint256 richBondAmount = 1_000_000e18;
        uint256 lockDuration = 30 days;

        vm.startPrank(detfAlice);
        rich.approve(address(detf), richBondAmount);
        (uint256 tokenId,) = IBaseProtocolDETFBonding(address(detf)).bondWithRich(
            richBondAmount, lockDuration, detfAlice, block.timestamp + 1 hours
        );
        vm.stopPrank();

        vm.startPrank(detfAlice);
        IBaseProtocolDETFBonding(address(detf)).sellNFT(tokenId, detfAlice);
        vm.stopPrank();

        uint256 richirBalance = richir.balanceOf(detfAlice);

        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);

        vm.startPrank(detfAlice);
        richir.approve(address(detf), richirBalance);
        vm.expectRevert();
        IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(richir)), richirBalance, rich, 0, detfAlice, false, block.timestamp - 1
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Admin Function Tests                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Tests that owner can add an allowed address
    function test_addAllowedAddress_byOwner_succeeds() public {
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);
        assertTrue(
            IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(detfAlice),
            "detfAlice should be allowed after owner adds"
        );
    }

    /// @notice Tests that owner can add multiple addresses
    function test_addAllowedAddress_multipleAddresses() public {
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfBob);
        
        assertTrue(
            IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(detfAlice),
            "detfAlice should be allowed"
        );
        assertTrue(
            IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(detfBob),
            "detfBob should be allowed"
        );
    }

    /// @notice Tests that random address cannot add allowed addresses
    function test_addAllowedAddress_byRandom_fails() public {
        vm.prank(detfAlice);
        vm.expectRevert();
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfBob);
    }

    /// @notice Tests that owner can remove an allowed address
    function test_removeAllowedAddress_byOwner_succeeds() public {
        // First add
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);
        assertTrue(
            IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(detfAlice),
            "detfAlice should be allowed initially"
        );

        // Then remove
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).removeAllowedRichirRedeemAddress(detfAlice);
        assertFalse(
            IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(detfAlice),
            "detfAlice should be removed after owner removes"
        );
    }

    /// @notice Tests that random address cannot remove allowed addresses
    function test_removeAllowedAddress_byRandom_fails() public {
        // First add as owner
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);

        // Try to remove as non-owner
        vm.prank(detfAlice);
        vm.expectRevert();
        IBaseProtocolDETFRichirRedeem(address(detf)).removeAllowedRichirRedeemAddress(detfAlice);
    }

    /// @notice Tests that isAllowedRichirRedeemAddress returns correct values
    function test_isAllowedAddress_returnsCorrectValue() public {
        // Initially false
        assertFalse(
            IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(detfAlice),
            "detfAlice should not be allowed initially"
        );
        assertFalse(
            IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(address(0)),
            "zero address should not be allowed"
        );

        // Add detfAlice
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).addAllowedRichirRedeemAddress(detfAlice);
        assertTrue(
            IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(detfAlice),
            "detfAlice should be allowed after adding"
        );
        assertFalse(
            IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(detfBob),
            "detfBob should still not be allowed"
        );

        // Remove detfAlice
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).removeAllowedRichirRedeemAddress(detfAlice);
        assertFalse(
            IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(detfAlice),
            "detfAlice should not be allowed after removal"
        );
    }

    /// @notice Tests that removing non-existent address succeeds silently
    function test_removeAllowedAddress_nonExistent_succeeds() public {
        // Should not revert even if address was never added
        vm.prank(owner);
        IBaseProtocolDETFRichirRedeem(address(detf)).removeAllowedRichirRedeemAddress(detfBob);
        // If we get here, the function handled it gracefully
        assertFalse(
            IBaseProtocolDETFRichirRedeem(address(detf)).isAllowedRichirRedeemAddress(detfBob),
            "detfBob should not be allowed"
        );
    }
}
