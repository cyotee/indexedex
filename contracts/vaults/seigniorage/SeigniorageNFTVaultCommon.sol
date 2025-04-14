// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {SeigniorageNFTVaultRepo} from "contracts/vaults/seigniorage/SeigniorageNFTVaultRepo.sol";

/**
 * @title SeigniorageNFTVaultCommon
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Common functionality for Seigniorage NFT Vault operations.
 * @dev Contains shared validation logic and constants.
 *      Core logic for rewards and positions is in SeigniorageNFTVaultRepo.
 */
abstract contract SeigniorageNFTVaultCommon is ISeigniorageNFTVault {
    /* ---------------------------------------------------------------------- */
    /*                          Lock Duration Validation                      */
    /* ---------------------------------------------------------------------- */

    function _bondTerms() internal view returns (BondTerms memory terms_) {
        terms_ = StandardVaultRepo._feeOracle().bondTermsOfVault(address(this));
    }

    /**
     * @notice Validates a lock duration is within acceptable bounds.
     * @param layout_ Storage layout reference
     * @param duration_ Proposed lock duration in seconds
     */
    function _validateLockDuration(SeigniorageNFTVaultRepo.Storage storage layout_, uint256 duration_) internal view {
        layout_;

        BondTerms memory terms = _bondTerms();
        if (duration_ < terms.minLockDuration) {
            revert LockDurationTooShort(duration_, terms.minLockDuration);
        }
        if (duration_ > terms.maxLockDuration) {
            revert LockDurationTooLong(duration_, terms.maxLockDuration);
        }
    }

    function _validateLockDuration(uint256 duration_) internal view {
        _validateLockDuration(SeigniorageNFTVaultRepo._layout(), duration_);
    }
}
