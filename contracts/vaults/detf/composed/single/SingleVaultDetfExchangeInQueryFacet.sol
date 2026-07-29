// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {SingleVaultDetfExchangeInQueryTarget} from "contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryTarget.sol";

contract SingleVaultDetfExchangeInQueryFacet is SingleVaultDetfExchangeInQueryTarget, IFacet {
    function facetName() external pure returns (string memory name_) {
        return type(SingleVaultDetfExchangeInQueryFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IStandardExchangeOut).interfaceId;
        interfaces_[2] = type(IDetf).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](4);
        funcs_[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[1] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs_[2] = IDetf.previewClaimLiquidity.selector;
        funcs_[3] = IDetf.previewBridgeRebasingClaim.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(SingleVaultDetfExchangeInQueryFacet).name;
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IStandardExchangeOut).interfaceId;
        interfaces_[2] = type(IDetf).interfaceId;
        functions_ = new bytes4[](4);
        functions_[0] = IStandardExchangeIn.previewExchangeIn.selector;
        functions_[1] = IStandardExchangeOut.previewExchangeOut.selector;
        functions_[2] = IDetf.previewClaimLiquidity.selector;
        functions_[3] = IDetf.previewBridgeRebasingClaim.selector;
    }
}