// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.30;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {
    ISwapFeePercentageBounds
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/ISwapFeePercentageBounds.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

contract StandardSwapFeePercentageBoundsFacet is IFacet, ISwapFeePercentageBounds {
    uint256 private constant _MIN_SWAP_FEE_PERCENTAGE = 1e12; // 0.0001%
    uint256 private constant _MAX_SWAP_FEE_PERCENTAGE = 0.1e18; // 10%

    function facetName() public pure returns (string memory name) {
        return type(StandardSwapFeePercentageBoundsFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(ISwapFeePercentageBounds).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = ISwapFeePercentageBounds.getMinimumSwapFeePercentage.selector;
        funcs[1] = ISwapFeePercentageBounds.getMaximumSwapFeePercentage.selector;
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

    function getMinimumSwapFeePercentage() external pure returns (uint256 minimumSwapFeePercentage) {
        return _MIN_SWAP_FEE_PERCENTAGE;
    }

    function getMaximumSwapFeePercentage() external pure returns (uint256 maximumSwapFeePercentage) {
        return _MAX_SWAP_FEE_PERCENTAGE;
    }
}
