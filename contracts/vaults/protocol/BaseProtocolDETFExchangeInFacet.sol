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
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {BaseProtocolDETFExchangeInTarget} from "contracts/vaults/protocol/BaseProtocolDETFExchangeInTarget.sol";

/**
 * @title BaseProtocolDETFExchangeInFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for Protocol DETF exchange-in operations.
 * @dev Extends BaseProtocolDETFExchangeInTarget and implements IFacet.
 */
contract BaseProtocolDETFExchangeInFacet is BaseProtocolDETFExchangeInTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory name) {
        return type(BaseProtocolDETFExchangeInFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(BaseProtocolDETFExchangeInFacet).name;
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        functions = new bytes4[](1);
        functions[0] = IStandardExchangeIn.exchangeIn.selector;
    }
}
