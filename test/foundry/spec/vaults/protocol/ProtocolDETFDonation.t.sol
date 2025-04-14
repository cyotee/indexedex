// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {ProtocolDETFIntegrationBase} from "./ProtocolDETF_IntegrationBase.t.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";

/**
 * @title ProtocolDETFDonation
 * @notice Tests for the Protocol DETF donation flow (IDXEX-018)
 * @dev Verifies:
 *      - WETH donations deposit to vault, add to reserve pool, and credit BPT to protocol NFT
 *      - CHIR donations burn the supply (not transfer)
 *      - Pretransferred flow works correctly for both token types
 *      - Invalid tokens are rejected
 */
contract ProtocolDETFDonation is ProtocolDETFIntegrationBase {
    function _seedChir(address recipient, uint256 amount) internal {
        deal(address(detf), recipient, amount, true);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Test: WETH Donation                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test that WETH donations are deposited to reserve pool and BPT added to protocol NFT
     */
    function test_donate_weth_adds_to_reserve_pool() public {
        uint256 donationAmount = 1_000e18;

        // Get initial state - protocol NFT position's original shares
        uint256 protocolNFTId = protocolNFTVault.protocolNFTId();
        uint256 initialProtocolNFTShares = protocolNFTVault.originalSharesOf(protocolNFTId);
        uint256 initialBptSupply = IERC20(address(reservePool)).totalSupply();

        // Approve and donate WETH
        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), donationAmount);
        IBaseProtocolDETFBonding(address(detf)).donate(IERC20(address(weth9)), donationAmount, false);
        vm.stopPrank();

        // Verify protocol NFT shares increased (BPT was added)
        uint256 finalProtocolNFTShares = protocolNFTVault.originalSharesOf(protocolNFTId);
        assertGt(finalProtocolNFTShares, initialProtocolNFTShares, "Protocol NFT shares should increase");

        // Verify BPT supply increased (new liquidity added to reserve pool)
        uint256 finalBptSupply = IERC20(address(reservePool)).totalSupply();
        assertGt(finalBptSupply, initialBptSupply, "BPT supply should increase from reserve pool deposit");

        // Verify WETH was taken from donor
        assertEq(
            IERC20(address(weth9)).balanceOf(detfAlice),
            1_000_000e18 - donationAmount,
            "WETH should be taken from donor"
        );
    }

    /**
     * @notice Test that WETH donations work with pretransferred flag
     */
    function test_donate_weth_pretransferred() public {
        uint256 donationAmount = 500e18;

        // Get initial state
        uint256 protocolNFTId = protocolNFTVault.protocolNFTId();
        uint256 initialProtocolNFTShares = protocolNFTVault.originalSharesOf(protocolNFTId);

        // Transfer WETH to DETF contract first
        vm.prank(detfAlice);
        IERC20(address(weth9)).transfer(address(detf), donationAmount);

        // Donate with pretransferred = true
        vm.prank(detfAlice);
        IBaseProtocolDETFBonding(address(detf)).donate(IERC20(address(weth9)), donationAmount, true);

        // Verify protocol NFT shares increased
        uint256 finalProtocolNFTShares = protocolNFTVault.originalSharesOf(protocolNFTId);
        assertGt(finalProtocolNFTShares, initialProtocolNFTShares, "Protocol NFT shares should increase");
    }

    /* ---------------------------------------------------------------------- */
    /*                              Test: CHIR Donation                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test that CHIR donations burn the supply
     */
    function test_donate_chir_burns_supply() public {
        uint256 chirAmount = 10_000e18;

        _seedChir(detfAlice, chirAmount);

        // Get initial state
        uint256 initialChirSupply = IERC20(address(detf)).totalSupply();
        uint256 donationAmount = chirAmount / 2;

        // Approve and donate CHIR
        vm.startPrank(detfAlice);
        IERC20(address(detf)).approve(address(detf), donationAmount);
        IBaseProtocolDETFBonding(address(detf)).donate(IERC20(address(detf)), donationAmount, false);
        vm.stopPrank();

        // Verify CHIR was burned (supply decreased)
        uint256 finalChirSupply = IERC20(address(detf)).totalSupply();
        assertEq(finalChirSupply, initialChirSupply - donationAmount, "CHIR supply should decrease by donation amount");

        // Verify CHIR was taken from donor
        assertEq(
            IERC20(address(detf)).balanceOf(detfAlice), chirAmount - donationAmount, "CHIR should be taken from donor"
        );

        // Verify DETF contract doesn't hold the CHIR (it was burned, not transferred)
        // The contract may have some CHIR from other operations, but the donation should not increase it
    }

    /**
     * @notice Test that CHIR donations work with pretransferred flag
     */
    function test_donate_chir_pretransferred() public {
        uint256 chirAmount = 10_000e18;
        uint256 donationAmount = chirAmount / 2;

        _seedChir(detfAlice, chirAmount);

        // Get initial state
        uint256 initialChirSupply = IERC20(address(detf)).totalSupply();

        // Transfer CHIR to DETF contract first
        vm.prank(detfAlice);
        IERC20(address(detf)).transfer(address(detf), donationAmount);

        // Donate with pretransferred = true
        vm.prank(detfAlice);
        IBaseProtocolDETFBonding(address(detf)).donate(IERC20(address(detf)), donationAmount, true);

        // Verify CHIR was burned (supply decreased)
        uint256 finalChirSupply = IERC20(address(detf)).totalSupply();
        assertEq(finalChirSupply, initialChirSupply - donationAmount, "CHIR supply should decrease by donation amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                              Test: Invalid Token                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test that donations revert for invalid tokens
     */
    function test_donate_reverts_invalid_token() public {
        uint256 donationAmount = 1_000e18;

        // Try to donate RICH (invalid token)
        vm.startPrank(detfAlice);
        rich.approve(address(detf), donationAmount);

        vm.expectRevert();
        IBaseProtocolDETFBonding(address(detf)).donate(rich, donationAmount, false);
        vm.stopPrank();
    }

    /**
     * @notice Test that zero amount donations revert
     */
    function test_donate_reverts_zero_amount() public {
        vm.prank(detfAlice);
        vm.expectRevert();
        IBaseProtocolDETFBonding(address(detf)).donate(IERC20(address(weth9)), 0, false);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Test: Fuzz Tests                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Fuzz test for WETH donations
     */
    function testFuzz_donate_weth(uint256 amount) public {
        // Bound amount to reasonable range that fits within pool liquidity constraints
        // The reserve pool has limited liquidity, so large deposits can exceed ratio limits
        amount = bound(amount, 1e18, 10_000e18);

        // Fund Alice with enough WETH
        _mintWeth(detfAlice, amount);

        // Get initial state
        uint256 protocolNFTId = protocolNFTVault.protocolNFTId();
        uint256 initialProtocolNFTShares = protocolNFTVault.originalSharesOf(protocolNFTId);

        // Approve and donate
        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), amount);
        IBaseProtocolDETFBonding(address(detf)).donate(IERC20(address(weth9)), amount, false);
        vm.stopPrank();

        // Verify protocol NFT shares increased
        uint256 finalProtocolNFTShares = protocolNFTVault.originalSharesOf(protocolNFTId);
        assertGt(finalProtocolNFTShares, initialProtocolNFTShares, "Protocol NFT shares should increase");
    }

    /**
     * @notice Fuzz test for CHIR donations
     */
    function testFuzz_donate_chir(uint256 chirAmount) public {
        chirAmount = bound(chirAmount, 1e18, 100_000e18);

        _seedChir(detfAlice, chirAmount);

        // Get initial state
        uint256 initialChirSupply = IERC20(address(detf)).totalSupply();

        // Approve and donate all CHIR
        vm.startPrank(detfAlice);
        IERC20(address(detf)).approve(address(detf), chirAmount);
        IBaseProtocolDETFBonding(address(detf)).donate(IERC20(address(detf)), chirAmount, false);
        vm.stopPrank();

        // Verify CHIR was burned
        uint256 finalChirSupply = IERC20(address(detf)).totalSupply();
        assertEq(finalChirSupply, initialChirSupply - chirAmount, "CHIR supply should decrease by donation amount");
    }
}
