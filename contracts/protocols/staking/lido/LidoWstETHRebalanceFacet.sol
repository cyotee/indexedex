// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ILidoWstETHRebalance} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";
import {LidoWstETHRebalanceTarget} from "contracts/protocols/staking/lido/LidoWstETHRebalanceTarget.sol";

contract LidoWstETHRebalanceFacet is LidoWstETHRebalanceTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(LidoWstETHRebalanceFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(ILidoWstETHRebalance).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = ILidoWstETHRebalance.rebalance.selector;
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
