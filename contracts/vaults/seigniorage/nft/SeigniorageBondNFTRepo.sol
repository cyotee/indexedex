// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {MultiStepOwnableRepo} from '@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol';

library SeigniorageBondNFTRepo {
    bytes32 internal constant DEFAULT_SLOT = keccak256("com.indexedex.seigniorage.bond.nft");

    struct Storage {
        uint256 detfOwnedNFTID;
        uint256 totalShares;
        uint256 lastRewardTokenBalance;
        uint256 rewardPerShares;
        /// @notice Original shares allocated to each token ID
        mapping(uint256 tokenId => uint256 originalShares) originalSharesOf;
        /// @notice Boosted shares (including bonus) for each token ID
        mapping(uint256 tokenId => uint256 effectiveShares) effectiveSharesOf;
        /// @notice Bonus multiplier (scaled by 1e18) used when position was created
        mapping(uint256 tokenId => uint256 bonusMultiplier) bonusMultiplierOf;
        /// @notice Unlock timestamp for each token ID
        mapping(uint256 tokenId => uint256 unlockTime) unlockTimeOf;
        /// @notice Reward per share at time of last update for each token ID
        mapping(uint256 tokenId => uint256) userRewardPerSharePaid;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        return _layoutStruct(DEFAULT_SLOT);
    }

    function _detfOwnedNFTID(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.detfOwnedNFTID;
    }

    function _detfOwnedNFTID() internal view returns (uint256) {
        return _detfOwnedNFTID(_layoutStruct());
    }

    /* ---------------------------------------------------------------------- */
    /*                          Reward Calculations                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Updates the global reward per share based on new reward deposits.
     */
    function _updateGlobalRewards(Storage storage layoutStruct_) internal {
        uint256 totalShares_ = layoutStruct_.totalShares;
        if (totalShares_ == 0) {
            return;
        }

        uint256 currentBalance = IERC20(MultiStepOwnableRepo._owner()).balanceOf(address(this));
        uint256 lastBalance = layoutStruct_.lastRewardTokenBalance;

        if (currentBalance > lastBalance) {
            uint256 newRewards = currentBalance - lastBalance;
            layoutStruct_.rewardPerShares += (newRewards * 1e18) / totalShares_;
            layoutStruct_.lastRewardTokenBalance = currentBalance;
        }
    }

    function _createPosition(
        Storage storage layoutStruct_,
        uint256 tokenId_,
        uint256 originalShares_,
        uint256 effectiveShares_,
        uint256 bonusMultiplier_,
        uint256 unlockTime_
    ) internal {
        layoutStruct_.originalSharesOf[tokenId_] = originalShares_;
        layoutStruct_.effectiveSharesOf[tokenId_] = effectiveShares_;
        layoutStruct_.bonusMultiplierOf[tokenId_] = bonusMultiplier_;
        layoutStruct_.unlockTimeOf[tokenId_] = unlockTime_;
        layoutStruct_.userRewardPerSharePaid[tokenId_] = layoutStruct_.rewardPerShares;
        layoutStruct_.totalShares += effectiveShares_;
    }

    function _createPosition(
        uint256 tokenId_,
        uint256 originalShares_,
        uint256 effectiveShares_,
        uint256 bonusMultiplier_,
        uint256 unlockTime_
    ) internal {
        _createPosition(_layoutStruct(), tokenId_, originalShares_, effectiveShares_, bonusMultiplier_, unlockTime_);
    }

}