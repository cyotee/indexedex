// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";

library DETFBondNFTMathLib {
    enum LockDurationStatus {
        Valid,
        TooShort,
        TooLong
    }

    function _calcBonusMultiplier(BondTerms memory terms_, uint256 lockDuration_)
        internal
        pure
        returns (uint256 bonusMultiplier_)
    {
        if (terms_.maxLockDuration <= terms_.minLockDuration) {
            return ONE_WAD + terms_.maxBonusPercentage;
        }

        uint256 normalized =
            ((lockDuration_ - terms_.minLockDuration) * ONE_WAD) / (terms_.maxLockDuration - terms_.minLockDuration);
        uint256 curveFactor = (normalized * normalized) / ONE_WAD;

        uint256 bonus;
        if (terms_.maxBonusPercentage >= terms_.minBonusPercentage) {
            bonus = terms_.minBonusPercentage + ((terms_.maxBonusPercentage - terms_.minBonusPercentage) * curveFactor)
                / ONE_WAD;
        } else {
            bonus = terms_.maxBonusPercentage;
        }

        bonusMultiplier_ = ONE_WAD + bonus;
    }

    function _bondTerms(address vault_) internal view returns (BondTerms memory terms_) {
        terms_ = StandardVaultRepo._feeOracle().bondTermsOfVault(vault_);
    }

    function _bonusMultiplierOfVault(address vault_, uint256 lockDuration_)
        internal
        view
        returns (uint256 bonusMultiplier_)
    {
        bonusMultiplier_ = _calcBonusMultiplier(_bondTerms(vault_), lockDuration_);
    }

    function _position(
        uint256 originalShares_,
        uint256 effectiveShares_,
        uint256 bonusMultiplier_,
        uint256 unlockTime_,
        uint256 rewardDebt_
    ) internal pure returns (IDETFNFTVault.Position memory position_) {
        position_ = IDETFNFTVault.Position({
            originalShares: originalShares_,
            effectiveShares: effectiveShares_,
            bonusMultiplier: bonusMultiplier_,
            unlockTime: unlockTime_,
            rewardDebt: rewardDebt_
        });
    }

    function _lockDurationStatus(BondTerms memory terms_, uint256 lockDuration_)
        internal
        pure
        returns (LockDurationStatus status_)
    {
        if (lockDuration_ < terms_.minLockDuration) {
            return LockDurationStatus.TooShort;
        }

        if (lockDuration_ > terms_.maxLockDuration) {
            return LockDurationStatus.TooLong;
        }

        return LockDurationStatus.Valid;
    }

    function _calcHarvestRewards(uint256 effectiveShares_, uint256 rewardPerShares_, uint256 paidPerShare_)
        internal
        pure
        returns (uint256 rewards_, bool hasRewards_)
    {
        if (rewardPerShares_ <= paidPerShare_) {
            return (0, false);
        }

        rewards_ = (effectiveShares_ * (rewardPerShares_ - paidPerShare_)) / ONE_WAD;
        hasRewards_ = rewards_ > 0;
    }

    function _calcEffectiveShares(uint256 shares_, uint256 bonusMultiplier_)
        internal
        pure
        returns (uint256 effectiveShares_)
    {
        effectiveShares_ = (shares_ * bonusMultiplier_) / ONE_WAD;
    }

    function _isDeadlineExceeded(uint256 deadline_, uint256 currentTimestamp_) internal pure returns (bool) {
        return currentTimestamp_ > deadline_;
    }

    function _isUnlockPending(uint256 unlockTime_, uint256 currentTimestamp_) internal pure returns (bool) {
        return currentTimestamp_ < unlockTime_;
    }

    function _isCallerOwner(address owner_, address caller_) internal pure returns (bool) {
        return owner_ == caller_;
    }

    function _validateRedeemCaller(address caller_, address recipient_, address protocolDETF_, address owner_)
        internal
        pure
        returns (bool)
    {
        if (owner_ == caller_) {
            return true;
        }

        if (caller_ == protocolDETF_ && recipient_ == owner_) {
            return true;
        }

        return false;
    }
}