// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFSafeTransferLib} from "contracts/vaults/detf/common/core/DETFSafeTransferLib.sol";
import {DETFNFTVaultRepo} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultRepo.sol";

/**
 * @title DETFNFTVaultService
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Stateless service library for Protocol NFT Vault operations.
 * @dev Uses structs to avoid stack-too-deep errors.
 */
library DETFNFTVaultService {
    /* ---------------------------------------------------------------------- */
    /*                              Structs                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Parameters for harvesting rewards (math inputs only; L-STRUCT-2)
    struct HarvestParams {
        uint256 effectiveShares;
        uint256 rewardPerShares;
        uint256 paidPerShare;
    }

    /// @notice Result of harvest calculation
    struct HarvestResult {
        uint256 rewards;
        bool hasRewards;
    }

    /// @notice Parameters for redemption caller validation (L-STRUCT-2: no unused tokenId)
    struct RedeemParams {
        address recipient;
        address caller;
        address detf;
    }

    /* ---------------------------------------------------------------------- */
    /*                          Harvest Logic                                 */
    /* ---------------------------------------------------------------------- */

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
        DETFNFTVaultRepo.Storage storage layout_,
        uint256 tokenId_,
        address recipient_,
        uint256 rewards_
    ) internal {
        // Update paid amount
        layout_.userRewardPerSharePaid[tokenId_] = layout_.rewardPerShares;
        layout_.lastRewardTokenBalance -= rewards_;

        // Safe transfer - using low-level call to avoid stack issues
        _safeTransfer(layout_.rewardToken, recipient_, rewards_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Transfer Helpers                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Safe ERC20 transfer without SafeERC20 library to avoid stack depth.
     */
    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        DETFSafeTransferLib._safeTransfer(token, to, amount);
    }

    /* ---------------------------------------------------------------------- */
    /*                       Redemption Validation                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Validates redemption caller. Returns true if valid.
     */
    function _validateRedeemCaller(RedeemParams memory params, address owner) internal pure returns (bool) {
        return DETFBondNFTMathLib._validateRedeemCaller(params.caller, params.recipient, params.detf, owner);
    }
}
