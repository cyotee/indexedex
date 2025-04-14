// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.30;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {
    IUnbalancedLiquidityInvariantRatioBounds
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IUnbalancedLiquidityInvariantRatioBounds.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

contract StandardUnbalancedLiquidityInvariantRatioBoundsFacet is IFacet, IUnbalancedLiquidityInvariantRatioBounds {
    uint256 private constant _MIN_INVARIANT_RATIO = 70e16; // 70%
    uint256 private constant _MAX_INVARIANT_RATIO = 300e16; // 300%

    function facetName() public pure returns (string memory name) {
        return type(StandardUnbalancedLiquidityInvariantRatioBoundsFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUnbalancedLiquidityInvariantRatioBounds).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IUnbalancedLiquidityInvariantRatioBounds.getMinimumInvariantRatio.selector;
        funcs[1] = IUnbalancedLiquidityInvariantRatioBounds.getMaximumInvariantRatio.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }

    function getMinimumInvariantRatio() external pure returns (uint256 minimumInvariantRatio) {
        return _MIN_INVARIANT_RATIO;
    }

    function getMaximumInvariantRatio() external pure returns (uint256 maximumInvariantRatio) {
        return _MAX_INVARIANT_RATIO;
    }
}
