// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {SeigniorageNFTVaultTarget} from "contracts/vaults/seigniorage/SeigniorageNFTVaultTarget.sol";

/**
 * @title SeigniorageNFTVaultFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for Seigniorage NFT Vault operations.
 * @dev Extends SeigniorageNFTVaultTarget and implements IFacet.
 */
contract SeigniorageNFTVaultFacet is SeigniorageNFTVaultTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory name) {
        return type(SeigniorageNFTVaultFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(ISeigniorageNFTVault).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](21);
        funcs_[0] = ISeigniorageNFTVault.lockFromDetf.selector;
        funcs_[1] = ISeigniorageNFTVault.unlock.selector;
        funcs_[2] = ISeigniorageNFTVault.withdrawRewards.selector;
        funcs_[3] = ISeigniorageNFTVault.lockInfoOf.selector;
        funcs_[4] = ISeigniorageNFTVault.pendingRewards.selector;
        funcs_[5] = ISeigniorageNFTVault.totalShares.selector;
        funcs_[6] = ISeigniorageNFTVault.rewardPerShares.selector;
        funcs_[7] = ISeigniorageNFTVault.currentRewardPerShare.selector;
        funcs_[8] = ISeigniorageNFTVault.rewardSharesOf.selector;
        funcs_[9] = ISeigniorageNFTVault.rewardPerShareOf.selector;
        funcs_[10] = ISeigniorageNFTVault.unlockTimeOf.selector;
        funcs_[11] = ISeigniorageNFTVault.bonusPercentageOf.selector;
        funcs_[12] = ISeigniorageNFTVault.minimumLockDuration.selector;
        funcs_[13] = ISeigniorageNFTVault.maximumLockDuration.selector;
        funcs_[14] = ISeigniorageNFTVault.minBonusPercentage.selector;
        funcs_[15] = ISeigniorageNFTVault.maxBonusPercentage.selector;
        funcs_[16] = ISeigniorageNFTVault.detfToken.selector;
        funcs_[17] = ISeigniorageNFTVault.lpToken.selector;
        funcs_[18] = ISeigniorageNFTVault.rewardToken.selector;
        funcs_[19] = ISeigniorageNFTVault.claimToken.selector;
        funcs_[20] = ISeigniorageNFTVault.tokenURI.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(SeigniorageNFTVaultFacet).name;

        interfaces = new bytes4[](1);
        interfaces[0] = type(ISeigniorageNFTVault).interfaceId;

        functions = new bytes4[](21);
        functions[0] = ISeigniorageNFTVault.lockFromDetf.selector;
        functions[1] = ISeigniorageNFTVault.unlock.selector;
        functions[2] = ISeigniorageNFTVault.withdrawRewards.selector;
        functions[3] = ISeigniorageNFTVault.lockInfoOf.selector;
        functions[4] = ISeigniorageNFTVault.pendingRewards.selector;
        functions[5] = ISeigniorageNFTVault.totalShares.selector;
        functions[6] = ISeigniorageNFTVault.rewardPerShares.selector;
        functions[7] = ISeigniorageNFTVault.currentRewardPerShare.selector;
        functions[8] = ISeigniorageNFTVault.rewardSharesOf.selector;
        functions[9] = ISeigniorageNFTVault.rewardPerShareOf.selector;
        functions[10] = ISeigniorageNFTVault.unlockTimeOf.selector;
        functions[11] = ISeigniorageNFTVault.bonusPercentageOf.selector;
        functions[12] = ISeigniorageNFTVault.minimumLockDuration.selector;
        functions[13] = ISeigniorageNFTVault.maximumLockDuration.selector;
        functions[14] = ISeigniorageNFTVault.minBonusPercentage.selector;
        functions[15] = ISeigniorageNFTVault.maxBonusPercentage.selector;
        functions[16] = ISeigniorageNFTVault.detfToken.selector;
        functions[17] = ISeigniorageNFTVault.lpToken.selector;
        functions[18] = ISeigniorageNFTVault.rewardToken.selector;
        functions[19] = ISeigniorageNFTVault.claimToken.selector;
        functions[20] = ISeigniorageNFTVault.tokenURI.selector;
    }
}
