// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {RebasingDETFTokenPricingTarget} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFTokenPricingTarget.sol';

contract RebasingDETFTokenPricingFacet is RebasingDETFTokenPricingTarget, IFacet {
    function facetName() external pure returns (string memory name_) {
        return type(RebasingDETFTokenPricingFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IDETF).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](10);
        funcs_[0] = IDETF.bondNftVault.selector;
        funcs_[1] = IDETF.detfNFTId.selector;
        funcs_[2] = IDETF.rebasingDetfToken.selector;
        funcs_[3] = IDETF.reservePool.selector;
        funcs_[4] = IDETF.previewRebasingDetfTokenReserveBpt.selector;
        funcs_[5] = IDETF.previewRebasingDetfTokenEthValue.selector;
        funcs_[6] = IDETF.previewStablePoolBptEthValue.selector;
        funcs_[7] = IDETF.previewCommonPoolBptEthValue.selector;
        funcs_[8] = IDETF.syntheticDetfEthPrice.selector;
        funcs_[9] = IDETF.previewReservePoolDecomposition.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(RebasingDETFTokenPricingFacet).name;

        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IDETF).interfaceId;

        functions_ = new bytes4[](10);
        functions_[0] = IDETF.bondNftVault.selector;
        functions_[1] = IDETF.detfNFTId.selector;
        functions_[2] = IDETF.rebasingDetfToken.selector;
        functions_[3] = IDETF.reservePool.selector;
        functions_[4] = IDETF.previewRebasingDetfTokenReserveBpt.selector;
        functions_[5] = IDETF.previewRebasingDetfTokenEthValue.selector;
        functions_[6] = IDETF.previewStablePoolBptEthValue.selector;
        functions_[7] = IDETF.previewCommonPoolBptEthValue.selector;
        functions_[8] = IDETF.syntheticDetfEthPrice.selector;
        functions_[9] = IDETF.previewReservePoolDecomposition.selector;
    }
}