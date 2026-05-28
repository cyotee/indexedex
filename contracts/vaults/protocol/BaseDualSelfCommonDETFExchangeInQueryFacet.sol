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
import {BaseDualSelfCommonDETFExchangeInQueryTarget} from "contracts/vaults/protocol/BaseDualSelfCommonDETFExchangeInQueryTarget.sol";

/**
 * @title BaseDualSelfCommonDETFExchangeInQueryFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for Protocol DETF exchange-in query/preview operations.
 * @dev Split from BaseDualSelfCommonDETFExchangeInFacet to meet EIP-170 contract size limit.
 *      Contains view-only functions (previewExchangeIn).
 */
contract BaseDualSelfCommonDETFExchangeInQueryFacet is BaseDualSelfCommonDETFExchangeInQueryTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory name) {
        return type(BaseDualSelfCommonDETFExchangeInQueryFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeIn.previewExchangeIn.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
