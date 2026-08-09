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

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {DETFNFTVaultTarget} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultTarget.sol";

/**
 * @title DETFNFTVaultFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for Protocol NFT Vault operations.
 * @dev Extends DETFNFTVaultTarget and implements IFacet.
 */
contract DETFNFTVaultFacet is DETFNFTVaultTarget, IFacet {

    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory name) {
        return type(DETFNFTVaultFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IDETFNFTVault).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        // Product surface (no retired markDETFNFTSold / detfNFTSold).
        funcs_ = new bytes4[](26);
        funcs_[0] = IDETFNFTVault.initializeDETFNFT.selector;
        funcs_[1] = IDETFNFTVault.createPosition.selector;
        funcs_[2] = IDETFNFTVault.redeemPosition.selector;
        funcs_[3] = IDETFNFTVault.claimRewards.selector;
        funcs_[4] = IDETFNFTVault.addToDETFNFT.selector;
        funcs_[5] = IDETFNFTVault.sellPositionToDetfNft.selector;
        funcs_[6] = IDETFNFTVault.getPosition.selector;
        funcs_[7] = IDETFNFTVault.pendingRewards.selector;
        funcs_[8] = IDETFNFTVault.totalShares.selector;
        funcs_[9] = IDETFNFTVault.detf.selector;
        funcs_[10] = IDETFNFTVault.lpToken.selector;
        funcs_[11] = IDETFNFTVault.rewardToken.selector;
        funcs_[12] = IDETFNFTVault.detfNFTId.selector;
        funcs_[13] = IDETFNFTVault.positionOf.selector;
        funcs_[14] = IDETFNFTVault.originalSharesOf.selector;
        funcs_[15] = IDETFNFTVault.effectiveSharesOf.selector;
        funcs_[16] = IDETFNFTVault.unlockTimeOf.selector;
        funcs_[17] = IDETFNFTVault.isUnlocked.selector;
        funcs_[18] = IDETFNFTVault.convertToShares.selector;
        funcs_[19] = IDETFNFTVault.convertToAssets.selector;
        funcs_[20] = IDETFNFTVault.reallocateDetfNftRewards.selector;
        funcs_[21] = IERC721Metadata.tokenURI.selector;
        funcs_[22] = IDETFNFTVault.transferHeldToken.selector;
        funcs_[23] = IDETFNFTVault.createPositionWithEffectiveBase.selector;
        funcs_[24] = IDETFNFTVault.lockInfoOf.selector;
        funcs_[25] = IDETFNFTVault.rewardPerShares.selector;
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
