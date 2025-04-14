// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {ProtocolNFTVaultTarget} from "contracts/vaults/protocol/ProtocolNFTVaultTarget.sol";

/**
 * @title ProtocolNFTVaultFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for Protocol NFT Vault operations.
 * @dev Extends ProtocolNFTVaultTarget and implements IFacet.
 */
contract ProtocolNFTVaultFacet is ProtocolNFTVaultTarget, IFacet {

    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory name) {
        return type(ProtocolNFTVaultFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IProtocolNFTVault).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](23);
        funcs_[0] = IProtocolNFTVault.initializeProtocolNFT.selector;
        funcs_[1] = IProtocolNFTVault.createPosition.selector;
        funcs_[2] = IProtocolNFTVault.redeemPosition.selector;
        funcs_[3] = IProtocolNFTVault.claimRewards.selector;
        funcs_[4] = IProtocolNFTVault.addToProtocolNFT.selector;
        funcs_[5] = IProtocolNFTVault.sellPositionToProtocol.selector;
        funcs_[6] = IProtocolNFTVault.getPosition.selector;
        funcs_[7] = IProtocolNFTVault.pendingRewards.selector;
        funcs_[8] = IProtocolNFTVault.totalShares.selector;
        funcs_[9] = IProtocolNFTVault.protocolDETF.selector;
        funcs_[10] = IProtocolNFTVault.lpToken.selector;
        funcs_[11] = IProtocolNFTVault.rewardToken.selector;
        funcs_[12] = IProtocolNFTVault.protocolNFTId.selector;
        funcs_[13] = IProtocolNFTVault.positionOf.selector;
        funcs_[14] = IProtocolNFTVault.originalSharesOf.selector;
        funcs_[15] = IProtocolNFTVault.effectiveSharesOf.selector;
        funcs_[16] = IProtocolNFTVault.unlockTimeOf.selector;
        funcs_[17] = IProtocolNFTVault.isUnlocked.selector;
        funcs_[18] = IProtocolNFTVault.convertToShares.selector;
        funcs_[19] = IProtocolNFTVault.convertToAssets.selector;
        funcs_[20] = IProtocolNFTVault.markProtocolNFTSold.selector;
        funcs_[21] = IProtocolNFTVault.reallocateProtocolRewards.selector;
        funcs_[22] = IERC721Metadata.tokenURI.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        public
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
