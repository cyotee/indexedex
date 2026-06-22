// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {SingleVaultDetfExchangeOutTarget} from "contracts/vaults/detf/composed/single/SingleVaultDetfExchangeOutTarget.sol";

contract SingleVaultDetfExchangeOutFacet is SingleVaultDetfExchangeOutTarget, IFacet {
    function facetName() external pure returns (string memory name_) {
        return type(SingleVaultDetfExchangeOutFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeOut.exchangeOut.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(SingleVaultDetfExchangeOutFacet).name;
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeOut).interfaceId;
        functions_ = new bytes4[](1);
        functions_[0] = IStandardExchangeOut.exchangeOut.selector;
    }
}