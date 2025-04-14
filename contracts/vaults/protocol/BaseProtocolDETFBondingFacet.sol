// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";

import {IBaseProtocolDETFBonding, BaseProtocolDETFBondingTarget} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";

/**
 * @title BaseProtocolDETFBondingFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for Protocol DETF bonding operations.
 * @dev Extends BaseProtocolDETFBondingTarget and implements IFacet.
 */
contract BaseProtocolDETFBondingFacet is BaseProtocolDETFBondingTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory name) {
        return type(BaseProtocolDETFBondingFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IBaseProtocolDETFBonding).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](9);
        funcs_[0] = IBaseProtocolDETFBonding.bondWithWeth.selector;
        funcs_[1] = IBaseProtocolDETFBonding.bondWithRich.selector;
        funcs_[2] = IBaseProtocolDETFBonding.captureSeigniorage.selector;
        funcs_[3] = IBaseProtocolDETFBonding.sellNFT.selector;
        funcs_[4] = IBaseProtocolDETFBonding.donate.selector;
        funcs_[5] = BaseProtocolDETFBondingTarget.initBridge.selector;
        funcs_[6] = IProtocolDETF.claimLiquidity.selector;
        funcs_[7] = IProtocolDETF.bridgeRichir.selector;
        funcs_[8] = IProtocolDETF.receiveBridgedRich.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(BaseProtocolDETFBondingFacet).name;
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBaseProtocolDETFBonding).interfaceId;
        functions = new bytes4[](9);
        functions[0] = IBaseProtocolDETFBonding.bondWithWeth.selector;
        functions[1] = IBaseProtocolDETFBonding.bondWithRich.selector;
        functions[2] = IBaseProtocolDETFBonding.captureSeigniorage.selector;
        functions[3] = IBaseProtocolDETFBonding.sellNFT.selector;
        functions[4] = IBaseProtocolDETFBonding.donate.selector;
        functions[5] = BaseProtocolDETFBondingTarget.initBridge.selector;
        functions[6] = IProtocolDETF.claimLiquidity.selector;
        functions[7] = IProtocolDETF.bridgeRichir.selector;
        functions[8] = IProtocolDETF.receiveBridgedRich.selector;
    }
}
