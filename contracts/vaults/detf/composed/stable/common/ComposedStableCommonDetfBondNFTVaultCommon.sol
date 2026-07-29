// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/core/DETFBondNFTMathLib.sol";
import {ComposedStableCommonDetfBondNFTVaultRepo} from "contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultRepo.sol";

abstract contract ComposedStableCommonDetfBondNFTVaultCommon is IDetfErrors {
    using ComposedStableCommonDetfBondNFTVaultRepo for ComposedStableCommonDetfBondNFTVaultRepo.Storage;

    error BaseSharesZero();
    error DeadlineExceeded(uint256 deadline, uint256 currentTimestamp);
    error LockDurationNotExpired(uint256 currentTime, uint256 unlockTime);
    error NotBondHolder(address owner, address caller);
    error LockDurationTooShort(uint256 duration, uint256 minimum);
    error LockDurationTooLong(uint256 duration, uint256 maximum);
    error DETFNFTCannotBeUnlocked(uint256 tokenId);
    error DETFNFTSold();

    struct LockInfo {
        uint256 sharesAwarded;
        uint256 rewardPerShare;
        uint256 bonusPercentage;
        uint256 unlockTime;
    }

    function _bondTerms() internal view returns (BondTerms memory terms) {
        terms = DETFBondNFTMathLib._bondTerms(address(this));
    }

    function _validateLockDuration(ComposedStableCommonDetfBondNFTVaultRepo.Storage storage, uint256 lockDuration_)
        internal
        view
    {
        BondTerms memory terms = _bondTerms();
        DETFBondNFTMathLib.LockDurationStatus status = DETFBondNFTMathLib._lockDurationStatus(terms, lockDuration_);

        if (status == DETFBondNFTMathLib.LockDurationStatus.TooShort) {
            revert LockDurationTooShort(lockDuration_, terms.minLockDuration);
        }

        if (status == DETFBondNFTMathLib.LockDurationStatus.TooLong) {
            revert LockDurationTooLong(lockDuration_, terms.maxLockDuration);
        }
    }

    function _calcBonusMultiplier(uint256 lockDuration_) internal view returns (uint256 bonusMultiplier_) {
        bonusMultiplier_ = DETFBondNFTMathLib._bonusMultiplierOfVault(address(this), lockDuration_);
    }

    function _getPosition(uint256 tokenId_) internal view returns (IDETFNFTVault.Position memory position) {
        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct = ComposedStableCommonDetfBondNFTVaultRepo._layoutStruct();
        position = DETFBondNFTMathLib._position(
            layoutStruct.originalSharesOf[tokenId_],
            layoutStruct.effectiveSharesOf[tokenId_],
            layoutStruct.bonusMultiplierOf[tokenId_],
            layoutStruct.unlockTimeOf[tokenId_],
            layoutStruct.userRewardPerSharePaid[tokenId_]
        );
    }

    function _isDETFNFT(uint256 tokenId_) internal view returns (bool) {
        return tokenId_ == ComposedStableCommonDetfBondNFTVaultRepo._detfNFTId();
    }

    function _isFeeRecipientNFT(uint256 tokenId_) internal view returns (bool) {
        return tokenId_ == ComposedStableCommonDetfBondNFTVaultRepo._feeRecipientNFTId();
    }
}