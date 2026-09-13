// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";
import {AaveV3StataMarkerTarget} from "contracts/protocols/lending/aave/v3.6/AaveV3StataMarkerTarget.sol";

import {AaveV3StataStandardYieldTarget} from "./AaveV3StataStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";

// tag::AaveV3StataMarkerFacet[]
/**
 * @title AaveV3StataMarkerFacet - IFacet declaration for the Stata marker.
 * @notice Provides the `stataToken()` marker function so that the interface ID
 *         can be used as a vault fee type for usage fee overrides.
 */
contract AaveV3StataMarkerFacet is AaveV3StataMarkerTarget, AaveV3StataStandardYieldTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                                 IFacet                                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IFacet
     */
    function facetName() public pure returns (string memory name) {
        return type(AaveV3StataMarkerFacet).name;
    }

    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[1] = type(IStandardizedYield).interfaceId;
        interfaces[0] = type(IAaveV3StataStandardVault).interfaceId;
        return interfaces;
    }

    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IAaveV3StataStandardVault.stataToken.selector;
        return NativeStandardYieldSelectors._append(funcs);
    }

    /**
     * @inheritdoc IFacet
     */
    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
// end::AaveV3StataMarkerFacet[]
