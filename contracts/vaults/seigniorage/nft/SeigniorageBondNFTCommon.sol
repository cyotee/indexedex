// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {MultiStepOwnableRepo} from '@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol';
import {DETFBondNFTMathLib} from 'contracts/vaults/detf/core/DETFBondNFTMathLib.sol';
import {DETFSafeTransferLib} from 'contracts/vaults/detf/core/DETFSafeTransferLib.sol';
import {ISeigniorageNFTVault} from 'contracts/interfaces/ISeigniorageNFTVault.sol';
import {BondTerms} from 'contracts/interfaces/VaultFeeTypes.sol';
import {SeigniorageBondNFTRepo} from "contracts/vaults/seigniorage/nft/SeigniorageBondNFTRepo.sol";

abstract contract SeigniorageBondNFTCommon {

    error BaseSharesZero();

    /// @notice Parameters for redemption
    struct RedeemParams {
        uint256 tokenId;
        address recipient;
        address caller;
        address protocolDETF;
    }

    /// @notice Parameters for harvesting rewards
    struct HarvestParams {
        uint256 tokenId;
        address recipient;
        uint256 effectiveShares;
        uint256 rewardPerShares;
        uint256 paidPerShare;
    }

    /// @notice Result of harvest calculation
    struct HarvestResult {
        uint256 rewards;
        bool hasRewards;
    }

    /**
     * @notice Gets bond terms from the fee oracle via StandardVaultRepo.
     * @dev Queries the fee oracle's 3-level fallback chain (vault → type → global).
     * @return terms The current bond terms
     */
    function _bondTerms() internal view returns (BondTerms memory terms) {
        terms = DETFBondNFTMathLib._bondTerms(address(this));
    }

    /**
     * @notice Checks if a token ID is the protocol-owned NFT.
     * @param tokenId_ Token ID to check
     * @return True if this is the protocol NFT
     */
    function _isDETFOwnedNFT(uint256 tokenId_) internal view returns (bool) {
        return tokenId_ == SeigniorageBondNFTRepo._detfOwnedNFTID();
    }
    /**
     * @notice Validates that lock duration is within allowed bounds.
     * @param lockDuration_ Duration to validate
     */
    function _validateLockDuration(BondTerms memory terms, uint256 lockDuration_) internal view {
        DETFBondNFTMathLib.LockDurationStatus status = DETFBondNFTMathLib._lockDurationStatus(terms, lockDuration_);

        if (status == DETFBondNFTMathLib.LockDurationStatus.TooShort) {
            revert ISeigniorageNFTVault.LockDurationTooShort(lockDuration_, terms.minLockDuration);
        }

        if (status == DETFBondNFTMathLib.LockDurationStatus.TooLong) {
            revert ISeigniorageNFTVault.LockDurationTooLong(lockDuration_, terms.maxLockDuration);
        }
    }

    /**
     * @notice Calculates bonus multiplier for a given lock duration.
     * @dev Uses quadratic curve: longer locks get exponentially higher bonuses.
     *      bonus = min_bonus + (max_bonus - min_bonus) * (normalized_duration)^2
     *      multiplier = 1 + bonus
     *
     * @param lockDuration_ Lock duration in seconds
     * @return bonusMultiplier_ Multiplier scaled by 1e18 (1e18 = 1x = no bonus)
     */
    function _calcBonusMultiplier(BondTerms memory terms, uint256 lockDuration_) internal view returns (uint256 bonusMultiplier_) {
        bonusMultiplier_ = DETFBondNFTMathLib._calcBonusMultiplier(terms, lockDuration_);
    }

    /**
     * @dev Validates redemption caller. Returns true if valid.
     */
    function _validateRedeemCaller(RedeemParams memory params, address owner) internal pure returns (bool) {
        return DETFBondNFTMathLib._validateRedeemCaller(params.caller, params.recipient, params.protocolDETF, owner);
    }

    /**
     * @dev Internal function to harvest rewards for a position.
     *      Uses service library structs to avoid stack-too-deep.
     */
    function _harvestRewardsInternal(SeigniorageBondNFTRepo.Storage storage layout_, uint256 tokenId_, address recipient_)
        internal
        returns (uint256 rewards_)
    {
        // Build params struct to reduce stack usage
        HarvestParams memory params = HarvestParams({
            tokenId: tokenId_,
            recipient: recipient_,
            effectiveShares: layout_.effectiveSharesOf[tokenId_],
            rewardPerShares: layout_.rewardPerShares,
            paidPerShare: layout_.userRewardPerSharePaid[tokenId_]
        });

        //     // Calculate rewards using service
        HarvestResult memory result = _calcHarvestRewards(params);

        if (!result.hasRewards) {
            return 0;
        }

        rewards_ = result.rewards;

        _executeHarvestTransfer(layout_, tokenId_, recipient_, rewards_);
    }

    /**
     * @dev Calculates rewards without state modification.
     *      Separates calculation from transfer to reduce stack depth.
     */
    function _calcHarvestRewards(HarvestParams memory params) internal pure returns (HarvestResult memory result) {
        (result.rewards, result.hasRewards) = DETFBondNFTMathLib._calcHarvestRewards(
            params.effectiveShares, params.rewardPerShares, params.paidPerShare
        );
    }

    /**
     * @dev Performs the reward transfer. Call after _calcHarvestRewards.
     */
    function _executeHarvestTransfer(
        SeigniorageBondNFTRepo.Storage storage layout_,
        uint256 tokenId_,
        address recipient_,
        uint256 rewards_
    ) internal {
        // Update paid amount
        layout_.userRewardPerSharePaid[tokenId_] = layout_.rewardPerShares;
        layout_.lastRewardTokenBalance -= rewards_;

        // Safe transfer - using low-level call to avoid stack issues
        DETFSafeTransferLib._safeTransfer(IERC20(MultiStepOwnableRepo._owner()), recipient_, rewards_);
    }

}