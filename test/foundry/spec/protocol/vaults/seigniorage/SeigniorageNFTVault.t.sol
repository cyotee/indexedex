// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    TestBase_SeigniorageNFTVault,
    MockSeigniorageDETF
} from "contracts/vaults/seigniorage/TestBase_SeigniorageNFTVault.sol";

/**
 * @title SeigniorageNFTVault_Test
 * @notice Tests for the SeigniorageNFTVault core functionality.
 * @dev Tests lock positions, bonus multipliers, rewards, and unlock operations.
 *      IMPORTANT: lockFromDetf() is onlyOwner - must use _lockSharesForUser() helper
 *      or prank as nftVaultOwner when testing lock operations.
 */
contract SeigniorageNFTVault_Test is TestBase_SeigniorageNFTVault {
    function _bondTerms() internal view returns (BondTerms memory) {
        return IVaultFeeOracleQuery(address(indexedexManager)).bondTermsOfVault(address(nftVault));
    }

    function _expectedBonusMultiplierFromOracle(uint256 lockDuration) internal view returns (uint256) {
        BondTerms memory terms = _bondTerms();

        if (lockDuration <= terms.minLockDuration) {
            return ONE_WAD + terms.minBonusPercentage;
        }
        if (lockDuration >= terms.maxLockDuration) {
            return ONE_WAD + terms.maxBonusPercentage;
        }

        uint256 normalizedDuration =
            ((lockDuration - terms.minLockDuration) * ONE_WAD) / (terms.maxLockDuration - terms.minLockDuration);
        uint256 quadraticDuration = (normalizedDuration * normalizedDuration) / ONE_WAD;
        uint256 bonusRange = terms.maxBonusPercentage - terms.minBonusPercentage;
        uint256 bonusPercentage = terms.minBonusPercentage + (bonusRange * quadraticDuration) / ONE_WAD;
        return ONE_WAD + bonusPercentage;
    }

    function _expectedEffectiveSharesFromOracle(uint256 originalShares, uint256 lockDuration)
        internal
        view
        returns (uint256)
    {
        return (originalShares * _expectedBonusMultiplierFromOracle(lockDuration)) / ONE_WAD;
    }

    /* ---------------------------------------------------------------------- */
    /*                        Lock Position Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_lockShares_mintsNFT() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        // Verify NFT ownership
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), alice, "Alice should own the NFT");
        assertEq(IERC721(address(nftVault)).balanceOf(alice), 1, "Alice should have 1 NFT");
    }

    function test_lockShares_recordsPosition() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);

        // Verify position data
        assertEq(info.sharesAwarded, LOCK_AMOUNT, "Original shares mismatch");
        assertEq(info.unlockTime, block.timestamp + lockDuration, "Unlock time mismatch");
    }

    function test_lockShares_recordsCorrectShares() public {
        // In the new architecture, lockShares just records shares - no token transfer.
        // The DETF holds actual BPT; NFT vault just tracks share amounts.
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        // Verify shares are recorded correctly
        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);
        assertEq(info.sharesAwarded, LOCK_AMOUNT, "Shares should be recorded correctly");

        // Verify total shares tracking (totalShares returns effective shares)
        assertGt(nftVault.totalShares(), 0, "Total shares should be non-zero after lock");
    }

    function test_lockShares_zeroAmount_reverts() public {
        // Owner tries to lock zero amount - should revert
        // Cache lpTokenReserve before expectRevert to avoid it being tested
        uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();

        vm.prank(nftVaultOwner);
        vm.expectRevert(ISeigniorageNFTVault.BaseSharesZero.selector);
        nftVault.lockFromDetf(0, bptReserveBefore, 30 days, alice);
    }

    function test_lockShares_multiplePositions() public {
        uint256 lockDuration1 = 30 days;
        uint256 lockDuration2 = 90 days;

        uint256 tokenId1 = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration1);
        uint256 tokenId2 = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration2);

        // Verify both NFTs exist
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId1), alice);
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId2), alice);
        assertEq(IERC721(address(nftVault)).balanceOf(alice), 2);

        // Verify different unlock times
        ISeigniorageNFTVault.LockInfo memory info1 = nftVault.lockInfoOf(tokenId1);
        ISeigniorageNFTVault.LockInfo memory info2 = nftVault.lockInfoOf(tokenId2);
        assertLt(info1.unlockTime, info2.unlockTime);
    }

    function test_lockShares_toRecipient() public {
        // In the new architecture, lockShares just records shares for the recipient.
        // No token transfer happens - DETF holds the actual BPT.
        uint256 lockDuration = 30 days;

        // Owner (DETF) locks shares with Bob as recipient
        uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();
        vm.prank(nftVaultOwner);
        uint256 tokenId = nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, lockDuration, bob);
        mockSeigniorageDETF.setLpTokenReserve(bptReserveBefore + LOCK_AMOUNT);

        // Bob owns the NFT
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), bob);
        assertEq(IERC721(address(nftVault)).balanceOf(bob), 1);

        // Verify position recorded correctly for Bob
        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);
        assertEq(info.sharesAwarded, LOCK_AMOUNT, "Shares should be recorded for Bob");
    }

    /* ---------------------------------------------------------------------- */
    /*                      Access Control Tests                              */
    /* ---------------------------------------------------------------------- */

    function test_lockShares_notOwner_reverts() public {
        // Alice tries to lock directly - should revert with NotOwner
        // Cache lpTokenReserve before expectRevert to avoid it being tested
        uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, alice));
        nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, 30 days, alice);
    }

    function test_lockShares_onlyOwnerCanCall() public {
        // Verify that only owner (nftVaultOwner) can call lockShares
        // First, give owner some tokens
        claimToken.mint(nftVaultOwner, LOCK_AMOUNT);

        uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();
        vm.prank(nftVaultOwner);
        uint256 tokenId = nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, 30 days, alice);
        mockSeigniorageDETF.setLpTokenReserve(bptReserveBefore + LOCK_AMOUNT);

        // NFT should be created
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), alice);
    }

    /* ---------------------------------------------------------------------- */
    /*                      Bonus Multiplier Tests                            */
    /* ---------------------------------------------------------------------- */

    function test_bonusMultiplier_1day_base() public {
        uint256 lockDuration = 1 days;

        BondTerms memory terms = _bondTerms();

        uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();
        vm.prank(nftVaultOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeigniorageNFTVault.LockDurationTooShort.selector, lockDuration, terms.minLockDuration
            )
        );
        nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, lockDuration, alice);
    }

    function test_bonusMultiplier_90days_quadratic() public {
        uint256 lockDuration = 90 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);

        uint256 expectedBonus = _expectedBonusMultiplierFromOracle(lockDuration);
        assertApproxEqRel(info.bonusPercentage, expectedBonus, 0.01e18);
    }

    function test_bonusMultiplier_180days_quadratic() public {
        uint256 lockDuration = 180 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);

        uint256 expectedBonus = _expectedBonusMultiplierFromOracle(lockDuration);
        assertApproxEqRel(info.bonusPercentage, expectedBonus, 0.01e18);
    }

    function test_bonusMultiplier_365days_max() public {
        uint256 lockDuration = 365 days;

        BondTerms memory terms = _bondTerms();

        uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();
        vm.prank(nftVaultOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeigniorageNFTVault.LockDurationTooLong.selector, lockDuration, terms.maxLockDuration
            )
        );
        nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, lockDuration, alice);
    }

    function test_bonusMultiplier_over365_reverts() public {
        // Lock for longer than max - should revert (owner calls)
        uint256 lockDuration = 500 days;

        BondTerms memory terms = _bondTerms();

        // Give owner tokens first
        claimToken.mint(nftVaultOwner, LOCK_AMOUNT);

        // Cache lpTokenReserve before expectRevert to avoid it being tested
        uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();

        vm.prank(nftVaultOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeigniorageNFTVault.LockDurationTooLong.selector, lockDuration, terms.maxLockDuration
            )
        );
        nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, lockDuration, alice);
    }

    function testFuzz_bonusMultiplier_scaling(uint256 lockDuration) public {
        BondTerms memory terms = _bondTerms();
        lockDuration = bound(lockDuration, terms.minLockDuration, terms.maxLockDuration);

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);

        uint256 minBonus = ONE_WAD + terms.minBonusPercentage;
        uint256 maxBonus = ONE_WAD + terms.maxBonusPercentage;

        assertGe(info.bonusPercentage, minBonus);
        assertLe(info.bonusPercentage, maxBonus);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Unlock Tests                                  */
    /* ---------------------------------------------------------------------- */

    function test_unlock_returnsOriginalShares() public {
        // In the new architecture, unlock calls DETF.claimLiquidity() which
        // extracts value from the 80/20 pool and sends to recipient.
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        // Warp to unlock time
        _warpToUnlock(tokenId);

        vm.prank(alice);
        uint256 lpReturned = nftVault.unlock(tokenId, alice);

        // Should return original shares worth of extracted liquidity
        assertEq(lpReturned, LOCK_AMOUNT, "Should return original locked amount value");

        // Verify claimLiquidity was called with correct params (check mock tracking)
        assertEq(mockSeigniorageDETF.claimedAmounts(alice), LOCK_AMOUNT, "DETF should have claimed for alice");
    }

    function test_unlock_burnsNFT() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _warpToUnlock(tokenId);

        vm.prank(alice);
        nftVault.unlock(tokenId, alice);

        // NFT should be burned - balance should be 0
        assertEq(IERC721(address(nftVault)).balanceOf(alice), 0, "NFT should be burned");

        // ownerOf returns address(0) for burned tokens in Crane's ERC721
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), address(0), "Burned NFT should have no owner");
    }

    function test_unlock_beforeUnlock_reverts() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        // Try to unlock before unlock time
        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeigniorageNFTVault.LockDurationNotExpired.selector, block.timestamp, info.unlockTime
            )
        );
        nftVault.unlock(tokenId, alice);
    }

    function test_unlock_notOwner_reverts() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _warpToUnlock(tokenId);

        // Bob tries to unlock Alice's position
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ISeigniorageNFTVault.NotBondHolder.selector, alice, bob));
        nftVault.unlock(tokenId, bob);
    }

    function test_unlock_toRecipient() public {
        // In the new architecture, unlock calls DETF.claimLiquidity() with the recipient.
        // The DETF extracts value from the pool and sends to the specified recipient.
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _warpToUnlock(tokenId);

        // Alice unlocks but specifies Bob as recipient
        vm.prank(alice);
        uint256 lpReturned = nftVault.unlock(tokenId, bob);

        // Verify claimLiquidity was called with Bob as recipient
        assertEq(mockSeigniorageDETF.claimedAmounts(bob), LOCK_AMOUNT, "DETF should have claimed for bob");
        assertEq(lpReturned, LOCK_AMOUNT, "Should return correct liquidity amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                      Reward Distribution Tests                         */
    /* ---------------------------------------------------------------------- */

    function test_rewards_accumulateFromSeigniorage() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        // Alice locks shares via owner
        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        // Distribute rewards to vault
        _distributeRewards(rewardAmount);

        // Check pending rewards
        uint256 pending = nftVault.pendingRewards(tokenId);

        // Alice should have pending rewards (all rewards since she's only staker)
        assertGt(pending, 0, "Should have pending rewards");
    }

    function test_rewards_distributedByEffectiveShares() public {
        uint256 shortLock = 30 days;
        uint256 longLock = _bondTerms().maxLockDuration;
        uint256 rewardAmount = 1000e18;

        // Alice locks for short duration (lower bonus)
        uint256 aliceTokenId = _lockSharesForUser(alice, LOCK_AMOUNT, shortLock);

        // Bob locks for long duration (higher bonus)
        uint256 bobTokenId = _lockSharesForUser(bob, LOCK_AMOUNT, longLock);

        // Distribute rewards
        _distributeRewards(rewardAmount);

        uint256 alicePending = nftVault.pendingRewards(aliceTokenId);
        uint256 bobPending = nftVault.pendingRewards(bobTokenId);

        // Bob should have more rewards due to higher effective shares
        assertGt(bobPending, alicePending, "Bob should have more rewards due to longer lock");
    }

    function test_withdrawRewards_claimsPending() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _distributeRewards(rewardAmount);

        uint256 pending = nftVault.pendingRewards(tokenId);
        uint256 aliceRewardsBefore = rewardToken.balanceOf(alice);

        vm.prank(alice);
        uint256 claimed = nftVault.withdrawRewards(tokenId, alice);

        uint256 aliceRewardsAfter = rewardToken.balanceOf(alice);

        assertEq(claimed, pending, "Claimed should equal pending");
        assertEq(aliceRewardsAfter - aliceRewardsBefore, claimed, "Alice should receive rewards");
    }

    function test_withdrawRewards_positionUnchanged() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory infoBefore = nftVault.lockInfoOf(tokenId);

        _distributeRewards(rewardAmount);

        vm.prank(alice);
        nftVault.withdrawRewards(tokenId, alice);

        ISeigniorageNFTVault.LockInfo memory infoAfter = nftVault.lockInfoOf(tokenId);

        // Position should be unchanged
        assertEq(infoAfter.sharesAwarded, infoBefore.sharesAwarded, "Shares should be unchanged");
        assertEq(infoAfter.unlockTime, infoBefore.unlockTime, "Unlock time should be unchanged");
        assertEq(infoAfter.bonusPercentage, infoBefore.bonusPercentage, "Bonus should be unchanged");
    }

    function test_withdrawRewards_notOwner_reverts() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _distributeRewards(1000e18);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ISeigniorageNFTVault.NotBondHolder.selector, alice, bob));
        nftVault.withdrawRewards(tokenId, bob);
    }

    function test_unlock_claimsAllRewards() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _distributeRewards(rewardAmount);

        uint256 pending = nftVault.pendingRewards(tokenId);
        uint256 aliceRewardsBefore = rewardToken.balanceOf(alice);

        _warpToUnlock(tokenId);

        vm.prank(alice);
        nftVault.unlock(tokenId, alice);

        uint256 aliceRewardsAfter = rewardToken.balanceOf(alice);

        // Unlock should also claim pending rewards
        assertEq(aliceRewardsAfter - aliceRewardsBefore, pending, "Should receive all pending rewards on unlock");
    }

    /* ---------------------------------------------------------------------- */
    /*                        View Function Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_totalShares_afterMultipleLocks() public {
        uint256 lockDuration1 = 30 days;
        uint256 lockDuration2 = _bondTerms().maxLockDuration;

        _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration1);
        _lockSharesForUser(bob, LOCK_AMOUNT, lockDuration2);

        // totalShares() returns effective shares (original * bonus)
        uint256 totalEffective = nftVault.totalShares();

        // Alice's effective shares (first deposit is 1:1)
        uint256 expectedAlice = _expectedEffectiveSharesFromOracle(LOCK_AMOUNT, lockDuration1);

        // Bob's originalShares are priced against existing shares:
        // originalShares = bptOut * totalShares / bptReserveBefore
        // Since Alice deposited LOCK_AMOUNT BPT and got effectiveAlice shares,
        // Bob's bptReserveBefore = LOCK_AMOUNT, totalShares = effectiveAlice
        // So Bob's originalShares = LOCK_AMOUNT * effectiveAlice / LOCK_AMOUNT = effectiveAlice
        uint256 bobOriginalShares = expectedAlice; // Priced against Alice's position
        uint256 expectedBob = _expectedEffectiveSharesFromOracle(bobOriginalShares, lockDuration2);

        assertApproxEqRel(totalEffective, expectedAlice + expectedBob, 0.02e18); // 2% tolerance for rounding
    }

    function test_totalShares_decreasesOnUnlock() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        uint256 totalBefore = nftVault.totalShares();
        assertGt(totalBefore, 0, "Should have shares before unlock");

        _warpToUnlock(tokenId);

        vm.prank(alice);
        nftVault.unlock(tokenId, alice);

        uint256 totalAfter = nftVault.totalShares();
        assertEq(totalAfter, 0, "Should have zero shares after unlocking only position");
    }
}
