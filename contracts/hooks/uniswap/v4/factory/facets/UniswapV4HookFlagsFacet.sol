// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4HookFlags
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookFlags.sol";
import {
    UniswapV4HookFlagsTarget
} from "contracts/hooks/uniswap/v4/factory/targets/UniswapV4HookFlagsTarget.sol";

/**
 * @title UniswapV4HookFlagsFacet
 * @notice Base facet installed on every hook diamond proxy by the hook package callback factory.
 */
contract UniswapV4HookFlagsFacet is UniswapV4HookFlagsTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(UniswapV4HookFlagsFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4HookFlags).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IUniswapV4HookFlags.requiredHookFlags.selector;
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
}
