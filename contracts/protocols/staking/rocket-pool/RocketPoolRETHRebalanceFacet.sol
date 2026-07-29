// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IRocketPoolRETHRebalance
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";
import {
    RocketPoolRETHRebalanceTarget
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHRebalanceTarget.sol";

contract RocketPoolRETHRebalanceFacet is RocketPoolRETHRebalanceTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(RocketPoolRETHRebalanceFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IRocketPoolRETHRebalance).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IRocketPoolRETHRebalance.rebalance.selector;
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
