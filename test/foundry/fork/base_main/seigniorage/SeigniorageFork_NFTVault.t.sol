// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {TestBase_SeigniorageDETF_Fork} from "test/foundry/fork/base_main/seigniorage/TestBase_SeigniorageDETF_Fork.sol";

interface IERC20MintBurnToken is IERC20, IERC20MintBurn {}

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
contract SeigniorageFork_NFTVault_Test is TestBase_SeigniorageDETF_Fork {
    uint256 internal constant LOCK_AMOUNT = 1000e18;

    bool internal reserveVaultSeeded;

    /* ---------------------------------------------------------------------- */
    /*                           Helper Functions                             */
    /* ---------------------------------------------------------------------- */

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

    function _mintReserveVaultSharesTo(address user, uint256 tokenAmount) internal returns (uint256 sharesOut) {
        uint256 liquidity = _mintReserveAssetTo(user, tokenAmount);
        require(liquidity > 0, "No LP minted");

        vm.startPrank(user);
        _reserveAsset().approve(address(daiUsdcVault), type(uint256).max);
        sharesOut = daiUsdcVault.deposit(liquidity, user);
        vm.stopPrank();
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
            _mintReserveVaultSharesTo(owner, 1e18);
            reserveVaultSeeded = true;
        }

        uint256 reserveAssetIn = _mintReserveAssetTo(payer, amount);

        vm.startPrank(payer);
        _reserveAsset().approve(address(detf), reserveAssetIn);
        tokenId = detf.underwrite(IERC20(address(_reserveAsset())), reserveAssetIn, lockDuration, recipient, false);
        vm.stopPrank();
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

    /* ---------------------------------------------------------------------- */
    /*                        Lock Position Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_fork_lockShares_mintsNFT() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        assertEq(IERC721(address(_nftVault())).ownerOf(tokenId), alice, "Fork: Alice should own the NFT");
        assertEq(IERC721(address(_nftVault())).balanceOf(alice), 1, "Fork: Alice should have 1 NFT");
    }

    function test_fork_lockShares_recordsPosition() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);

        assertGt(info.sharesAwarded, 0, "Fork: Original shares should be non-zero");
        assertEq(info.unlockTime, block.timestamp + lockDuration, "Fork: Unlock time mismatch");
    }

    function test_fork_lockShares_recordsCorrectShares() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);
        assertGt(info.sharesAwarded, 0, "Fork: Shares should be recorded correctly");

        assertGt(_nftVault().totalShares(), 0, "Fork: Total shares should be non-zero after lock");
    }

    function test_fork_lockShares_zeroAmount_reverts() public {
        uint256 bptReserveBefore = _lpReserve();
        ISeigniorageNFTVault nftVault = _nftVault();

        vm.prank(address(detf));
        vm.expectRevert(ISeigniorageNFTVault.BaseSharesZero.selector);
        nftVault.lockFromDetf(0, bptReserveBefore, 30 days, alice);
    }

    function test_fork_lockShares_multiplePositions() public {
        uint256 lockDuration1 = 30 days;
        uint256 lockDuration2 = 90 days;

        uint256 tokenId1 = _lockSharesForUser(alice, 100e18, lockDuration1);
        uint256 tokenId2 = _lockFromDetfAsOwner(alice, _lpReserve() / 10, lockDuration2);

        assertEq(IERC721(address(_nftVault())).ownerOf(tokenId1), alice);
        assertEq(IERC721(address(_nftVault())).ownerOf(tokenId2), alice);
        assertEq(IERC721(address(_nftVault())).balanceOf(alice), 2);

        ISeigniorageNFTVault.LockInfo memory info1 = _nftVault().lockInfoOf(tokenId1);
        ISeigniorageNFTVault.LockInfo memory info2 = _nftVault().lockInfoOf(tokenId2);
        assertLt(info1.unlockTime, info2.unlockTime);
    }

    function test_fork_lockShares_toRecipient() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, bob, LOCK_AMOUNT, lockDuration);

        assertEq(IERC721(address(_nftVault())).ownerOf(tokenId), bob);
        assertEq(IERC721(address(_nftVault())).balanceOf(bob), 1);

        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);
        assertGt(info.sharesAwarded, 0, "Fork: Shares should be recorded for Bob");
    }

    /* ---------------------------------------------------------------------- */
    /*                      Access Control Tests                              */
    /* ---------------------------------------------------------------------- */

    function test_fork_lockShares_notOwner_reverts() public {
        uint256 bptReserveBefore = _lpReserve();
        ISeigniorageNFTVault nftVault = _nftVault();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, alice));
        nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, 30 days, alice);
    }

    function test_fork_lockShares_onlyOwnerCanCall() public {
        uint256 bptReserveBefore = _lpReserve();
        ISeigniorageNFTVault nftVault = _nftVault();

        vm.prank(address(detf));
        uint256 tokenId = nftVault.lockFromDetf(LOCK_AMOUNT, bptReserveBefore, 30 days, alice);

        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), alice);
    }

    /* ---------------------------------------------------------------------- */
    /*                      Bonus Multiplier Tests                            */
    /* ---------------------------------------------------------------------- */

    function test_fork_bonusMultiplier_90days_quadratic() public {
        uint256 lockDuration = 90 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);

        uint256 expectedBonus = _expectedBonusMultiplierFromOracle(lockDuration);
        assertApproxEqRel(info.bonusPercentage, expectedBonus, 0.01e18);
    }

    function test_fork_bonusMultiplier_180days_quadratic() public {
        uint256 lockDuration = 180 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);

        uint256 expectedBonus = _expectedBonusMultiplierFromOracle(lockDuration);
        assertApproxEqRel(info.bonusPercentage, expectedBonus, 0.01e18);
    }

    function testFuzz_fork_bonusMultiplier_scaling(uint256 lockDuration) public {
        BondTerms memory terms = _bondTerms();
        lockDuration = bound(lockDuration, terms.minLockDuration, terms.maxLockDuration);

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory info = _nftVault().lockInfoOf(tokenId);

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
        uint256 aliceRateTargetBefore = _rateTarget().balanceOf(alice);

        _warpToUnlock(tokenId);

        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(alice);
        uint256 lpReturned = nftVault.unlock(tokenId, alice);

        assertGt(lpReturned, 0, "Fork: Should return extracted liquidity");
        assertEq(_rateTarget().balanceOf(alice) - aliceRateTargetBefore, lpReturned, "Fork: Alice should receive unlock output");
    }

    function test_fork_unlock_burnsNFT() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _warpToUnlock(tokenId);

        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(alice);
        nftVault.unlock(tokenId, alice);

        assertEq(IERC721(address(nftVault)).balanceOf(alice), 0, "Fork: NFT should be burned");
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), address(0), "Fork: Burned NFT should have no owner");
    }

    function test_fork_unlock_beforeUnlock_reverts() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

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

    function test_fork_unlock_notOwner_reverts() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _warpToUnlock(tokenId);

        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ISeigniorageNFTVault.NotBondHolder.selector, alice, bob));
        nftVault.unlock(tokenId, bob);
    }

    function test_fork_unlock_toRecipient() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);
        uint256 bobRateTargetBefore = _rateTarget().balanceOf(bob);
        uint256 aliceRateTargetBefore = _rateTarget().balanceOf(alice);

        _warpToUnlock(tokenId);

        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(alice);
        uint256 lpReturned = nftVault.unlock(tokenId, bob);

        assertGt(lpReturned, 0, "Fork: Should return correct liquidity amount");
        assertEq(_rateTarget().balanceOf(alice), aliceRateTargetBefore, "Fork: Alice should not receive rate target output");
        assertEq(_rateTarget().balanceOf(bob) - bobRateTargetBefore, lpReturned, "Fork: Bob should receive unlock output");
    }

    /* ---------------------------------------------------------------------- */
    /*                      Reward Distribution Tests                         */
    /* ---------------------------------------------------------------------- */

    function test_fork_rewards_accumulateFromSeigniorage() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        _distributeRewards(rewardAmount);

        uint256 pending = _nftVault().pendingRewards(tokenId);

        assertGt(pending, 0, "Fork: Should have pending rewards");
    }

    function test_fork_rewards_distributedByEffectiveShares() public {
        uint256 shortLock = 30 days;
        uint256 longLock = _bondTerms().maxLockDuration;
        uint256 rewardAmount = 1000e18;

        uint256 aliceTokenId = _lockSharesForUser(alice, 100e18, shortLock);
        uint256 bobTokenId = _lockFromDetfAsOwner(bob, _lpReserve() / 2, longLock);

        _distributeRewards(rewardAmount);

        uint256 alicePending = _nftVault().pendingRewards(aliceTokenId);
        uint256 bobPending = _nftVault().pendingRewards(bobTokenId);
        uint256 aliceEffectiveShares = _nftVault().rewardSharesOf(aliceTokenId);
        uint256 bobEffectiveShares = _nftVault().rewardSharesOf(bobTokenId);

        assertApproxEqRel(
            alicePending * bobEffectiveShares,
            bobPending * aliceEffectiveShares,
            0.01e18,
            "Fork: Rewards should be distributed in proportion to effective shares"
        );
    }

    function test_fork_withdrawRewards_claimsPending() public {
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

        assertEq(claimed, pending, "Fork: Claimed should equal pending");
        assertEq(aliceRewardsAfter - aliceRewardsBefore, claimed, "Fork: Alice should receive rewards");
    }

    function test_fork_withdrawRewards_positionUnchanged() public {
        uint256 lockDuration = 30 days;
        uint256 rewardAmount = 1000e18;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        ISeigniorageNFTVault.LockInfo memory infoBefore = _nftVault().lockInfoOf(tokenId);

        _distributeRewards(rewardAmount);

        ISeigniorageNFTVault nftVault = _nftVault();
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

        ISeigniorageNFTVault nftVault = _nftVault();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ISeigniorageNFTVault.NotBondHolder.selector, alice, bob));
        nftVault.withdrawRewards(tokenId, bob);
    }

    function test_fork_unlock_claimsAllRewards() public {
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

        assertEq(aliceRewardsAfter - aliceRewardsBefore, pending, "Fork: Should receive all pending rewards on unlock");
    }

    /* ---------------------------------------------------------------------- */
    /*                        View Function Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_fork_totalShares_afterMultipleLocks() public {
        uint256 lockDuration1 = 30 days;
        uint256 lockDuration2 = _bondTerms().maxLockDuration;

        uint256 aliceTokenId = _lockSharesForUser(alice, 100e18, lockDuration1);
        uint256 bobTokenId = _lockFromDetfAsOwner(bob, _lpReserve() / 2, lockDuration2);

        uint256 totalEffective = _nftVault().totalShares();

        ISeigniorageNFTVault.LockInfo memory aliceInfo = _nftVault().lockInfoOf(aliceTokenId);
        ISeigniorageNFTVault.LockInfo memory bobInfo = _nftVault().lockInfoOf(bobTokenId);

        uint256 expectedAlice = _expectedEffectiveSharesFromOracle(aliceInfo.sharesAwarded, lockDuration1);
        uint256 expectedBob = _expectedEffectiveSharesFromOracle(bobInfo.sharesAwarded, lockDuration2);

        assertApproxEqRel(totalEffective, expectedAlice + expectedBob, 0.02e18, "Fork: Total effective shares mismatch");
    }

    function test_fork_totalShares_decreasesOnUnlock() public {
        uint256 lockDuration = 30 days;

        uint256 tokenId = _lockSharesForUser(alice, LOCK_AMOUNT, lockDuration);

        uint256 totalBefore = _nftVault().totalShares();
        assertGt(totalBefore, 0, "Fork: Should have shares before unlock");

        _warpToUnlock(tokenId);

        ISeigniorageNFTVault nftVault = _nftVault();
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
        ISeigniorageNFTVault nftVault = _nftVault();
        assertEq(IERC721(address(nftVault)).ownerOf(tokenId), alice, "Fork: Alice should own NFT");

        // 2. Distribute rewards
        _distributeRewards(rewardAmount);

        // 3. Check pending rewards accumulated
        uint256 pending = nftVault.pendingRewards(tokenId);
        assertGt(pending, 0, "Fork: Should have pending rewards");

        // 4. Warp to unlock
        _warpToUnlock(tokenId);

        // 5. Unlock and receive everything
        uint256 aliceRewardsBefore = _rewardToken().balanceOf(alice);
        uint256 aliceRateTargetBefore = _rateTarget().balanceOf(alice);

        vm.prank(alice);
        uint256 lpReturned = nftVault.unlock(tokenId, alice);

        // 6. Verify final state
        assertGt(lpReturned, 0, "Fork: Should return extracted liquidity");
        assertEq(_rewardToken().balanceOf(alice) - aliceRewardsBefore, pending, "Fork: Should receive rewards");
        assertEq(_rateTarget().balanceOf(alice) - aliceRateTargetBefore, lpReturned, "Fork: Should receive unlock output");
        assertEq(IERC721(address(nftVault)).balanceOf(alice), 0, "Fork: NFT should be burned");
        assertEq(nftVault.totalShares(), 0, "Fork: Total shares should be zero");
    }
}
