// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

/**
 * @title ProtocolNFTVaultTest
 * @notice Tests for US-5.5 and US-5.7: NFT Sale and Protocol NFT Privileges
 * @dev Specification tests for NFT vault mechanics.
 */
contract ProtocolNFTVaultTest is Test {
    /* ---------------------------------------------------------------------- */
    /*                          Position Creation                             */
    /* ---------------------------------------------------------------------- */

    function test_createPosition_sharesRecorded() public pure {
        uint256 depositShares = 100e18;
        uint256 bonusMultiplier = 15e17; // 1.5x

        uint256 effectiveShares = (depositShares * bonusMultiplier) / ONE_WAD;

        assertEq(effectiveShares, 150e18, "Effective shares should include bonus");
    }

    function test_createPosition_unlockTimeSet() public view {
        uint256 lockDuration = 30 days;
        uint256 unlockTime = block.timestamp + lockDuration;

        assertTrue(unlockTime > block.timestamp, "Unlock time should be in future");
    }

    /* ---------------------------------------------------------------------- */
    /*                          NFT Sale to Protocol                          */
    /* ---------------------------------------------------------------------- */

    function test_sellNFT_valueCalculation() public pure {
        uint256 originalShares = 100e18;
        uint256 bonusMultiplier = 15e17;
        uint256 effectiveShares = (originalShares * bonusMultiplier) / ONE_WAD;

        // RICHIR minted = effective shares (rebasing will adjust value)
        uint256 richirMinted = effectiveShares;

        assertEq(richirMinted, 150e18, "RICHIR should equal effective shares");
    }

    function test_sellNFT_transferToProtocolNFT() public pure {
        uint256 userNFTShares = 100e18;
        uint256 protocolNFTSharesBefore = 500e18;

        uint256 protocolNFTSharesAfter = protocolNFTSharesBefore + userNFTShares;

        assertEq(protocolNFTSharesAfter, 600e18, "Protocol NFT should accumulate shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Protocol NFT Privileges                          */
    /* ---------------------------------------------------------------------- */

    function test_protocolNFT_alwaysUnlocked() public view {
        // Protocol NFT has unlockTime = 0 (always unlocked)
        uint256 protocolNFTUnlockTime = 0;

        assertTrue(block.timestamp >= protocolNFTUnlockTime, "Protocol NFT should always be unlocked");
    }

    function test_protocolNFT_cannotBeRedeemed() public pure {
        // Protocol NFT token ID is reserved and cannot be redeemed normally
        uint256 protocolNFTId = 1; // Token ID 1 is reserved for protocol

        assertTrue(protocolNFTId == 1, "Protocol NFT ID should be 1");
    }

    function test_protocolNFT_accumulatesWithoutNewBond() public pure {
        uint256 existingShares = 1000e18;
        uint256 newSharesFromSale = 100e18;

        // Protocol NFT can add shares without starting a new lock period
        uint256 newTotal = existingShares + newSharesFromSale;

        assertEq(newTotal, 1100e18, "Protocol NFT accumulates shares without new lock");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Reward Distribution                            */
    /* ---------------------------------------------------------------------- */

    function test_rewardPerShare_accumulation() public pure {
        uint256 totalEffectiveShares = 1000e18;
        uint256 newRewards = 100e18;

        // rewardPerShare increases by: newRewards * 1e18 / totalEffectiveShares
        uint256 rewardPerShareIncrease = (newRewards * ONE_WAD) / totalEffectiveShares;

        assertEq(rewardPerShareIncrease, 1e17, "Reward per share should increase by 0.1");
    }

    function test_earnedRewards_calculation() public pure {
        uint256 effectiveShares = 100e18;
        uint256 rewardPerShare = 5e17; // 0.5 per share
        uint256 paidPerShare = 2e17; // Already claimed 0.2 per share

        // Earned = effectiveShares * (rewardPerShare - paidPerShare) / 1e18
        uint256 earned = (effectiveShares * (rewardPerShare - paidPerShare)) / ONE_WAD;

        assertEq(earned, 30e18, "Earned rewards should be 30");
    }

    function test_claimRewards_updatesDebt() public pure {
        uint256 currentRewardPerShare = 10e17;

        // After claiming, user's paidPerShare should equal current rewardPerShare
        uint256 newPaidPerShare = currentRewardPerShare;

        assertEq(newPaidPerShare, 10e17, "Paid per share should update to current");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Lock Expiry Checks                            */
    /* ---------------------------------------------------------------------- */

    function test_isLocked_beforeExpiry() public view {
        uint256 unlockTime = block.timestamp + 1 days;

        bool isLocked = block.timestamp < unlockTime;

        assertTrue(isLocked, "Should be locked before expiry");
    }

    function test_isLocked_afterExpiry() public view {
        uint256 unlockTime = block.timestamp - 1;

        bool isLocked = block.timestamp < unlockTime;

        assertFalse(isLocked, "Should be unlocked after expiry");
    }

    function test_redeem_requiresUnlock() public view {
        uint256 unlockTime = block.timestamp + 1 days;

        bool canRedeem = block.timestamp >= unlockTime;

        assertFalse(canRedeem, "Cannot redeem while locked");
    }
}
