// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";

import {
    TestBase_UniswapV4HookDiamondPackageCallBackFactory
} from "test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol";

contract UniswapV4HookDiamondFactory_ImmutableTest is TestBase_UniswapV4HookDiamondPackageCallBackFactory {
    /// H10: no diamondCut after postDeploy; PostDeploy selectors gone
    function test_H10_immutableNoDiamondCutOrPostDeploy() public {
        address proxy = _deployStubPremine();
        IDiamondLoupe loupe = IDiamondLoupe(proxy);

        assertEq(loupe.facetAddress(IDiamondCut.diamondCut.selector), address(0), "diamondCut must be absent");
        assertEq(
            loupe.facetAddress(IPostDeployAccountHook.postDeploy.selector),
            address(0),
            "postDeploy must be removed"
        );

        // Calling diamondCut should fail (no facet / fallback)
        IDiamond.FacetCut[] memory empty;
        vm.expectRevert();
        IDiamondCut(proxy).diamondCut(empty, address(0), "");
    }
}
