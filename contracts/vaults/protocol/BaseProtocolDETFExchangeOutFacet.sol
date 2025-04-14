// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {BaseProtocolDETFExchangeOutTarget} from "contracts/vaults/protocol/BaseProtocolDETFExchangeOutTarget.sol";

/**
 * @title BaseProtocolDETFExchangeOutFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for Protocol DETF exchange-out operations.
 * @dev Extends BaseProtocolDETFExchangeOutTarget and implements IFacet.
 */
contract BaseProtocolDETFExchangeOutFacet is BaseProtocolDETFExchangeOutTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory name) {
        return type(BaseProtocolDETFExchangeOutFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeOut).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](2);
        funcs_[0] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs_[1] = IStandardExchangeOut.exchangeOut.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(BaseProtocolDETFExchangeOutFacet).name;
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeOut).interfaceId;
        functions = new bytes4[](2);
        functions[0] = IStandardExchangeOut.previewExchangeOut.selector;
        functions[1] = IStandardExchangeOut.exchangeOut.selector;
    }
}
