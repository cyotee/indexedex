// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {DETFSYTarget} from "contracts/vaults/detf/common/sy/DETFSYTarget.sol";

/// @title DETFSYFacet
/// @notice Static, funded Pendle shares and directional routes for either DETF wrapper.
contract DETFSYFacet is DETFSYTarget, IFacet {
    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory) { return type(DETFSYFacet).name; }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](4);
        ids_[0] = type(IERC20).interfaceId;
        ids_[1] = type(IERC20Metadata).interfaceId;
        ids_[2] = type(IStandardizedYield).interfaceId;
        ids_[3] = type(IStandardVault).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](29);
        funcs_[0] = IERC20.totalSupply.selector;
        funcs_[1] = IERC20.balanceOf.selector;
        funcs_[2] = IERC20.transfer.selector;
        funcs_[3] = IERC20.allowance.selector;
        funcs_[4] = IERC20.approve.selector;
        funcs_[5] = IERC20.transferFrom.selector;
        funcs_[6] = IERC20Metadata.name.selector;
        funcs_[7] = IERC20Metadata.symbol.selector;
        funcs_[8] = IERC20Metadata.decimals.selector;
        funcs_[9] = IStandardizedYield.deposit.selector;
        funcs_[10] = IStandardizedYield.redeem.selector;
        funcs_[11] = IStandardizedYield.exchangeRate.selector;
        funcs_[12] = IStandardizedYield.yieldToken.selector;
        funcs_[13] = IStandardizedYield.assetInfo.selector;
        funcs_[14] = IStandardizedYield.getTokensIn.selector;
        funcs_[15] = IStandardizedYield.getTokensOut.selector;
        funcs_[16] = IStandardizedYield.isValidTokenIn.selector;
        funcs_[17] = IStandardizedYield.isValidTokenOut.selector;
        funcs_[18] = IStandardizedYield.previewDeposit.selector;
        funcs_[19] = IStandardizedYield.previewRedeem.selector;
        funcs_[20] = IStandardizedYield.getRewardTokens.selector;
        funcs_[21] = IStandardizedYield.accruedRewards.selector;
        funcs_[22] = IStandardizedYield.rewardIndexesCurrent.selector;
        funcs_[23] = IStandardizedYield.rewardIndexesStored.selector;
        funcs_[24] = IStandardizedYield.claimRewards.selector;
        funcs_[25] = IStandardVault.vaultFeeTypeIds.selector;
        funcs_[26] = IStandardVault.contentsId.selector;
        funcs_[27] = IStandardVault.vaultTypes.selector;
        funcs_[28] = IStandardVault.vaultConfig.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
