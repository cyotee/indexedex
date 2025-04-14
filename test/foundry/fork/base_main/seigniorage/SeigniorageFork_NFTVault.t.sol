// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {TestBase_SeigniorageFork} from "test/foundry/fork/base_main/seigniorage/TestBase_SeigniorageFork.sol";

/**
 * @title SeigniorageFork_NFTVault_Test
 * @notice Fork tests for Seigniorage NFT Vault on Base mainnet.
 * @dev Mirrors tests from SeigniorageNFTVault.t.sol but runs against
 *      live Base mainnet Balancer V3 infrastructure.
 *
 *      Key validations:
 *      - NFT minting and burning work correctly
 *      - Lock position tracking
 *      - Bonus multiplier calculations
 *      - Reward distribution
 *      - Access control
 */
contract SeigniorageFork_NFTVault_Test is TestBase_SeigniorageFork {
    /* ---------------------------------------------------------------------- */
    /*                           Helper Functions                             */
    /* ---------------------------------------------------------------------- */

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

    function test_fork_lockShares_mintsNFT() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), alice, "Fork: Alice should own the NFT");
        assertEq(IERC721(address(nftVault)).balanceOf(alice), 1, "Fork: Alice should have 1 NFT");
    }

    function test_fork_lockShares_recordsPosition() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);

        assertEq(info.sharesAwarded, LOCK_AMOUNT, "Fork: Original shares mismatch");
        assertEq(info.unlockTime, block.timestamp + lockDuration, "Fork: Unlock time mismatch");
    }

    function test_fork_lockShares_recordsCorrectShares() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);
        assertEq(info.sharesAwarded, LOCK_AMOUNT, "Fork: Shares should be recorded correctly");

        assertGt(nftVault.totalShares(), 0, "Fork: Total shares should be non-zero after lock");
    }

    function test_fork_lockShares_zeroAmount_reverts() public {
        uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();

        vm.prank(nftVaultOwner);
        vm.expectRevert(ISeigniorageNFTVault.BaseSharesZero.selector);
        nftVault.lockFromDetf(0, bptReserveBefore, 30 days, alice);
    }

    function test_fork_lockShares_multiplePositions() public {
        uint256 lockDuration1 = 30 days;
        uint256 lockDuration2 = 90 days;

        uint256 tokenId1 = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration1);
        uint256 tokenId2 = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration2);

        assertEq(IERC721(address(nftVault)).ownerOf(tokenId1), alice);
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId2), alice);
        assertEq(IERC721(address(nftVault)).balanceOf(alice), 2);

        ISeigniorageNFTVault.LockInfo memory info1 = nftVault.lockInfoOf(tokenId1);
        ISeigniorageNFTVault.LockInfo memory info2 = nftVault.lockInfoOf(tokenId2);
        assertLt(info1.unlockTime, info2.unlockTime);
    }

    function test_fork_lockShares_toRecipient() public {
        uint256 lockDuration = 30 days;

        uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();
        vm.prank(nftVaultOwner);
        uint256 tokenId = nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, lockDuration, bob);
        mockSeigniorageDETF.setLpTokenReserve(bptReserveBefore + LOCK_AMOUNT);

        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), bob);
        assertEq(IERC721(address(nftVault)).balanceOf(bob), 1);

        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);
        assertEq(info.sharesAwarded, LOCK_AMOUNT, "Fork: Shares should be recorded for Bob");
    }

    /* ---------------------------------------------------------------------- */
    /*                      Access Control Tests                              */
    /* ---------------------------------------------------------------------- */

    function test_fork_lockShares_notOwner_reverts() public {
        uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, alice));
        nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, 30 days, alice);
    }

    function test_fork_lockShares_onlyOwnerCanCall() public {
        seigniorageToken.mint(nftVaultOwner, LOCK_AMOUNT);

        uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();
        vm.prank(nftVaultOwner);
        uint256 tokenId = nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, 30 days, alice);
        mockSeigniorageDETF.setLpTokenReserve(bptReserveBefore + LOCK_AMOUNT);

        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), alice);
    }

    /* ---------------------------------------------------------------------- */
    /*                      Bonus Multiplier Tests                            */
    /* ---------------------------------------------------------------------- */

    function test_fork_bonusMultiplier_90days_quadratic() public {
        uint256 lockDuration = 90 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);

        uint256 expectedBonus = _expectedBonusMultiplierFromOracle(lockDuration);
        assertApproxEqRel(info.bonusPercentage, expectedBonus, 0.01e18);
    }

    function test_fork_bonusMultiplier_180days_quadratic() public {
        uint256 lockDuration = 180 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);

        uint256 expectedBonus = _expectedBonusMultiplierFromOracle(lockDuration);
        assertApproxEqRel(info.bonusPercentage, expectedBonus, 0.01e18);
    }

    function testFuzz_fork_bonusMultiplier_scaling(uint256 lockDuration) public {
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

    function test_fork_unlock_returnsOriginalShares() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _warpToUnlock(tokenId);

        vm.prank(alice);
        uint256 lpReturned = nftVault.unlock(tokenId, alice);

        assertEq(lpReturned, LOCK_AMOUNT, "Fork: Should return original locked amount value");
        assertEq(mockSeigniorageDETF.claimedAmounts(alice), LOCK_AMOUNT, "Fork: DETF should have claimed for alice");
    }

    function test_fork_unlock_burnsNFT() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _warpToUnlock(tokenId);

        vm.prank(alice);
        nftVault.unlock(tokenId, alice);

        assertEq(IERC721(address(nftVault)).balanceOf(alice), 0, "Fork: NFT should be burned");
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), address(0), "Fork: Burned NFT should have no owner");
    }

    function test_fork_unlock_beforeUnlock_reverts() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeigniorageNFTVault.LockDurationNotExpired.selector, block.timestamp, info.unlockTime
            )
        );
        nftVault.unlock(tokenId, alice);
    }

    function test_fork_unlock_notOwner_reverts() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _warpToUnlock(tokenId);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ISeigniorageNFTVault.NotBondHolder.selector, alice, bob));
        nftVault.unlock(tokenId, bob);
    }

    function test_fork_unlock_toRecipient() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _warpToUnlock(tokenId);

        vm.prank(alice);
        uint256 lpReturned = nftVault.unlock(tokenId, bob);

        assertEq(mockSeigniorageDETF.claimedAmounts(bob), LOCK_AMOUNT, "Fork: DETF should have claimed for bob");
        assertEq(lpReturned, LOCK_AMOUNT, "Fork: Should return correct liquidity amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                      Reward Distribution Tests                         */
    /* ---------------------------------------------------------------------- */

    function test_fork_rewards_accumulateFromSeigniorage() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _distributeRewards(rewardAmount);

        uint256 pending = nftVault.pendingRewards(tokenId);

        assertGt(pending, 0, "Fork: Should have pending rewards");
    }

    function test_fork_rewards_distributedByEffectiveShares() public {
        uint256 shortLock = 30 days;
        uint256 longLock = _bondTerms().maxLockDuration;
        uint256 rewardAmount = 1000e18;

        uint256 aliceTokenId = _lockSharesForUser(alice, LOCK_AMOUNT, shortLock);
        uint256 bobTokenId = _lockSharesForUser(bob, LOCK_AMOUNT, longLock);

        _distributeRewards(rewardAmount);

        uint256 alicePending = nftVault.pendingRewards(aliceTokenId);
        uint256 bobPending = nftVault.pendingRewards(bobTokenId);

        assertGt(bobPending, alicePending, "Fork: Bob should have more rewards due to longer lock");
    }

    function test_fork_withdrawRewards_claimsPending() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _distributeRewards(rewardAmount);

        uint256 pending = nftVault.pendingRewards(tokenId);
        uint256 aliceRewardsBefore = rewardToken.balanceOf(alice);

        vm.prank(alice);
        uint256 claimed = nftVault.withdrawRewards(tokenId, alice);

        uint256 aliceRewardsAfter = rewardToken.balanceOf(alice);

        assertEq(claimed, pending, "Fork: Claimed should equal pending");
        assertEq(aliceRewardsAfter - aliceRewardsBefore, claimed, "Fork: Alice should receive rewards");
    }

    function test_fork_withdrawRewards_positionUnchanged() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory infoBefore = nftVault.lockInfoOf(tokenId);

        _distributeRewards(rewardAmount);

        vm.prank(alice);
        nftVault.withdrawRewards(tokenId, alice);

        ISeigniorageNFTVault.LockInfo memory infoAfter = nftVault.lockInfoOf(tokenId);

        assertEq(infoAfter.sharesAwarded, infoBefore.sharesAwarded, "Fork: Shares should be unchanged");
        assertEq(infoAfter.unlockTime, infoBefore.unlockTime, "Fork: Unlock time should be unchanged");
        assertEq(infoAfter.bonusPercentage, infoBefore.bonusPercentage, "Fork: Bonus should be unchanged");
    }

    function test_fork_withdrawRewards_notOwner_reverts() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _distributeRewards(1000e18);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ISeigniorageNFTVault.NotBondHolder.selector, alice, bob));
        nftVault.withdrawRewards(tokenId, bob);
    }

    function test_fork_unlock_claimsAllRewards() public {
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

        assertEq(aliceRewardsAfter - aliceRewardsBefore, pending, "Fork: Should receive all pending rewards on unlock");
    }

    /* ---------------------------------------------------------------------- */
    /*                        View Function Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_fork_totalShares_afterMultipleLocks() public {
        uint256 lockDuration1 = 30 days;
        uint256 lockDuration2 = _bondTerms().maxLockDuration;

        _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration1);
        _lockSharesForUser(bob, LOCK_AMOUNT, lockDuration2);

        uint256 totalEffective = nftVault.totalShares();

        assertGt(totalEffective, 0, "Fork: Total shares should be non-zero");
    }

    function test_fork_totalShares_decreasesOnUnlock() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        uint256 totalBefore = nftVault.totalShares();
        assertGt(totalBefore, 0, "Fork: Should have shares before unlock");

        _warpToUnlock(tokenId);

        vm.prank(alice);
        nftVault.unlock(tokenId, alice);

        uint256 totalAfter = nftVault.totalShares();
        assertEq(totalAfter, 0, "Fork: Should have zero shares after unlocking only position");
    }

    /* ---------------------------------------------------------------------- */
    /*                    Fork-Specific Integration Tests                     */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Validates that the NFT vault integrates correctly with mainnet infrastructure.
     */
    function test_fork_mainnetIntegration_fullLifecycle() public {
        uint256 lockDuration = 60 days;
        uint256 rewardAmount = 5000e18;

        // 1. Lock shares
        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), alice, "Fork: Alice should own NFT");

        // 2. Distribute rewards
        _distributeRewards(rewardAmount);

        // 3. Check pending rewards accumulated
        uint256 pending = nftVault.pendingRewards(tokenId);
        assertGt(pending, 0, "Fork: Should have pending rewards");

        // 4. Warp to unlock
        _warpToUnlock(tokenId);

        // 5. Unlock and receive everything
        uint256 aliceRewardsBefore = rewardToken.balanceOf(alice);

        vm.prank(alice);
        uint256 lpReturned = nftVault.unlock(tokenId, alice);

        // 6. Verify final state
        assertEq(lpReturned, LOCK_AMOUNT, "Fork: Should return original shares");
        assertEq(rewardToken.balanceOf(alice) - aliceRewardsBefore, pending, "Fork: Should receive rewards");
        assertEq(IERC721(address(nftVault)).balanceOf(alice), 0, "Fork: NFT should be burned");
        assertEq(nftVault.totalShares(), 0, "Fork: Total shares should be zero");
    }
}
