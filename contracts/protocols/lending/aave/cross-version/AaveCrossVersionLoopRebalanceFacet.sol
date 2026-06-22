// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {AaveCrossVersionLoopRebalanceTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceTarget.sol";

/**
 * @title AaveCrossVersionLoopRebalanceFacet
 * @author cyotee doge <doge.cyotee>
 * @notice IFacet declaration for permissionless rebalance + forceRepay.
 */
contract AaveCrossVersionLoopRebalanceFacet is AaveCrossVersionLoopRebalanceTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(AaveCrossVersionLoopRebalanceFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](3);
        funcs[0] = AaveCrossVersionLoopRebalanceTarget.rebalance.selector;
        funcs[1] = AaveCrossVersionLoopRebalanceTarget.forceRepay.selector;
        funcs[2] = AaveCrossVersionLoopRebalanceTarget.previewNetCarry.selector;
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
