// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {SeigniorageDETFExchangeInTarget} from "contracts/vaults/seigniorage/SeigniorageDETFExchangeInTarget.sol";

/**
 * @title SeigniorageDETFExchangeInFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for Seigniorage DETF exchange-in operations.
 * @dev Extends SeigniorageDETFExchangeInTarget and implements IFacet.
 */
contract SeigniorageDETFExchangeInFacet is SeigniorageDETFExchangeInTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory name) {
        return type(SeigniorageDETFExchangeInFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](2);
        funcs_[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.exchangeIn.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(SeigniorageDETFExchangeInFacet).name;
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        functions = new bytes4[](2);
        functions[0] = IStandardExchangeIn.previewExchangeIn.selector;
        functions[1] = IStandardExchangeIn.exchangeIn.selector;
    }
}
