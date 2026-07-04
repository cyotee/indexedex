// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IERC20Metadata} from '@crane/contracts/interfaces/IERC20Metadata.sol';

import {IRICHIR} from 'contracts/interfaces/IRICHIR.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {RebasingDETFTokenTarget} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFTokenTarget.sol';

contract RebasingDETFTokenFacet is RebasingDETFTokenTarget, IFacet {
    function facetName() external pure returns (string memory) {
        return type(RebasingDETFTokenFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](5);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IRICHIR).interfaceId;
        interfaces_[3] = type(IStandardExchangeIn).interfaceId;
        interfaces_[4] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](26);
        funcs_[0] = IERC20.totalSupply.selector;
        funcs_[1] = IERC20.balanceOf.selector;
        funcs_[2] = IERC20.transfer.selector;
        funcs_[3] = IERC20.allowance.selector;
        funcs_[4] = IERC20.approve.selector;
        funcs_[5] = IERC20.transferFrom.selector;
        funcs_[6] = IERC20Metadata.name.selector;
        funcs_[7] = IERC20Metadata.symbol.selector;
        funcs_[8] = IERC20Metadata.decimals.selector;
        funcs_[9] = IRICHIR.sharesOf.selector;
        funcs_[10] = IRICHIR.totalShares.selector;
        funcs_[11] = IRICHIR.redemptionRate.selector;
        funcs_[12] = IRICHIR.protocolDETF.selector;
        funcs_[13] = IRICHIR.setProtocolDETF.selector;
        funcs_[14] = IRICHIR.detfNFTId.selector;
        funcs_[15] = IRICHIR.wethToken.selector;
        funcs_[16] = IRICHIR.convertToShares.selector;
        funcs_[17] = IRICHIR.convertToRichir.selector;
        funcs_[18] = IRICHIR.previewRedeem.selector;
        funcs_[19] = IRICHIR.mintFromNFTSale.selector;
        funcs_[20] = IRICHIR.redeem.selector;
        funcs_[21] = IRICHIR.burnShares.selector;
        funcs_[22] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[23] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[24] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs_[25] = IStandardExchangeOut.exchangeOut.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(RebasingDETFTokenFacet).name;

        interfaces_ = new bytes4[](5);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IRICHIR).interfaceId;
        interfaces_[3] = type(IStandardExchangeIn).interfaceId;
        interfaces_[4] = type(IStandardExchangeOut).interfaceId;

        functions_ = new bytes4[](26);
        functions_[0] = IERC20.totalSupply.selector;
        functions_[1] = IERC20.balanceOf.selector;
        functions_[2] = IERC20.transfer.selector;
        functions_[3] = IERC20.allowance.selector;
        functions_[4] = IERC20.approve.selector;
        functions_[5] = IERC20.transferFrom.selector;
        functions_[6] = IERC20Metadata.name.selector;
        functions_[7] = IERC20Metadata.symbol.selector;
        functions_[8] = IERC20Metadata.decimals.selector;
        functions_[9] = IRICHIR.sharesOf.selector;
        functions_[10] = IRICHIR.totalShares.selector;
        functions_[11] = IRICHIR.redemptionRate.selector;
        functions_[12] = IRICHIR.protocolDETF.selector;
        functions_[13] = IRICHIR.setProtocolDETF.selector;
        functions_[14] = IRICHIR.detfNFTId.selector;
        functions_[15] = IRICHIR.wethToken.selector;
        functions_[16] = IRICHIR.convertToShares.selector;
        functions_[17] = IRICHIR.convertToRichir.selector;
        functions_[18] = IRICHIR.previewRedeem.selector;
        functions_[19] = IRICHIR.mintFromNFTSale.selector;
        functions_[20] = IRICHIR.redeem.selector;
        functions_[21] = IRICHIR.burnShares.selector;
        functions_[22] = IStandardExchangeIn.previewExchangeIn.selector;
        functions_[23] = IStandardExchangeIn.exchangeIn.selector;
        functions_[24] = IStandardExchangeOut.previewExchangeOut.selector;
        functions_[25] = IStandardExchangeOut.exchangeOut.selector;
    }
}