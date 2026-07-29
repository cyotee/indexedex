// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {RebasingClaimTokenTarget} from "contracts/vaults/detf/claimToken/RebasingClaimTokenTarget.sol";

/**
 * @title RebasingClaimTokenFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for rebasing claim token rebasing token operations.
 * @dev Extends RebasingClaimTokenTarget and implements IFacet.
 */
contract RebasingClaimTokenFacet is RebasingClaimTokenTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory) {
        return type(RebasingClaimTokenFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](5);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IRebasingClaimToken).interfaceId;
        interfaces_[3] = type(IStandardExchangeIn).interfaceId;
        interfaces_[4] = type(IStandardExchangeOut).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](26);
        // ERC20 functions
        funcs_[0] = IERC20.totalSupply.selector;
        funcs_[1] = IERC20.balanceOf.selector;
        funcs_[2] = IERC20.transfer.selector;
        funcs_[3] = IERC20.allowance.selector;
        funcs_[4] = IERC20.approve.selector;
        funcs_[5] = IERC20.transferFrom.selector;
        // ERC20Metadata functions
        funcs_[6] = IERC20Metadata.name.selector;
        funcs_[7] = IERC20Metadata.symbol.selector;
        funcs_[8] = IERC20Metadata.decimals.selector;
        // IRebasingClaimToken functions
        funcs_[9] = IRebasingClaimToken.sharesOf.selector;
        funcs_[10] = IRebasingClaimToken.totalShares.selector;
        funcs_[11] = IRebasingClaimToken.redemptionRate.selector;
        funcs_[12] = IRebasingClaimToken.detf.selector;
        funcs_[13] = IRebasingClaimToken.setDetf.selector;
        funcs_[14] = IRebasingClaimToken.detfNFTId.selector;
        funcs_[15] = IRebasingClaimToken.rateAsset.selector;
        funcs_[16] = IRebasingClaimToken.convertToShares.selector;
        funcs_[17] = IRebasingClaimToken.convertToClaim.selector;
        funcs_[18] = IRebasingClaimToken.previewRedeem.selector;
        funcs_[19] = IRebasingClaimToken.mintFromNFTSale.selector;
        funcs_[20] = IRebasingClaimToken.redeem.selector;
        funcs_[21] = IRebasingClaimToken.burnShares.selector;
        funcs_[22] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[23] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[24] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs_[25] = IStandardExchangeOut.exchangeOut.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = type(RebasingClaimTokenFacet).name;

        interfaces = new bytes4[](5);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IRebasingClaimToken).interfaceId;
        interfaces[3] = type(IStandardExchangeIn).interfaceId;
        interfaces[4] = type(IStandardExchangeOut).interfaceId;

        functions = new bytes4[](26);
        functions[0] = IERC20.totalSupply.selector;
        functions[1] = IERC20.balanceOf.selector;
        functions[2] = IERC20.transfer.selector;
        functions[3] = IERC20.allowance.selector;
        functions[4] = IERC20.approve.selector;
        functions[5] = IERC20.transferFrom.selector;
        functions[6] = IERC20Metadata.name.selector;
        functions[7] = IERC20Metadata.symbol.selector;
        functions[8] = IERC20Metadata.decimals.selector;
        functions[9] = IRebasingClaimToken.sharesOf.selector;
        functions[10] = IRebasingClaimToken.totalShares.selector;
        functions[11] = IRebasingClaimToken.redemptionRate.selector;
        functions[12] = IRebasingClaimToken.detf.selector;
        functions[13] = IRebasingClaimToken.setDetf.selector;
        functions[14] = IRebasingClaimToken.detfNFTId.selector;
        functions[15] = IRebasingClaimToken.rateAsset.selector;
        functions[16] = IRebasingClaimToken.convertToShares.selector;
        functions[17] = IRebasingClaimToken.convertToClaim.selector;
        functions[18] = IRebasingClaimToken.previewRedeem.selector;
        functions[19] = IRebasingClaimToken.mintFromNFTSale.selector;
        functions[20] = IRebasingClaimToken.redeem.selector;
        functions[21] = IRebasingClaimToken.burnShares.selector;
        functions[22] = IStandardExchangeIn.previewExchangeIn.selector;
        functions[23] = IStandardExchangeIn.exchangeIn.selector;
        functions[24] = IStandardExchangeOut.previewExchangeOut.selector;
        functions[25] = IStandardExchangeOut.exchangeOut.selector;
    }
}
