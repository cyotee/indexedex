// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {IAaveCrossVersionLoopVault} from "contracts/interfaces/IAaveCrossVersionLoopVault.sol";
import {AaveCrossVersionLoopMarkerTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopMarkerTarget.sol";

/**
 * @title AaveCrossVersionLoopMarkerFacet
 * @author cyotee doge <doge.cyotee>
 * @notice IFacet declaration for the cross-version loop marker. Its interfaceId is used as the
 *         vault fee type key for usage/performance-fee configuration (PRD decisions 19, 26).
 */
contract AaveCrossVersionLoopMarkerFacet is AaveCrossVersionLoopMarkerTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(AaveCrossVersionLoopMarkerFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IAaveCrossVersionLoopVault).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IAaveCrossVersionLoopVault.tokenA.selector;
        funcs[1] = IAaveCrossVersionLoopVault.tokenB.selector;
        funcs[2] = IAaveCrossVersionLoopVault.aaveV36Pool.selector;
        funcs[3] = IAaveCrossVersionLoopVault.aaveV4Spoke.selector;
        funcs[4] = IAaveCrossVersionLoopVault.aaveV4Hub.selector;
        funcs[5] = IAaveCrossVersionLoopVault.netBalanceOf.selector;
    }

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
