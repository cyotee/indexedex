// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    SeigniorageDETFIntegration_Test
} from "test/foundry/spec/protocol/vaults/seigniorage/SeigniorageDETFIntegration.t.sol";

interface IERC20MintBurnToken is IERC20, IERC20MintBurn {}

/**
 * @title SeigniorageNFTVault_Test
 * @notice Tests for the SeigniorageNFTVault core functionality.
 * @dev Tests lock positions, bonus multipliers, rewards, and unlock operations.
 *      Bond positions are created through the real DETF underwriting flow.
 *      Direct lockFromDetf calls are only used for owner-gated negative-path coverage.
 */
contract SeigniorageNFTVault_Test is SeigniorageDETFIntegration_Test {
    uint256 internal constant LOCK_AMOUNT = 1000e18;

    bool internal reserveVaultSeeded;

    function _nftVault() internal view returns (ISeigniorageNFTVault) {
        return detf.seigniorageNFTVault();
    }

    function _rewardToken() internal view returns (IERC20MintBurnToken) {
        return IERC20MintBurnToken(address(detf.seigniorageToken()));
    }

    function _rateTarget() internal view returns (IERC20) {
        return detf.reserveVaultRateTarget();
    }

    function _bondTerms() internal view returns (BondTerms memory) {
        return IVaultFeeOracleQuery(address(indexedexManager)).bondTermsOfVault(address(_nftVault()));
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

    function _lpReserve() internal view returns (uint256) {
        return IBasicVault(address(detf)).reserveOfToken(detf.reservePool());
    }

    function _lockSharesForUser(address user, uint256 amount, uint256 lockDuration)
        internal
        returns (uint256 tokenId)
    {
        return _lockSharesForUser(user, user, amount, lockDuration);
    }

    function _lockSharesForUser(address payer, address recipient, uint256 amount, uint256 lockDuration)
        internal
        returns (uint256 tokenId)
    {
        if (!reserveVaultSeeded) {
            _mintVaultShares(owner, 1e18);
            reserveVaultSeeded = true;
        }

        uint256 reserveAssetIn = _mintReserveAssetTo(payer, amount);

        vm.startPrank(payer);
        _vaultAsset().approve(address(detf), reserveAssetIn);
        tokenId = detf.underwrite(IERC20(address(_vaultAsset())), reserveAssetIn, lockDuration, recipient, false);
        vm.stopPrank();
    }

    function _distributeRewards(uint256 amount) internal {
        IERC20MintBurnToken rewardToken = _rewardToken();
        ISeigniorageNFTVault nftVault = _nftVault();

        vm.prank(address(detf));
        rewardToken.mint(address(nftVault), amount);
    }

    function _warpToUnlock(uint256 tokenId) internal {
        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);
        vm.warp(info.unlockTime);
    }

    function _expectedUnlockPreview(uint256 tokenId) internal view returns (uint256) {
        uint256 totalShares = _nftVault().totalShares();
        uint256 rewardShares = _nftVault().rewardSharesOf(tokenId);
        uint256 lpAmount = (rewardShares * _lpReserve()) / totalShares;
        return detf.previewClaimLiquidity(lpAmount);
    }

    function _lockFromDetfAsOwner(address recipient, uint256 bptOut, uint256 lockDuration)
        internal
        returns (uint256 tokenId)
    {
        ISeigniorageNFTVault nftVault = _nftVault();
        uint256 bptReserveBefore = _lpReserve();

        vm.prank(address(detf));
        tokenId = nftVault.lockFromDetf(bptOut, bptReserveBefore, lockDuration, recipient);
    }

    /* ---------------------------------------------------------------------- */
    /*                        Lock Position Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_lockShares_mintsNFT() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        // Verify NFT ownership
        assertEq(IERC721(address(_nftVault())).ownerOf(tokenId), alice, "Alice should own the NFT");
        assertEq(IERC721(address(_nftVault())).balanceOf(alice), 1, "Alice should have 1 NFT");
    }

    function test_lockShares_recordsPosition() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);

        // Verify position data
        assertGt(info.sharesAwarded, 0, "Original shares should be non-zero");
        assertEq(info.unlockTime, block.timestamp + lockDuration, "Unlock time mismatch");
    }

    function test_lockShares_recordsCorrectShares() public {
        // In the new architecture, lockShares just records shares - no token transfer.
        // The DETF holds actual BPT; NFT vault just tracks share amounts.
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        // Verify shares are recorded correctly
        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);
        assertGt(info.sharesAwarded, 0, "Shares should be recorded correctly");

        // Verify total shares tracking (totalShares returns effective shares)
        assertGt(_nftVault().totalShares(), 0, "Total shares should be non-zero after lock");
    }

    function test_lockShares_zeroAmount_reverts() public {
        uint256 bptReserveBefore = _lpReserve();
        ISeigniorageNFTVault nftVault = _nftVault();

        vm.prank(address(detf));
        vm.expectRevert(ISeigniorageNFTVault.BaseSharesZero.selector);
        nftVault.lockFromDetf(0, bptReserveBefore, 30 days, alice);
    }

    function test_lockShares_multiplePositions() public {
        uint256 lockDuration1 = 30 days;
        uint256 lockDuration2 = 90 days;

        uint256 tokenId1 = _lockSharesForUser(alice, 100e18, lockDuration1);
        uint256 tokenId2 = _lockFromDetfAsOwner(alice, _lpReserve() / 10, lockDuration2);

        // Verify both NFTs exist
        assertEq(IERC721(address(_nftVault())).ownerOf(tokenId1), alice);
        assertEq(IERC721(address(_nftVault())).ownerOf(tokenId2), alice);
        assertEq(IERC721(address(_nftVault())).balanceOf(alice), 2);

        // Verify different unlock times
        ISeigniorageNFTVault.LockInfo memory info1 = _nftVault().lockInfoOf(tokenId1);
        ISeigniorageNFTVault.LockInfo memory info2 = _nftVault().lockInfoOf(tokenId2);
        assertLt(info1.unlockTime, info2.unlockTime);
    }

    function test_lockShares_toRecipient() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, bob, LOCK_AMOUNT, lockDuration);

        // Bob owns the NFT
        assertEq(IERC721(address(_nftVault())).ownerOf(tokenId), bob);
        assertEq(IERC721(address(_nftVault())).balanceOf(bob), 1);

        // Verify position recorded correctly for Bob
        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);
        assertGt(info.sharesAwarded, 0, "Shares should be recorded for Bob");
    }

    /* ---------------------------------------------------------------------- */
    /*                      Access Control Tests                              */
    /* ---------------------------------------------------------------------- */

    function test_lockShares_notOwner_reverts() public {
        uint256 bptReserveBefore = _lpReserve();
        ISeigniorageNFTVault nftVault = _nftVault();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, alice));
        nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, 30 days, alice);
    }

    function test_lockShares_onlyOwnerCanCall() public {
        uint256 bptReserveBefore = _lpReserve();
        ISeigniorageNFTVault nftVault = _nftVault();

        vm.prank(address(detf));
        uint256 tokenId = nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, 30 days, alice);

        // NFT should be created
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), alice);
    }

    /* ---------------------------------------------------------------------- */
    /*                      Bonus Multiplier Tests                            */
    /* ---------------------------------------------------------------------- */

    function test_bonusMultiplier_1day_base() public {
        BondTerms memory terms = _bondTerms();
        uint256 lockDuration = terms.minLockDuration;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);
        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);

        assertEq(info.bonusPercentage, ONE_WAD + terms.minBonusPercentage);
    }

    function test_bonusMultiplier_90days_quadratic() public {
        uint256 lockDuration = 90 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);

        uint256 expectedBonus = _expectedBonusMultiplierFromOracle(lockDuration);
        assertApproxEqRel(info.bonusPercentage, expectedBonus, 0.01e18);
    }

    function test_bonusMultiplier_180days_quadratic() public {
        uint256 lockDuration = 180 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);

        uint256 expectedBonus = _expectedBonusMultiplierFromOracle(lockDuration);
        assertApproxEqRel(info.bonusPercentage, expectedBonus, 0.01e18);
    }

    function test_bonusMultiplier_365days_max() public {
        BondTerms memory terms = _bondTerms();
        uint256 lockDuration = terms.maxLockDuration;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT / 2, lockDuration);
        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);

        assertEq(info.bonusPercentage, ONE_WAD + terms.maxBonusPercentage);
    }

    function test_bonusMultiplier_over365_reverts() public {
        BondTerms memory terms = _bondTerms();
        uint256 lockDuration = terms.maxLockDuration + 1;

        uint256 bptReserveBefore = _lpReserve();
        ISeigniorageNFTVault nftVault = _nftVault();

        vm.prank(address(detf));
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

        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);

        uint256 minBonus = ONE_WAD + terms.minBonusPercentage;
        uint256 maxBonus = ONE_WAD + terms.maxBonusPercentage;

        assertGe(info.bonusPercentage, minBonus);
        assertLe(info.bonusPercentage, maxBonus);
    }

    /// @notice Wave 3C L1: bonus still in [min,max] when both amount and duration vary.
    function testFuzz_bonusMultiplier_withAmounts(uint256 lockDuration, uint256 amountSeed) public {
        BondTerms memory terms = _bondTerms();
        lockDuration = bound(lockDuration, terms.minLockDuration, terms.maxLockDuration);
        uint256 amount = bound(amountSeed, LOCK_AMOUNT / 10, LOCK_AMOUNT * 2);

        uint256 tokenId = _lockSharesForUser(alice, amount, lockDuration);
        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);

        uint256 minBonus = ONE_WAD + terms.minBonusPercentage;
        uint256 maxBonus = ONE_WAD + terms.maxBonusPercentage;
        assertGe(info.bonusPercentage, minBonus, "P-TIME min bonus");
        assertLe(info.bonusPercentage, maxBonus, "P-TIME max bonus");
        // sharesAwarded is effective (bonus-scaled) BPT claim, not raw input amount.
        assertGe(info.sharesAwarded, amount, "P-CONS awarded >= locked input");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Unlock Tests                                  */
    /* ---------------------------------------------------------------------- */

    function test_unlock_returnsOriginalShares() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);
        uint256 aliceRateTargetBefore = _rateTarget().balanceOf(alice);

        // Warp to unlock time
        _warpToUnlock(tokenId);

        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(alice);
        uint256 lpReturned = nftVault.unlock(tokenId, alice);

        assertGt(lpReturned, 0, "Should return extracted liquidity");
        assertEq(_rateTarget().balanceOf(alice) - aliceRateTargetBefore, lpReturned, "Alice should receive unlock output");
    }

    function test_unlock_burnsNFT() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _warpToUnlock(tokenId);

        ISeigniorageNFTVault nftVault = _nftVault();
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
        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);
        ISeigniorageNFTVault nftVault = _nftVault();

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
        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ISeigniorageNFTVault.NotBondHolder.selector, alice, bob));
        nftVault.unlock(tokenId, bob);
    }

    function test_unlock_toRecipient() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);
        uint256 bobRateTargetBefore = _rateTarget().balanceOf(bob);
        uint256 aliceRateTargetBefore = _rateTarget().balanceOf(alice);

        _warpToUnlock(tokenId);

        // Alice unlocks but specifies Bob as recipient
        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(alice);
        uint256 lpReturned = nftVault.unlock(tokenId, bob);

        assertGt(lpReturned, 0, "Recipient unlock should return liquidity");
        assertEq(_rateTarget().balanceOf(alice), aliceRateTargetBefore, "Alice should not receive rate target output");
        assertEq(_rateTarget().balanceOf(bob) - bobRateTargetBefore, lpReturned, "Bob should receive unlock output");
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
        uint256 pending = _nftVault().pendingRewards(tokenId);

        // Alice should have pending rewards (all rewards since she's only staker)
        assertGt(pending, 0, "Should have pending rewards");
    }

    function test_rewards_distributedByEffectiveShares() public {
        uint256 shortLock = 30 days;
        uint256 longLock = _bondTerms().maxLockDuration;
        uint256 rewardAmount = 1000e18;

        // Alice locks for short duration (lower bonus)
        uint256 aliceTokenId = _lockSharesForUser(alice, 100e18, shortLock);

        // Bob locks for long duration (higher bonus)
        uint256 bobTokenId = _lockFromDetfAsOwner(bob, _lpReserve() / 2, longLock);

        // Distribute rewards
        _distributeRewards(rewardAmount);

        uint256 alicePending = _nftVault().pendingRewards(aliceTokenId);
        uint256 bobPending = _nftVault().pendingRewards(bobTokenId);
        uint256 aliceEffectiveShares = _nftVault().rewardSharesOf(aliceTokenId);
        uint256 bobEffectiveShares = _nftVault().rewardSharesOf(bobTokenId);

        assertApproxEqRel(
            alicePending * bobEffectiveShares,
            bobPending * aliceEffectiveShares,
            0.01e18,
            "Rewards should be distributed in proportion to effective shares"
        );
    }

    function test_withdrawRewards_claimsPending() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _distributeRewards(rewardAmount);

        uint256 pending = _nftVault().pendingRewards(tokenId);
        uint256 aliceRewardsBefore = _rewardToken().balanceOf(alice);

        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(alice);
        uint256 claimed = nftVault.withdrawRewards(tokenId, alice);

        uint256 aliceRewardsAfter = _rewardToken().balanceOf(alice);

        assertEq(claimed, pending, "Claimed should equal pending");
        assertEq(aliceRewardsAfter - aliceRewardsBefore, claimed, "Alice should receive rewards");
    }

    function test_withdrawRewards_positionUnchanged() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory infoBefore = _nftVault().lockInfoOf(tokenId);

        _distributeRewards(rewardAmount);

        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(alice);
        nftVault.withdrawRewards(tokenId, alice);

        ISeigniorageNFTVault.LockInfo memory infoAfter = _nftVault().lockInfoOf(tokenId);

        // Position should be unchanged
        assertEq(infoAfter.sharesAwarded, infoBefore.sharesAwarded, "Shares should be unchanged");
        assertEq(infoAfter.unlockTime, infoBefore.unlockTime, "Unlock time should be unchanged");
        assertEq(infoAfter.bonusPercentage, infoBefore.bonusPercentage, "Bonus should be unchanged");
    }

    function test_withdrawRewards_notOwner_reverts() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _distributeRewards(1000e18);

        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ISeigniorageNFTVault.NotBondHolder.selector, alice, bob));
        nftVault.withdrawRewards(tokenId, bob);
    }

    function test_unlock_claimsAllRewards() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _distributeRewards(rewardAmount);

        uint256 pending = _nftVault().pendingRewards(tokenId);
        uint256 aliceRewardsBefore = _rewardToken().balanceOf(alice);

        _warpToUnlock(tokenId);

        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(alice);
        nftVault.unlock(tokenId, alice);

        uint256 aliceRewardsAfter = _rewardToken().balanceOf(alice);

        // Unlock should also claim pending rewards
        assertEq(aliceRewardsAfter - aliceRewardsBefore, pending, "Should receive all pending rewards on unlock");
    }

    /* ---------------------------------------------------------------------- */
    /*                        View Function Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_totalShares_afterMultipleLocks() public {
        uint256 lockDuration1 = 30 days;
        uint256 lockDuration2 = _bondTerms().maxLockDuration;

        uint256 aliceTokenId = _lockSharesForUser(alice, 100e18, lockDuration1);
        uint256 bobTokenId = _lockFromDetfAsOwner(bob, _lpReserve() / 2, lockDuration2);

        // totalShares() returns effective shares (original * bonus)
        uint256 totalEffective = _nftVault().totalShares();

        ISeigniorageNFTVault.LockInfo memory aliceInfo = _nftVault().lockInfoOf(aliceTokenId);
        ISeigniorageNFTVault.LockInfo memory bobInfo = _nftVault().lockInfoOf(bobTokenId);

        uint256 expectedAlice = _expectedEffectiveSharesFromOracle(aliceInfo.sharesAwarded, lockDuration1);
        uint256 expectedBob = _expectedEffectiveSharesFromOracle(bobInfo.sharesAwarded, lockDuration2);

        assertApproxEqRel(totalEffective, expectedAlice + expectedBob, 0.02e18); // 2% tolerance for rounding
    }

    function test_totalShares_decreasesOnUnlock() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        uint256 totalBefore = _nftVault().totalShares();
        assertGt(totalBefore, 0, "Should have shares before unlock");

        _warpToUnlock(tokenId);

        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(alice);
        nftVault.unlock(tokenId, alice);

        uint256 totalAfter = _nftVault().totalShares();
        assertEq(totalAfter, 0, "Should have zero shares after unlocking only position");
    }
}
