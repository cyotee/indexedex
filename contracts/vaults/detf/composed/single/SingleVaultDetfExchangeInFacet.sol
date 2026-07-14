// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SingleVaultDetfExchangeInTarget} from "contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInTarget.sol";

contract SingleVaultDetfExchangeInFacet is SingleVaultDetfExchangeInTarget, IFacet {
    function facetName() external pure returns (string memory name_) {
        return type(SingleVaultDetfExchangeInFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IProtocolDETF).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](2);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IProtocolDETF.mintWithRateAsset.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(SingleVaultDetfExchangeInFacet).name;
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IProtocolDETF).interfaceId;
        functions_ = new bytes4[](2);
        functions_[0] = IStandardExchangeIn.exchangeIn.selector;
        functions_[1] = IProtocolDETF.mintWithRateAsset.selector;
    }
}