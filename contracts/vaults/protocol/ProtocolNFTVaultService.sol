// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ProtocolNFTVaultRepo} from "contracts/vaults/protocol/ProtocolNFTVaultRepo.sol";

/**
 * @title ProtocolNFTVaultService
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Stateless service library for Protocol NFT Vault operations.
 * @dev Uses structs to avoid stack-too-deep errors.
 */
library ProtocolNFTVaultService {
    /* ---------------------------------------------------------------------- */
    /*                              Structs                                   */
    /* ---------------------------------------------------------------------- */

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

    /// @notice Parameters for redemption
    struct RedeemParams {
        uint256 tokenId;
        address recipient;
        address caller;
        address protocolDETF;
    }

    /* ---------------------------------------------------------------------- */
    /*                          Harvest Logic                                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Calculates rewards without state modification.
     *      Separates calculation from transfer to reduce stack depth.
     */
    function _calcHarvestRewards(HarvestParams memory params) internal pure returns (HarvestResult memory result) {
        // Early exit if no pending rewards
        if (params.rewardPerShares <= params.paidPerShare) {
            result.hasRewards = false;
            result.rewards = 0;
            return result;
        }

        // Calculate rewards
        result.rewards = (params.effectiveShares * (params.rewardPerShares - params.paidPerShare)) / ONE_WAD;

        result.hasRewards = result.rewards > 0;
    }

    /**
     * @dev Performs the reward transfer. Call after _calcHarvestRewards.
     */
    function _executeHarvestTransfer(
        ProtocolNFTVaultRepo.Storage storage layout_,
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
        (bool success, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Redemption Validation                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Validates redemption caller. Returns true if valid.
     */
    function _validateRedeemCaller(RedeemParams memory params, address owner) internal pure returns (bool) {
        if (owner == params.caller) {
            return true;
        }
        // Allow Protocol DETF to redeem on behalf of holder to holder
        if (params.caller == params.protocolDETF && params.recipient == owner) {
            return true;
        }
        return false;
    }
}
