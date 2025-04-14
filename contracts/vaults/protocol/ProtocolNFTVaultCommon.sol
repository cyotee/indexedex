// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {ProtocolNFTVaultRepo} from "contracts/vaults/protocol/ProtocolNFTVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";

/**
 * @title ProtocolNFTVaultCommon
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Common functionality for Protocol NFT Vault.
 * @dev Contains shared logic for:
 *      - Lock duration validation
 *      - Bonus multiplier calculation
 *      - Position lookup helpers
 */
abstract contract ProtocolNFTVaultCommon is IProtocolDETFErrors {
    using ProtocolNFTVaultRepo for ProtocolNFTVaultRepo.Storage;

    /* ---------------------------------------------------------------------- */
    /*                          Error Definitions                             */
    /* ---------------------------------------------------------------------- */

    error BaseSharesZero();
    error DeadlineExceeded(uint256 deadline, uint256 currentTimestamp);
    error LockDurationNotExpired(uint256 currentTime, uint256 unlockTime);
    error NotBondHolder(address owner, address caller);
    error LockDurationTooShort(uint256 duration, uint256 minimum);
    error LockDurationTooLong(uint256 duration, uint256 maximum);
    error ProtocolNFTCannotBeUnlocked(uint256 tokenId);
    error ProtocolNFTSold();

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
     * @dev Queries the fee oracle's 3-level fallback chain (vault → type → global).
     * @return terms The current bond terms
     */
    function _bondTerms() internal view returns (BondTerms memory terms) {
        terms = StandardVaultRepo._feeOracle().bondTermsOfVault(address(this));
    }

    /* ---------------------------------------------------------------------- */
    /*                       Lock Duration Validation                         */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Validates that lock duration is within allowed bounds.
     * @param lockDuration_ Duration to validate
     */
    function _validateLockDuration(ProtocolNFTVaultRepo.Storage storage, uint256 lockDuration_) internal view {
        BondTerms memory terms = _bondTerms();

        if (lockDuration_ < terms.minLockDuration) {
            revert LockDurationTooShort(lockDuration_, terms.minLockDuration);
        }

        if (lockDuration_ > terms.maxLockDuration) {
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
        BondTerms memory terms = _bondTerms();

        // Guard against division by zero
        if (terms.maxLockDuration <= terms.minLockDuration) {
            return ONE_WAD + terms.maxBonusPercentage;
        }

        // Normalize duration to 0-1 range (scaled by 1e18)
        uint256 normalized =
            ((lockDuration_ - terms.minLockDuration) * ONE_WAD) / (terms.maxLockDuration - terms.minLockDuration);

        // Apply quadratic curve
        uint256 curveFactor = (normalized * normalized) / ONE_WAD;

        // Calculate bonus within min-max range
        uint256 bonus;
        if (terms.maxBonusPercentage >= terms.minBonusPercentage) {
            bonus = terms.minBonusPercentage + ((terms.maxBonusPercentage - terms.minBonusPercentage) * curveFactor)
                / ONE_WAD;
        } else {
            bonus = terms.maxBonusPercentage;
        }

        // Return 1 + bonus as multiplier
        bonusMultiplier_ = ONE_WAD + bonus;
    }

    /* ---------------------------------------------------------------------- */
    /*                       Position Lookup Helpers                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Gets the position details for a token ID.
     * @param tokenId_ Token ID to query
     * @return position The position data
     */
    function _getPosition(uint256 tokenId_) internal view returns (IProtocolNFTVault.Position memory position) {
        ProtocolNFTVaultRepo.Storage storage layout = ProtocolNFTVaultRepo._layout();

        position.originalShares = layout.originalSharesOf[tokenId_];
        position.effectiveShares = layout.effectiveSharesOf[tokenId_];
        position.bonusMultiplier = layout.bonusMultiplierOf[tokenId_];
        position.unlockTime = layout.unlockTimeOf[tokenId_];
        position.rewardDebt = layout.userRewardPerSharePaid[tokenId_];
    }

    /**
     * @notice Checks if a token ID is the protocol-owned NFT.
     * @param tokenId_ Token ID to check
     * @return True if this is the protocol NFT
     */
    function _isProtocolNFT(uint256 tokenId_) internal view returns (bool) {
        return tokenId_ == ProtocolNFTVaultRepo._protocolNFTId();
    }
}
