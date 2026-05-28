// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {
    IBaseDualSelfCommonDETFBonding,
    BaseDualSelfCommonDETFBondingTarget
} from "contracts/vaults/protocol/BaseDualSelfCommonDETFBondingTarget.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {EthereumDualSelfCommonDETFBondingTarget} from "contracts/vaults/protocol/EthereumDualSelfCommonDETFBondingTarget.sol";

contract EthereumDualSelfCommonDETFBondingFacet is EthereumDualSelfCommonDETFBondingTarget, IFacet {
    function facetName() external pure returns (string memory name) {
        return type(EthereumDualSelfCommonDETFBondingFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IBaseDualSelfCommonDETFBonding).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](7);
        funcs_[0] = IBaseDualSelfCommonDETFBonding.acceptedBondTokens.selector;
        funcs_[1] = IBaseDualSelfCommonDETFBonding.isAcceptedBondToken.selector;
        funcs_[2] = IBaseDualSelfCommonDETFBonding.bond.selector;
        funcs_[3] = IBaseDualSelfCommonDETFBonding.captureSeigniorage.selector;
        funcs_[4] = IBaseDualSelfCommonDETFBonding.sellNFT.selector;
        funcs_[5] = IBaseDualSelfCommonDETFBonding.donate.selector;
        funcs_[6] = IProtocolDETF.claimLiquidity.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(EthereumDualSelfCommonDETFBondingFacet).name;
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBaseDualSelfCommonDETFBonding).interfaceId;
        functions = new bytes4[](7);
        functions[0] = IBaseDualSelfCommonDETFBonding.acceptedBondTokens.selector;
        functions[1] = IBaseDualSelfCommonDETFBonding.isAcceptedBondToken.selector;
        functions[2] = IBaseDualSelfCommonDETFBonding.bond.selector;
        functions[3] = IBaseDualSelfCommonDETFBonding.captureSeigniorage.selector;
        functions[4] = IBaseDualSelfCommonDETFBonding.sellNFT.selector;
        functions[5] = IBaseDualSelfCommonDETFBonding.donate.selector;
        functions[6] = IProtocolDETF.claimLiquidity.selector;
    }
}