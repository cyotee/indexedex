// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFNFTVaultRepo} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultRepo.sol";

/**
 * @title DETFNFTVaultCommon
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Common functionality for Protocol NFT Vault.
 * @dev Contains shared logic for:
 *      - Lock duration validation
 *      - Bonus multiplier calculation
 *      - Position lookup helpers
 */
abstract contract DETFNFTVaultCommon is IDetfErrors {
    using DETFNFTVaultRepo for DETFNFTVaultRepo.Storage;

    /* ---------------------------------------------------------------------- */
    /*                          Error Definitions                             */
    /* ---------------------------------------------------------------------- */

    error BaseSharesZero();
    error DeadlineExceeded(uint256 deadline, uint256 currentTimestamp);
    error LockDurationNotExpired(uint256 currentTime, uint256 unlockTime);
    error NotBondHolder(address owner, address caller);
    error LockDurationTooShort(uint256 duration, uint256 minimum);
    error LockDurationTooLong(uint256 duration, uint256 maximum);
    error DETFNFTCannotBeUnlocked(uint256 tokenId);
    error DETFNFTSold();

    /* ---------------------------------------------------------------------- */
    /*                          Lock Info Struct                              */
    /* ---------------------------------------------------------------------- */

    struct LockInfo {
        uint256 sharesAwarded;
        uint256 rewardPerShare;
        uint256 bonusPercentage;
        uint256 unlockTime;
    }

    /* ---------------------------------------------------------------------- */
    /*                          Bond Terms Helper                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Gets bond terms from the fee oracle via StandardVaultRepo.
     * @dev Queries the fee oracle's 3-level fallback chain (vault -> type -> global).
     * @return terms The current bond terms
     */
    function _bondTerms() internal view returns (BondTerms memory terms) {
        terms = DETFBondNFTMathLib._bondTerms(address(this));
    }

    /* ---------------------------------------------------------------------- */
    /*                       Lock Duration Validation                         */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Validates that lock duration is within allowed bounds.
     * @param lockDuration_ Duration to validate
     */
    function _validateLockDuration(DETFNFTVaultRepo.Storage storage, uint256 lockDuration_) internal view {
        BondTerms memory terms = _bondTerms();
        DETFBondNFTMathLib.LockDurationStatus status = DETFBondNFTMathLib._lockDurationStatus(terms, lockDuration_);

        if (status == DETFBondNFTMathLib.LockDurationStatus.TooShort) {
            revert LockDurationTooShort(lockDuration_, terms.minLockDuration);
        }

        if (status == DETFBondNFTMathLib.LockDurationStatus.TooLong) {
            revert LockDurationTooLong(lockDuration_, terms.maxLockDuration);
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
    function _calcBonusMultiplier(uint256 lockDuration_) internal view returns (uint256 bonusMultiplier_) {
        bonusMultiplier_ = DETFBondNFTMathLib._bonusMultiplierOfVault(address(this), lockDuration_);
    }

    /* ---------------------------------------------------------------------- */
    /*                       Position Lookup Helpers                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Gets the position details for a token ID.
     * @param tokenId_ Token ID to query
     * @return position The position data
     */
    function _getPosition(uint256 tokenId_) internal view returns (IDETFNFTVault.Position memory position) {
        DETFNFTVaultRepo.Storage storage layoutStruct = DETFNFTVaultRepo._layoutStruct();
        position = DETFBondNFTMathLib._position(
            layoutStruct.originalSharesOf[tokenId_],
            layoutStruct.effectiveSharesOf[tokenId_],
            layoutStruct.bonusMultiplierOf[tokenId_],
            layoutStruct.unlockTimeOf[tokenId_],
            layoutStruct.userRewardPerSharePaid[tokenId_]
        );
    }

    /**
     * @notice Checks if a token ID is the protocol-owned NFT.
     * @param tokenId_ Token ID to check
     * @return True if this is the protocol NFT
     */
    function _isDETFNFT(uint256 tokenId_) internal view returns (bool) {
        return tokenId_ == DETFNFTVaultRepo._detfNFTId();
    }
}
