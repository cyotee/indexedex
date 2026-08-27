// SPDX-License-Identifier: BSL-1.1
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
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {UniswapV4DetfBondNFTVaultTarget} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultTarget.sol";

/**
 * @title UniswapV4DetfBondNFTVaultFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for Protocol NFT Vault operations.
 * @dev Extends UniswapV4DetfBondNFTVaultTarget and implements IFacet.
 */
contract UniswapV4DetfBondNFTVaultFacet is UniswapV4DetfBondNFTVaultTarget, IFacet {

    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory name) {
        return type(UniswapV4DetfBondNFTVaultFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IDETFNFTVault).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        bytes4[] memory a = _funcsA();
        bytes4[] memory b = _funcsB();
        funcs_ = new bytes4[](a.length + b.length);
        for (uint256 i; i < a.length; ++i) {
            funcs_[i] = a[i];
        }
        for (uint256 j; j < b.length; ++j) {
            funcs_[a.length + j] = b[j];
        }
    }

    function _funcsA() private pure returns (bytes4[] memory funcs_) {
        // Product surface (no retired markDETFNFTSold / detfNFTSold).
        funcs_ = new bytes4[](20);
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
    }

    function _funcsB() private pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](17);
        funcs_[0] = IDETFNFTVault.reallocateDetfNftRewards.selector;
        funcs_[1] = IERC721Metadata.tokenURI.selector;
        funcs_[2] = IDETFNFTVault.transferHeldToken.selector;
        funcs_[3] = IDETFNFTVault.createPositionWithEffectiveBase.selector;
        funcs_[4] = IDETFNFTVault.lockInfoOf.selector;
        funcs_[5] = IDETFNFTVault.rewardPerShares.selector;
        funcs_[6] = IDETFNFTVault.removeFromDETFNFT.selector;
        funcs_[7] = IDETFNFTVault.totalOriginalShares.selector;
        funcs_[8] = IDETFNFTVault.initializeReservedBondNfts.selector;
        funcs_[9] = IDETFNFTVault.reservedBondNftsWired.selector;
        funcs_[10] = IDETFNFTVault.addEffectiveSharesOnly.selector;
        funcs_[11] = IDETFNFTVault.retireMaturePosition.selector;
        funcs_[12] = bytes4(keccak256("donate(address,uint256,uint256,bool,uint256)"));
        funcs_[13] = bytes4(keccak256("donate(address,address,uint256,uint256,bool,uint256)"));
        funcs_[14] = IDetfNftReserveDonation.donateWithPermit2Allowance.selector;
        funcs_[15] = IDetfNftReserveDonation.donateWithPermit2Signature.selector;
        funcs_[16] = IDetfNftReserveDonation.previewDonate.selector;
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
