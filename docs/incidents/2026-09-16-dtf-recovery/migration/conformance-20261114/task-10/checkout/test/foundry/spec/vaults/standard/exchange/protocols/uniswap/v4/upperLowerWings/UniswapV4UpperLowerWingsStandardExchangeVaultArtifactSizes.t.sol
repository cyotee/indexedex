// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";

/// @notice Release gate independent of the larger Foundry harness code-size limit.
contract UniswapV4UpperLowerWingsStandardExchangeVaultArtifactSizesTest is Test {
    function test_everyDeployedFamilyComponentFitsEip170() public view {
        string[14] memory suffixes = ["Money", "RebalanceFacet", "EconomicFacet", "InFacet", "RebalancePlanner",
            "Projection", "ExecutionDelegate", "SYFacet", "QueryFacet", "TransitionFacet", "OutFacet", "DFPkg", "Harvest", "LiquidationQuote"];
        for (uint256 i; i < suffixes.length; ++i) {
            string memory name = string.concat("UniswapV4UpperLowerWingsStandardExchangeVault", suffixes[i]);
            string memory artifact = vm.readFile(string.concat(vm.projectRoot(), "/out/", name, ".sol/", name, ".json"));
            bytes memory runtime = bytes(vm.parseJsonString(artifact, ".deployedBytecode.object"));
            assertGt(runtime.length, 2, name);
            uint256 prefix = runtime[0] == "0" && runtime[1] == "x" ? 2 : 0;
            assertLe((runtime.length - prefix) / 2, 24576, name);
        }
    }
}
