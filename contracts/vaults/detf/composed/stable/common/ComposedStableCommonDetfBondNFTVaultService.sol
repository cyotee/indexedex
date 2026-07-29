// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {DETFBondNFTMathLib} from "contracts/vaults/detf/core/DETFBondNFTMathLib.sol";
import {DETFSafeTransferLib} from "contracts/vaults/detf/core/DETFSafeTransferLib.sol";
import {ComposedStableCommonDetfBondNFTVaultRepo} from "contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultRepo.sol";

library ComposedStableCommonDetfBondNFTVaultService {
    struct HarvestParams {
        uint256 tokenId;
        address recipient;
        uint256 effectiveShares;
        uint256 rewardPerShares;
        uint256 paidPerShare;
    }

    struct HarvestResult {
        uint256 rewards;
        bool hasRewards;
    }

    struct RedeemParams {
        uint256 tokenId;
        address recipient;
        address caller;
        address detf;
    }

    function _calcHarvestRewards(HarvestParams memory params) internal pure returns (HarvestResult memory result) {
        (result.rewards, result.hasRewards) = DETFBondNFTMathLib._calcHarvestRewards(
            params.effectiveShares, params.rewardPerShares, params.paidPerShare
        );
    }

    function _executeHarvestTransfer(
        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layout_,
        uint256 tokenId_,
        address recipient_,
        uint256 rewards_
    ) internal {
        layout_.userRewardPerSharePaid[tokenId_] = layout_.rewardPerShares;
        layout_.lastRewardTokenBalance -= rewards_;
        _safeTransfer(layout_.rewardToken, recipient_, rewards_);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        DETFSafeTransferLib._safeTransfer(token, to, amount);
    }

    function _validateRedeemCaller(RedeemParams memory params, address owner) internal pure returns (bool) {
        return DETFBondNFTMathLib._validateRedeemCaller(params.caller, params.recipient, params.detf, owner);
    }
}